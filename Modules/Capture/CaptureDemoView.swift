//
//  CaptureDemoView.swift
//
//  PRO feature demo — pick a photo or scan a document, then run on-device OCR.
//  The "Pick a photo" path works on the Simulator; "Scan" needs a real device.
//

import SwiftUI
import PhotosUI

struct CaptureDemoView: View {
    @State private var image: UIImage?
    @State private var recognizedText = ""
    @State private var isRecognizing = false
    @State private var showScanner = false
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                preview

                HStack(spacing: DS.Spacing.md) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        actionLabel("Pick a photo", "photo.on.rectangle")
                    }
                    Button { showScanner = true } label: {
                        actionLabel("Scan document", "doc.viewfinder")
                    }
                    .buttonStyle(.plain)
                }

                if isRecognizing {
                    ProgressView("Recognizing text…")
                        .frame(maxWidth: .infinity)
                        .padding(DS.Spacing.lg)
                } else if !recognizedText.isEmpty {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Label("Recognized text", systemImage: "text.viewfinder").appFont(.headline)
                        Text(recognizedText)
                            .appFont(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(DS.Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
            }
            .padding(DS.Spacing.lg)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(Text("Camera & OCR"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showScanner) {
            DocumentScannerView(
                onComplete: { pages in
                    showScanner = false
                    if let first = pages.first { setImage(first) }
                },
                onCancel: { showScanner = false }
            )
            .ignoresSafeArea()
        }
        .onChange(of: photoItem) { newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let ui = UIImage(data: data) {
                    setImage(ui)
                }
            }
        }
    }

    private var preview: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .frame(height: 200)
                    .overlay(
                        VStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "doc.text.viewfinder")
                                .font(.system(size: 40))
                                .foregroundColor(DS.accent)
                            Text("Pick a photo or scan a document to extract its text")
                                .appFont(.footnote)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(DS.Spacing.lg)
                    )
            }
        }
    }

    private func actionLabel(_ title: String, _ icon: String) -> some View {
        Label(title, systemImage: icon)
            .appFont(.subheadline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
    }

    private func setImage(_ ui: UIImage) {
        image = ui
        recognizedText = ""
        isRecognizing = true
        Task {
            let text = await TextRecognizer.recognize(in: ui)
            await MainActor.run {
                recognizedText = text.isEmpty ? "No text found in this image." : text
                isRecognizing = false
            }
        }
    }
}

#Preview {
    NavigationStack { CaptureDemoView() }
}
