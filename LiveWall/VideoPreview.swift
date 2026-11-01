import SwiftUI
import AVFoundation
import UIKit

struct VideoPreview: UIViewRepresentable {
    let url: URL
    let start: Double
    let duration: Double

    func makeUIView(context: Context) -> LoopingPlayerView {
        LoopingPlayerView()
    }

    func updateUIView(_ view: LoopingPlayerView, context: Context) {
        view.configure(url: url, start: start, duration: duration)
    }
}

final class LoopingPlayerView: UIView {

    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    private var player: AVPlayer?
    private var currentURL: URL?
    private var startTime: Double = 0
    private var endTime: Double = 3
    private var timeObserver: Any?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        playerLayer.videoGravity = .resizeAspectFill
        clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
    }

    func configure(url: URL, start: Double, duration: Double) {
        let clampedStart = max(0, start)
        startTime = clampedStart
        endTime = clampedStart + max(0.1, duration)

        if currentURL != url {
            currentURL = url
            teardown()

            let item = AVPlayerItem(url: url)
            let player = AVPlayer(playerItem: item)
            player.isMuted = true
            player.actionAtItemEnd = .none
            self.player = player
            playerLayer.player = player

            timeObserver = player.addPeriodicTimeObserver(
                forInterval: CMTime(value: 1, timescale: 20),
                queue: .main
            ) { [weak self] time in
                guard let self, let player = self.player else { return }
                let seconds = time.seconds
                if seconds >= self.endTime || seconds < self.startTime - 0.1 {
                    player.seek(
                        to: CMTime(seconds: self.startTime, preferredTimescale: 600),
                        toleranceBefore: .zero,
                        toleranceAfter: .zero
                    )
                }
            }

            player.seek(
                to: CMTime(seconds: clampedStart, preferredTimescale: 600),
                toleranceBefore: .zero,
                toleranceAfter: .zero
            )
            player.play()
        } else if let player {
            let current = player.currentItem?.currentTime().seconds ?? 0
            if current < startTime - 0.05 || current > endTime + 0.05 {
                player.seek(
                    to: CMTime(seconds: startTime, preferredTimescale: 600),
                    toleranceBefore: .zero,
                    toleranceAfter: .zero
                )
            }
        }
    }

    private func teardown() {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        player?.pause()
        player = nil
        playerLayer.player = nil
    }
}
