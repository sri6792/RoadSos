// lib/screens/splash_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'main_shell.dart';
import 'login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Palette ────────────────────────────────────────────────────────
  static const Color _red = Color(0xFFE83000);
  static const Color _orange = Color(0xFFFF6600);
  static const Color _amber = Color(0xFFFFAA00);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _ink = Color(0xFF1A1A1A);

  // ── Controllers ───────────────────────────────────────────────────
  late final AnimationController _entryCtrl;
  late final AnimationController _floatA; // 7 s
  late final AnimationController _floatB; // 9 s
  late final AnimationController _floatC; // 11 s
  late final AnimationController _floatD; // 8.5 s
  late final AnimationController _progressCtrl;

  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    // Entry fade + scale
    _entryCtrl = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..forward();
    _fade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _scale = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));

    // Aurora float loops — staggered delays so they never sync
    _floatA = AnimationController(
      duration: const Duration(milliseconds: 7000),
      vsync: this,
    )..repeat(reverse: true);

    _floatB = AnimationController(
      duration: const Duration(milliseconds: 9000),
      vsync: this,
    );
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _floatB.repeat(reverse: true);
    });

    _floatC = AnimationController(
      duration: const Duration(milliseconds: 11000),
      vsync: this,
    );
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) _floatC.repeat(reverse: true);
    });

    _floatD = AnimationController(
      duration: const Duration(milliseconds: 8500),
      vsync: this,
    );
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _floatD.repeat(reverse: true);
    });

    // Progress bar
    _progressCtrl = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    );
    _progress = CurvedAnimation(parent: _progressCtrl, curve: Curves.easeInOut);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _progressCtrl.forward();
    });

    // Navigate at 3 s
    Timer(const Duration(milliseconds: 3000), _navigate);
  }

  Future<void> _navigate() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final stayLoggedIn = prefs.getBool('stay_logged_in') ?? false;
    if (stayLoggedIn && FirebaseAuth.instance.currentUser != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _floatA.dispose();
    _floatB.dispose();
    _floatC.dispose();
    _floatD.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  // ── Floating aurora blob ──────────────────────────────────────────
  //
  // Each blob is a heavily blurred ellipse that drifts slowly.
  // [ctrl] drives translate + scale; [phase] offsets where in the
  // animation each blob starts so they never move in lockstep.
  Widget _blob({
    required AnimationController ctrl,
    required double width,
    required double height,
    required Alignment gradientCenter,
    required List<Color> colors,
    required Offset txRange, // (min, max) x translate
    required Offset tyRange, // (min, max) y translate
    double scaleMin = 1.0,
    double scaleMax = 1.06,
    double opacityMin = 0.80,
    double opacityMax = 1.0,
  }) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final t = ctrl.value;
        final tx = txRange.dx + (txRange.dy - txRange.dx) * t;
        final ty = tyRange.dx + (tyRange.dy - tyRange.dx) * t;
        final sc = scaleMin + (scaleMax - scaleMin) * t;
        final op = opacityMin + (opacityMax - opacityMin) * t;
        return Opacity(
          opacity: op,
          child: Transform.translate(
            offset: Offset(tx, ty),
            child: Transform.scale(
              scale: sc,
              child: ImageFiltered(
                imageFilter: ColorFilter.matrix(<double>[
                  1,
                  0,
                  0,
                  0,
                  0,
                  0,
                  1,
                  0,
                  0,
                  0,
                  0,
                  0,
                  1,
                  0,
                  0,
                  0,
                  0,
                  0,
                  1,
                  0,
                ]),
                child: Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(height),
                    gradient: RadialGradient(
                      center: gradientCenter,
                      radius: 1.0,
                      colors: colors,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Aurora zone (top or bottom) ───────────────────────────────────
  //
  // Stacks 4 blobs inside a ClipRect so they don't bleed outside
  // their zone. BackdropFilter gives the feathered-into-white edge.
  Widget _auroraZone({required bool isTop, required double zoneHeight}) {
    final screenW = MediaQuery.of(context).size.width;

    Widget zone = SizedBox(
      width: double.infinity,
      height: zoneHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Blob 1 — large, anchored to edge
          Positioned(
            top: isTop ? -zoneHeight * 0.35 : null,
            bottom: isTop ? null : -zoneHeight * 0.35,
            left: -screenW * 0.15,
            child: ImageFiltered(
              imageFilter: _blurFilter(52),
              child: _blobShape(
                width: screenW * 1.30,
                height: zoneHeight * 0.90,
                ctrl: _floatA,
                center: const Alignment(0, 0.4),
                colors: [
                  _red.withValues(alpha: 0.55),
                  _orange.withValues(alpha: 0.30),
                  Colors.transparent,
                ],
                txMin: 0,
                txMax: 14,
                tyMin: 0,
                tyMax: isTop ? 10 : -10,
              ),
            ),
          ),
          // Blob 2 — medium, offset left
          Positioned(
            top: isTop ? -zoneHeight * 0.10 : null,
            bottom: isTop ? null : -zoneHeight * 0.10,
            left: 0,
            child: ImageFiltered(
              imageFilter: _blurFilter(44),
              child: _blobShape(
                width: screenW * 1.0,
                height: zoneHeight * 0.72,
                ctrl: _floatB,
                center: const Alignment(-0.2, 0.5),
                colors: [
                  _orange.withValues(alpha: 0.38),
                  _amber.withValues(alpha: 0.20),
                  Colors.transparent,
                ],
                txMin: -14,
                txMax: 0,
                tyMin: 0,
                tyMax: isTop ? 6 : -6,
              ),
            ),
          ),
          // Blob 3 — smaller, offset right, amber tinted
          Positioned(
            top: isTop ? zoneHeight * 0.18 : null,
            bottom: isTop ? null : zoneHeight * 0.18,
            left: screenW * 0.10,
            child: ImageFiltered(
              imageFilter: _blurFilter(38),
              child: _blobShape(
                width: screenW * 0.80,
                height: zoneHeight * 0.55,
                ctrl: _floatC,
                center: const Alignment(0.3, 0.3),
                colors: [
                  _amber.withValues(alpha: 0.22),
                  _orange.withValues(alpha: 0.12),
                  Colors.transparent,
                ],
                txMin: 0,
                txMax: -12,
                tyMin: isTop ? -8 : 8,
                tyMax: 0,
              ),
            ),
          ),
          // Blob 4 — concentrated red core, right-centre
          Positioned(
            top: isTop ? zoneHeight * 0.05 : null,
            bottom: isTop ? null : zoneHeight * 0.05,
            left: screenW * 0.30,
            child: ImageFiltered(
              imageFilter: _blurFilter(46),
              child: _blobShape(
                width: screenW * 0.60,
                height: zoneHeight * 0.68,
                ctrl: _floatD,
                center: const Alignment(0, 0.4),
                colors: [_red.withValues(alpha: 0.28), Colors.transparent],
                txMin: 0,
                txMax: 10,
                tyMin: 0,
                tyMax: isTop ? 8 : -8,
              ),
            ),
          ),
        ],
      ),
    );

    // Feather the inner edge so it dissolves into white cleanly
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => LinearGradient(
        begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
        end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
        colors: [Colors.white, Colors.white, Colors.transparent],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect),
      child: zone,
    );
  }

  // Small helpers to reduce duplication
  ImageFilter _blurFilter(double sigma) =>
      ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);

  Widget _blobShape({
    required double width,
    required double height,
    required AnimationController ctrl,
    required Alignment center,
    required List<Color> colors,
    required double txMin,
    required double txMax,
    required double tyMin,
    required double tyMax,
  }) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final t = ctrl.value;
        return Transform.translate(
          offset: Offset(
            txMin + (txMax - txMin) * t,
            tyMin + (tyMax - tyMin) * t,
          ),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height),
              gradient: RadialGradient(
                center: center,
                radius: 1.0,
                colors: colors,
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final auroraH = size.height * 0.38;

    return Scaffold(
      backgroundColor: _white,
      body: Stack(
        children: [
          // ── TOP AURORA ───────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: auroraH,
            child: _auroraZone(isTop: true, zoneHeight: auroraH),
          ),

          // ── BOTTOM AURORA ────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: auroraH,
            child: _auroraZone(isTop: false, zoneHeight: auroraH),
          ),

          // ── CONTENT ──────────────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  children: [
                    const Spacer(),

                    // Icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_red, _orange, _amber],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _red.withValues(alpha: 0.28),
                            blurRadius: 28,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: _orange.withValues(alpha: 0.15),
                            blurRadius: 50,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.emergency_rounded,
                        color: _white,
                        size: 40,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Wordmark: ROAD (black) + SOS (gradient)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          'ROAD',
                          style: GoogleFonts.bebasNeue(
                            fontSize: 68,
                            letterSpacing: 5,
                            color: _ink,
                            height: 1,
                          ),
                        ),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [_red, _orange, _amber],
                          ).createShader(bounds),
                          child: Text(
                            'SOS',
                            style: GoogleFonts.bebasNeue(
                              fontSize: 68,
                              letterSpacing: 5,
                              color: _white,
                              height: 1,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Sub-heading
                    Text(
                      'HELP ALWAYS READY',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF999999),
                        letterSpacing: 3.5,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Tagline
                    Text(
                      'Emergency assistance at your fingertips',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w300,
                        color: const Color(0xFFBBBBBB),
                        letterSpacing: 0.2,
                      ),
                    ),

                    const Spacer(),

                    // Progress bar + footer
                    Padding(
                      padding: const EdgeInsets.fromLTRB(36, 0, 36, 44),
                      child: Column(
                        children: [
                          // Progress track
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: AnimatedBuilder(
                              animation: _progress,
                              builder: (_, __) => Stack(
                                children: [
                                  Container(
                                    height: 2,
                                    color: _red.withValues(alpha: 0.10),
                                  ),
                                  FractionallySizedBox(
                                    widthFactor: _progress.value,
                                    child: Container(
                                      height: 2,
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [_red, _orange, _amber],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Connecting to services…',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xFFFFFFFF),
                                  letterSpacing: 0.3,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'v2.1.0',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xFFFFFFFF),
                                  letterSpacing: 0.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
