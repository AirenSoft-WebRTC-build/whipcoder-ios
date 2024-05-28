//
//  VideoSourceView.swift
//  WHIPCoder
//
//  Created by dimiden on 5/9/24.
//

import UIKit
import WebRTC

class VideoSourceView: UIView {
  private let logger: Logger = .init(VideoSourceView.self)

  override init(frame: CGRect) {
    super.init(frame: frame)
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
}
