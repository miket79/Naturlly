import SwiftUI
import QuickLookThumbnailing

#if os(macOS)
import AppKit
private typealias CrossPlatformImage = NSImage
#elseif canImport(UIKit)
import UIKit
private typealias CrossPlatformImage = UIImage
#endif

// Renders a visual cover/thumbnail for a Document
// Attempts to generate a system thumbnail; falls back to a gradient + icon
struct DocumentCoverView: View {
    let document: Document
    var size: CGSize

    @State private var image: CrossPlatformImage?
    @State private var isGenerating = false

    var body: some View {
        ZStack {
            if let img = image {
                Image(platformImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else {
                placeholder
                    .frame(width: size.width, height: size.height)
            }
        }
        .onAppear(perform: generateThumbnailIfNeeded)
        .onChange(of: document.fileURL) { _, _ in
            image = nil
            generateThumbnailIfNeeded()
        }
        .accessibilityLabel(Text(String(format: String(localized: "cover.accessibility"), document.name)))
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.35), Color.purple.opacity(0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 8) {
                Image(systemName: document.type.icon)
                    .font(.system(size: 36))
                    .foregroundColor(.white.opacity(0.9))
                Text(document.name)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 8)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func generateThumbnailIfNeeded() {
        guard !isGenerating, image == nil else { return }
        isGenerating = true

        // Ensure the file still exists before attempting to generate a thumbnail
        let filePath = document.fileURL.path
        guard FileManager.default.fileExists(atPath: filePath) else {
            #if DEBUG
            print("DocumentCoverView: file does not exist at path: \(filePath)")
            #endif
            isGenerating = false
            return
        }

        #if canImport(QuickLookThumbnailing)
        let scale: CGFloat = {
            #if os(macOS)
            return NSScreen.main?.backingScaleFactor ?? 2.0
            #else
            return UIScreen.main.scale
            #endif
        }()

        let request = QLThumbnailGenerator.Request(
            fileAt: document.fileURL,
            size: size,
            scale: scale,
            representationTypes: .all
        )

        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { rep, _ in
            DispatchQueue.main.async {
                self.isGenerating = false
                #if os(macOS)
                if let img = rep?.nsImage { self.image = img; return }
                #else
                if let img = rep?.uiImage { self.image = img; return }
                #endif
                #if DEBUG
                print("DocumentCoverView: thumbnail generation failed for URL: \(document.fileURL.path)")
                #endif
            }
        }
        #else
        isGenerating = false
        #endif
    }
}

private extension Image {
    init(platformImage: CrossPlatformImage) {
        #if os(macOS)
        self.init(nsImage: platformImage)
        #else
        self.init(uiImage: platformImage)
        #endif
    }
}
