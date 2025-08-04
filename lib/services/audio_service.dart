import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  
  String? _currentRecordingPath;
  bool _isRecording = false;
  bool _isPlaying = false;

  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  String? get currentRecordingPath => _currentRecordingPath;

  /// Request microphone permission
  Future<bool> requestMicrophonePermission() async {
    try {
      final status = await Permission.microphone.request();
      return status == PermissionStatus.granted;
    } catch (e) {
      debugPrint('Error requesting microphone permission: $e');
      return false;
    }
  }

  /// Check if microphone permission is granted
  Future<bool> hasMicrophonePermission() async {
    try {
      final status = await Permission.microphone.status;
      return status == PermissionStatus.granted;
    } catch (e) {
      debugPrint('Error checking microphone permission: $e');
      return false;
    }
  }

  /// Start recording audio
  Future<bool> startRecording() async {
    try {
      if (_isRecording) {
        debugPrint('Already recording');
        return false;
      }

      // Check permission
      if (!await hasMicrophonePermission()) {
        final granted = await requestMicrophonePermission();
        if (!granted) {
          debugPrint('Microphone permission not granted');
          return false;
        }
      }

      // Get temporary directory for recording
      final directory = await getTemporaryDirectory();
      final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _currentRecordingPath = path.join(directory.path, fileName);

      // Configure recording
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      );

      // Start recording
      await _recorder.start(config, path: _currentRecordingPath!);
      _isRecording = true;
      
      debugPrint('Started recording to: $_currentRecordingPath');
      return true;
    } catch (e) {
      debugPrint('Error starting recording: $e');
      _isRecording = false;
      _currentRecordingPath = null;
      return false;
    }
  }

  /// Stop recording audio
  Future<String?> stopRecording() async {
    try {
      if (!_isRecording) {
        debugPrint('Not currently recording');
        return null;
      }

      final recordingPath = await _recorder.stop();
      _isRecording = false;
      
      debugPrint('Stopped recording, file saved to: $recordingPath');
      return recordingPath ?? _currentRecordingPath;
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Play audio file
  Future<bool> playAudio(String filePath) async {
    try {
      if (_isPlaying) {
        await stopAudio();
      }

      await _player.play(DeviceFileSource(filePath));
      _isPlaying = true;
      
      // Listen for completion
      _player.onPlayerStateChanged.listen((PlayerState state) {
        if (state == PlayerState.completed) {
          _isPlaying = false;
        }
      });

      debugPrint('Started playing audio: $filePath');
      return true;
    } catch (e) {
      debugPrint('Error playing audio: $e');
      _isPlaying = false;
      return false;
    }
  }

  /// Stop audio playback
  Future<void> stopAudio() async {
    try {
      await _player.stop();
      _isPlaying = false;
      debugPrint('Stopped audio playback');
    } catch (e) {
      debugPrint('Error stopping audio: $e');
    }
  }

  /// Get audio file duration
  Future<Duration?> getAudioDuration(String filePath) async {
    try {
      await _player.setSource(DeviceFileSource(filePath));
      return await _player.getDuration();
    } catch (e) {
      debugPrint('Error getting audio duration: $e');
      return null;
    }
  }

  /// Convert audio file to bytes for processing
  Future<Uint8List?> getAudioBytes(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('Audio file does not exist: $filePath');
        return null;
      }
      
      return await file.readAsBytes();
    } catch (e) {
      debugPrint('Error reading audio file bytes: $e');
      return null;
    }
  }

  /// Clean up temporary audio files
  Future<void> cleanupTempFiles() async {
    try {
      final directory = await getTemporaryDirectory();
      final files = directory.listSync();
      
      for (final file in files) {
        if (file is File && file.path.contains('audio_')) {
          await file.delete();
        }
      }
      
      debugPrint('Cleaned up temporary audio files');
    } catch (e) {
      debugPrint('Error cleaning up temp files: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _recorder.dispose();
    _player.dispose();
  }
}