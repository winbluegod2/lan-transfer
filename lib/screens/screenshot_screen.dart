import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

/// Full-screen screenshot crop overlay.
/// Displays [imagePath] and lets the user drag to select a region.
/// Pops with the cropped [File] on confirm, or null on cancel/ESC.
class ScreenshotCropScreen extends StatefulWidget {
  final String imagePath;
  const ScreenshotCropScreen({super.key, required this.imagePath});

  @override
  State<ScreenshotCropScreen> createState() => _ScreenshotCropScreenState();
}

class _ScreenshotCropScreenState extends State<ScreenshotCropScreen> {
  Offset? _start;
  Offset? _current;
  bool _dragging = false;
  bool _confirming = false;

  Rect? get _selection {
    if (_start == null || _current == null) return null;
    return Rect.fromPoints(_start!, _current!);
  }

  @override
  Widget build(BuildContext context) {
    final sel = _selection;
    final size = MediaQuery.of(context).size;

    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.pop(context);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ── Background: the captured screenshot ──────────────────────────
            Positioned.fill(
              child: Image.file(
                File(widget.imagePath),
                fit: BoxFit.fill, // stretch to fill → proportional crop math
              ),
            ),

            // ── Selection overlay ─────────────────────────────────────────────
            Positioned.fill(
              child: GestureDetector(
                onPanStart: (d) => setState(() {
                  _start = d.localPosition;
                  _current = d.localPosition;
                  _dragging = true;
                }),
                onPanUpdate: (d) => setState(() => _current = d.localPosition),
                onPanEnd: (_) => setState(() => _dragging = false),
                child: CustomPaint(
                  painter: _SelectionPainter(selection: sel),
                ),
              ),
            ),

            // ── Hint ──────────────────────────────────────────────────────────
            if (sel == null)
              const Center(
                child: Text(
                  '拖动鼠标选择区域   ESC 取消',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                  ),
                ),
              ),

            // ── Confirm / Cancel toolbar ──────────────────────────────────────
            if (sel != null && !_dragging)
              Positioned(
                left: _toolbarLeft(sel, size),
                top: _toolbarTop(sel, size),
                child: Material(
                  color: Colors.transparent,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ToolbarButton(
                        icon: Icons.close,
                        color: Colors.grey.shade700,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      _ToolbarButton(
                        icon: Icons.check,
                        color: Colors.green.shade700,
                        loading: _confirming,
                        onTap: _confirm,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  double _toolbarLeft(Rect sel, Size size) {
    final ideal = sel.right - 88;
    return ideal.clamp(8.0, size.width - 96);
  }

  double _toolbarTop(Rect sel, Size size) {
    const toolbarH = 44.0;
    final belowY = sel.bottom + 6;
    if (belowY + toolbarH < size.height) return belowY;
    return (sel.top - toolbarH - 6).clamp(8.0, size.height - toolbarH);
  }

  Future<void> _confirm() async {
    final sel = _selection;
    if (sel == null || _confirming) return;
    setState(() => _confirming = true);

    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final source = img.decodeImage(bytes);
      if (source == null) return;

      final size = MediaQuery.of(context).size;
      // Map selection (logical window pixels) → image physical pixels
      final scaleX = source.width / size.width;
      final scaleY = source.height / size.height;

      final x = (sel.left * scaleX).round().clamp(0, source.width - 1);
      final y = (sel.top * scaleY).round().clamp(0, source.height - 1);
      final w = (sel.width * scaleX).round().clamp(1, source.width - x);
      final h = (sel.height * scaleY).round().clamp(1, source.height - y);

      final cropped = img.copyCrop(source, x: x, y: y, width: w, height: h);
      final outBytes = img.encodePng(cropped);

      final outPath =
          '${Directory.systemTemp.path}${Platform.pathSeparator}lan_crop_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(outPath).writeAsBytes(outBytes);

      if (mounted) Navigator.pop(context, File(outPath));
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }
}

// ── Custom painter for the selection overlay ──────────────────────────────────

class _SelectionPainter extends CustomPainter {
  final Rect? selection;
  _SelectionPainter({this.selection});

  @override
  void paint(Canvas canvas, Size size) {
    final dimPaint = Paint()..color = Colors.black54;
    final sel = selection;

    if (sel == null) {
      canvas.drawRect(Offset.zero & size, dimPaint);
      return;
    }

    // Dim everything outside the selection
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRect(sel)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, dimPaint);

    // Selection border
    canvas.drawRect(
      sel,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Corner handles
    final handle = Paint()..color = Colors.white;
    const s = 6.0;
    for (final c in [sel.topLeft, sel.topRight, sel.bottomLeft, sel.bottomRight]) {
      canvas.drawRect(Rect.fromCenter(center: c, width: s, height: s), handle);
    }
  }

  @override
  bool shouldRepaint(_SelectionPainter old) => old.selection != selection;
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool loading;
  const _ToolbarButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: loading
            ? const Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
