import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';
import 'screens/live_traffic_screen.dart';
import 'screens/namma_metro_screen.dart';
import 'screens/sos_screen.dart';
import 'screens/report_screen.dart';
import 'screens/about_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF08080F),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const NammaCommuteApp());
}

class NammaCommuteApp extends StatelessWidget {
  const NammaCommuteApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Namma Commute',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6B35),
          brightness: Brightness.dark,
          primary: const Color(0xFFFF6B35),
          secondary: const Color(0xFF00E5CC),
          surface: const Color(0xFF12121E),
        ),
        scaffoldBackgroundColor: const Color(0xFF08080F),
        textTheme: GoogleFonts.spaceGroteskTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _navAnimController;

  void _navigateTo(int index) {
    if (_currentIndex == index) return;
    _navAnimController.forward(from: 0);
    setState(() => _currentIndex = index);
  }

  @override
  void initState() {
    super.initState();
    _navAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void dispose() {
    _navAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onNavigate: _navigateTo),
      const LiveTrafficScreen(),
      const NammaMetroScreen(),
      const ReportScreen(),
      const SOSScreen(),
      const AboutScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF08080F),
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      {'icon': Icons.home_rounded,             'label': 'Home',    'color': const Color(0xFFFF6B35)},
      {'icon': Icons.sensors_rounded,          'label': 'Traffic', 'color': const Color(0xFFFF6B35)},
      {'icon': Icons.train_rounded,            'label': 'Metro',   'color': const Color(0xFF7C6FFF)},
      {'icon': Icons.campaign_rounded,         'label': 'Report',  'color': const Color(0xFF00E5CC)},
      {'icon': Icons.emergency_share_rounded,  'label': 'SOS',     'color': const Color(0xFFFF3B5C)},
      {'icon': Icons.diversity_3_rounded,      'label': 'About',   'color': const Color(0xFF7C6FFF)},
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E1C),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06), width: 0.5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 30, offset: const Offset(0, -10)),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final item = items[i];
              final isActive = _currentIndex == i;
              final color = item['color'] as Color;
              return GestureDetector(
                onTap: () => _navigateTo(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.symmetric(horizontal: isActive ? 14 : 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive ? color.withOpacity(0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: isActive ? Border.all(color: color.withOpacity(0.3), width: 0.5) : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item['icon'] as IconData,
                          color: isActive ? color : Colors.white24,
                          size: 22),
                      if (isActive) ...[
                        const SizedBox(width: 6),
                        Text(item['label'] as String,
                            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
