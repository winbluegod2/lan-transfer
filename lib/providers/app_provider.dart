import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../core/models/chat_message.dart';
import '../core/models/device_info.dart';
import '../core/models/received_item.dart';
import '../core/server/transfer_server.dart';
import '../core/client/transfer_client.dart';
import '../core/discovery/discovery_service.dart';
import '../core/storage/message_store.dart';
import '../core/utils/network_utils.dart';

enum ConnectionStatus { idle, connecting, connected, failed }

class SendTask {
  final String id;
  final String targetName;
  final String itemName;
  double progress;
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
  final List<ChatMessage> _messages = [];
  final List<SendTask> _sendTasks = [];
  bool _serverRunning = false;

  // profile
  String? _customName;
  String? _avatarPath;
  bool _wakelockEnabled = false;

  final _server = TransferServer();
  final _client = TransferClient();
  final _store = MessageStore();
  DiscoveryService? _discovery;

  // ── Getters ──────────────────────────────────────────────────────────────
  DeviceInfo? get myDevice => _myDevice;
  List<DeviceInfo> get nearbyDevices => List.unmodifiable(_nearbyDevices);
  List<ChatMessage> get allMessages => List.unmodifiable(_messages);
  List<SendTask> get activeSendTasks =>
      _sendTasks.where((t) => !t.isDone).toList();
  bool get serverRunning => _serverRunning;
  String? get avatarPath => _avatarPath;
  bool get wakelockEnabled => _wakelockEnabled;

  List<ChatMessage> messagesFor(String peerId) =>
      _messages.where((m) => m.peerId == peerId).toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  /// All peers that have a conversation history (for offline peers display)
  List<({String id, String name, String os})> get knownPeers {
    final seen = <String, ({String id, String name, String os})>{};
    for (final m in _messages) {
      seen[m.peerId] = (id: m.peerId, name: m.peerName, os: m.peerOs);
    }
    return seen.values.toList();
  }

  int unreadFor(String peerId) =>
      _messages
          .where((m) => m.peerId == peerId && m.direction == MessageDirection.received)
          .length;

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> init() async {
    // Load profile
    final prefs = await SharedPreferences.getInstance();
    _customName = prefs.getString('profile_name');
    _avatarPath = prefs.getString('avatar_path');
    _wakelockEnabled = prefs.getBool('wakelock_enabled') ?? false;

    // Restore wakelock state
    if (_wakelockEnabled && (Platform.isAndroid || Platform.isIOS)) {
      WakelockPlus.toggle(enable: true);
    }

    // Load message history
    final saved = await _store.load();
    _messages.addAll(saved);
    notifyListeners();

    // Build device info
    final ip = await NetworkUtils.getLocalIp();
    final deviceName = await NetworkUtils.getDeviceName();
    final name = (_customName != null && _customName!.isNotEmpty)
        ? _customName!
        : deviceName;
    final os = NetworkUtils.getOsName();
    final id = prefs.getString('device_id') ?? const Uuid().v4();
    await prefs.setString('device_id', id);

    _myDevice = DeviceInfo(
      id: id,
      name: name,
      ip: ip,
      port: TransferServer.port,
      os: os,
    );
    notifyListeners();

    // Request runtime permissions on Android (needed for mDNS discovery)
    if (Platform.isAndroid) {
      await [
        Permission.nearbyWifiDevices,
        Permission.locationWhenInUse,
      ].request();
    }

    await _startServer();
    await _startDiscovery();
  }

  Future<void> _startServer() async {
    if (_myDevice == null) return;
    await _server.start(
      myDevice: _myDevice!,
      onReceived: (item) {
        final msg = ChatMessage(
          id: item.id,
          peerId: item.sender.id,
          peerName: item.sender.name,
          peerOs: item.sender.os,
          direction: MessageDirection.received,
          type: item.type == ItemType.text ? MessageType.text : MessageType.file,
          content: item.content,
          fileName: item.fileName,
          fileSize: item.fileSize,
          timestamp: item.receivedAt,
        );
        _messages.add(msg);
        _store.save(List.from(_messages));
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
        if (device.id == _myDevice!.id) return;
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

  // ── Profile ───────────────────────────────────────────────────────────────
  Future<void> saveProfile({String? name, String? avatarPath}) async {
    final prefs = await SharedPreferences.getInstance();
    if (name != null) {
      _customName = name;
      await prefs.setString('profile_name', name);
    }
    if (avatarPath != null) {
      _avatarPath = avatarPath;
      await prefs.setString('avatar_path', avatarPath);
    }
    // Update myDevice name
    if (_myDevice != null && name != null) {
      _myDevice = DeviceInfo(
        id: _myDevice!.id,
        name: name.isNotEmpty ? name : _myDevice!.name,
        ip: _myDevice!.ip,
        port: _myDevice!.port,
        os: _myDevice!.os,
      );
    }
    notifyListeners();
  }

  // ── Wakelock ──────────────────────────────────────────────────────────────
  Future<void> toggleWakelock() async {
    _wakelockEnabled = !_wakelockEnabled;
    await WakelockPlus.toggle(enable: _wakelockEnabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('wakelock_enabled', _wakelockEnabled);
    notifyListeners();
  }

  // ── Connect ───────────────────────────────────────────────────────────────
  Future<DeviceInfo?> connectTo(String ip, int port) async {
    final device = await _client.ping(ip, port);
    if (device != null) {
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

  // ── Send text ─────────────────────────────────────────────────────────────
  Future<String?> sendText(DeviceInfo target, String text) async {
    if (_myDevice == null) return 'not initialized';
    final result = await _client.sendText(
      target: target,
      me: _myDevice!,
      text: text,
    );
    if (result.success) {
      _addSentMessage(
        target: target,
        type: MessageType.text,
        content: text,
      );
    }
    return result.success ? null : result.error;
  }

  // ── Send file ─────────────────────────────────────────────────────────────
  Future<String?> sendFile(DeviceInfo target, File file) async {
    if (_myDevice == null) return 'not initialized';
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

    Future.delayed(const Duration(seconds: 3), () {
      _sendTasks.remove(task);
      notifyListeners();
    });

    if (result.success) {
      _addSentMessage(
        target: target,
        type: MessageType.file,
        content: file.path,
        fileName: fileName,
        fileSize: file.lengthSync(),
      );
    }
    return result.success ? null : result.error;
  }

  void _addSentMessage({
    required DeviceInfo target,
    required MessageType type,
    required String content,
    String? fileName,
    int? fileSize,
  }) {
    final msg = ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      peerId: target.id,
      peerName: target.name,
      peerOs: target.os,
      direction: MessageDirection.sent,
      type: type,
      content: content,
      fileName: fileName,
      fileSize: fileSize,
      timestamp: DateTime.now(),
    );
    _messages.add(msg);
    _store.save(List.from(_messages));
    notifyListeners();
  }

  // ── Delete message ────────────────────────────────────────────────────────
  void deleteMessage(String messageId) {
    _messages.removeWhere((m) => m.id == messageId);
    _store.save(List.from(_messages));
    notifyListeners();
  }

  @override
  void dispose() {
    _server.stop();
    _discovery?.stop();
    super.dispose();
  }
}
