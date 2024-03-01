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

class VideoRoomInfo: NSObject {
    
    var call_user_id: String!

    // 频道 key 加入房间使用
    var call_channel_key: String!

    /// room id
    var call_channel_name: String!
    
    var self_user_id: String!
    
    var is_hd: Int = 0

}


class VideoframeRate: NSObject {
    
    ///  分辨率高
    dynamic var agoraVideoResolutionH: Int = 0

    /// 分辨率宽
    dynamic var agoraVideoResolutionW: Int = 0

    /// 帧率
    dynamic var agoraVideoframeRate: Int = 0
    
    /// 帧率
    var isLive: Bool = false

    ///  分辨率高
    dynamic var agoraLiveVideoResolutionH: Int = 0

    /// 分辨率宽
    dynamic var agoraLiveVideoResolutionW: Int = 0

    /// 帧率
    dynamic var agoraLiveVideoframeRate: Int = 0
}


class VideoConnectService: NSObject {
    
    public static let shared = VideoConnectService()

    public weak var delegate: VideoConnectStateDelegate?
    /// Agora 实例
    var agoraKit: AgoraRtcEngineKit?

    private var currentRoomInfo: VideoRoomInfo?

    private var videoframeRate: VideoframeRate?

    fileprivate var agoarAppId: String = ""

    fileprivate var streamId: Int = -1

    
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

        if isLive {
            if let newframeRate = videoframeRate?.agoraLiveVideoframeRate, newframeRate > 0 {
                frameRate = AgoraVideoFrameRate(rawValue: newframeRate) ?? .fps15
            }
            
            if let w = videoframeRate?.agoraLiveVideoResolutionW, w > 0,let h = videoframeRate?.agoraLiveVideoResolutionH, h > 0 {
                dimensions = CGSize(width: w, height: h)
            }
        }else{
            if let newframeRate = videoframeRate?.agoraVideoframeRate, newframeRate > 0 {
                frameRate = AgoraVideoFrameRate(rawValue: newframeRate) ?? .fps15
            }
            
            if let w = videoframeRate?.agoraVideoResolutionW, w > 0,let h = videoframeRate?.agoraVideoResolutionH, h > 0 {
                dimensions = CGSize(width: w, height: h)
            }
        }
        if is_hd == 1 {
            dimensions = CGSize(width: 720, height: 960)
        }
        let config = AgoraVideoEncoderConfiguration(size: dimensions, frameRate: frameRate, bitrate: profile.bitrate, orientationMode: .fixedPortrait, mirrorMode: .auto)
        return config
    }
    
    
    func videoConnect(roomInfo: VideoRoomInfo, mute: Bool = false) {
        guard let id = roomInfo.self_user_id , let uid = UInt(id) else { return }
        guard let roomKey = roomInfo.call_channel_key, let roomid = roomInfo.call_channel_name else { return }
        guard let otherUid = roomInfo.call_user_id else { return }
        setAgoraRtcEngineKit()
        currentRoomInfo = roomInfo

        // 视频编码配置
        let profile: AgoraVideoProfile
        // 网络是wifi， 并且配置了超宽摄像头
        if Reachability.shared.networkStatus == .ethernetOrWiFi, Device.allDevicesWithUltraWideCamera.contains(Device.current) {
            profile = .portrait480P_9
        } else {
            profile = .portrait480P_10
        }
        
        let config = self.initAgoraVideoEncoderConfiguration(isLive:false,is_hd: currentRoomInfo?.is_hd ?? 0)
        config.degradationPreference = .balanced
        agoraKit?.setVideoEncoderConfiguration(config)
        agoraKit?.setParameters("{\"che.video.startVideoBitRate\":\(profile.minBitrate)}")
        
        
        let option = AgoraRtcChannelMediaOptions()
        option.channelProfile = .liveBroadcasting
        option.clientRoleType = .broadcaster
        let result = agoraKit?.joinChannel(byToken: roomKey, channelId: roomid, uid: uid, mediaOptions: option) { [weak self] _, _, _ in
            guard let `self` = self else { return }
            let con = AgoraDataStreamConfig()
            self.agoraKit?.createDataStream(&self.streamId, config: con)
            VideoConnectService.shared.muteVideo(for: otherUid,mute: mute)
        }
    }
    
    /// Description
    func muteVideo(for user: String, mute: Bool = false) {
        guard let uid = UInt(user) else {
            return
        }
        agoraKit?.muteRemoteAudioStream(uid, mute: mute)
    }
    
    // 退出房间
    func stopVideoConnect(model: VideoRoomInfo) {

        guard let roomInfo = currentRoomInfo, model.call_channel_name == roomInfo.call_channel_name else {
            return
        }
        
        agoraKit?.leaveChannel { [weak self] _ in
            guard let `self` = self else { return }
            self.streamId = -1
            self.currentRoomInfo = nil
        }
    }
    
    // 推流
    func uploadStream(content: CVPixelBuffer) {
        guard currentRoomInfo?.call_channel_name != nil else {
            return
        }
        let buffer = AgoraVideoFrame()
        buffer.format = 12
        buffer.textureBuf = content
        buffer.time = CMTimeMakeWithSeconds(CACurrentMediaTime(), 1000)
        agoraKit?.pushExternalVideoFrame(buffer)
    }
    
    // 更新token
    func renewToken(token: String) {
        agoraKit?.renewToken(token)
    }
    
}



extension VideoConnectService: AgoraRtcEngineDelegate {
    /// 已接收到远端视频并完成解码回调。
    func rtcEngine(_ engine: AgoraRtcEngineKit, firstRemoteVideoDecodedOfUid uid: UInt, size: CGSize, elapsed: Int) {
        
        guard let roomInfo = currentRoomInfo else {
            return
        }
        
        guard let delegate = delegate else {
            return
        }
        guard roomInfo.call_channel_name.count  > 0 else {
            return
        }
        
        delegate.videoReceived(for: uid)
    }
    
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        
        guard let delegate = delegate, "\(uid)" == currentRoomInfo?.call_user_id else {
            return
        }
        
        delegate.videoUserLeave(id: uid)
    }
        
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        
        guard let delegate = delegate, "\(uid)" == currentRoomInfo?.call_user_id else {
            return
        }

        guard let view = delegate.videoRenderView(for: uid) else {
            return
        }
        
        delegate.videoUserJoined(uid: uid)

        let canvas = AgoraRtcVideoCanvas()
        canvas.uid = uid
        canvas.view = view
        canvas.renderMode = .hidden
        agoraKit?.setupRemoteVideo(canvas)
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, tokenPrivilegeWillExpire token: String) {
        guard let delegate = delegate else {
            return
        }
        delegate.tokenPrivilegeWillExpire()
    }
        
    func rtcEngine(_ engine: AgoraRtcEngineKit, connectionChangedTo state: AgoraConnectionState, reason: AgoraConnectionChangedReason) {
        if reason == .reasonBannedByServer {
            // 退出当前房间 (服务端在admin中强制关闭 房间 会回调 原因是 reasonBannedByServer)
            delegate?.videoBannedByServer()
        }
    }
    //
    func rtcEngine(_ engine: AgoraRtcEngineKit, localVideoStats stats: AgoraRtcLocalVideoStats, sourceType: AgoraVideoSourceType) {
 
    }

    // 报告实时互动统计信息。
    func rtcEngine(_ engine: AgoraRtcEngineKit, reportRtcStats stats: AgoraChannelStats) {
 
    }
    //
    func rtcEngineRequestToken(_ engine: AgoraRtcEngineKit) {

    }
    
}
