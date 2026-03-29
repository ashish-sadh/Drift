import SwiftUI
import AVFoundation

/// Camera-based barcode scanner using AVFoundation.
struct BarcodeScannerView: UIViewControllerRepresentable {
    let onBarcodeFound: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.onBarcodeFound = { barcode in
            onBarcodeFound(barcode)
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    class ScannerViewController: UIViewController, @preconcurrency AVCaptureMetadataOutputObjectsDelegate {
        var onBarcodeFound: ((String) -> Void)?
        private var captureSession: AVCaptureSession?
        private var previewLayer: AVCaptureVideoPreviewLayer?
        private var hasFoundBarcode = false

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            setupCamera()
        }

        private func setupCamera() {
            let session = AVCaptureSession()

            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else {
                showError("Camera not available")
                return
            }

            session.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else {
                showError("Cannot process barcodes")
                return
            }

            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.ean13, .ean8, .upce, .code128, .code39, .code93, .interleaved2of5]

            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.videoGravity = .resizeAspectFill
            preview.frame = view.bounds
            view.layer.addSublayer(preview)
            previewLayer = preview

            // Add scan area overlay
            addOverlay()

            captureSession = session
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
        }

        private func addOverlay() {
            // Semi-transparent overlay with clear center
            let overlay = UIView(frame: view.bounds)
            overlay.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            overlay.isUserInteractionEnabled = false
            view.addSubview(overlay)

            let scanArea = CGRect(
                x: view.bounds.width * 0.1,
                y: view.bounds.height * 0.3,
                width: view.bounds.width * 0.8,
                height: view.bounds.height * 0.15
            )

            let path = UIBezierPath(rect: overlay.bounds)
            path.append(UIBezierPath(roundedRect: scanArea, cornerRadius: 12).reversing())

            let mask = CAShapeLayer()
            mask.path = path.cgPath
            overlay.layer.mask = mask

            // Scan area border
            let border = CAShapeLayer()
            border.path = UIBezierPath(roundedRect: scanArea, cornerRadius: 12).cgPath
            border.strokeColor = UIColor(white: 1, alpha: 0.6).cgColor
            border.fillColor = UIColor.clear.cgColor
            border.lineWidth = 2
            view.layer.addSublayer(border)

            // Label
            let label = UILabel()
            label.text = "Point camera at barcode"
            label.textColor = .white
            label.font = .systemFont(ofSize: 14, weight: .medium)
            label.textAlignment = .center
            label.frame = CGRect(x: 0, y: scanArea.maxY + 16, width: view.bounds.width, height: 20)
            view.addSubview(label)
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            previewLayer?.frame = view.bounds
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            captureSession?.stopRunning()
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            guard !hasFoundBarcode,
                  let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let barcode = object.stringValue else { return }

            hasFoundBarcode = true
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            captureSession?.stopRunning()

            Log.foodLog.info("Scanned barcode: \(barcode)")
            onBarcodeFound?(barcode)
        }

        private func showError(_ msg: String) {
            let label = UILabel()
            label.text = msg
            label.textColor = .white
            label.textAlignment = .center
            label.frame = view.bounds
            view.addSubview(label)
        }
    }
}

/// Combined view: scanner + lookup + log
struct BarcodeLookupView: View {
    @Bindable var viewModel: FoodLogViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var scannedBarcode: String?
    @State private var product: OpenFoodFactsService.Product?
    @State private var isLooking = false
    @State private var error: String?
    @State private var servings: Double = 1.0
    @State private var selectedMealType: MealType = .lunch

    var body: some View {
        NavigationStack {
            ZStack {
                if product == nil && !isLooking {
                    BarcodeScannerView { barcode in
                        scannedBarcode = barcode
                        lookupBarcode(barcode)
                    }
                    .ignoresSafeArea()
                } else if isLooking {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Looking up barcode...")
                            .font(.subheadline).foregroundStyle(.secondary)
                        if let barcode = scannedBarcode {
                            Text(barcode).font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
                        }
                    }
                } else if let product {
                    productView(product)
                }

                if let error {
                    VStack(spacing: 12) {
                        Image(systemName: "barcode.viewfinder")
                            .font(.system(size: 40)).foregroundStyle(Theme.surplus)
                        Text(error).font(.subheadline).foregroundStyle(.secondary)
                        Button("Scan Again") {
                            self.error = nil
                            self.product = nil
                            self.scannedBarcode = nil
                        }
                        .buttonStyle(.borderedProminent).tint(Theme.accent)
                    }
                }
            }
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func productView(_ p: OpenFoodFactsService.Product) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                // Product info
                VStack(alignment: .leading, spacing: 4) {
                    Text(p.name).font(.headline)
                    if let brand = p.brand {
                        Text(brand).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text("Per 100g").font(.caption).foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()

                // Macros
                HStack(spacing: 8) {
                    macroPill("\(Int(p.calories))", label: "cal", color: Theme.calorieBlue)
                    macroPill("\(Int(p.proteinG))g", label: "P", color: Theme.proteinRed)
                    macroPill("\(Int(p.carbsG))g", label: "C", color: Theme.carbsGreen)
                    macroPill("\(Int(p.fatG))g", label: "F", color: Theme.fatYellow)
                    macroPill("\(Int(p.fiberG))g", label: "Fiber", color: Theme.fiberBrown)
                }

                // Serving + meal
                VStack(spacing: 10) {
                    HStack {
                        Text("Servings (100g each)")
                        Spacer()
                        TextField("1", value: $servings, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Stepper("", value: $servings, in: 0.25...10, step: 0.25)
                            .frame(width: 100)
                    }

                    if let servingG = p.servingSizeG {
                        Button("Use serving size (\(Int(servingG))g)") {
                            servings = servingG / 100.0
                        }
                        .font(.caption).foregroundStyle(Theme.accent)
                    }

                    Picker("Meal", selection: $selectedMealType) {
                        ForEach(MealType.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                .card()

                // Total
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total").font(.caption).foregroundStyle(.secondary)
                    Text("\(Int(p.calories * servings)) cal · \(Int(p.proteinG * servings))P \(Int(p.carbsG * servings))C \(Int(p.fatG * servings))F")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()

                Button {
                    logProduct(p)
                } label: {
                    Label("Log Food", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).tint(Theme.accent)

                Button("Scan Another") {
                    product = nil
                    scannedBarcode = nil
                    error = nil
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 24)
        }
        .background(Theme.background)
    }

    private func macroPill(_ value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.caption.weight(.bold).monospacedDigit())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
    }

    private func lookupBarcode(_ barcode: String) {
        isLooking = true
        error = nil
        Task {
            do {
                product = try await OpenFoodFactsService.lookup(barcode: barcode)
                isLooking = false
            } catch {
                self.error = error.localizedDescription
                isLooking = false
            }
        }
    }

    private func logProduct(_ p: OpenFoodFactsService.Product) {
        let food = Food(
            name: [p.name, p.brand].compactMap { $0 }.joined(separator: " - "),
            category: "Scanned",
            servingSize: 100,
            servingUnit: "g",
            calories: p.calories,
            proteinG: p.proteinG,
            carbsG: p.carbsG,
            fatG: p.fatG,
            fiberG: p.fiberG
        )
        viewModel.logFood(food, servings: servings, mealType: selectedMealType)
        dismiss()
    }
}
