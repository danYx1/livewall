import SwiftUI
import PhotosUI
import AVFoundation
import Photos
import UIKit

final class StudioModel: ObservableObject {

    enum Media {
        case none
        case video(url: URL, duration: Double)
        case photo(data: Data)
    }

    enum Status {
        case success
        case failure(String)
    }

    @Published private(set) var media: Media = .none
    @Published var start: Double = 0
    @Published var clipLength: Double = 3
    @Published var fillMode: FillMode = .fill
    @Published var isWorking = false
    @Published var progress: Double = 0
    @Published var status: Status?
    @Published var showGuide = false

    var hasMedia: Bool {
        if case .none = media { return false }
        return true
    }

    var videoDuration: Double {
        if case .video(_, let duration) = media { return duration }
        return 0
    }

    var maxClipLength: Double {
        if case .video(_, let duration) = media {
            return max(1, min(5, duration))
        }
        return 5
    }

    var effectiveStart: Double {
        guard case .video(_, let duration) = media else { return 0 }
        return max(0, min(start, max(0, duration - 0.2)))
    }

    var effectiveLength: Double {
        if case .video(_, let duration) = media {
            return max(0.2, min(clipLength, max(0.2, duration - effectiveStart)))
        }
        return max(1, min(clipLength, 5))
    }

    // MARK: - Загрузка

    @MainActor
    func loadVideo(_ item: PhotosPickerItem) async {
        status = nil
        do {
            guard let picked = try await item.loadTransferable(type: PickedVideo.self) else {
                throw LiveWallError.invalidRange
            }

            let asset: AVAsset = AVURLAsset(url: picked.url)
            let time = try await asset.load(.duration)
            let duration = time.seconds
      
            let duration = try await asset.load(.duration).seconds
            guard duration > 0.2 else { throw LiveWallError.invalidRange }

            media = .video(url: picked.url, duration: duration)
            start = 0
            clipLength = min(3.0, max(1.0, duration))
        } catch {
            status = .failure(error.localizedDescription)
        }
    }

    @MainActor
    func loadImage(_ item: PhotosPickerItem) async {
        status = nil
        do {
            guard let picked = try await item.loadTransferable(type: PickedImage.self),
                  UIImage(data: picked.data) != nil else {
                throw LiveWallError.imageDecode
            }

            media = .photo(data: picked.data)
            clipLength = 3
        } catch {
            status = .failure(error.localizedDescription)
        }
    }

    // MARK: - Экспорт

    @MainActor
    func export() async {
        guard !isWorking, hasMedia else { return }

        isWorking = true
        progress = 0
        status = nil

        defer { isWorking = false }

        let size = StudioModel.targetSize

        do {
            let result: LiveWallResult

            switch media {
            case .video(let url, _):
                result = try await LivePhotoMaker.shared.makeLivePhoto(
                    fromVideo: url,
                    start: CMTime(seconds: effectiveStart, preferredTimescale: 600),
                    duration: CMTime(seconds: effectiveLength, preferredTimescale: 600),
                    targetSize: size,
                    fillMode: fillMode,
                    onProgress: { [weak self] value in
                        Task { @MainActor in self?.progress = value }
                    }
                )

            case .photo(let data):
                result = try await LivePhotoMaker.shared.makeLivePhoto(
                    fromImageData: data,
                    targetSize: size,
                    fillMode: fillMode,
                    duration: CMTime(seconds: effectiveLength, preferredTimescale: 600),
                    onProgress: { [weak self] value in
                        Task { @MainActor in self?.progress = value }
                    }
                )

            case .none:
                return
            }

            try await PhotoLibrary.saveLivePhoto(result)
            progress = 1
            status = .success
        } catch {
            status = .failure(error.localizedDescription)
        }
    }

    // MARK: - Размер кадра

    @MainActor
    static var targetSize: CGSize {
        let screen: CGRect
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first {
            screen = scene.screen.bounds
        } else {
            screen = CGRect(x: 0, y: 0, width: 390, height: 844)
        }

        let scale = UIScreen.main.scale
        var width = screen.width * scale
        var height = screen.height * scale

        let limit: CGFloat = 1920
        let longest = max(width, height)
        if longest > limit {
            let ratio = limit / longest
            width *= ratio
            height *= ratio
        }

        return CGSize(
            width: max(2, (width / 2).rounded() * 2),
            height: max(2, (height / 2).rounded() * 2)
        )
    }
}
