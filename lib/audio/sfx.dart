import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SfxKind { reveal, flag, chord, mine, win, lose, chat }

/// Pre-synthesises tiny WAV clips at startup and plays them through one
/// `AudioPlayer` per kind. No audio assets need to be shipped.
class SoundService {
  SoundService();

  bool muted = false;

  final Map<SfxKind, AudioPlayer> _players = {};
  final Map<SfxKind, Uint8List> _bytes = {};
  Future<void>? _initialising;

  Future<void> init() {
    return _initialising ??= _doInit();
  }

  Future<void> _doInit() async {
    for (final kind in SfxKind.values) {
      _bytes[kind] = _synthesize(kind);
      final p = AudioPlayer();
      try {
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setPlayerMode(PlayerMode.lowLatency);
      } catch (_) {}
      _players[kind] = p;
    }
  }

  Future<void> play(SfxKind kind) async {
    if (muted) return;
    await init();
    final p = _players[kind];
    final b = _bytes[kind];
    if (p == null || b == null) return;
    try {
      await p.stop();
      await p.play(BytesSource(b, mimeType: 'audio/wav'));
    } catch (_) {
      // Some platforms / browsers block audio until first user gesture;
      // we silently ignore failures.
    }
  }

  Future<void> dispose() async {
    for (final p in _players.values) {
      try {
        await p.dispose();
      } catch (_) {}
    }
    _players.clear();
    _bytes.clear();
  }
}

// ─────────────────────────────────── Synthesis ─────────────────────────────────

const int _sampleRate = 22050;

Uint8List _synthesize(SfxKind kind) {
  switch (kind) {
    case SfxKind.reveal:
      return _renderWav(
        durationSec: 0.06,
        wave: (t) {
          final env = exp(-t * 60);
          return env * sin(2 * pi * 880 * t) * 0.35;
        },
      );
    case SfxKind.flag:
      return _renderWav(
        durationSec: 0.12,
        wave: (t) {
          final env = exp(-t * 22);
          final f = 600 + 1400 * t;
          return env * sin(2 * pi * f * t) * 0.4;
        },
      );
    case SfxKind.chord:
      return _renderWav(
        durationSec: 0.09,
        wave: (t) {
          final env = exp(-t * 35);
          // Tiny burst of filtered noise for a "brush" feel.
          final noise = (_rng.nextDouble() - 0.5);
          final tone = sin(2 * pi * 1500 * t) * 0.3;
          return env * (noise * 0.45 + tone) * 0.5;
        },
      );
    case SfxKind.mine:
      return _renderWav(
        durationSec: 0.55,
        wave: (t) {
          final env = exp(-t * 4);
          final f = 220 * exp(-t * 4) + 60;
          final noise = (_rng.nextDouble() - 0.5) * 0.6;
          return env * (sin(2 * pi * f * t) * 0.7 + noise) * 0.55;
        },
      );
    case SfxKind.win:
      // C-E-G arpeggio (523, 659, 784 Hz).
      return _renderWav(
        durationSec: 0.6,
        wave: (t) {
          final freqs = [523.25, 659.25, 783.99, 1046.5];
          final step = (t / 0.13).floor().clamp(0, freqs.length - 1);
          final local = t - step * 0.13;
          final env = (local < 0.01)
              ? local / 0.01
              : exp(-(local - 0.01) * 12);
          return env * sin(2 * pi * freqs[step] * t) * 0.32;
        },
      );
    case SfxKind.lose:
      return _renderWav(
        durationSec: 0.45,
        wave: (t) {
          final env = exp(-t * 5);
          final f = 600 * exp(-t * 6) + 110;
          return env * sin(2 * pi * f * t) * 0.45;
        },
      );
    case SfxKind.chat:
      return _renderWav(
        durationSec: 0.18,
        wave: (t) {
          final env = exp(-t * 28);
          final tone = sin(2 * pi * 1040 * t) * 0.5
              + sin(2 * pi * 1560 * t) * 0.25;
          return env * tone * 0.38;
        },
      );
  }
}

final _rng = Random(0x5eed);

Uint8List _renderWav({
  required double durationSec,
  required double Function(double t) wave,
}) {
  final samples = (durationSec * _sampleRate).round();
  final dataBytes = samples * 2;
  final out = ByteData(44 + dataBytes);

  // RIFF chunk
  _writeAscii(out, 0, 'RIFF');
  out.setUint32(4, 36 + dataBytes, Endian.little);
  _writeAscii(out, 8, 'WAVE');

  // fmt subchunk
  _writeAscii(out, 12, 'fmt ');
  out.setUint32(16, 16, Endian.little); // PCM header size
  out.setUint16(20, 1, Endian.little); // PCM format
  out.setUint16(22, 1, Endian.little); // mono
  out.setUint32(24, _sampleRate, Endian.little);
  out.setUint32(28, _sampleRate * 2, Endian.little); // byte rate
  out.setUint16(32, 2, Endian.little); // block align
  out.setUint16(34, 16, Endian.little); // bits per sample

  // data subchunk
  _writeAscii(out, 36, 'data');
  out.setUint32(40, dataBytes, Endian.little);

  for (var i = 0; i < samples; i++) {
    final t = i / _sampleRate;
    final v = wave(t).clamp(-1.0, 1.0);
    final sample = (v * 32767).round();
    out.setInt16(44 + i * 2, sample, Endian.little);
  }

  return out.buffer.asUint8List();
}

void _writeAscii(ByteData out, int offset, String s) {
  for (var i = 0; i < s.length; i++) {
    out.setUint8(offset + i, s.codeUnitAt(i));
  }
}

// ─────────────────────────────────── Provider ──────────────────────────────────

final soundProvider = Provider<SoundService>((ref) {
  final s = SoundService();
  unawaited(s.init());
  ref.onDispose(() => unawaited(s.dispose()));
  return s;
});

final mutedProvider = NotifierProvider<MutedNotifier, bool>(MutedNotifier.new);

class MutedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() {
    state = !state;
    ref.read(soundProvider).muted = state;
  }
}
