import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// Model information class
class LLMModel {
  final String id;
  final String name;
  final String author;
  final String description;
  final List<String> files;
  final bool isGated;
  final int sizeBytes;
  final String format; // e.g., "safetensors", "gguf", "tflite"
  
  LLMModel({
    required this.id,
    required this.name,
    required this.author,
    required this.description,
    required this.files,
    required this.isGated,
    required this.sizeBytes,
    required this.format,
  });
  
  factory LLMModel.fromJson(Map<String, dynamic> json) {
    return LLMModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      author: json['author'] ?? '',
      description: json['description'] ?? '',
      files: List<String>.from(json['files'] ?? []),
      isGated: json['gated'] ?? false,
      sizeBytes: json['size'] ?? 0,
      format: json['format'] ?? 'safetensors',
    );
  }
}

// Download progress callback
typedef ProgressCallback = void Function(int received, int total, double percentage);
typedef StatusCallback = void Function(DownloadStatus status);

enum DownloadStatus {
  idle,
  downloading,
  completed,
  error,
  cancelled,
  authenticating
}

enum ModelStatus {
  notDownloaded,
  downloading,
  downloaded,
  error,
  cancelled,
}

class DownloadProgress {
  final ModelStatus status;
  final double progress;
  final int downloadedBytes;
  final int totalBytes;
  final double speed; // in bytes/sec
  final Duration eta;
  final String? errorMessage;

  DownloadProgress({
    required this.status,
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.speed = 0.0,
    this.eta = Duration.zero,
    this.errorMessage,
  });
}

// Main LLM Download Manager
class ModelService {
  static final ModelService _instance = ModelService._internal();
  factory ModelService() => _instance;
  ModelService._internal();

  final Dio _dio = Dio();
  final Map<String, CancelToken> _downloadTokens = {};
  final Map<String, DownloadStatus> _downloadStatuses = {};
  
  String? _hfToken;
  late Directory _modelsDirectory;
  bool _initialized = false;

  final _progressController = StreamController<DownloadProgress>.broadcast();
  Stream<DownloadProgress> get progressStream => _progressController.stream;

  static const _tokenKey = 'huggingface_token';
  static const _modelStatusKey = 'model_status';
  static const _modelPathKey = 'model_path';
  static const _modelUrl = 'https://huggingface.co/google/gemma-3n-E2B-it-litert-preview/resolve/main/gemma-3n-E2B-it-int4.task';
  
  // Current download state
  CancelToken? _currentDownloadToken;
  bool _isDownloading = false;

  // Initialize the download manager
  Future<void> initialize() async {
    if (_initialized) return;
    
    // Setup directories
    final appDir = await getApplicationDocumentsDirectory();
    _modelsDirectory = Directory('${appDir.path}/llm_models');
    if (!await _modelsDirectory.exists()) {
      await _modelsDirectory.create(recursive: true);
    }
    
    // Load saved HF token
    await _loadAuthToken();
    
    // Configure Dio
    _dio.options = BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 10),
      headers: {
        'User-Agent': 'flutter-llm-downloader/1.0',
      },
    );
    
    _initialized = true;
  }

  // Token management
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    _hfToken = token;
  }

  Future<String?> getToken() async {
    if (_hfToken != null) return _hfToken;
    final prefs = await SharedPreferences.getInstance();
    _hfToken = prefs.getString(_tokenKey);
    return _hfToken;
  }

  Future<bool> hasValidToken() async {
    // Bypass token verification - allow downloads without authentication
    return true;
  }

  Future<void> _loadAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    _hfToken = prefs.getString(_tokenKey);
  }

  // Model status management
  Future<void> _setModelStatus(ModelStatus status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelStatusKey, status.toString());
  }

  Future<ModelStatus> getModelStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final statusString = prefs.getString(_modelStatusKey);
    if (statusString == null) return ModelStatus.notDownloaded;
    
    switch (statusString) {
      case 'ModelStatus.downloaded':
        return ModelStatus.downloaded;
      case 'ModelStatus.downloading':
        return ModelStatus.downloading;
      case 'ModelStatus.error':
        return ModelStatus.error;
      case 'ModelStatus.cancelled':
        return ModelStatus.cancelled;
      default:
        return ModelStatus.notDownloaded;
    }
  }

  // Model path management
  Future<String> getModelPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/llm_models/gemma-3n-E2B-it-int4.task';
  }

  Future<void> _setModelPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelPathKey, path);
  }

  Future<String?> getStoredModelPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_modelPathKey);
  }

  // Download model
  Future<void> downloadModel() async {
    await initialize();
    
    if (_isDownloading) {
      debugPrint('Download already in progress');
      return;
    }

    try {
      _isDownloading = true;
      
      // Enable wakelock to prevent screen sleep during download
      await WakelockPlus.enable();
      debugPrint('Wakelock enabled for download');
      
      await _setModelStatus(ModelStatus.downloading);
      
      final token = await getToken();
      // Token is optional - only use if available for gated models

      final path = await getModelPath();
      final directory = File(path).parent;
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Delete existing file if it exists
      final existingFile = File(path);
      if (await existingFile.exists()) {
        await existingFile.delete();
      }

      // Create cancel token
      _currentDownloadToken = CancelToken();

      _progressController.add(DownloadProgress(
        status: ModelStatus.downloading,
        progress: 0.0,
      ));

      // Start download
      final headers = <String, String>{};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      
      await _dio.download(
        _modelUrl,
        path,
        cancelToken: _currentDownloadToken,
        options: Options(
          headers: headers,
        ),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            final percentage = progress * 100;
            
            _progressController.add(DownloadProgress(
              status: ModelStatus.downloading,
              progress: progress,
              downloadedBytes: received,
              totalBytes: total,
              speed: 0.0, // Speed calculation would need time tracking
              eta: Duration.zero,
            ));
          }
        },
      );

      // Verify download
      if (await existingFile.exists()) {
        if (await _verifyModelFile(existingFile)) {
          final size = await existingFile.length();
          await _setModelStatus(ModelStatus.downloaded);
          await _setModelPath(existingFile.path);
          _progressController.add(DownloadProgress(
            status: ModelStatus.downloaded,
            progress: 1.0,
            downloadedBytes: size,
            totalBytes: size,
          ));
        } else {
          await existingFile.delete();
          throw Exception('Model verification failed. The downloaded file is invalid.');
        }
      } else {
        throw Exception('Download completed but file not found');
      }

    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        await _setModelStatus(ModelStatus.cancelled);
        _progressController.add(DownloadProgress(
          status: ModelStatus.cancelled,
          errorMessage: 'Download cancelled',
        ));
      } else {
        await _setModelStatus(ModelStatus.error);
        _progressController.add(DownloadProgress(
          status: ModelStatus.error,
          errorMessage: e.toString(),
        ));
      }
      rethrow;
    } finally {
      _isDownloading = false;
      _currentDownloadToken = null;
      
      // Disable wakelock when download completes (success, error, or cancel)
      await WakelockPlus.disable();
      debugPrint('Wakelock disabled after download');
    }
  }

  // Cancel download
  Future<void> cancelDownload() async {
    if (_currentDownloadToken != null && !_currentDownloadToken!.isCancelled) {
      _currentDownloadToken!.cancel('User cancelled');
    }
  }

  // Verify model file
  Future<bool> _verifyModelFile(File file) async {
    try {
      // Verify it's a .task file
      if (!file.path.endsWith('.task')) {
        debugPrint('File verification failed: Not a .task file');
        return false;
      }

      final stat = await file.stat();
      // Gemma 3N models are typically smaller, around 50MB-2GB
      if (stat.size < 10 * 1024 * 1024) { // At least 10MB
        debugPrint('File verification failed: File too small (${stat.size} bytes)');
        return false;
      }
      if (stat.size > 5 * 1024 * 1024 * 1024) { // Less than 5GB
        debugPrint('File verification failed: File too large (${stat.size} bytes)');
        return false;
      }

      // Try to read first few bytes to verify it's a valid file
      final randomAccessFile = await file.open();
      final header = await randomAccessFile.read(16);
      await randomAccessFile.close();

      // Basic check - file should not be empty or all zeros
      if (header.isEmpty || header.every((byte) => byte == 0)) {
        debugPrint('File verification failed: Invalid header');
        return false;
      }

      debugPrint('File verification successful: ${stat.size} bytes');
      return true;
    } catch (e) {
      debugPrint('Model verification error: $e');
      return false;
    }
  }

  // Delete model
  Future<void> deleteModel() async {
    try {
      // Cancel any ongoing download first
      await cancelDownload();
      
      final modelPath = await getModelPath();
      final file = File(modelPath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('Model file deleted: $modelPath');
      }
      
      await _setModelStatus(ModelStatus.notDownloaded);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_modelPathKey);
      
      // Emit status update
      _progressController.add(DownloadProgress(status: ModelStatus.notDownloaded));
      
    } catch (e) {
      debugPrint('Error deleting model: $e');
      await _setModelStatus(ModelStatus.error);
      _progressController.add(DownloadProgress(
        status: ModelStatus.error,
        errorMessage: 'Failed to delete model: $e',
      ));
      rethrow;
    }
  }

  // Get model size
  Future<int> getModelSizeInBytes() async {
    try {
      final modelPath = await getModelPath();
      final file = File(modelPath);
      if (!await file.exists()) return 0;

      final stat = await file.stat();
      return stat.size;
    } catch (e) {
      debugPrint('Error getting model size: $e');
      return 0;
    }
  }

  // Utility methods
  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  
  String formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    if (bytesPerSecond < 1024 * 1024) return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }
  
  String formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes < 60) return '${minutes}m ${remainingSeconds}s';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '${hours}h ${remainingMinutes}m';
  }

  // Check if model file actually exists and is valid
  Future<bool> isModelActuallyDownloaded() async {
    try {
      final modelPath = await getModelPath();
      final file = File(modelPath);
      if (!await file.exists()) {
        // File doesn't exist, update status
        await _setModelStatus(ModelStatus.notDownloaded);
        return false;
      }
      
      // Verify the file is valid
      if (!await _verifyModelFile(file)) {
        // File is corrupted, delete and update status
        await file.delete();
        await _setModelStatus(ModelStatus.notDownloaded);
        return false;
      }
      
      return true;
    } catch (e) {
      debugPrint('Error checking model: $e');
      await _setModelStatus(ModelStatus.error);
      return false;
    }
  }

  // Cleanup resources
  void dispose() {
    if (_currentDownloadToken != null && !_currentDownloadToken!.isCancelled) {
      _currentDownloadToken!.cancel('Service disposed');
    }
    _progressController.close();
  }
}
