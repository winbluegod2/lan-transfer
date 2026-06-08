import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import '../core/models/chat_message.dart';
import '../core/models/device_info.dart';
import '../core/utils/network_utils.dart';
import '../providers/app_provider.dart';

class ConversationScreen extends StatefulWidget {
  final DeviceInfo target;
  const ConversationScreen({super.key, required this.target});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    setState(() => _sending = true);
    final error = await context.read<AppProvider>().sendText(widget.target, text);
    setState(() => _sending = false);
    if (error != null && mounted) {
      _showSnack('发送失败：$error');
    } else {
      _scrollToBottom();
    }
  }

  Future<void> _sendFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: false, withData: false);
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;

    setState(() => _sending = true);
    final error = await context.read<AppProvider>().sendFile(widget.target, File(path));
    setState(() => _sending = false);
    if (error != null && mounted) {
      _showSnack('发送失败：$error');
    } else {
      _scrollToBottom();
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  void _onMessageLongPress(BuildContext context, ChatMessage msg) {
    final isDesktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (msg.type == MessageType.text)
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('复制文本'),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: msg.content));
                  _showSnack('已复制');
                },
              ),
            if (msg.type == MessageType.file) ...[
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: const Text('打开文件'),
                onTap: () {
                  Navigator.pop(context);
                  OpenFile.open(msg.content);
                },
              ),
              if (isDesktop)
                ListTile(
                  leading: const Icon(Icons.folder_open),
                  title: const Text('打开所在目录'),
                  onTap: () {
                    Navigator.pop(context);
                    _openFolder(msg.content);
                  },
                ),
            ],
            ListTile(
              leading: Icon(Icons.delete_outline, color: Colors.red.shade400),
              title: Text('删除', style: TextStyle(color: Colors.red.shade400)),
              onTap: () {
                Navigator.pop(context);
                context.read<AppProvider>().deleteMessage(msg.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openFolder(String filePath) {
    final dir = File(filePath).parent.path;
    if (Platform.isMacOS) {
      Process.run('open', ['-R', filePath]);
    } else if (Platform.isWindows) {
      // /select, and path must be one argument; use native backslashes
      final winPath = filePath.replaceAll('/', '\\');
      Process.run('explorer.exe', ['/select,$winPath']);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [dir]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Text(NetworkUtils.osIcon(widget.target.os),
                style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.target.name,
                      style: const TextStyle(fontSize: 16),
                      overflow: TextOverflow.ellipsis),
                  Text(widget.target.address,
                      style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withOpacity(0.5),
                          fontFamily: 'monospace')),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList(cs)),
          _buildInputBar(cs),
        ],
      ),
    );
  }

  Widget _buildMessageList(ColorScheme cs) {
    return Consumer<AppProvider>(
      builder: (_, provider, __) {
        final messages = provider.messagesFor(widget.target.id);
        if (messages.isEmpty) {
          return Center(
            child: Text('暂无消息',
                style: TextStyle(color: cs.onSurface.withOpacity(0.4))),
          );
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients &&
              _scrollCtrl.position.pixels >=
                  _scrollCtrl.position.maxScrollExtent - 80) {
            _scrollToBottom();
          }
        });
        return ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: messages.length,
          itemBuilder: (_, i) => _MessageBubble(
            message: messages[i],
            onTap: messages[i].type == MessageType.file
                ? () => OpenFile.open(messages[i].content)
                : null,
            onLongPress: () => _onMessageLongPress(context, messages[i]),
          ),
        );
      },
    );
  }

  Widget _buildInputBar(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _sending ? null : _sendFile,
            icon: const Icon(Icons.attach_file),
            tooltip: '发送文件',
          ),
          Expanded(
            child: TextField(
              controller: _textCtrl,
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendText(),
              decoration: InputDecoration(
                hintText: '输入消息...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 4),
          FilledButton(
            onPressed: _sending ? null : _sendText,
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(12),
            ),
            child: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send, size: 20),
          ),
        ],
      ),
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onTap;
  final VoidCallback onLongPress;

  const _MessageBubble({required this.message, this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final isSent = message.direction == MessageDirection.sent;
    final cs = Theme.of(context).colorScheme;

    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSent ? cs.primaryContainer : cs.surfaceContainerHigh,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isSent ? 16 : 4),
              bottomRight: Radius.circular(isSent ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.type == MessageType.file)
                _FileBubbleContent(message: message, isSent: isSent)
              else
                Text(
                  message.content,
                  style: TextStyle(
                    color: isSent ? cs.onPrimaryContainer : cs.onSurface,
                  ),
                ),
              const SizedBox(height: 2),
              Text(
                _formatTime(message.timestamp),
                style: TextStyle(
                  fontSize: 10,
                  color: (isSent ? cs.onPrimaryContainer : cs.onSurface)
                      .withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (msgDay == today) return time;
    return '${dt.month}/${dt.day} $time';
  }
}

class _FileBubbleContent extends StatelessWidget {
  final ChatMessage message;
  final bool isSent;

  const _FileBubbleContent({required this.message, required this.isSent});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = isSent ? cs.onPrimaryContainer : cs.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.insert_drive_file_outlined, color: color, size: 28),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.fileName ?? '文件',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w500, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
              if (message.fileSize != null)
                Text(
                  NetworkUtils.formatFileSize(message.fileSize!),
                  style: TextStyle(color: color.withOpacity(0.6), fontSize: 12),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
