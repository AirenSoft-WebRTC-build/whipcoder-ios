//
//  WHIPCoder.swift
//  WHIPCoder
//
//  Created by dimiden on 5/14/24.
//

import WebRTC

enum WHIPCoderError: Error {
    case requestFailed
    case streamExists
    case invalidResponse
}

class WHIPCoder {
    private let logger: Logger = .init(WHIPCoder.self)
    private var url: URL
    private var links: [String] = []
    private var location: String?
    private var vary: String?

    private let requestSDP: String

    init(_ url: URL, requestSDP: String) {
        self.url = url
        self.requestSDP = requestSDP
    }

    func getLinks() -> [String] { return links }
    func getLocation() -> String? { return location }
    func getVary() -> String? { return vary }

    typealias SDPCallback = (_ sdp: RTCSessionDescription?, _ error: Error?) -> Void

    func requestCreate(_ completionHandler: SDPCallback? = nil) {
        do {
            logger.info("Trying to request to \(url)...")

            let client = HTTPClient(url)

            client.setHeader("application/sdp", forKey: "Content-Type")
            client.method = HTTPMethod.post
            client.body = requestSDP.data(using: .utf8)

            try client.request { response, data, error in
                let logger = self.logger

                guard error == nil else {
                    completionHandler?(nil, error)
                    return
                }

                guard let response = response else {
                    completionHandler?(nil, WHIPCoderError.invalidResponse)
                    return
                }

                if response.isSucceeded() == false {
                    logger.error("Server respond error status code: \(response.statusCode) with \(data != nil ? "" : "no ")body\(data != nil ? ", \(data!.description)" : "")")

                    completionHandler?(nil, (response.statusCode == 409) ? WHIPCoderError.streamExists : WHIPCoderError.invalidResponse)
                    return
                }

                guard let data = data else {
                    logger.error("Server respond no body with status code: \(response.statusCode)")
                    completionHandler?(nil, WHIPCoderError.invalidResponse)
                    return
                }

                guard let sdp = String(data: data, encoding: .utf8) else {
                    logger.error("Invalid answer SDP")
                    completionHandler?(nil, WHIPCoderError.invalidResponse)
                    return
                }

                logger.debug("Got answer SDP:\n\(sdp.description.replacingOccurrences(of: "\r", with: ""))")

                let answerSDP = RTCSessionDescription(type: .answer, sdp: sdp)

                let headers = response.allHeaderFields
                self.links = (headers["Link"] as? String)?.split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) } ?? []
                self.location = headers["Location"] as? String
                self.vary = headers["Vary"] as? String

                logger.info("Request is succeeded and got headers:")
                logger.info(" - link: \(self.links.count) items")
                for link in self.links {
                    logger.info("   - \(link)")
                }

                logger.info(" - location: \(self.location ?? "")")
                logger.info(" - vary: \(self.vary ?? "")")

                completionHandler?(answerSDP, nil)
            }
        } catch {
            logger.error("\(error.localizedDescription)")
            completionHandler?(nil, error)
        }
    }

    func requestDelete(_ completionHandler: SDPCallback? = nil) -> Bool {
        if location?.isEmpty ?? false {
            return false
        }

        do {
            let port = (url.port != nil) ? ":\(url.port!)" : ""
            let urlString = "\(url.scheme ?? "")://\(url.host ?? "")\(port)\(location ?? "")"

            let client = try HTTPClient(urlString)

            client.setHeader("application/sdp", forKey: "Content-Type")
            client.method = HTTPMethod.delete

            try client.request { response, _, error in
                let logger = self.logger

                guard error == nil else {
                    logger.error("An error occurred: \(error!.localizedDescription)")
                    completionHandler?(nil, error)
                    return
                }

                guard response != nil else {
                    logger.error("Invalid response: nil")
                    completionHandler?(nil, WHIPCoderError.invalidResponse)
                    return
                }
            }
        } catch {
            logger.error("\(error.localizedDescription)")
        }

        return false
    }
}
