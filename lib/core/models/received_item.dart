import 'device_info.dart';

enum ItemType { text, file }

class ReceivedItem {
  final String id;
  final ItemType type;

  /// text: 文本内容；file: 本地保存路径
  final String content;

  final String? fileName;
  final int? fileSize;
  final DeviceInfo sender;
  final DateTime receivedAt;

  const ReceivedItem({
    required this.id,
    required this.type,
    required this.content,
    this.fileName,
    this.fileSize,
    required this.sender,
    required this.receivedAt,
  });

  bool get isText => type == ItemType.text;
  bool get isFile => type == ItemType.file;

  String get displayName {
    if (isText) return '文本消息';
    return fileName ?? '未知文件';
  }
}
