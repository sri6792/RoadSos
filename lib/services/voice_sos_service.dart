// lib/services/voice_sos_service.dart
//
// Fixed background voice SOS — four root bugs corrected:
//   1. ListenMode changed from `confirmation` (yes/no only) → `dictation`
//   2. Locale no longer rotates through all 50+ device locales; locked to best
//      single locale (en_IN handles English + Hinglish; hi_IN for pure Hindi)
//   3. partialResults enabled — fires the moment a keyword is heard, not after
//      3 seconds of silence
//   4. Phonetic variants added for Indian keywords (STT mis-transcriptions)

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceSosService {
  static final VoiceSosService instance = VoiceSosService._();
  VoiceSosService._();

  // ── Keywords ───────────────────────────────────────────────────────────────
  // Keep to SHORT, phonetically distinct words.
  // Multi-word phrases are listed as a single string — they match if the full
  // phrase appears anywhere in the transcript.
  //
  // FIX 4: Added phonetic variants for Indian words because STT engines
  // frequently transcribe them differently depending on accent + locale.
  static const _keywords = [
    // English — single-word keywords get exact-word matching (see _exactWords)
    'sos',
    'help',        // added — "help me" often just transcribes as "help"
    'emergency',
    'accident',
    'help me',
    'need help',
    'save me',
    'call ambulance',
    'call police',

    // Hindi — original + common STT mis-transcriptions
    'bachao',      // standard
    'bacha',       // STT sometimes drops the trailing "o"
    'bachav',
    'madad karo',
    'madat karo',  // STT variant
    'ambulance bulao',

    // Marathi
    'vaachva',
    'vachva',      // STT drops the double-a
    'sahaay kara',
    'sahay kara',

    // Tamil
    'udhavi',
    'udavi',       // STT variant
    'avasaram',
    'avasara',

    // Telugu
    'sahayam',
    'pramadam',
    'pramadham',   // STT variant with h

    // Kannada
    'sahaaya',
    'apaghata',
    'apagata',     // STT variant

    // Malayalam
    'sahaayam',
    'apakadam',
    'apakaatam',   // STT variant

    // Bengali
    'shahajjo',
    'sahajjo',     // STT drops the h
    'bipod',
    'bipat',       // regional variant

    // Gujarati
    'bachavo',
    'bachao',      // same as Hindi — intentional overlap
  ];

  // Words that must appear as a complete word, not a substring.
  // e.g. "sos" should not fire on "those", "help" should not fire on "helpful"
  static const _exactWords = {
    'sos', 'help', 'bachao', 'bacha', 'bachav', 'madad',
    'udhavi', 'udavi', 'sahayam', 'sahaaya', 'sahaayam',
    'shahajjo', 'bipod', 'bachavo',
  };

  // ── Timing ─────────────────────────────────────────────────────────────────
  static const _cooldown      = Duration(seconds: 20);
  static const _listenFor     = Duration(seconds: 30); // long window per cycle
  static const _pauseFor      = Duration(seconds: 1);  // FIX 3: was 3 s → 1 s
  static const _restartDelay  = Duration(milliseconds: 500); // was 2 s → 0.5 s

  // ── State ──────────────────────────────────────────────────────────────────
  final SpeechToText _stt = SpeechToText();
  bool _isRunning    = false;
  bool _isListening  = false;
  bool _initialized  = false;
  DateTime? _lastTriggered;
  Timer? _restartTimer;
  String? _bestLocaleId; // FIX 2: single locked locale, chosen once at init

  static const _audioChannel = MethodChannel('com.example.roadsos/audio');

  VoidCallback? onTriggered;
  final ValueNotifier<bool> isListeningNotifier = ValueNotifier(false);

  bool get isRunning => _isRunning;

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<bool> start() async {
    if (_isRunning) return true;

    if (!_initialized) {
      _initialized = await _stt.initialize(
        onError: (e) {
          debugPrint('VoiceSOS error: ${e.errorMsg}');
          if (_isRunning) {
            _isListening = false;
            _restartTimer = Timer(_restartDelay, _listen);
          }
        },
        onStatus: (status) {
          debugPrint('VoiceSOS status: $status');
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
            isListeningNotifier.value = false;
            if (_isRunning) {
              // FIX 2: no locale rotation — just restart on the same locale
              _restartTimer = Timer(_restartDelay, _listen);
            }
          }
        },
      );

      if (_initialized) {
        // FIX 2: pick the single best locale once and lock to it forever
        _bestLocaleId = await _pickBestLocale();
        debugPrint('VoiceSOS: locked locale = $_bestLocaleId');
      }
    }

    if (!_initialized) return false;

    _isRunning = true;
    _listen();
    return true;
  }

  void stop() {
    _isRunning = false;
    _restartTimer?.cancel();
    _stt.stop();
    _isListening = false;
    isListeningNotifier.value = false;
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  /// FIX 2: choose the single best locale.
  /// Priority: en_IN → hi_IN → en_US → device default (null).
  /// en_IN on Google's speech backend handles English AND common Hinglish
  /// (bachao, madad, ambulance) very reliably.
  Future<String?> _pickBestLocale() async {
    final locales = await _stt.locales();
    const preferred = ['en_IN', 'en-IN', 'hi_IN', 'hi-IN', 'en_US', 'en-US'];
    for (final want in preferred) {
      final match = locales.firstWhere(
            (l) => l.localeId == want || l.localeId.startsWith(want.split('_')[0] + '_'),
        orElse: () => LocaleName('', ''),
      );
      if (match.localeId.isNotEmpty) return match.localeId;
    }
    return null; // device default
  }

  Future<void> _listen() async {
    if (!_isRunning || _isListening) return;
    _isListening = true;
    isListeningNotifier.value = true;

    // Mute system beep before STT starts
    try {
      await _audioChannel.invokeMethod('muteBeep');
    } catch (_) {}

    _stt.listen(
      listenFor: _listenFor,
      pauseFor: _pauseFor,
      partialResults: true,
      cancelOnError: false,
      localeId: _bestLocaleId,
      listenMode: ListenMode.dictation,
      onResult: (result) {
        final text = result.recognizedWords.toLowerCase().trim();
        if (text.isEmpty) return;
        debugPrint('VoiceSOS [${result.finalResult ? "FINAL" : "partial"}] '
            '[$_bestLocaleId]: "$text"');
        if (_matchesKeyword(text)) {
          _onKeywordDetected();
        }
      },
    );

    // Unmute after beep window (STT beep plays in first ~400ms)
    await Future.delayed(const Duration(milliseconds: 600));
    try {
      await _audioChannel.invokeMethod('unmuteBeep');
    } catch (_) {}

  }

  /// Returns true if [text] contains any keyword.
  /// For exact-word keywords, the keyword must appear as a whole word
  /// (surrounded by spaces or string boundaries) to avoid sub-word matches.
  bool _matchesKeyword(String text) {
    // Pre-split once for exact-word checks
    final wordSet = RegExp(r'\b\w+\b')
        .allMatches(text)
        .map((m) => m.group(0)!)
        .toSet();

    for (final kw in _keywords) {
      if (_exactWords.contains(kw)) {
        // Whole-word match — "help" must not fire on "helpful"
        if (wordSet.contains(kw)) return true;
      } else {
        // Phrase match — substring is fine for multi-word phrases
        if (text.contains(kw)) return true;
      }
    }
    return false;
  }

  void _onKeywordDetected() {
    final now = DateTime.now();
    if (_lastTriggered != null && now.difference(_lastTriggered!) < _cooldown) {
      debugPrint('VoiceSOS: keyword heard but in cooldown — ignored');
      return;
    }
    _lastTriggered = now;
    debugPrint('VoiceSOS: *** TRIGGERED ***');
    onTriggered?.call();
  }
}