//
//  BackgroundViewCoin.swift
//  NexChat
//
//  Created by Nepomuk Crhonek on 07.01.2024.
//

import SwiftUI
import AVKit
import AVFoundation

struct BackgroundVideoViewCoin: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        return VideoPlayerUIViewCoin(frame: .zero)
    }

    func updateUIView(_ uiView: UIView, context: Context) {
    }
}

class VideoPlayerUIViewCoin: UIView {
    private var playerLayer = AVPlayerLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)

        guard let videoData = NSDataAsset(name: "coinbuy") else {
            debugPrint("coinbuy.mp4 not found in asset catalog")
            return
        }

        // Write the video data to a temporary file
        let tempFilePath = NSTemporaryDirectory() + "coinbuy.mp4"
        let tempFileURL = URL(fileURLWithPath: tempFilePath)
        do {
            try videoData.data.write(to: tempFileURL)
        } catch {
            debugPrint("Failed to write video data to temporary file: \(error)")
            return
        }

        let player = AVPlayer(url: tempFileURL)
        player.isMuted = true
        player.play()

        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
            player.seek(to: CMTime.zero)
            player.play()
        }

        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}