// lib/screens/login_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import 'main_shell.dart';

const _webClientId =
    '728318811353-kvu3pu879p3ongmce27mnckkkc6frk9v.apps.googleusercontent.com';

// ── Palette (mirrors SplashScreen) ────────────────────────────────────────────
const Color _red = Color(0xFFE83000);
const Color _orange = Color(0xFFFF6600);
const Color _amber = Color(0xFFFFAA00);
const Color _white = Color(0xFFFFFFFF);
const Color _ink = Color(0xFF1A1A1A);

// ── Country model ──────────────────────────────────────────────────────────────
class _Country {
  final String flag;
  final String name;
  final String dialCode;
  const _Country({
    required this.flag,
    required this.name,
    required this.dialCode,
  });
}

const List<_Country> _countries = [
  _Country(flag: '🇮🇳', name: 'India', dialCode: '+91'),
  _Country(flag: '🇺🇸', name: 'United States', dialCode: '+1'),
  _Country(flag: '🇬🇧', name: 'United Kingdom', dialCode: '+44'),
  _Country(flag: '🇦🇺', name: 'Australia', dialCode: '+61'),
  _Country(flag: '🇦🇪', name: 'UAE', dialCode: '+971'),
  _Country(flag: '🇸🇬', name: 'Singapore', dialCode: '+65'),
  _Country(flag: '🇲🇾', name: 'Malaysia', dialCode: '+60'),
  _Country(flag: '🇩🇪', name: 'Germany', dialCode: '+49'),
  _Country(flag: '🇫🇷', name: 'France', dialCode: '+33'),
  _Country(flag: '🇯🇵', name: 'Japan', dialCode: '+81'),
  _Country(flag: '🇨🇳', name: 'China', dialCode: '+86'),
  _Country(flag: '🇷🇺', name: 'Russia', dialCode: '+7'),
  _Country(flag: '🇧🇷', name: 'Brazil', dialCode: '+55'),
  _Country(flag: '🇿🇦', name: 'South Africa', dialCode: '+27'),
  _Country(flag: '🇳🇬', name: 'Nigeria', dialCode: '+234'),
  _Country(flag: '🇨🇦', name: 'Canada', dialCode: '+1'),
  _Country(flag: '🇰🇷', name: 'South Korea', dialCode: '+82'),
  _Country(flag: '🇮🇩', name: 'Indonesia', dialCode: '+62'),
  _Country(flag: '🇵🇰', name: 'Pakistan', dialCode: '+92'),
  _Country(flag: '🇧🇩', name: 'Bangladesh', dialCode: '+880'),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  final bool hideSkip;
  const LoginScreen({super.key, this.hideSkip = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  // Controllers
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  late final AnimationController _entryCtrl;
  late final AnimationController _floatA;
  late final AnimationController _floatB;
  late final AnimationController _floatC;
  late final AnimationController _floatD;

  late final Animation<double> _fade;
  late final Animation<double> _scale;

  // State
  _Country _selectedCountry = _countries.first;
  bool _otpSent = false;
  bool _loading = false;
  String? _errorMsg;
  String? _verificationId;

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..forward();

    _fade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _scale = Tween<double>(
      begin: 0.96,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));

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
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _floatA.dispose();
    _floatB.dispose();
    _floatC.dispose();
    _floatD.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  Future<void> _navigateHome({bool isGuest = false}) async {
    if (isGuest) await AuthService.instance.loginAsGuest();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => MainShell(isGuest: isGuest),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  // ── Google Sign-In ──────────────────────────────────────────────────────────
  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      await GoogleSignIn.instance.initialize(serverClientId: _webClientId);

      final googleUser = await GoogleSignIn.instance.authenticate();

      final googleAuth = googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCred = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final user = userCred.user;

      await AuthService.instance.loginWithGoogle(
        name: user?.displayName ?? googleUser.displayName ?? 'User',
        email: user?.email ?? googleUser.email,
      );

      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('stay_logged_in', true);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell(isGuest: false)),
        (route) => false,
      );
    } catch (e) {
      print("GOOGLE SIGN-IN ERROR: $e");
      setState(() {
        _loading = false;
        _errorMsg = e.toString();
      });
    }
  }

  // ── Phone OTP — Send ────────────────────────────────────────────────────────
  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 6) {
      setState(() => _errorMsg = 'Enter a valid phone number');
      return;
    }
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    final fullNumber = '${_selectedCountry.dialCode}$phone';

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: fullNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        await AuthService.instance.loginWithPhone(fullNumber);
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (_, animation, __) => const MainShell(isGuest: false),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 500),
          ),
          (route) => false,
        );
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() {
          _loading = false;
          _errorMsg = e.message ?? 'Failed to send OTP. Check the number.';
        });
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _loading = false;
          _otpSent = true;
          _verificationId = verificationId;
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  // ── Phone OTP — Verify ──────────────────────────────────────────────────────
  Future<void> _verifyOtp() async {
    final otp = _otpCtrl.text.trim();
    if (_verificationId == null) {
      setState(() => _errorMsg = 'OTP not sent. Please send OTP again.');
      return;
    }
    if (otp.length != 6) {
      setState(() => _errorMsg = 'Enter the 6-digit OTP');
      return;
    }
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      await AuthService.instance.loginWithPhone(
        '${_selectedCountry.dialCode}${_phoneCtrl.text.trim()}',
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, animation, __) => const MainShell(isGuest: false),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _loading = false;
        _errorMsg = e.message ?? 'Invalid OTP. Please try again.';
      });
    }
  }

  // ── Aurora helpers ─────────────────────────────────────────────────────────
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

  Widget _auroraZone({required bool isTop, required double zoneHeight}) {
    final screenW = MediaQuery.of(context).size.width;

    final zone = SizedBox(
      width: double.infinity,
      height: zoneHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: isTop ? -zoneHeight * 0.50 : null,
            bottom: isTop ? null : -zoneHeight * 0.50,
            left: -screenW * 0.35,
            child: ImageFiltered(
              imageFilter: _blurFilter(52),
              child: _blobShape(
                width: screenW * 1.50,
                height: zoneHeight * 1.10,
                ctrl: _floatA,
                center: const Alignment(0, 0.4),
                colors: [
                  _red.withValues(alpha: 0.25),
                  _orange.withValues(alpha: 0.12),
                  Colors.transparent,
                ],
                txMin: 0,
                txMax: 20,
                tyMin: 0,
                tyMax: isTop ? 15 : -15,
              ),
            ),
          ),
          Positioned(
            top: isTop ? -zoneHeight * 0.25 : null,
            bottom: isTop ? null : -zoneHeight * 0.25,
            right: -screenW * 0.20,
            child: ImageFiltered(
              imageFilter: _blurFilter(44),
              child: _blobShape(
                width: screenW * 1.30,
                height: zoneHeight * 0.95,
                ctrl: _floatB,
                center: const Alignment(-0.2, 0.5),
                colors: [
                  _orange.withValues(alpha: 0.18),
                  _amber.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
                txMin: -20,
                txMax: 0,
                tyMin: 0,
                tyMax: isTop ? 10 : -10,
              ),
            ),
          ),
          Positioned(
            top: isTop ? zoneHeight * 0.08 : null,
            bottom: isTop ? null : zoneHeight * 0.08,
            left: -screenW * 0.25,
            child: ImageFiltered(
              imageFilter: _blurFilter(38),
              child: _blobShape(
                width: screenW * 1.20,
                height: zoneHeight * 0.85,
                ctrl: _floatC,
                center: const Alignment(0.3, 0.3),
                colors: [
                  _amber.withValues(alpha: 0.12),
                  _orange.withValues(alpha: 0.06),
                  Colors.transparent,
                ],
                txMin: 0,
                txMax: -18,
                tyMin: isTop ? -12 : 12,
                tyMax: 0,
              ),
            ),
          ),
          Positioned(
            top: isTop ? -zoneHeight * 0.15 : null,
            bottom: isTop ? null : -zoneHeight * 0.15,
            right: -screenW * 0.30,
            child: ImageFiltered(
              imageFilter: _blurFilter(46),
              child: _blobShape(
                width: screenW * 1.40,
                height: zoneHeight * 1.00,
                ctrl: _floatD,
                center: const Alignment(0, 0.4),
                colors: [_red.withValues(alpha: 0.13), Colors.transparent],
                txMin: 0,
                txMax: 16,
                tyMin: 0,
                tyMax: isTop ? 12 : -12,
              ),
            ),
          ),
        ],
      ),
    );

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

  // ── Country Picker Bottom Sheet ─────────────────────────────────────────────
  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CountryPickerSheet(
        countries: _countries,
        selected: _selectedCountry,
        onSelect: (c) {
          setState(() => _selectedCountry = c);
          Navigator.pop(context);
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final pad = (size.width * 0.06).clamp(20.0, 32.0);
    final isSmall = size.height < 680;
    final auroraH = size.height * 0.32;
    final canGoBack = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: _white,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── TOP AURORA ──────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: auroraH,
            child: _auroraZone(isTop: true, zoneHeight: auroraH),
          ),

          // ── BOTTOM AURORA ───────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: auroraH,
            child: _auroraZone(isTop: false, zoneHeight: auroraH),
          ),

          // ── CONTENT ─────────────────────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ── Header ────────────────────────────────────────
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          pad,
                          isSmall ? 20 : 32,
                          pad,
                          0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Logo row — centered, with back button on the left
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                // Back button — only when navigated from inside app
                                if (canGoBack)
                                  Positioned(
                                    left: 0,
                                    child: GestureDetector(
                                      onTap: () => Navigator.of(context).pop(),
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: _white.withValues(alpha: 0.85),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFE5E5E5),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha:
                                                0.06,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.arrow_back_rounded,
                                          color: _ink,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),

                                // Logo — always centered
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(15),
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [_red, _orange, _amber],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _red.withValues(alpha:0.30),
                                            blurRadius: 20,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.emergency_rounded,
                                        color: _white,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          'ROAD',
                                          style: GoogleFonts.bebasNeue(
                                            fontSize: isSmall ? 38 : 44,
                                            letterSpacing: 3,
                                            color: _ink,
                                            height: 1,
                                          ),
                                        ),
                                        ShaderMask(
                                          shaderCallback: (bounds) =>
                                              const LinearGradient(
                                                colors: [_red, _orange, _amber],
                                              ).createShader(bounds),
                                          child: Text(
                                            'SOS',
                                            style: GoogleFonts.bebasNeue(
                                              fontSize: isSmall ? 38 : 44,
                                              letterSpacing: 2.5,
                                              color: _white,
                                              height: 1,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            SizedBox(height: isSmall ? 12 : 16),
                            Text(
                              'HELP ALWAYS READY',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFCC2200),
                                letterSpacing: 3.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sign in to save your emergency contacts\nand get faster help when it matters.',
                              style: GoogleFonts.inter(
                                fontSize: isSmall ? 13 : 14,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF555555),
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: isSmall ? 20 : 28),

                      // Thin gradient rule
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: pad),
                        child: Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                _red.withValues(alpha: 0.18),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: isSmall ? 20 : 28),

                      // ── Form ──────────────────────────────────────────
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: pad),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Error banner
                            if (_errorMsg != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: _red.withValues(alpha: 0.07),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _red.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline_rounded,
                                      color: _red,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMsg!,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: _red,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Google button
                            _GoogleSignInButton(
                              onTap: _loading ? null : _signInWithGoogle,
                              loading: _loading && !_otpSent,
                            ),
                            const SizedBox(height: 20),

                            // Divider
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: const Color(0xFFEEEEEE),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  child: Text(
                                    'or use phone',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xFF777777),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: const Color(0xFFEEEEEE),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            Text(
                              'Mobile Number',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _ink,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Phone row: country selector + input
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: _otpSent ? null : _showCountryPicker,
                                  child: Container(
                                    height: 54,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFAFAFA),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: const Color(0xFFE5E5E5),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _selectedCountry.flag,
                                          style: const TextStyle(fontSize: 20),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _selectedCountry.dialCode,
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: _ink,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          size: 18,
                                          color: _otpSent
                                              ? const Color(0xFFCCCCCC)
                                              : const Color(0xFF999999),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                Expanded(
                                  child: TextField(
                                    controller: _phoneCtrl,
                                    keyboardType: TextInputType.phone,
                                    enabled: !_otpSent,
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      color: _ink,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: '98765 43210',
                                      hintStyle: GoogleFonts.inter(
                                        color: const Color(0xFFCCCCCC),
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFFFAFAFA),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 16,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFE5E5E5),
                                          width: 1.5,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFE5E5E5),
                                          width: 1.5,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                          color: _orange,
                                          width: 1.5,
                                        ),
                                      ),
                                      disabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFEEEEEE),
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // OTP field — animated
                            AnimatedSize(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              child: _otpSent
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 16),
                                        Row(
                                          children: [
                                            Text(
                                              'Enter OTP',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: _ink,
                                                letterSpacing: 0.4,
                                              ),
                                            ),
                                            const Spacer(),
                                            TextButton(
                                              onPressed: () => setState(() {
                                                _otpSent = false;
                                                _otpCtrl.clear();
                                                _errorMsg = null;
                                              }),
                                              style: TextButton.styleFrom(
                                                foregroundColor: _red,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                    ),
                                                minimumSize: Size.zero,
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                              child: Text(
                                                'Change number',
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color: _red,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        TextField(
                                          controller: _otpCtrl,
                                          keyboardType: TextInputType.number,
                                          maxLength: 6,
                                          autofocus: true,
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.bebasNeue(
                                            fontSize: 32,
                                            letterSpacing: 14,
                                            color: _ink,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: '• • • • • •',
                                            hintStyle: GoogleFonts.inter(
                                              fontSize: 20,
                                              letterSpacing: 10,
                                              color: const Color(0xFFCCCCCC),
                                            ),
                                            counterText: '',
                                            filled: true,
                                            fillColor: const Color(0xFFFAFAFA),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 16,
                                                ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              borderSide: const BorderSide(
                                                color: Color(0xFFE5E5E5),
                                                width: 1.5,
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              borderSide: const BorderSide(
                                                color: Color(0xFFE5E5E5),
                                                width: 1.5,
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              borderSide: const BorderSide(
                                                color: _orange,
                                                width: 1.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'OTP sent to ${_selectedCountry.dialCode} ${_phoneCtrl.text}',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: const Color(0xFF666666),
                                          ),
                                        ),
                                      ],
                                    )
                                  : const SizedBox.shrink(),
                            ),

                            const SizedBox(height: 20),

                            // Send OTP / Verify button
                            _GradientButton(
                              label: _otpSent
                                  ? 'Verify & Continue'
                                  : 'Send OTP',
                              loading: _loading,
                              onTap: _loading
                                  ? null
                                  : () => _otpSent ? _verifyOtp() : _sendOtp(),
                            ),

                            const SizedBox(height: 12),

                            // Skip if urgent — only when not navigated from inside app
                            if (!widget.hideSkip) ...[
                              Center(
                                child: Text(
                                  'SKIP IF URGENT',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFCC2200),
                                    letterSpacing: 2.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ).paddingSymmetric(vertical: 8),
                              _GlowBorderSkipButton(
                                onTap: () => _navigateHome(isGuest: true),
                              ),
                            ],

                            const SizedBox(height: 16),
                            Center(
                              child: Text(
                                'By continuing, you agree to our Terms & Privacy Policy',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                  color: const Color(0xFF777777),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Extension helper ───────────────────────────────────────────────────────────
extension on Widget {
  Widget paddingSymmetric({double vertical = 0, double horizontal = 0}) =>
      Padding(
        padding: EdgeInsets.symmetric(
          vertical: vertical,
          horizontal: horizontal,
        ),
        child: this,
      );
}

// ── Gradient primary button ────────────────────────────────────────────────────
class _GradientButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;

  const _GradientButton({
    required this.label,
    required this.loading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.65 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: _red,
            boxShadow: [
              BoxShadow(
                color: _red.withValues(alpha:0.28),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: _white,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _white,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }
}

// ── Skip button ────────────────────────────────────────────────────────────────
class _GlowBorderSkipButton extends StatelessWidget {
  final VoidCallback? onTap;
  const _GlowBorderSkipButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(colors: [_red, _orange, _amber]),
            ),
          ),
          Positioned(
            top: 2,
            left: 2,
            right: 2,
            bottom: 2,
            child: Container(
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bolt_rounded, color: _red, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Continue without signing in',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _red,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Google Sign-In button ──────────────────────────────────────────────────────
class _GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool loading;
  const _GoogleSignInButton({required this.onTap, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E5E5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            else ...[
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'G',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4285F4),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Continue with Google',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Country Picker Bottom Sheet ────────────────────────────────────────────────
class _CountryPickerSheet extends StatefulWidget {
  final List<_Country> countries;
  final _Country selected;
  final ValueChanged<_Country> onSelect;

  const _CountryPickerSheet({
    required this.countries,
    required this.selected,
    required this.onSelect,
  });

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.countries
        .where(
          (c) =>
              c.name.toLowerCase().contains(_query.toLowerCase()) ||
              c.dialCode.contains(_query),
        )
        .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFDDDDDD),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Text(
                  'Select Country',
                  style: GoogleFonts.bebasNeue(
                    fontSize: 22,
                    letterSpacing: 2,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: GoogleFonts.inter(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search country…',
                hintStyle: GoogleFonts.inter(color: const Color(0xFFCCCCCC)),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFFBBBBBB),
                  size: 20,
                ),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final c = filtered[i];
                final isSelected =
                    c.dialCode == widget.selected.dialCode &&
                    c.name == widget.selected.name;
                return ListTile(
                  leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
                  title: Text(
                    c.name,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: _ink,
                    ),
                  ),
                  trailing: Text(
                    c.dialCode,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: isSelected ? _orange : const Color(0xFF999999),
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  tileColor: isSelected
                      ? _orange.withValues(alpha: 0.05)
                      : Colors.transparent,
                  onTap: () => widget.onSelect(c),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
