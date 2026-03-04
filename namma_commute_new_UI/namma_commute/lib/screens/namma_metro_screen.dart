import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class NammaMetroScreen extends StatefulWidget {
  const NammaMetroScreen({super.key});
  @override
  State<NammaMetroScreen> createState() => _NammaMetroScreenState();
}

class _NammaMetroScreenState extends State<NammaMetroScreen> with TickerProviderStateMixin {
  int _selectedLine = 0;
  bool _loading = true;
  List<dynamic> _lines = [];
  List<dynamic> _stations = [];
  List<dynamic> _schedule = [];
  List<dynamic> _aiStatus = [];
  Timer? _refreshTimer;
  late AnimationController _trainCtrl;
  late AnimationController _pulseCtrl;
  String? _fareFrom, _fareTo;
  Map<String, dynamic>? _fareResult;

  @override
  void initState() {
    super.initState();
    _trainCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _fetchAll();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchSchedule());
  }

  @override
  void dispose() {
    _trainCtrl.dispose();
    _pulseCtrl.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    try {
      final results = await Future.wait([ApiService.getMetroLines(), ApiService.getMetroAiStatus()]);
      if (!mounted) return;
      setState(() { _lines = results[0] as List<dynamic>; _aiStatus = results[1] as List<dynamic>; _loading = false; });
      if (_lines.isNotEmpty) _fetchStationsAndSchedule();
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _fetchStationsAndSchedule() async {
    if (_lines.isEmpty) return;
    try {
      final lineId = _lines[_selectedLine]['id'] as int;
      final r = await Future.wait([ApiService.getMetroStations(lineId), ApiService.getMetroSchedule(lineId)]);
      if (!mounted) return;
      setState(() { _stations = r[0] as List<dynamic>; _schedule = r[1] as List<dynamic>; });
    } catch (_) {}
  }

  Future<void> _fetchSchedule() async {
    if (_lines.isEmpty) return;
    try {
      final lineId = _lines[_selectedLine]['id'] as int;
      final s = await ApiService.getMetroSchedule(lineId);
      if (!mounted) return;
      setState(() => _schedule = s);
    } catch (_) {}
  }

  Future<void> _calcFare() async {
    if (_fareFrom == null || _fareTo == null || _lines.isEmpty) return;
    try {
      final lineId = _lines[_selectedLine]['id'] as int;
      final r = await ApiService.getMetroFare(lineId, _fareFrom!, _fareTo!);
      if (!mounted) return;
      setState(() => _fareResult = r);
    } catch (_) {}
  }

  Color _lineColor() {
    if (_lines.isEmpty) return const Color(0xFF7C6FFF);
    final c = _lines[_selectedLine]['color'] as String? ?? '#7C6FFF';
    try { return Color(int.parse(c.replaceFirst('#', '0xFF'))); } catch (_) { return const Color(0xFF7C6FFF); }
  }

  Map<String, dynamic>? get _aiLine {
    if (_aiStatus.isEmpty || _lines.isEmpty) return null;
    final id = _lines[_selectedLine]['id'];
    for (final l in _aiStatus) { if (l['line_id'] == id) return l as Map<String, dynamic>; }
    return _aiStatus.isNotEmpty ? _aiStatus[0] as Map<String, dynamic> : null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: Color(0xFF08080F),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF7C6FFF))));
    final lc = _lineColor();
    return Scaffold(
      backgroundColor: const Color(0xFF08080F),
      body: Column(children: [
        _buildHeader(lc),
        _buildAnimatedTrain(lc),
        _buildLineSelector(lc),
        _buildAiStatus(lc),
        Expanded(child: DefaultTabController(length: 3, child: Column(children: [
          _buildTabBar(lc),
          Expanded(child: TabBarView(children: [_buildScheduleTab(lc), _buildStationsTab(lc), _buildFareTab(lc)])),
        ]))),
      ]),
    );
  }

  Widget _buildHeader(Color lc) {
    final line = _lines.isNotEmpty ? _lines[_selectedLine] : {};
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [lc.withOpacity(0.25), const Color(0xFF0E0E1C)]),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06), width: 0.5)),
      ),
      child: SafeArea(bottom: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Namma Metro', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (line.isNotEmpty) Row(children: [
            _metroStat('${line['total_stations'] ?? '-'}', 'Stations', lc),
            const SizedBox(width: 10),
            _metroStat('${(line['distance_km'] as num?)?.toStringAsFixed(0) ?? '-'}km', 'Distance', lc),
            const SizedBox(width: 10),
            _metroStat('${line['frequency_min'] ?? '-'} min', 'Frequency', lc),
            const SizedBox(width: 10),
            _metroStat(line['operating_hours'] as String? ?? '5:30-23:00', 'Hours', lc),
          ]),
        ]),
      )),
    );
  }

  Widget _metroStat(String val, String label, Color color) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2), width: 0.5)),
    child: Column(children: [
      Text(val, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
      Text(label, style: const TextStyle(color: Colors.white30, fontSize: 8)),
    ]),
  ));

  // ── ANIMATED METRO TRAIN ──────────────────────────────────────────────────
  Widget _buildAnimatedTrain(Color lc) {
    return SizedBox(height: 70,
      child: AnimatedBuilder(animation: _trainCtrl, builder: (ctx, _) =>
        CustomPaint(painter: _MetroTrainPainter(_trainCtrl.value, lc),
          size: const Size(double.infinity, 70)),
      ),
    );
  }

  Widget _buildLineSelector(Color lc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: List.generate(_lines.length, (i) {
        final l = _lines[i];
        final sel = _selectedLine == i;
        final c = () { try { return Color(int.parse((l['color'] as String).replaceFirst('#', '0xFF'))); } catch (_) { return lc; } }();
        return Expanded(child: GestureDetector(
          onTap: () { setState(() { _selectedLine = i; _stations = []; _schedule = []; _fareResult = null; }); _fetchStationsAndSchedule(); },
          child: AnimatedContainer(duration: const Duration(milliseconds: 200),
            margin: EdgeInsets.only(right: i < _lines.length - 1 ? 10 : 0),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: sel ? c.withOpacity(0.15) : Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: sel ? c : Colors.white.withOpacity(0.08), width: sel ? 1 : 0.5),
            ),
            child: Text(l['name'] as String? ?? 'Line', textAlign: TextAlign.center,
                style: TextStyle(color: sel ? c : Colors.white38, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ));
      })),
    );
  }

  Widget _buildAiStatus(Color lc) {
    final ai = _aiLine;
    if (ai == null) return const SizedBox.shrink();
    final status = ai['status'] as String? ?? 'on_time';
    final delay = ai['delay_min'] as int? ?? 0;
    final reasons = (ai['reasons'] as List<dynamic>?) ?? [];
    final sc = status == 'on_time' ? const Color(0xFF30D158) : const Color(0xFFFFD60A);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: sc.withOpacity(0.08), borderRadius: BorderRadius.circular(14),
            border: Border.all(color: sc.withOpacity(0.25), width: 0.5)),
        child: Row(children: [
          AnimatedBuilder(animation: _pulseCtrl, builder: (ctx, _) =>
            Icon(status == 'on_time' ? Icons.check_circle_rounded : Icons.warning_rounded,
                color: Color.lerp(sc, sc.withOpacity(0.5), _pulseCtrl.value), size: 20)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(status == 'on_time' ? 'Services Running Normally' : 'Delay: +$delay min',
                style: TextStyle(color: sc, fontWeight: FontWeight.w700, fontSize: 12)),
            if (reasons.isNotEmpty) Text(reasons[0] as String, style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: lc.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text('AI LIVE', style: TextStyle(color: lc, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1))),
        ]),
      ),
    );
  }

  Widget _buildTabBar(Color lc) => TabBar(indicatorColor: lc, labelColor: lc, unselectedLabelColor: Colors.white30,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 13),
      tabs: const [Tab(text: 'Next Trains'), Tab(text: 'Stations'), Tab(text: 'Fare Calc')]);

  Widget _buildScheduleTab(Color lc) {
    if (_schedule.isEmpty) return const Center(child: Text('Loading schedule...', style: TextStyle(color: Colors.white38)));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _schedule.length,
      itemBuilder: (ctx, i) {
        final s = _schedule[i] as Map<String, dynamic>;
        final onTime = (s['status'] as String?) == 'on_time';
        final sc = onTime ? const Color(0xFF30D158) : const Color(0xFFFFD60A);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF12121E), borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.06), width: 0.5)),
          child: Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: lc.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.train_rounded, color: lc, size: 22)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Platform ${s['platform'] ?? 1}', style: TextStyle(color: lc, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
              Text('Departs in ${s['departure']}', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              Text(s['departure_time'] as String? ?? '', style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: sc.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Text(onTime ? '✅ On Time' : '⚠️ Delayed', style: TextStyle(color: sc, fontSize: 11, fontWeight: FontWeight.w700))),
          ]),
        );
      },
    );
  }

  Widget _buildStationsTab(Color lc) {
    if (_stations.isEmpty) return Center(child: CircularProgressIndicator(color: lc));
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: _stations.length,
      itemBuilder: (ctx, i) {
        final s = _stations[i] as Map<String, dynamic>;
        final isHub = s['is_hub'] == true;
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 32, child: Column(children: [
            if (i > 0) Container(width: 2, height: 14, color: lc.withOpacity(0.3)),
            AnimatedBuilder(animation: _pulseCtrl, builder: (ctx, _) => Container(
              width: isHub ? 16 : 10, height: isHub ? 16 : 10,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: isHub ? lc : lc.withOpacity(0.35),
                boxShadow: isHub ? [BoxShadow(color: lc.withOpacity(0.4 * _pulseCtrl.value), blurRadius: 8, spreadRadius: 2)] : null,
                border: isHub ? Border.all(color: Colors.white, width: 2) : null),
            )),
            if (i < _stations.length - 1) Container(width: 2, height: 30, color: lc.withOpacity(0.3)),
          ])),
          Expanded(child: Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4, top: 2),
            child: Row(children: [
              Expanded(child: Text(s['name'] as String? ?? '',
                style: TextStyle(color: isHub ? Colors.white : Colors.white60,
                  fontSize: isHub ? 14 : 12, fontWeight: isHub ? FontWeight.w700 : FontWeight.w400))),
              if (isHub) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: lc.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                child: Text('HUB', style: TextStyle(color: lc, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 1))),
            ]),
          )),
        ]);
      },
    );
  }

  Widget _buildFareTab(Color lc) {
    final names = _stations.map((s) => s['name'] as String).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('FARE CALCULATOR', style: GoogleFonts.spaceGrotesk(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
        const SizedBox(height: 16),
        _dropdownField('From Station', _fareFrom, names, (v) => setState(() { _fareFrom = v; _fareResult = null; }), lc),
        const SizedBox(height: 12),
        _dropdownField('To Station', _fareTo, names, (v) => setState(() { _fareTo = v; _fareResult = null; }), lc),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _fareFrom != null && _fareTo != null && _fareFrom != _fareTo ? _calcFare : null,
          child: AnimatedContainer(duration: const Duration(milliseconds: 200),
            width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: _fareFrom != null && _fareTo != null && _fareFrom != _fareTo
                ? LinearGradient(colors: [lc, lc.withOpacity(0.7)])
                : null,
              color: _fareFrom == null || _fareTo == null || _fareFrom == _fareTo ? Colors.white12 : null,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text('Calculate Fare', textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ),
        if (_fareResult != null) ...[
          const SizedBox(height: 24),
          Container(width: double.infinity, padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [lc.withOpacity(0.15), const Color(0xFF12121E)]),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: lc.withOpacity(0.3), width: 0.5),
            ),
            child: Column(children: [
              Text('₹${_fareResult!['fare_inr']}', style: GoogleFonts.spaceGrotesk(color: lc, fontSize: 56, fontWeight: FontWeight.w900)),
              Text('${_fareResult!['stops']} stops', style: const TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 6),
              Text(_fareResult!['note'] as String? ?? '', style: const TextStyle(color: Colors.white30, fontSize: 10), textAlign: TextAlign.center),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _dropdownField(String label, String? val, List<String> opts, void Function(String?) onCh, Color lc) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
      const SizedBox(height: 6),
      Container(padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12),
            border: Border.all(color: val != null ? lc.withOpacity(0.3) : Colors.white.withOpacity(0.08), width: 0.5)),
        child: DropdownButtonHideUnderline(child: DropdownButton<String>(
          value: val, isExpanded: true, dropdownColor: const Color(0xFF1A1A2E),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          hint: const Text('Select station', style: TextStyle(color: Colors.white30)),
          items: opts.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: onCh,
        )),
      ),
    ]);
  }
}

class _MetroTrainPainter extends CustomPainter {
  final double t;
  final Color lineColor;
  _MetroTrainPainter(this.t, this.lineColor);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Track
    canvas.drawRect(Rect.fromLTWH(0, h * 0.55, w, 3), Paint()..color = lineColor.withOpacity(0.3));
    canvas.drawRect(Rect.fromLTWH(0, h * 0.58, w, 1), Paint()..color = Colors.white.withOpacity(0.05));

    // Sleepers
    final sleeperPaint = Paint()..color = Colors.white.withOpacity(0.04);
    for (double x = (t * 40) % 40; x < w; x += 40) {
      canvas.drawRect(Rect.fromLTWH(x, h * 0.52, 6, 10), sleeperPaint);
    }

    // Train body — moves across
    final tx = -280 + t * (w + 560);
    _drawTrain(canvas, tx, h * 0.2, lineColor);
  }

  void _drawTrain(Canvas canvas, double x, double y, Color color) {
    // Main body
    final body = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, 240, 52), const Radius.circular(10));
    canvas.drawRRect(body, Paint()..color = color);

    // Nose
    final nosePath = Path()
      ..moveTo(x + 240, y + 8)
      ..lineTo(x + 260, y + 26)
      ..lineTo(x + 240, y + 44)
      ..close();
    canvas.drawPath(nosePath, Paint()..color = color.withOpacity(0.8));

    // Windows
    final winPaint = Paint()..color = Colors.white.withOpacity(0.2);
    for (int i = 0; i < 5; i++) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 15.0 + i * 44, y + 10, 32, 22), const Radius.circular(4)), winPaint);
    }

    // Stripe
    canvas.drawRect(Rect.fromLTWH(x, y + 38, 240, 5), Paint()..color = Colors.white.withOpacity(0.15));

    // Wheels
    final wheelPaint = Paint()..color = const Color(0xFF2A2A3E);
    final rimPaint = Paint()..color = Colors.white.withOpacity(0.3)..strokeWidth = 1.5..style = PaintingStyle.stroke;
    for (int i = 0; i < 3; i++) {
      final wx = x + 30.0 + i * 80;
      final wy = y + 52.0;
      canvas.drawCircle(Offset(wx, wy), 10, wheelPaint);
      canvas.drawCircle(Offset(wx, wy), 10, rimPaint);
    }

    // Front light
    canvas.drawCircle(Offset(x + 255, y + 20), 5, Paint()..color = Colors.yellow.withOpacity(0.9));
    canvas.drawCircle(Offset(x + 255, y + 20), 10, Paint()..color = Colors.yellow.withOpacity(0.2));
  }

  @override
  bool shouldRepaint(_MetroTrainPainter old) => old.t != t;
}
