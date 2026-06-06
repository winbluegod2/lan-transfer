import 'dart:convert';

class DeviceInfo {
  final String id;
  final String name;
  final String ip;
  final int port;
  final String os; // ios | android | macos | windows | linux

  const DeviceInfo({
    required this.id,
    required this.name,
    required this.ip,
    required this.port,
    required this.os,
  });

  String get address => '$ip:$port';

  /// 用于二维码内容
  String toQrData() => jsonEncode(toJson());

  static DeviceInfo? fromQrData(String data) {
    try {
      return fromJson(jsonDecode(data));
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ip': ip,
        'port': port,
        'os': os,
      };

  factory DeviceInfo.fromJson(Map<String, dynamic> json) => DeviceInfo(
        id: json['id'] as String,
        name: json['name'] as String,
        ip: json['ip'] as String,
        port: json['port'] as int,
        os: json['os'] as String,
      );

  DeviceInfo copyWith({String? ip}) => DeviceInfo(
        id: id,
        name: name,
        ip: ip ?? this.ip,
        port: port,
        os: os,
      );

  @override
  bool operator ==(Object other) => other is DeviceInfo && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
