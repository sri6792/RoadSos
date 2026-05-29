import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

const String geminiApiKey =
    "const_api_key";

// ── Palette ────────────────────────────────────────────────────────────────────
const Color _red = Color(0xFFE83000);
const Color _orange = Color(0xFFFF6600);
const Color _amber = Color(0xFFFFAA00);
const Color _white = Color(0xFFFFFFFF);
const Color _ink = Color(0xFF1A1A1A);
const Color _surface = Color(0xFFF7F7F8);

// ── Rotating Conic Gradient Border Painter ────────────────────────────────────
class _RotatingBorderPainter extends CustomPainter {
  final double angle;
  final double glowIntensity;

  _RotatingBorderPainter({required this.angle, required this.glowIntensity});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final radius = Radius.circular(28);
    final rrect = RRect.fromRectAndRadius(rect, radius);

    // Outer glow layers
    for (int i = 3; i >= 1; i--) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = i * 4.0
        ..color = _red.withValues(alpha: 0.06 * glowIntensity * i)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, i * 3.0);
      canvas.drawRRect(rrect, glowPaint);
    }

    // Rotating conic gradient border
    final sweepPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: angle,
        endAngle: angle + math.pi * 2,
        colors: const [
          Colors.transparent,
          Colors.transparent,
          Color(0xFFFF3300),
          Color(0xFFFF6600),
          Color(0xFFFFAA00),
          Color(0xFFFF6600),
          Color(0xFFFF3300),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.45, 0.5, 0.55, 0.6, 0.65, 1.0],
      ).createShader(rect);

    canvas.drawRRect(rrect, sweepPaint);

    // Bright leading edge dot
    final leadX =
        size.width / 2 + (size.width / 2) * math.cos(angle + math.pi * 0.5);
    final leadY =
        size.height / 2 + (size.height / 2) * math.sin(angle + math.pi * 0.5);

    final dotPaint = Paint()
      ..color = _amber.withValues(alpha: 0.9 * glowIntensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(
      Offset(leadX.clamp(4, size.width - 4), leadY.clamp(4, size.height - 4)),
      5,
      dotPaint,
    );

    final dotSolidPaint = Paint()
      ..color = _white.withValues(alpha: glowIntensity);
    canvas.drawCircle(
      Offset(leadX.clamp(4, size.width - 4), leadY.clamp(4, size.height - 4)),
      2.5,
      dotSolidPaint,
    );
  }

  @override
  bool shouldRepaint(_RotatingBorderPainter old) =>
      old.angle != angle || old.glowIntensity != glowIntensity;
}

// ── Main Screen ───────────────────────────────────────────────────────────────
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;
  bool _showSuggestions = true;

  late final GenerativeModel _model;
  late final ChatSession _chat;

  // Aurora float controllers
  late final AnimationController _floatA;
  late final AnimationController _floatB;
  late final AnimationController _floatC;
  late final AnimationController _floatD;

  // Input border rotation
  late final AnimationController _borderRotation;

  // Input ambient glow pulse
  late final AnimationController _glowPulse;

  // Suggestion entrance stagger
  late final AnimationController _suggestionEntrance;

  final List<String> _suggestions = [
    '🚑  First aid steps',
    '🚗  After an accident',
    '🔧  Car broke down',
    '📞  Emergency numbers',
  ];

  @override
  void initState() {
    super.initState();

    // Aurora blobs
    _floatA = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7000),
    )..repeat(reverse: true);
    _floatB = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 9000),
    );
    _floatC = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 11000),
    );
    _floatD = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8500),
    );

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _floatB.repeat(reverse: true);
    });
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) _floatC.repeat(reverse: true);
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _floatD.repeat(reverse: true);
    });

    // Rotating border — continuous 360° spin
    _borderRotation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();

    // Glow pulse
    _glowPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    // Suggestion chips entrance
    _suggestionEntrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    // Gemini model
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: geminiApiKey,
      systemInstruction: Content.system('''
You are RoadSOS AI.
You help with:
- Road safety
- Accident guidance
- First aid
- Emergency advice
Keep replies short and practical.
'''),
    );

    _chat = _model.startChat();

    _messages.add({
      'role': 'ai',
      'text': 'Hi 👋 I\'m RoadSOS AI.\nHow can I help you today?',
      'time': _timeNow(),
    });
  }

  @override
  void dispose() {
    _floatA.dispose();
    _floatB.dispose();
    _floatC.dispose();
    _floatD.dispose();
    _borderRotation.dispose();
    _glowPulse.dispose();
    _suggestionEntrance.dispose();
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _timeNow() {
    final n = DateTime.now();
    final h = n.hour % 12 == 0 ? 12 : n.hour % 12;
    final m = n.minute.toString().padLeft(2, '0');
    final period = n.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  Future<void> _sendMessage([String? overrideText]) async {
    final text = (overrideText ?? _controller.text).trim();
    if (text.isEmpty || _isTyping) return;

    _controller.clear();

    setState(() {
      _messages.add({'role': 'user', 'text': text, 'time': _timeNow()});
      _isTyping = true;
      _showSuggestions = false;
    });

    _scrollBottom();

    try {
      final response = await _chat.sendMessage(Content.text(text));
      final reply = response.text ?? "Sorry, I couldn't reply.";
      setState(() {
        _messages.add({'role': 'ai', 'text': reply, 'time': _timeNow()});
        _isTyping = false;
      });
    } catch (e) {
      setState(() {
        _messages.add({
          'role': 'ai',
          'text': 'Something went wrong. Please try again.',
          'time': _timeNow(),
        });
        _isTyping = false;
      });
    }

    _scrollBottom();
  }

  void _scrollBottom() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  // ── Aurora blob ────────────────────────────────────────────────────────────
  Widget _blobShape({
    required AnimationController ctrl,
    required double width,
    required double height,
    required List<Color> colors,
    required double txMin,
    required double txMax,
    required double tyMin,
    required double tyMax,
  }) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, child) {
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
                center: Alignment.center,
                radius: 1.0,
                colors: colors,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _auroraBackground() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              top: -h * 0.08,
              left: -w * 0.15,
              child: ImageFiltered(
                imageFilter: _blur(52),
                child: _blobShape(
                  ctrl: _floatA,
                  width: w * 1.3,
                  height: h * 0.30,
                  colors: [
                    _red.withValues(alpha: 0.42),
                    _orange.withValues(alpha: 0.20),
                    Colors.transparent,
                  ],
                  txMin: 0,
                  txMax: 14,
                  tyMin: 0,
                  tyMax: 10,
                ),
              ),
            ),
            Positioned(
              top: -h * 0.04,
              right: -w * 0.10,
              child: ImageFiltered(
                imageFilter: _blur(44),
                child: _blobShape(
                  ctrl: _floatB,
                  width: w * 0.90,
                  height: h * 0.22,
                  colors: [
                    _orange.withValues(alpha: 0.28),
                    _amber.withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                  txMin: -14,
                  txMax: 0,
                  tyMin: 0,
                  tyMax: 6,
                ),
              ),
            ),
            Positioned(
              top: h * 0.06,
              left: w * 0.20,
              child: ImageFiltered(
                imageFilter: _blur(40),
                child: _blobShape(
                  ctrl: _floatC,
                  width: w * 0.70,
                  height: h * 0.18,
                  colors: [
                    _amber.withValues(alpha: 0.16),
                    _orange.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                  txMin: 0,
                  txMax: -12,
                  tyMin: -8,
                  tyMax: 0,
                ),
              ),
            ),
            Positioned(
              bottom: -h * 0.06,
              right: -w * 0.10,
              child: ImageFiltered(
                imageFilter: _blur(52),
                child: _blobShape(
                  ctrl: _floatD,
                  width: w * 1.2,
                  height: h * 0.28,
                  colors: [
                    _red.withValues(alpha: 0.36),
                    _orange.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                  txMin: 0,
                  txMax: 10,
                  tyMin: 0,
                  tyMax: -10,
                ),
              ),
            ),
            Positioned(
              bottom: -h * 0.03,
              left: -w * 0.20,
              child: ImageFiltered(
                imageFilter: _blur(48),
                child: _blobShape(
                  ctrl: _floatB,
                  width: w * 0.85,
                  height: h * 0.22,
                  colors: [
                    _orange.withValues(alpha: 0.26),
                    _amber.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                  txMin: -10,
                  txMax: 0,
                  tyMin: 0,
                  tyMax: -6,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  ImageFilter _blur(double sigma) =>
      ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);

  // ── Message bubble ─────────────────────────────────────────────────────────
  Widget _messageBubble(Map<String, dynamic> msg) {
    final isUser = msg['role'] == 'user';
    final text = msg['text'] as String;
    final time = msg['time'] as String? ?? '';

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 380),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(isUser ? 18 * (1 - v) : -18 * (1 - v), 0),
          child: child,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: isUser
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            if (!isUser) ...[
              // AI avatar with gradient ring
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_red, _orange],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _red.withValues(alpha: 0.30),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2.5),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _white.withValues(alpha: 0.95),
                    ),
                    child: const Icon(
                      Icons.emergency_rounded,
                      color: _red,
                      size: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  // Glassmorphic AI bubble / gradient user bubble
                  ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 5),
                      bottomRight: Radius.circular(isUser ? 5 : 20),
                    ),
                    child: BackdropFilter(
                      filter: isUser
                          ? ImageFilter.blur(sigmaX: 0, sigmaY: 0)
                          : ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient: isUser
                              ? const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFFF3A00),
                                    Color(0xFFE83000),
                                    Color(0xFFCC4400),
                                  ],
                                )
                              : null,
                          color: isUser ? null : _white.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: Radius.circular(isUser ? 20 : 5),
                            bottomRight: Radius.circular(isUser ? 5 : 20),
                          ),
                          border: Border.all(
                            color: isUser
                                ? _orange.withValues(alpha: 0.30)
                                : _white.withValues(alpha: 0.60),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isUser
                                  ? _red.withValues(alpha: 0.24)
                                  : Colors.black.withValues(alpha: 0.06),
                              blurRadius: isUser ? 16 : 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          text,
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            height: 1.6,
                            color: isUser ? _white : _ink,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      time,
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        color: const Color(0xFFAAAAAA),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isUser) ...[
              const SizedBox(width: 8),
              // User avatar
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_orange, _amber],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _orange.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2.5),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _white.withValues(alpha: 0.95),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: _orange,
                      size: 15,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Typing indicator ───────────────────────────────────────────────────────
  Widget _typingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [_red, _orange]),
              boxShadow: [
                BoxShadow(
                  color: _red.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(2.5),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _white.withValues(alpha: 0.95),
                ),
                child: const Icon(
                  Icons.emergency_rounded,
                  color: _red,
                  size: 15,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(5),
              bottomRight: Radius.circular(20),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  color: _white.withValues(alpha: 0.78),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(5),
                    bottomRight: Radius.circular(20),
                  ),
                  border: Border.all(color: _white.withValues(alpha: 0.60)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    3,
                    (i) => _BouncingDot(delay: i * 180),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Rotating glow input bar ────────────────────────────────────────────────
  Widget _buildInputBar() {
    return Container(
      decoration: BoxDecoration(
        color: _white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
      child: SafeArea(
        top: false,
        child: AnimatedBuilder(
          animation: Listenable.merge([_borderRotation, _glowPulse]),
          builder: (context, _) {
            final angle = _borderRotation.value * 2 * math.pi;
            final glowIntensity = 0.5 + 0.5 * _glowPulse.value;

            return Stack(
              children: [
                // Ambient glow behind the input
                Positioned.fill(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: _red.withValues(alpha: 0.10 * glowIntensity),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: _orange.withValues(
                            alpha: 0.07 * glowIntensity,
                          ),
                          blurRadius: 36,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
                // Rotating conic gradient border
                CustomPaint(
                  painter: _RotatingBorderPainter(
                    angle: angle,
                    glowIntensity: glowIntensity,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 18),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            onSubmitted: (_) => _sendMessage(),
                            style: GoogleFonts.dmSans(
                              fontSize: 14.5,
                              color: _ink,
                              fontWeight: FontWeight.w400,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Ask for help...',
                              hintStyle: GoogleFonts.dmSans(
                                fontSize: 14.5,
                                color: const Color(0xFFBBBBBB),
                                fontWeight: FontWeight.w400,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.all(5),
                          child: GestureDetector(
                            onTap: _sendMessage,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFFFF3300), _orange],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _red.withValues(
                                      alpha: 0.35 + 0.15 * glowIntensity,
                                    ),
                                    blurRadius: 12 + 4 * glowIntensity,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.send_rounded,
                                color: _white,
                                size: 19,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: Container(
          decoration: BoxDecoration(
            color: _white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Gradient icon container
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_red, _orange, _amber],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _red.withValues(alpha: 0.32),
                          blurRadius: 16,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.emergency_rounded,
                      color: _white,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'ROAD',
                            style: GoogleFonts.bebasNeue(
                              fontSize: 23,
                              letterSpacing: 2.5,
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
                                fontSize: 23,
                                letterSpacing: 2.5,
                                color: _white,
                                height: 1,
                              ),
                            ),
                          ),
                          Text(
                            ' AI',
                            style: GoogleFonts.bebasNeue(
                              fontSize: 23,
                              letterSpacing: 2.5,
                              color: _ink,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Emergency Assistant',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: const Color(0xFF999999),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Online pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF22c55e).withValues(alpha: 0.28),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF22c55e,
                          ).withValues(alpha: 0.10),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PulseDot(),
                        const SizedBox(width: 5),
                        Text(
                          'Online',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF16a34a),
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
      body: Stack(
        children: [
          // Aurora background
          Positioned.fill(child: _auroraBackground()),

          Column(
            children: [
              // Messages
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _DateChip(),
                          const SizedBox(height: 10),
                          _messageBubble(_messages[0]),
                        ],
                      );
                    }
                    if (_isTyping && index == _messages.length) {
                      return _typingIndicator();
                    }
                    return _messageBubble(_messages[index]);
                  },
                ),
              ),

              // Suggestion chips with staggered entrance
              if (_showSuggestions)
                SizedBox(
                  height: 50,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _suggestions.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      return TweenAnimationBuilder<double>(
                        duration: Duration(milliseconds: 400 + i * 80),
                        tween: Tween(begin: 0.0, end: 1.0),
                        curve: Curves.easeOutBack,
                        builder: (_, v, child) => Opacity(
                          opacity: v.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, 12 * (1 - v)),
                            child: child,
                          ),
                        ),
                        child: GestureDetector(
                          onTap: () => _sendMessage(
                            _suggestions[i]
                                .replaceAll(RegExp(r'^[^\w]+'), '')
                                .trim(),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _white.withValues(alpha: 0.90),
                                  _white.withValues(alpha: 0.75),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: _red.withValues(alpha: 0.20),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _red.withValues(alpha: 0.07),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Text(
                              _suggestions[i],
                              style: GoogleFonts.dmSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: _red,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 6),

              // Input bar with rotating glow border
              _buildInputBar(),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Date chip ─────────────────────────────────────────────────────────────────
class _DateChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: _white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _white.withValues(alpha: 0.50)),
            ),
            child: Text(
              'TODAY',
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF999999),
                letterSpacing: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Pulsing green dot ──────────────────────────────────────────────────────────
class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.55,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) => Opacity(
        opacity: _anim.value,
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF22c55e),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF22c55e).withValues(alpha: 0.55),
                blurRadius: 5,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bouncing typing dot ────────────────────────────────────────────────────────
class _BouncingDot extends StatefulWidget {
  final int delay;
  const _BouncingDot({required this.delay});

  @override
  State<_BouncingDot> createState() => _BouncingDotState();
}

class _BouncingDotState extends State<_BouncingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
    _anim = Tween<double>(
      begin: 0.0,
      end: -7.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [_red, _orange]),
          ),
        ),
      ),
    );
  }
}
