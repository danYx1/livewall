import Foundation
import AVFoundation
import CoreImage
import ImageIO
import UIKit
import Photos
import UniformTypeIdentifiers

// MARK: - Модели

enum FillMode: String, CaseIterable, Identifiable {
    case fill
    case fit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fill: return "Заполнить"
        case .fit: return "Вписать"
        }
    }
}

struct LiveWallResult {
    let photoURL: URL
    let videoURL: URL
    let identifier: String
}

enum LiveWallError: LocalizedError {
    case noVideoTrack
    case invalidRange
    case writerFailed(String)
    case readerFailed(String)
    case imageDecode
    case photoAccess

    var errorDescription: String? {
        switch self {
        case .noVideoTrack:
            return "В выбранном файле нет видеодорожки."
        case .invalidRange:
            return "Не удалось определить подходящий фрагмент видео."
        case .writerFailed(let message):
            return "Ошибка записи: \(message)"
        case .readerFailed(let message):
            return "Ошибка чтения видео: \(message)"
        case .imageDecode:
            return "Не удалось открыть изображение."
        case .photoAccess:
            return "Нет доступа к Фотопленке. Разрешите его в Настройках."
        }
    }
}

// MARK: - Создание Live Photo

final class LivePhotoMaker {

    static let shared = LivePhotoMaker()

    private let context = CIContext(options: nil)

    private init() {}

    // MARK: Видео → Live Photo

    func makeLivePhoto(fromVideo url: URL,
                       start: CMTime,
                       duration: CMTime,
                       targetSize: CGSize,
                       fillMode: FillMode,
                       onProgress: @escaping (Double) -> Void) async throws -> LiveWallResult {

        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])

        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw LiveWallError.noVideoTrack
        }

        let (naturalSize, preferredTransform) = try await track.load(.naturalSize, .preferredTransform)
        let assetDuration = try await asset.load(.duration)

        let safeStart = CMTimeMaximum(.zero, CMTimeMinimum(start, assetDuration))
        let available = CMTimeSubtract(assetDuration, safeStart)
        let total = CMTimeMinimum(duration, available)

        guard total.seconds > 0.05 else { throw LiveWallError.invalidRange }

        let size = LivePhotoMaker.evenSize(targetSize)
        let transform = LivePhotoMaker.videoTransform(
            naturalSize: naturalSize,
            preferredTransform: preferredTransform,
            targetSize: size,
            fillMode: fillMode
        )

        let composition = AVMutableVideoComposition()
        composition.renderSize = size
        composition.frameDuration = CMTime(value: 1, timescale: 30)
        composition.renderScale = 1

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: assetDuration)
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        layerInstruction.setTransform(transform, at: .zero)
        instruction.layerInstructions = [layerInstruction]
        composition.instructions = [instruction]

        let identifier = UUID().uuidString
        let folder = LivePhotoMaker.workFolder()
        let movieURL = folder.appendingPathComponent("LiveWall-\(identifier).mov")
        let photoURL = folder.appendingPathComponent("LiveWall-\(identifier).jpg")

        let writer = try MovieWriter(url: movieURL, size: size, identifier: identifier)

        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = CMTimeRange(start: safeStart, duration: total)

        let output = AVAssetReaderVideoCompositionOutput(
            videoTracks: [track],
            videoSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        )
        output.videoComposition = composition
        output.alwaysCopiesSampleData = false

        guard reader.canAdd(output) else {
            throw LiveWallError.readerFailed("output rejected")
        }
        reader.add(output)

        guard reader.startReading() else {
            throw LiveWallError.readerFailed(reader.error?.localizedDescription ?? "startReading")
        }

        try writer.start()
        writer.appendStillImageTime(at: .zero)

        let still = try await writer.writeSamples(
            from: output,
            reader: reader,
            expectedFrames: max(1, Int(total.seconds * 30)),
            onProgress: onProgress
        )

        try LivePhotoMaker.writeStillImage(still, identifier: identifier, to: photoURL)

        return LiveWallResult(photoURL: photoURL, videoURL: movieURL, identifier: identifier)
    }

    // MARK: Фото → Live Photo (эффект Кена Бёрнса)

    func makeLivePhoto(fromImageData data: Data,
                       targetSize: CGSize,
                       fillMode: FillMode,
                       duration: CMTime,
                       onProgress: @escaping (Double) -> Void) async throws -> LiveWallResult {

        guard let source = CIImage(data: data, options: [.applyOrientationProperty: true]) else {
            throw LiveWallError.imageDecode
        }

        let normalized = source.transformed(
            by: CGAffineTransform(translationX: -source.extent.origin.x, y: -source.extent.origin.y)
        )
        let sourceSize = normalized.extent.size
        guard sourceSize.width > 1, sourceSize.height > 1 else { throw LiveWallError.imageDecode }

        let size = LivePhotoMaker.evenSize(targetSize)
        let scaleX = size.width / sourceSize.width
        let scaleY = size.height / sourceSize.height
        let baseScale = fillMode == .fill ? max(scaleX, scaleY) : min(scaleX, scaleY)

        let identifier = UUID().uuidString
        let folder = LivePhotoMaker.workFolder()
        let movieURL = folder.appendingPathComponent("LiveWall-\(identifier).mov")
        let photoURL = folder.appendingPathComponent("LiveWall-\(identifier).jpg")

        let seconds = max(1.0, min(duration.seconds, 5.0))
        let frameCount = max(2, Int(seconds * 30.0))

        let writer = try MovieWriter(url: movieURL, size: size, identifier: identifier)
        try writer.start()
        writer.appendStillImageTime(at: .zero)

        let still = try await writer.renderFrames(
            count: frameCount,
            image: { progress in
                LivePhotoMaker.kenBurns(
                    base: normalized,
                    size: size,
                    baseScale: baseScale,
                    progress: CGFloat(progress)
                )
            },
            onProgress: onProgress
        )

        try LivePhotoMaker.writeStillImage(still, identifier: identifier, to: photoURL)

        return LiveWallResult(photoURL: photoURL, videoURL: movieURL, identifier: identifier)
    }

    // MARK: - Геометрия

    static func evenSize(_ size: CGSize) -> CGSize {
        func even(_ value: CGFloat) -> CGFloat {
            max(2, (value / 2).rounded(.down) * 2)
        }
        return CGSize(width: even(size.width), height: even(size.height))
    }

    static func videoTransform(naturalSize: CGSize,
                               preferredTransform: CGAffineTransform,
                               targetSize: CGSize,
                               fillMode: FillMode) -> CGAffineTransform {

        let rect = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        let oriented = CGSize(width: abs(rect.width), height: abs(rect.height))

        let normalize = preferredTransform.concatenating(
            CGAffineTransform(translationX: -rect.origin.x, y: -rect.origin.y)
        )

        let scaleX = targetSize.width / max(oriented.width, 1)
        let scaleY = targetSize.height / max(oriented.height, 1)
        let scale = fillMode == .fill ? max(scaleX, scaleY) : min(scaleX, scaleY)

        let dx = (targetSize.width - oriented.width * scale) / 2
        let dy = (targetSize.height - oriented.height * scale) / 2

        return normalize
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: dx, y: dy))
    }

    static func kenBurns(base: CIImage, size: CGSize, baseScale: CGFloat, progress: CGFloat) -> CIImage {
        let zoom = 1.0 + 0.12 * progress
        let scale = baseScale * zoom
        let scaled = base.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let overflowX = max(0, scaled.extent.width - size.width)
        let overflowY = max(0, scaled.extent.height - size.height)

        let dx = (size.width - scaled.extent.width) / 2 + overflowX * 0.15 * (progress - 0.5)
        let dy = (size.height - scaled.extent.height) / 2 + overflowY * 0.15 * (progress - 0.5)

        let moved = scaled.transformed(by: CGAffineTransform(translationX: dx, y: dy))
        let bounds = CGRect(origin: .zero, size: size)
        let background = CIImage(color: CIColor.black).cropped(to: bounds)

        return moved.composited(over: background).cropped(to: bounds)
    }

    // MARK: - Файлы

    static func workFolder() -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LiveWall", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// Записывает JPEG со ссылкой на идентификатор Live Photo (MakerApple 17).
    static func writeStillImage(_ image: CGImage, identifier: String, to url: URL) throws {
        try? FileManager.default.removeItem(at: url)

        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw LiveWallError.writerFailed("jpeg destination")
        }

        var properties: [String: Any] = [:]
        properties[kCGImagePropertyOrientation as String] = 1
        properties[kCGImageDestinationLossyCompressionQuality as String] = 0.95
        properties[kCGImagePropertyMakerAppleDictionary as String] = ["17": identifier]

        CGImageDestinationAddImage(destination, image, properties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw LiveWallError.writerFailed("jpeg finalize")
        }
    }
}

// MARK: - Сохранение в Фотопленку

enum PhotoLibrary {

    static func saveLivePhoto(_ result: LiveWallResult) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw LiveWallError.photoAccess
        }

        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()

            let photoOptions = PHAssetResourceCreationOptions()
            photoOptions.originalFilename = "LiveWall.jpg"
            photoOptions.uniformTypeIdentifier = UTType.jpeg.identifier
            request.addResource(with: .photo, fileURL: result.photoURL, options: photoOptions)

            let videoOptions = PHAssetResourceCreationOptions()
            videoOptions.originalFilename = "LiveWall.mov"
            videoOptions.uniformTypeIdentifier = UTType.quickTimeMovie.identifier
            request.addResource(with: .pairedVideo, fileURL: result.videoURL, options: videoOptions)
        }
    }
}
