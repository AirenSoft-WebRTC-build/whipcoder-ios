//
//  VideoRenderView.swift
//  WHIPCoder
//
//  Created by dimiden on 5/28/24.
//

import WebRTC

// VideoRenderView is a custom UIView that is used to render video frames from RTCVideoTrack:
//
// - When calling setSize() from RTCFileVideoCapturer, it is called on a Thread other than MainThread, so it is improved to call it on MainThread
// - RTCMTLVideoView does not set UIViewContentModeScaleAspectFit mode, so it is improved to maintain the aspect ratio
class VideoRenderView: UIView, RTCVideoRenderer {
    private let logger: Logger = .init(VideoRenderView.self)
    private let renderer: RTCMTLVideoView?
    private var contentSize: CGSize = CGSizeZero

    override init(frame: CGRect) {
        renderer = .init(frame: CGRectZero)

        super.init(frame: frame)

        if renderer != nil {
            addSubview(renderer!)
        }
    }

    required init?(coder: NSCoder) {
        renderer = .init(coder: coder)

        super.init(coder: coder)

        if renderer != nil {
            addSubview(renderer!)
        }
    }

    override var bounds: CGRect { didSet { updateSize() } }

    private func updateSize() {
        guard let renderer = renderer else { return }

        let frame = bounds
        let aspectRatio = (contentSize.height != 0) ? contentSize.width / contentSize.height : 1
        let size = CGSize(width: min(frame.width, frame.height * aspectRatio),
                          height: min(frame.height, frame.width / aspectRatio))

        // Place the render view to center
        let x = (frame.width - size.width) / 2
        let y = (frame.height - size.height) / 2

        renderer.frame = CGRect(x: x, y: y, width: size.width, height: size.height)
    }

    // Called when the size of the video is changed
    func setSize(_ size: CGSize) {
        // Assume that the size is changed on the MainThread
        if Thread.isMainThread {
            contentSize = size
            renderer?.setSize(size)

            updateSize()
            return
        }

        DispatchQueue.main.async { self.setSize(size) }
    }

    // Called when the video frame is ready to be displayed
    func renderFrame(_ frame: RTCVideoFrame?) {
        // Pass the frame to the renderer
        renderer?.renderFrame(frame)
    }
}
