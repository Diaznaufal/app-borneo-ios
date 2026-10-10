import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  override func application(
    _ application: UIApplication,
    supportedInterfaceOrientationsFor window: UIWindow?
  ) -> UIInterfaceOrientationMask {
    return .landscape
  }
}

// Override controller utama agar identik dengan game engine (menolak rotasi)
extension FlutterViewController {
  // Matikan autorotate total
  open override var shouldAutorotate: Bool {
    return false
  }

  open override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    return .landscape
  }

  open override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
    return .landscapeLeft
  }

  // Sembunyikan status bar bawaan iOS
  open override var prefersStatusBarHidden: Bool {
    return true
  }
}