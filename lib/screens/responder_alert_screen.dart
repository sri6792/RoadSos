// lib/screens/responder_alert_screen.dart
// Shown to a volunteer when someone nearby triggers SOS.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/responder_service.dart';
import '../services/app_state.dart';

class ResponderAlertScreen extends StatefulWidget {
  final Map<String, dynamic> alertData;
  const ResponderAlertScreen({super.key, required this.alertData});

  @override
  State<ResponderAlertScreen> createState() => _ResponderAlertScreenState();
}

class _ResponderAlertScreenState extends State<ResponderAlertScreen>
    with TickerProviderStateMixin {
  // Pulse on the ring icon
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // Blob background
  late AnimationController _blobCtrl;
  late Animation<double> _blobAnim;

  // Ripple waves
  late AnimationController _waveCtrl;
  late Animation<double> _waveAnim;

  // Accepted state scale-in
  late AnimationController _acceptCtrl;
  late Animation<double> _acceptScale;

  bool _accepted = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();

    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 1.0,
      end: 1.07,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _blobCtrl = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
    _blobAnim = Tween<double>(begin: 0, end: 1).animate(_blobCtrl);

    _waveCtrl = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    )..repeat();
    _waveAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _waveCtrl, curve: Curves.easeOut));

    _acceptCtrl = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _acceptScale = CurvedAnimation(
      parent: _acceptCtrl,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _blobCtrl.dispose();
    _waveCtrl.dispose();
    _acceptCtrl.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    setState(() => _loading = true);
    HapticFeedback.mediumImpact();

    final lat = AppState.instance.lastLat;
    final lng = AppState.instance.lastLng;

    await ResponderService.instance.acceptSOS(
      docId: widget.alertData['docId'] as String,
      myLat: lat ?? 0.0,
      myLng: lng ?? 0.0,
      myName: AppState.instance.userName,
    );

    setState(() {
      _loading = false;
      _accepted = true;
    });
    _pulseCtrl.stop();
    _waveCtrl.stop();
    _acceptCtrl.forward();

    final vLat = widget.alertData['lat'];
    final vLng = widget.alertData['lng'];
    if (vLat != null && vLng != null) {
      final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=$vLat,$vLng'
        '&travelmode=driving',
      );
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {}
    }
  }

  void _dismiss() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final pad = (size.width * 0.06).clamp(18.0, 28.0);
    final data = widget.alertData;
    final victimName = data['victimName'] as String? ?? 'Someone nearby';
    final address = data['address'] as String? ?? 'Unknown location';
    final bloodGroup = data['bloodGroup'] as String? ?? '';

    // After accepting, blob shifts to green-tinted calm palette
    final blobColor1 = _accepted
        ? const Color(0xFF22C55E)
        : const Color(0xFFFF4500);
    final blobColor2 = _accepted
        ? const Color(0xFF16A34A)
        : const Color(0xFFFF7700);
    final blobColor3 = _accepted
        ? const Color(0xFF15803D)
        : const Color(0xFFCC2200);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Animated blob background ─────────────────────────────────
            AnimatedBuilder(
              animation: _blobAnim,
              builder: (_, __) => CustomPaint(
                size: size,
                painter: _BlobBgPainter(
                  progress: _blobAnim.value,
                  centerY: size.height * 0.34,
                  color1: blobColor1,
                  color2: blobColor2,
                  color3: blobColor3,
                ),
              ),
            ),

            // ── Ripple rings (hidden after accept) ───────────────────────
            if (!_accepted)
              AnimatedBuilder(
                animation: _waveAnim,
                builder: (_, __) => CustomPaint(
                  size: size,
                  painter: _RipplePainter(
                    progress: _waveAnim.value,
                    centerY: size.height * 0.34,
                    color: const Color(0xFFFF6600),
                  ),
                ),
              ),

            // ── Main content ─────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: pad),
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // ── Top pill badge ─────────────────────────────────────
                  Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _accepted
                            ? const Color(0xFF22C55E).withValues(alpha: 0.15)
                            : const Color(0xFFFF4500).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _accepted
                              ? const Color(0xFF22C55E).withValues(alpha: 0.35)
                              : const Color(0xFFFF4500).withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _accepted
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFFFF4500),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _accepted ? 'RESPONDING' : 'EMERGENCY NEARBY',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _accepted
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFFFF4500),
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Ring / accepted badge ─────────────────────────────
                  if (!_accepted)
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, __) => Transform.scale(
                        scale: _pulseAnim.value,
                        child: const _GradientResponderRing(),
                      ),
                    )
                  else
                    ScaleTransition(
                      scale: _acceptScale,
                      child: const _AcceptedBadge(),
                    ),

                  const SizedBox(height: 24),

                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Text(
                      _accepted
                          ? "You're on your way!"
                          : 'Someone needs your help',
                      key: ValueKey(_accepted),
                      style: GoogleFonts.rajdhani(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Text(
                      _accepted
                          ? 'Navigation is opening.\nThank you for being a hero.'
                          : 'You are within ~500m.\nYou could be there in 2–3 minutes.',
                      key: ValueKey(_accepted),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.58),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Victim info card ───────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
                    ),
                    child: Column(
                      children: [
                        _InfoRow(
                          icon: Icons.person_rounded,
                          label: 'Person',
                          value: victimName,
                        ),
                        _RowDivider(),
                        _InfoRow(
                          icon: Icons.location_on_rounded,
                          label: 'Location',
                          value: address,
                          valueColor: const Color(0xFFFF7744),
                        ),
                        if (bloodGroup.isNotEmpty &&
                            bloodGroup != 'Not set') ...[
                          _RowDivider(),
                          _InfoRow(
                            icon: Icons.bloodtype_rounded,
                            label: 'Blood Group',
                            value: bloodGroup,
                            valueColor: const Color(0xFFFF7744),
                          ),
                        ],
                        _RowDivider(),
                        _InfoRow(
                          icon: Icons.medical_services_rounded,
                          label: 'What to do',
                          value:
                              'Keep them calm, check breathing, do not move them',
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // ── Action buttons ─────────────────────────────────────
                  if (!_accepted) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _accept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.directions_run_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    "I'm on my way",
                                    style: GoogleFonts.inter(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Dismiss — styled like Cancel SOS button
                    GestureDetector(
                      onTap: _dismiss,
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.close_rounded,
                              color: Colors.white54,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'I cannot help right now',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.45),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final vLat = data['lat'];
                          final vLng = data['lng'];
                          if (vLat != null && vLng != null) {
                            launchUrl(
                              Uri.parse(
                                'https://www.google.com/maps/dir/?api=1'
                                '&destination=$vLat,$vLng&travelmode=driving',
                              ),
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        icon: const Icon(
                          Icons.navigation_rounded,
                          color: Colors.white,
                        ),
                        label: Text(
                          'Open Navigation',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0EA5E9),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _dismiss,
                      child: Container(
                        width: double.infinity,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Close',
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.38),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Gradient Responder Ring ────────────────────────────────────────────────────

class _GradientResponderRing extends StatelessWidget {
  const _GradientResponderRing();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer faint ring
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFFF6600).withValues(alpha:0.18),
                width: 1.5,
              ),
            ),
          ),
          // Mid ring
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFFF4500).withValues(alpha:0.30),
                width: 1.5,
              ),
            ),
          ),
          // White glow halo
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha:0.16),
                  blurRadius: 18,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),
          // Main gradient circle
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                center: Alignment(-0.3, -0.3),
                radius: 1.0,
                colors: [
                  Color(0xFFFFCC44),
                  Color(0xFFFF7700),
                  Color(0xFFFF3D00),
                  Color(0xFFCC2200),
                ],
                stops: [0.0, 0.35, 0.70, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF4500).withValues(alpha:0.70),
                  blurRadius: 32,
                  spreadRadius: 6,
                ),
                BoxShadow(
                  color: const Color(0xFFFF8800).withValues(alpha:0.30),
                  blurRadius: 60,
                  spreadRadius: 16,
                ),
              ],
            ),
            child: const Icon(
              Icons.emergency_rounded,
              color: Colors.white,
              size: 34,
              shadows: [Shadow(color: Colors.black26, blurRadius: 8)],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Accepted badge ─────────────────────────────────────────────────────────────

class _AcceptedBadge extends StatelessWidget {
  const _AcceptedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.3, -0.3),
          radius: 1.0,
          colors: [Color(0xFF4ADE80), Color(0xFF22C55E), Color(0xFF15803D)],
          stops: [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF22C55E).withValues(alpha: 0.65),
            blurRadius: 36,
            spreadRadius: 8,
          ),
          BoxShadow(
            color: const Color(0xFF22C55E).withValues(alpha: 0.25),
            blurRadius: 64,
            spreadRadius: 20,
          ),
        ],
      ),
      child: const Icon(Icons.check_rounded, color: Colors.white, size: 52),
    );
  }
}

// ── Info row ───────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white38, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white38,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? Colors.white,
                    height: 1.4,
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

class _RowDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(color: Colors.white.withValues(alpha: 0.07), height: 1);
  }
}

// ── Blob background painter ────────────────────────────────────────────────────

class _BlobBgPainter extends CustomPainter {
  final double progress;
  final double centerY;
  final Color color1;
  final Color color2;
  final Color color3;

  _BlobBgPainter({
    required this.progress,
    required this.centerY,
    required this.color1,
    required this.color2,
    required this.color3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = centerY;
    final t = progress * math.pi * 2;

    // Primary blob
    final paint1 = Paint()
      ..shader =
          RadialGradient(
            colors: [
              color1.withValues(alpha: 0.50),
              color2.withValues(alpha: 0.26),
              Colors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(
            Rect.fromCircle(center: Offset(cx, cy), radius: size.width * 0.58),
          );
    final bx = cx + math.sin(t * 0.7) * size.width * 0.05;
    final by = cy + math.cos(t * 0.5) * size.height * 0.03;
    canvas.drawCircle(Offset(bx, by), size.width * 0.58, paint1);

    // Secondary amber blob
    final paint2 = Paint()
      ..shader =
          RadialGradient(
            colors: [
              color2.withValues(alpha: 0.30),
              color1.withValues(alpha: 0.12),
              Colors.transparent,
            ],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(
            Rect.fromCircle(
              center: Offset(cx + size.width * 0.16, cy - size.height * 0.04),
              radius: size.width * 0.42,
            ),
          );
    final b2x =
        cx + size.width * 0.16 + math.cos(t * 0.6 + 1.2) * size.width * 0.04;
    final b2y =
        cy - size.height * 0.04 + math.sin(t * 0.8) * size.height * 0.02;
    canvas.drawCircle(Offset(b2x, b2y), size.width * 0.42, paint2);

    // Tertiary deep blob — bottom left
    final paint3 = Paint()
      ..shader =
          RadialGradient(
            colors: [color3.withValues(alpha: 0.26), Colors.transparent],
            stops: const [0.0, 1.0],
          ).createShader(
            Rect.fromCircle(
              center: Offset(cx - size.width * 0.18, cy + size.height * 0.05),
              radius: size.width * 0.36,
            ),
          );
    final b3x =
        cx - size.width * 0.18 + math.sin(t * 0.9 + 2.0) * size.width * 0.04;
    final b3y =
        cy + size.height * 0.05 + math.cos(t * 0.6 + 0.5) * size.height * 0.02;
    canvas.drawCircle(Offset(b3x, b3y), size.width * 0.36, paint3);
  }

  @override
  bool shouldRepaint(_BlobBgPainter old) =>
      old.progress != progress ||
      old.color1 != color1 ||
      old.color2 != color2 ||
      old.color3 != color3;
}

// ── Ripple painter ─────────────────────────────────────────────────────────────

class _RipplePainter extends CustomPainter {
  final double progress;
  final double centerY;
  final Color color;

  _RipplePainter({
    required this.progress,
    required this.centerY,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = centerY;
    final maxR = size.width * 0.60;

    for (int i = 0; i < 3; i++) {
      final offset = i / 3.0;
      final t = (progress + offset) % 1.0;
      final radius = maxR * t;
      final opacity = (1 - t) * 0.22;

      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..color = color.withValues(alpha:opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.progress != progress;
}
