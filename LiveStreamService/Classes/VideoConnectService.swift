//
//  VideoConnectService.swift
//  LiveStreamService
//
//  Created by xcode on 2024/2/29.
//

import Foundation
import AgoraRtcKit
import DeviceKit

// agora 回调
protocol VideoConnectStateDelegate: NSObjectProtocol {
    func videoUserJoined(uid: UInt)
    func videoRenderView(for user: UInt) -> UIView?
    func videoReceived(for user: UInt)
    func videoUserLeave(id: UInt)
    func firstLocalVideoFramePublish()
    func videoBannedByServer()
    func tokenPrivilegeWillExpire()
}


class VideoConnectService: NSObject {
    
    public static let shared = VideoConnectService()

    public weak var delegate: VideoConnectStateDelegate?
    /// Agora 实例
    var agoraKit: AgoraRtcEngineKit?

    fileprivate var call_channel_name: String = ""
    
    fileprivate var agoarAppId: String = ""

    
    /// 初始化 Agora 实例
    func setAgoraRtcEngineKit() {
        guard agoraKit == nil else { return }

        let kit = AgoraRtcEngineKit.sharedEngine(withAppId: agoarAppId, delegate: self)
        kit.enableMainQueueDispatch(true)
        //是否分发回调至主队列
        kit.setChannelProfile(AgoraChannelProfile.liveBroadcasting)
        //设置外部视频源。
        kit.setExternalVideoSource(true, useTexture: false, sourceType: .videoFrame)
        kit.setClientRole(.broadcaster)
        // 开启或关闭扬声器播放。
        kit.setEnableSpeakerphone(true)
        // main thread
        DispatchQueue.main.async {
            kit.enableVideo()
            kit.enableAudio()
        }
        agoraKit = kit
    }
    
    func initAgoraVideoEncoderConfiguration(isLive:Bool,is_hd:Int = 0) -> AgoraVideoEncoderConfiguration{
        // 视频编码配置
        let profile: AgoraVideoProfile
        // 网络是wifi， 并且配置了超宽摄像头
        if Reachability.shared.networkStatus == .ethernetOrWiFi, Device.allDevicesWithUltraWideCamera.contains(Device.current) {
            profile = .portrait480P_9
        } else {
            profile = .portrait480P_10
        }
        
        var dimensions = profile.dimensions
        var frameRate = profile.frameRate

//        if isLive {
//            if let newframeRate = AppInfoV2.shared?.agoraLiveVideoframeRate, newframeRate > 0 {
//                frameRate = AgoraVideoFrameRate(rawValue: newframeRate) ?? .fps15
//            }
//            
//            if let w = AppInfoV2.shared?.agoraLiveVideoResolutionW, w > 0,let h = AppInfoV2.shared?.agoraLiveVideoResolutionH, h > 0 {
//                dimensions = CGSize(width: w, height: h)
//            }
//        }else{
//            if let newframeRate = AppInfoV2.shared?.agoraVideoframeRate, newframeRate > 0 {
//                frameRate = AgoraVideoFrameRate(rawValue: newframeRate) ?? .fps15
//            }
//            
//            if let w = AppInfoV2.shared?.agoraVideoResolutionW, w > 0,let h = AppInfoV2.shared?.agoraVideoResolutionH, h > 0 {
//                dimensions = CGSize(width: w, height: h)
//            }
//        }
        if is_hd == 1 {
            dimensions = CGSize(width: 720, height: 960)
        }
        let config = AgoraVideoEncoderConfiguration(size: dimensions, frameRate: frameRate, bitrate: profile.bitrate, orientationMode: .fixedPortrait, mirrorMode: .auto)
        return config
    }
    
    
}



extension VideoConnectService: AgoraRtcEngineDelegate {
    /// 已接收到远端视频并完成解码回调。
    func rtcEngine(_ engine: AgoraRtcEngineKit, firstRemoteVideoDecodedOfUid uid: UInt, size: CGSize, elapsed: Int) {
        guard let delegate = delegate else {
            return
        }
        guard call_channel_name.count > 0 else {
            return
        }
        delegate.videoReceived(for: uid)
    }
    
    
}
