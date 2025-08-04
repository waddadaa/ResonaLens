enum MessageType { text, image, audio }

enum MessageSender { user, assistant }

class ChatMessage {
  final String id;
  final String content;
  final MessageType type;
  final MessageSender sender;
  final DateTime timestamp;
  final String? filePath; // For image/audio files
  final bool isLoading;

  ChatMessage({
    required this.id,
    required this.content,
    required this.type,
    required this.sender,
    required this.timestamp,
    this.filePath,
    this.isLoading = false,
  });

  ChatMessage copyWith({
    String? id,
    String? content,
    MessageType? type,
    MessageSender? sender,
    DateTime? timestamp,
    String? filePath,
    bool? isLoading,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      type: type ?? this.type,
      sender: sender ?? this.sender,
      timestamp: timestamp ?? this.timestamp,
      filePath: filePath ?? this.filePath,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}