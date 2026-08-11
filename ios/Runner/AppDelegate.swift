import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var firebaseConfigChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "StarForgeFirebaseConfigProbe"
    ) else { return }
    let channel = FlutterMethodChannel(
      name: "com.starforge.ceo_manager/firebase_config",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "hasNativeFirebaseConfig" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil)
    }
    firebaseConfigChannel = channel
  }
}
