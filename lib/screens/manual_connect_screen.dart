import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/server/transfer_server.dart';
import '../providers/app_provider.dart';

class ManualConnectScreen extends StatefulWidget {
  const ManualConnectScreen({super.key});

  @override
  State<ManualConnectScreen> createState() => _ManualConnectScreenState();
}

class _ManualConnectScreenState extends State<ManualConnectScreen> {
  final _ipCtrl = TextEditingController();
  final _portCtrl =
      TextEditingController(text: TransferServer.port.toString());
  final _formKey = GlobalKey<FormState>();
  bool _connecting = false;

  @override
  void dispose() {
    _ipCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('手动输入 IP')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '输入对方设备的 IP 地址',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '对方需打开 LAN Transfer 并在同一 WiFi 网络',
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.5),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              // IP 输入
              TextFormField(
                controller: _ipCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                decoration: InputDecoration(
                  labelText: 'IP 地址',
                  hintText: '192.168.1.xxx',
                  prefixIcon: const Icon(Icons.computer_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '请输入 IP 地址';
                  final parts = v.trim().split('.');
                  if (parts.length != 4) return 'IP 格式不正确';
                  for (final p in parts) {
                    final n = int.tryParse(p);
                    if (n == null || n < 0 || n > 255) return 'IP 格式不正确';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // 端口输入
              TextFormField(
                controller: _portCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '端口',
                  hintText: '${TransferServer.port}',
                  prefixIcon: const Icon(Icons.settings_ethernet),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '请输入端口';
                  final n = int.tryParse(v.trim());
                  if (n == null || n < 1 || n > 65535) return '端口范围 1-65535';
                  return null;
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _connecting ? null : _connect,
                  icon: _connecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.link),
                  label: Text(_connecting ? '连接中...' : '连接'),
                ),
              ),
              const SizedBox(height: 24),
              // 提示：如何查找对方 IP
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          '如何找到对方 IP？',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '对方打开 LAN Transfer，首页会显示本机 IP 地址。\n'
                      '也可以让对方点击"显示二维码"，扫码自动填入。',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;

    final ip = _ipCtrl.text.trim();
    final port = int.parse(_portCtrl.text.trim());

    setState(() => _connecting = true);

    final provider = context.read<AppProvider>();
    final device = await provider.connectTo(ip, port);

    setState(() => _connecting = false);

    if (!mounted) return;

    if (device != null) {
      Navigator.pop(context, device);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('无法连接到 $ip:$port\n请检查：\n1. 是否在同一 WiFi\n2. 对方是否已打开 App'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
