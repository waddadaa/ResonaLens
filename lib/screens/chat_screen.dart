import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/media_input_bottom_sheet.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService.instance;
  
  List<ChatMessage> _messages = [];
  bool _isModelLoading = false;
  bool _isGenerating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeModel();
  }

  Future<void> _initializeModel() async {
    setState(() {
      _isModelLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await _chatService.initializeModel();
      if (!success) {
        _errorMessage = 'Failed to initialize the model. Please check the model file.';
      }
    } catch (e) {
      _errorMessage = 'Error initializing model: $e';
    } finally {
      setState(() => _isModelLoading = false);
    }
  }

  Future<void> _sendMessage({
    required String content,
    required MessageType type,
    String? filePath,
  }) async {
    if (content.trim().isEmpty && type == MessageType.text) return;
    if (!_chatService.isInitialized) {
      _showError('Model not initialized');
      return;
    }

    print('ChatScreen: Creating message with type: $type, content: "$content", filePath: $filePath');
    
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      type: type,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
      filePath: filePath,
    );
    
    print('ChatScreen: Created message - type: ${userMessage.type}, filePath: ${userMessage.filePath}');

    final loadingMessage = ChatMessage(
      id: '${DateTime.now().millisecondsSinceEpoch + 1}',
      content: 'Thinking...',
      type: MessageType.text,
      sender: MessageSender.assistant,
      timestamp: DateTime.now(),
      isLoading: true,
    );

    setState(() {
      _messages.add(userMessage);
      _messages.add(loadingMessage);
      _isGenerating = true;
    });

    _scrollToBottom();
    _messageController.clear();

    try {
      final response = await _chatService.generateResponse(userMessage);
      
      setState(() {
        _messages.removeLast(); // Remove loading message
        _messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: response,
          type: MessageType.text,
          sender: MessageSender.assistant,
          timestamp: DateTime.now(),
        ));
      });
    } catch (e) {
      setState(() {
        _messages.removeLast(); // Remove loading message
        _messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: 'Error: ${e.toString()}',
          type: MessageType.text,
          sender: MessageSender.assistant,
          timestamp: DateTime.now(),
        ));
      });
    } finally {
      setState(() => _isGenerating = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showMediaInputBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MediaInputBottomSheet(
        onSendMessage: _sendMessage,
      ),
    );
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text('Are you sure you want to clear all messages?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() => _messages.clear());
              Navigator.of(context).pop();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Gemma Chat'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _messages.isNotEmpty ? _clearChat : null,
            icon: const Icon(Icons.clear_all),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Column(
        children: [
          // Error Banner
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.red[100],
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red[700]),
                textAlign: TextAlign.center,
              ),
            ),
          
          // Loading Banner
          if (_isModelLoading)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.blue[100],
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Initializing model...'),
                ],
              ),
            ),
          
          // Messages List
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text(
                      'Start a conversation with Gemma!\nYou can send text, images, or audio.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return MessageBubble(message: _messages[index]);
                    },
                  ),
          ),
          
          // Input Area
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _chatService.isInitialized && !_isGenerating
                      ? _showMediaInputBottomSheet
                      : null,
                  icon: const Icon(Icons.attach_file),
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    maxLines: null,
                    enabled: _chatService.isInitialized && !_isGenerating,
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        _sendMessage(
                          content: value.trim(),
                          type: MessageType.text,
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    print('Send button debug:');
                    print('  isInitialized: ${_chatService.isInitialized}');
                    print('  isGenerating: $_isGenerating');
                    print('  text not empty: ${_messageController.text.trim().isNotEmpty}');
                    print('  text content: "${_messageController.text}"');
                    
                    if (_chatService.isInitialized && 
                        !_isGenerating && 
                        _messageController.text.trim().isNotEmpty) {
                      _sendMessage(
                        content: _messageController.text.trim(),
                        type: MessageType.text,
                      );
                    } else {
                      print('Send button conditions not met!');
                    }
                  },
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}