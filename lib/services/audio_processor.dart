import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'audio_format_converter.dart';

/// Audio processing modes following MediaPipe's framework
enum AudioProcessingMode {
  /// For processing independent audio clips
  audioClips,
  /// For continuous audio stream processing (like from a microphone)
  audioStream,
}

/// Audio format configuration
class AudioConfig {
  final int sampleRate;
  final int channels;
  final int bitsPerSample;
  final AudioProcessingMode mode;

  const AudioConfig({
    this.sampleRate = 16000, // Standard for speech processing
    this.channels = 1, // Mono for Gemma 3n
    this.bitsPerSample = 16,
    this.mode = AudioProcessingMode.audioClips,
  });
}

/// Audio data container following MediaPipe conventions
class AudioData {
  final Float32List samples;
  final int sampleRate;
  final int channels;
  final Duration duration;

  AudioData({
    required this.samples,
    required this.sampleRate,
    required this.channels,
    required this.duration,
  });

  /// Create from raw PCM data
  factory AudioData.fromPcmBytes(
    Uint8List pcmBytes, {
    required int sampleRate,
    int channels = 1,
    int bitsPerSample = 16,
  }) {
    // Convert PCM bytes to float samples
    final samples = Float32List(pcmBytes.length ~/ (bitsPerSample ~/ 8));
    
    if (bitsPerSample == 16) {
      for (int i = 0; i < samples.length; i++) {
        final sample = (pcmBytes[i * 2] | (pcmBytes[i * 2 + 1] << 8));
        // Convert 16-bit signed int to float [-1.0, 1.0]
        samples[i] = sample / 32768.0;
      }
    }
    
    final duration = Duration(
      milliseconds: (samples.length * 1000 / sampleRate).round(),
    );
    
    return AudioData(
      samples: samples,
      sampleRate: sampleRate,
      channels: channels,
      duration: duration,
    );
  }
}

/// MediaPipe-compatible audio processor
class MediaPipeAudioProcessor {
  static final MediaPipeAudioProcessor _instance = MediaPipeAudioProcessor._internal();
  factory MediaPipeAudioProcessor() => _instance;
  MediaPipeAudioProcessor._internal();

  AudioConfig _config = const AudioConfig();
  bool _isInitialized = false;
  final AudioFormatConverter _formatConverter = AudioFormatConverter();

  /// Initialize the audio processor with configuration
  Future<bool> initialize({AudioConfig? config}) async {
    try {
      _config = config ?? const AudioConfig();
      _isInitialized = true;
      debugPrint('MediaPipeAudioProcessor: Initialized with config: '
          'sampleRate=${_config.sampleRate}, channels=${_config.channels}, '
          'mode=${_config.mode}');
      return true;
    } catch (e) {
      debugPrint('MediaPipeAudioProcessor: Failed to initialize: $e');
      return false;
    }
  }

  /// Process audio file for Gemma 3n
  Future<AudioData?> processAudioFile(String filePath) async {
    if (!_isInitialized) {
      debugPrint('MediaPipeAudioProcessor: Not initialized');
      return null;
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('MediaPipeAudioProcessor: Audio file does not exist: $filePath');
        return null;
      }

      debugPrint('MediaPipeAudioProcessor: Processing audio file: $filePath');

      // Use format converter to handle different audio formats
      final conversionResult = await _formatConverter.convertForGemma3n(filePath);
      
      if (!conversionResult.success) {
        debugPrint('MediaPipeAudioProcessor: Audio conversion failed: ${conversionResult.error}');
        return null;
      }

      // Create AudioData from converted samples
      return AudioData(
        samples: conversionResult.samples!,
        sampleRate: conversionResult.sampleRate!,
        channels: conversionResult.channels!,
        duration: conversionResult.duration!,
      );
    } catch (e) {
      debugPrint('MediaPipeAudioProcessor: Error processing audio file: $e');
      return null;
    }
  }

  /// Process raw PCM audio data
  AudioData? _processPcmData(Uint8List rawData) {
    try {
      // Skip audio header if present (simplified approach)
      // In reality, you'd properly parse WAV/other format headers
      final pcmData = _extractPcmFromRawData(rawData);
      
      return AudioData.fromPcmBytes(
        pcmData,
        sampleRate: _config.sampleRate,
        channels: _config.channels,
      );
    } catch (e) {
      debugPrint('MediaPipeAudioProcessor: Error processing PCM data: $e');
      return null;
    }
  }

  /// Extract PCM data from raw audio file bytes
  Uint8List _extractPcmFromRawData(Uint8List rawData) {
    // Simplified extraction - in reality you'd parse audio format headers
    // For WAV files, skip the 44-byte header
    if (rawData.length > 44 && _isWavFile(rawData)) {
      return Uint8List.fromList(rawData.skip(44).toList());
    }
    
    // For other formats, return as-is (this is overly simplified)
    return rawData;
  }

  /// Simple WAV file detection
  bool _isWavFile(Uint8List data) {
    if (data.length < 12) return false;
    
    // Check for "RIFF" and "WAVE" headers
    final riff = String.fromCharCodes(data.sublist(0, 4));
    final wave = String.fromCharCodes(data.sublist(8, 12));
    
    return riff == 'RIFF' && wave == 'WAVE';
  }

  /// Validate audio data for Gemma 3n compatibility
  bool validateAudioData(AudioData audioData) {
    // Check duration (Gemma 3n might have limits)
    if (audioData.duration.inSeconds > 30) {
      debugPrint('MediaPipeAudioProcessor: Audio too long (${audioData.duration.inSeconds}s)');
      return false;
    }

    // Check sample rate compatibility
    if (audioData.sampleRate < 8000 || audioData.sampleRate > 48000) {
      debugPrint('MediaPipeAudioProcessor: Invalid sample rate: ${audioData.sampleRate}');
      return false;
    }

    // Check for valid samples
    if (audioData.samples.isEmpty) {
      debugPrint('MediaPipeAudioProcessor: No audio samples found');
      return false;
    }

    return true;
  }

  /// Convert audio data to format expected by Gemma 3n
  Map<String, dynamic> prepareForGemma3n(AudioData audioData) {
    if (!validateAudioData(audioData)) {
      throw Exception('Invalid audio data for Gemma 3n processing');
    }

    return {
      'samples': audioData.samples,
      'sample_rate': audioData.sampleRate,
      'channels': audioData.channels,
      'duration_ms': audioData.duration.inMilliseconds,
      'format': 'float32',
    };
  }

  /// Cleanup resources
  void dispose() {
    _isInitialized = false;
    debugPrint('MediaPipeAudioProcessor: Disposed');
  }

  bool get isInitialized => _isInitialized;
  AudioConfig get config => _config;
}