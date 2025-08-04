package com.example.resonalens

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Log
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.tasks.genai.llminference.LlmInference
import com.google.mediapipe.tasks.genai.llminference.LlmInferenceSession
import com.google.mediapipe.tasks.genai.llminference.GraphOptions
import java.io.File

class GemmaModelHelper private constructor() {
    companion object {
        private var instance: GemmaModelHelper? = null
        private var llmInference: LlmInference? = null
        private var llmSession: LlmInferenceSession? = null
        
        fun getInstance(): GemmaModelHelper {
            return instance ?: synchronized(this) {
                instance ?: GemmaModelHelper().also { instance = it }
            }
        }
    }
    
    fun initializeModel(
        context: Context,
        modelPath: String,
        enableVisionModality: Boolean = true,
        enableAudioModality: Boolean = true
    ): Boolean {
        return try {
            // Check if model file exists
            val modelFile = File(modelPath)
            if (!modelFile.exists()) {
                throw Exception("Model file not found at: $modelPath")
            }
            
            // Create LLM Inference instance
            val options = LlmInference.LlmInferenceOptions.builder()
                .setModelPath(modelPath)
                .setMaxTokens(2048)
                .setMaxNumImages(if (enableVisionModality) 1 else 0)
                .build()
            
            llmInference = LlmInference.createFromOptions(context, options)
            
            // Create session with configuration
            val sessionOptionsBuilder = LlmInferenceSession.LlmInferenceSessionOptions.builder()
                .setTopK(40)
                .setTemperature(0.8f)
            
            // Enable multimodal capabilities if needed
            if (enableVisionModality) {
                Log.d("GemmaModelHelper", "Enabling vision modality")
                sessionOptionsBuilder.setGraphOptions(
                    GraphOptions.builder()
                        .setEnableVisionModality(true)
                        .build()
                )
            }
            
            llmSession = LlmInferenceSession.createFromOptions(
                llmInference!!,
                sessionOptionsBuilder.build()
            )
            
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
    
    fun generateResponse(
        prompt: String,
        images: List<MPImage>? = null,
        callback: (String) -> Unit,
        errorCallback: (String) -> Unit
    ) {
        llmSession?.let { session ->
            try {
                if (images != null && images.isNotEmpty()) {
                    // For multimodal input with images
                    Log.d("GemmaModelHelper", "Adding ${images.size} images to session")
                    // Add the text prompt first (required order)
                    session.addQueryChunk(prompt)
                    Log.d("GemmaModelHelper", "Added text prompt: $prompt")
                    // Then add images
                    for (image in images) {
                        session.addImage(image)
                        Log.d("GemmaModelHelper", "Added image to session: ${image.width}x${image.height}")
                    }
                } else {
                    // Add text prompt only
                    session.addQueryChunk(prompt)
                    Log.d("GemmaModelHelper", "Added text-only prompt: $prompt")
                }
                
                // Generate response asynchronously
                val fullResponse = StringBuilder()
                session.generateResponseAsync { partialResult, done ->
                    if (partialResult != null) {
                        fullResponse.append(partialResult)
                    }
                    if (done) {
                        callback(fullResponse.toString())
                    }
                }
            } catch (e: Exception) {
                errorCallback(e.message ?: "Inference failed")
            }
        } ?: errorCallback("Model not initialized")
    }
    
    fun generateTextSync(prompt: String): String? {
        return try {
            llmSession?.let { session ->
                session.addQueryChunk(prompt)
                val response = StringBuilder()
                var isComplete = false
                
                session.generateResponseAsync { partialResult, done ->
                    if (partialResult != null) {
                        response.append(partialResult)
                    }
                    if (done) {
                        isComplete = true
                    }
                }
                
                // Wait for completion (simple blocking approach)
                while (!isComplete) {
                    Thread.sleep(50)
                }
                
                response.toString()
            }
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
    
    fun loadImageFromPath(imagePath: String): MPImage? {
        return try {
            println("GemmaModelHelper: Attempting to load image from: $imagePath")
            val file = File(imagePath)
            println("GemmaModelHelper: File exists: ${file.exists()}, File size: ${file.length()} bytes")
            
            val bitmap = BitmapFactory.decodeFile(imagePath)
            if (bitmap != null) {
                println("GemmaModelHelper: Bitmap loaded successfully - Width: ${bitmap.width}, Height: ${bitmap.height}")
                val mpImage = BitmapImageBuilder(bitmap).build()
                println("GemmaModelHelper: MPImage created successfully")
                mpImage
            } else {
                println("GemmaModelHelper: Failed to decode bitmap from file")
                null
            }
        } catch (e: Exception) {
            println("GemmaModelHelper: Exception loading image: ${e.message}")
            e.printStackTrace()
            null
        }
    }
    
    fun cleanup() {
        try {
            llmSession?.close()
            llmInference?.close()
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            llmSession = null
            llmInference = null
        }
    }
    
    fun isInitialized(): Boolean {
        return llmInference != null && llmSession != null
    }
}