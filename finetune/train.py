#!/usr/bin/env python3
"""
LoRA fine-tuning for Drift tool-calling models.
Config-driven, MPS-compatible, trains on assistant tokens only.

Usage:
    python train.py --config config/qwen2.5-1.5b.yaml --data data/train.jsonl
    python train.py --config config/gemma4-2b.yaml --data data/train.jsonl
"""

import argparse
import json
import os
import time
from datetime import datetime
from pathlib import Path

import torch
import yaml
from datasets import Dataset
from peft import LoraConfig, get_peft_model, TaskType
from transformers import AutoModelForCausalLM, AutoTokenizer
from trl import SFTConfig, SFTTrainer

# MPS memory management
os.environ["PYTORCH_MPS_HIGH_WATERMARK_RATIO"] = "0.0"


def load_config(config_path: str) -> dict:
    with open(config_path) as f:
        return yaml.safe_load(f)


def format_example(item: dict, chat_template: str) -> str:
    """Format a training example into the target chat template."""
    system = item["system"]
    user = item["user"]
    assistant = item["assistant"]

    if chat_template == "gemma":
        return (
            f"<start_of_turn>user\n{system}\n\n{user}<end_of_turn>\n"
            f"<start_of_turn>model\n{assistant}<end_of_turn>"
        )
    # Default: ChatML
    return (
        f"<|im_start|>system\n{system}<|im_end|>\n"
        f"<|im_start|>user\n{user}<|im_end|>\n"
        f"<|im_start|>assistant\n{assistant}<|im_end|>"
    )


def get_response_template(chat_template: str) -> str:
    """Return the template string that marks the start of the assistant response."""
    if chat_template == "gemma":
        return "<start_of_turn>model\n"
    return "<|im_start|>assistant\n"


def load_training_data(data_path: str, chat_template: str) -> Dataset:
    """Load JSONL and format as chat conversations."""
    texts = []
    with open(data_path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            item = json.loads(line)
            texts.append(format_example(item, chat_template))

    return Dataset.from_dict({"text": texts})


def main():
    parser = argparse.ArgumentParser(description="Fine-tune model with LoRA")
    parser.add_argument("--config", type=str, required=True, help="Model config YAML")
    parser.add_argument("--data", type=str, required=True, help="Training data JSONL")
    parser.add_argument("--output-dir", type=str, default=None, help="Output directory")
    parser.add_argument("--resume", type=str, default=None, help="Resume from checkpoint")
    args = parser.parse_args()

    config = load_config(args.config)
    model_id = config["model_id"]
    chat_template = config.get("chat_template", "chatml")
    lora_cfg = config["lora"]
    train_cfg = config["training"]

    # Output directory
    model_name = model_id.split("/")[-1]
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_dir = args.output_dir or f"output/{model_name}/{timestamp}"
    Path(output_dir).mkdir(parents=True, exist_ok=True)

    print(f"{'='*60}")
    print(f"Fine-tuning: {model_id}")
    print(f"Chat template: {chat_template}")
    print(f"Output: {output_dir}")
    print(f"{'='*60}")

    # Determine device
    if torch.backends.mps.is_available():
        device = "mps"
        print("Using MPS (Apple Silicon)")
    elif torch.cuda.is_available():
        device = "cuda"
        print("Using CUDA")
    else:
        device = "cpu"
        print("Using CPU (this will be slow)")

    # Load tokenizer
    print(f"\nLoading tokenizer: {model_id}")
    tokenizer = AutoTokenizer.from_pretrained(model_id, trust_remote_code=True)
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token

    # Load model
    print(f"Loading model: {model_id}")
    model = AutoModelForCausalLM.from_pretrained(
        model_id,
        torch_dtype=torch.float32,  # MPS needs float32
        device_map={"": device} if device != "mps" else None,
        trust_remote_code=True,
    )
    if device == "mps":
        model = model.to(device)

    # Apply LoRA
    print(f"Applying LoRA (r={lora_cfg['r']}, alpha={lora_cfg['alpha']})")
    lora_config = LoraConfig(
        r=lora_cfg["r"],
        lora_alpha=lora_cfg["alpha"],
        lora_dropout=lora_cfg["dropout"],
        target_modules=lora_cfg["target_modules"],
        task_type=TaskType.CAUSAL_LM,
    )
    model = get_peft_model(model, lora_config)
    model.print_trainable_parameters()

    # Load data
    print(f"\nLoading training data: {args.data}")
    dataset = load_training_data(args.data, chat_template)
    print(f"  {len(dataset)} examples")

    # Response template for completion-only loss
    response_template = get_response_template(chat_template)

    # SFTConfig (TRL 1.0 API — replaces TrainingArguments)
    sft_config = SFTConfig(
        output_dir=output_dir,
        num_train_epochs=train_cfg["epochs"],
        per_device_train_batch_size=train_cfg["batch_size"],
        gradient_accumulation_steps=train_cfg["gradient_accumulation"],
        learning_rate=train_cfg["learning_rate"],
        lr_scheduler_type=train_cfg.get("lr_scheduler", "cosine"),
        warmup_ratio=train_cfg.get("warmup_ratio", 0.05),
        optim=train_cfg["optim"],
        logging_steps=10,
        save_strategy="epoch",
        save_total_limit=2,
        fp16=False,
        bf16=False,
        gradient_checkpointing=True,
        max_grad_norm=1.0,
        dataloader_pin_memory=False,  # Required for MPS
        report_to="none",
        # TRL 1.0 specific
        max_length=train_cfg.get("max_seq_length", 512),
        dataset_text_field="text",
        completion_only_loss=response_template,  # Mask loss to assistant tokens only
        packing=False,
    )

    # Trainer
    trainer = SFTTrainer(
        model=model,
        args=sft_config,
        train_dataset=dataset,
        processing_class=tokenizer,
    )

    # Train
    print(f"\n{'='*60}")
    print("Starting training...")
    print(f"{'='*60}\n")

    start_time = time.time()
    if args.resume:
        trainer.train(resume_from_checkpoint=args.resume)
    else:
        trainer.train()
    elapsed = time.time() - start_time

    print(f"\n{'='*60}")
    print(f"Training complete in {elapsed/60:.1f} minutes")
    print(f"{'='*60}")

    # Save final model
    final_path = f"{output_dir}/final"
    trainer.save_model(final_path)
    tokenizer.save_pretrained(final_path)
    print(f"Model saved: {final_path}")

    # Save config for reproducibility
    with open(f"{output_dir}/config.yaml", "w") as f:
        yaml.dump(config, f)

    # Write a symlink for convenience
    latest = Path(f"output/{model_name}/latest")
    if latest.is_symlink():
        latest.unlink()
    latest.symlink_to(Path(timestamp).resolve() if not Path(timestamp).is_absolute() else timestamp, target_is_directory=True)
    print(f"Latest symlink: {latest} → {timestamp}")


if __name__ == "__main__":
    main()
