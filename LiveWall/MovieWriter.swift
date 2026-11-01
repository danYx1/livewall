import Foundation
import AVFoundation
import CoreImage
import CoreMedia
import CoreVideo

/// Пишет MOV-файл, пригодный для использования в качестве «видео» Live Photo:
/// видео-дорожка H.264 + метаданные `com.apple.quicktime.content.identifier`
/// и тайм-метаданные `com.apple.quicktime.still-image-time`.
final class MovieWriter {

    let writer: AVAssetWriter
    let videoInput: AVAssetWriterInput
    let pixelAdaptor: AVAssetWriterInputPixelBufferAdaptor
    let metaInput: AVAssetWriterInput?
    let metaAdaptor: AVAssetWriterInputMetadataAdaptor?
    let size: CGSize
    let identifier: String
    let frameRate: Int32

    init(url: URL, size: CGSize, identifier: String, frameRate: Int32 = 30) throws {
        self.size = size
        self.identifier = identifier
        self.frameRate = frameRate

        try? FileManager.default.removeItem(at: url)

        do {
            writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        } catch {
            throw LiveWallError.writerFailed(error.localizedDescription)
        }

        let width = max(2, Int(size.width))
        let height = max(2, Int(size.height))

        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: width * height * 3,
                AVVideoMaxKeyFrameIntervalKey: Int(frameRate),
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoAllowFrameReorderingKey: false
            ]
        ]

        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        videoInput.expectsMediaDataInRealTime = false
        videoInput.mediaTimeScale = frameRate

        pixelAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ]
        )

        guard writer.canAdd(videoInput) else {
            throw LiveWallError.writerFailed("video input rejected")
        }
        writer.add(videoInput)

        let meta = MovieWriter.makeMetadataInput()
        if let input = meta?.0, writer.canAdd(input) {
            writer.add(input)
            metaInput = input
            metaAdaptor = meta?.1
        } else {
            metaInput = nil
            metaAdaptor = nil
        }

        let item = AVMutableMetadataItem()
        item.keySpace = AVMetadataKeySpace(rawValue: "mdta")
        item.key = "com.apple.quicktime.content.identifier" as NSString
        item.value = identifier as NSString
        item.dataType = "com.apple.metadata.datatype.UTF-8"
        writer.metadata = [item]
    }

    // MARK: - Lifecycle

    func start() throws {
        guard writer.startWriting() else {
            throw LiveWallError.writerFailed(writer.error?.localizedDescription ?? "startWriting")
        }
        writer.startSession(atSourceTime: .zero)
    }

    /// Отмечает кадр, который Photos должен показывать как статичное изображение.
    func appendStillImageTime(at time: CMTime) {
        guard let metaAdaptor else { return }
        let item = AVMutableMetadataItem()
        item.identifier = AVMetadataIdentifier(rawValue: "com.apple.quicktime.still-image-time")
        item.value = 0 as NSNumber
        item.dataType = kCMMetadataBaseDataType_SInt8 as String
        item.extendedLanguageTag = "und"
        let group = AVTimedMetadataGroup(
            items: [item],
            timeRange: CMTimeRange(start: time, duration: CMTime(value: 1, timescale: frameRate))
        )
        metaAdaptor.append(group)
    }

    // MARK: - Video track (перекодирование готовых сэмплов)

    func writeSamples(from output: AVAssetReaderOutput,
                      reader: AVAssetReader,
                      expectedFrames: Int,
                      onProgress: @escaping (Double) -> Void) async throws -> CGImage {

        let context = CIContext(options: nil)
        var baseTime: CMTime?
        var still: CGImage?
        var frameIndex = 0

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CGImage, Error>) in
            var finished = false
            let queue = DispatchQueue(label: "com.livewall.writer.video", qos: .userInitiated)

            videoInput.requestMediaDataWhenReady(on: queue) { [self] in
                while videoInput.isReadyForMoreMediaData {
                    if finished { return }

                    guard let sample = output.copyNextSampleBuffer() else {
                        finished = true
                        videoInput.markAsFinished()
                        metaInput?.markAsFinished()

                        if reader.status == .failed {
                            writer.cancelWriting()
                            continuation.resume(throwing: LiveWallError.readerFailed(reader.error?.localizedDescription ?? "reader"))
                            return
                        }

                        writer.finishWriting {
                            if writer.status == .completed, let image = still {
                                continuation.resume(returning: image)
                            } else {
                                continuation.resume(throwing: LiveWallError.writerFailed(writer.error?.localizedDescription ?? "finish"))
                            }
                        }
                        return
                    }

                    let pts = CMSampleBufferGetPresentationTimeStamp(sample)
                    if baseTime == nil { baseTime = pts }
                    let offset = baseTime ?? .zero

                    if still == nil, let buffer = CMSampleBufferGetImageBuffer(sample) {
                        let image = CIImage(cvPixelBuffer: buffer)
                        still = context.createCGImage(image, from: image.extent)
                    }

                    guard let retimed = sample.shifted(by: offset) else {
                        finished = true
                        videoInput.markAsFinished()
                        metaInput?.markAsFinished()
                        writer.cancelWriting()
                        continuation.resume(throwing: LiveWallError.writerFailed("retime"))
                        return
                    }

                    guard videoInput.append(retimed) else {
                        finished = true
                        videoInput.markAsFinished()
                        metaInput?.markAsFinished()
                        writer.cancelWriting()
                        continuation.resume(throwing: LiveWallError.writerFailed(writer.error?.localizedDescription ?? "append"))
                        return
                    }

                    frameIndex += 1
                    if expectedFrames > 0 {
                        onProgress(min(1, Double(frameIndex) / Double(expectedFrames)))
                    }
                }
            }
        }
    }

    // MARK: - Video track (кадры, нарисованные вручную)

    func renderFrames(count: Int,
                      image: @escaping (Double) -> CIImage,
                      onProgress: @escaping (Double) -> Void) async throws -> CGImage {

        let context = CIContext(options: nil)
        var index = 0
        var still: CGImage?

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CGImage, Error>) in
            var finished = false
            let queue = DispatchQueue(label: "com.livewall.writer.frames", qos: .userInitiated)

            videoInput.requestMediaDataWhenReady(on: queue) { [self] in
                while videoInput.isReadyForMoreMediaData {
                    if finished { return }

                    if index >= count {
                        finished = true
                        videoInput.markAsFinished()
                        metaInput?.markAsFinished()
                        writer.finishWriting {
                            if writer.status == .completed, let image = still {
                                continuation.resume(returning: image)
                            } else {
                                continuation.resume(throwing: LiveWallError.writerFailed(writer.error?.localizedDescription ?? "finish"))
                            }
                        }
                        return
                    }

                    guard let pool = pixelAdaptor.pixelBufferPool else {
                        finished = true
                        writer.cancelWriting()
                        continuation.resume(throwing: LiveWallError.writerFailed("pixel buffer pool"))
                        return
                    }

                    var buffer: CVPixelBuffer?
                    let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buffer)
                    guard status == kCVReturnSuccess, let pixelBuffer = buffer else {
                        finished = true
                        writer.cancelWriting()
                        continuation.resume(throwing: LiveWallError.writerFailed("pixel buffer"))
                        return
                    }

                    let progress = count <= 1 ? 0 : Double(index) / Double(count - 1)
                    let frameImage = image(progress)
                    let bounds = CGRect(origin: .zero, size: size)

                    context.render(frameImage, to: pixelBuffer, bounds: bounds, colorSpace: CGColorSpaceCreateDeviceRGB())

                    if still == nil {
                        still = context.createCGImage(frameImage, from: bounds)
                    }

                    let pts = CMTime(value: CMTimeValue(index), timescale: frameRate)
                    guard pixelAdaptor.append(pixelBuffer, withPresentationTime: pts) else {
                        finished = true
                        videoInput.markAsFinished()
                        metaInput?.markAsFinished()
                        writer.cancelWriting()
                        continuation.resume(throwing: LiveWallError.writerFailed(writer.error?.localizedDescription ?? "append frame"))
                        return
                    }

                    index += 1
                    onProgress(min(1, Double(index) / Double(max(count, 1))))
                }
            }
        }
    }

    // MARK: - Metadata format

    private static func makeMetadataInput() -> (AVAssetWriterInput, AVAssetWriterInputMetadataAdaptor)? {
        let specification: [String: Any] = [
            kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier as String: "com.apple.quicktime.still-image-time",
            kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType as String: "com.apple.metadata.datatype.int8"
        ]

        var formatDescription: CMFormatDescription?
        // 'mebx' — тип метаданных QuickTime.
        let status = CMMetadataFormatDescriptionCreateWithMetadataSpecifications(
            allocator: kCFAllocatorDefault,
            metadataType: 0x6D656278,
            metadataSpecifications: [specification] as CFArray,
            formatDescriptionOut: &formatDescription
        )

        guard status == noErr, let description = formatDescription else { return nil }

        let input = AVAssetWriterInput(mediaType: .metadata, outputSettings: nil, sourceFormatHint: description)
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputMetadataAdaptor(assetWriterInput: input)
        return (input, adaptor)
    }
}

extension CMSampleBuffer {
    /// Сдвигает тайминги сэмпла так, чтобы дорожка начиналась с нуля.
    func shifted(by offset: CMTime) -> CMSampleBuffer? {
        let pts = CMSampleBufferGetPresentationTimeStamp(self)
        let dts = CMSampleBufferGetDecodeTimeStamp(self)

        var timing = CMSampleTimingInfo(
            duration: CMSampleBufferGetDuration(self),
            presentationTimeStamp: CMTimeSubtract(pts, offset),
            decodeTimeStamp: dts.isValid ? CMTimeSubtract(dts, offset) : .invalid
        )

        var newBuffer: CMSampleBuffer?
        let status = CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault,
            sampleBuffer: self,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleBufferOut: &newBuffer
        )

        guard status == noErr else { return nil }
        return newBuffer
    }
}
