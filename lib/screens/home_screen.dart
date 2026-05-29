// lib/screens/home_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

import '../models/models.dart';
import '../secrets.dart';
import 'sos_active_screen.dart';

import 'package:url_launcher/url_launcher.dart';

import 'main_shell.dart';
import '../services/cache_service.dart';
import '../services/connectivity_service.dart';
import '../services/app_state.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const Color _red = Color(0xFFE83000);
const Color _orange = Color(0xFFFF6600);
const Color _amber = Color(0xFFFFAA00);
const Color _white = Color(0xFFFFFFFF);
const Color _ink = Color(0xFF1A1A1A);

class HomeScreen extends StatefulWidget {
  final bool isGuest;
  const HomeScreen({super.key, this.isGuest = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isOffline = false;
  bool _locationUnavailable = false;
  String _cacheLabel = '';

  Future<void> _loadCachedHospitals() async {
    final cached = CacheService.instance.getServices(ServiceType.hospital);
    if (cached.isNotEmpty) {
      setState(() {
        nearbyHospitals = cached
            .take(3)
            .map(
              (s) => {
                'name': s.name,
                'vicinity': s.address,
                'geometry': {
                  'location': {'lat': s.lat, 'lng': s.lng},
                },
              },
            )
            .toList();
        _cacheLabel = CacheService.instance.lastUpdatedLabel(
          ServiceType.hospital,
        );
        hospitalsLoading = false;
      });
    } else {
      setState(() => hospitalsLoading = false);
    }
  }

  String currentAddress = 'Getting location...';
  LatLng? currentLatLng;
  bool mapLoading = true;
  List<dynamic> nearbyHospitals = [];
  bool hospitalsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  Future<void> _openHospitalNavigation(dynamic hospital) async {
    final destLat = hospital['geometry']?['location']?['lat'];
    final destLng = hospital['geometry']?['location']?['lng'];
    if (destLat == null || destLng == null) return;

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=${currentLatLng?.latitude},${currentLatLng?.longitude}'
      '&destination=$destLat,$destLng'
      '&travelmode=driving',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _loadCurrentLocation() async {
    setState(() {
      mapLoading = true;
      hospitalsLoading = true;
      nearbyHospitals = [];
      currentAddress = 'Getting location...';
      _isOffline = false;
      _locationUnavailable = false;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        setState(() {
          currentAddress = 'Location off';
          mapLoading = false;
          _locationUnavailable = true;
          _isOffline = true;
        });
        await _loadCachedHospitals();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          currentAddress = 'Permission denied';
          mapLoading = false;
          _locationUnavailable = true;
          _isOffline = true;
        });
        await _loadCachedHospitals();
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final userLocation = LatLng(position.latitude, position.longitude);
      setState(() {
        currentLatLng = userLocation;
        mapLoading = false;
        _locationUnavailable = false;
      });

      await _loadAddress(position.latitude, position.longitude);
      await _fetchNearbyHospitals(position.latitude, position.longitude);
    } catch (e) {
      setState(() {
        currentAddress = 'Location unavailable';
        mapLoading = false;
        _locationUnavailable = true;
        _isOffline = true;
      });
      await _loadCachedHospitals();
    }
  }

  Future<void> _loadAddress(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        String area = place.subLocality?.isNotEmpty == true
            ? place.subLocality!
            : place.locality?.isNotEmpty == true
            ? place.locality!
            : place.name ?? 'Unknown';
        String state = place.administrativeArea ?? '';
        setState(() {
          currentAddress = '$area, $state';
        });
      }
    } catch (e) {
      setState(() {
        currentAddress = 'Live Location';
      });
    }
  }

  Future<void> _fetchNearbyHospitals(double lat, double lng) async {
    if (!ConnectivityService.instance.isOnline) {
      setState(() => _isOffline = true);
      await _loadCachedHospitals();
      return;
    }

    final url =
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
        '?location=$lat,$lng'
        '&rankby=distance'
        '&keyword=hospital clinic medical'
        '&key=$googleApiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List? ?? [];

        await CacheService.instance.saveFromPlacesResults(
          results,
          ServiceType.hospital,
        );

        setState(() {
          nearbyHospitals = results;
          _isOffline = false;
          _cacheLabel = '';
          hospitalsLoading = false;
        });
      } else {
        setState(() => hospitalsLoading = false);
      }
    } catch (e) {
      debugPrint('Places error: $e');
      setState(() => _isOffline = true);
      await _loadCachedHospitals();
    }
  }

  String get _greetingName {
    if (widget.isGuest) return 'Guest';
    final name = AppState.instance.userName;
    if (name.isNotEmpty) return name;
    return 'Welcome';
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final pad = (size.width * 0.055).clamp(16.0, 28.0);
    final isSmall = size.height < 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      // ── Sticky Header (always visible, never collapses) ──────────────────
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          color: _white,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: pad, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Greeting block ────────────────────────────────────
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Greeting is BIGGER — this is the prominent line
                      Text(
                        _greeting,
                        style: GoogleFonts.bebasNeue(
                          fontSize: 26,
                          letterSpacing: 1.5,
                          color: _ink,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Name is smaller / secondary
                      Text(
                        _greetingName,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF888888),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // ── Location pill ─────────────────────────────────────
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE5E5E5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _locationUnavailable
                                ? Icons.location_off_rounded
                                : Icons.location_on_rounded,
                            size: 14,
                            color: _locationUnavailable
                                ? const Color(0xFFAAAAAA)
                                : _red,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              currentAddress,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Offline / location-off banner ──────────────────────────────
          SliverToBoxAdapter(
            child: ValueListenableBuilder<bool>(
              valueListenable: ConnectivityService.instance.notifier,
              builder: (context, isOnline, _) {
                final showBanner = !isOnline || _isOffline;
                if (!showBanner) return const SizedBox.shrink();

                final isLocOff = _locationUnavailable;

                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFCA28)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isLocOff
                            ? Icons.location_off_rounded
                            : Icons.wifi_off_rounded,
                        color: const Color(0xFF7B5800),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isLocOff && !isOnline
                                  ? 'Offline & location unavailable'
                                  : isLocOff
                                  ? 'Location is turned off'
                                  : 'You are offline',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF7B5800),
                              ),
                            ),
                            Text(
                              _cacheLabel.isNotEmpty
                                  ? 'Showing cached data · Updated $_cacheLabel'
                                  : isLocOff
                                  ? 'Enable location for live nearby services'
                                  : 'Connect to internet for live data',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF7B5800),
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _loadCurrentLocation,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF7B5800,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Retry',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF7B5800),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: pad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: isSmall ? 14 : 18),

                  // ── SOS Card ─────────────────────────────────────────
                  _SOSCard(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SOSActiveScreen(),
                        ),
                      );
                    },
                  ),

                  SizedBox(height: isSmall ? 14 : 18),

                  // ── Quick Actions ────────────────────────────────────
                  _SectionHeader(title: 'Quick Actions'),
                  const SizedBox(height: 10),
                  _QuickActionsRow(),

                  SizedBox(height: isSmall ? 14 : 18),

                  // ── Map Preview ──────────────────────────────────────
                  _SectionHeader(title: 'Your Location'),
                  const SizedBox(height: 10),
                  _MapPreview(
                    latLng: currentLatLng,
                    loading: mapLoading,
                    onRefresh: _loadCurrentLocation,
                    address: currentAddress,
                    locationUnavailable: _locationUnavailable,
                  ),

                  SizedBox(height: isSmall ? 14 : 18),

                  // ── Nearby Hospitals ─────────────────────────────────
                  _SectionHeader(
                    title: 'Nearby Hospitals',
                    actionLabel: 'See All →',
                    onAction: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MainShell(initialIndex: 1),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  if (hospitalsLoading)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                        child: CircularProgressIndicator(color: _red),
                      ),
                    )
                  else if (nearbyHospitals.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.local_hospital_outlined,
                              color: const Color(0xFFCCCCCC),
                              size: 40,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _locationUnavailable
                                  ? 'Enable location to find nearby hospitals'
                                  : 'No nearby hospitals found',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF888888),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_locationUnavailable)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: TextButton(
                                  onPressed: () =>
                                      Geolocator.openLocationSettings(),
                                  child: Text(
                                    'Open Location Settings',
                                    style: GoogleFonts.inter(
                                      color: _red,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...nearbyHospitals.take(3).map((hospital) {
                      return GestureDetector(
                        onTap: () => _openHospitalNavigation(hospital),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFEEEEEE),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      _red.withValues(alpha: 0.12),
                                      _orange.withValues(alpha: 0.08),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: const Icon(
                                  Icons.local_hospital_rounded,
                                  color: _red,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      hospital['name'] ?? 'Hospital',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: _ink,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      hospital['vicinity'] ??
                                          hospital['location'] ??
                                          '',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: const Color(0xFF888888),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.navigation_rounded,
                                  color: _red,
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

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

// ── Section header ─────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

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
        if (actionLabel != null && onAction != null) ...[
          const Spacer(),
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel!,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _red,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── SOS Card (image-style layout) ─────────────────────────────────────────────
class _SOSCard extends StatelessWidget {
  final VoidCallback onTap;
  const _SOSCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEEEEEE), width: 1),
        boxShadow: [
          BoxShadow(
            color: _red.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Left: text content ───────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Emergency Help',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF888888),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SOS',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 48,
                      letterSpacing: 4,
                      color: _red,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tap the button to alert\nyour emergency contacts',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF888888),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFEEEEEE),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.groups_rounded,
                            color: _red,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            "Stay calm, we're\nhere to help you",
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _ink,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 16),

            // ── Right: animated SOS button ───────────────────────────────
            _SOSButtonCircle(onTap: onTap),
          ],
        ),
      ),
    );
  }
}

// ── Animated circular SOS button ──────────────────────────────────────────────
class _SOSButtonCircle extends StatefulWidget {
  final VoidCallback onTap;
  const _SOSButtonCircle({required this.onTap});

  @override
  State<_SOSButtonCircle> createState() => _SOSButtonCircleState();
}

class _SOSButtonCircleState extends State<_SOSButtonCircle>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _glowCtrl;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _glowAnim;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat(reverse: true);

    _glowCtrl = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(
      begin: 1.0,
      end: 1.06,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _glowAnim = Tween<double>(
      begin: 14.0,
      end: 28.0,
    ).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double btnSize = 130;

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnim, _glowAnim]),
      builder: (_, __) => Transform.scale(
        scale: _isPressed ? 0.94 : _pulseAnim.value,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) {
            setState(() => _isPressed = false);
            widget.onTap();
          },
          onTapCancel: () => setState(() => _isPressed = false),
          child: SizedBox(
            width: btnSize,
            height: btnSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: btnSize,
                  height: btnSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _red.withValues(alpha: .07),
                  ),
                ),
                Container(
                  width: btnSize * 0.84,
                  height: btnSize * 0.84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _red.withValues(alpha: .13),
                  ),
                ),
                Container(
                  width: btnSize * 0.68,
                  height: btnSize * 0.68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFF3300),
                        Color(0xFFE83000),
                        Color(0xFFCC2200),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _red.withValues(alpha: 0.45),
                        blurRadius: _glowAnim.value,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.emergency_rounded,
                        color: _white,
                        size: 22,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'SOS',
                        style: GoogleFonts.bebasNeue(
                          fontSize: 22,
                          letterSpacing: 3,
                          color: _white,
                          height: 1,
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
    );
  }
}

// ── Map Preview (large box) ────────────────────────────────────────────────────
class _MapPreview extends StatelessWidget {
  final LatLng? latLng;
  final bool loading;
  final VoidCallback onRefresh;
  final String address;
  final bool locationUnavailable;

  const _MapPreview({
    required this.latLng,
    required this.loading,
    required this.onRefresh,
    required this.address,
    required this.locationUnavailable,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: screenWidth * 0.72,
            child: loading
                ? const Center(child: CircularProgressIndicator(color: _red))
                : latLng == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.map_outlined,
                          color: const Color(0xFFCCCCCC),
                          size: 44,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Map unavailable',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF888888),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: onRefresh,
                          child: Text(
                            'Enable location',
                            style: GoogleFonts.inter(
                              color: _red,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: latLng!,
                      zoom: 15,
                    ),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    markers: {
                      Marker(
                        markerId: const MarkerId('user'),
                        position: latLng!,
                      ),
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFFEEEEEE), width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _red.withValues(alpha:0.12),
                        _orange.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    locationUnavailable
                        ? Icons.location_off_rounded
                        : Icons.my_location_rounded,
                    color: locationUnavailable ? const Color(0xFFAAAAAA) : _red,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        locationUnavailable
                            ? 'Location unavailable'
                            : 'Your location',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF888888),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      Text(
                        address,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _ink,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onRefresh,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFEEEEEE)),
                    ),
                    child: const Icon(
                      Icons.refresh_rounded,
                      color: _ink,
                      size: 16,
                    ),
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

// ── Quick Actions Row (replaces GridView to avoid height gaps) ─────────────────
class _QuickActionsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.local_hospital_rounded, 'Hospital', _red, _orange),
      (Icons.local_police_rounded, 'Police', _orange, _amber),
      (Icons.car_crash_rounded, 'Towing', _red, _orange),
      (Icons.build_rounded, 'Mechanic', _orange, _amber),
    ];

    return Row(
      children: List.generate(actions.length, (i) {
        final a = actions[i];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < actions.length - 1 ? 10 : 0),
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => MainShell(initialIndex: 1)),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEEEEEE)),
                  boxShadow: [
                    BoxShadow(
                      color: a.$3.withValues(alpha: 0.10),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            a.$3.withValues(alpha: 0.15),
                            a.$4.withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(a.$1, color: a.$3, size: 22),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      a.$2,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
