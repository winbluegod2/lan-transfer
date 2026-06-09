import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';
import '../models/device_info.dart';
import '../utils/debug_logger.dart';

/// mDNS 服务：广播自己 + 发现局域网内其他设备
class DiscoveryService {
  static const _serviceType = '_lantransfer._tcp';

  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;

  final void Function(DeviceInfo device) onDeviceFound;
  final void Function(String deviceId) onDeviceLost;

  DiscoveryService({
    required this.onDeviceFound,
    required this.onDeviceLost,
  });

  /// 广播本机信息
  Future<void> startBroadcast(DeviceInfo me) async {
    DebugLogger.log('broadcast: start (${me.name} ${me.ip}:${me.port})');
    try {
      _broadcast = BonsoirBroadcast(
        service: BonsoirService(
          name: me.name,
          type: _serviceType,
          port: me.port,
          attributes: {
            'id': me.id,
            'os': me.os,
            'ip': me.ip,
          },
        ),
      );
      await _broadcast!.ready;
      await _broadcast!.start();
      DebugLogger.log('broadcast: started OK');
    } catch (e) {
      DebugLogger.log('broadcast: ERROR $e');
      debugPrint('LanTransfer broadcast error: $e');
      _broadcast = null;
    }
  }

  /// 开始发现局域网内其他设备
  Future<void> startDiscovery() async {
    DebugLogger.log('discovery: start');
    try {
      _discovery = BonsoirDiscovery(type: _serviceType);
      await _discovery!.ready;

      _discovery!.eventStream!.listen((event) {
        if (event.type == BonsoirDiscoveryEventType.discoveryServiceFound) {
          DebugLogger.log('discovery: found ${event.service?.name} → resolving');
          event.service?.resolve(_discovery!.serviceResolver);
        } else if (event.type ==
            BonsoirDiscoveryEventType.discoveryServiceResolved) {
          final service = event.service as ResolvedBonsoirService?;
          if (service == null) return;

          final attrs = service.attributes;
          final id = attrs?['id'];
          final os = attrs?['os'] ?? 'unknown';

          // 优先用服务属性里的 IPv4，避免 macOS 将 host 解析为 IPv6
          String? ip = attrs?['ip'];
          if (ip == null || ip.isEmpty) {
            ip = service.host;
            if (ip != null && ip.endsWith('.')) {
              ip = ip.substring(0, ip.length - 1);
            }
          }

          DebugLogger.log('discovery: resolved ${service.name} id=$id ip=$ip');
          if (id == null || ip == null || ip.isEmpty) return;

          onDeviceFound(DeviceInfo(
            id: id,
            name: service.name,
            ip: ip,
            port: service.port,
            os: os,
          ));
        } else if (event.type == BonsoirDiscoveryEventType.discoveryServiceLost) {
          final service = event.service;
          final id = service?.attributes?['id'];
          DebugLogger.log('discovery: LOST ${service?.name} id=$id');
          if (id != null) onDeviceLost(id);
        }
      }, onError: (e) {
        DebugLogger.log('discovery: stream ERROR $e');
        debugPrint('LanTransfer discovery error: $e');
      }, onDone: () {
        DebugLogger.log('discovery: stream DONE (closed)');
      });

      await _discovery!.start();
      DebugLogger.log('discovery: started OK');
    } catch (e) {
      DebugLogger.log('discovery: ERROR $e');
      debugPrint('LanTransfer discovery error: $e');
      _discovery = null;
    }
  }

  /// 只停止发现（不影响广播）
  Future<void> stopDiscoveryOnly() async {
    DebugLogger.log('discovery: stopOnly');
    await _discovery?.stop();
    _discovery = null;
  }

  /// 只重启发现（不影响广播），避免其他设备感知到本机下线
  Future<void> restartDiscovery() async {
    DebugLogger.log('discovery: restart');
    await stopDiscoveryOnly();
    await startDiscovery();
  }

  Future<void> stop() async {
    DebugLogger.log('discovery+broadcast: stop all');
    await _broadcast?.stop();
    await _discovery?.stop();
    _broadcast = null;
    _discovery = null;
  }
}
