// lib/screens/emergency_contacts_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'login_screen.dart';
import '../models/models.dart';

// ── Palette (matches home_screen) ─────────────────────────────────────────────
const Color _red = Color(0xFFE83000);
const Color _orange = Color(0xFFFF6600);
const Color _white = Color(0xFFFFFFFF);
const Color _ink = Color(0xFF1A1A1A);
const Color _bg = Color(0xFFF5F5F5);
const Color _mid = Color(0xFF888888);
const Color _light = Color(0xFFEEEEEE);

class EmergencyContactsScreen extends StatefulWidget {
  final bool isGuest;
  const EmergencyContactsScreen({super.key, this.isGuest = false});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final List<EmergencyContact> _guestContacts = [];

  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get contactsRef => FirebaseFirestore
      .instance
      .collection('users')
      .doc(uid)
      .collection('emergencyContacts');

  final List<Map<String, dynamic>> _nationalContacts = [
    {
      'title': 'National Emergency',
      'number': '112',
      'icon': Icons.emergency_rounded,
      'color': _red,
    },
    {
      'title': 'Ambulance',
      'number': '108',
      'icon': Icons.local_hospital_rounded,
      'color': const Color(0xFFDC2626),
    },
    {
      'title': 'Police',
      'number': '100',
      'icon': Icons.local_police_rounded,
      'color': const Color(0xFF1A2A4A),
    },
    {
      'title': 'Fire Brigade',
      'number': '101',
      'icon': Icons.local_fire_department_rounded,
      'color': _orange,
    },
    {
      'title': 'Road Accident Helpline',
      'number': '1073',
      'icon': Icons.car_crash_rounded,
      'color': const Color(0xFF0284C7),
    },
    {
      'title': 'Women Helpline',
      'number': '1091',
      'icon': Icons.shield_rounded,
      'color': const Color(0xFF7C3AED),
    },
  ];

  Future<void> _setPrimary(String id) async {
    final all = await contactsRef.get();
    for (final doc in all.docs) {
      await doc.reference.update({'isPrimary': doc.id == id});
    }
  }

  Future<void> _delete(String id) async => await contactsRef.doc(id).delete();

  void _setGuestPrimary(String id) {
    setState(() {
      for (int i = 0; i < _guestContacts.length; i++) {
        final c = _guestContacts[i];
        _guestContacts[i] = EmergencyContact(
          id: c.id,
          name: c.name,
          phone: c.phone,
          relation: c.relation,
          isPrimary: c.id == id,
        );
      }
    });
  }

  void _deleteGuest(String id) =>
      setState(() => _guestContacts.removeWhere((c) => c.id == id));

  Future<void> _callNumber(String number) async {
    final Uri uri = Uri(scheme: 'tel', path: number.replaceAll(' ', ''));

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not place call'),
            backgroundColor: _red,
          ),
        );
      }
    }
  }

  // ── Bottom sheets ──────────────────────────────────────────────────────────

  void _showGuestAddSheet(BuildContext ctx) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddContactSheet(
        title: 'Add Quick Contact',
        subtitle: 'Saved for this session only.',
        fields: [
          _FieldDef(label: 'Name', ctrl: nameCtrl, hint: 'Enter name'),
          _FieldDef(
            label: 'Phone Number',
            ctrl: phoneCtrl,
            hint: 'Enter phone number',
            keyboard: TextInputType.phone,
          ),
        ],
        onSave: () {
          if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) {
            return;
          }
          setState(() {
            _guestContacts.add(
              EmergencyContact(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                relation: 'Quick Contact',
                isPrimary: _guestContacts.isEmpty,
              ),
            );
          });
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showAddContactSheet(BuildContext ctx) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final relCtrl = TextEditingController();

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddContactSheet(
        title: 'Add Emergency Contact',
        fields: [
          _FieldDef(
            label: 'Full Name',
            ctrl: nameCtrl,
            hint: 'Enter full name',
          ),
          _FieldDef(
            label: 'Phone Number',
            ctrl: phoneCtrl,
            hint: 'Enter phone number',
            keyboard: TextInputType.phone,
          ),
          _FieldDef(
            label: 'Relation',
            ctrl: relCtrl,
            hint: 'Parent / Friend / Sibling',
          ),
        ],
        onSave: () async {
          if (uid == null) return;
          if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) {
            return;
          }
          final existing = await contactsRef.get();
          await contactsRef.add({
            'name': nameCtrl.text.trim(),
            'phone': phoneCtrl.text.trim(),
            'relation': relCtrl.text.trim(),
            'isPrimary': existing.docs.isEmpty,
            'createdAt': FieldValue.serverTimestamp(),
          });
          if (mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  // ── Dynamic contact builders ───────────────────────────────────────────────

  Widget _buildDynamicContacts() {
    if (uid == null) return _GuestSignInCard();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: contactsRef.orderBy('createdAt').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'Unable to load contacts',
            style: GoogleFonts.inter(fontSize: 13, color: _red),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator(color: _red)),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _EmptyContactsHint(onAdd: () => _showAddContactSheet(context));
        }
        return Column(
          children: docs.map((doc) {
            final data = doc.data();
            final contact = EmergencyContact(
              id: doc.id,
              name: data['name'] ?? '',
              phone: data['phone'] ?? '',
              relation: data['relation'] ?? '',
              isPrimary: data['isPrimary'] ?? false,
            );
            return _ContactCard(
              contact: contact,
              onSetPrimary: () => _setPrimary(doc.id),
              onDelete: () => _delete(doc.id),
              onCall: () => _callNumber(contact.phone),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildGuestContacts() {
    if (_guestContacts.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EmptyContactsHint(onAdd: () => _showGuestAddSheet(context)),
          const SizedBox(height: 16),
          _GuestSignInCard(),
        ],
      );
    }
    return Column(
      children: _guestContacts
          .map(
            (c) => _ContactCard(
              contact: c,
              onSetPrimary: () => _setGuestPrimary(c.id),
              onDelete: () => _deleteGuest(c.id),
              onCall: () => _callNumber(c.phone),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final pad = (size.width * 0.055).clamp(16.0, 28.0);

    return Scaffold(
      backgroundColor: _bg,
      // ── Sticky header ────────────────────────────────────────────────────
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(86),
        child: Container(
          color: _white,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: pad, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EMERGENCY',
                        style: GoogleFonts.bebasNeue(
                          fontSize: 26,
                          letterSpacing: 2,
                          color: _ink,
                          height: 0.95,
                        ),
                      ),
                      Text(
                        'CONTACTS',
                        style: GoogleFonts.bebasNeue(
                          fontSize: 26,
                          letterSpacing: 2,
                          color: _red,
                          height: 0.95,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => widget.isGuest
                        ? _showGuestAddSheet(context)
                        : _showAddContactSheet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: _red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.add_rounded,
                            color: _white,
                            size: 16,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Add',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _white,
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
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: pad, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Subtitle ──────────────────────────────────────────
                  Text(
                    widget.isGuest
                        ? 'Quick contacts for this session'
                        : 'Your saved emergency contacts',
                    style: GoogleFonts.inter(fontSize: 13, color: _mid),
                  ),
                  const SizedBox(height: 14),

                  // ── Personal contacts ─────────────────────────────────
                  widget.isGuest
                      ? _buildGuestContacts()
                      : _buildDynamicContacts(),

                  const SizedBox(height: 28),

                  // ── National numbers section header ───────────────────
                  _SectionHeader(
                    title: 'National Emergency Numbers',
                    subtitle: 'Tap any number to call directly',
                  ),
                  const SizedBox(height: 12),

                  ..._nationalContacts.map(
                    (item) => _NationalContactCard(item: item),
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

// ── Section header (matches home_screen style) ─────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: Text(
              subtitle!,
              style: GoogleFonts.inter(fontSize: 12, color: _mid),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Contact card ───────────────────────────────────────────────────────────────
class _ContactCard extends StatelessWidget {
  final EmergencyContact contact;
  final VoidCallback onSetPrimary;
  final VoidCallback onDelete;
  final VoidCallback onCall;

  const _ContactCard({
    required this.contact,
    required this.onSetPrimary,
    required this.onDelete,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: contact.isPrimary ? _red.withValues(alpha: 0.3) : _light,
          width: contact.isPrimary ? 1.5 : 1,
        ),
        boxShadow: contact.isPrimary
            ? [
                BoxShadow(
                  color: _red.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          // ── Avatar ────────────────────────────────────────────────────
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: contact.isPrimary
                    ? [
                        _red.withValues(alpha: .15),
                        _orange.withValues(alpha: 0.08),
                      ]
                    : [const Color(0xFFF5F5F5), const Color(0xFFEEEEEE)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: contact.isPrimary ? _red.withValues(alpha: 0.2) : _light,
              ),
            ),
            child: Center(
              child: Text(
                contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                style: GoogleFonts.bebasNeue(
                  fontSize: 22,
                  color: contact.isPrimary ? _red : _ink,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // ── Info ──────────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        contact.name,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (contact.isPrimary) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Primary',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _red,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  contact.phone,
                  style: GoogleFonts.inter(fontSize: 12, color: _mid),
                ),
                if (contact.relation.isNotEmpty)
                  Text(
                    contact.relation,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: _mid.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),

          // ── Actions ───────────────────────────────────────────────────
          GestureDetector(
            onTap: onCall,
            child: Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: _red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.call_rounded, size: 16, color: _red),
            ),
          ),
          Column(
            children: [
              GestureDetector(
                onTap: onSetPrimary,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: contact.isPrimary
                        ? _red.withValues(alpha: 0.1)
                        : _bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: contact.isPrimary
                          ? _red.withValues(alpha: 0.3)
                          : _light,
                    ),
                  ),
                  child: Icon(
                    contact.isPrimary
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 16,
                    color: contact.isPrimary ? _red : _mid,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _light),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: _mid,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── National contact card ──────────────────────────────────────────────────────
class _NationalContactCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _NationalContactCard({required this.item});

  Future<void> _call(BuildContext context) async {
    final Uri uri = Uri(
      scheme: 'tel',
      path: item['number'].toString().replaceAll(' ', ''),
    );

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not place call')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = item['color'] as Color;
    return GestureDetector(
      onTap: () => _call(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _light),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: .15),
                    color.withValues(alpha: .06),
                  ],
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(item['icon'] as IconData, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  Text(
                    item['number'] as String,
                    style: GoogleFonts.bebasNeue(
                      fontSize: 18,
                      letterSpacing: 2,
                      color: color,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.15),
                    color.withValues(alpha: 0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.call_rounded, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty contacts hint ────────────────────────────────────────────────────────
class _EmptyContactsHint extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyContactsHint({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAdd,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _red.withValues(alpha: 0.2), width: 1.5),
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
                    _orange.withValues(alpha: 0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.add_rounded, color: _red, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add your first contact',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'They will be notified with your location during SOS',
                    style: GoogleFonts.inter(fontSize: 12, color: _mid),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Guest sign-in card ─────────────────────────────────────────────────────────
class _GuestSignInCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _light),
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
                    _orange.withValues(alpha: 0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.person_add_rounded,
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
                    'Sign in to save permanently',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Contacts are lost when you close the app',
                    style: GoogleFonts.inter(fontSize: 12, color: _mid),
                  ),
                ],
              ),
            ),

            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _red.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: _red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable add-contact bottom sheet ─────────────────────────────────────────
class _FieldDef {
  final String label;
  final TextEditingController ctrl;
  final String hint;
  final TextInputType keyboard;
  _FieldDef({
    required this.label,
    required this.ctrl,
    required this.hint,
    this.keyboard = TextInputType.text,
  });
}

class _AddContactSheet extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<_FieldDef> fields;
  final VoidCallback onSave;

  const _AddContactSheet({
    required this.title,
    this.subtitle,
    required this.fields,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _light,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: GoogleFonts.bebasNeue(
              fontSize: 24,
              letterSpacing: 1.5,
              color: _ink,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: GoogleFonts.inter(fontSize: 12, color: _mid),
            ),
          ],
          const SizedBox(height: 20),
          ...fields.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _LabeledField(
                label: f.label,
                ctrl: f.ctrl,
                hint: f.hint,
                keyboard: f.keyboard,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: _red,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Save Contact',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Labeled text field ─────────────────────────────────────────────────────────
class _LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String hint;
  final TextInputType keyboard;

  const _LabeledField({
    required this.label,
    required this.ctrl,
    required this.hint,
    this.keyboard = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboard,
          style: GoogleFonts.inter(fontSize: 15, color: _ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(fontSize: 14, color: _mid),
            filled: true,
            fillColor: _bg,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _light),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _light),
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
