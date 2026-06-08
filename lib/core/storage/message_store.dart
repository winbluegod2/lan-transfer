import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/chat_message.dart';

class MessageStore {
  static const _filename = 'lan_transfer_messages.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_filename');
  }

  Future<List<ChatMessage>> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return [];
      final raw = await file.readAsString();
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<ChatMessage> messages) async {
    try {
      final file = await _file();
      await file.writeAsString(
          jsonEncode(messages.map((m) => m.toJson()).toList()));
    } catch (_) {}
  }
}
