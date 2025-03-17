//
//  RTCVideoCodecInfo+ProfileLevelId.swift
//  WHIPCoder
//
//  Created by dimiden on 5/16/24.
//

import WebRTC

extension RTCVideoCodecInfo {
    func h264ProfileLevelId() -> RTCH264ProfileLevelId? {
        if name.lowercased() == "h264" {
            if let levelId = parameters["profile-level-id"] {
                return RTCH264ProfileLevelId(hexString: levelId)
            }
        }
    
        return nil
    }
  
    func h264ProfileLevelString(_ level: RTCH264Level) -> String {
        switch level {
        case .level1_b:
            return "1b"
      
        default:
            let value = level.rawValue
            return "\(Int32(value / 10)).\(value % 10)"
        }
    }
  
    func codecInfoString() -> String {
        var levelString: String?
    
        if let levelId = h264ProfileLevelId() {
            switch levelId.profile {
            case .baseline: levelString = "Baseline"
            case .constrainedBaseline: levelString = "Constrained Baseline"
            case .main: levelString = "Main"
            case .high: levelString = "High"
            case .constrainedHigh: levelString = "Constrained High"
            @unknown default:
                levelString = "unknown \(levelId)"
            }
      
            levelString = " (\(levelString!), \(h264ProfileLevelString(levelId.level)))"
        }
    
        return "\(name)\(levelString ?? "")"
    }
    
    func getMimeType() -> String {
        switch name {
        case "H264": return "video/h264"
        case "H265": return "video/h265"
        case "VP8": return "video/vp8"
        case "VP9": return "video/vp9"
        case "AV1": return "video/av1"
        default: return ""
        }
    }
    
    func isEqual(to capability: RTCRtpCodecCapability) -> Bool {
        let mimeType = getMimeType()
        
        return
            (capability.mimeType.caseInsensitiveCompare(mimeType) == .orderedSame) &&
            (capability.kind == kRTCMediaStreamTrackKindVideo) &&
            (parameters == capability.parameters)
    }
}
