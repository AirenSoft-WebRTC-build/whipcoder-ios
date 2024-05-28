//
//  Configuration.swift
//  OMETester
//
//  Created by dimiden on 5/7/24.
//

import WebRTC

class Settings {
  static let shared = Settings()

  private enum ConfigKeys: String {
    case endpointUrl = "WHIPCoder.Config.endpointUrl"
    case iceServerStrings = "WHIPCoder.Config.iceServerStrings"
    case useBframe = "WHIPCoder.Config.useBframe"
    case videoCodecInfo = "WHIPCoder.Config.videoCodecInfo"
    case videoBitrate = "WHIPCoder.Config.videoBitrate"
    case framerate = "WHIPCoder.Config.framerate"
    case mediaFileName = "WHIPCoder.Config.mediaFileName"
    case resolution = "WHIPCoder.Config.resolution"
  }

  // MARK: - Data Structure to store obj-c classes

  private struct VideoCodecInfo: Codable {
    enum CodingKeys: CodingKey {
      case name
      case h264Profile
    }

    let name: String
    let h264Profile: RTCH264Profile?

    init(name: String, h264Profile: RTCH264Profile?) {
      self.name = name
      self.h264Profile = h264Profile
    }

    init(_ codecInfo: RTCVideoCodecInfo) {
      self.init(name: codecInfo.name, h264Profile: codecInfo.h264ProfileLevelId()?.profile)
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.name = try container.decode(String.self, forKey: .name)

      let rawProfile = try? container.decodeIfPresent(
        RTCH264Profile.RawValue.self, forKey: .h264Profile
      )
      self.h264Profile = (rawProfile != nil) ? RTCH264Profile(rawValue: rawProfile!) : nil
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(name, forKey: .name)
      try container.encode(h264Profile?.rawValue, forKey: .h264Profile)
    }

    func isEquals(_ codecInfo: RTCVideoCodecInfo?) -> Bool {
      return (name == codecInfo?.name) && (h264Profile == codecInfo?.h264ProfileLevelId()?.profile)
    }
  }

  // MARK: - Getter/Setter

  private func get<T>(_ key: ConfigKeys) -> T? {
    return UserDefaults.standard.object(forKey: key.rawValue) as? T
  }

  private func get<T>(_ key: ConfigKeys, default defaultValue: T) -> T {
    return get(key) ?? defaultValue
  }

  private func set<T>(_ value: T?, forKey key: ConfigKeys) {
    if value == nil {
      UserDefaults.standard.removeObject(forKey: key.rawValue)
    } else {
      UserDefaults.standard.set(value, forKey: key.rawValue)
    }
  }

  // MARK: - Encode/Decode helper

  private func decode<T>(_ data: Data?, type: T.Type) -> T? where T: Decodable {
    guard let data = data else { return nil }
    return try? PropertyListDecoder().decode(type, from: data)
  }

  private func decode<T>(_ data: Data?, type: T.Type, default defaultValue: T) -> T where T: Decodable {
    return decode(data, type: type) ?? defaultValue
  }

  private func encode<T>(_ value: T?) -> Data? where T: Encodable {
    guard let value = value else { return nil }
    return try? PropertyListEncoder().encode(value)
  }

  // MARK: - Configuration Variables

  var endpointUrl: String {
    get { get(ConfigKeys.endpointUrl, default: "http://192.168.0.160:43333/app/stream?direction=whip") }
    set { set(newValue, forKey: ConfigKeys.endpointUrl) }
  }

  var iceServerStrings: [String] {
    get { get(ConfigKeys.iceServerStrings, default: []) }
    set { set(newValue, forKey: ConfigKeys.iceServerStrings) }
  }

  var useBframe: Bool {
    get { get(ConfigKeys.useBframe, default: false) }
    set { set(newValue, forKey: ConfigKeys.useBframe) }
  }

  var videoCodecInfo: RTCVideoCodecInfo? {
    get {
      let codecInfo = decode(get(ConfigKeys.videoCodecInfo), type: VideoCodecInfo.self)
      return videoCodecInfos.first { rtcCodecInfo in
        codecInfo?.isEquals(rtcCodecInfo) ?? false
      }
    }
    set {
      let codecInfo = (newValue != nil) ? VideoCodecInfo(newValue!) : nil
      set(encode(codecInfo), forKey: ConfigKeys.videoCodecInfo)
    }
  }

  // Unit: Kbps
  var videoBitrate: Int32 {
    get { get(ConfigKeys.videoBitrate) ?? 3000 }
    set { set(newValue, forKey: ConfigKeys.videoBitrate) }
  }

  var framerate: Int16 {
    get { get(ConfigKeys.framerate, default: availableFramerates()[0]) }
    set { set(newValue, forKey: ConfigKeys.framerate) }
  }

  var mediaFileName: String {
    get { get(ConfigKeys.mediaFileName, default: availableMediaFileNames()[0]) }
    set { set(newValue, forKey: ConfigKeys.mediaFileName) }
  }

  var resolution: CMVideoDimensions? {
    get {
      // [0] = width, [1] = height
      guard let resolution: [Int32] = get(ConfigKeys.resolution) else {
        return availableCameraResolutions()[0]
      }

      return CMVideoDimensions(width: resolution[0], height: resolution[1])
    }
    set {
      var resolution: [Int32]?
      if newValue != nil {
        resolution = [Int32(newValue!.width), Int32(newValue!.height)]
      }
      set(resolution, forKey: ConfigKeys.resolution)
    }
  }

  // MARK: - Lists of candidates

  private lazy var videoCodecInfos = RTCDefaultVideoEncoderFactory().supportedCodecs()
  func availableVideoCodecInfos() -> [RTCVideoCodecInfo] { videoCodecInfos }

  private lazy var cameraResolutions = RTCCameraVideoCapturer.captureDevices()
    .flatMap { device in
      RTCCameraVideoCapturer.supportedFormats(for: device)
        .map { format in
          CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        }
    }
    .reduce(into: [CMVideoDimensions]()) { array, res in
      if array.contains(
        where: { ($0.width == Int(res.width)) && ($0.height == Int(res.height)) }
      ) == false {
        array.append(res)
      }
    }
    .sorted { res1, res2 in
      (res1.width != res2.width) ? (res1.width < res2.width) : (res1.height < res2.height)
    }

  func availableCameraResolutions() -> [CMVideoDimensions] { cameraResolutions }

  private lazy var framerates: [Int16] = [5, 15, 30, 60]
  func availableFramerates() -> [Int16] { framerates }

  private lazy var mediaFileNames: [String] = Self.getTestFiles(ext: "mp4").sorted()
  private static func getTestFiles(ext: String) -> [String] {
    if let resourcePath = Bundle.main.resourcePath {
      let fileManager = FileManager.default
      do {
        let fileExt = ".\(ext)"
        let files = try fileManager.contentsOfDirectory(atPath: resourcePath)
        return files.filter { $0.hasSuffix(fileExt) }
      } catch {}
    }

    return []
  }

  func availableMediaFileNames() -> [String] { mediaFileNames }
}
