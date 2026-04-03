import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";

import "dart:convert";
import "dart:typed_data";

import "../services/api_service.dart";

class _PickedPhoto {
  _PickedPhoto({required this.bytes, required this.name});

  final Uint8List bytes;
  final String name;

  String toDataUrl() => "data:image/jpeg;base64,${base64Encode(bytes)}";
}

class NewRequestScreen extends StatefulWidget {
  const NewRequestScreen({super.key});

  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends State<NewRequestScreen> {
  final _description = TextEditingController();
  final List<String> _selected = [];
  final List<_PickedPhoto> _photos = [];
  final ImagePicker _picker = ImagePicker();

  final commonWaste = const [
    "UPS Battery Pack",
    "Inverter Circuit Board",
    "CRT Monitor",
    "Networking Router",
    "Wi-Fi Repeater",
    "Old Modem",
    "Set-Top Box",
    "Electronic Ballast",
    "Defective Power Supply Unit",
    "Damaged PCB Components",
    "Smartwatch Motherboard",
    "Broken Tablet Digitizer",
    "Cartridge Chip Module",
    "CCTV DVR Unit",
    "Hard Disk Enclosure",
    "Laser Printer Drum Unit",
    "Audio Mixer Panel",
    "E-bike Controller",
    "Biometric Scanner",
    "Lab Instrument Board",
    "Switchgear Relay Module",
    "POS Terminal",
    "Barcode Scanner",
    "Bluetooth Speaker Circuit"
  ];

  bool _loading = false;
  String _message = "";

  Future<void> _capturePhoto() async {
    final photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 82);
    if (photo == null) return;

    final bytes = await photo.readAsBytes();
    setState(() {
      _photos.add(_PickedPhoto(bytes: bytes, name: photo.name));
    });
  }

  Future<void> _pickPhotos() async {
    final photos = await _picker.pickMultiImage(imageQuality: 82);
    if (photos.isEmpty) return;

    final selected = <_PickedPhoto>[];
    for (final photo in photos) {
      selected.add(_PickedPhoto(bytes: await photo.readAsBytes(), name: photo.name));
    }

    setState(() => _photos.addAll(selected));
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _message = "";
    });

    try {
      await ApiService.instance.createRequest(
        imageUrls: _photos.map((photo) => photo.toDataUrl()).toList(),
        description: _description.text.trim(),
        categories: _selected,
      );
      if (!mounted) return;
      setState(() {
        _message = "Request submitted successfully.";
        _description.clear();
        _selected.clear();
        _photos.clear();
      });
    } catch (_) {
      setState(() => _message = "Failed to submit request.");
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("New E-Waste Request"),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Capture photos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Text("Take multiple photos with the camera or add more from gallery."),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(onPressed: _capturePhoto, icon: const Icon(Icons.photo_camera), label: const Text("Camera")),
                      FilledButton.tonalIcon(onPressed: _pickPhotos, icon: const Icon(Icons.collections), label: const Text("Gallery")),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_photos.isNotEmpty)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _photos.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemBuilder: (context, index) {
                        final photo = _photos[index];
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.memory(photo.bytes, fit: BoxFit.cover),
                            ),
                            Positioned(
                              right: 4,
                              top: 4,
                              child: CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.black87,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  iconSize: 16,
                                  onPressed: () => _removePhoto(index),
                                  icon: const Icon(Icons.close, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Description", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _description,
                    maxLines: 4,
                    decoration: const InputDecoration(hintText: "Describe the items you want collected"),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("E-waste suggestions (including uncommon items)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: commonWaste
                        .map(
                          (item) => FilterChip(
                            selected: _selected.contains(item),
                            label: Text(item),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selected.add(item);
                                } else {
                                  _selected.remove(item);
                                }
                              });
                            },
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: _loading || _photos.isEmpty ? null : _submit,
            child: _loading ? const CircularProgressIndicator() : const Text("Send to Admin"),
          ),
          if (_message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_message),
          ]
        ],
      ),
    );
  }
}
