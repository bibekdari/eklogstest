import Foundation
import UIKit
import SystemConfiguration
import CoreTelephony
import CoreLocation

public class Eklogs: NSObject {
    let uploadLog = "ekmobile-bigmart-dev"
    let eventLog="ekmobile-bigmart-event-dev"
    let baseURL = "https://drk.ekbana.net/topics/"
    let logUser = "drk"
    let logPassword = "Drk@ekbana31"
    var latitude: Double?
    var longitude: Double?
    var sessionID: Date = Date()
    var locationObtained: (()->())?
    
    public override init() {
        super.init()
        sessionStart()
    }
    
    public func sessionStart() {
        var sessionData: [String: String?] = [:]
        
        func start() {
            let urlSession = URLSession.shared
            let request = EndPoint.log.request(body: sessionData as [String : Any])
            urlSession.dataTask(request: request) { (object: String) in
                
            } failure: { (error) in
                debugPrint(error)
            }
        }
        
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        sessionData["sessionId"] = "\(sessionID.timeIntervalSince1970)"
        sessionData["applicationid"] = Bundle.main.bundleIdentifier
        sessionData["versionNum"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        sessionData["versionCode"] = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        sessionData["locale"] = Locale.current.languageCode
        sessionData["deviceId"] = UIDevice.current.identifierForVendor?.uuidString
        sessionData["osType"] = UIDevice.current.systemName
        sessionData["osVersion"] = UIDevice.current.systemVersion
        sessionData["height"] = "\(UIScreen.main.bounds.height)"
        sessionData["width"] = "\(UIScreen.main.bounds.width)"
        sessionData["orientation"] = UIDevice.current.orientation.isPortrait ? "portrait" : "landscape"
        sessionData["batteryLevel"] = "\(UIDevice.current.batteryLevel * 100)"
        //UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.phone ? "iOS"
        let nt = networkType()
        sessionData["network"] = nt
        sessionData["connectedToNetwork"] = "\(nt != nil)"
        sessionData["internalMemTotal"] = "\(ProcessInfo.processInfo.physicalMemory)"
        sessionData["internalMemAvail"] = "\(freeMemory())"
        sessionData["isLowPowerModeEnabled"] = "\(ProcessInfo.processInfo.isLowPowerModeEnabled)"
        
        sessionData["carrier"] = CTTelephonyNetworkInfo().subscriberCellularProvider?.carrierName
        
        let locationAuthorizationStatus =  CLLocationManager.authorizationStatus()
        
        if locationAuthorizationStatus == .authorizedAlways || locationAuthorizationStatus == .authorizedWhenInUse {
            let locationManager = CLLocationManager()
            locationManager.delegate = self
            locationManager.requestLocation()
            locationObtained = { [weak self] in
                if let latitude = self?.latitude, let longitude = self?.longitude {
                    sessionData["latitude"] = "\(latitude)"
                    sessionData["longitude"] = "\(longitude)"
                }
                start()
                self?.locationObtained = nil
            }
        }else {
            start()
        }
    }
    
    public func log(eventName: String, eventType: String, userID: String?, x: String, y: String) {
        let eventDict = [
            "eventName": eventName,
            "eventType": eventType,
            "sessionId": "\(sessionID.timeIntervalSince1970)",
            "userId":userID,
            "x": x,
            "y": y
        ]
        let urlSession = URLSession.shared
        let request = EndPoint.event.request(body: eventDict as [String : Any])
        urlSession.dataTask(request: request) { (object: String) in
            
        } failure: { (error) in
            debugPrint(error)
        }
    }
    
    private func networkType() -> String? {
        
        var zeroAddress = sockaddr_in(sin_len: 0, sin_family: 0, sin_port: 0, sin_addr: in_addr(s_addr: 0), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)

        let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }

        var flags: SCNetworkReachabilityFlags = SCNetworkReachabilityFlags(rawValue: 0)
        if SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) == false {
            return nil
        }

        // Only Working for WIFI
        var isReachable = flags == .reachable
        var needsConnection = flags == .connectionRequired

        let wifiReachable = isReachable && !needsConnection
        
        if wifiReachable {
            return "WIFI"
        }

        // Working for Cellular and WIFI
        isReachable = (flags.rawValue & UInt32(kSCNetworkFlagsReachable)) != 0
        needsConnection = (flags.rawValue & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
        let cellularReachable = (isReachable && !needsConnection)

        if cellularReachable {
            return "Cellular"
        }
        return nil
    }
    
    private func freeMemory() -> Int64 {
        var pagesize: vm_size_t = 0

        let host_port: mach_port_t = mach_host_self()
        var host_size: mach_msg_type_number_t = mach_msg_type_number_t(MemoryLayout<vm_statistics_data_t>.stride / MemoryLayout<integer_t>.stride)
        host_page_size(host_port, &pagesize)

        var vm_stat: vm_statistics = vm_statistics_data_t()
        withUnsafeMutablePointer(to: &vm_stat) { (vmStatPointer) -> Void in
            vmStatPointer.withMemoryRebound(to: integer_t.self, capacity: Int(host_size)) {
                if (host_statistics(host_port, HOST_VM_INFO, $0, &host_size) != KERN_SUCCESS) {
                    NSLog("Error: Failed to fetch vm statistics")
                }
            }
        }

        /* Stats in bytes */
//        let mem_used: Int64 = Int64(vm_stat.active_count +
//                vm_stat.inactive_count +
//                vm_stat.wire_count) * Int64(pagesize)
        let mem_free: Int64 = Int64(vm_stat.free_count) * Int64(pagesize)
        return mem_free
    }
}


extension Eklogs: CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        latitude = locations.first?.coordinate.latitude
        longitude = locations.first?.coordinate.longitude
        locationObtained?()
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationObtained?()
    }
}
