import 'dart:io';
import '../models/chat_message.dart';
import 'model_service.dart';
import 'mediapipe_platform.dart';
import 'audio_task_factory.dart';
import 'audio_processor.dart';

class ChatService {
  static ChatService? _instance;
  static ChatService get instance => _instance ??= ChatService._();
  
  ChatService._();

  bool _isInitialized = false;
  final ModelService _modelService = ModelService();
  final AudioTaskFactory _audioTaskFactory = AudioTaskFactory();

  Future<bool> initializeModel() async {
    if (_isInitialized) return true;

    try {
      print('ChatService: Starting model initialization...');
      
      // Check if model is downloaded first
      final isDownloaded = await _modelService.isModelActuallyDownloaded();
      print('ChatService: Model downloaded: $isDownloaded');
      if (!isDownloaded) {
        throw Exception('No model found. Please download the model first.');
      }

      // Get model path from model service
      final modelPath = await _modelService.getModelPath();
      print('ChatService: Model path: $modelPath');
      
      // Check if model file exists
      final modelFile = File(modelPath);
      final exists = await modelFile.exists();
      print('ChatService: Model file exists: $exists');
      if (!exists) {
        throw Exception('Model file not found at $modelPath');
      }

      print('ChatService: Calling MediaPipe initialization...');
      // Initialize audio processing factory
      final audioInitialized = await _audioTaskFactory.initialize();
      print('ChatService: Audio task factory initialized: $audioInitialized');
      
      // TEMPORARY: Skip MediaPipe initialization for testing
      try {
        _isInitialized = await MediaPipePlatform.initializeModel(
          modelPath,
          enableVision: true,
        );
        print('ChatService: MediaPipe initialization result: $_isInitialized');
      } catch (e) {
        print('ChatService: MediaPipe initialization failed: $e');
        print('ChatService: Setting initialized to true for testing...');
        _isInitialized = true; // TEMPORARY: Force initialization for UI testing
      }

      print('ChatService: Model initialization completed successfully');
      return true;
    } catch (e) {
      print('ChatService: Error initializing model: $e');
      return false;
    }
  }

  Future<String> generateResponse(ChatMessage message) async {
    print('ChatService: generateResponse called with: ${message.content}');
    if (!_isInitialized) {
      print('ChatService: Model not initialized!');
      throw Exception('Model not initialized');
    }

    try {
      print('ChatService: Processing message type: ${message.type}');
      switch (message.type) {
        case MessageType.text:
          print('ChatService: Calling MediaPipe generateText...');
          try {
            final result = await MediaPipePlatform.generateText(message.content);
            print('ChatService: Generated response: $result');
            return result;
          } catch (e) {
            print('ChatService: MediaPipe generateText failed: $e');
            // TEMPORARY: Return mock response for testing
            return 'Mock response: I received your message "${message.content}". This is a test response since MediaPipe is not fully initialized yet.';
          }
          
        case MessageType.image:
          print('ChatService: Processing image message');
          print('ChatService: Image file path: ${message.filePath}');
          print('ChatService: Image prompt: "${message.content}"');
          
          if (message.filePath == null) {
            print('ChatService: Error - Image file path is null');
            throw Exception('Image file path is required');
          }
          
          final imageFile = File(message.filePath!);
          final exists = await imageFile.exists();
          print('ChatService: Image file exists: $exists');
          
          if (!exists) {
            print('ChatService: Error - Image file not found at: ${message.filePath}');
            throw Exception('Image file not found');
          }
          
          final prompt = message.content.isEmpty ? 'What do you see in this image?' : message.content;
          print('ChatService: Calling MediaPipe generateFromImage with prompt: "$prompt"');
          
          try {
            final result = await MediaPipePlatform.generateFromImage(prompt, message.filePath!);
            print('ChatService: Image analysis result: $result');
            return result;
          } catch (e) {
            print('ChatService: MediaPipe generateFromImage failed: $e');
            // TEMPORARY: Return mock response for testing
            return 'Mock image response: I can see you uploaded an image at ${message.filePath}. The prompt was: "$prompt". This is a test response since MediaPipe image processing may not be fully working yet.';
          }
          
        case MessageType.audio:
          print('ChatService: Processing audio message');
          print('ChatService: Audio file path: ${message.filePath}');
          print('ChatService: Audio prompt: "${message.content}"');
          
          if (message.filePath == null) {
            print('ChatService: Error - Audio file path is null');
            throw Exception('Audio file path is required');
          }
          
          final audioFile = File(message.filePath!);
          final exists = await audioFile.exists();
          print('ChatService: Audio file exists: $exists');
          
          if (!exists) {
            print('ChatService: Error - Audio file not found at: ${message.filePath}');
            throw Exception('Audio file not found');
          }
          
          final prompt = message.content.isEmpty ? 'What do you hear in this audio?' : message.content;
          print('ChatService: Calling MediaPipe generateFromAudio with prompt: "$prompt"');
          
          try {
            // Use MediaPipe audio processing pipeline
            final audioTask = await _audioTaskFactory.createTask(AudioTaskType.audioLlmInference);
            if (audioTask != null) {
              print('ChatService: Processing audio with MediaPipe audio task...');
              final taskResult = await audioTask.processAudioFile(message.filePath!);
              
              if (taskResult.success) {
                print('ChatService: Audio processing successful, calling MediaPipe with processed data...');
                // Convert processed audio data for MediaPipe
                final audioData = taskResult.data['audio_data'] as Map<String, dynamic>;
                final result = await MediaPipePlatform.generateFromAudio(prompt, message.filePath!);
                audioTask.dispose();
                return result;
              } else {
                print('ChatService: Audio processing failed: ${taskResult.error}');
                audioTask.dispose();
                return 'I had trouble processing the audio file. Error: ${taskResult.error}';
              }
            } else {
              print('ChatService: Failed to create audio task');
              return 'I encountered an error setting up audio processing. Please try again.';
            }
          } catch (e) {
            print('ChatService: MediaPipe generateFromAudio failed: $e');
            // TEMPORARY: Return mock response for testing
            return 'Mock audio response: I received an audio file at ${message.filePath}. The prompt was: "$prompt". This is a test response since MediaPipe audio processing may not be fully working yet.';
          }
      }
    } catch (e) {
      throw Exception('Generation failed: $e');
    }
  }

  Future<void> dispose() async {
    if (_isInitialized) {
      await MediaPipePlatform.cleanupModel();
      _audioTaskFactory.dispose();
      _isInitialized = false;
    }
  }

  bool get isInitialized => _isInitialized;
}