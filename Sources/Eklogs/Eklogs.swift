import Foundation
import UIKit
import SystemConfiguration
import CoreTelephony
import CoreLocation

struct SDKInfo: Codable {
    let projectId: String
    let token: String
}

public class Eklogs: NSObject {
    var logUser: String
    var logPassword: String
    var logDomain: String
    var latitude: Double?
    var longitude: Double?
    var sessionID: Date = Date()
    var locationObtained: (()->())?
    
    var sdkInfo: SDKInfo?
    
    public init(user: String, password: String, domain: String) {
        logUser = user
        logPassword = password
        logDomain = domain
        super.init()
        getInfo()
    }
    
    private func authorization() -> String {
        let loginString = String(format: "%@:%@", logUser, logPassword)
        let loginData = loginString.data(using: String.Encoding.utf8)!
        let base64LoginString = loginData.base64EncodedString()
        return base64LoginString
    }
    
    func getInfo() {
        let urlSession = URLSession.shared
        var request = EndPoint.info(logDomain).request()
        request.request.setValue("Basic \(authorization())", forHTTPHeaderField: "Authorization")
        urlSession.dataTask(request: request) { (sdkInfo: SDKInfo?) in
            self.sdkInfo = sdkInfo
            self.sessionStart()
        } failure: { (error) in
            debugPrint(error)
        }
    }
    
    func sessionStart() {
        guard let projectID = sdkInfo?.projectId else {
            debugPrint("No project ID found")
            return
        }
        var sessionData: [String: String] = [:]
        
        func start() {
            let urlSession = URLSession.shared
            let param = [
                "records": sessionData
            ]
            var request = EndPoint.log(projectID).request(body: param as [String : Any])
            request.request.setValue(sdkInfo?.token, forHTTPHeaderField: "token")
            request.request.setValue("Basic \(authorization())", forHTTPHeaderField: "Authorization")
            urlSession.dataTask(request: request) { (object: LogResponse?) in
                
            } failure: { (error) in
                debugPrint(error)
            }
        }
        
        if let data = try? Data(contentsOf: URL(string: "http://whatismyip.akamai.com/")!), let ip = String(data: data, encoding: .utf8) {
            sessionData["ipAddress"] = ip
        }
        
        UIDevice.current.isBatteryMonitoringEnabled = true
        sessionData["brand"] = "Apple"
        sessionData["device"] = UIDevice.modelName
        sessionData["deviceType"] = UIDevice.current.model
        sessionData["sessionId"] = "\(sessionID.timeIntervalSince1970)"
        sessionData["applicationid"] = Bundle.main.bundleIdentifier
        sessionData["versionNum"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        sessionData["versionCode"] = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        sessionData["locale"] = Locale.current.languageCode
        sessionData["deviceId"] = UIDevice.current.identifierForVendor?.uuidString
        sessionData["os"] = UIDevice.current.systemName
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
        guard let projectID = sdkInfo?.projectId else {
            debugPrint("No project ID found")
            return
        }
        let eventDict = [
            "eventName": eventName,
            "eventType": eventType,
            "sessionId": "\(sessionID.timeIntervalSince1970)",
            "userId":userID,
            "x": x,
            "y": y
        ]
        let param = [
            "records": eventDict
        ]
        let urlSession = URLSession.shared
        var request = EndPoint.event(projectID).request(body: param as [String : Any])
        request.request.setValue(sdkInfo?.token, forHTTPHeaderField: "token")
        request.request.setValue("Basic \(authorization())", forHTTPHeaderField: "Authorization")
        urlSession.dataTask(request: request) { (object: LogResponse?) in
            
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

extension UIDevice {

    static let modelName: String = {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }

        func mapToDevice(identifier: String) -> String { // swiftlint:disable:this cyclomatic_complexity
            #if os(iOS)
            switch identifier {
            case "iPod5,1":                                 return "iPod touch (5th generation)"
            case "iPod7,1":                                 return "iPod touch (6th generation)"
            case "iPod9,1":                                 return "iPod touch (7th generation)"
            case "iPhone3,1", "iPhone3,2", "iPhone3,3":     return "iPhone 4"
            case "iPhone4,1":                               return "iPhone 4s"
            case "iPhone5,1", "iPhone5,2":                  return "iPhone 5"
            case "iPhone5,3", "iPhone5,4":                  return "iPhone 5c"
            case "iPhone6,1", "iPhone6,2":                  return "iPhone 5s"
            case "iPhone7,2":                               return "iPhone 6"
            case "iPhone7,1":                               return "iPhone 6 Plus"
            case "iPhone8,1":                               return "iPhone 6s"
            case "iPhone8,2":                               return "iPhone 6s Plus"
            case "iPhone8,4":                               return "iPhone SE"
            case "iPhone9,1", "iPhone9,3":                  return "iPhone 7"
            case "iPhone9,2", "iPhone9,4":                  return "iPhone 7 Plus"
            case "iPhone10,1", "iPhone10,4":                return "iPhone 8"
            case "iPhone10,2", "iPhone10,5":                return "iPhone 8 Plus"
            case "iPhone10,3", "iPhone10,6":                return "iPhone X"
            case "iPhone11,2":                              return "iPhone XS"
            case "iPhone11,4", "iPhone11,6":                return "iPhone XS Max"
            case "iPhone11,8":                              return "iPhone XR"
            case "iPhone12,1":                              return "iPhone 11"
            case "iPhone12,3":                              return "iPhone 11 Pro"
            case "iPhone12,5":                              return "iPhone 11 Pro Max"
            case "iPhone12,8":                              return "iPhone SE (2nd generation)"
            case "iPhone13,1":                              return "iPhone 12 mini"
            case "iPhone13,2":                              return "iPhone 12"
            case "iPhone13,3":                              return "iPhone 12 Pro"
            case "iPhone13,4":                              return "iPhone 12 Pro Max"
            case "iPad2,1", "iPad2,2", "iPad2,3", "iPad2,4":return "iPad 2"
            case "iPad3,1", "iPad3,2", "iPad3,3":           return "iPad (3rd generation)"
            case "iPad3,4", "iPad3,5", "iPad3,6":           return "iPad (4th generation)"
            case "iPad6,11", "iPad6,12":                    return "iPad (5th generation)"
            case "iPad7,5", "iPad7,6":                      return "iPad (6th generation)"
            case "iPad7,11", "iPad7,12":                    return "iPad (7th generation)"
            case "iPad11,6", "iPad11,7":                    return "iPad (8th generation)"
            case "iPad4,1", "iPad4,2", "iPad4,3":           return "iPad Air"
            case "iPad5,3", "iPad5,4":                      return "iPad Air 2"
            case "iPad11,3", "iPad11,4":                    return "iPad Air (3rd generation)"
            case "iPad13,1", "iPad13,2":                    return "iPad Air (4th generation)"
            case "iPad2,5", "iPad2,6", "iPad2,7":           return "iPad mini"
            case "iPad4,4", "iPad4,5", "iPad4,6":           return "iPad mini 2"
            case "iPad4,7", "iPad4,8", "iPad4,9":           return "iPad mini 3"
            case "iPad5,1", "iPad5,2":                      return "iPad mini 4"
            case "iPad11,1", "iPad11,2":                    return "iPad mini (5th generation)"
            case "iPad6,3", "iPad6,4":                      return "iPad Pro (9.7-inch)"
            case "iPad7,3", "iPad7,4":                      return "iPad Pro (10.5-inch)"
            case "iPad8,1", "iPad8,2", "iPad8,3", "iPad8,4":return "iPad Pro (11-inch) (1st generation)"
            case "iPad8,9", "iPad8,10":                     return "iPad Pro (11-inch) (2nd generation)"
            case "iPad6,7", "iPad6,8":                      return "iPad Pro (12.9-inch) (1st generation)"
            case "iPad7,1", "iPad7,2":                      return "iPad Pro (12.9-inch) (2nd generation)"
            case "iPad8,5", "iPad8,6", "iPad8,7", "iPad8,8":return "iPad Pro (12.9-inch) (3rd generation)"
            case "iPad8,11", "iPad8,12":                    return "iPad Pro (12.9-inch) (4th generation)"
            case "AppleTV5,3":                              return "Apple TV"
            case "AppleTV6,2":                              return "Apple TV 4K"
            case "AudioAccessory1,1":                       return "HomePod"
            case "AudioAccessory5,1":                       return "HomePod mini"
            case "i386", "x86_64":                          return "Simulator \(mapToDevice(identifier: ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "iOS"))"
            default:                                        return identifier
            }
            #elseif os(tvOS)
            switch identifier {
            case "AppleTV5,3": return "Apple TV 4"
            case "AppleTV6,2": return "Apple TV 4K"
            case "i386", "x86_64": return "Simulator \(mapToDevice(identifier: ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "tvOS"))"
            default: return identifier
            }
            #endif
        }

        return mapToDevice(identifier: identifier)
    }()

}
