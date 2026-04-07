#!/usr/bin/env python3
"""
Export fine-tuned model: merge LoRA → HF → GGUF → quantize.

Usage:
    python export.py --model output/latest/final --quant q4_k_m
    python export.py --model output/latest/final --llama-cpp /tmp/llama.cpp --quant q4_k_m
"""

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

import torch
from peft import PeftModel
from transformers import AutoModelForCausalLM, AutoTokenizer


def merge_lora(model_path: str, output_path: str):
    """Merge LoRA adapter into base model."""
    print(f"\n{'='*50}")
    print("Step 1: Merging LoRA adapter")
    print(f"{'='*50}")

    adapter_config = Path(model_path) / "adapter_config.json"
    if not adapter_config.exists():
        print(f"No adapter_config.json — assuming already merged model at {model_path}")
        if model_path != output_path:
            shutil.copytree(model_path, output_path, dirs_exist_ok=True)
        return

    with open(adapter_config) as f:
        cfg = json.load(f)
    base_model_id = cfg["base_model_name_or_path"]

    print(f"  Base model: {base_model_id}")
    print(f"  Adapter: {model_path}")

    tokenizer = AutoTokenizer.from_pretrained(model_path, trust_remote_code=True)
    base_model = AutoModelForCausalLM.from_pretrained(
        base_model_id,
        torch_dtype=torch.float16,
        trust_remote_code=True,
    )

    model = PeftModel.from_pretrained(base_model, model_path)
    model = model.merge_and_unload()

    Path(output_path).mkdir(parents=True, exist_ok=True)
    model.save_pretrained(output_path)
    tokenizer.save_pretrained(output_path)
    print(f"  ✅ Merged model saved: {output_path}")


def convert_to_gguf(hf_path: str, gguf_path: str, llama_cpp_path: str):
    """Convert HF model to GGUF using llama.cpp."""
    print(f"\n{'='*50}")
    print("Step 2: Converting to GGUF (f16)")
    print(f"{'='*50}")

    convert_script = Path(llama_cpp_path) / "convert_hf_to_gguf.py"
    if not convert_script.exists():
        print(f"  ❌ convert_hf_to_gguf.py not found at {convert_script}")
        print(f"  Clone llama.cpp: git clone https://github.com/ggerganov/llama.cpp {llama_cpp_path}")
        sys.exit(1)

    cmd = [
        sys.executable, str(convert_script),
        hf_path,
        "--outfile", gguf_path,
        "--outtype", "f16",
    ]

    print(f"  Running: {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"  ❌ Conversion failed:\n{result.stderr}")
        sys.exit(1)

    print(f"  ✅ GGUF (f16): {gguf_path}")


def quantize_gguf(input_gguf: str, output_gguf: str, quant_type: str, llama_cpp_path: str):
    """Quantize GGUF model."""
    print(f"\n{'='*50}")
    print(f"Step 3: Quantizing to {quant_type}")
    print(f"{'='*50}")

    quantize_bin = Path(llama_cpp_path) / "build" / "bin" / "llama-quantize"
    if not quantize_bin.exists():
        # Try alternate location
        quantize_bin = Path(llama_cpp_path) / "build" / "llama-quantize"
    if not quantize_bin.exists():
        print(f"  ❌ llama-quantize not found. Build llama.cpp:")
        print(f"  cd {llama_cpp_path} && cmake -B build && cmake --build build --target llama-quantize")
        sys.exit(1)

    cmd = [str(quantize_bin), input_gguf, output_gguf, quant_type.upper()]
    print(f"  Running: {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"  ❌ Quantization failed:\n{result.stderr}")
        sys.exit(1)

    # File size
    size_mb = Path(output_gguf).stat().st_size / (1024 * 1024)
    print(f"  ✅ Quantized: {output_gguf} ({size_mb:.0f} MB)")


def main():
    parser = argparse.ArgumentParser(description="Export model to GGUF")
    parser.add_argument("--model", type=str, required=True, help="Fine-tuned model path")
    parser.add_argument("--quant", type=str, default="q4_k_m", help="Quantization type (default: q4_k_m)")
    parser.add_argument("--llama-cpp", type=str, default="/tmp/llama.cpp", help="Path to llama.cpp repo")
    parser.add_argument("--output-dir", type=str, default=None, help="Output directory")
    args = parser.parse_args()

    model_path = Path(args.model)
    if not model_path.exists():
        print(f"❌ Model not found: {model_path}")
        sys.exit(1)

    # Determine output dir
    output_dir = Path(args.output_dir) if args.output_dir else model_path.parent / "export"
    output_dir.mkdir(parents=True, exist_ok=True)

    # Infer model name from path
    model_name = model_path.parent.name if model_path.name == "final" else model_path.name

    # Step 1: Merge LoRA
    merged_path = str(output_dir / "merged")
    merge_lora(str(model_path), merged_path)

    # Step 2: Convert to GGUF f16
    f16_gguf = str(output_dir / f"drift-{model_name}-f16.gguf")
    convert_to_gguf(merged_path, f16_gguf, args.llama_cpp)

    # Step 3: Quantize
    quant_gguf = str(output_dir / f"drift-{model_name}-{args.quant}.gguf")
    quantize_gguf(f16_gguf, quant_gguf, args.quant, args.llama_cpp)

    # Cleanup f16 (large)
    f16_path = Path(f16_gguf)
    if f16_path.exists():
        f16_path.unlink()
        print(f"\n  Cleaned up f16 GGUF ({f16_path.name})")

    print(f"\n{'='*50}")
    print(f"EXPORT COMPLETE")
    print(f"  GGUF: {quant_gguf}")
    print(f"{'='*50}")
    print(f"\nTo test in iOS:")
    print(f"  cp {quant_gguf} /tmp/")
    print(f"  xcodebuild test -only-testing:'DriftTests/LLMToolCallingEval' ...")


if __name__ == "__main__":
    main()
