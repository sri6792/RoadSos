// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../services/app_state.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import '../services/responder_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Palette (matches home_screen) ────────────────────────────────────────────
const Color _red = Color(0xFFE83000);
const Color _orange = Color(0xFFFF6600);
const Color _white = Color(0xFFFFFFFF);
const Color _ink = Color(0xFF1A1A1A);
const Color _success = Color(0xFF22C55E);
const Color _info = Color(0xFF3B82F6);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isFirstResponder = false;
  bool _savingResponder = false;

  String _name = '';
  String _bloodGroup = '';
  String _allergies = '';
  String _conditions = '';
  String _vehicle = '';
  String _registration = '';

  @override
  void initState() {
    super.initState();
    _isFirstResponder = AppState.instance.isFirstResponder;
    _name = AppState.instance.userName;
    _bloodGroup = AppState.instance.bloodGroup;
    _allergies = AppState.instance.allergies;
    _conditions = AppState.instance.conditions;
    _vehicle = AppState.instance.vehicle;
    _registration = AppState.instance.registration;
  }

  void _showEditSheet() {
    final nameCtrl = TextEditingController(text: _name);
    final bloodCtrl = TextEditingController(text: _bloodGroup);
    final allergyCtrl = TextEditingController(text: _allergies);
    final condCtrl = TextEditingController(text: _conditions);
    final vehicleCtrl = TextEditingController(text: _vehicle);
    final regCtrl = TextEditingController(text: _registration);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E5E5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Container(
                    width: 3,
                    height: 22,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_red, _orange],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Edit Profile',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 26,
                      letterSpacing: 1.5,
                      color: _ink,
                      height: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _EditField(
                label: 'Full Name',
                ctrl: nameCtrl,
                icon: Icons.person_rounded,
              ),
              const SizedBox(height: 12),
              _EditField(
                label: 'Blood Group',
                ctrl: bloodCtrl,
                icon: Icons.bloodtype_rounded,
                hint: 'e.g. B+, O-, AB+',
              ),
              const SizedBox(height: 12),
              _EditField(
                label: 'Allergies',
                ctrl: allergyCtrl,
                icon: Icons.warning_amber_rounded,
                hint: 'e.g. Penicillin, Pollen',
              ),
              const SizedBox(height: 12),
              _EditField(
                label: 'Medical Conditions',
                ctrl: condCtrl,
                icon: Icons.monitor_heart_rounded,
                hint: 'e.g. Mild Asthma',
              ),
              const SizedBox(height: 18),

              // Section divider
              Row(
                children: [
                  const Icon(
                    Icons.directions_car_rounded,
                    size: 14,
                    color: Color(0xFF888888),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Vehicle Info',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF888888),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Divider(color: const Color(0xFFEEEEEE), height: 1),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _EditField(
                label: 'Vehicle',
                ctrl: vehicleCtrl,
                icon: Icons.directions_car_rounded,
                hint: 'e.g. Honda City - White',
              ),
              const SizedBox(height: 12),
              _EditField(
                label: 'Registration Number',
                ctrl: regCtrl,
                icon: Icons.confirmation_number_rounded,
                hint: 'e.g. MH 01 AB 1234',
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    AppState.instance.userName = nameCtrl.text.trim();
                    AppState.instance.bloodGroup = bloodCtrl.text.trim();
                    AppState.instance.allergies = allergyCtrl.text.trim();
                    AppState.instance.conditions = condCtrl.text.trim();
                    AppState.instance.vehicle = vehicleCtrl.text.trim();
                    AppState.instance.registration = regCtrl.text.trim();
                    AuthService.instance.loginWithPhone(
                      nameCtrl.text.trim().isNotEmpty
                          ? nameCtrl.text.trim()
                          : _name,
                    );
                    setState(() {
                      _name = AppState.instance.userName;
                      _bloodGroup = AppState.instance.bloodGroup;
                      _allergies = AppState.instance.allergies;
                      _conditions = AppState.instance.conditions;
                      _vehicle = AppState.instance.vehicle;
                      _registration = AppState.instance.registration;
                    });
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: _white,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Profile updated!',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: _success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _red,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Save Changes',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleFirstResponder(bool value) async {
    setState(() {
      _savingResponder = true;
      _isFirstResponder = value;
    });
    AppState.instance.isFirstResponder = value;

    if (value) {
      try {
        final perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied ||
            perm == LocationPermission.deniedForever) {
          await Geolocator.requestPermission();
        }
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        AppState.instance.lastLat = pos.latitude;
        AppState.instance.lastLng = pos.longitude;
        await ResponderService.instance.registerAsResponder(
          lat: pos.latitude,
          lng: pos.longitude,
          name: AppState.instance.userName,
          available: true,
        );
        ResponderService.instance.startListeningForAlerts(
          lat: pos.latitude,
          lng: pos.longitude,
        );
      } catch (e) {
        debugPrint('Responder location error: $e');
      }
    } else {
      await ResponderService.instance.registerAsResponder(
        lat: AppState.instance.lastLat ?? 0,
        lng: AppState.instance.lastLng ?? 0,
        name: AppState.instance.userName,
        available: false,
      );
      ResponderService.instance.stopListeningForAlerts();
    }

    setState(() => _savingResponder = false);

    if (value && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.volunteer_activism_rounded,
                color: _white,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You are now a Golden Hour Responder!',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: _success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final pad = (size.width * 0.055).clamp(16.0, 28.0);
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final name =
        firebaseUser?.displayName ??
        firebaseUser?.email?.split('@').first ??
        _name;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Header ─────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: _white,
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(pad, 16, pad, 0),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MY',
                                style: GoogleFonts.bebasNeue(
                                  fontSize: 26,
                                  letterSpacing: 1.5,
                                  color: _ink,
                                  height: 1,
                                ),
                              ),
                              Text(
                                'PROFILE',
                                style: GoogleFonts.bebasNeue(
                                  fontSize: 26,
                                  letterSpacing: 1.5,
                                  color: _red,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: _showEditSheet,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE5E5E5),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.edit_outlined,
                                    size: 14,
                                    color: _ink,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Edit',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Profile card ──────────────────────────────────────────
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: pad),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _ink,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: _ink.withValues(alpha: 0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Avatar
                            Container(
                              width: 62,
                              height: 62,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [_red, _orange],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: _red.withValues(alpha: 0.4),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  initial,
                                  style: GoogleFonts.bebasNeue(
                                    fontSize: 32,
                                    letterSpacing: 1,
                                    color: _white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name.isEmpty ? 'RoadSOS User' : name,
                                    style: GoogleFonts.inter(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: _white,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'RoadSOS Member',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: _white.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  // Badge
                                  _isFirstResponder
                                      ? _ProfileBadge(
                                          icon:
                                              Icons.volunteer_activism_rounded,
                                          label: 'Golden Hour Responder',
                                          color: _success,
                                        )
                                      : _ProfileBadge(
                                          icon: Icons.bloodtype_rounded,
                                          label: _bloodGroup.isEmpty
                                              ? 'No Blood Group Added'
                                              : 'Blood: $_bloodGroup',
                                          color: _red,
                                        ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),

          // ── Body ───────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(pad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Section header ──────────────────────────────────────────
                  _SectionHeader(title: 'First Responder'),
                  const SizedBox(height: 10),

                  // ── Golden Hour Card ────────────────────────────────────────
                  _GoldenHourCard(
                    isActive: _isFirstResponder,
                    isSaving: _savingResponder,
                    onToggle: _toggleFirstResponder,
                  ),

                  const SizedBox(height: 18),
                  _SectionHeader(title: 'Medical Info'),
                  const SizedBox(height: 10),

                  // ── Medical Info ────────────────────────────────────────────
                  _ProfileSection(
                    icon: Icons.medical_information_rounded,
                    color: _red,
                    children: [
                      _InfoRow(
                        label: 'Blood Group',
                        value: _bloodGroup.isEmpty ? 'Not Added' : _bloodGroup,
                        icon: Icons.bloodtype_rounded,
                        iconColor: _red,
                      ),
                      _Divider(),
                      _InfoRow(
                        label: 'Allergies',
                        value: _allergies.isEmpty ? 'Not Added' : _allergies,
                        icon: Icons.warning_amber_rounded,
                        iconColor: _orange,
                      ),
                      _Divider(),
                      _InfoRow(
                        label: 'Conditions',
                        value: _conditions.isEmpty ? 'Not Added' : _conditions,
                        icon: Icons.monitor_heart_rounded,
                        iconColor: _info,
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),
                  _SectionHeader(title: 'Vehicle Info'),
                  const SizedBox(height: 10),

                  // ── Vehicle Info ────────────────────────────────────────────
                  _ProfileSection(
                    icon: Icons.directions_car_rounded,
                    color: _info,
                    children: [
                      _InfoRow(
                        label: 'Vehicle',
                        value: _vehicle.isEmpty ? 'Not Added' : _vehicle,
                        icon: Icons.directions_car_filled_rounded,
                        iconColor: _info,
                      ),
                      _Divider(),
                      _InfoRow(
                        label: 'Registration',
                        value: _registration.isEmpty
                            ? 'Not Added'
                            : _registration,
                        icon: Icons.confirmation_number_rounded,
                        iconColor: _orange,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Sign Out ────────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            title: Text(
                              'Sign Out?',
                              style: GoogleFonts.bebasNeue(
                                fontSize: 24,
                                letterSpacing: 1,
                                color: _ink,
                              ),
                            ),
                            content: Text(
                              'You will need to sign in again to access your emergency contacts and profile.',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: const Color(0xFF888888),
                                height: 1.5,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text(
                                  'Cancel',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF888888),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _red,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Sign Out',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    color: _white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && mounted) {
                          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('stay_logged_in', false);
          await AuthService.instance.logout();
                          if (!mounted) return;
                          // profile_screen.dart — in the sign out onPressed, replace pushAndRemoveUntil with:
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(hideSkip: true),
                            ),
                          );
                        }
                      },
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: Color(0xFFAAAAAA),
                        size: 17,
                      ),
                      label: Text(
                        'Sign Out',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF888888),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE5E5E5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 90),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Profile Badge ─────────────────────────────────────────────────────────────
class _ProfileBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _ProfileBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Header (matches home_screen style) ────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_red, _orange],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.bebasNeue(
            fontSize: 18,
            letterSpacing: 1.5,
            color: _ink,
            height: 1,
          ),
        ),
      ],
    );
  }
}

// ── Profile Section container ─────────────────────────────────────────────────
class _ProfileSection extends StatelessWidget {
  final IconData icon;
  final Color color;
  final List<Widget> children;
  const _ProfileSection({
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(children: children),
      ),
    );
  }
}

// ── Info Row ──────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = value == 'Not Added';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF888888),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: isEmpty ? FontWeight.w400 : FontWeight.w600,
                    color: isEmpty ? const Color(0xFFCCCCCC) : _ink,
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

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const Divider(color: Color(0xFFF5F5F5), height: 1, thickness: 1);
}

// ── Golden Hour Card ──────────────────────────────────────────────────────────
class _GoldenHourCard extends StatelessWidget {
  final bool isActive;
  final bool isSaving;
  final ValueChanged<bool> onToggle;

  const _GoldenHourCard({
    required this.isActive,
    required this.isSaving,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isActive ? _success.withValues(alpha: 0.06) : _white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive
              ? _success.withValues(alpha: 0.35)
              : const Color(0xFFEEEEEE),
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: [
          if (isActive)
            BoxShadow(
              color: _success.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isActive
                        ? _success.withValues(alpha: 0.12)
                        : _red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.volunteer_activism_rounded,
                    color: isActive ? _success : _red,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Golden Hour Responder',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _ink,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _red,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              'NEW',
                              style: GoogleFonts.inter(
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                color: _white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isActive
                            ? 'You will be alerted when someone nearby needs help'
                            : 'Get alerted when someone nearby needs help',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF888888),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _success,
                        ),
                      )
                    : Switch(
                        value: isActive,
                        onChanged: onToggle,
                        activeThumbColor: _white,
                        activeTrackColor: _success,
                        inactiveThumbColor: _white,
                        inactiveTrackColor: const Color(0xFFE5E5E5),
                      ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(color: Color(0xFFF5F5F5), height: 1),
            const SizedBox(height: 12),

            if (isActive) ...[
              // Active state
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _StatChip(
                    icon: Icons.radar_rounded,
                    label: 'Monitoring 500m',
                    color: _success,
                  ),
                  _StatChip(
                    icon: Icons.notifications_active_rounded,
                    label: 'Alerts ON',
                    color: _info,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _success.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: Color(0xFF888888),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'If someone triggers SOS nearby, you\'ll receive an instant alert with their location and medical info.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF888888),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Inactive: why become a responder
              Text(
                'Why become a responder?',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 8),
              _BulletPoint('50% of accident deaths happen in the first hour'),
              _BulletPoint('Ambulances average 20+ min in Indian cities'),
              _BulletPoint('You could save a life in just 2 minutes'),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final String text;
  const _BulletPoint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _red.withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF888888),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Edit field ────────────────────────────────────────────────────────────────
class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final IconData icon;
  final String hint;

  const _EditField({
    required this.label,
    required this.ctrl,
    required this.icon,
    this.hint = '',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF888888),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          style: GoogleFonts.inter(fontSize: 14, color: _ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFFCCCCCC),
            ),
            prefixIcon: Icon(icon, size: 17, color: const Color(0xFFAAAAAA)),
            filled: true,
            fillColor: const Color(0xFFF8F8F8),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _red, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
