//
//  Reachability.swift
//  LiveStreamService
//
//  Created by xcode on 2024/2/29.
//

import Foundation
import CoreTelephony
import Alamofire

public enum ReachabilityStatus {
    case unKnown
    case notReachable
    case ethernetOrWiFi
    case cellular
}

class Reachability {
    public static let shared = Reachability()
    /// Network reachability manager
    var reachability: NetworkReachabilityManager?
    /// 网络状态
    var networkStatus: ReachabilityStatus = .unKnown
    /// 蜂窝网络下网络状态
    var networkCellularStatus: String = "unKnown"
    /// 是否可以请求网络（是否有网）
    var enableNetWork: Bool {
        return networkStatus != .notReachable && networkStatus != .unKnown
    }
    
    
    public func startMonitoring() {
        if reachability == nil {
            reachability = NetworkReachabilityManager.default
        }

        reachability?.startListening(onQueue: .main, onUpdatePerforming: { [unowned self] status in
            switch status {
            case .notReachable:
                self.networkStatus = .notReachable
            case .unknown:
                self.networkStatus = .unKnown
            case .reachable(.ethernetOrWiFi):
                self.networkStatus = .ethernetOrWiFi
            case .reachable(.cellular):
                self.networkStatus = .cellular

                let info = CTTelephonyNetworkInfo()
                var currentStatus: String?
                var currentNet: String = "unKnown"

                // ios 12.0之前 currentStatus = info.currentRadioAccessTechnology
                if let radioDic = info.serviceCurrentRadioAccessTechnology {
                    for (_, value) in radioDic {
                        if currentStatus == nil {
                            currentStatus = value
                            break
                        }
                    }
                }

                guard let _ = currentStatus else {
                    self.networkCellularStatus = currentNet
                    break
                }

                if currentStatus == CTRadioAccessTechnologyGPRS {
                    currentNet = "GPRS"
                } else if currentStatus == CTRadioAccessTechnologyEdge {
                    currentNet = "2.75G"
                } else if currentStatus == CTRadioAccessTechnologyWCDMA {
                    currentNet = "3G"
                } else if currentStatus == CTRadioAccessTechnologyHSDPA {
                    currentNet = "3.5G"
                } else if currentStatus == CTRadioAccessTechnologyHSUPA {
                    currentNet = "3.5G"
                } else if currentStatus == CTRadioAccessTechnologyCDMA1x {
                    currentNet = "2G"
                } else if currentStatus == CTRadioAccessTechnologyCDMAEVDORev0 {
                    currentNet = "3G"
                } else if currentStatus == CTRadioAccessTechnologyCDMAEVDORevA {
                    currentNet = "3G"
                } else if currentStatus == CTRadioAccessTechnologyCDMAEVDORevB {
                    currentNet = "3G"
                } else if currentStatus == CTRadioAccessTechnologyeHRPD {
                    currentNet = "HRPD"
                } else if currentStatus == CTRadioAccessTechnologyLTE {
                    currentNet = "4G"
                } else if #available(iOS 14.1, *) {
                    if currentStatus == CTRadioAccessTechnologyNRNSA {
                        currentNet = "5G"
                    } else if currentStatus == CTRadioAccessTechnologyNR {
                        currentNet = "5G"
                    }
                }

                self.networkCellularStatus = currentNet
                break
            }
            // Sent notification
//            NotificationCenter.default.post(name: Constant.notification.networkStatus, object: nil)
        })
    }
    
    /// Stops monitoring for changes in network reachability status.
    public func stopMonitoring() {
        guard reachability != nil else { return }
        reachability?.stopListening()
    }
}
