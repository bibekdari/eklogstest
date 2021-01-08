//
//  ViewController.swift
//  TestEkLog
//
//  Created by bibek timalsina on 07/01/2021.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    @IBAction func clicked(_ sender: UIButton) {
        let logger = (UIApplication.shared.delegate as? AppDelegate)?.logger
        logger?.log(eventName: "click", eventType: "AdButton", userID: nil, x: "\(sender.frame.midX)", y: "\(sender.frame.midY)")
    }
    
}

