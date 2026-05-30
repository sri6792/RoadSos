// lib/screens/offline_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../widgets/common_widgets.dart';

// ── Palette (mirrors home_screen.dart) ────────────────────────────────────────
const Color _red = Color(0xFFE83000);
const Color _orange = Color(0xFFFF6600);
const Color _amber = Color(0xFFFFAA00);
const Color _white = Color(0xFFFFFFFF);
const Color _ink = Color(0xFF1A1A1A);

class OfflineScreen extends StatefulWidget {
  const OfflineScreen({super.key});

  @override
  State<OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends State<OfflineScreen> {
  int _expandedTip = -1;

  final List<Map<String, String>> _firstAidTips = [
    {
      'title': 'Unconscious Person',
      'icon': '🧠',
      'steps':
          '1. Check surroundings for safety\n2. Call 112 immediately\n3. Place in recovery position\n4. Monitor breathing\n5. Do not give food/water',
    },
    {
      'title': 'Severe Bleeding',
      'icon': '🩸',
      'steps':
          '1. Apply firm pressure with clean cloth\n2. Elevate the wound if possible\n3. Do not remove cloth — add more if soaked\n4. Keep person calm and warm\n5. Seek medical help immediately',
    },
    {
      'title': 'Vehicle Accident',
      'icon': '🚗',
      'steps':
          '1. Do not move injured persons unless in danger\n2. Turn off vehicle ignition\n3. Switch on hazard lights\n4. Call 112 and 1033 (Road helpline)\n5. Keep bystanders away',
    },
    {
      'title': 'Choking',
      'icon': '😮',
      'steps':
          '1. Encourage coughing\n2. Give 5 firm back blows between shoulder blades\n3. If no improvement, give 5 abdominal thrusts\n4. Alternate back blows and thrusts\n5. Call 112 if unconscious',
    },
    {
      'title': 'Chest Pain',
      'icon': '❤️',
      'steps':
          '1. Have person sit or lie comfortably\n2. Loosen tight clothing\n3. Give aspirin if available and not allergic\n4. Call 112 immediately\n5. Begin CPR if unconscious and not breathing',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final pad = (size.width * 0.055).clamp(16.0, 28.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Offline Banner Header ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: _white,
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // Top app-bar row
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: pad,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'No Internet',
                                style: GoogleFonts.bebasNeue(
                                  fontSize: 26,
                                  letterSpacing: 1.5,
                                  color: _ink,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Offline Mode',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFF888888),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          // Offline pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3CD),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFFFCA28),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.wifi_off_rounded,
                                  size: 14,
                                  color: Color(0xFF7B5800),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'OFFLINE',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF7B5800),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Warning info strip
                    Container(
                      margin: EdgeInsets.fromLTRB(pad, 0, pad, 14),
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
                          const Icon(
                            Icons.info_outline_rounded,
                            color: Color(0xFF7B5800),
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Cached data shown · SMS SOS still works without internet',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF7B5800),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {},
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
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
                    ),

                    // SMS SOS button
                    Padding(
                      padding: EdgeInsets.fromLTRB(pad, 0, pad, 18),
                      child: GestureDetector(
                        onTap: () {},
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFF3300),
                                Color(0xFFE83000),
                                Color(0xFFCC2200),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: _red.withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.sms_rounded,
                                color: _white,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Send SMS SOS',
                                style: GoogleFonts.bebasNeue(
                                  fontSize: 20,
                                  letterSpacing: 2,
                                  color: _white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Body content ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: pad, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Emergency Numbers ──────────────────────────────────
                  _OfflineSectionHeader(title: 'Emergency Numbers'),
                  const SizedBox(height: 12),
                  _EmergencyNumbersGrid(),
                  const SizedBox(height: 22),

                  // ── Cached Nearby Services ─────────────────────────────
                  _OfflineSectionHeader(
                    title: 'Cached Nearby Services',
                    actionLabel: 'Updated 2h ago',
                  ),
                  const SizedBox(height: 12),
                  ...SampleData.hospitals
                      .take(2)
                      .map(
                        (s) => ServiceListItem(
                          service: s,
                          onCall: () {},
                          onNavigate: () {},
                        ),
                      ),
                  const SizedBox(height: 22),

                  // ── First Aid Tips ─────────────────────────────────────
                  _OfflineSectionHeader(title: 'First Aid Tips'),
                  const SizedBox(height: 12),
                  ..._firstAidTips.asMap().entries.map(
                    (e) => _FirstAidTile(
                      tip: e.value,
                      isExpanded: _expandedTip == e.key,
                      onTap: () => setState(() {
                        _expandedTip = _expandedTip == e.key ? -1 : e.key;
                      }),
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

// ── Section Header (matches _SectionHeader from home_screen.dart) ─────────────
class _OfflineSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;

  const _OfflineSectionHeader({
    required this.title,
    this.actionLabel,
  });

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
        if (actionLabel != null) ...[
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 11,
                  color: Color(0xFF888888),
                ),
                const SizedBox(width: 4),
                Text(
                  actionLabel!,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF888888),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Emergency Numbers Grid ─────────────────────────────────────────────────────
class _EmergencyNumbersGrid extends StatelessWidget {
  final List<Map<String, dynamic>> _numbers = [
    {
      'label': 'Emergency',
      'number': '112',
      'icon': Icons.sos_rounded,
      'color': _red,
      'accent': _orange,
    },
    {
      'label': 'Ambulance',
      'number': '108',
      'icon': Icons.local_hospital_rounded,
      'color': _red,
      'accent': _orange,
    },
    {
      'label': 'Police',
      'number': '100',
      'icon': Icons.local_police_rounded,
      'color': _orange,
      'accent': _amber,
    },
    {
      'label': 'Fire',
      'number': '101',
      'icon': Icons.local_fire_department_rounded,
      'color': _orange,
      'accent': _amber,
    },
    {
      'label': 'Women Help',
      'number': '1091',
      'icon': Icons.woman_rounded,
      'color': Color(0xFF9C27B0),
      'accent': Color(0xFFCE93D8),
    },
    {
      'label': 'Road Help',
      'number': '1033',
      'icon': Icons.car_repair_rounded,
      'color': Color(0xFF1565C0),
      'accent': Color(0xFF90CAF9),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.05,
      children: _numbers.map((n) {
        final color = n['color'] as Color;
        final accent = n['accent'] as Color;
        return GestureDetector(
          onTap: () {},
          child: Container(
            decoration: BoxDecoration(
              color: _white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEEEEEE)),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Gradient icon container — same style as home_screen
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withValues(alpha: 0.15),
                        accent.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(n['icon'] as IconData, color: color, size: 20),
                ),
                const SizedBox(height: 6),
                Text(
                  n['number'] as String,
                  style: GoogleFonts.bebasNeue(
                    fontSize: 22,
                    letterSpacing: 1.5,
                    color: _ink,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  n['label'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: const Color(0xFF888888),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── First Aid Expandable Tile ──────────────────────────────────────────────────
class _FirstAidTile extends StatelessWidget {
  final Map<String, String> tip;
  final bool isExpanded;
  final VoidCallback onTap;

  const _FirstAidTile({
    required this.tip,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isExpanded
                ? _red.withValues(alpha: 0.30)
                : const Color(0xFFEEEEEE),
            width: isExpanded ? 1.5 : 1,
          ),
          boxShadow: isExpanded
              ? [
                  BoxShadow(
                    color: _red.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Icon badge
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _red.withValues(alpha: 0.10),
                          _orange.withValues(alpha: 0.06),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        tip['icon']!,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tip['title']!,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isExpanded
                          ? _red.withValues(alpha: 0.08)
                          : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: isExpanded ? _red : const Color(0xFF888888),
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
            if (isExpanded)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: Text(
                    tip['steps']!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF444444),
                      height: 1.75,
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
