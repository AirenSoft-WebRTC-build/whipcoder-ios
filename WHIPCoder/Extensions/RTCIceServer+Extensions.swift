//
//  RTCIceServer+Extensions.swift
//  WHIPCoder
//
//  Created by dimiden on 5/16/24.
//

import WebRTC

extension RTCIceServer {
  // Parse the line like below:
  // <turn:1.1.1.1:42000?transport=tcp>; rel="ice-server"; username="ome"; credential="airen"; credential-type="password"
  static func fromLine(_ line: String) -> RTCIceServer? {
    let tokens = line.split(separator: ";")
      .map { $0.trimmingCharacters(in: .whitespaces) }

    if tokens.count < 1 {
      return nil
    }

    let turnUrl = [
      tokens[0]
        .replacingOccurrences(of: "<", with: "")
        .replacingOccurrences(of: ">", with: "")
        .trimmingCharacters(in: .whitespaces)
    ]

    let restTokens = tokens.dropFirst()
      .reduce(into: [String: String]()) { result, token in
        let keyValue = token.split(separator: "=", maxSplits: 1)
          .map { $0.trimmingCharacters(in: .whitespaces) }

        var value = keyValue[1]
        
        if (value.hasPrefix("\"")) {
          value.removeFirst()
        }
        
        if (value.hasSuffix("\"")) {
          value.removeLast()
        }
        
        result[keyValue[0]] = value
      }

    let username = restTokens["username"]
    let credential = restTokens["credential"]

    return RTCIceServer(urlStrings: turnUrl, username: username, credential: credential, tlsCertPolicy: .secure)
  }
}
