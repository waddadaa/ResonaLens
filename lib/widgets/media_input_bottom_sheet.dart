import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/chat_message.dart';

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
  File? _selectedFile;
  MessageType _selectedType = MessageType.image;

  Future<void> _pickFile() async {
    if (_selectedType == MessageType.image) {
      await _pickImage();
    } else {
      // For audio, we'll keep the placeholder for now
      _showAudioPickerDialog();
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

  void _showAudioPickerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Audio'),
        content: const Text(
          'Audio file selection is not yet implemented.\n\n'
          'This feature will be added in a future update.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
                        : 'No file selected',
                    style: TextStyle(
                      color: _selectedFile != null ? Colors.green : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.folder_open),
                    label: Text('Select ${_selectedType == MessageType.image ? 'Image' : 'Audio'}'),
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