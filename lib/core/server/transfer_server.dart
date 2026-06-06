import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:path_provider/path_provider.dart';
import '../models/device_info.dart';
import '../models/received_item.dart';

typedef OnReceived = void Function(ReceivedItem item);

class TransferServer {
  static const int port = 53317;

  HttpServer? _server;
  OnReceived? _onReceived;

  bool get isRunning => _server != null;

  Future<void> start({
    required DeviceInfo myDevice,
    required OnReceived onReceived,
  }) async {
    if (isRunning) return;
    _onReceived = onReceived;

    final router = Router();

    // 健康检查 / 设备信息
    router.get('/ping', (_) => _jsonResponse(myDevice.toJson()));

    // 接收文本
    router.post('/receive/text', (shelf.Request req) async {
      try {
        final sender = _parseSender(req.headers);
        final body = await req.readAsString();
        final text = (jsonDecode(body) as Map)['text'] as String;

        _onReceived?.call(ReceivedItem(
          id: _id(),
          type: ItemType.text,
          content: text,
          sender: sender,
          receivedAt: DateTime.now(),
        ));

        return _jsonResponse({'success': true});
      } catch (e) {
        return _jsonResponse({'error': e.toString()}, status: 400);
      }
    });

    // 接收文件
    router.post('/receive/file', (shelf.Request req) async {
      try {
        final sender = _parseSender(req.headers);
        final rawName = req.headers['x-file-name'] ?? 'file';
        final fileName = Uri.decodeComponent(rawName);
        final fileSize =
            int.tryParse(req.headers['x-file-size'] ?? '0') ?? 0;

        final savePath = await _resolveSavePath(fileName);
        final file = File(savePath);
        final sink = file.openWrite();
        await req.read().forEach(sink.add);
        await sink.close();

        _onReceived?.call(ReceivedItem(
          id: _id(),
          type: ItemType.file,
          content: savePath,
          fileName: fileName,
          fileSize: fileSize,
          sender: sender,
          receivedAt: DateTime.now(),
        ));

        return _jsonResponse({'success': true});
      } catch (e) {
        return _jsonResponse({'error': e.toString()}, status: 500);
      }
    });

    final handler = const shelf.Pipeline()
        .addMiddleware(_corsMiddleware())
        .addHandler(router);

    _server = await shelf_io.serve(
      handler,
      InternetAddress.anyIPv4,
      port,
    );
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  DeviceInfo _parseSender(Map<String, String> headers) => DeviceInfo(
        id: headers['x-sender-id'] ?? '',
        name: headers['x-sender-name'] ?? 'Unknown',
        ip: headers['x-sender-ip'] ?? '',
        port: int.tryParse(headers['x-sender-port'] ?? '') ?? port,
        os: headers['x-sender-os'] ?? 'unknown',
      );

  shelf.Response _jsonResponse(Map<String, dynamic> body, {int status = 200}) =>
      shelf.Response(
        status,
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'},
      );

  shelf.Middleware _corsMiddleware() => (shelf.Handler inner) {
        return (shelf.Request req) async {
          if (req.method == 'OPTIONS') {
            return shelf.Response.ok('', headers: _corsHeaders);
          }
          final res = await inner(req);
          return res.change(headers: _corsHeaders);
        };
      };

  static const _corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': '*',
  };

  String _id() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<String> _resolveSavePath(String fileName) async {
    final dir = await _saveDir();
    String path = '${dir.path}/$fileName';
    int counter = 1;
    while (File(path).existsSync()) {
      final dot = fileName.lastIndexOf('.');
      final base = dot > 0 ? fileName.substring(0, dot) : fileName;
      final ext = dot > 0 ? fileName.substring(dot) : '';
      path = '${dir.path}/${base}_$counter$ext';
      counter++;
    }
    return path;
  }

  Future<Directory> _saveDir() async {
    Directory? base;
    if (Platform.isAndroid || Platform.isIOS) {
      base = await getApplicationDocumentsDirectory();
    } else {
      base = await getDownloadsDirectory();
    }
    base ??= await getTemporaryDirectory();

    final dir = Directory('${base.path}/LanTransfer');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }
}
