package com.example.resonalens

import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.resonalens/mediapipe"
    private lateinit var gemmaHelper: GemmaModelHelper
    private val mainHandler = Handler(Looper.getMainLooper())
    
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        gemmaHelper = GemmaModelHelper.getInstance()
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initializeModel" -> {
                    val modelPath = call.argument<String>("modelPath")
                    val enableVision = call.argument<Boolean>("enableVision") ?: true
                    
                    if (modelPath != null) {
                        Thread {
                            val success = gemmaHelper.initializeModel(this, modelPath, enableVision)
                            mainHandler.post {
                                result.success(success)
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGUMENTS", "Model path is required", null)
                    }
                }
                
                "generateText" -> {
                    val prompt = call.argument<String>("prompt")
                    
                    if (prompt != null) {
                        if (!gemmaHelper.isInitialized()) {
                            result.error("MODEL_NOT_INITIALIZED", "Model is not initialized", null)
                            return@setMethodCallHandler
                        }
                        
                        gemmaHelper.generateResponse(
                            prompt = prompt,
                            callback = { response -> 
                                mainHandler.post {
                                    result.success(response)
                                }
                            },
                            errorCallback = { error -> 
                                mainHandler.post {
                                    result.error("INFERENCE_ERROR", error, null)
                                }
                            }
                        )
                    } else {
                        result.error("INVALID_ARGUMENTS", "Prompt is required", null)
                    }
                }
                
                "generateFromImage" -> {
                    val prompt = call.argument<String>("prompt")
                    val imagePath = call.argument<String>("imagePath")
                    
                    if (prompt != null && imagePath != null) {
                        if (!gemmaHelper.isInitialized()) {
                            result.error("MODEL_NOT_INITIALIZED", "Model is not initialized", null)
                            return@setMethodCallHandler
                        }
                        
                        Thread {
                            println("MainActivity: Loading image from path: $imagePath")
                            val mpImage = gemmaHelper.loadImageFromPath(imagePath)
                            if (mpImage != null) {
                                println("MainActivity: Image loaded successfully, calling generateResponse with image")
                                gemmaHelper.generateResponse(
                                    prompt = prompt,
                                    images = listOf(mpImage),
                                    callback = { response -> 
                                        println("MainActivity: Received response: $response")
                                        mainHandler.post {
                                            result.success(response)
                                        }
                                    },
                                    errorCallback = { error -> 
                                        println("MainActivity: Error in generateResponse: $error")
                                        mainHandler.post {
                                            result.error("INFERENCE_ERROR", error, null)
                                        }
                                    }
                                )
                            } else {
                                println("MainActivity: Failed to load image from path: $imagePath")
                                mainHandler.post {
                                    result.error("IMAGE_LOAD_ERROR", "Failed to load image from path: $imagePath", null)
                                }
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGUMENTS", "Prompt and image path are required", null)
                    }
                }
                
                "generateFromAudio" -> {
                    val prompt = call.argument<String>("prompt")
                    val audioPath = call.argument<String>("audioPath")
                    
                    if (prompt != null && audioPath != null) {
                        if (!gemmaHelper.isInitialized()) {
                            result.error("MODEL_NOT_INITIALIZED", "Model is not initialized", null)
                            return@setMethodCallHandler
                        }
                        
                        Thread {
                            println("MainActivity: Loading audio from path: $audioPath")
                            val audioData = gemmaHelper.loadAudioFromPath(audioPath)
                            if (audioData != null && audioData.isNotEmpty()) {
                                println("MainActivity: Audio loaded successfully, calling generateResponse with audio")
                                gemmaHelper.generateResponse(
                                    prompt = prompt,
                                    audioData = audioData,
                                    callback = { response -> 
                                        println("MainActivity: Received audio response: $response")
                                        mainHandler.post {
                                            result.success(response)
                                        }
                                    },
                                    errorCallback = { error -> 
                                        println("MainActivity: Error in audio generateResponse: $error")
                                        mainHandler.post {
                                            result.error("INFERENCE_ERROR", error, null)
                                        }
                                    }
                                )
                            } else {
                                println("MainActivity: Failed to load audio from path: $audioPath")
                                // Fallback to text-only processing with audio description
                                val audioPrompt = "$prompt [Note: Audio file at $audioPath could not be processed directly]"
                                gemmaHelper.generateResponse(
                                    prompt = audioPrompt,
                                    callback = { response -> 
                                        mainHandler.post {
                                            result.success("I received an audio file but couldn't process it directly. Here's my response based on your prompt: $response")
                                        }
                                    },
                                    errorCallback = { error -> 
                                        mainHandler.post {
                                            result.error("AUDIO_PROCESSING_ERROR", "Failed to process audio: $error", null)
                                        }
                                    }
                                )
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGUMENTS", "Prompt and audio path are required", null)
                    }
                }
                
                "isModelInitialized" -> {
                    result.success(gemmaHelper.isInitialized())
                }
                
                "cleanupModel" -> {
                    gemmaHelper.cleanup()
                    result.success(true)
                }
                
                else -> result.notImplemented()
            }
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        if (::gemmaHelper.isInitialized) {
            gemmaHelper.cleanup()
        }
    }
}
