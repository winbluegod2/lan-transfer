import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../core/models/device_info.dart';
import '../core/utils/network_utils.dart';
import '../providers/app_provider.dart';

class SendScreen extends StatefulWidget {
  final DeviceInfo target;
  const SendScreen({super.key, required this.target});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _textCtrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              NetworkUtils.osIcon(widget.target.os),
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.target.name,
                      style: const TextStyle(fontSize: 16)),
                  Text(
                    widget.target.address,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withOpacity(0.5),
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.text_fields), text: '文本'),
            Tab(icon: Icon(Icons.attach_file), text: '文件'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTextTab(context),
          _buildFileTab(context),
        ],
      ),
    );
  }

  // ── 文本 Tab ──────────────────────────────────────────────────────────────
  Widget _buildTextTab(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: TextField(
              controller: _textCtrl,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText: '输入要发送的文本...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _sending ? null : _sendText,
              icon: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
              label: Text(_sending ? '发送中...' : '发送'),
            ),
          ),
        ],
      ),
    );
  }

  // ── 文件 Tab ──────────────────────────────────────────────────────────────
  Widget _buildFileTab(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.upload_file_outlined,
              size: 72,
              color:
                  Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              '选择文件发送给对方',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '支持任意类型文件',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _sending ? null : _pickAndSendFile,
                icon: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.folder_open),
                label: Text(_sending ? '发送中...' : '选择文件'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      _showSnack('请输入内容', isError: true);
      return;
    }
    setState(() => _sending = true);
    final provider = context.read<AppProvider>();
    final ok = await provider.sendText(widget.target, text);
    setState(() => _sending = false);

    if (ok) {
      _textCtrl.clear();
      _showSnack('发送成功 ✓');
    } else {
      _showSnack('发送失败，对方可能已离线', isError: true);
    }
  }

  Future<void> _pickAndSendFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;

    final path = result.files.first.path;
    if (path == null) {
      _showSnack('无法获取文件路径', isError: true);
      return;
    }

    setState(() => _sending = true);
    final provider = context.read<AppProvider>();
    final ok = await provider.sendFile(widget.target, File(path));
    setState(() => _sending = false);

    if (ok) {
      _showSnack('文件发送成功 ✓');
    } else {
      _showSnack('发送失败，对方可能已离线', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          isError ? Theme.of(context).colorScheme.error : null,
      behavior: SnackBarBehavior.floating,
    ));
  }
}
