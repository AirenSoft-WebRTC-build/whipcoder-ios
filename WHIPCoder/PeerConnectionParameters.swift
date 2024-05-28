//
//  PeerConnectionParameters.swift
//  WHIPCoder
//
//  Created by dimiden on 5/14/24.
//

import WebRTC

class PeerConnectionParameters: CustomStringConvertible {
  let endpointUrl: String
  let useBframe: Bool
  let preferredCodecInfo: RTCVideoCodecInfo
  let videoBitrate: Int32
  let framerate: Int16
  let mediaFileName: String
  
  let iceServers: [RTCIceServer]

  init(
    endpointUrl: String,
    useBframe: Bool,
    preferredCodecInfo: RTCVideoCodecInfo,
    videoBitrate: Int32,
    framerate: Int16,
    mediaFileName: String,
    
    iceServers: [RTCIceServer]
  ) {
    self.endpointUrl = endpointUrl
    self.useBframe = useBframe
    self.preferredCodecInfo = preferredCodecInfo
    self.videoBitrate = videoBitrate
    self.framerate = framerate
    self.mediaFileName = mediaFileName
    
    self.iceServers = iceServers
  }
  
  static func fromSettings(_ settings: Settings) throws -> PeerConnectionParameters {
    guard let videoCodecInfo = settings.videoCodecInfo else {
      throw PeerConnectionError.invalidSettings
    }
          
    return PeerConnectionParameters(
      endpointUrl: settings.endpointUrl,
      useBframe: settings.useBframe,
      preferredCodecInfo: videoCodecInfo,
      videoBitrate: settings.videoBitrate,
      framerate: settings.framerate,
      mediaFileName: settings.mediaFileName,
      
      iceServers: settings.iceServerStrings.compactMap { RTCIceServer.fromLine($0) }
    )
  }

  var description: String {
    return "<\(String(describing: PeerConnectionParameters.self)): " +
      "endpoint: \(endpointUrl), useBframe: \(useBframe), \(preferredCodecInfo.codecInfoString()) " +
      "framerate: \(framerate), \(videoBitrate)Kbps, fileName: \(mediaFileName), turnServers: \(iceServers)>"
  }
}
