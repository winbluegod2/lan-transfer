import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../core/models/device_info.dart';
import '../providers/app_provider.dart';

/// 仅 iOS / Android 使用
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _processing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('扫描二维码'),
        actions: [
          IconButton(
            onPressed: _controller.toggleTorch,
            icon: const Icon(Icons.flashlight_on_outlined),
            tooltip: '手电筒',
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // 扫描框遮罩
          _ScanOverlay(),
          // 提示文字
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _processing ? '正在连接...' : '将二维码对准框内',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          if (_processing)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
        ],
      ),
    );
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null) return;

    final device = DeviceInfo.fromQrData(code);
    if (device == null) {
      _showError('无效的二维码');
      return;
    }

    setState(() => _processing = true);
    await _controller.stop();

    final provider = context.read<AppProvider>();
    final resolved = await provider.connectTo(device.ip, device.port);

    if (!mounted) return;

    if (resolved != null) {
      Navigator.pop(context, resolved);
    } else {
      setState(() => _processing = false);
      _showError('无法连接到 ${device.ip}:${device.port}，请确认设备在线');
      await _controller.start();
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Theme.of(context).colorScheme.error,
      behavior: SnackBarBehavior.floating,
    ));
  }
}

class _ScanOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OverlayPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const boxSize = 240.0;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: boxSize,
      height: boxSize,
    );

    final paint = Paint()..color = Colors.black54;

    // 四周遮罩
    canvas
      ..drawRect(Rect.fromLTRB(0, 0, size.width, rect.top), paint)
      ..drawRect(
          Rect.fromLTRB(0, rect.top, rect.left, rect.bottom), paint)
      ..drawRect(
          Rect.fromLTRB(rect.right, rect.top, size.width, rect.bottom), paint)
      ..drawRect(
          Rect.fromLTRB(0, rect.bottom, size.width, size.height), paint);

    // 扫描框边角
    const cornerLen = 24.0;
    const cornerWidth = 3.0;
    final cp = Paint()
      ..color = Colors.white
      ..strokeWidth = cornerWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final corners = [
      // 左上
      [rect.topLeft, Offset(rect.left + cornerLen, rect.top),
          Offset(rect.left, rect.top + cornerLen)],
      // 右上
      [rect.topRight, Offset(rect.right - cornerLen, rect.top),
          Offset(rect.right, rect.top + cornerLen)],
      // 左下
      [rect.bottomLeft, Offset(rect.left + cornerLen, rect.bottom),
          Offset(rect.left, rect.bottom - cornerLen)],
      // 右下
      [rect.bottomRight, Offset(rect.right - cornerLen, rect.bottom),
          Offset(rect.right, rect.bottom - cornerLen)],
    ];

    for (final c in corners) {
      canvas
        ..drawLine(c[0], c[1], cp)
        ..drawLine(c[0], c[2], cp);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
