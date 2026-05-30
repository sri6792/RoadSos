// lib/screens/sos_active_screen.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/sms_service.dart';
import '../services/app_state.dart';
import '../services/responder_service.dart';

String currentCallingService = 'Connecting to emergency services...';

class SOSActiveScreen extends StatefulWidget {
  const SOSActiveScreen({super.key});

  @override
  State<SOSActiveScreen> createState() => _SOSActiveScreenState();
}

class _SOSActiveScreenState extends State<SOSActiveScreen>
    with TickerProviderStateMixin {
  int _countdown = 10;
  Timer? _timer;

  bool _callConnected = false;
  bool _smsSent = false;
  bool _locationShared = false;

  // Golden Hour responder state
  bool _searchingResponders = false;
  bool _responderFound = false;
  String _responderName = '';
  double _responderEta = 0;
  String? _responderDocId;

  String liveAddress = 'Fetching live location...';
  String liveCoords = '';
  double? _lat;
  double? _lng;

  // ── Animation controllers ─────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  late AnimationController _responderCtrl;
  late Animation<double> _responderFadeIn;

  @override
  void initState() {
    super.initState();

    // Slow breathing pulse on the circle
    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 1.0,
      end: 1.06,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Responder found fade
    _responderCtrl = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _responderFadeIn = CurvedAnimation(
      parent: _responderCtrl,
      curve: Curves.easeOut,
    );

    _activateRealSOS();

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_countdown > 0) _countdown--;
      });
    });
  }

  Future<void> _activateRealSOS() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => liveAddress = 'Location service is off');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => liveAddress = 'Location permission denied');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _lat = position.latitude;
      _lng = position.longitude;
      AppState.instance.lastLat = _lat;
      AppState.instance.lastLng = _lng;

      liveCoords =
          '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';

      String address = 'Live location';
      try {
        final places = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (places.isNotEmpty) {
          final p = places.first;
          address =
              '${p.name ?? ''}, ${p.locality ?? ''}, ${p.administrativeArea ?? ''}';
        }
      } catch (_) {}

      setState(() {
        liveAddress = address;
        _locationShared = true;
      });

      final mapLink =
          'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';

      final smsMessage =
          '''
🚨 ROADSOS EMERGENCY ALERT 🚨

Possible accident detected.

📍 Location: $address
🗺 Coordinates: $liveCoords
Google Maps: $mapLink

Please respond immediately.
''';

      final numbers = AppState.instance.sosNumbers;
      final smsSuccess = await SMSService.sendSOS(
        numbers: numbers,
        message: smsMessage,
      );
      setState(() => _smsSent = smsSuccess);

      _broadcastToResponders(
        lat: position.latitude,
        lng: position.longitude,
        address: address,
      );

      final sosData = {
        'type': 'sos_alert',
        'status': 'SOS Triggered',
        'latitude': position.latitude.toStringAsFixed(6),
        'longitude': position.longitude.toStringAsFixed(6),
        'address': address,
        'coordinates': liveCoords,
        'mapLink': mapLink,
        'smsStatus': smsSuccess ? 'sent' : 'failed',
        'callStatus': 'calling',
        'notifiedContacts': numbers.length,
        'userId': AppState.instance.isGuest ? 'guest' : 'user',
        'time': DateTime.now(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      try {
        await FirebaseFirestore.instance.collection('sos_alerts').add(sosData);
        await FirebaseFirestore.instance
            .collection('emergency_logs')
            .add(sosData);
      } catch (e) {
        debugPrint('Offline mode active: $e');
      }
    } catch (e) {
      debugPrint('SOS ERROR: $e');
      setState(() {
        liveAddress = 'Unable to share location';
        liveCoords = '';
      });
    }
  }

  Future<void> _broadcastToResponders({
    required double lat,
    required double lng,
    required String address,
  }) async {
    setState(() => _searchingResponders = true);

    ResponderService.instance.onResponderFound = (name, eta) {
      if (!mounted) return;
      setState(() {
        _responderFound = true;
        _responderName = name;
        _responderEta = eta;
        _searchingResponders = false;
      });
      _responderCtrl.forward();
    };

    final docId = await ResponderService.instance.broadcastSOS(
      lat: lat,
      lng: lng,
      address: address,
      victimName: AppState.instance.userName,
      bloodGroup: 'B+',
    );

    if (docId != null) {
      _responderDocId = docId;
      ResponderService.instance.listenForResponder(docId);
    } else {
      setState(() => _searchingResponders = false);
    }
  }

  Future<void> _logEmergencyNumberCall(String number, String label) async {
    setState(() {
      _callConnected = true;
      currentCallingService = '$label ($number)';
    });
    try {
      await FirebaseFirestore.instance.collection('emergency_logs').add({
        'type': 'emergency_number_call',
        'label': label,
        'number': number,
        'status': 'Calling',
        'callingText': 'Calling $label ($number)',
        'userId': AppState.instance.isGuest ? 'guest' : 'user',
        'time': DateTime.now(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Call log will sync when online: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    _responderCtrl.dispose();
    ResponderService.instance.onResponderFound = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final pad = (size.width * 0.06).clamp(18.0, 28.0);
    final isSmall = size.height < 700;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: pad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Header ───────────────────────────────────────────
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'ROAD SOS',
                            style: GoogleFonts.rajdhani(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                          // ── Cancel SOS styled like the Add button ─────
                          GestureDetector(
                            onTap: _showCancelDialog,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha:0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha:0.22),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.close_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Cancel SOS',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      // ── SOS circle with warm gradient blob ───────────────
                      SizedBox(height: isSmall ? 18 : 28),
                      Center(
                        child: AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (_, __) => Transform.scale(
                            scale: _pulseAnim.value,
                            child: _GradientSOSCircle(countdown: _countdown),
                          ),
                        ),
                      ),

                      SizedBox(height: isSmall ? 14 : 20),

                      Text(
                        'SOS ACTIVATED',
                        style: GoogleFonts.rajdhani(
                          fontSize: (size.width * 0.09).clamp(28.0, 40.0),
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Emergency services are being contacted',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha:0.60),
                        ),
                        textAlign: TextAlign.center,
                      ),

                      SizedBox(height: isSmall ? 16 : 22),

                      // ── Golden Hour responder card ───────────────────────
                      _GoldenHourStatusCard(
                        searching: _searchingResponders,
                        found: _responderFound,
                        responderName: _responderName,
                        etaMinutes: _responderEta,
                        fadeAnim: _responderFadeIn,
                      ),

                      const SizedBox(height: 10),

                      // ── Status cards ─────────────────────────────────────
                      _StatusCard(
                        icon: Icons.call_rounded,
                        title: 'Emergency Call',
                        subtitle: _callConnected
                            ? 'Calling $currentCallingService'
                            : 'Preparing emergency connection...',
                        status: _callConnected,
                        statusLabel: _callConnected
                            ? currentCallingService
                            : 'Connecting...',
                      ),
                      const SizedBox(height: 10),
                      _StatusCard(
                        icon: Icons.notifications_active_rounded,
                        title: 'Emergency Response',
                        subtitle: _smsSent
                            ? 'Nearby emergency services notified'
                            : 'Contacting emergency response system...',
                        status: _smsSent,
                        statusLabel: _smsSent ? 'Alert Sent' : 'Sending...',
                      ),
                      const SizedBox(height: 10),
                      _StatusCard(
                        icon: Icons.location_on_rounded,
                        title: 'Live Location',
                        subtitle: liveCoords.isNotEmpty
                            ? '$liveAddress\n$liveCoords'
                            : liveAddress,
                        status: _locationShared,
                        statusLabel: _locationShared
                            ? 'Sharing'
                            : 'Fetching...',
                      ),

                      SizedBox(height: isSmall ? 14 : 20),

                      // ── Quick dial ───────────────────────────────────────
                      Row(
                        children: [
                          _QuickDial(
                            label: 'Ambulance',
                            number: '108',
                            color: const Color(0xFFE83000),
                            onLog: _logEmergencyNumberCall,
                          ),
                          const SizedBox(width: 10),
                          _QuickDial(
                            label: 'Police',
                            number: '100',
                            color: const Color(0xFF1A3A6A),
                            onLog: _logEmergencyNumberCall,
                          ),
                          const SizedBox(width: 10),
                          _QuickDial(
                            label: 'Fire',
                            number: '101',
                            color: const Color(0xFFFF6600),
                            onLog: _logEmergencyNumberCall,
                          ),
                        ],
                      ),

                      SizedBox(height: isSmall ? 20 : 32),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Cancel SOS?',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        content: Text(
          'This will stop the emergency alert screen.',
          style: GoogleFonts.inter(color: Colors.white54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Keep Active',
              style: GoogleFonts.inter(
                color: const Color(0xFFFF4500),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text(
              'Cancel SOS',
              style: GoogleFonts.inter(color: Colors.white38),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated warm gradient SOS circle ─────────────────────────────────────────

class _GradientSOSCircle extends StatelessWidget {
  final int countdown;
  const _GradientSOSCircle({required this.countdown});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final ringSize = (size.width * 0.50).clamp(170.0, 235.0);
    final innerSize = ringSize * 0.62;

    return SizedBox(
      width: ringSize + 90,
      height: ringSize + 90,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ───────────────── BIG BACKGROUND GLOW ─────────────────
          // Lowest layer
          Container(
            width: ringSize + 75,
            height: ringSize + 75,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF5500).withValues(alpha:0.22),
                  blurRadius: 95,
                  spreadRadius: 35,
                ),
                BoxShadow(
                  color: const Color(0xFFFFAA00).withValues(alpha:0.14),
                  blurRadius: 130,
                  spreadRadius: 50,
                ),
              ],
            ),
          ),

          // ───────────────── OUTER GLOW HALO ─────────────────
          Container(
            width: ringSize * 1.12,
            height: ringSize * 1.12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6600).withValues(alpha:0.26),
                  blurRadius: 45,
                  spreadRadius: 12,
                ),
              ],
            ),
          ),

          // ───────────────── OUTER RING ─────────────────
          Container(
            width: ringSize,
            height: ringSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFFF7700).withValues(alpha:0.26),
                width: 1.8,
              ),
            ),
          ),

          // ───────────────── MID RING ─────────────────
          Container(
            width: ringSize * 0.82,
            height: ringSize * 0.82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFFF5500).withValues(alpha:0.38),
                width: 1.6,
              ),
            ),
          ),

          // ───────────────── INNER RING GLOW ─────────────────
          Container(
            width: ringSize * 0.67,
            height: ringSize * 0.67,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha:0.18),
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
                BoxShadow(
                  color: const Color(0xFFFF8800).withValues(alpha:0.28),
                  blurRadius: 55,
                  spreadRadius: 14,
                ),
              ],
            ),
          ),

          // ───────────────── MAIN SOS CIRCLE ─────────────────
          // Top layer
          Container(
            width: innerSize,
            height: innerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                center: Alignment(-0.25, -0.25),
                radius: 1.0,
                colors: [
                  Color(0xFFFFDD66),
                  Color(0xFFFF8800),
                  Color(0xFFFF4500),
                  Color(0xFFCC2200),
                ],
                stops: [0.0, 0.32, 0.72, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF5500).withValues(alpha:0.65),
                  blurRadius: 42,
                  spreadRadius: 10,
                ),
                BoxShadow(
                  color: const Color(0xFFFFAA00).withValues(alpha:0.25),
                  blurRadius: 75,
                  spreadRadius: 24,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  countdown > 0 ? '$countdown' : '!',
                  style: GoogleFonts.rajdhani(
                    fontSize: innerSize * 0.30,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha:0.30),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
                Text(
                  countdown > 0 ? 'seconds' : 'ACTIVE',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha:0.82),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated blob background painter ──────────────────────────────────────────

class _BlobBackgroundPainter extends CustomPainter {
  final double progress; // 0 → 1 looping
  final double centerY;

  _BlobBackgroundPainter({required this.progress, required this.centerY});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = centerY;
    final t = progress * math.pi * 2;

    // Primary blob — warm red/orange glow
    final paint1 = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFFFF4500).withValues(alpha:0.55),
              const Color(0xFFFF6600).withValues(alpha:0.28),
              Colors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(
            Rect.fromCircle(center: Offset(cx, cy), radius: size.width * 0.60),
          );

    final blobX = cx + math.sin(t * 0.7) * size.width * 0.06;
    final blobY = cy + math.cos(t * 0.5) * size.height * 0.03;
    canvas.drawCircle(Offset(blobX, blobY), size.width * 0.60, paint1);

    // Secondary blob — amber/yellow accent, offset
    final paint2 = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFFFFAA00).withValues(alpha:0.32),
              const Color(0xFFFF6600).withValues(alpha:0.15),
              Colors.transparent,
            ],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(
            Rect.fromCircle(
              center: Offset(cx + size.width * 0.18, cy - size.height * 0.04),
              radius: size.width * 0.44,
            ),
          );

    final b2x =
        cx + size.width * 0.18 + math.cos(t * 0.6 + 1.2) * size.width * 0.05;
    final b2y =
        cy - size.height * 0.04 + math.sin(t * 0.8) * size.height * 0.025;
    canvas.drawCircle(Offset(b2x, b2y), size.width * 0.44, paint2);

    // Tertiary deep red blob — bottom left
    final paint3 = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFFCC2200).withValues(alpha:0.28),
              Colors.transparent,
            ],
            stops: const [0.0, 1.0],
          ).createShader(
            Rect.fromCircle(
              center: Offset(cx - size.width * 0.20, cy + size.height * 0.05),
              radius: size.width * 0.38,
            ),
          );

    final b3x =
        cx - size.width * 0.20 + math.sin(t * 0.9 + 2.0) * size.width * 0.04;
    final b3y =
        cy + size.height * 0.05 + math.cos(t * 0.6 + 0.5) * size.height * 0.02;
    canvas.drawCircle(Offset(b3x, b3y), size.width * 0.38, paint3);
  }

  @override
  bool shouldRepaint(_BlobBackgroundPainter old) => old.progress != progress;
}

// ── Ripple / wave rings painter ────────────────────────────────────────────────

class _RipplePainter extends CustomPainter {
  final double progress; // 0 → 1 looping
  final double centerY;

  _RipplePainter({required this.progress, required this.centerY});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = centerY;
    final maxR = size.width * 0.62;

    for (int i = 0; i < 3; i++) {
      final offset = i / 3.0;
      final t = ((progress + offset) % 1.0);
      final radius = maxR * t;
      final opacity = (1 - t) * 0.25;

      final paint = Paint()
        ..color = const Color(0xFFFF6600).withValues(alpha:opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.progress != progress;
}

// ── Golden Hour Status Card ────────────────────────────────────────────────────

class _GoldenHourStatusCard extends StatelessWidget {
  final bool searching;
  final bool found;
  final String responderName;
  final double etaMinutes;
  final Animation<double> fadeAnim;

  const _GoldenHourStatusCard({
    required this.searching,
    required this.found,
    required this.responderName,
    required this.etaMinutes,
    required this.fadeAnim,
  });

  @override
  Widget build(BuildContext context) {
    if (!searching && !found) return const SizedBox.shrink();

    return FadeTransition(
      opacity: found ? fadeAnim : const AlwaysStoppedAnimation(1.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: found
              ? const Color(0xFF22C55E).withValues(alpha:0.12)
              : Colors.white.withValues(alpha:0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: found
                ? const Color(0xFF22C55E).withValues(alpha:0.40)
                : Colors.white.withValues(alpha:0.10),
            width: found ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: found
                    ? const Color(0xFF22C55E).withValues(alpha:0.18)
                    : Colors.white.withValues(alpha:0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: found
                  ? const Icon(
                      Icons.volunteer_activism_rounded,
                      color: Color(0xFF22C55E),
                      size: 20,
                    )
                  : const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFFF7700),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    found
                        ? '$responderName is on the way!'
                        : 'Finding nearby volunteers...',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: found ? const Color(0xFF22C55E) : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    found
                        ? 'Arriving in ~${etaMinutes.toStringAsFixed(0)} min · Golden Hour Responder'
                        : 'Checking for first-aid trained people nearby',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: found
                          ? const Color(0xFF22C55E).withValues(alpha:0.75)
                          : Colors.white.withValues(alpha:0.45),
                    ),
                  ),
                ],
              ),
            ),
            if (found)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha:0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '~${etaMinutes.toStringAsFixed(0)} min',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF22C55E),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Status card ────────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool status;
  final String statusLabel;

  const _StatusCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha:0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha:0.09)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: status
                  ? const Color(0xFF22C55E).withValues(alpha:0.14)
                  : const Color(0xFFFF4500).withValues(alpha:0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: status ? const Color(0xFF22C55E) : const Color(0xFFFF7744),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha:0.50),
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: status
                  ? const Color(0xFF22C55E).withValues(alpha:0.14)
                  : const Color(0xFFFF4500).withValues(alpha:0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statusLabel,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: status
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFFF7744),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick dial ─────────────────────────────────────────────────────────────────

class _QuickDial extends StatelessWidget {
  final String label;
  final String number;
  final Color color;
  final Future<void> Function(String number, String label) onLog;

  const _QuickDial({
    required this.label,
    required this.number,
    required this.color,
    required this.onLog,
  });

  Future<void> _makeCall() async {
    await onLog(number, label);

    final uri = Uri.parse('tel:$number');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        debugPrint('Cannot launch dialer');
      }
    } catch (e) {
      debugPrint('Dialer error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: _makeCall,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: color.withValues(alpha:0.14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha:0.28)),
          ),
          child: Column(
            children: [
              Icon(Icons.call_rounded, color: color, size: 19),
              const SizedBox(height: 4),
              Text(
                number,
                style: GoogleFonts.rajdhani(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha:0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
