import 'package:flutter/services.dart';
import 'dart:io';

class MediaPipePlatform {
  static const MethodChannel _channel = MethodChannel('com.example.resonalens/mediapipe');
  
  /// Initialize the MediaPipe model with the given .task file path
  static Future<bool> initializeModel(String modelPath, {bool enableVision = true}) async {
    try {
      final result = await _channel.invokeMethod('initializeModel', {
        'modelPath': modelPath,
        'enableVision': enableVision,
      });
      return result as bool;
    } catch (e) {
      print('Failed to initialize model: $e');
      return false;
    }
  }
  
  /// Generate text response from a text prompt
  static Future<String> generateText(String prompt) async {
    try {
      final result = await _channel.invokeMethod('generateText', {
        'prompt': prompt,
      });
      return result as String;
    } catch (e) {
      throw Exception('Failed to generate text: $e');
    }
  }
  
  /// Generate response from an image and text prompt
  static Future<String> generateFromImage(String prompt, String imagePath) async {
    try {
      // Validate image file exists
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw Exception('Image file not found: $imagePath');
      }
      
      final result = await _channel.invokeMethod('generateFromImage', {
        'prompt': prompt,
        'imagePath': imagePath,
      });
      return result as String;
    } catch (e) {
      throw Exception('Failed to generate from image: $e');
    }
  }
  
  /// Generate response from an audio file and text prompt
  static Future<String> generateFromAudio(String prompt, String audioPath) async {
    try {
      // Validate audio file exists
      final audioFile = File(audioPath);
      if (!await audioFile.exists()) {
        throw Exception('Audio file not found: $audioPath');
      }
      
      final result = await _channel.invokeMethod('generateFromAudio', {
        'prompt': prompt,
        'audioPath': audioPath,
      });
      return result as String;
    } catch (e) {
      throw Exception('Failed to generate from audio: $e');
    }
  }
  
  /// Check if the model is currently initialized
  static Future<bool> isModelInitialized() async {
    try {
      final result = await _channel.invokeMethod('isModelInitialized');
      return result as bool;
    } catch (e) {
      print('Failed to check model status: $e');
      return false;
    }
  }
  
  /// Clean up the MediaPipe model resources
  static Future<bool> cleanupModel() async {
    try {
      final result = await _channel.invokeMethod('cleanupModel');
      return result as bool;
    } catch (e) {
      print('Failed to cleanup model: $e');
      return false;
    }
  }
  
  /// Handle platform-specific exceptions and provide user-friendly error messages
  static String _getErrorMessage(dynamic error) {
    if (error is PlatformException) {
      switch (error.code) {
        case 'MODEL_NOT_INITIALIZED':
          return 'Model is not initialized. Please initialize the model first.';
        case 'INFERENCE_ERROR':
          return 'Inference failed: ${error.message}';
        case 'INVALID_ARGUMENTS':
          return 'Invalid arguments provided: ${error.message}';
        case 'IMAGE_LOAD_ERROR':
          return 'Failed to load image: ${error.message}';
        default:
          return error.message ?? 'Unknown error occurred';
      }
    }
    return error.toString();
  }
}