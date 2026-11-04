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

    // Canal usado pela navegação para manter a tela ligada
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RotasTela") {
      let canal = FlutterMethodChannel(
        name: "rotas_app/tela",
        binaryMessenger: registrar.messenger()
      )
      canal.setMethodCallHandler { call, result in
        if call.method == "manterLigada" {
          let ligar = (call.arguments as? Bool) ?? false
          DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = ligar
          }
          result(nil)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }
}
