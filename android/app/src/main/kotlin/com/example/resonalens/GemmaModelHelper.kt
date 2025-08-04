package com.example.resonalens

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.util.Log
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.tasks.genai.llminference.LlmInference
import com.google.mediapipe.tasks.genai.llminference.LlmInferenceSession
import com.google.mediapipe.tasks.genai.llminference.GraphOptions
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

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
            
            // Note: Audio modality might not be available in current MediaPipe version
            if (enableAudioModality) {
                Log.d("GemmaModelHelper", "Audio modality requested but may not be supported in current MediaPipe version")
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
        audioData: FloatArray? = null,
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
                } else if (audioData != null && audioData.isNotEmpty()) {
                    // For audio input - since addAudio is not available, we'll process as text with context
                    Log.d("GemmaModelHelper", "Processing audio data as text context (${audioData.size} samples)")
                    val audioPrompt = "$prompt [Note: Audio processing - ${audioData.size} samples at 16kHz, duration: ${audioData.size/16000.0}s]"
                    session.addQueryChunk(audioPrompt)
                    Log.d("GemmaModelHelper", "Added audio-context prompt: $audioPrompt")
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
    
    fun loadAudioFromPath(audioPath: String): FloatArray? {
        return try {
            Log.d("GemmaModelHelper", "Attempting to load audio from: $audioPath")
            val file = File(audioPath)
            Log.d("GemmaModelHelper", "Audio file exists: ${file.exists()}, File size: ${file.length()} bytes")
            
            if (!file.exists()) {
                Log.e("GemmaModelHelper", "Audio file does not exist")
                return null
            }
            
            // Use MediaMetadataRetriever to extract basic audio metadata
            val retriever = MediaMetadataRetriever()
            try {
                retriever.setDataSource(audioPath)
                
                // Extract basic metadata
                val duration = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
                val mimeType = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_MIMETYPE)
                
                Log.d("GemmaModelHelper", "Audio metadata - Duration: ${duration}ms, Type: $mimeType")
                
                // For now, create representative data based on file size and duration
                // This is a placeholder until full audio decoding is implemented
                val sampleRate = 16000
                val numSamples = if (duration > 0) {
                    (duration * sampleRate / 1000).toInt()
                } else {
                    // Estimate based on file size (rough approximation)
                    minOf(file.length().toInt() / 4, sampleRate * 10) // Max 10 seconds
                }
                
                Log.d("GemmaModelHelper", "Creating audio representation with $numSamples samples")
                
                // Create placeholder audio data - in production this would be actual decoded audio
                val audioData = FloatArray(numSamples) { 0.01f * (it % 100) } // Small non-zero pattern
                
                return audioData
            } finally {
                retriever.release()
            }
        } catch (e: Exception) {
            Log.e("GemmaModelHelper", "Exception loading audio: ${e.message}")
            e.printStackTrace()
            null
        }
    }
    
    private fun extractPcmFromAudioFile(filePath: String): FloatArray? {
        // TODO: Implement proper audio decoding
        // This would typically involve:
        // 1. Using MediaExtractor to extract audio track
        // 2. Using MediaCodec to decode compressed audio
        // 3. Converting decoded bytes to Float32 samples
        // 4. Resampling to target sample rate (16kHz)
        // 5. Converting to mono if needed
        
        Log.w("GemmaModelHelper", "Audio extraction not fully implemented - using placeholder")
        return null
    }
    
    fun isInitialized(): Boolean {
        return llmInference != null && llmSession != null
    }
}