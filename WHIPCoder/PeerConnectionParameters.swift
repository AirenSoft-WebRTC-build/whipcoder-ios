//
//  PeerConnectionParameters.swift
//  WHIPCoder
//
//  Created by dimiden on 5/14/24.
//

import WebRTC

class PeerConnectionParameters: CustomStringConvertible {
    let endpointUrl: String

#if RTC_ENABLE_BFRAME
    let useBframe: Bool
#endif // RTC_ENABLE_BFRAME
    let useSimulcast: Bool
    let preferredCodecInfo: RTCVideoCodecInfo
    let videoBitrate: Int32
    let framerate: Int16
    let mediaFileName: String

    let iceServers: [RTCIceServer]

#if RTC_ENABLE_BFRAME
    init(
        endpointUrl: String,
        useSimulcast: Bool,
        preferredCodecInfo: RTCVideoCodecInfo,
        videoBitrate: Int32,
        framerate: Int16,
        mediaFileName: String,

        iceServers: [RTCIceServer]
    ) {
        self.endpointUrl = endpointUrl
        self.useBframe = useBframe
        self.useSimulcast = useSimulcast
        self.preferredCodecInfo = preferredCodecInfo
        self.videoBitrate = videoBitrate
        self.framerate = framerate
        self.mediaFileName = mediaFileName

        self.iceServers = iceServers
    }
#else
    init(
        endpointUrl: String,
        useSimulcast: Bool,
        preferredCodecInfo: RTCVideoCodecInfo,
        videoBitrate: Int32,
        framerate: Int16,
        mediaFileName: String,

        iceServers: [RTCIceServer]
    ) {
        self.endpointUrl = endpointUrl
        self.useSimulcast = useSimulcast
        self.preferredCodecInfo = preferredCodecInfo
        self.videoBitrate = videoBitrate
        self.framerate = framerate
        self.mediaFileName = mediaFileName

        self.iceServers = iceServers
    }
#endif // RTC_ENABLE_BFRAME

    static func fromSettings(_ settings: Settings) throws -> PeerConnectionParameters {
        guard let videoCodecInfo = settings.videoCodecInfo else {
            throw PeerConnectionError.invalidSettings
        }

#if RTC_ENABLE_BFRAME
        return PeerConnectionParameters(
            endpointUrl: settings.endpointUrl,
            useBframe: settings.useBframe,
            useSimulcast: settings.useSimulcast,
            preferredCodecInfo: videoCodecInfo,
            videoBitrate: settings.videoBitrate,
            framerate: settings.framerate,
            mediaFileName: settings.mediaFileName,

            iceServers: settings.iceServerStrings.compactMap { RTCIceServer.fromLine($0) }
        )
#else // RTC_ENABLE_BFRAME
        return PeerConnectionParameters(
            endpointUrl: settings.endpointUrl,
            useSimulcast: settings.useSimulcast,
            preferredCodecInfo: videoCodecInfo,
            videoBitrate: settings.videoBitrate,
            framerate: settings.framerate,
            mediaFileName: settings.mediaFileName,

            iceServers: settings.iceServerStrings.compactMap { RTCIceServer.fromLine($0) }
        )
#endif // RTC_ENABLE_BFRAME
    }

    var description: String {
        var extra = ""
#if RTC_ENABLE_BFRAME
        extra.append("useBframe: \(useBframe), ")
#endif // RTC_ENABLE_BFRAME
        extra.append(contentsOf: "useSimulcast: \(useSimulcast), ")

        return "<\(String(describing: PeerConnectionParameters.self)): " +
            "endpoint: \(endpointUrl), \(extra)\(preferredCodecInfo.codecInfoString()) " +
            "framerate: \(framerate), \(videoBitrate)Kbps, fileName: \(mediaFileName), turnServers: \(iceServers)>"
    }
}
