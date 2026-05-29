// lib/screens/crash_alert_screen.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'sos_active_screen.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const Color _red = Color(0xFFE83000);
const Color _orange = Color(0xFFFF6600);
const Color _amber = Color(0xFFFFAA00);
const Color _yellow = Color(0xFFFFDD00);
const Color _white = Color(0xFFFFFFFF);

const List<Color> _fireGradient = [_red, _orange, _amber, _yellow];

class CrashAlertScreen extends StatefulWidget {
  final int seconds;
  final String title;
  final String subtitle;

  const CrashAlertScreen({
    super.key,
    this.seconds = 10,
    this.title = 'Are you okay?',
    this.subtitle =
        'A sudden impact was detected.\nSOS will be sent automatically.',
  });

  @override
  State<CrashAlertScreen> createState() => _CrashAlertScreenState();
}

class _CrashAlertScreenState extends State<CrashAlertScreen>
    with TickerProviderStateMixin {
  late int _remaining;
  Timer? _timer;
  bool _cancelled = false;

  // Countdown ring pulse
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  // Blob rotation
  late AnimationController _rotateCtrl;
  late Animation<double> _rotation;

  // Blob scale / breathe
  late AnimationController _blobCtrl;
  late Animation<double> _blobScale;

  // Cancel button press
  bool _cancelPressed = false;

  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _remaining = widget.seconds;

    // ── Ring pulse ──────────────────────────────────────────────────────────
    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 1.0,
      end: 1.06,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // ── Blob rotation (slow, 8 s per turn) ─────────────────────────────────
    _rotateCtrl = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
    _rotation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(parent: _rotateCtrl, curve: Curves.linear));

    // ── Blob breathe ────────────────────────────────────────────────────────
    _blobCtrl = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    )..repeat(reverse: true);
    _blobScale = Tween<double>(
      begin: 0.88,
      end: 1.12,
    ).animate(CurvedAnimation(parent: _blobCtrl, curve: Curves.easeInOut));

    _startVoiceAlert();
    _startCountdown();
  }

  Future<void> _startVoiceAlert() async {
    await _tts.setLanguage('en-IN');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.speak(
      'Accident detected. SOS will be triggered in 10 seconds. '
      'Tap Cancel if you are safe.',
    );
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _remaining--);
      HapticFeedback.mediumImpact();
      if (_remaining <= 0) {
        t.cancel();
        _triggerSOS();
      }
    });
  }

  void _triggerSOS() {
    if (!mounted || _cancelled) return;
    _tts.stop();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const SOSActiveScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _cancel() {
    _cancelled = true;
    _timer?.cancel();
    _tts.stop();
    _tts.speak('Okay. Stay safe.');
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    _rotateCtrl.dispose();
    _blobCtrl.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _remaining / widget.seconds;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0000),
      body: Stack(
        children: [
          // ── Full-screen dark vignette texture ─────────────────────────────
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [const Color(0xFF2A0800), const Color(0xFF0F0000)],
                ),
              ),
            ),
          ),

          // ── Rotating + pulsing fire blob ──────────────────────────────────
          Positioned(
            top: size.height * 0.28,
            left: size.width * 0.5 - 140,
            child: AnimatedBuilder(
              animation: Listenable.merge([_rotation, _blobScale]),
              builder: (_, __) => Transform.scale(
                scale: _blobScale.value,
                child: Transform.rotate(
                  angle: _rotation.value,
                  child: SizedBox(
                    width: 280,
                    height: 280,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer glow blob
                        Container(
                          width: 280,
                          height: 240,
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                _amber.withValues(alpha: 0.28),
                                _orange.withValues(alpha: 0.18),
                                _red.withValues(alpha: 0.10),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.4, 0.7, 1.0],
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.elliptical(140, 100),
                              topRight: Radius.elliptical(80, 140),
                              bottomLeft: Radius.elliptical(100, 80),
                              bottomRight: Radius.elliptical(130, 110),
                            ),
                          ),
                        ),
                        // Inner hot core
                        Container(
                          width: 180,
                          height: 160,
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                _yellow.withValues(alpha: 0.20),
                                _amber.withValues(alpha: 0.22),
                                _orange.withValues(alpha: 0.16),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.35, 0.65, 1.0],
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.elliptical(90, 70),
                              topRight: Radius.elliptical(60, 90),
                              bottomLeft: Radius.elliptical(80, 60),
                              bottomRight: Radius.elliptical(70, 80),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Main content ──────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const SizedBox(height: 40),

                  // ── CRASH DETECTED badge ─────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _red.withValues(alpha: 0.25),
                          _orange.withValues(alpha: 0.15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _orange.withValues(alpha: 0.45),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: _amber,
                          size: 15,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'CRASH DETECTED',
                          style: GoogleFonts.bebasNeue(
                            fontSize: 15,
                            letterSpacing: 2.5,
                            color: _amber,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Title ────────────────────────────────────────────────
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [_white, Color(0xFFFFCCBB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: Text(
                      widget.title,
                      style: GoogleFonts.bebasNeue(
                        fontSize: 44,
                        letterSpacing: 2,
                        color: _white,
                        height: 1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    widget.subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: _white.withValues(alpha:0.55),
                      height: 1.65,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const Spacer(),

                  // ── Countdown ring ───────────────────────────────────────
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, child) =>
                        Transform.scale(scale: _pulse.value, child: child),
                    child: SizedBox(
                      width: 210,
                      height: 210,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // ── BIG PULSING GLOW BEHIND RING ─────────────────────
                          AnimatedBuilder(
                            animation: _pulse,
                            builder: (_, __) => Transform.scale(
                              scale: _pulse.value * 1.15,
                              child: Container(
                                width: 260,
                                height: 260,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      _amber.withValues(alpha: 0.22),
                                      _orange.withValues(alpha: 0.16),
                                      _red.withValues(alpha: 0.10),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.15, 0.45, 0.72, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Soft outer halo
                          Container(
                            width: 240,
                            height: 240,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _orange.withValues(alpha: 0.18),
                                  blurRadius: 45,
                                  spreadRadius: 10,
                                ),
                                BoxShadow(
                                  color: _red.withValues(alpha: 0.12),
                                  blurRadius: 70,
                                  spreadRadius: 18,
                                ),
                              ],
                            ),
                          ),

                          // ── Gradient countdown ring ──────────────────────────
                          SizedBox.expand(
                            child: CustomPaint(
                              painter: _GradientArcPainter(
                                progress: progress,
                                strokeWidth: 11,
                                gradientColors: _fireGradient,
                                trackColor: _red.withValues(alpha: 0.12),
                              ),
                            ),
                          ),

                          // ── Countdown number ─────────────────────────────────
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                      colors: [_white, _amber],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ).createShader(bounds),
                                child: Text(
                                  '$_remaining',
                                  style: GoogleFonts.bebasNeue(
                                    fontSize: 90,
                                    color: _white,
                                    height: 1,
                                  ),
                                ),
                              ),
                              Text(
                                'SECONDS',
                                style: GoogleFonts.bebasNeue(
                                  fontSize: 13,
                                  letterSpacing: 3,
                                  color: _white.withValues(alpha:0.45),
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // ── I'm Safe — Cancel button ─────────────────────────────
                  GestureDetector(
                    onTapDown: (_) => setState(() => _cancelPressed = true),
                    onTapUp: (_) {
                      setState(() => _cancelPressed = false);
                      _cancel();
                    },
                    onTapCancel: () => setState(() => _cancelPressed = false),
                    child: AnimatedScale(
                      scale: _cancelPressed ? 0.96 : 1.0,
                      duration: const Duration(milliseconds: 100),
                      child: Container(
                        width: double.infinity,
                        height: 60,
                        decoration: BoxDecoration(
                          color: _white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: _orange.withValues(alpha:0.20),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                      colors: [_red, _orange],
                                    ).createShader(bounds),
                                child: const Icon(
                                  Icons.check_circle_rounded,
                                  color: _white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ShaderMask(
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                      colors: [_red, _orange],
                                    ).createShader(bounds),
                                child: Text(
                                  "I'm Safe — Cancel SOS",
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: _white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Send SOS Now ─────────────────────────────────────────
                  GestureDetector(
                    onTap: _triggerSOS,
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_red, _orange],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: _red.withValues(alpha:0.40),
                            blurRadius: 16,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.emergency_rounded,
                              color: _white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Send SOS Now',
                              style: GoogleFonts.bebasNeue(
                                fontSize: 18,
                                letterSpacing: 2,
                                color: _white,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Gradient Arc Painter ───────────────────────────────────────────────────────
// Draws a circular progress ring with a multi-stop gradient stroke.
class _GradientArcPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final List<Color> gradientColors;
  final Color trackColor;

  _GradientArcPainter({
    required this.progress,
    required this.strokeWidth,
    required this.gradientColors,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track (background ring)
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    // Gradient sweep
    final sweepAngle = 2 * math.pi * progress;
    final gradientPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + sweepAngle,
        colors: gradientColors,
        tileMode: TileMode.clamp,
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, gradientPaint);

    // Glowing tip dot at the leading edge
    final tipAngle = -math.pi / 2 + sweepAngle;
    final tipX = center.dx + radius * math.cos(tipAngle);
    final tipY = center.dy + radius * math.sin(tipAngle);

    // Glow halo
    canvas.drawCircle(
      Offset(tipX, tipY),
      strokeWidth * 0.9,
      Paint()
        ..color = _amber.withValues(alpha:0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // Bright tip
    canvas.drawCircle(
      Offset(tipX, tipY),
      strokeWidth * 0.42,
      Paint()..color = _yellow,
    );
  }

  @override
  bool shouldRepaint(_GradientArcPainter old) => old.progress != progress;
}
