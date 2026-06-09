import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/models/chat_message.dart';
import '../core/models/device_info.dart';
import '../core/utils/network_utils.dart';
import '../core/utils/debug_logger.dart';
import '../providers/app_provider.dart';
import 'conversation_screen.dart';
import 'qr_display_screen.dart';
import 'qr_scan_screen.dart';
import 'manual_connect_screen.dart';
import 'settings_screen.dart';

final homeRouteObserver = RouteObserver<ModalRoute<void>>();

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    homeRouteObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    homeRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // 从子页面（如 ConversationScreen）返回时触发
    context.read<AppProvider>().refreshDiscovery();
  }

  void _openConversation(DeviceInfo device) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ConversationScreen(target: device)),
    );
  }

  void _openQrScan() async {
    final device = await Navigator.push<DeviceInfo>(
      context,
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (device != null && mounted) _openConversation(device);
  }

  void _openManualConnect() async {
    final device = await Navigator.push<DeviceInfo>(
      context,
      MaterialPageRoute(builder: (_) => const ManualConnectScreen()),
    );
    if (device != null && mounted) _openConversation(device);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final cs = Theme.of(context).colorScheme;
    final me = provider.myDevice;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('LAN Transfer',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      // 屏幕常亮（仅移动端）
                      if (Platform.isAndroid || Platform.isIOS)
                        Tooltip(
                          message: provider.wakelockEnabled ? '关闭屏幕常亮' : '开启屏幕常亮',
                          child: IconButton(
                            onPressed: () => context.read<AppProvider>().toggleWakelock(),
                            icon: Icon(
                              provider.wakelockEnabled
                                  ? Icons.brightness_high
                                  : Icons.brightness_low,
                              size: 20,
                              color: provider.wakelockEnabled ? Colors.amber : null,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      // 服务状态
                      Tooltip(
                        message: provider.serverError ?? '',
                        child: GestureDetector(
                          onTap: provider.serverRunning
                              ? null
                              : () => context.read<AppProvider>().retryServer(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: provider.serverRunning
                                  ? Colors.green.shade50
                                  : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: provider.serverRunning
                                    ? Colors.green.shade200
                                    : Colors.red.shade200,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle,
                                    size: 8,
                                    color: provider.serverRunning
                                        ? Colors.green
                                        : Colors.red),
                                const SizedBox(width: 4),
                                Text(
                                  provider.serverRunning ? '运行中' : '未启动（点击重试）',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: provider.serverRunning
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // 设置
                      IconButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SettingsScreen()),
                        ),
                        icon: const Icon(Icons.settings_outlined, size: 20),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (me != null) _MyDeviceCard(device: me, avatarPath: provider.avatarPath),
                  const SizedBox(height: 4),
                  ...provider.activeSendTasks.map((t) => _SendProgressTile(task: t)),
                ],
              ),
            ),
            // ── Device list ──────────────────────────────────────────────
            Expanded(
              child: _DeviceList(
                onDeviceTap: _openConversation,
              ),
            ),
            // ── Debug panel（仅 debug 模式）──────────────────────────────
            if (kDebugMode) const _DebugPanel(),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'manual',
            onPressed: _openManualConnect,
            tooltip: '手动输入 IP',
            child: const Icon(Icons.keyboard_alt_outlined),
          ),
          const SizedBox(height: 8),
          if (Platform.isAndroid || Platform.isIOS)
            FloatingActionButton.small(
              heroTag: 'scan',
              onPressed: _openQrScan,
              tooltip: '扫描二维码',
              child: const Icon(Icons.qr_code_scanner),
            ),
        ],
      ),
    );
  }
}

// ── 本机信息卡片 ──────────────────────────────────────────────────────────────

class _MyDeviceCard extends StatelessWidget {
  final DeviceInfo device;
  final String? avatarPath;
  const _MyDeviceCard({required this.device, this.avatarPath});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.primaryContainer.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: cs.primaryContainer,
              backgroundImage:
                  avatarPath != null ? FileImage(File(avatarPath!)) : null,
              child: avatarPath == null
                  ? Text(
                      NetworkUtils.osIcon(device.os),
                      style: const TextStyle(fontSize: 18),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(device.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  Text(device.address,
                      style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface.withOpacity(0.6),
                          fontFamily: 'monospace')),
                ],
              ),
            ),
            IconButton.filledTonal(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => QrDisplayScreen(device: device)),
              ),
              icon: const Icon(Icons.qr_code),
              tooltip: '显示二维码',
            ),
          ],
        ),
      ),
    );
  }
}

// ── 发送进度条 ────────────────────────────────────────────────────────────────

class _SendProgressTile extends StatelessWidget {
  final SendTask task;
  const _SendProgressTile({required this.task});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.upload_outlined, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '发送 ${task.itemName} → ${task.targetName}',
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('${(task.progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 2),
          LinearProgressIndicator(value: task.progress, minHeight: 3),
        ],
      ),
    );
  }
}

// ── 设备列表 ──────────────────────────────────────────────────────────────────

class _DeviceList extends StatelessWidget {
  final void Function(DeviceInfo device) onDeviceTap;
  const _DeviceList({required this.onDeviceTap});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final nearby = provider.nearbyDevices;
    final knownIds = nearby.map((d) => d.id).toSet();
    final offlinePeers = provider.knownPeers
        .where((p) => !knownIds.contains(p.id))
        .toList();

    return CustomScrollView(
      slivers: [
        // 附近设备
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          sliver: SliverToBoxAdapter(
            child: Row(children: [
              Text('附近设备',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.5),
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              if (nearby.isEmpty)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.4)),
                ),
            ]),
          ),
        ),
        if (nearby.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('正在搜索局域网设备...',
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.4))),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.separated(
              itemCount: nearby.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _DeviceCard(
                device: nearby[i],
                isOnline: true,
                onTap: onDeviceTap,
                provider: context.read<AppProvider>(),
              ),
            ),
          ),
        // 历史会话（离线）
        if (offlinePeers.isNotEmpty) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
            sliver: SliverToBoxAdapter(
              child: Text('历史会话',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.5),
                      fontWeight: FontWeight.w600)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverList.separated(
              itemCount: offlinePeers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final p = offlinePeers[i];
                final device = DeviceInfo(
                    id: p.id, name: p.name, ip: '', port: 0, os: p.os);
                return _DeviceCard(
                  device: device,
                  isOnline: false,
                  onTap: onDeviceTap,
                  provider: context.read<AppProvider>(),
                );
              },
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final DeviceInfo device;
  final bool isOnline;
  final void Function(DeviceInfo) onTap;
  final AppProvider provider;

  const _DeviceCard({
    required this.device,
    required this.isOnline,
    required this.onTap,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final messages = provider.messagesFor(device.id);
    final lastMsg = messages.isNotEmpty ? messages.last : null;
    final unread = provider.unreadFor(device.id);

    return Card(
      child: ListTile(
        leading: Stack(
          children: [
            Text(NetworkUtils.osIcon(device.os),
                style: const TextStyle(fontSize: 28)),
            if (isOnline)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.surface, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
        title: Text(device.name,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: lastMsg != null
            ? Text(
                lastMsg.type == MessageType.file
                    ? '📎 ${lastMsg.fileName ?? '文件'}'
                    : lastMsg.content,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: cs.onSurface.withOpacity(0.6), fontSize: 13),
              )
            : Text(
                isOnline ? device.address : '离线',
                style: TextStyle(
                    fontFamily: isOnline ? 'monospace' : null,
                    fontSize: 12,
                    color: cs.onSurface.withOpacity(isOnline ? 0.5 : 0.35)),
              ),
        trailing: unread > 0
            ? Badge(
                label: Text('$unread'),
                child: const Icon(Icons.chevron_right),
              )
            : const Icon(Icons.chevron_right),
        onTap: isOnline ? () => onTap(device) : null,
      ),
    );
  }
}

// ── Debug 面板（仅 debug 模式显示）────────────────────────────────────────────
class _DebugPanel extends StatefulWidget {
  const _DebugPanel();

  @override
  State<_DebugPanel> createState() => _DebugPanelState();
}

class _DebugPanelState extends State<_DebugPanel> {
  bool _expanded = false;
  List<String> _logs = DebugLogger.logs;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    DebugLogger.stream.listen((logs) {
      if (!mounted) return;
      setState(() => _logs = logs);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        border: const Border(top: BorderSide(color: Colors.green, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题栏
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.bug_report, color: Colors.green, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'DEBUG  ${_logs.length} events',
                    style: const TextStyle(
                        color: Colors.green,
                        fontSize: 11,
                        fontFamily: 'monospace'),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      DebugLogger.clear();
                      setState(() => _logs = []);
                    },
                    child: const Text('CLR',
                        style: TextStyle(
                            color: Colors.orange,
                            fontSize: 10,
                            fontFamily: 'monospace')),
                  ),
                  const SizedBox(width: 12),
                  Icon(_expanded ? Icons.expand_more : Icons.expand_less,
                      color: Colors.green, size: 16),
                ],
              ),
            ),
          ),
          // 日志内容
          if (_expanded)
            SizedBox(
              height: 180,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                itemCount: _logs.length,
                itemBuilder: (_, i) {
                  final line = _logs[i];
                  Color color = Colors.white70;
                  if (line.contains('ERROR')) color = Colors.red;
                  else if (line.contains('LOST') || line.contains('DONE')) color = Colors.orange;
                  else if (line.contains('resolved') || line.contains('started OK')) color = Colors.greenAccent;
                  else if (line.contains('refresh') || line.contains('restart') || line.contains('lifecycle')) color = Colors.yellow;
                  return Text(line,
                      style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontFamily: 'monospace'));
                },
              ),
            ),
        ],
      ),
    );
  }
}
