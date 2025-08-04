import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'audio_processor.dart';

/// Audio task types following MediaPipe framework patterns
enum AudioTaskType {
  /// General audio processing for multimodal LLM
  audioLlmInference,
  /// Audio classification (future extension)
  audioClassification,
  /// Audio embedding extraction (future extension) 
  audioEmbedding,
}

/// Configuration for audio tasks
class AudioTaskConfig {
  final AudioTaskType taskType;
  final AudioConfig audioConfig;
  final Map<String, dynamic> additionalOptions;

  const AudioTaskConfig({
    required this.taskType,
    this.audioConfig = const AudioConfig(),
    this.additionalOptions = const {},
  });
}

/// Result from audio task processing
class AudioTaskResult {
  final AudioTaskType taskType;
  final Map<String, dynamic> data;
  final bool success;
  final String? error;
  final Duration processingTime;

  AudioTaskResult({
    required this.taskType,
    required this.data,
    required this.success,
    this.error,
    required this.processingTime,
  });
}

/// MediaPipe-style audio task factory
class AudioTaskFactory {
  static final AudioTaskFactory _instance = AudioTaskFactory._internal();
  factory AudioTaskFactory() => _instance;
  AudioTaskFactory._internal();

  final MediaPipeAudioProcessor _audioProcessor = MediaPipeAudioProcessor();
  final Map<AudioTaskType, AudioTaskConfig> _taskConfigs = {};
  bool _isInitialized = false;

  /// Initialize the factory with default configurations
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Initialize audio processor
      final processorInitialized = await _audioProcessor.initialize();
      if (!processorInitialized) {
        debugPrint('AudioTaskFactory: Failed to initialize audio processor');
        return false;
      }

      // Setup default task configurations
      _setupDefaultConfigurations();
      
      _isInitialized = true;
      debugPrint('AudioTaskFactory: Initialized successfully');
      return true;
    } catch (e) {
      debugPrint('AudioTaskFactory: Initialization failed: $e');
      return false;
    }
  }

  /// Setup default configurations for different task types
  void _setupDefaultConfigurations() {
    // Configuration for LLM inference with audio
    _taskConfigs[AudioTaskType.audioLlmInference] = const AudioTaskConfig(
      taskType: AudioTaskType.audioLlmInference,
      audioConfig: AudioConfig(
        sampleRate: 16000, // Standard for speech recognition
        channels: 1, // Mono for LLM processing
        bitsPerSample: 16,
        mode: AudioProcessingMode.audioClips,
      ),
      additionalOptions: {
        'max_duration_seconds': 30,
        'normalize_audio': true,
        'apply_voice_activity_detection': true,
      },
    );

    // Future configurations for other task types
    _taskConfigs[AudioTaskType.audioClassification] = const AudioTaskConfig(
      taskType: AudioTaskType.audioClassification,
      audioConfig: AudioConfig(
        sampleRate: 16000,
        channels: 1,
        mode: AudioProcessingMode.audioClips,
      ),
    );

    _taskConfigs[AudioTaskType.audioEmbedding] = const AudioTaskConfig(
      taskType: AudioTaskType.audioEmbedding,
      audioConfig: AudioConfig(
        sampleRate: 16000,
        channels: 1,
        mode: AudioProcessingMode.audioClips,
      ),
    );
  }

  /// Create and configure an audio task
  Future<AudioTask?> createTask(AudioTaskType taskType) async {
    if (!_isInitialized) {
      debugPrint('AudioTaskFactory: Not initialized');
      return null;
    }

    final config = _taskConfigs[taskType];
    if (config == null) {
      debugPrint('AudioTaskFactory: No configuration found for task type: $taskType');
      return null;
    }

    try {
      switch (taskType) {
        case AudioTaskType.audioLlmInference:
          return AudioLlmInferenceTask(config);
        case AudioTaskType.audioClassification:
          return AudioClassificationTask(config);
        case AudioTaskType.audioEmbedding:
          return AudioEmbeddingTask(config);
      }
    } catch (e) {
      debugPrint('AudioTaskFactory: Failed to create task: $e');
      return null;
    }
  }

  /// Update configuration for a specific task type
  void updateTaskConfig(AudioTaskType taskType, AudioTaskConfig config) {
    _taskConfigs[taskType] = config;
    debugPrint('AudioTaskFactory: Updated configuration for $taskType');
  }

  /// Get current configuration for a task type
  AudioTaskConfig? getTaskConfig(AudioTaskType taskType) {
    return _taskConfigs[taskType];
  }

  /// Cleanup resources
  void dispose() {
    _audioProcessor.dispose();
    _taskConfigs.clear();
    _isInitialized = false;
    debugPrint('AudioTaskFactory: Disposed');
  }

  bool get isInitialized => _isInitialized;
}

/// Base class for audio tasks
abstract class AudioTask {
  final AudioTaskConfig config;
  final MediaPipeAudioProcessor _processor = MediaPipeAudioProcessor();

  AudioTask(this.config);

  /// Process audio from file path
  Future<AudioTaskResult> processAudioFile(String filePath, {Map<String, dynamic>? options});

  /// Process audio from raw data
  Future<AudioTaskResult> processAudioData(AudioData audioData, {Map<String, dynamic>? options});

  /// Validate input parameters
  bool validateInput(dynamic input);

  /// Cleanup task resources
  void dispose();
}

/// Audio task for LLM inference (Gemma 3n integration)
class AudioLlmInferenceTask extends AudioTask {
  AudioLlmInferenceTask(super.config);

  @override
  Future<AudioTaskResult> processAudioFile(String filePath, {Map<String, dynamic>? options}) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      if (!validateInput(filePath)) {
        return AudioTaskResult(
          taskType: config.taskType,
          data: {},
          success: false,
          error: 'Invalid file path',
          processingTime: stopwatch.elapsed,
        );
      }

      // Process audio file
      final audioData = await _processor.processAudioFile(filePath);
      if (audioData == null) {
        return AudioTaskResult(
          taskType: config.taskType,
          data: {},
          success: false,
          error: 'Failed to process audio file',
          processingTime: stopwatch.elapsed,
        );
      }

      return processAudioData(audioData, options: options);
    } catch (e) {
      return AudioTaskResult(
        taskType: config.taskType,
        data: {},
        success: false,
        error: e.toString(),
        processingTime: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<AudioTaskResult> processAudioData(AudioData audioData, {Map<String, dynamic>? options}) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Validate audio data
      if (!_processor.validateAudioData(audioData)) {
        return AudioTaskResult(
          taskType: config.taskType,
          data: {},
          success: false,
          error: 'Invalid audio data for Gemma 3n',
          processingTime: stopwatch.elapsed,
        );
      }

      // Prepare data for Gemma 3n
      final gemmaData = _processor.prepareForGemma3n(audioData);
      
      // Add processing metadata
      final result = {
        'audio_data': gemmaData,
        'processing_config': {
          'sample_rate': config.audioConfig.sampleRate,
          'channels': config.audioConfig.channels,
          'mode': config.audioConfig.mode.toString(),
        },
        'metadata': {
          'duration_ms': audioData.duration.inMilliseconds,
          'samples_count': audioData.samples.length,
          'processing_time_ms': stopwatch.elapsedMilliseconds,
        },
      };

      return AudioTaskResult(
        taskType: config.taskType,
        data: result,
        success: true,
        processingTime: stopwatch.elapsed,
      );
    } catch (e) {
      return AudioTaskResult(
        taskType: config.taskType,
        data: {},
        success: false,
        error: e.toString(),
        processingTime: stopwatch.elapsed,
      );
    }
  }

  @override
  bool validateInput(dynamic input) {
    if (input is String) {
      final file = File(input);
      return file.existsSync() && file.lengthSync() > 0;
    }
    if (input is AudioData) {
      return _processor.validateAudioData(input);
    }
    return false;
  }

  @override
  void dispose() {
    // Task-specific cleanup
    debugPrint('AudioLlmInferenceTask: Disposed');
  }
}

/// Placeholder for future audio classification task
class AudioClassificationTask extends AudioTask {
  AudioClassificationTask(super.config);

  @override
  Future<AudioTaskResult> processAudioFile(String filePath, {Map<String, dynamic>? options}) async {
    // TODO: Implement audio classification
    return AudioTaskResult(
      taskType: config.taskType,
      data: {'message': 'Audio classification not yet implemented'},
      success: false,
      error: 'Not implemented',
      processingTime: Duration.zero,
    );
  }

  @override
  Future<AudioTaskResult> processAudioData(AudioData audioData, {Map<String, dynamic>? options}) async {
    // TODO: Implement audio classification
    return AudioTaskResult(
      taskType: config.taskType,
      data: {'message': 'Audio classification not yet implemented'},
      success: false,
      error: 'Not implemented',
      processingTime: Duration.zero,
    );
  }

  @override
  bool validateInput(dynamic input) => false;

  @override
  void dispose() {}
}

/// Placeholder for future audio embedding task
class AudioEmbeddingTask extends AudioTask {
  AudioEmbeddingTask(super.config);

  @override
  Future<AudioTaskResult> processAudioFile(String filePath, {Map<String, dynamic>? options}) async {
    // TODO: Implement audio embedding extraction
    return AudioTaskResult(
      taskType: config.taskType,
      data: {'message': 'Audio embedding extraction not yet implemented'},
      success: false,
      error: 'Not implemented',
      processingTime: Duration.zero,
    );
  }

  @override
  Future<AudioTaskResult> processAudioData(AudioData audioData, {Map<String, dynamic>? options}) async {
    // TODO: Implement audio embedding extraction
    return AudioTaskResult(
      taskType: config.taskType,
      data: {'message': 'Audio embedding extraction not yet implemented'},
      success: false,
      error: 'Not implemented',
      processingTime: Duration.zero,
    );
  }

  @override
  bool validateInput(dynamic input) => false;

  @override
  void dispose() {}
}