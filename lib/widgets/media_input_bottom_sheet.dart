import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../models/chat_message.dart';
import '../services/audio_service.dart';

class MediaInputBottomSheet extends StatefulWidget {
  final Function({
    required String content,
    required MessageType type,
    String? filePath,
  }) onSendMessage;

  const MediaInputBottomSheet({
    super.key,
    required this.onSendMessage,
  });

  @override
  State<MediaInputBottomSheet> createState() => _MediaInputBottomSheetState();
}

class _MediaInputBottomSheetState extends State<MediaInputBottomSheet> {
  final TextEditingController _promptController = TextEditingController();
  final AudioService _audioService = AudioService();
  File? _selectedFile;
  MessageType _selectedType = MessageType.image;
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _recordedAudioPath;

  Future<void> _pickFile() async {
    if (_selectedType == MessageType.image) {
      await _pickImage();
    } else {
      await _pickAudio();
    }
  }

  Future<void> _pickImage() async {
    try {
      // Show options for camera or gallery
      final ImageSource? source = await _showImageSourceDialog();
      if (source == null) return;

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedFile = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Image Source'),
        content: const Text('Choose where to get the image from:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
            child: const Text('Gallery'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(ImageSource.camera),
            child: const Text('Camera'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAudio() async {
    final choice = await _showAudioSourceDialog();
    if (choice == null) return;

    if (choice == 'record') {
      await _recordAudio();
    } else if (choice == 'file') {
      await _pickAudioFile();
    }
  }

  Future<String?> _showAudioSourceDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Audio Source'),
        content: const Text('Choose how to get the audio:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('file'),
            child: const Text('Pick File'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('record'),
            child: const Text('Record'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAudioFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _recordedAudioPath = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking audio file: $e')),
        );
      }
    }
  }

  Future<void> _recordAudio() async {
    try {
      if (!_isRecording) {
        final hasPermission = await _audioService.hasMicrophonePermission();
        if (!hasPermission) {
          final granted = await _audioService.requestMicrophonePermission();
          if (!granted) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Microphone permission is required for recording')),
              );
            }
            return;
          }
        }

        final started = await _audioService.startRecording();
        if (started) {
          setState(() {
            _isRecording = true;
          });
        }
      } else {
        final recordingPath = await _audioService.stopRecording();
        setState(() {
          _isRecording = false;
          if (recordingPath != null) {
            _recordedAudioPath = recordingPath;
            _selectedFile = File(recordingPath);
          }
        });
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error recording audio: $e')),
        );
      }
    }
  }

  Future<void> _playRecordedAudio() async {
    if (_recordedAudioPath == null) return;

    try {
      if (!_isPlaying) {
        final success = await _audioService.playAudio(_recordedAudioPath!);
        if (success) {
          setState(() {
            _isPlaying = true;
          });
          
          // Listen for playback completion (simplified)
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              setState(() {
                _isPlaying = false;
              });
            }
          });
        }
      } else {
        await _audioService.stopAudio();
        setState(() {
          _isPlaying = false;
        });
      }
    } catch (e) {
      setState(() {
        _isPlaying = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing audio: $e')),
        );
      }
    }
  }



  void _sendMessage() {
    final prompt = _promptController.text.trim();
    
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file first')),
      );
      return;
    }

    print('MediaInputBottomSheet: Sending message with type: $_selectedType, filePath: ${_selectedFile!.path}, prompt: "$prompt"');
    
    widget.onSendMessage(
      content: prompt.isEmpty ? 'What do you see/hear in this file?' : prompt,
      type: _selectedType,
      filePath: _selectedFile!.path,
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Title
            const Text(
              'Send Media',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            // Media type selection
            Row(
              children: [
                Expanded(
                  child: RadioListTile<MessageType>(
                    title: const Text('Image'),
                    value: MessageType.image,
                    groupValue: _selectedType,
                    onChanged: (value) {
                      setState(() {
                        _selectedType = value!;
                        _selectedFile = null; // Reset selection
                      });
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<MessageType>(
                    title: const Text('Audio'),
                    value: MessageType.audio,
                    groupValue: _selectedType,
                    onChanged: (value) {
                      setState(() {
                        _selectedType = value!;
                        _selectedFile = null; // Reset selection
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // File selection
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Icon(
                    _selectedType == MessageType.image 
                        ? Icons.image 
                        : Icons.audiotrack,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedFile != null
                        ? 'Selected: ${_selectedFile!.path.split('/').last}'
                        : _isRecording 
                            ? 'Recording...'
                            : 'No file selected',
                    style: TextStyle(
                      color: _selectedFile != null 
                          ? Colors.green 
                          : _isRecording 
                              ? Colors.orange
                              : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Column(
                    children: [
                      if (_selectedType == MessageType.audio && _recordedAudioPath != null) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _playRecordedAudio,
                            icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                            label: Text(_isPlaying ? 'Stop Playback' : 'Play Recording'),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _selectedType == MessageType.audio && _isRecording 
                              ? _recordAudio
                              : _pickFile,
                          icon: Icon(
                            _selectedType == MessageType.image 
                                ? Icons.folder_open
                                : _isRecording 
                                    ? Icons.stop
                                    : Icons.mic,
                          ),
                          label: Text(
                            _selectedType == MessageType.image 
                                ? 'Select Image'
                                : _isRecording 
                                    ? 'Stop Recording'
                                    : 'Record/Select Audio',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isRecording ? Colors.red : null,
                            foregroundColor: _isRecording ? Colors.white : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Prompt input
            TextField(
              controller: _promptController,
              decoration: InputDecoration(
                labelText: 'Optional prompt',
                hintText: _selectedType == MessageType.image
                    ? 'Ask about the image...'
                    : 'Ask about the audio...',
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedFile != null ? _sendMessage : null,
                    child: const Text('Send'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }
}