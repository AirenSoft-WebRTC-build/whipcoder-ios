//
//  HTTPClient.swift
//  WHIPCoder
//
//  Created by dimiden on 5/15/24.
//

import UIKit

enum HTTPClientError: Error {
    case invalidURL
    case requestFailed
    case invalidResponse
    case noData
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
    case head = "HEAD"
    case options = "OPTIONS"
    case trace = "TRACE"
    case connect = "CONNECT"
}

class HTTPClient {
    private let logger: Logger = .init(HTTPClient.self)

    private let userAgent: String
    private var urlRequest: URLRequest

    typealias DataCallback = (_ response: HTTPURLResponse?, _ data: Data?, _ error: Error?) -> Void

    init(_ url: URL) {
        let dictionary = Bundle.main.infoDictionary
        let appName: String = dictionary?["CFBundleName"] as? String ?? "Unknown"
        let appVersion: String = dictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let appBuild: String = dictionary?["CFBundleVersion"] as? String ?? "Unknown"

        let device = UIDevice.current
        let deviceName: String = device.model
        let osName: String = device.systemName
        let osVersion: String = device.systemVersion

        userAgent = "\(appName)/\(appVersion) (\(appBuild); \(deviceName); \(osName) \(osVersion))"
        urlRequest = URLRequest(url: url)
    }

    convenience init(_ urlString: String) throws {
        guard let url = URL(string: urlString) else { throw HTTPClientError.invalidURL }
        self.init(url)
    }

    var method: HTTPMethod = .get
    var body: Data?

    func setHeader(_ value: String?, forKey key: String) {
        urlRequest.setValue(value, forHTTPHeaderField: key)
    }

    func setHeaderIfNotPresent(_ value: String?, forKey key: String) {
        if urlRequest.value(forHTTPHeaderField: key) == nil {
            setHeader(value, forKey: key)
        }
    }

    func addHeader(_ value: String, forKey key: String) {
        urlRequest.addValue(value, forHTTPHeaderField: key)
    }

    func request(completion: @escaping DataCallback) throws {
        urlRequest.httpMethod = method.rawValue
        urlRequest.httpBody = body

        logger.info("Trying to request to \(urlRequest.debugDescription) (method: \(method), body: \(body?.count ?? 0) bytes)...")

        setHeaderIfNotPresent("*/*", forKey: "Accept")
        setHeaderIfNotPresent(userAgent, forKey: "User-Agent")

        URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                completion(nil, nil, error)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(nil, nil, HTTPClientError.invalidResponse)
                return
            }

            completion(httpResponse, data, nil)
        }.resume()
    }
}

extension HTTPURLResponse {
    func isSucceeded() -> Bool {
        return (statusCode / 100) == 2
    }
}
