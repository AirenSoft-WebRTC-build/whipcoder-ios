//
//  AppDelegate.swift
//  WHIPCoder
//
//  Created by dimiden on 5/7/24.
//

import UIKit
import WebRTC

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // RTCSetMinDebugLogLevel(RTCLoggingSeverity.verbose)

        RTCInitFieldTrialDictionary([
            "WebRTC-LegacySimulcastLayerLimit": "Disabled",
            "WebRTC-SpsPpsIdrIsH264Keyframe": "Enabled",
            "WebRTC-VideoLayersAllocationAdvertised": "Enabled",
        ])

        RTCInitializeSSL()
        RTCSetupInternalTracer()

        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func applicationWillTerminate(_ application: UIApplication) {
        RTCShutdownInternalTracer()
        RTCCleanupSSL()
    }
}
