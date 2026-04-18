import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:share_plus/share_plus.dart';

class QRDialog extends StatefulWidget {
  final String data;
  final String title;
  final bool showSaveButton;
  final String? shareText;

  const QRDialog({
    super.key,
    required this.data,
    required this.title,
    this.showSaveButton = false,
    this.shareText,
  });

  @override
  State<QRDialog> createState() => _QRDialogState();
}

class _QRDialogState extends State<QRDialog> {
  final GlobalKey _qrKey = GlobalKey();
  bool _isSaving = false; // useful for community share post

  // Captures the widget wrapped by RepaintBoundary and saves it to the device's gallery.
  Future<void> _saveQRToGallery() async {
    setState(() => _isSaving = true);
    try {
      // Find the render object and convert it to a high-quality image
      RenderRepaintBoundary boundary =
          _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      // Convert the image to PNG byte data
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      // Save the image using the "image_gallery_saver_plus"
      final result = await ImageGallerySaverPlus.saveImage(
        pngBytes,
        quality: 100,
        name: "PawHub_QR_${DateTime.now().millisecondsSinceEpoch}",
      );

      if (mounted) {
        if (result['isSuccess']) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("QR Code saved to gallery! 🎉"),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Failed to save QR Code"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Triggers the native share sheet with the provided text
  void _shareLink() {
    if (widget.shareText != null) {
      SharePlus.instance.share(ShareParams(text: widget.shareText!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            // required to take a screenshot of this specific container
            RepaintBoundary(
              key: _qrKey,
              child: Container(
                color: Colors.white,
                // // White background ensures the saved image isn't transparent/black
                padding: const EdgeInsets.all(8.0),
                child: QrImageView(
                  data: widget.data,
                  version: QrVersions.auto,
                  size: 200,
                ),
              ),
            ),

            const SizedBox(height: 20),

            //useful for adoption (only display close button)
            if (!widget.showSaveButton && widget.shareText == null) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close"),
                ),
              ),
            ] else ...[
              // Shows save and share action buttons
              Row(
                children: [
                  if (widget.showSaveButton)
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isSaving ? null : _saveQRToGallery,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.download_rounded,
                                color: Colors.black87,
                                size: 18,
                              ),
                        label: const Text(
                          "Save",
                          style: TextStyle(color: Colors.black87),
                        ),
                      ),
                    ),
                  if (widget.showSaveButton && widget.shareText != null)
                    const SizedBox(width: 12),
                  if (widget.shareText != null)
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _shareLink,
                        icon: const Icon(
                          Icons.share_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: const Text(
                          "Share",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Close",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class QRScannerPage extends StatefulWidget {
  final String id;

  const QRScannerPage({super.key, required this.id});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

// SingleTickerProviderStateMixin --> ensuring smooth frame updates and automatically pausing when off-screen
class _QRScannerPageState extends State<QRScannerPage> with SingleTickerProviderStateMixin {
  bool isScanned = false;

  // Animation controllers for the glowing scanning line
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // Initialize an animation that moves up and down every 2 seconds
    _animationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(
            reverse: true,
          ); // Reverses automatically to create a bouncing effect

    _animation = Tween<double>(begin: 0, end: 1).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scanWindowSize = MediaQuery.of(context).size.width * 0.7;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "Scan QR Code",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          MobileScanner(
            // Defines the active detection area (improves scanning performance)
            scanWindow: Rect.fromCenter(
              center: MediaQuery.of(context).size.center(Offset.zero),
              width: scanWindowSize,
              height: scanWindowSize,
            ),
            onDetect: (capture) {
              if (isScanned) return; // Prevent multiple pops

              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final String? value = barcodes.first.rawValue;

                if (value != null) {
                  isScanned = true;
                  Navigator.pop(context, value);
                }
              }
            },
          ),

          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.6),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Center(
                  child: Container(
                    width: scanWindowSize,
                    height: scanWindowSize,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // The four corner borders of the viewfinder frame
          Center(
            child: Container(
              width: scanWindowSize,
              height: scanWindowSize,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    child: _buildCornerBox(Alignment.topLeft),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: _buildCornerBox(Alignment.topRight),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: _buildCornerBox(Alignment.bottomLeft),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: _buildCornerBox(Alignment.bottomRight),
                  ),
                ],
              ),
            ),
          ),

          //The glowing green scanning line that moves up and down
          Center(
            child: SizedBox(
              width: scanWindowSize,
              height: scanWindowSize,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Stack(
                    children: [
                      Positioned(
                        top: _animation.value * (scanWindowSize - 4),
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.greenAccent,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.greenAccent.withValues(
                                  alpha: 0.5,
                                ),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.15,
            left: 0,
            right: 0,
            child: const Text(
              "Align QR Code within the frame to scan",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to draw the green L-shaped corners for the viewfinder
  Widget _buildCornerBox(Alignment alignment) {
    const double length = 30.0;
    const double strokeWidth = 4.0;
    const Color color = Colors.greenAccent;

    return Container(
      width: length,
      height: length,
      decoration: BoxDecoration(
        border: Border(
          top:
              (alignment == Alignment.topLeft ||
                  alignment == Alignment.topRight)
              ? const BorderSide(color: color, width: strokeWidth)
              : BorderSide.none,
          bottom:
              (alignment == Alignment.bottomLeft ||
                  alignment == Alignment.bottomRight)
              ? const BorderSide(color: color, width: strokeWidth)
              : BorderSide.none,
          left:
              (alignment == Alignment.topLeft ||
                  alignment == Alignment.bottomLeft)
              ? const BorderSide(color: color, width: strokeWidth)
              : BorderSide.none,
          right:
              (alignment == Alignment.topRight ||
                  alignment == Alignment.bottomRight)
              ? const BorderSide(color: color, width: strokeWidth)
              : BorderSide.none,
        ),
      ),
    );
  }
}
