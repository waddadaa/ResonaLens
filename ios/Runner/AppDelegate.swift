import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    private let CHANNEL = "com.example.resonalens/mediapipe"
    private let gemmaHelper = GemmaModelHelper.shared()
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        
        guard let controller = window?.rootViewController as? FlutterViewController else {
            fatalError("rootViewController is not type FlutterViewController")
        }
        
        let methodChannel = FlutterMethodChannel(name: CHANNEL, binaryMessenger: controller.binaryMessenger)
        
        methodChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            self?.handleMethodCall(call: call, result: result)
        }
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    private func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initializeModel":
            handleInitializeModel(call: call, result: result)
        case "generateText":
            handleGenerateText(call: call, result: result)
        case "generateFromImage":
            handleGenerateFromImage(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func handleInitializeModel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let modelPath = args["modelPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Model path is required", details: nil))
            return
        }
        
        let enableVisionModality = args["enableVisionModality"] as? Bool ?? true
        let enableAudioModality = args["enableAudioModality"] as? Bool ?? true
        
        print("AppDelegate: Initializing model at path: \(modelPath)")
        print("AppDelegate: Vision modality: \(enableVisionModality), Audio modality: \(enableAudioModality)")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let success = self?.gemmaHelper.initializeModel(
                modelPath: modelPath,
                enableVisionModality: enableVisionModality,
                enableAudioModality: enableAudioModality
            ) ?? false
            
            DispatchQueue.main.async {
                if success {
                    print("AppDelegate: Model initialization successful")
                    result(true)
                } else {
                    print("AppDelegate: Model initialization failed")
                    result(FlutterError(code: "INITIALIZATION_FAILED", message: "Failed to initialize model", details: nil))
                }
            }
        }
    }
    
    private func handleGenerateText(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let prompt = args["prompt"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Prompt is required", details: nil))
            return
        }
        
        if !gemmaHelper.isInitialized() {
            result(FlutterError(code: "MODEL_NOT_INITIALIZED", message: "Model is not initialized", details: nil))
            return
        }
        
        print("AppDelegate: Generating text for prompt: \(prompt)")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.gemmaHelper.generateResponse(
                prompt: prompt,
                images: nil,
                completion: { response in
                    print("AppDelegate: Text generation successful, response length: \(response.count)")
                    result(response)
                },
                errorCompletion: { error in
                    print("AppDelegate: Text generation failed: \(error)")
                    result(FlutterError(code: "INFERENCE_ERROR", message: error, details: nil))
                }
            )
        }
    }
    
    private func handleGenerateFromImage(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let prompt = args["prompt"] as? String,
              let imagePath = args["imagePath"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Prompt and image path are required", details: nil))
            return
        }
        
        if !gemmaHelper.isInitialized() {
            result(FlutterError(code: "MODEL_NOT_INITIALIZED", message: "Model is not initialized", details: nil))
            return
        }
        
        print("AppDelegate: Generating from image - prompt: \(prompt), imagePath: \(imagePath)")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            if let image = self.gemmaHelper.loadImageFromPath(imagePath) {
                print("AppDelegate: Image loaded successfully, calling generateResponse with image")
                
                self.gemmaHelper.generateResponse(
                    prompt: prompt,
                    images: [image],
                    completion: { response in
                        print("AppDelegate: Image generation successful, response length: \(response.count)")
                        result(response)
                    },
                    errorCompletion: { error in
                        print("AppDelegate: Image generation failed: \(error)")
                        result(FlutterError(code: "INFERENCE_ERROR", message: error, details: nil))
                    }
                )
            } else {
                print("AppDelegate: Failed to load image from path: \(imagePath)")
                result(FlutterError(code: "IMAGE_LOAD_ERROR", message: "Failed to load image from path: \(imagePath)", details: nil))
            }
        }
    }
}
