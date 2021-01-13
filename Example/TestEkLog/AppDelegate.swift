//
//  AppDelegate.swift
//  TestEkLog
//
//  Created by bibek timalsina on 07/01/2021.
//

import UIKit
import Eklogs

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var logger: Eklogs?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        let logUser = "sdkuser"
        let logPassword = "3kl0gS5Dk!@#"
        let domain = "bigmart-mobile"
        logger = Eklogs(user: logUser, password: logPassword, domain: domain)
        return true
    }

}

