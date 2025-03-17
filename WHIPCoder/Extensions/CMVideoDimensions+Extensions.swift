//
//  CMVideoDimensions+Extensions.swift
//  WHIPCoder
//
//  Created by dimiden on 5/16/24.
//

import CoreMedia

extension CMVideoDimensions {
    func isEquals(_ dimension: CMVideoDimensions?) -> Bool {
        return (width == dimension?.width) && (height == dimension?.height)
    }

    func resolutionString() -> String {
        return "\(width)x\(height)"
    }
}
