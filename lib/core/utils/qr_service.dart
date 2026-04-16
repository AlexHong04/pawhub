import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRDialog extends StatelessWidget {
  final String data;
  final String title;

  const QRDialog({
    super.key,
    required this.data,
    required this.title,
  });

  Widget _buildQR(String data, {double size = 220}) {
    return QrImageView(
      data: data,
      version: QrVersions.auto,
      size: size,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            _buildQR(data),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
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

class _QRScannerPageState extends State<QRScannerPage> {
  bool isScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan QR Code")),
      body: MobileScanner(
        onDetect: (capture) {
          if (isScanned) return;

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
    );
  }
}