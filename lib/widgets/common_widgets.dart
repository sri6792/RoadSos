// lib/widgets/common_widgets.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';

// ─── Responsive helpers ───────────────────────────────────────────────────────
class R {
  static double w(BuildContext ctx, double pct) =>
      MediaQuery.of(ctx).size.width * pct;

  static double h(BuildContext ctx, double pct) =>
      MediaQuery.of(ctx).size.height * pct;

  static double sp(BuildContext ctx, double size) {
    final w = MediaQuery.of(ctx).size.width;
    return size * (w / 390); // base 390px
  }

  static double pad(BuildContext ctx) => w(ctx, 0.05).clamp(16.0, 28.0);
}

// ─── Quick Action Button ──────────────────────────────────────────────────────
class QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const QuickActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 6),

              // FIXED OVERFLOW
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Service List Item ────────────────────────────────────────────────────────
class ServiceListItem extends StatelessWidget {
  final NearbyService service;
  final VoidCallback onCall;
  final VoidCallback onNavigate;

  const ServiceListItem({
    super.key,
    required this.service,
    required this.onCall,
    required this.onNavigate,
  });

  Color _typeColor() {
    switch (service.type) {
      case ServiceType.hospital:
        return AppColors.sosRed;
      case ServiceType.police:
        return AppColors.navyDark;
      case ServiceType.towing:
        return AppColors.warning;
      case ServiceType.mechanic:
        return AppColors.info;
    }
  }

  IconData _typeIcon() {
    switch (service.type) {
      case ServiceType.hospital:
        return Icons.local_hospital_rounded;
      case ServiceType.police:
        return Icons.local_police_rounded;
      case ServiceType.towing:
        return Icons.car_crash_rounded;
      case ServiceType.mechanic:
        return Icons.build_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGray, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _typeColor().withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_typeIcon(), color: _typeColor(), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          service.name,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.navyDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: service.isOpen
                              ? AppColors.success.withValues(alpha: 0.1)
                              : AppColors.midGray.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          service.isOpen ? 'Open' : 'Closed',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: service.isOpen
                                ? AppColors.success
                                : AppColors.midGray,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    service.address,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.midGray,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 12,
                        color: _typeColor(),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${service.distance.toStringAsFixed(1)} km',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _typeColor(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.star_rounded,
                        size: 12,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        service.rating.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.midGray,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                _ActionBtn(
                  icon: Icons.call_rounded,
                  color: AppColors.success,
                  onTap: onCall,
                ),
                const SizedBox(height: 6),
                _ActionBtn(
                  icon: Icons.navigation_rounded,
                  color: AppColors.info,
                  onTap: onNavigate,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

// Remaining widgets unchanged...

// ─── Status Badge ─────────────────────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String label;
  final bool active;
  const StatusBadge({super.key, required this.label, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? AppColors.success.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active
              ? AppColors.success.withValues(alpha: 0.5)
              : AppColors.white.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (active)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 6),
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
            ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: active ? AppColors.success : AppColors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.navyDark,
          ),
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel!,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.sosRed,
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Info Row ─────────────────────────────────────────────────────────────────
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.sosRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.sosRed),
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
                    color: AppColors.midGray,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.navyDark,
                    fontWeight: FontWeight.w600,
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
