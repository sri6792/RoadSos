// lib/screens/main_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'nearby_services_screen.dart';
import 'emergency_contacts_screen.dart';
import 'profile_screen.dart';
import 'sos_active_screen.dart';
import 'crash_alert_screen.dart';
import 'responder_alert_screen.dart';
import 'chatbot_screen.dart'; // ← added
import '../services/accident_detection_service.dart';
import '../services/voice_sos_service.dart';
import '../services/responder_service.dart';
import '../services/app_state.dart';
import 'login_screen.dart';

class MainShell extends StatefulWidget {
  final int initialIndex;
  final bool isGuest;

  const MainShell({super.key, this.initialIndex = 0, this.isGuest = false});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with TickerProviderStateMixin {
  late int _currentIndex;
  late AnimationController _sosCtrl;
  late Animation<double> _sosPulse;
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _screens = [
      HomeScreen(isGuest: widget.isGuest),
      const NearbyServicesScreen(),
      EmergencyContactsScreen(isGuest: widget.isGuest),
      if (!widget.isGuest) const ProfileScreen(),
    ];

    VoiceSosService.instance.onTriggered = _onVoiceSOSTriggered;
    VoiceSosService.instance.start();

    AccidentDetectionService.instance.onCrashDetected = _onCrashDetected;
    AccidentDetectionService.instance.start();

    if (!widget.isGuest && AppState.instance.isFirstResponder) {
      _startResponderListener();
    }
    ResponderService.instance.onNearbySOSAlert = _onNearbySOSAlert;

    _sosCtrl = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);
    _sosPulse = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _sosCtrl, curve: Curves.easeInOut));
  }

  Future<void> _startResponderListener() async {
    final lat = AppState.instance.lastLat;
    final lng = AppState.instance.lastLng;
    if (lat != null && lng != null) {
      ResponderService.instance.startListeningForAlerts(lat: lat, lng: lng);
    }
  }

  @override
  void dispose() {
    AccidentDetectionService.instance.stop();
    VoiceSosService.instance.stop();
    ResponderService.instance.onNearbySOSAlert = null;
    _sosCtrl.dispose();
    super.dispose();
  }

  void _onVoiceSOSTriggered() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (_) => Dialog.fullscreen(
        child: CrashAlertScreen(
          seconds: 3,
          title: 'Voice SOS Detected',
          subtitle:
          'You said "Help" or "SOS".\nSOS will be triggered in 3 seconds.',
        ),
      ),
    );
  }

  void _onCrashDetected() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (_) => const Dialog.fullscreen(child: CrashAlertScreen()),
    );
  }

  void _onNearbySOSAlert(Map<String, dynamic> alertData) {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) HapticFeedback.heavyImpact();
    });

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
          opacity: animation,
          child: ResponderAlertScreen(alertData: alertData),
        ),
        transitionDuration: const Duration(milliseconds: 350),
        fullscreenDialog: true,
      ),
    );
  }

  void _triggerSOS() {
    HapticFeedback.heavyImpact();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
        const SOSActiveScreen(),
        transitionsBuilder: (context, anim, secondaryAnimation, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _openChatbot() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            FadeTransition(opacity: animation, child: const ChatbotScreen()),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final navHeight = 68.0 + MediaQuery.of(context).padding.bottom;

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: _screens),

      // ── Chatbot FAB ──────────────────────────────────────────────
      floatingActionButton: Padding(
        // Sits just above the nav bar with a comfortable margin
        padding: EdgeInsets.only(bottom: navHeight - 48),
        child: _ChatFAB(onTap: _openChatbot),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        navHeight: navHeight,
        sosPulse: _sosPulse,
        onSOS: _triggerSOS,
        isGuest: widget.isGuest,
      ),
    );
  }
}

// ── Chat FAB widget ────────────────────────────────────────────────
class _ChatFAB extends StatefulWidget {
  final VoidCallback onTap;
  const _ChatFAB({required this.onTap});

  @override
  State<_ChatFAB> createState() => _ChatFABState();
}

class _ChatFABState extends State<_ChatFAB>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
      lowerBound: 0.0,
      upperBound: 1.0,
      value: 1.0,
    );
    _scale = Tween<double>(
      begin: 0.88,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.reverse(),
      onTapUp: (_) {
        _ctrl.forward();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.forward(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.sosRed,
            boxShadow: [
              BoxShadow(
                color: AppColors.sosRed.withValues(alpha: 0.35),
                blurRadius: 16,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.chat_rounded, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

// ── Bottom nav (unchanged) ─────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final double navHeight;
  final Animation<double> sosPulse;
  final VoidCallback onSOS;
  final bool isGuest;

  const _BottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.navHeight,
    required this.sosPulse,
    required this.onSOS,
    required this.isGuest,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    final navItems = [
      (Icons.home_rounded, Icons.home_outlined, 'Home'),
      (Icons.location_on_rounded, Icons.location_on_outlined, 'Services'),
      (Icons.contacts_rounded, Icons.contacts_outlined, 'Contacts'),
      if (isGuest)
        (Icons.login_rounded, Icons.login_outlined, 'Sign In')
      else
        (Icons.person_rounded, Icons.person_outlined, 'Profile'),
    ];

    return Container(
      height: navHeight,
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.navyDark.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: bottomPad),
            child: Row(
              children: [
                ...navItems.take(2).toList().asMap().entries.map((e) {
                  final idx = e.key;
                  final item = e.value;
                  return _NavItem(
                    icon: currentIndex == idx ? item.$1 : item.$2,
                    label: item.$3,
                    isSelected: currentIndex == idx,
                    onTap: () => onTap(idx),
                  );
                }),
                SizedBox(width: size.width * 0.18),
                ...navItems.skip(2).toList().asMap().entries.map((e) {
                  final idx = e.key + 2;
                  final item = e.value;
                  final isSignIn = isGuest && idx == 3;
                  return _NavItem(
                    icon: currentIndex == idx ? item.$1 : item.$2,
                    label: item.$3,
                    isSelected: !isSignIn && currentIndex == idx,
                    onTap: isSignIn
                        ? () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(hideSkip: true),
                      ),
                    )
                        : () => onTap(idx),
                  );
                }),
              ],
            ),
          ),

          // Floating SOS button
          Positioned(
            top: -22,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: sosPulse,
                builder: (context, snapshot) => Transform.scale(
                  scale: sosPulse.value,
                  child: GestureDetector(
                    onTap: onSOS,
                    child: Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.sosRed,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.sosRed.withValues(alpha: 0.45),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                        border: Border.all(color: AppColors.white, width: 3),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.emergency_rounded,
                            color: AppColors.white,
                            size: 20,
                          ),
                          Text(
                            'SOS',
                            style: GoogleFonts.rajdhani(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.white,
                              letterSpacing: 1,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.sosRed.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                size: 22,
                color: isSelected ? AppColors.sosRed : AppColors.midGray,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppColors.sosRed : AppColors.midGray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
