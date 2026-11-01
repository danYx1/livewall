import Foundation
import CoreTransferable
import UniformTypeIdentifiers

/// Видео, выбранное через PhotosPicker (копируется во временную папку).
struct PickedVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let fileExtension = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent("picked-\(UUID().uuidString)")
                .appendingPathExtension(fileExtension)

            try? FileManager.default.removeItem(at: copy)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return PickedVideo(url: copy)
        }
    }
}

/// Изображение, выбранное через PhotosPicker.
struct PickedImage: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            PickedImage(data: data)
        }
    }
}
