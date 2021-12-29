import Flutter
import UIKit
import FBSDKCoreKit
import FBSDKCoreKit_Basics
import FBAudienceNetwork

public class SwiftFacebookAppEventsPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    
    var _eventSink: FlutterEventSink?
    var _deepLinkUrl: String = ""
    var _queuedLinks = [String]()
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        _eventSink = events
        _queuedLinks.forEach({ events($0) })
        _queuedLinks.removeAll()
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        _eventSink = nil
        return nil
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter.oddbit.id/facebook_app_events/methods", binaryMessenger: registrar.messenger())
        
        let eventChannel = FlutterEventChannel(name: "flutter.oddbit.id/facebook_app_events/events", binaryMessenger: registrar.messenger())
        
        let instance = SwiftFacebookAppEventsPlugin()
        
        eventChannel.setStreamHandler(instance)

        // Required for FB SDK 9.0, as it does not initialize the SDK automatically any more.
        // See: https://developers.facebook.com/blog/post/2021/01/19/introducing-facebook-platform-sdk-version-9/
        // "Removal of Auto Initialization of SDK" section
        ApplicationDelegate.shared.initializeSDK()

        registrar.addApplicationDelegate(instance)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    

    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [AnyHashable : Any] = [:]) -> Bool {
        let launchOptionsForFacebook = launchOptions as? [UIApplication.LaunchOptionsKey: Any]
        ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions:
                launchOptionsForFacebook
        )
        AppLinkUtility.fetchDeferredAppLink{ (url, error) in
            if let error = error {
                print("Error %a", error)
            }
            if let url = url {
                self._deepLinkUrl = url.absoluteString
                self.sendMessageToStream(link: self._deepLinkUrl)
            }
            
        }
        return true
    }
    
    public func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        self._deepLinkUrl = url.absoluteString
        self.sendMessageToStream(link: self._deepLinkUrl)
        return ApplicationDelegate.shared.application(application, open: url, sourceApplication: options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String, annotation: options[UIApplication.OpenURLOptionsKey.annotation])
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getDeepLinkUrl":
            handleGetDeepLinkUrl(call, result: result)
            break;
        case "clearUserData":
            handleClearUserData(call, result: result)
            break
        case "clearUserID":
            handleClearUserID(call, result: result)
            break
        case "flush":
            handleFlush(call, result: result)
            break
        case "getApplicationId":
            handleGetApplicationId(call, result: result)
            break
        case "logEvent":
            handleLogEvent(call, result: result)
            break
        case "logPushNotificationOpen":
            handlePushNotificationOpen(call, result: result)
            break
        case "setUserID":
            handleSetUserId(call, result: result)
            break
        case "setAutoLogAppEventsEnabled":
            handleSetAutoLogAppEventsEnabled(call, result: result)
            break
        case "setDataProcessingOptions":
            handleSetDataProcessingOptions(call, result: result)
            break
        case "logPurchase":
            handlePurchased(call, result: result)
            break
        case "getAnonymousId":
            handleHandleGetAnonymousId(call, result: result)
            break
        case "setAdvertiserTracking":
            handleSetAdvertiserTracking(call, result: result)
            break
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    func sendMessageToStream(link: String) {
        guard let eventSink = _eventSink else {
            _queuedLinks.append(link)
            return
        }
        eventSink(link);
    }
    
    private func handleGetDeepLinkUrl(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        result(_deepLinkUrl);
    }

    private func handleClearUserData(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        AppEvents.clearUserData()
        result(nil)
    }

    private func handleClearUserID(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        AppEvents.clearUserID()
        result(nil)
    }

    private func handleFlush(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        AppEvents.flush()
        result(nil)
    }

    private func handleGetApplicationId(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        result(Settings.appID)
    }

    private func handleHandleGetAnonymousId(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        result(AppEvents.anonymousID)
    }

    private func handleLogEvent(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? [String: Any] ?? [String: Any]()
        let eventName = arguments["name"] as! String
        let parameters = arguments["parameters"] as? [AppEvents.ParameterName: Any] ?? [AppEvents.ParameterName: Any]()
        if arguments["_valueToSum"] != nil && !(arguments["_valueToSum"] is NSNull) {
            let valueToDouble = arguments["_valueToSum"] as! Double
            AppEvents.logEvent(AppEvents.Name(eventName), valueToSum: valueToDouble, parameters: parameters)
        } else {
            AppEvents.logEvent(AppEvents.Name(eventName), parameters: parameters)
        }

        result(nil)
    }

    private func handlePushNotificationOpen(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? [String: Any] ?? [String: Any]()
        let payload = arguments["payload"] as? [String: Any]
        if let action = arguments["action"] {
            let actionString = action as! String
            AppEvents.logPushNotificationOpen(payload!, action: actionString)
        } else {
            AppEvents.logPushNotificationOpen(payload!)
        }

        result(nil)
    }

    private func handleSetUserId(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let id = call.arguments as! String
        AppEvents.userID = id
        result(nil)
    }

    private func handleSetAutoLogAppEventsEnabled(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let enabled = call.arguments as! Bool
        Settings.isAutoLogAppEventsEnabled = enabled
        result(nil)
    }

    private func handleSetDataProcessingOptions(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? [String: Any] ?? [String: Any]()
        let modes = arguments["options"] as? [String] ?? []
        let state = arguments["state"] as? Int32 ?? 0
        let country = arguments["country"] as? Int32 ?? 0

        Settings.setDataProcessingOptions(modes, country: country, state: state)

        result(nil)
    }

    private func handlePurchased(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? [String: Any] ?? [String: Any]()
        let amount = arguments["amount"] as! Double
        let currency = arguments["currency"] as! String
        let parameters = arguments["parameters"] as? [String: Any] ?? [String: Any]()
        AppEvents.logPurchase(amount, currency: currency, parameters: parameters)

        result(nil)
    }

    private func handleSetAdvertiserTracking(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? [String: Any] ?? [String: Any]()
        let enabled = arguments["enabled"] as! Bool
        let collectId = arguments["collectId"] as! Bool
        Settings.setAdvertiserTrackingEnabled(enabled)
        Settings.isAdvertiserIDCollectionEnabled = collectId
        result(nil)
    }
}
