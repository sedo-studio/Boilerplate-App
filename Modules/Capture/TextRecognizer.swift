//
//  TextRecognizer.swift
//
//  PRO feature — on-device OCR via the Vision framework (no network, free).
//  Self-contained: delete `Modules/Capture` + flip `featureFlags.camera` off.
//

import Foundation
import Vision
#if canImport(UIKit)
import UIKit
#endif

enum TextRecognizer {
    /// Recognize text in an image entirely on-device. Returns the joined lines.
    static func recognize(in image: UIImage) async -> String {
        guard let cgImage = image.cgImage else { return "" }
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let lines = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string } ?? []
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: "")
                }
            }
        }
    }
}
