import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nameCtrl;
  String? _avatarPath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<AppProvider>();
    _nameCtrl = TextEditingController(text: provider.myDevice?.name ?? '');
    _avatarPath = provider.avatarPath;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final srcPath = result.files.first.path;
    if (srcPath == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final ext = srcPath.split('.').last;
    final dest = '${dir.path}/avatar.$ext';
    await File(srcPath).copy(dest);
    setState(() => _avatarPath = dest);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await context.read<AppProvider>().saveProfile(
          name: _nameCtrl.text.trim(),
          avatarPath: _avatarPath,
        );
    setState(() => _saving = false);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickAvatar,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 52,
                    backgroundColor: cs.primaryContainer,
                    backgroundImage: _avatarPath != null
                        ? FileImage(File(_avatarPath!))
                        : null,
                    child: _avatarPath == null
                        ? Text(
                            _nameCtrl.text.isNotEmpty
                                ? _nameCtrl.text[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                                fontSize: 36, color: cs.onPrimaryContainer),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: cs.primary,
                      child: Icon(Icons.camera_alt,
                          size: 16, color: cs.onPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('点击头像更换图片',
                style: TextStyle(
                    color: cs.onSurface.withOpacity(0.5), fontSize: 12)),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _nameCtrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: '显示名称',
              hintText: '输入你的名字',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '名称将在局域网中广播给其他设备，重启 App 后生效于 mDNS 广播。',
            style: TextStyle(
                fontSize: 12, color: cs.onSurface.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }
}
