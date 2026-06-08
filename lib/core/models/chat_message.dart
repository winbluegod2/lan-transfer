import 'dart:convert';

enum MessageDirection { sent, received }
enum MessageType { text, file }

class ChatMessage {
  final String id;
  final String peerId;
  final String peerName;
  final String peerOs;
  final MessageDirection direction;
  final MessageType type;
  final String content; // text content or file path
  final String? fileName;
  final int? fileSize;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.peerId,
    required this.peerName,
    required this.peerOs,
    required this.direction,
    required this.type,
    required this.content,
    this.fileName,
    this.fileSize,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'peerId': peerId,
        'peerName': peerName,
        'peerOs': peerOs,
        'direction': direction.name,
        'type': type.name,
        'content': content,
        'fileName': fileName,
        'fileSize': fileSize,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        peerId: json['peerId'] as String,
        peerName: json['peerName'] as String,
        peerOs: json['peerOs'] as String? ?? 'unknown',
        direction:
            MessageDirection.values.byName(json['direction'] as String),
        type: MessageType.values.byName(json['type'] as String),
        content: json['content'] as String,
        fileName: json['fileName'] as String?,
        fileSize: json['fileSize'] as int?,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
