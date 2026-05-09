import "dart:convert";

import "package:flutter/material.dart";
import "package:qr_flutter/qr_flutter.dart";

import "../models/auth_session.dart";
import "../models/request_model.dart";
import "../services/api_service.dart";
import "new_request_screen.dart";

enum StudentView { requests, history, profile }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.session, required this.onLogout});

  final AuthSession session;
  final VoidCallback onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  List<WasteRequest> _requests = [];
  String _error = "";
  StudentView _view = StudentView.requests;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = "";
    });

    try {
      final requests = await ApiService.instance.getMyRequests();
      setState(() => _requests = requests);
    } catch (_) {
      setState(() => _error = "Failed to load requests. Server may be waking up, please refresh once.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generateQr(String requestId) async {
    try {
      final token = await ApiService.instance.getQrToken(requestId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Generated QR", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE3E9E4)),
                    ),
                    child: QrImageView(
                      data: token,
                      size: 240,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Show this QR to the member only after your request is approved.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("Close"),
                  ),
                ],
              ),
            ),
          );
        },
      );
      await _load();
    } catch (_) {
      setState(() => _error = "QR generation failed");
    }
  }

  Future<void> _accept(String requestId) async {
    setState(() => _error = "");
    try {
      await ApiService.instance.acceptQuote(requestId);
      await _load();
    } catch (_) {
      setState(() => _error = "Unable to accept quote for this request.");
    }
  }

  Future<void> _cancel(String requestId) async {
    setState(() => _error = "");
    try {
      await ApiService.instance.cancelRequest(requestId, reason: "Cancelled by student from app");
      await _load();
    } catch (_) {
      setState(() => _error = "Unable to deny/cancel this request.");
    }
  }

  Future<void> _openCounterOfferSheet(WasteRequest request) async {
    final amountController = TextEditingController(text: (request.adminQuote > 0 ? request.adminQuote : request.currentQuote).toStringAsFixed(0));
    final messageController = TextEditingController(text: "Please review my revised quote.");

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Counter Offer", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: "Your revised amount"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: messageController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: "Message to admin"),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text.trim()) ?? 0;
                    if (amount <= 0) {
                      if (!mounted) return;
                      setState(() => _error = "Enter a valid amount for re-quote.");
                      return;
                    }

                    Navigator.of(context).pop();
                    try {
                      await ApiService.instance.counterOffer(
                        requestId: request.id,
                        amount: amount,
                        message: messageController.text.trim(),
                      );
                      await _load();
                    } catch (_) {
                      if (!mounted) return;
                      setState(() => _error = "Unable to submit counter offer.");
                    }
                  },
                  child: const Text("Send Re-Quote"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openImageViewer(List<String> images, int initialIndex) async {
    if (images.isEmpty) return;

    final controller = PageController(initialPage: initialIndex);
    var currentIndex = initialIndex;

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) {
        return Dialog.fullscreen(
          child: Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: StatefulBuilder(
                builder: (context, setState) {
                  controller.addListener(() {
                    final newIndex = controller.page?.round() ?? initialIndex;
                    if (newIndex != currentIndex) {
                      setState(() => currentIndex = newIndex);
                    }
                  });
                  return Text("Image ${currentIndex + 1}/${images.length}");
                },
              ),
            ),
            body: PageView.builder(
              controller: controller,
              itemCount: images.length,
              itemBuilder: (context, index) {
                final imageUrl = images[index];
                final isDataUrl = imageUrl.startsWith("data:");

                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.95,
                      maxHeight: MediaQuery.of(context).size.height * 0.8,
                    ),
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4,
                      child: isDataUrl
                          ? Image.memory(
                              base64Decode(imageUrl.split(",").last),
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white70, size: 56),
                            )
                          : Image.network(
                              imageUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white70, size: 56),
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeRequests = _requests.where((request) => ["SUBMITTED", "QUOTED", "BARGAINING", "AGREED", "QR_ISSUED"].contains(request.status)).toList();
    final historyRequests = _requests.where((request) => ["COLLECTED", "CANCELLED"].contains(request.status)).toList();
    final activeNegotiationCount = _requests.where((request) => ["QUOTED", "BARGAINING"].contains(request.status)).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(_view == StudentView.requests ? "My Requests" : _view == StudentView.history ? "History" : "Profile"),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: widget.onLogout, icon: const Icon(Icons.logout)),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(widget.session.fullName),
                accountEmail: Text(widget.session.email),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text(widget.session.fullName.isNotEmpty ? widget.session.fullName[0].toUpperCase() : "S"),
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.tertiary],
                  ),
                ),
              ),
              _drawerTile(context, icon: Icons.inventory_2_outlined, title: "Requests", index: StudentView.requests),
              _drawerTile(context, icon: Icons.history_toggle_off, title: "History", index: StudentView.history),
              _drawerTile(context, icon: Icons.person_outline, title: "Profile", index: StudentView.profile),
              const Spacer(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text("Logout"),
                onTap: widget.onLogout,
              ),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeroCard(activeRequests.length, activeNegotiationCount, historyRequests.length),
                  const SizedBox(height: 16),
                  if (_error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(_error, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                    ),
                  if (_view == StudentView.requests) ..._buildRequestView(activeRequests),
                  if (_view == StudentView.history) ..._buildHistoryView(historyRequests),
                  if (_view == StudentView.profile) ..._buildProfileView(),
                ],
              ),
      ),
    );
  }

  Widget _buildHeroCard(int activeCount, int negotiationCount, int historyCount) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Campus ${widget.session.campusId}", style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text(
              "Track requests, compare quotes, and complete collection only after QR scan.",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _statPill("Active", activeCount),
                _statPill("Negotiating", negotiationCount),
                _statPill("History", historyCount),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const NewRequestScreen()));
                await _load();
              },
              icon: const Icon(Icons.photo_camera),
              label: const Text("Create New Request"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statPill(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
      child: Text("$label: $value", style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  List<Widget> _buildRequestView(List<WasteRequest> requests) {
    if (requests.isEmpty) {
      return [const Card(child: Padding(padding: EdgeInsets.all(16), child: Text("No active requests. Create one to start.")))];
    }

    return requests.map((request) {
      final adminQuote = request.adminQuote > 0 ? request.adminQuote : request.currentQuote;
      final showNegotiationActions = (request.status == "QUOTED" || request.status == "BARGAINING") && request.quotePendingForUser;
      final showQrButton = request.status == "AGREED" || request.status == "QR_ISSUED";

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(request.description, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                    _statusChip(request.status),
                  ],
                ),
                const SizedBox(height: 8),
                Text("Admin Quote: ${adminQuote.toStringAsFixed(2)}"),
                if (request.adminQuoteMessage.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text("Admin note: ${request.adminQuoteMessage}", style: const TextStyle(color: Colors.black54)),
                  ),
                if ((request.collectorName ?? "").trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "Collector assigned: ${request.collectorName} · ${request.collectorPhone ?? "-"}",
                      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                    ),
                  ),
                if (request.status == "BARGAINING" && !request.quotePendingForUser)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text("Waiting for admin response to your re-quote.", style: TextStyle(color: Colors.black54)),
                  ),
                const SizedBox(height: 8),
                if (request.imageUrls.isNotEmpty)
                  GestureDetector(
                    onTap: () => _openImageViewer(request.imageUrls, 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 140,
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.25,
                        ),
                        color: const Color(0xFFF1F4F2),
                        child: Builder(
                          builder: (context) {
                            final imageUrl = request.imageUrls.first;
                            final isDataUrl = imageUrl.startsWith("data:");
                            
                            return isDataUrl
                                ? Image.memory(
                                    base64Decode(imageUrl.split(",").last),
                                    width: double.infinity,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Container(
                                      height: 180,
                                      alignment: Alignment.center,
                                      color: Colors.black12,
                                      child: const Icon(Icons.image_not_supported_outlined),
                                    ),
                                  )
                                : Image.network(
                                    imageUrl,
                                    width: double.infinity,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Container(
                                      height: 180,
                                      alignment: Alignment.center,
                                      color: Colors.black12,
                                      child: const Icon(Icons.image_not_supported_outlined),
                                    ),
                                  );
                          },
                        ),
                      ),
                    ),
                  ),
                if (request.imageUrls.length > 1) ...[
                  const SizedBox(height: 8),
                  Text("${request.imageUrls.length} photos attached (tap image to open full view)"),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (showNegotiationActions)
                      FilledButton.tonal(
                        onPressed: () => _openCounterOfferSheet(request),
                        child: const Text("Re-Quote"),
                      ),
                    if (showNegotiationActions)
                      FilledButton(
                        onPressed: () => _accept(request.id),
                        child: const Text("Accept"),
                      ),
                    if (["SUBMITTED", "QUOTED", "BARGAINING"].contains(request.status))
                      OutlinedButton(
                        onPressed: () => _cancel(request.id),
                        child: const Text("Deny / Cancel"),
                      ),
                    if (showQrButton)
                      FilledButton.icon(
                        onPressed: () => _generateQr(request.id),
                        icon: const Icon(Icons.qr_code_2),
                        label: const Text("View QR"),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildHistoryView(List<WasteRequest> requests) {
    if (requests.isEmpty) {
      return [const Card(child: Padding(padding: EdgeInsets.all(16), child: Text("No completed history yet.")))];
    }

    return requests.map((request) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(request.description, style: const TextStyle(fontWeight: FontWeight.w700))),
                    _statusChip(request.status),
                  ],
                ),
                const SizedBox(height: 6),
                Text("Status: ${request.status} · Admin Quote: ${(request.adminQuote > 0 ? request.adminQuote : request.currentQuote).toStringAsFixed(2)}"),
                Text("Created: ${request.createdAt.isEmpty ? "-" : request.createdAt.split("T").first}"),
                if (request.status == "COLLECTED")
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text("Agreed Amount: ${request.agreedQuote.toStringAsFixed(2)}"),
                  ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildProfileView() {
    return [
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Student Profile", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              _profileLine("Name", widget.session.fullName),
              _profileLine("Email", widget.session.email),
              _profileLine("Role", widget.session.role),
              _profileLine("Campus", widget.session.campusId),
              const SizedBox(height: 10),
              const Text(
                "Tip: Add clear descriptions and multiple photos to get a faster and more accurate quote.",
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _profileLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final normalized = status.toUpperCase();
    Color bg;
    Color fg;

    if (["QUOTED", "BARGAINING"].contains(normalized)) {
      bg = const Color(0xFFFFE7B2);
      fg = const Color(0xFF9C6200);
    } else if (["AGREED", "QR_ISSUED"].contains(normalized)) {
      bg = const Color(0xFFD8F7E7);
      fg = const Color(0xFF146C43);
    } else if (normalized == "COLLECTED") {
      bg = const Color(0xFFD8F7E7);
      fg = const Color(0xFF146C43);
    } else if (normalized == "CANCELLED") {
      bg = const Color(0xFFFDE2E4);
      fg = const Color(0xFF8F1F26);
    } else {
      bg = const Color(0xFFE7EAED);
      fg = const Color(0xFF44505A);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(normalized, style: TextStyle(fontWeight: FontWeight.w700, color: fg, fontSize: 12)),
    );
  }

  Widget _drawerTile(BuildContext context, {required IconData icon, required String title, required StudentView index}) {
    final selected = _view == index;
    return ListTile(
      leading: Icon(icon, color: selected ? Theme.of(context).colorScheme.primary : null),
      title: Text(title),
      selected: selected,
      onTap: () {
        Navigator.pop(context);
        setState(() => _view = index);
      },
    );
  }
}
