import 'dart:async';

import 'package:flutter/material.dart';
import '../services/model_service.dart';
import 'chat_screen.dart';

class ModelManagementScreen extends StatefulWidget {
  const ModelManagementScreen({super.key});

  @override
  State<ModelManagementScreen> createState() => _ModelManagementScreenState();
}

class _ModelManagementScreenState extends State<ModelManagementScreen> {
  final _modelService = ModelService();
  final _tokenController = TextEditingController();
  StreamSubscription<DownloadProgress>? _progressSubscription;

  ModelStatus _modelStatus = ModelStatus.notDownloaded;
  int _modelSize = 0;
  bool _isLoading = true;
  double _downloadProgress = 0.0;
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  double _downloadSpeed = 0;
  Duration _eta = Duration.zero;
  String? _errorMessage;
  bool _tokenSaved = false;

  @override
  void initState() {
    super.initState();
    _initialize();
    _setupProgressListener();
  }

  Future<void> _initialize() async {
    await _loadToken();
    await _checkModelStatus();
  }

  void _setupProgressListener() {
    _progressSubscription = _modelService.progressStream.listen(
      (progress) {
        if (!mounted) return;
        setState(() {
          _modelStatus = progress.status;
          _downloadProgress = progress.progress;
          _downloadedBytes = progress.downloadedBytes;
          _totalBytes = progress.totalBytes;
          _downloadSpeed = progress.speed;
          _eta = progress.eta;
          
          // Handle error messages
          if (progress.errorMessage != null) {
            _errorMessage = progress.errorMessage;
          }
          
          // Clear loading state when download completes or fails
          if (progress.status == ModelStatus.downloaded || 
              progress.status == ModelStatus.error ||
              progress.status == ModelStatus.cancelled) {
            _isLoading = false;
          }
        });
        
        // Refresh model size when download completes
        if (progress.status == ModelStatus.downloaded) {
          _updateModelSize();
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _errorMessage = error.toString();
            _modelStatus = ModelStatus.error;
            _isLoading = false;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _progressSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkModelStatus() async {
    setState(() => _isLoading = true);
    try {
      // First check stored status
      final status = await _modelService.getModelStatus();
      
      // Then verify if model actually exists and is valid
      final actuallyDownloaded = await _modelService.isModelActuallyDownloaded();
      
      final size = await _modelService.getModelSizeInBytes();
      
      if (mounted) {
        setState(() {
          _modelStatus = actuallyDownloaded ? ModelStatus.downloaded : 
                        (status == ModelStatus.error ? ModelStatus.error : ModelStatus.notDownloaded);
          _modelSize = size;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _modelStatus = ModelStatus.error;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateModelSize() async {
    try {
      final size = await _modelService.getModelSizeInBytes();
      if (mounted) {
        setState(() => _modelSize = size);
      }
    } catch (e) {
      debugPrint('Error updating model size: $e');
    }
  }

  Future<void> _loadToken() async {
    try {
      final token = await _modelService.getToken();
      if (token != null && mounted) {
        setState(() {
          _tokenController.text = token;
          _tokenSaved = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading token: $e');
    }
  }

  Future<void> _saveToken() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() => _errorMessage = 'Please enter a HuggingFace token');
      return;
    }

    try {
      await _modelService.saveToken(token);
      if (mounted) {
        setState(() {
          _tokenSaved = true;
          _errorMessage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Token saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to save token: $e');
      }
    }
  }

  Future<void> _deleteModel() async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Model'),
        content: const Text('Are you sure you want to delete the downloaded model? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _modelService.deleteModel();
      // Status will be updated via progress stream
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _downloadModel() async {
    if (_isLoading || _modelStatus == ModelStatus.downloading) return;
    
    // Save token before download
    await _saveToken();

    // Check if token was saved (but don't validate it)
    if (!_tokenSaved) {
      setState(() => _errorMessage = 'Please enter and save a HuggingFace token first.');
      return;
    }

    setState(() {
      _isLoading = true;
      _downloadProgress = 0.0;
      _downloadedBytes = 0;
      _totalBytes = 0;
      _downloadSpeed = 0;
      _eta = Duration.zero;
      _errorMessage = null;
    });

    try {
      await _modelService.downloadModel();
      // Status updates will come through the progress stream
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _cancelDownload() async {
    try {
      await _modelService.cancelDownload();
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() => _errorMessage = 'Failed to cancel download: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Model Management'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.save,
              color: _tokenSaved ? Colors.green : null,
            ),
            onPressed: _saveToken,
            tooltip: 'Save Token',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Token input section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'HuggingFace Authentication',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _tokenController,
                      decoration: InputDecoration(
                        labelText: 'HuggingFace Token',
                        hintText: 'Enter your HuggingFace read token',
                        border: const OutlineInputBorder(),
                        suffixIcon: _tokenSaved 
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                      ),
                      obscureText: true,
                      onChanged: (value) {
                        setState(() => _tokenSaved = false);
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Get your token from: https://huggingface.co/settings/tokens',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Model status section
            if (_isLoading && _modelStatus != ModelStatus.downloading)
              const Center(child: CircularProgressIndicator())
            else
              _buildStatusSection(),

            const Spacer(),

            // Error message
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Go to chat button
            ElevatedButton(
              onPressed: _modelStatus == ModelStatus.downloaded ? _navigateToChat : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: _modelStatus == ModelStatus.downloaded
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
                foregroundColor: Colors.white,
              ),
              child: Text(
                _modelStatus == ModelStatus.downloaded
                    ? 'Go to Chat'
                    : 'Download model to enable chat',
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildModelStatusWidget() {
    switch (_modelStatus) {
      case ModelStatus.notDownloaded:
        return const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Model not downloaded'),
            SizedBox(height: 4),
            Text(
              'Download the Gemma-2B model to start chatting',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        );
        
      case ModelStatus.downloading:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Downloading...'),
                Text('${(_downloadProgress * 100).toStringAsFixed(1)}%'),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _downloadProgress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
            ),
            const SizedBox(height: 8),
            if (_totalBytes > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_modelService.formatFileSize(_downloadedBytes)} / ${_modelService.formatFileSize(_totalBytes)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  if (_downloadSpeed > 0)
                    Text(
                      _modelService.formatSpeed(_downloadSpeed),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
              if (_eta.inSeconds > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'ETA: ${_modelService.formatDuration(_eta.inSeconds)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          ],
        );
        
      case ModelStatus.downloaded:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text('Model downloaded successfully'),
              ],
            ),
            const SizedBox(height: 4),
            if (_modelSize > 0)
              Text(
                'Size: ${_modelService.formatFileSize(_modelSize)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        );
        
      case ModelStatus.error:
        return const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 20),
                SizedBox(width: 8),
                Text(
                  'Error with model',
                  style: TextStyle(color: Colors.red),
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              'Try downloading again or check your token',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        );
        
      case ModelStatus.cancelled:
        return const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cancel_outlined, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Text(
                  'Download cancelled',
                  style: TextStyle(color: Colors.orange),
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              'You can restart the download anytime',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        );
    }
  }

  Widget _buildStatusSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.smart_toy, size: 24),
                SizedBox(width: 8),
                Text(
                  'Gemma-2B Model',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildModelStatusWidget(),
            const SizedBox(height: 16),
            _buildModelActionsWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildModelActionsWidget() {
    switch (_modelStatus) {
      case ModelStatus.notDownloaded:
      case ModelStatus.error:
      case ModelStatus.cancelled:
        return ElevatedButton.icon(
          onPressed: !_isLoading && _tokenSaved ? _downloadModel : null,
          icon: const Icon(Icons.download),
          label: Text(_modelStatus == ModelStatus.error ? 'Retry Download' : 'Download Model'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        );
        
      case ModelStatus.downloading:
        return Column(
          children: [
            ElevatedButton.icon(
              onPressed: _cancelDownload,
              icon: const Icon(Icons.cancel),
              label: const Text('Cancel Download'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Downloading... ${(_downloadProgress * 100).toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        );
        
      case ModelStatus.downloaded:
        return Row(
          children: [
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _deleteModel,
                icon: const Icon(Icons.delete),
                label: const Text('Delete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: ElevatedButton.icon(
                onPressed: !_isLoading ? _downloadModel : null,
                icon: const Icon(Icons.refresh),
                label: const Text('Re-download'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        );
    }
  }

  void _navigateToChat() {
    // Navigate to the chat screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const ChatScreen()),
    );
  }
}