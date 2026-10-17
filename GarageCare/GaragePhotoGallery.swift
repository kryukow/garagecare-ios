import PhotosUI
import SwiftUI
import UIKit

/// First image remains in the legacy field so older records survive an upgrade.
/// Only additional JPEGs are encoded into the new optional field.
enum GaragePhotoArchive {
    static func images(primary: Data?, additional: Data?) -> [Data] {
        var result: [Data] = []
        if let primary { result.append(primary) }
        if let additional, let extra = try? JSONDecoder().decode([Data].self, from: additional) {
            result.append(contentsOf: extra)
        }
        return result
    }

    static func store(_ images: [Data], primary: inout Data?, additional: inout Data?) {
        primary = images.first
        let extra = Array(images.dropFirst())
        additional = extra.isEmpty ? nil : try? JSONEncoder().encode(extra)
    }

    @MainActor
    static func normalized(_ item: PhotosPickerItem) async throws -> Data {
        guard let raw = try await item.loadTransferable(type: Data.self),
              let image = UIImage(data: raw) else {
            throw PhotoError.invalidImage
        }
        let ratio = min(1, 2048 / max(image.size.width, image.size.height))
        let size = CGSize(width: max(1, image.size.width * ratio), height: max(1, image.size.height * ratio))
        let rendererFormat = UIGraphicsImageRendererFormat()
        rendererFormat.scale = 1
        let rendered = UIGraphicsImageRenderer(size: size, format: rendererFormat).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let jpeg = rendered.jpegData(compressionQuality: 0.82) else {
            throw PhotoError.invalidImage
        }
        return jpeg
    }

    enum PhotoError: LocalizedError {
        case invalidImage
        var errorDescription: String? { "Не удалось обработать выбранное фото." }
    }
}

struct GaragePhotoViewer: View {
    @Environment(\.dismiss) private var dismiss
    let images: [Data]
    @Binding var selectedIndex: Int

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            TabView(selection: $selectedIndex) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, data in
                    if let image = UIImage(data: data) {
                        GarageZoomablePhoto(image: image)
                            .tag(index)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .automatic : .never))
            VStack(alignment: .trailing, spacing: 16) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.headline.bold())
                        .padding(13)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Закрыть фото")
                Text("\(min(selectedIndex + 1, images.count)) / \(images.count)")
                    .font(.caption.monospacedDigit())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .foregroundStyle(.white)
            .padding(20)
        }
    }
}


private struct GarageZoomablePhoto: UIViewRepresentable {
    let image: UIImage

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .black
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5
        scrollView.bouncesZoom = true
        scrollView.delegate = context.coordinator
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])
        context.coordinator.imageView = imageView

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.toggleZoom(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        if context.coordinator.imageView?.image !== image {
            context.coordinator.imageView?.image = image
            scrollView.setZoomScale(1, animated: false)
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        @objc func toggleZoom(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = gesture.view as? UIScrollView else { return }
            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                let point = gesture.location(in: imageView)
                let width = scrollView.bounds.width / 2.5
                let height = scrollView.bounds.height / 2.5
                scrollView.zoom(to: CGRect(x: point.x - width / 2, y: point.y - height / 2, width: width, height: height), animated: true)
            }
        }
    }
}

/// A reusable tappable gallery for saved images in history, tasks and vehicles.
struct GaragePhotoStrip: View {
    let title: String
    let primary: Data?
    let additional: Data?
    var height: CGFloat = 118

    @State private var selectedIndex = 0
    @State private var showingViewer = false

    private var images: [Data] {
        GaragePhotoArchive.images(primary: primary, additional: additional)
    }

    var body: some View {
        if !images.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(Array(images.enumerated()), id: \.offset) { index, data in
                            if let image = UIImage(data: data) {
                                Button {
                                    selectedIndex = index
                                    showingViewer = true
                                } label: {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: height, height: height)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Открыть фото \(index + 1) из \(images.count)")
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }
            .fullScreenCover(isPresented: $showingViewer) {
                GaragePhotoViewer(images: images, selectedIndex: $selectedIndex)
            }
        }
    }
}
