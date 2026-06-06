import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../models/device_info.dart';

typedef ProgressCallback = void Function(double progress); // 0.0 ~ 1.0

class TransferResult {
  final bool success;
  final String? error;
  const TransferResult({required this.success, this.error});
}

class TransferClient {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 10),
  ));

  Map<String, String> _senderHeaders(DeviceInfo me) => {
        'x-sender-id': me.id,
        'x-sender-name': me.name,
        'x-sender-ip': me.ip,
        'x-sender-port': me.port.toString(),
        'x-sender-os': me.os,
      };

  /// 检查目标设备是否在线，成功返回其 DeviceInfo
  Future<DeviceInfo?> ping(String ip, int port) async {
    try {
      final res = await _dio.get(
        'http://$ip:$port/ping',
        options: Options(
          sendTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
      );
      if (res.statusCode == 200) {
        return DeviceInfo.fromJson(res.data as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  /// 发送文本
  Future<TransferResult> sendText({
    required DeviceInfo target,
    required DeviceInfo me,
    required String text,
  }) async {
    try {
      final res = await _dio.post(
        'http://${target.address}/receive/text',
        data: jsonEncode({'text': text}),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            ..._senderHeaders(me),
          },
        ),
      );
      return TransferResult(success: res.statusCode == 200);
    } on DioException catch (e) {
      return TransferResult(success: false, error: e.message);
    }
  }

  /// 发送文件
  Future<TransferResult> sendFile({
    required DeviceInfo target,
    required DeviceInfo me,
    required File file,
    ProgressCallback? onProgress,
  }) async {
    try {
      final fileName = file.path.split(Platform.pathSeparator).last;
      final fileSize = await file.length();

      final res = await _dio.post(
        'http://${target.address}/receive/file',
        data: file.openRead(),
        options: Options(
          headers: {
            'Content-Type': 'application/octet-stream',
            'Content-Length': fileSize.toString(),
            'x-file-name': Uri.encodeComponent(fileName),
            'x-file-size': fileSize.toString(),
            ..._senderHeaders(me),
          },
        ),
        onSendProgress: onProgress == null
            ? null
            : (sent, total) {
                if (total > 0) onProgress(sent / total);
              },
      );
      return TransferResult(success: res.statusCode == 200);
    } on DioException catch (e) {
      return TransferResult(success: false, error: e.message);
    }
  }
}
