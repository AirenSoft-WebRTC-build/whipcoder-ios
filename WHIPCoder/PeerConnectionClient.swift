//
//  PeerConnectionClient.swift
//  WHIPCoder
//
//  Created by dimiden on 5/14/24.
//

import Foundation
import WebRTC

enum PeerConnectionError: Error {
  case invalidState
  case invalidSettings
  case creationFailed
  case cannotCreateOffserSdp
}

class PeerConnectionClient {
  private let logger: Logger = .init(PeerConnectionClient.self)
  private static let dispatcher = DispatchQueue(
    label: String(describing: PeerConnectionClient.self))

  private let parameters: PeerConnectionParameters
  private let delegate: RTCPeerConnectionDelegate

  private var videoCapturer: RTCFileVideoCapturer?
  private var frameCallback: FrameCallback?

  private static let kMediaStreamId = ["ARDAMS"]
  private static let kAudioTrackId = "ARDAMSa0"
  private static let kVideoTrackId = "ARDAMSv0"
  private static let kVideoTrackKind = "video"

  private var whipCoder: WHIPCoder?

  private var factory: RTCPeerConnectionFactory?
  private var peerConnection: RTCPeerConnection?
  private var videoSource: RTCVideoSource?

  private var sdpMediaConstraints: RTCMediaConstraints?

  private var localVideoTrack: RTCVideoTrack?

  private var links: [String] = []

  typealias CreateCallback = (_ error: Error?) -> Void
  typealias FrameCallback = (_ frame: RTCVideoFrame) -> Void

  init(parameters: PeerConnectionParameters, delegate: RTCPeerConnectionDelegate) {
    self.parameters = parameters
    self.delegate = delegate

    logger.debug("PeerConnectionClient is created with: \(parameters)")
  }

  private func prepareFactory(options: RTCPeerConnectionFactoryOptions?) throws
    -> RTCPeerConnectionFactory
  {
    guard factory == nil else {
      logger.error("PeerConnectionFactory has already been created")
      throw PeerConnectionError.invalidState
    }

    #if RTC_ENABLE_BFRAME
    let decoderFactory = RTCDefaultVideoDecoderFactory()
    let encoderFactory = RTCDefaultVideoEncoderFactory(bframe: parameters.useBframe)
    #else // RTC_ENABLE_BFRAME
    let decoderFactory = RTCDefaultVideoDecoderFactory()
    let encoderFactory = RTCDefaultVideoEncoderFactory()
    #endif // RTC_ENABLE_BFRAME

    encoderFactory.preferredCodec = parameters.preferredCodecInfo

    let factory = RTCPeerConnectionFactory(
      encoderFactory: encoderFactory,
      decoderFactory: decoderFactory
    )

    if options != nil {
      factory.setOptions(options!)
    }

    self.factory = factory
    return factory
  }

  private func preparePeerConnection(factory: RTCPeerConnectionFactory, iceServers: [RTCIceServer], renderer: RTCVideoRenderer?)
    throws -> RTCPeerConnection
  {
    logger.info("Preparing peer connection with ICEServers:\(iceServers)")

    let config = RTCConfiguration()
    config.iceServers = iceServers
    config.iceTransportPolicy = .relay
    config.bundlePolicy = .maxBundle
    config.rtcpMuxPolicy = .require
    config.continualGatheringPolicy = .gatherOnce
    config.enableCpuAdaptation = false
    config.keyType = .ECDSA
    config.sdpSemantics = .unifiedPlan

    guard
      let peerConnection = factory.peerConnection(
        with: config,
        constraints: defaultPeerConnectionConstraints(),
        delegate: delegate
      )
    else {
      throw PeerConnectionError.creationFailed
    }

    logger.debug("PeerConnection is created")

    localVideoTrack = createVideoTrack(factory: factory)
    if renderer != nil {
      localVideoTrack?.add(renderer!)
    }

    peerConnection.add(localVideoTrack!, streamIds: Self.kMediaStreamId)

    // Set the bitrate
    for sender in peerConnection.senders {
      if sender.track?.kind == Self.kVideoTrackKind {
        setEncodingParameters(maxBitrate: parameters.videoBitrate, maxFramerate: parameters.framerate, forVideoSender: sender)
      }
    }

    self.peerConnection = peerConnection
    return peerConnection
  }

  private func setEncodingParameters(maxBitrate: Int32, maxFramerate: Int16, forVideoSender sender: RTCRtpSender) {
    if maxBitrate <= 0 {
      return
    }

    logger.info("Encoding parameters: bitrate: \(maxBitrate)kbps, framerate: \(maxFramerate)fps")

    let parametersToModify = sender.parameters

    for encoding in parametersToModify.encodings {
      logger.info("Applying parameters to \(encoding.debugDescription)")
      encoding.maxBitrateBps = NSNumber(value: maxBitrate * 1000)
      encoding.maxFramerate = NSNumber(value: maxFramerate)
    }

    sender.parameters = parametersToModify
  }

  private func createOffer(
    peerConnection: RTCPeerConnection,
    for constraints: RTCMediaConstraints,
    completionHandler: @escaping WHIPCoder.SDPCallback
  ) {
    peerConnection.offer(
      for: constraints,
      completionHandler: { sdp, error in
        if error != nil {
          self.logger.error("Failed to create session description: \(error?.localizedDescription ?? "")")

          DispatchQueue.main.async {
            self.disconnect()
            completionHandler(nil, error)
          }
          return
        }

        guard let sdp = sdp else {
          self.logger.error("Invalid SDP: \(String(describing: sdp))")
          DispatchQueue.main.async {
            self.disconnect()
            completionHandler(nil, PeerConnectionError.cannotCreateOffserSdp)
          }
          return
        }

        self.logger.debug("offer SDP is created\n\(sdp.description.replacingOccurrences(of: "\r", with: ""))")
        completionHandler(sdp, nil)
      }
    )
  }

  func create(options: RTCPeerConnectionFactoryOptions? = nil, renderer: RTCVideoRenderer?, completionHandler: CreateCallback? = nil) throws {
    let factory = try prepareFactory(options: options)
    let peerConnection = try preparePeerConnection(factory: factory, iceServers: parameters.iceServers, renderer: renderer)

    let urlString = parameters.endpointUrl
    guard let url = URL(string: urlString) else {
      logger.error("Invalid URL: \(urlString)")
      completionHandler?(HTTPClientError.invalidURL)
      return
    }

    createOffer(peerConnection: peerConnection, for: defaultOfferConstraints()) { offerSdp, offerError in
      guard let offerSdp = offerSdp else {
        self.logger.error("Could not create offer SDP: \(String(describing: offerError))")
        completionHandler?(offerError)
        return
      }

      peerConnection.setLocalDescription(offerSdp) { setOfferSdpError in
        if setOfferSdpError != nil {
          self.logger.error("Could not set offer SDP: \(String(describing: setOfferSdpError))")
          completionHandler?(setOfferSdpError)
          return
        }

        let whipCoder = WHIPCoder(url, requestSDP: offerSdp.sdp)
        whipCoder.requestCreate { answerSdp, answerError in
          guard let answerSdp = answerSdp else {
            self.logger.error("Could not obtain answer SDP: \(String(describing: answerError))")
            completionHandler?(answerError)
            return
          }

          peerConnection.setRemoteDescription(answerSdp) { setAnswerSdpError in
            if setAnswerSdpError != nil {
              self.logger.error("Could not set answer SDP: \(String(describing: setAnswerSdpError))")
              completionHandler?(setAnswerSdpError)
              return
            }

            self.logger.info("Remote description is set: \(String(describing: answerError))")
            self.links = whipCoder.getLinks()

            completionHandler?(nil)
          }
        }

        self.whipCoder = whipCoder
      }
    }
  }

  private func defaultPeerConnectionConstraints() -> RTCMediaConstraints {
    return RTCMediaConstraints(
      mandatoryConstraints: nil,
      optionalConstraints: ["DtlsSrtpKeyAgreement": "true"]
    )
  }

  private func defaultOfferConstraints() -> RTCMediaConstraints {
    return RTCMediaConstraints(
      mandatoryConstraints: [
        "OfferToReceiveAudio": "false",
        "OfferToReceiveVideo": "false",
      ],
      optionalConstraints: nil
    )
  }

  var linkStrings: [String] { links }

  func disconnect() {
    _ = whipCoder?.requestDelete()
    videoCapturer?.stopCapture()
    factory?.stopAecDump()
    peerConnection?.stopRtcEventLog()
    peerConnection = nil

    RTCStopInternalCapture()
  }

  private func createVideoTrack(factory: RTCPeerConnectionFactory) -> RTCVideoTrack {
    let source = factory.videoSource()

    logger.info("Creating video track with media file: \(parameters.mediaFileName)...")

    let videoCapturer = RTCFileVideoCapturer(delegate: source)
    videoCapturer.startCapturing(
      fromFileNamed: parameters.mediaFileName,
      onError: { error in
        self.logger.error("Could not open the media file: \(self.parameters.mediaFileName), error: \(error)")
      }
    )

    self.videoCapturer = videoCapturer

    videoSource = source

    return factory.videoTrack(with: source, trackId: Self.kVideoTrackId)
  }
}
