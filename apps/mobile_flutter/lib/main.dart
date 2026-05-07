import "package:flutter_dotenv/flutter_dotenv.dart" as dotenv;
import "package:flutter/material.dart";

import "models/auth_session.dart";
import "models/request_model.dart";
import "services/api_service.dart";
import "screens/home_screen.dart";
import "screens/login_screen.dart";
import "screens/member_scan_screen.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.dotenv.load(fileName: ".env");
  runApp(const EcoCampusApp());
}

class EcoCampusApp extends StatefulWidget {
  const EcoCampusApp({super.key});

  @override
  State<EcoCampusApp> createState() => _EcoCampusAppState();
}

class _EcoCampusAppState extends State<EcoCampusApp> {
  AuthSession? _session;
  bool _isLoadingSession = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    await Future.delayed(const Duration(milliseconds: 400));
    final token = await ApiService.instance.getToken();
    if (mounted) {
      setState(() => _isLoadingSession = false);
    }
  }

  Future<void> _logout() async {
    await ApiService.instance.clearToken();
    setState(() => _session = null);
  }

  @override
  Widget build(BuildContext context) {
    // Show splash while checking for saved session
    if (_isLoadingSession) {
      return MaterialApp(
        home: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF081A1F), Color(0xFF0B5D5F)],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.recycling, size: 60, color: Color(0xFFF4A259)),
                  const SizedBox(height: 20),
                  const Text("Eco Campus", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 30),
                  const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFFF4A259))),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B5D5F), brightness: Brightness.light),
      useMaterial3: true,
    );

    return MaterialApp(
      title: "Eco Campus",
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        scaffoldBackgroundColor: const Color(0xFFF5F7F3),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Color(0xFFF5F7F3),
          foregroundColor: Color(0xFF0F2528),
          titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF0F2528)),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF7F9F7),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFDDE5DF))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFDDE5DF))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF0B5D5F), width: 1.4)),
        ),
      ),
      home: _session == null
          ? LoginScreen(
              onLoggedIn: (session) => setState(() => _session = session),
            )
          : _session!.role == "MEMBER"
              ? MemberDashboardShell(session: _session!, onLogout: _logout)
              : HomeScreen(session: _session!, onLogout: _logout),
    );
  }
}

class MemberDashboardShell extends StatefulWidget {
  const MemberDashboardShell({super.key, required this.session, required this.onLogout});

  final AuthSession session;
  final VoidCallback onLogout;

  @override
  State<MemberDashboardShell> createState() => _MemberDashboardShellState();
}

class _MemberDashboardShellState extends State<MemberDashboardShell> {
  int _index = 0;
  final GlobalKey<_MemberAssignedRequestsScreenState> _assignedKey = GlobalKey<_MemberAssignedRequestsScreenState>();
  final GlobalKey<_MemberHistoryScreenState> _historyKey = GlobalKey<_MemberHistoryScreenState>();

  @override
  Widget build(BuildContext context) {
    final views = [
      const MemberScanScreen(),
      MemberAssignedRequestsScreen(key: _assignedKey),
      MemberHistoryScreen(key: _historyKey, session: widget.session),
      MemberProfileScreen(session: widget.session),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Member Dashboard"),
        actions: [
          IconButton(
            onPressed: () {
              if (_index == 1) {
                _assignedKey.currentState?._load();
              } else if (_index == 2) {
                _historyKey.currentState?._load();
              } else {
                setState(() {});
              }
            },
            icon: const Icon(Icons.refresh),
          ),
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
                  child: Text(widget.session.fullName.isNotEmpty ? widget.session.fullName[0].toUpperCase() : "M"),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.qr_code_scanner),
                title: const Text("Scanner"),
                selected: _index == 0,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _index = 0);
                },
              ),
              ListTile(
                leading: const Icon(Icons.assignment_outlined),
                title: const Text("Assigned Pickups"),
                selected: _index == 1,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _index = 1);
                },
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text("History"),
                selected: _index == 2,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _index = 2);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text("Profile"),
                selected: _index == 3,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _index = 3);
                },
              ),
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
      body: views[_index],
    );
  }
}

class MemberAssignedRequestsScreen extends StatefulWidget {
  const MemberAssignedRequestsScreen({super.key});

  @override
  State<MemberAssignedRequestsScreen> createState() => _MemberAssignedRequestsScreenState();
}

class _MemberAssignedRequestsScreenState extends State<MemberAssignedRequestsScreen> {
  bool _loading = true;
  String _error = "";
  List<WasteRequest> _requests = [];

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
      final requests = await ApiService.instance.getMemberAssignedRequests();
      setState(() => _requests = requests);
    } catch (_) {
      setState(() => _error = "Failed to load assigned pickups");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      "Students waiting for pickup (QR issued)",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (_error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_error, style: const TextStyle(color: Colors.red)),
                  ),
                if (_requests.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text("No assigned pickups right now."),
                    ),
                  ),
                ..._requests.map(
                  (request) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                      title: Text(request.studentName ?? "Student"),
                      subtitle: Text("Phone: ${request.studentPhone ?? "-"}"),
                      trailing: const Icon(Icons.chevron_right),
                      isThreeLine: false,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class MemberHistoryScreen extends StatefulWidget {
  const MemberHistoryScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<MemberHistoryScreen> createState() => _MemberHistoryScreenState();
}

class _MemberHistoryScreenState extends State<MemberHistoryScreen> {
  bool _loading = true;
  String _error = "";
  List<WasteRequest> _requests = [];

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
      final requests = await ApiService.instance.getMemberHistory();
      setState(() => _requests = requests);
    } catch (_) {
      setState(() => _error = "Failed to load collection history");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.session.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(widget.session.email),
                        Text("Campus: ${widget.session.campusId}"),
                        const SizedBox(height: 8),
                        Text("Collected requests: ${_requests.length}"),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_error.isNotEmpty) Text(_error, style: const TextStyle(color: Colors.red)),
                ..._requests.map(
                  (request) => Card(
                    child: ListTile(
                      title: Text(request.description),
                      subtitle: Text(
                        "Student: ${request.studentName ?? "Unknown"}\nAmount: ${request.agreedQuote.toStringAsFixed(2)} | Collected: ${request.collectedAt ?? "-"}",
                      ),
                      isThreeLine: true,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class MemberProfileScreen extends StatelessWidget {
  const MemberProfileScreen({super.key, required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Member Profile", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Text("Name: ${session.fullName}"),
                Text("Email: ${session.email}"),
                Text("Role: ${session.role}"),
                Text("Campus: ${session.campusId}"),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
