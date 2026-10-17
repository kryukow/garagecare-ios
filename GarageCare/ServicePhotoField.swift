import PhotosUI
import SwiftUI
import UIKit

/// Adds several images while retaining the original first image in the legacy
/// SwiftData field. The extra photos are stored separately for safe migration.
struct ServicePhotoField: View {
    let title: String
    @Binding var data: Data?
    @Binding var additionalData: Data?
    @Binding var isLoading: Bool

    @State private var selection: [PhotosPickerItem] = []
    @State private var selectedIndex = 0
    @State private var showingViewer = false
    @State private var errorMessage: String?

    private var images: [Data] {
        GaragePhotoArchive.images(primary: data, additional: additionalData)
    }

    var body: some View {
        Section(title) {
            PhotosPicker(selection: $selection, maxSelectionCount: 10, matching: .images) {
                Label("Добавить фотографии", systemImage: "photo.badge.plus")
            }
            .disabled(isLoading || images.count >= 30)

            if isLoading { ProgressView("Подготовка фотографий…") }

            if !images.isEmpty {
                Text("\(images.count) фото · нажми для просмотра")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(Array(images.enumerated()), id: \.offset) { index, bytes in
                            if let image = UIImage(data: bytes) {
                                ZStack(alignment: .topTrailing) {
                                    Button {
                                        selectedIndex = index
                                        showingViewer = true
                                    } label: {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 120, height: 105)
                                            .clipped()
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Открыть фото \(index + 1)")

                                    Button(role: .destructive) {
                                        var updated = images
                                        updated.remove(at: index)
                                        var primary = data
                                        var extras = additionalData
                                        GaragePhotoArchive.store(updated, primary: &primary, additional: &extras)
                                        data = primary
                                        additionalData = extras
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title3)
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(.white, Color.black.opacity(0.6))
                                            .padding(4)
                                    }
                                    .accessibilityLabel("Удалить фото \(index + 1)")
                                }
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.red)
            }
        }
        .onChange(of: selection.count) { _, count in
            guard count > 0 else { return }
            let picked = selection
            Task { await addPhotos(picked) }
        }
        .fullScreenCover(isPresented: $showingViewer) {
            GaragePhotoViewer(images: images, selectedIndex: $selectedIndex)
        }
    }

    @MainActor
    private func addPhotos(_ items: [PhotosPickerItem]) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            selection = []
        }

        var updated = images
        for item in items {
            if updated.count >= 30 {
                errorMessage = "Можно хранить до 30 фотографий в одном разделе."
                break
            }
            do {
                let jpeg = try await GaragePhotoArchive.normalized(item)
                updated.append(jpeg)
            } catch {
                errorMessage = "Часть фотографий не загрузилась: \(error.localizedDescription)"
            }
        }
        var primary = data
        var extras = additionalData
        GaragePhotoArchive.store(updated, primary: &primary, additional: &extras)
        data = primary
        additionalData = extras
    }
}
