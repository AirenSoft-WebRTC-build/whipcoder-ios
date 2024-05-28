//
//  PublishViewController.swift
//  WHIPCoder
//
//  Created by dimiden on 5/9/24.
//

import UIKit
import WebRTC

class PublishViewController: UIViewController, RTCPeerConnectionDelegate {
  private let logger: Logger = .init(PublishViewController.self)

  @IBOutlet var settingLabel: UILabel!
  @IBOutlet var renderView: VideoRenderView!
  @IBOutlet var exitButton: UIButton!

  private var peerConnectionClient: PeerConnectionClient?

  @IBAction func phoneDownPressed(_ sender: UIButton) {
    peerConnectionClient?.disconnect()
    dismiss(animated: true)
  }

  private func alert(title: String, message: String, completion: (() -> Void)? = nil) {
    DispatchQueue.main.async {
      let alertViewController = UIAlertController(title: title, message: message, preferredStyle: .alert)
      alertViewController.addAction(UIAlertAction(title: "OK", style: .default) { _ in completion?() })

      self.present(alertViewController, animated: true)
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    let settings = Settings.shared

    settingLabel.text = [
      "Content: \(settings.mediaFileName)",
      "Codec: \(settings.videoCodecInfo?.codecInfoString() ?? "-")",
      "Bitrate: \(settings.videoBitrate)",
      "Framerate: \(settings.framerate)",
      "Use b-frame: \(settings.useBframe)",
    ].joined(separator: "\n")

    do {
      try preparePeerConnectionClient(settings: settings)
    } catch {
      alert(title: "Error", message: "Failed to prepare PeerConnectionClient: \(error.localizedDescription)") {
        self.dismiss(animated: true)
      }
    }
  }

  private func preparePeerConnectionClient(settings: Settings) throws {
    logger.info("Preparing PeerConnectionClient...")

    let parameters = try PeerConnectionParameters.fromSettings(settings)

    peerConnectionClient = PeerConnectionClient(
      parameters: parameters,
      delegate: self
    )

    try peerConnectionClient?.create(options: nil, renderer: renderView) { error in
      if error != nil {
        self.alert(title: "Error", message: "Could not create peer connection: \(String(describing: error!))") {
          self.dismiss(animated: true)
        }
        return
      }

      Settings.shared.iceServerStrings = self.peerConnectionClient!.linkStrings
    }
  }

  private func onFrame(frame: RTCVideoFrame) {}

  // MARK: - RTCPeerConnectionDelegate

  func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
    logger.info("Signaling state changed: \(stateChanged)")
  }

  func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
    logger.info("Stream with \(stream.videoTracks.count) video tracks and \(stream.audioTracks.count) audio tracks was added.")
  }

  func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
    logger.info("Stream was removed")
  }

  func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
    logger.info("WARNING: Renegotiation needed but unimplemented")
  }

  func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
    logger.info("ICE state changed: \(newState)")
  }

  func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
    logger.info("ICE gathering state changed: \(newState)")
  }

  func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {}

  func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}

  func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}

  // @optional
  func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCPeerConnectionState) {
    logger.info("ICE+DTLS state changed: \(newState)")
  }

  func peerConnection(_ peerConnection: RTCPeerConnection, didStartReceivingOn transceiver: RTCRtpTransceiver) {
    guard let track = transceiver.receiver.track else { return }
    logger.info("Now receiving \(track.kind) on track \(track.trackId)")
  }

  func peerConnection(
    _ peerConnection: RTCPeerConnection, didChangeLocalCandidate local: RTCIceCandidate,
    remoteCandidate remote: RTCIceCandidate, lastReceivedMs lastDataReceivedMs: Int32,
    changeReason reason: String
  ) {
    logger.info("ICE candidate pair changed because: \(reason)")
  }

  func peerConnection(_ peerConnection: RTCPeerConnection, didFailToGatherIceCandidate event: RTCIceCandidateErrorEvent) {
    logger.error(
      "Failed to gather ICE candidate. address: \(event.address), port: \(event.port), "
        + "url: \(event.url), errorCode: \(event.errorCode), errorText: \(event.errorText)")
  }
}
