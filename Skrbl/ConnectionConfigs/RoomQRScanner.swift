//
//  RoomQRScanner.swift
//  Sketra
//
//  Created by Codex on 30/07/2026.
//

import SwiftUI
import UIKit
import Vision
import VisionKit

struct RoomQRScanner: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCode: onCode)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        guard DataScannerViewController.isSupported,
              DataScannerViewController.isAvailable else {
            return ScannerUnavailableViewController()
        }

        let scanner = DataScannerViewController(
            recognizedDataTypes: [
                .barcode(symbologies: [.qr])
            ],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(
        _ viewController: UIViewController,
        context: Context
    ) {
        guard let scanner = viewController as? DataScannerViewController,
              !scanner.isScanning else {
            return
        }

        try? scanner.startScanning()
    }

    static func dismantleUIViewController(
        _ viewController: UIViewController,
        coordinator: Coordinator
    ) {
        (viewController as? DataScannerViewController)?.stopScanning()
    }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onCode: (String) -> Void
        private var hasDeliveredCode = false

        init(onCode: @escaping (String) -> Void) {
            self.onCode = onCode
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard !hasDeliveredCode else { return }

            for item in addedItems {
                guard case .barcode(let barcode) = item,
                      let payload = barcode.payloadStringValue else {
                    continue
                }

                hasDeliveredCode = true
                dataScanner.stopScanning()
                onCode(payload)
                return
            }
        }
    }
}

private final class ScannerUnavailableViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor(
            red: 9.0 / 255.0,
            green: 53.0 / 255.0,
            blue: 11.0 / 255.0,
            alpha: 1
        )

        let imageView = UIImageView(
            image: UIImage(systemName: "camera.fill")
        )
        imageView.tintColor = .white
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            pointSize: 44
        )

        let label = UILabel()
        label.text = "Camera scanning is unavailable.\nCheck Camera access in Settings."
        label.textAlignment = .center
        label.textColor = .white
        label.font = UIFont(name: "Chalkduster", size: 16)
            ?? .systemFont(ofSize: 16)
        label.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [imageView, label])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(
                greaterThanOrEqualTo: view.leadingAnchor,
                constant: 24
            ),
            stack.trailingAnchor.constraint(
                lessThanOrEqualTo: view.trailingAnchor,
                constant: -24
            )
        ])
    }
}
