import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../core/models/device_info.dart';
import '../core/utils/network_utils.dart';
import 'send_screen.dart';
import 'received_items_screen.dart';
import 'qr_display_screen.dart';
import 'qr_scan_screen.dart';
import 'manual_connect_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, provider, cs),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  _DevicesTab(onDeviceTap: _openSend),
                  const ReceivedItemsScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.devices_other_outlined),
            selectedIcon: Icon(Icons.devices_other),
            label: '设备',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: provider.receivedItems.isNotEmpty,
              label: Text('${provider.receivedItems.length}'),
              child: const Icon(Icons.inbox_outlined),
            ),
            selectedIcon: const Icon(Icons.inbox),
            label: '收件箱',
          ),
        ],
      ),
      floatingActionButton: _tab == 0
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 手动输入 IP
                FloatingActionButton.small(
                  heroTag: 'manual',
                  onPressed: () => _openManualConnect(context),
                  tooltip: '手动输入 IP',
                  child: const Icon(Icons.keyboard_alt_outlined),
                ),
                const SizedBox(height: 8),
                // 扫描二维码（仅移动端）
                if (Platform.isAndroid || Platform.isIOS)
                  FloatingActionButton.small(
                    heroTag: 'scan',
                    onPressed: () => _openQrScan(context),
                    tooltip: '扫描二维码',
                    child: const Icon(Icons.qr_code_scanner),
                  ),
              ],
            )
          : null,
    );
  }

  Widget _buildHeader(
      BuildContext context, AppProvider provider, ColorScheme cs) {
    final me = provider.myDevice;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'LAN Transfer',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              // 服务状态指示
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                      provider.serverRunning ? '运行中' : '未启动',
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
            ],
          ),
          const SizedBox(height: 10),
          // 本机信息卡片
          if (me != null) _MyDeviceCard(device: me),
          const SizedBox(height: 4),
          // 传输进度条（发送中）
          ...provider.activeSendTasks.map((task) => _SendProgressTile(task: task)),
        ],
      ),
    );
  }

  void _openSend(BuildContext context, DeviceInfo device) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SendScreen(target: device)),
    );
  }

  void _openQrScan(BuildContext context) async {
    final device = await Navigator.push<DeviceInfo>(
      context,
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (device != null && mounted) _openSend(context, device);
  }

  void _openManualConnect(BuildContext context) async {
    final device = await Navigator.push<DeviceInfo>(
      context,
      MaterialPageRoute(builder: (_) => const ManualConnectScreen()),
    );
    if (device != null && mounted) _openSend(context, device);
  }
}

// ── 本机信息卡片 ──────────────────────────────────────────────────────────

class _MyDeviceCard extends StatelessWidget {
  final DeviceInfo device;
  const _MyDeviceCard({required this.device});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.primaryContainer.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Text(
              NetworkUtils.osIcon(device.os),
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  Text(
                    device.address,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withOpacity(0.6),
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            // 显示二维码按钮
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

// ── 发送中进度条 ──────────────────────────────────────────────────────────

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
              Text(
                '${(task.progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 2),
          LinearProgressIndicator(value: task.progress, minHeight: 3),
        ],
      ),
    );
  }
}

// ── 设备列表 Tab ──────────────────────────────────────────────────────────

class _DevicesTab extends StatelessWidget {
  final void Function(BuildContext context, DeviceInfo device) onDeviceTap;
  const _DevicesTab({required this.onDeviceTap});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final devices = provider.nearbyDevices;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Text(
                  '附近设备',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.5),
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(width: 8),
                if (devices.isEmpty)
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.4),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (devices.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.radar,
                      size: 56,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.2)),
                  const SizedBox(height: 12),
                  Text(
                    '正在搜索局域网设备...',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '确保设备在同一 WiFi 网络',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.3),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.separated(
              itemCount: devices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) =>
                  _DeviceCard(device: devices[i], onTap: onDeviceTap),
            ),
          ),
      ],
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final DeviceInfo device;
  final void Function(BuildContext context, DeviceInfo device) onTap;

  const _DeviceCard({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Text(
          NetworkUtils.osIcon(device.os),
          style: const TextStyle(fontSize: 28),
        ),
        title: Text(device.name,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(
          device.address,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => onTap(context, device),
      ),
    );
  }
}
