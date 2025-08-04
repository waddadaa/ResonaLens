import 'dart:io';
import 'package:flutter/material.dart';
import '../models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == MessageSender.user;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue[600],
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser ? Colors.blue[600] : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMessageContent(),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 12,
                      color: isUser ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.green[600],
              child: const Icon(Icons.person, color: Colors.white, size: 16),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageContent() {
    final isUser = message.sender == MessageSender.user;
    final textColor = isUser ? Colors.white : Colors.black;

    if (message.isLoading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(textColor),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            message.content,
            style: TextStyle(color: textColor),
          ),
        ],
      );
    }

    switch (message.type) {
      case MessageType.text:
        return Text(
          message.content,
          style: TextStyle(color: textColor),
        );
        
      case MessageType.image:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.filePath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(message.filePath!),
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 200,
                      height: 200,
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image),
                    );
                  },
                ),
              ),
            if (message.content.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                message.content,
                style: TextStyle(color: textColor),
              ),
            ],
          ],
        );
        
      case MessageType.audio:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isUser ? Colors.blue[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.audiotrack,
                    color: textColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Audio message',
                    style: TextStyle(color: textColor),
                  ),
                ],
              ),
            ),
            if (message.content.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                message.content,
                style: TextStyle(color: textColor),
              ),
            ],
          ],
        );
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${time.day}/${time.month} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}