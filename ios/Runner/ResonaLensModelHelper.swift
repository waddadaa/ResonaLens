import Foundation
import UIKit
import MediaPipeTasksGenAI

@objc class GemmaModelHelper: NSObject {
    private static var instance: GemmaModelHelper?
    private var llmInference: LlmInference?
    private var llmSession: LlmInferenceSession?
    
    @objc static func shared() -> GemmaModelHelper {
        if instance == nil {
            instance = GemmaModelHelper()
        }
        return instance!
    }
    
    private override init() {
        super.init()
    }
    
    @objc func initializeModel(
        modelPath: String,
        enableVisionModality: Bool = true,
        enableAudioModality: Bool = true
    ) -> Bool {
        do {
            // Check if model file exists
            guard FileManager.default.fileExists(atPath: modelPath) else {
                print("GemmaModelHelper: Model file not found at: \(modelPath)")
                return false
            }
            
            // Create LLM Inference options
            let options = LlmInference.LlmInferenceOptions()
            options.modelPath = modelPath
            options.maxTokens = 2048
            options.maxNumImages = enableVisionModality ? 1 : 0
            
            // Create LLM Inference instance
            llmInference = try LlmInference(options: options)
            
            // Create session options
            let sessionOptions = LlmInferenceSession.LlmInferenceSessionOptions()
            sessionOptions.topK = 40
            sessionOptions.temperature = 0.8
            
            // Enable vision modality if needed
            if enableVisionModality {
                print("GemmaModelHelper: Enabling vision modality")
                let graphOptions = GraphOptions()
                graphOptions.enableVisionModality = true
                sessionOptions.graphOptions = graphOptions
            }
            
            // Create session
            llmSession = try LlmInferenceSession(llmInference: llmInference!, options: sessionOptions)
            
            print("GemmaModelHelper: Model initialized successfully")
            return true
            
        } catch {
            print("GemmaModelHelper: Failed to initialize model: \(error.localizedDescription)")
            return false
        }
    }
    
    @objc func generateResponse(
        prompt: String,
        images: [UIImage]? = nil,
        completion: @escaping (String) -> Void,
        errorCompletion: @escaping (String) -> Void
    ) {
        guard let session = llmSession else {
            errorCompletion("Model not initialized")
            return
        }
        
        do {
            if let images = images, !images.isEmpty {
                // For multimodal input with images
                print("GemmaModelHelper: Adding \(images.count) images to session")
                
                // Add the text prompt first (required order)
                try session.addQueryChunk(prompt)
                print("GemmaModelHelper: Added text prompt: \(prompt)")
                
                // Then add images
                for image in images {
                    let mpImage = try MPImage(uiImage: image)
                    try session.addImage(mpImage)
                    print("GemmaModelHelper: Added image to session: \(image.size.width)x\(image.size.height)")
                }
            } else {
                // Add text prompt only
                try session.addQueryChunk(prompt)
                print("GemmaModelHelper: Added text-only prompt: \(prompt)")
            }
            
            // Generate response asynchronously
            let fullResponse = NSMutableString()
            session.generateResponseAsync { partialResult, done in
                if let partialResult = partialResult {
                    fullResponse.append(partialResult)
                }
                if done {
                    DispatchQueue.main.async {
                        completion(fullResponse as String)
                    }
                }
            }
            
        } catch {
            errorCompletion("Inference failed: \(error.localizedDescription)")
        }
    }
    
    @objc func generateTextSync(prompt: String) -> String? {
        guard let session = llmSession else {
            return nil
        }
        
        do {
            try session.addQueryChunk(prompt)
            let response = NSMutableString()
            var isComplete = false
            
            session.generateResponseAsync { partialResult, done in
                if let partialResult = partialResult {
                    response.append(partialResult)
                }
                if done {
                    isComplete = true
                }
            }
            
            // Wait for completion (simple blocking approach)
            while !isComplete {
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
            }
            
            return response as String
            
        } catch {
            print("GemmaModelHelper: Text generation failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    @objc func loadImageFromPath(_ imagePath: String) -> UIImage? {
        print("GemmaModelHelper: Loading image from path: \(imagePath)")
        
        guard FileManager.default.fileExists(atPath: imagePath) else {
            print("GemmaModelHelper: Image file does not exist at path: \(imagePath)")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: imagePath))
            let image = UIImage(data: data)
            
            if let image = image {
                print("GemmaModelHelper: Image loaded successfully, size: \(image.size.width)x\(image.size.height)")
                return image
            } else {
                print("GemmaModelHelper: Failed to create UIImage from data")
                return nil
            }
        } catch {
            print("GemmaModelHelper: Error loading image: \(error.localizedDescription)")
            return nil
        }
    }
    
    @objc func isInitialized() -> Bool {
        return llmInference != nil && llmSession != nil
    }
    
    @objc func cleanup() {
        llmSession = nil
        llmInference = nil
        print("GemmaModelHelper: Cleaned up resources")
    }
    
    deinit {
        cleanup()
    }
}
