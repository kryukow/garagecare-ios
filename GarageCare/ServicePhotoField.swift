import PhotosUI
import SwiftUI
import UIKit

/// The same picker is used for a service photo and for a separate receipt.
struct ServicePhotoField: View {
    let title: String
    @Binding var data: Data?
    @Binding var isLoading: Bool
    @State private var selection: PhotosPickerItem?
    @State private var errorMessage: String?

    var body: some View {
        Section(title) {
            PhotosPicker(selection: $selection, matching: .images) {
                Label(data == nil ? "Прикрепить фото" : "Заменить фото", systemImage: "photo.on.rectangle")
            }
            if isLoading { ProgressView("Загрузка фото…") }
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable().scaledToFit().frame(maxHeight: 220)
                    .accessibilityLabel(title)
                Button("Удалить фото", role: .destructive) {
                    selection = nil
                    self.data = nil
                }
            }
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
        }
        .task(id: selection) {
            guard let selection else { isLoading = false; return }
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }
            do {
                guard let bytes = try await selection.loadTransferable(type: Data.self),
                      let image = UIImage(data: bytes) else {
                    errorMessage = "Не удалось открыть фото. Выбери другое изображение."
                    return
                }
                try Task.checkCancellation()
                // Bound storage and JSON backup size; also normalize HEIC and orientation.
                let ratio = min(1, 2048 / max(image.size.width, image.size.height))
                let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
                let format = UIGraphicsImageRendererFormat()
                format.scale = 1
                let normalized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                    image.draw(in: CGRect(origin: .zero, size: size))
                }
                guard let jpeg = normalized.jpegData(compressionQuality: 0.85) else {
                    errorMessage = "Не удалось обработать фото."
                    return
                }
                data = jpeg
            } catch is CancellationError {
                // A newly selected image supersedes the previous request.
            } catch {
                errorMessage = "Не удалось загрузить фото: \(error.localizedDescription)"
            }
        }
    }
}
