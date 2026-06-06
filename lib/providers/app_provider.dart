import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../core/models/device_info.dart';
import '../core/models/received_item.dart';
import '../core/server/transfer_server.dart';
import '../core/client/transfer_client.dart';
import '../core/discovery/discovery_service.dart';
import '../core/utils/network_utils.dart';

enum ConnectionStatus { idle, connecting, connected, failed }

class SendTask {
  final String id;
  final String targetName;
  final String itemName;
  double progress; // 0.0 ~ 1.0, -1 = done, -2 = error
  String? error;

  SendTask({
    required this.id,
    required this.targetName,
    required this.itemName,
    this.progress = 0.0,
    this.error,
  });

  bool get isDone => progress < 0;
  bool get isError => progress == -2.0;
}

class AppProvider extends ChangeNotifier {
  DeviceInfo? _myDevice;
  final List<DeviceInfo> _nearbyDevices = [];
  final List<ReceivedItem> _receivedItems = [];
  final List<SendTask> _sendTasks = [];
  bool _serverRunning = false;

  final _server = TransferServer();
  final _client = TransferClient();
  DiscoveryService? _discovery;

  // ── Getters ──────────────────────────────────────────────────────────────
  DeviceInfo? get myDevice => _myDevice;
  List<DeviceInfo> get nearbyDevices => List.unmodifiable(_nearbyDevices);
  List<ReceivedItem> get receivedItems =>
      List.unmodifiable(_receivedItems.reversed.toList());
  List<SendTask> get activeSendTasks =>
      _sendTasks.where((t) => !t.isDone).toList();
  bool get serverRunning => _serverRunning;
  int get unreadCount => _receivedItems.length;

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> init() async {
    final ip = await NetworkUtils.getLocalIp();
    final name = await NetworkUtils.getDeviceName();
    final os = NetworkUtils.getOsName();
    final id = const Uuid().v4();

    _myDevice = DeviceInfo(
      id: id,
      name: name,
      ip: ip,
      port: TransferServer.port,
      os: os,
    );
    notifyListeners();

    await _startServer();
    await _startDiscovery();
  }

  Future<void> _startServer() async {
    if (_myDevice == null) return;
    await _server.start(
      myDevice: _myDevice!,
      onReceived: (item) {
        _receivedItems.add(item);
        notifyListeners();
      },
    );
    _serverRunning = true;
    notifyListeners();
  }

  Future<void> _startDiscovery() async {
    if (_myDevice == null) return;
    _discovery = DiscoveryService(
      onDeviceFound: (device) {
        if (device.id == _myDevice!.id) return; // 忽略自己
        final idx = _nearbyDevices.indexWhere((d) => d.id == device.id);
        if (idx >= 0) {
          _nearbyDevices[idx] = device;
        } else {
          _nearbyDevices.add(device);
        }
        notifyListeners();
      },
      onDeviceLost: (id) {
        _nearbyDevices.removeWhere((d) => d.id == id);
        notifyListeners();
      },
    );
    await _discovery!.startBroadcast(_myDevice!);
    await _discovery!.startDiscovery();
  }

  // ── 连接：ping 目标设备 ────────────────────────────────────────────────
  Future<DeviceInfo?> connectTo(String ip, int port) async {
    final device = await _client.ping(ip, port);
    if (device != null) {
      // 补上 IP（mDNS 可能已经有，手动连接需要补）
      final withIp = DeviceInfo(
        id: device.id,
        name: device.name,
        ip: ip,
        port: port,
        os: device.os,
      );
      if (!_nearbyDevices.any((d) => d.id == withIp.id)) {
        _nearbyDevices.add(withIp);
        notifyListeners();
      }
      return withIp;
    }
    return null;
  }

  // ── 发送文本 ──────────────────────────────────────────────────────────────
  Future<bool> sendText(DeviceInfo target, String text) async {
    if (_myDevice == null) return false;
    final result = await _client.sendText(
      target: target,
      me: _myDevice!,
      text: text,
    );
    return result.success;
  }

  // ── 发送文件 ──────────────────────────────────────────────────────────────
  Future<bool> sendFile(DeviceInfo target, File file) async {
    if (_myDevice == null) return false;
    final taskId = const Uuid().v4();
    final fileName = file.path.split(Platform.pathSeparator).last;

    final task = SendTask(
      id: taskId,
      targetName: target.name,
      itemName: fileName,
    );
    _sendTasks.add(task);
    notifyListeners();

    final result = await _client.sendFile(
      target: target,
      me: _myDevice!,
      file: file,
      onProgress: (p) {
        task.progress = p;
        notifyListeners();
      },
    );

    task.progress = result.success ? -1.0 : -2.0;
    task.error = result.error;
    notifyListeners();

    // 3秒后清除已完成任务
    Future.delayed(const Duration(seconds: 3), () {
      _sendTasks.remove(task);
      notifyListeners();
    });

    return result.success;
  }

  void clearReceived() {
    _receivedItems.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _server.stop();
    _discovery?.stop();
    super.dispose();
  }
}
