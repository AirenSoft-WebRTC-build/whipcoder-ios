//
//  Logger.swift
//  WHIPCoder
//
//  Created by dimiden on 5/15/24.
//

import Foundation

class Logger {
  private let dateFormatter: ISO8601DateFormatter
  private let queue: DispatchQueue
  private let tag: String

  init(_ tag: String) {
    self.tag = tag
    self.dateFormatter = ISO8601DateFormatter()
    dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    dateFormatter.timeZone = TimeZone.current
    self.queue = DispatchQueue(label: "com.airensoft.logger.\(tag)", qos: .utility)
  }

  convenience init<T>(_ type: T.Type) {
    self.init(String(describing: type.self))
  }

  enum LogLevel: String {
    case debug = "D 💭"
    case info = "I 🔎"
    case warning = "W ⚠️"
    case error = "E 🔴"
  }

  private func log(_ message: String) {
    queue.async { print(message) }
  }

  private class ThreadInfo: CustomStringConvertible {
    let number: Int
    let name: String

    init(number: Int, name: String) {
      self.number = number
      self.name = name
    }

    static func info() -> ThreadInfo? {
      // <NSThread: 0x0000...>{number = 9, name = (null)}
      let description = Thread.current.description
      let tokens = description.split(separator: ">")

      if tokens.count >= 2 {
        let descriptionPart = tokens[1]
        var number: Int?
        var name: String?

        for pair in descriptionPart.split(separator: ",") {
          let keyValue = pair.split(separator: "=")

          if keyValue.count >= 2 {
            let key = keyValue[0].trimmingCharacters(in: .whitespaces)
            let value = keyValue[1].trimmingCharacters(in: .whitespaces)

            // key가 number나 num으로 끝나면
            if key.hasSuffix("number") || key.hasSuffix("num") {
              number = Int(value)
            } else if key.hasSuffix("name") {
              name = value.hasSuffix("}") ? String(value.dropLast()) : value

              if name == "(null)" {
                name = "Thread"
              }
            }
          }
        }

        guard let number = number, let name = name else {
          return nil
        }

        return ThreadInfo(number: number, name: name)
      }

      // Unknown format
      return nil
    }

    var description: String {
      return "\(name)-\(number)"
    }
  }

  private func log(_ level: LogLevel, _ message: String, file: String, line: Int, function: String) {
    let fileName = (file as NSString).lastPathComponent
    let date = dateFormatter.string(from: Date())
    let threadInfo = ThreadInfo.info()

    log("[\(date)] \(level.rawValue) [\(threadInfo?.description ?? "Unknown thread")] \(fileName):\(line) | \(function) | \(message)")
  }

  func debug(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    log(.debug, message, file: file, line: line, function: function)
  }

  func info(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    log(.info, message, file: file, line: line, function: function)
  }

  func warning(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    log(.warning, message, file: file, line: line, function: function)
  }

  func error(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    log(.error, message, file: file, line: line, function: function)
  }
}
