// lib/screens/nearby_services_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../secrets.dart';
import 'package:url_launcher/url_launcher.dart';

// ── Palette (matches home_screen) ────────────────────────────────────────────
const Color _red = Color(0xFFE83000);
const Color _orange = Color(0xFFFF6600);
const Color _amber = Color(0xFFFFAA00);
const Color _white = Color(0xFFFFFFFF);
const Color _ink = Color(0xFF1A1A1A);
const Color _success = Color(0xFF22C55E);
const Color _info = Color(0xFF3B82F6);

class NearbyServicesScreen extends StatefulWidget {
  const NearbyServicesScreen({super.key});

  @override
  State<NearbyServicesScreen> createState() => _NearbyServicesScreenState();
}

class _NearbyServicesScreenState extends State<NearbyServicesScreen>
    with SingleTickerProviderStateMixin {
  int _selectedTab = 0;

  String currentAddress = 'Getting location...';
  bool loading = true;
  bool showingCached = false;
  bool _locationUnavailable = false;

  double? currentLat;
  double? currentLng;

  List<dynamic> services = [];

  final _tabs = const [
    (
    'Hospitals',
    Icons.local_hospital_rounded,
    _red,
    'hospital clinic medical',
    ),
    ('Police', Icons.local_police_rounded, _ink, 'police station'),
    (
    'Towing',
    Icons.car_crash_rounded,
    _orange,
    'towing service roadside assistance',
    ),
    ('Mechanics', Icons.build_rounded, _info, 'car repair mechanic garage'),
  ];

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    setState(() {
      loading = true;
      showingCached = false;
      services = [];
      currentAddress = 'Getting location...';
      _locationUnavailable = false;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          currentAddress = 'Location off';
          _locationUnavailable = true;
        });
        await _loadCachedServicesFromFirestore();
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
          _locationUnavailable = true;
        });
        await _loadCachedServicesFromFirestore();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      currentLat = position.latitude;
      currentLng = position.longitude;

      await _loadAddress(position.latitude, position.longitude);
      await _fetchNearbyServices();
    } catch (e) {
      debugPrint('Location error: $e');
      setState(() {
        currentAddress = 'Offline data';
        _locationUnavailable = true;
      });
      await _loadCachedServicesFromFirestore();
    }
  }

  Future<void> _loadAddress(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final area = place.subLocality?.isNotEmpty == true
            ? place.subLocality!
            : place.locality?.isNotEmpty == true
            ? place.locality!
            : place.name ?? 'Live Location';
        setState(
              () => currentAddress = '$area, ${place.administrativeArea ?? ''}',
        );
      }
    } catch (_) {
      setState(() => currentAddress = 'Live Location');
    }
  }

  Future<void> _fetchNearbyServices() async {
    if (currentLat == null || currentLng == null) {
      await _loadCachedServicesFromFirestore();
      return;
    }
    setState(() {
      loading = true;
      showingCached = false;
      services = [];
    });

    final tab = _tabs[_selectedTab];
    final keyword = tab.$4;
    final typeName = tab.$1;

    final url =
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
        '?location=$currentLat,$currentLng&rankby=distance&keyword=$keyword&key=$googleApiKey';

    try {
      final response = await http.get(Uri.parse(url));
      final data = jsonDecode(response.body);
      final results = data['results'] ?? [];

      if (results.isEmpty) {
        await _loadCachedServicesFromFirestore();
        return;
      }

      setState(() {
        services = results;
        loading = false;
        showingCached = false;
      });

      for (final service in results.take(10)) {
        final placeId = service['place_id'];
        if (placeId == null) continue;
        await FirebaseFirestore.instance
            .collection('cached_services')
            .doc(placeId)
            .set({
          'name': service['name'] ?? '',
          'location': service['vicinity'] ?? '',
          'type': typeName,
          'keyword': keyword,
          'rating': service['rating'] ?? 0,
          'openNow': service['opening_hours']?['open_now'],
          'latitude': service['geometry']?['location']?['lat'],
          'longitude': service['geometry']?['location']?['lng'],
          'placeId': placeId,
          'source': 'google_places',
          'userLatitude': currentLat,
          'userLongitude': currentLng,
          'searchedFrom': currentAddress,
          'cachedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Nearby services error: $e');
      await _loadCachedServicesFromFirestore();
    }
  }

  Future<void> _loadCachedServicesFromFirestore() async {
    try {
      final typeName = _tabs[_selectedTab].$1;
      final snapshot = await FirebaseFirestore.instance
          .collection('cached_services')
          .where('type', isEqualTo: typeName)
          .limit(20)
          .get(const GetOptions(source: Source.cache));
      setState(() {
        services = snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data(), 'fromCache': true})
            .toList();
        loading = false;
        showingCached = true;
      });
    } catch (e) {
      setState(() {
        loading = false;
        showingCached = true;
        services = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final pad = (size.width * 0.055).clamp(16.0, 28.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Container(
              color: _white,
              padding: EdgeInsets.fromLTRB(pad, 16, pad, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NEARBY',
                            style: GoogleFonts.bebasNeue(
                              fontSize: 28,
                              letterSpacing: 2,
                              color: _ink,
                              height: 1,
                            ),
                          ),
                          Text(
                            'SERVICES',
                            style: GoogleFonts.bebasNeue(
                              fontSize: 28,
                              letterSpacing: 2,
                              color: _red,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Location pill
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
                                    : showingCached
                                    ? Icons.cloud_off_rounded
                                    : Icons.location_on_rounded,
                                size: 13,
                                color: _locationUnavailable || showingCached
                                    ? const Color(0xFFAAAAAA)
                                    : _red,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  currentAddress,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: _ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Refresh button
                      GestureDetector(
                        onTap: _loadLocation,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE5E5E5)),
                          ),
                          child: const Icon(
                            Icons.my_location_rounded,
                            color: _red,
                            size: 17,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Offline banner
                  if (showingCached)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3CD),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFCA28)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.wifi_off_rounded,
                            size: 14,
                            color: Color(0xFF7B5800),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Showing cached data — connect for live results',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF7B5800),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _loadLocation,
                            child: Text(
                              'Retry',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF7B5800),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Tab chips
                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _tabs.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final tab = _tabs[i];
                        final isSelected = _selectedTab == i;
                        return GestureDetector(
                          onTap: () async {
                            setState(() {
                              _selectedTab = i;
                              loading = true;
                              services = [];
                            });
                            await _fetchNearbyServices();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? tab.$3
                                  : tab.$3.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: isSelected
                                    ? tab.$3
                                    : tab.$3.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  tab.$2,
                                  size: 13,
                                  color: isSelected ? _white : tab.$3,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  tab.$1,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? _white : tab.$3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),

            // ── Body ─────────────────────────────────────────────────────────
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator(color: _red))
                  : services.isEmpty
                  ? _EmptyState(
                locationUnavailable: _locationUnavailable,
                showingCached: showingCached,
                tabLabel: _tabs[_selectedTab].$1,
                onRetry: _loadLocation,
              )
                  : ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(pad, 14, pad, 90),
                itemCount: services.length,
                itemBuilder: (_, i) {
                  final tab = _tabs[_selectedTab];
                  return _ServiceCard(
                    service: services[i],
                    icon: tab.$2,
                    color: tab.$3,
                    showingCached: showingCached,
                    currentLat: currentLat,
                    currentLng: currentLng,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool locationUnavailable;
  final bool showingCached;
  final String tabLabel;
  final VoidCallback onRetry;

  const _EmptyState({
    required this.locationUnavailable,
    required this.showingCached,
    required this.tabLabel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                color: Color(0xFFCCCCCC),
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              locationUnavailable
                  ? 'Location Required'
                  : showingCached
                  ? 'No Cached $tabLabel'
                  : 'No $tabLabel Nearby',
              style: GoogleFonts.bebasNeue(
                fontSize: 22,
                letterSpacing: 1.5,
                color: _ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              locationUnavailable
                  ? 'Enable location to find services near you'
                  : 'Try refreshing or check your connection',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF888888),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: locationUnavailable
                  ? () => Geolocator.openLocationSettings()
                  : onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  locationUnavailable ? 'Open Settings' : 'Retry',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Service Card ──────────────────────────────────────────────────────────────
class _ServiceCard extends StatelessWidget {
  final dynamic service;
  final IconData icon;
  final Color color;
  final bool showingCached;
  final double? currentLat;
  final double? currentLng;

  const _ServiceCard({
    required this.service,
    required this.icon,
    required this.color,
    required this.showingCached,
    required this.currentLat,
    required this.currentLng,
  });

  String _getDistance() {
    final destLat =
        service['geometry']?['location']?['lat'] ?? service['latitude'];
    final destLng =
        service['geometry']?['location']?['lng'] ?? service['longitude'];

    if (currentLat == null ||
        currentLng == null ||
        destLat == null ||
        destLng == null) {
      return '';
    }

    final distanceInMeters = Geolocator.distanceBetween(
      currentLat!,
      currentLng!,
      (destLat as num).toDouble(),
      (destLng as num).toDouble(),
    );

    if (distanceInMeters < 1000) {
      return '${distanceInMeters.toStringAsFixed(0)} m away';
    }

    return '${(distanceInMeters / 1000).toStringAsFixed(1)} km away';
  }

  Future<void> _openNavigation() async {
    final destLat =
        service['geometry']?['location']?['lat'] ?? service['latitude'];
    final destLng =
        service['geometry']?['location']?['lng'] ?? service['longitude'];

    if (destLat == null || destLng == null) return;

    final url = (currentLat != null && currentLng != null)
        ? 'https://www.google.com/maps/dir/?api=1&origin=$currentLat,$currentLng&destination=$destLat,$destLng&travelmode=driving'
        : 'https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLng&travelmode=driving';

    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = service['name'] ?? 'Service';
    final address =
        service['vicinity'] ?? service['location'] ?? 'Address unavailable';
    final rating = service['rating'];
    final openNow = service['opening_hours']?['open_now'] ?? service['openNow'];
    final distance = _getDistance();

    return GestureDetector(
      onTap: _openNavigation,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEEEEEE), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.14),
                    color.withValues(alpha: 0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 3),

                  Text(
                    address,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF888888),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 7),

                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (rating != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 13,
                              color: _amber,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              rating.toString(),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _ink,
                              ),
                            ),
                          ],
                        ),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: openNow == true
                              ? _success.withValues(alpha: 0.1)
                              : openNow == false
                              ? _red.withValues(alpha: 0.08)
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          openNow == true
                              ? 'Open now'
                              : openNow == false
                              ? 'Closed'
                              : 'Hours unknown',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: openNow == true
                                ? _success
                                : openNow == false
                                ? _red
                                : const Color(0xFF888888),
                          ),
                        ),
                      ),

                      if (distance.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _info.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.near_me_rounded,
                                size: 11,
                                color: _info,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                distance,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _info,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEEEEEE)),
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
  }
}