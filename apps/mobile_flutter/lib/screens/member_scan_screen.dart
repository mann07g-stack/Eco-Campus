import "package:flutter/material.dart";
import "package:mobile_scanner/mobile_scanner.dart";

import "../services/api_service.dart";

class MemberScanScreen extends StatefulWidget {
  const MemberScanScreen({super.key});

  @override
  State<MemberScanScreen> createState() => _MemberScanScreenState();
}

class _MemberScanScreenState extends State<MemberScanScreen> {
  final _manual = TextEditingController();
  bool _processing = false;
  String _message = "";
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  @override
  void dispose() {
    _manual.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleToken(String token) async {
    if (_processing) return;

    setState(() {
      _processing = true;
      _message = "Verifying collection...";
    });

    try {
      await ApiService.instance.memberScanQr(token);
      setState(() => _message = "Collection confirmed successfully.");
    } catch (_) {
      setState(() => _message = "Invalid or expired QR.");
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Member QR Scan")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Scan the student QR code", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 300,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: MobileScanner(
                        controller: _controller,
                        onDetect: (capture) {
                          if (capture.barcodes.isEmpty) {
                            return;
                          }

                          final token = capture.barcodes.first.rawValue;
                          if (token != null && token.isNotEmpty) {
                            _handleToken(token);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _processing ? "Scanning..." : "Point the camera at the student's QR code.",
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Manual verification", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  TextField(controller: _manual, decoration: const InputDecoration(hintText: "Paste QR token")),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _processing ? null : () => _handleToken(_manual.text.trim()),
                    child: const Text("Verify and Collect"),
                  ),
                ],
              ),
            ),
          ),
          if (_message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_message),
          ]
        ],
      ),
    );
  }
}
