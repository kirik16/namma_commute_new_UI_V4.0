import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class LiveTrafficScreen extends StatefulWidget {
  const LiveTrafficScreen({super.key});
  @override
  State<LiveTrafficScreen> createState() => _LiveTrafficScreenState();
}

class _LiveTrafficScreenState extends State<LiveTrafficScreen> with TickerProviderStateMixin {
  String _selectedFilter = 'All';
  bool _loading = true;
  bool _hasError = false;
  List<dynamic> _incidents = [];
  Map<String, dynamic> _summary = {};
  Timer? _refreshTimer;
  DateTime? _lastUpdated;
  late AnimationController _vehicleCtrl;
  late AnimationController _pulseCtrl;

  final _filters = ['All', 'critical', 'high', 'accident', 'flood', 'construction'];

  @override
  void initState() {
    super.initState();
    _vehicleCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _fetchData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchData());
  }

  @override
  void dispose() {
    _vehicleCtrl.dispose();
    _pulseCtrl.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final results = await Future.wait([
        ApiService.getTrafficIncidents(),
        ApiService.getTrafficSummary(),
      ]);
      if (!mounted) return;
      setState(() {
        _incidents = results[0] as List<dynamic>;
        _summary = results[1] as Map<String, dynamic>;
        _loading = false;
        _hasError = false;
        _lastUpdated = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _hasError = true; _loading = false; });
    }
  }

  List<dynamic> get _filtered {
    if (_selectedFilter == 'All') return _incidents;
    return _incidents.where((i) =>
      i['severity'] == _selectedFilter || i['type'] == _selectedFilter).toList();
  }

  Color _sevColor(String s) {
    switch (s) {
      case 'critical': return const Color(0xFFFF3B5C);
      case 'high':     return const Color(0xFFFF9500);
      case 'moderate': return const Color(0xFFFFD60A);
      default:         return const Color(0xFF30D158);
    }
  }

  String _typeIcon(String t) {
    switch (t) {
      case 'accident':     return '🚗';
      case 'construction': return '🚧';
      case 'flood':        return '🌊';
      case 'event':        return '🎭';
      case 'signal':       return '🚦';
      case 'pothole':      return '🕳️';
      default:             return '⚠️';
    }
  }

  String _timeAgo(String? ts) {
    if (ts == null) return '';
    try {
      final diff = DateTime.now().difference(DateTime.parse(ts));
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      return '${diff.inHours}h ago';
    } catch (_) { return ''; }
  }

  void _showRouteInfo(Map<String, dynamic> incident) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF12121E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          Text('Avoid ${incident['location']}', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(incident['description'] as String? ?? '', style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.5)),
          const SizedBox(height: 20),
          const Text('💡 Alternative Routes', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 10),
          _routeChip('Via Outer Ring Road', '+5 min'),
          const SizedBox(height: 8),
          _routeChip('Via NICE Road', '+12 min'),
          const SizedBox(height: 8),
          _routeChip('🚇 Take Namma Metro', 'Recommended'),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _routeChip(String route, String time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08))),
      child: Row(children: [
        Text(route, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const Spacer(),
        Text(time, style: const TextStyle(color: Color(0xFF30D158), fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  void _showReportSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF12121E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (ctx) => _QuickReportSheet(onSubmit: (data) async {
        Navigator.pop(ctx);
        try {
          await ApiService.createIncident(data);
          _fetchData();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('✅ Incident reported! Thank you.'),
            backgroundColor: const Color(0xFF30D158),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        }
      }),
    );
  }

  Future<void> _upvote(int id) async {
    try {
      await ApiService.upvoteIncident(id);
      _fetchData();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: const Color(0xFF08080F),
      body: Column(children: [
        _buildHeader(),
        _buildAnimatedRoad(),
        _buildFilterRow(),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
          : _hasError
            ? _buildError()
            : filtered.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _fetchData,
                  color: const Color(0xFFFF6B35),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) => _buildCard(filtered[i] as Map<String, dynamic>),
                  ),
                ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showReportSheet,
        backgroundColor: const Color(0xFFFF6B35),
        elevation: 0,
        icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
        label: Text('Report', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildHeader() {
    final total = _summary['total_active_incidents'] as int? ?? _incidents.length;
    final critical = _summary['critical_incidents'] as int? ?? 0;
    final index = _summary['traffic_index'] as int? ?? 0;
    final indexColor = index > 65 ? const Color(0xFF30D158) : index > 45 ? const Color(0xFFFFD60A) : const Color(0xFFFF3B5C);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E1C),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06), width: 0.5)),
      ),
      child: SafeArea(bottom: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(children: [
          Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Live Traffic', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
              Text('$total incidents · Bengaluru', style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ]),
            const Spacer(),
            AnimatedBuilder(animation: _pulseCtrl, builder: (ctx, _) =>
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B5C).withOpacity(0.1 + 0.05 * _pulseCtrl.value),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFF3B5C).withOpacity(0.4)),
                ),
                child: Row(children: [
                  Container(width: 6, height: 6,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                      color: Color.lerp(const Color(0xFFFF3B5C), Colors.red.shade200, _pulseCtrl.value))),
                  const SizedBox(width: 5),
                  Text('LIVE', style: GoogleFonts.spaceGrotesk(color: const Color(0xFFFF3B5C), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          // Stats row from real API data
          Row(children: [
            _statChip('🚨 $critical Critical', const Color(0xFFFF3B5C)),
            const SizedBox(width: 8),
            _statChip('📊 Index: $index', indexColor),
            const SizedBox(width: 8),
            if (_lastUpdated != null)
              _statChip('🔄 ${DateTime.now().difference(_lastUpdated!).inSeconds}s ago', Colors.white38),
          ]),
        ]),
      )),
    );
  }

  Widget _statChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.25), width: 0.5)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  // ── ANIMATED ROAD WITH VEHICLES ────────────────────────────────────────────
  Widget _buildAnimatedRoad() {
    return Container(
      height: 80,
      color: const Color(0xFF0A0A16),
      child: AnimatedBuilder(
        animation: _vehicleCtrl,
        builder: (ctx, _) => CustomPaint(
          painter: _RoadPainter(_vehicleCtrl.value, _incidents.length),
          size: const Size(double.infinity, 80),
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Container(
      height: 48,
      color: const Color(0xFF0E0E1C),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _filters.length,
        itemBuilder: (ctx, i) {
          final sel = _selectedFilter == _filters[i];
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = _filters[i]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: sel ? const Color(0xFFFF6B35) : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? const Color(0xFFFF6B35) : Colors.white.withOpacity(0.1), width: 0.5),
              ),
              child: Text(
                _filters[i][0].toUpperCase() + _filters[i].substring(1),
                style: TextStyle(color: sel ? Colors.white : Colors.white38,
                    fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w500),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> incident) {
    final sev = incident['severity'] as String? ?? 'low';
    final color = _sevColor(sev);
    final type = incident['type'] as String? ?? 'accident';
    final upvotes = incident['upvotes'] as int? ?? 0;
    final id = incident['id'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF12121E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25), width: 0.5),
        boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 16, spreadRadius: 1)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Severity bar at top
        Container(height: 3,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withOpacity(0.2)]),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(_typeIcon(type), style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(child: Text(incident['location'] as String? ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Text(sev.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
              ),
            ]),
            const SizedBox(height: 8),
            Text(incident['description'] as String? ?? '',
                style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.5)),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.access_time_rounded, color: Colors.white24, size: 12),
              const SizedBox(width: 4),
              Text(_timeAgo(incident['reported_at'] as String?), style: const TextStyle(color: Colors.white24, fontSize: 11)),
              const Spacer(),
              _actionBtn(Icons.thumb_up_outlined, '$upvotes', Colors.white38, () => _upvote(id)),
              const SizedBox(width: 8),
              _actionBtn(Icons.alt_route_rounded, 'Avoid', const Color(0xFF00E5CC), () => _showRouteInfo(incident)),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.2), width: 0.5)),
        child: Row(children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _buildError() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Text('📡', style: TextStyle(fontSize: 40)),
    const SizedBox(height: 12),
    const Text('Could not load incidents', style: TextStyle(color: Colors.white54)),
    const SizedBox(height: 12),
    GestureDetector(onTap: _fetchData,
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFFFF6B35), borderRadius: BorderRadius.circular(12)),
        child: const Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
  ]));

  Widget _buildEmpty() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Text('✅', style: TextStyle(fontSize: 48)),
    const SizedBox(height: 12),
    Text('No $_selectedFilter incidents right now', style: const TextStyle(color: Colors.white54, fontSize: 14)),
  ]));
}

// ── ANIMATED ROAD PAINTER ─────────────────────────────────────────────────────
class _RoadPainter extends CustomPainter {
  final double t;
  final int incidentCount;
  _RoadPainter(this.t, this.incidentCount);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Road background
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()..color = const Color(0xFF0A0A16));

    // Road surface
    final roadPaint = Paint()..color = const Color(0xFF1A1A28);
    canvas.drawRect(Rect.fromLTWH(0, h * 0.25, w, h * 0.5), roadPaint);

    // Center dashes
    final dashPaint = Paint()..color = const Color(0xFFFFD60A).withOpacity(0.4)..strokeWidth = 2;
    for (double x = -80 + (t * 80) % 80; x < w + 80; x += 60) {
      canvas.drawLine(Offset(x, h * 0.5), Offset(x + 30, h * 0.5), dashPaint);
    }

    // Lane lines
    final lanePaint = Paint()..color = Colors.white.withOpacity(0.08)..strokeWidth = 1;
    canvas.drawLine(Offset(0, h * 0.3), Offset(w, h * 0.3), lanePaint);
    canvas.drawLine(Offset(0, h * 0.7), Offset(w, h * 0.7), lanePaint);

    // Vehicles moving right (top lane)
    _drawCar(canvas, size, (-200 + t * (w + 400)) % (w + 300) - 100, h * 0.33, const Color(0xFFFF6B35), 0.85);
    _drawCar(canvas, size, (-200 + t * (w + 400) + 220) % (w + 300) - 100, h * 0.33, const Color(0xFF7C6FFF), 0.7);
    _drawBus(canvas, size, (-300 + t * (w + 400) * 0.6 + 120) % (w + 400) - 150, h * 0.33, const Color(0xFF00E5CC));

    // Vehicles moving left (bottom lane) — reversed
    _drawCar(canvas, size, w - (-150 + t * (w + 300) * 0.8) % (w + 250), h * 0.67, const Color(0xFFFFD60A), 0.75);
    _drawCar(canvas, size, w - (-150 + t * (w + 300) * 0.8 + 180) % (w + 250), h * 0.67, Colors.white.withOpacity(0.6), 0.65);

    // Traffic signal icon if incidents
    if (incidentCount > 0) {
      _drawSignal(canvas, w * 0.7, h * 0.22, const Color(0xFFFF3B5C));
    }
  }

  void _drawCar(Canvas canvas, Size size, double x, double y, Color color, double scale) {
    canvas.save();
    canvas.translate(x, y);
    canvas.scale(scale);
    final body = RRect.fromRectAndRadius(const Rect.fromLTWH(-22, -7, 44, 14), const Radius.circular(5));
    canvas.drawRRect(body, Paint()..color = color);
    // Roof
    final roof = RRect.fromRectAndRadius(const Rect.fromLTWH(-12, -14, 24, 9), const Radius.circular(4));
    canvas.drawRRect(roof, Paint()..color = color.withOpacity(0.7));
    // Wheels
    final wheelPaint = Paint()..color = Colors.black87;
    canvas.drawCircle(const Offset(-12, 7), 4, wheelPaint);
    canvas.drawCircle(const Offset(12, 7), 4, wheelPaint);
    // Headlights
    canvas.drawCircle(const Offset(21, -2), 2, Paint()..color = Colors.yellow.withOpacity(0.8));
    canvas.restore();
  }

  void _drawBus(Canvas canvas, Size size, double x, double y, Color color) {
    canvas.save();
    canvas.translate(x, y);
    final body = RRect.fromRectAndRadius(const Rect.fromLTWH(-35, -10, 70, 20), const Radius.circular(4));
    canvas.drawRRect(body, Paint()..color = color.withOpacity(0.85));
    // Windows
    final winPaint = Paint()..color = Colors.white.withOpacity(0.3);
    for (int i = 0; i < 4; i++) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-28.0 + i * 16, -7, 10, 8), const Radius.circular(2)), winPaint);
    }
    // Wheels
    final wp = Paint()..color = Colors.black87;
    canvas.drawCircle(const Offset(-22, 10), 5, wp);
    canvas.drawCircle(const Offset(22, 10), 5, wp);
    canvas.restore();
  }

  void _drawSignal(Canvas canvas, double x, double y, Color color) {
    final paint = Paint()..color = color.withOpacity(0.8);
    canvas.drawCircle(Offset(x, y), 5, paint);
    canvas.drawLine(Offset(x, y + 5), Offset(x, y + 15), Paint()..color = Colors.white24..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_RoadPainter old) => old.t != t;
}

// ── QUICK REPORT SHEET ────────────────────────────────────────────────────────
class _QuickReportSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onSubmit;
  const _QuickReportSheet({required this.onSubmit});
  @override
  State<_QuickReportSheet> createState() => _QuickReportSheetState();
}

class _QuickReportSheetState extends State<_QuickReportSheet> {
  String? _type;
  final _locCtrl = TextEditingController();
  final _types = [
    {'type': 'accident', 'icon': '🚗', 'label': 'Accident'},
    {'type': 'flood', 'icon': '🌊', 'label': 'Waterlogging'},
    {'type': 'construction', 'icon': '🚧', 'label': 'Construction'},
    {'type': 'signal', 'icon': '🚦', 'label': 'Signal'},
    {'type': 'pothole', 'icon': '🕳️', 'label': 'Pothole'},
    {'type': 'event', 'icon': '🎭', 'label': 'Event'},
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        Text('Quick Report', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: _types.map((t) {
          final sel = _type == t['type'];
          return GestureDetector(
            onTap: () => setState(() => _type = t['type'] as String),
            child: AnimatedContainer(duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? const Color(0xFFFF6B35).withOpacity(0.2) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? const Color(0xFFFF6B35) : Colors.white.withOpacity(0.1)),
              ),
              child: Text('${t['icon']} ${t['label']}',
                  style: TextStyle(color: sel ? const Color(0xFFFF6B35) : Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          );
        }).toList()),
        const SizedBox(height: 14),
        TextField(controller: _locCtrl, style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(hintText: 'Location (e.g. Silk Board)',
            hintStyle: const TextStyle(color: Colors.white30),
            filled: true, fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.all(14)),
        ),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity,
          child: ElevatedButton(
            onPressed: _type == null || _locCtrl.text.isEmpty ? null : () =>
              widget.onSubmit({'type': _type, 'location': _locCtrl.text, 'area': 'Bengaluru', 'severity': 'moderate'}),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B35),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text('Submit Report', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 8),
      ])),
    );
  }
}
