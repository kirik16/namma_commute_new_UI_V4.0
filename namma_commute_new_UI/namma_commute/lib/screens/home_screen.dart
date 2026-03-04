import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onNavigate;
  const HomeScreen({super.key, this.onNavigate});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  Timer? _timer;
  bool _loading = true;
  bool _hasError = false;
  String _errorMsg = '';
  Map<String, dynamic> _cityIndex = {};
  List<dynamic> _hotspots = [];
  Map<String, dynamic> _weather = {};
  int _syncCycles = 0;
  DateTime? _lastUpdated;

  final _quickActions = [
    {'icon': Icons.sensors_rounded,         'label': 'Live Traffic',  'color': Color(0xFFFF6B35), 'sub': 'Real-time updates', 'tab': 1},
    {'icon': Icons.train_rounded,           'label': 'Namma Metro',   'color': Color(0xFF7C6FFF), 'sub': 'Next trains & fare', 'tab': 2},
    {'icon': Icons.campaign_rounded,        'label': 'Report Issue',  'color': Color(0xFF00E5CC), 'sub': 'Help your city',    'tab': 3},
    {'icon': Icons.emergency_share_rounded, 'label': 'SOS Emergency', 'color': Color(0xFFFF3B5C), 'sub': 'Quick dial 108',   'tab': 4},
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic);
    _fetchData();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchData());
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final d = await ApiService.getLiveDashboard();
      if (!mounted) return;
      setState(() {
        _cityIndex = (d['traffic']?['city_index'] as Map<String, dynamic>?) ?? {};
        _hotspots = (d['traffic']?['junctions'] as List<dynamic>?) ?? [];
        _weather = (d['weather']?['current'] as Map<String, dynamic>?) ?? {};
        _syncCycles = d['sync']?['cycle_count'] as int? ?? 0;
        _lastUpdated = DateTime.now();
        _loading = false;
        _hasError = false;
      });
      _fadeCtrl.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() { _hasError = true; _errorMsg = e.toString().replaceAll('Exception: ', ''); _loading = false; });
    }
  }

  Color _sevColor(String? s) {
    switch (s) {
      case 'critical': return const Color(0xFFFF3B5C);
      case 'high':     return const Color(0xFFFF9500);
      case 'moderate': return const Color(0xFFFFD60A);
      default:         return const Color(0xFF30D158);
    }
  }

  String _timeAgo() {
    if (_lastUpdated == null) return '';
    final s = DateTime.now().difference(_lastUpdated!).inSeconds;
    return s < 60 ? '${s}s ago' : '${s ~/ 60}m ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08080F),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        color: const Color(0xFFFF6B35),
        backgroundColor: const Color(0xFF1A1A2E),
        child: CustomScrollView(slivers: [
          _buildHeader(),
          if (_loading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35))))
          else if (_hasError)
            SliverFillRemaining(child: _buildError())
          else
            SliverFadeTransition(
              opacity: _fadeAnim,
              sliver: SliverList(delegate: SliverChildListDelegate([
                _buildScoreCard(),
                _buildQuickActions(),
                _buildHotspotsSection(),
                _buildWeatherCard(),
                const SizedBox(height: 100),
              ])),
            ),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    final score = _cityIndex['index'] as int? ?? 0;
    final label = _cityIndex['label'] as String? ?? '';
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: const Color(0xFF08080F),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF1A0E00), Color(0xFF08080F)]),
          ),
          child: Stack(children: [
            // Decorative orb
            Positioned(right: -40, top: -40,
              child: Container(width: 200, height: 200,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [const Color(0xFFFF6B35).withOpacity(0.15), Colors.transparent])),
              ),
            ),
            SafeArea(child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  // Live badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B5C).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFF3B5C).withOpacity(0.4), width: 0.5),
                    ),
                    child: Row(children: [
                      AnimatedBuilder(animation: _pulseCtrl,
                        builder: (ctx, _) => Container(width: 6, height: 6,
                          decoration: BoxDecoration(shape: BoxShape.circle,
                            color: Color.lerp(const Color(0xFFFF3B5C), const Color(0xFFFF8FA3), _pulseCtrl.value))),
                      ),
                      const SizedBox(width: 5),
                      Text('LIVE', style: GoogleFonts.spaceGrotesk(color: const Color(0xFFFF3B5C), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                    ]),
                  ),
                  const Spacer(),
                  if (_weather['temp'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(20)),
                      child: Text('${(_weather['temp'] as num).toStringAsFixed(0)}°C  ${_weather['main'] ?? ''}',
                          style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    ),
                ]),
                const SizedBox(height: 14),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Namma', style: GoogleFonts.spaceGrotesk(color: Colors.white38, fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 2)),
                    Text('Commute', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, height: 1.1)),
                  ]),
                  const Spacer(),
                  if (label.isNotEmpty) Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('$score', style: GoogleFonts.spaceGrotesk(color: const Color(0xFFFF6B35), fontSize: 32, fontWeight: FontWeight.w900)),
                    Text('city score · ${_timeAgo()}', style: const TextStyle(color: Colors.white30, fontSize: 10)),
                  ]),
                ]),
              ]),
            )),
          ]),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 80, height: 80,
          decoration: BoxDecoration(color: const Color(0xFFFF3B5C).withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.wifi_off_rounded, color: Color(0xFFFF3B5C), size: 36)),
        const SizedBox(height: 20),
        Text('Server Unreachable', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(_errorMsg, style: const TextStyle(color: Colors.white38, fontSize: 12), textAlign: TextAlign.center),
        const SizedBox(height: 28),
        GestureDetector(
          onTap: () { setState(() { _loading = true; _hasError = false; }); _fetchData(); },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF8C5A)]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: const Color(0xFFFF6B35).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Text('Try Again', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    ));
  }

  Widget _buildScoreCard() {
    final score = _cityIndex['index'] as int? ?? 50;
    final label = _cityIndex['label'] as String? ?? 'Loading';
    final critical = _cityIndex['critical_count'] as int? ?? 0;
    final scoreColor = score > 65 ? const Color(0xFF30D158) : score > 45 ? const Color(0xFFFFD60A) : const Color(0xFFFF3B5C);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [const Color(0xFF1A1A2E), const Color(0xFF12121E)]),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.07), width: 0.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 30, offset: const Offset(0, 10))],
        ),
        child: Row(children: [
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (ctx, child) => Transform.scale(scale: 0.95 + 0.05 * _pulseCtrl.value, child: child),
            child: SizedBox(width: 100, height: 100,
              child: CustomPaint(painter: _ArcPainter(score / 100, scoreColor),
                child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('$score', style: TextStyle(color: scoreColor, fontSize: 28, fontWeight: FontWeight.w900)),
                  Text('/100', style: const TextStyle(color: Colors.white30, fontSize: 10)),
                ])),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: scoreColor, shape: BoxShape.circle)),
              const SizedBox(width: 7),
              Text(label, style: TextStyle(color: scoreColor, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
            ]),
            const SizedBox(height: 8),
            Text('City Traffic Index', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(critical > 0 ? '⚠️  $critical critical incident${critical > 1 ? "s" : ""} active' : '✅  All clear across the city',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 4),
            Text('Sync #$_syncCycles · auto-refresh 30s', style: const TextStyle(color: Colors.white24, fontSize: 10)),
          ])),
        ]),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Quick Access', style: GoogleFonts.spaceGrotesk(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.9,
          children: _quickActions.map((a) {
            final color = a['color'] as Color;
            return GestureDetector(
              onTap: () => widget.onNavigate?.call(a['tab'] as int),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF12121E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.2), width: 0.5),
                ),
                child: Row(children: [
                  Container(width: 38, height: 38,
                    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                    child: Icon(a['icon'] as IconData, color: color, size: 20)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(a['label'] as String, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(a['sub'] as String, style: TextStyle(color: Colors.white38, fontSize: 9), maxLines: 1),
                  ])),
                ]),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }

  Widget _buildHotspotsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('HOTSPOTS', style: GoogleFonts.spaceGrotesk(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
          const Spacer(),
          GestureDetector(
            onTap: () => widget.onNavigate?.call(1),
            child: Text('View all →', style: TextStyle(color: const Color(0xFFFF6B35), fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 12),
        ..._hotspots.take(5).toList().asMap().entries.map((e) => _buildHotspotRow(e.value as Map<String, dynamic>, e.key)),
      ]),
    );
  }

  Widget _buildHotspotRow(Map<String, dynamic> h, int idx) {
    final sev = h['severity'] as String? ?? 'low';
    final color = _sevColor(sev);
    final delay = h['delay_min'] as int? ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF12121E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 0.5),
      ),
      child: Row(children: [
        Container(width: 28, height: 28,
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
          child: Center(child: Text('${idx + 1}', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(h['junction'] as String? ?? '', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(h['message'] as String? ?? sev, style: const TextStyle(color: Colors.white38, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('+$delay min', style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900)),
          Text('delay', style: const TextStyle(color: Colors.white30, fontSize: 9)),
        ]),
      ]),
    );
  }

  Widget _buildWeatherCard() {
    final main = _weather['main'] as String? ?? 'Clear';
    final temp = (_weather['temp'] as num?)?.toStringAsFixed(0) ?? '28';
    final desc = _weather['description'] as String? ?? 'clear sky';
    final humidity = _weather['humidity'] as int? ?? 65;
    final rain = (_weather['rain_1h'] as num? ?? 0) > 0;
    final icon = main.toLowerCase().contains('rain') ? '🌧️' : main.toLowerCase().contains('cloud') ? '⛅' : main.toLowerCase().contains('thunder') ? '⛈️' : '☀️';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [const Color(0xFF0D1A2A), const Color(0xFF12121E)]),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF7C6FFF).withOpacity(0.2), width: 0.5),
        ),
        child: Row(children: [
          Text(icon, style: const TextStyle(fontSize: 40)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('$temp°C', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(width: 10),
              Text('${desc[0].toUpperCase()}${desc.substring(1)}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ]),
            const SizedBox(height: 4),
            Text('Humidity $humidity% · ${rain ? "🚦 Expect delays due to rain" : "Roads clear of rain impact"}',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ])),
        ]),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  _ArcPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    final bgPaint = Paint()..color = Colors.white.withOpacity(0.06)..strokeWidth = 7..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);
    final fgPaint = Paint()
      ..shader = SweepGradient(startAngle: -pi / 2, endAngle: -pi / 2 + 2 * pi * progress,
          colors: [color.withOpacity(0.6), color]).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = 7..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -pi / 2, 2 * pi * progress, false, fgPaint);
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.progress != progress;
}
