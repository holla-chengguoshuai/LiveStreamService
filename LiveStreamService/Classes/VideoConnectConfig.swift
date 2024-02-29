//
//  VideoConnectConfig.swift
//  LiveStreamService
//
//  Created by xcode on 2024/2/29.
//

import Foundation
import AgoraRtcKit

extension AgoraVideoProfile {
    // 分辨率
    var dimensions: CGSize {
        switch self {
        case .portrait480P_9:
            return CGSize(width: 480, height: 840)
        case .portrait480P_10:
            return CGSize(width: 480, height: 640)
        default:
            return CGSize(width: 480, height: 640)
        }
    }

    // 帧率 (fps)
    var frameRate: AgoraVideoFrameRate {
        switch self {
        case .portrait480P_9:
            return .fps24
        case .portrait480P_10:
            return .fps15
        default:
            return .fps15
        }
    }

    // 码率 (Kbps)
    var bitrate: NSInteger {
        switch self {
        case .portrait480P_9:
            return 930
        case .portrait480P_10:
            return 400
        default:
            return 400
        }
    }

    // 最小码率
    var minBitrate: NSInteger {
        switch self {
        case .portrait480P_9:
            return 600
        case .portrait480P_10:
            return 400
        default:
            return 400
        }
    }
}

