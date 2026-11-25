import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

enum Sfx { move, capture, check, gameOver }

class SoundFx {
  static final AudioPlayer _player = AudioPlayer();
  static final Map<Sfx, Uint8List> _cache = {};
  static const int _rate = 22050;

  static Future<void> play(Sfx sfx) async {
    try {
      final bytes = _cache.putIfAbsent(sfx, () => _buildWav(sfx));
      await _player.play(BytesSource(bytes));
    } catch (_) {
      // لو الصوت مش متاح، اللعبة تكمل عادي
    }
  }

  static Uint8List _buildWav(Sfx sfx) {
    final List<(double, int)> notes = switch (sfx) {
      Sfx.move => [(660.0, 70)],
      Sfx.capture => [(220.0, 60), (150.0, 110)],
      Sfx.check => [(880.0, 90), (1175.0, 140)],
      Sfx.gameOver => [(523.0, 160), (659.0, 160), (784.0, 380)],
    };

    final samples = <int>[];
    for (final (freq, ms) in notes) {
      final n = _rate * ms ~/ 1000;
      for (int i = 0; i < n; i++) {
        final t = i / _rate;
        final env = 1 - i / n; // خفوت تدريجي
        final v = sin(2 * pi * freq * t) * env * 0.4;
        samples.add((v * 32767).round());
      }
    }

    // بناء ملف WAV في الذاكرة
    final dataLen = samples.length * 2;
    final bd = ByteData(44 + dataLen);
    void writeStr(int offset, String s) {
      for (int i = 0; i < 4; i++) {
        bd.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    writeStr(0, 'RIFF');
    bd.setUint32(4, 36 + dataLen, Endian.little);
    writeStr(8, 'WAVE');
    writeStr(12, 'fmt ');
    bd.setUint32(16, 16, Endian.little);
    bd.setUint16(20, 1, Endian.little); // PCM
    bd.setUint16(22, 1, Endian.little); // mono
    bd.setUint32(24, _rate, Endian.little);
    bd.setUint32(28, _rate * 2, Endian.little);
    bd.setUint16(32, 2, Endian.little);
    bd.setUint16(34, 16, Endian.little);
    writeStr(36, 'data');
    bd.setUint32(40, dataLen, Endian.little);
    for (int i = 0; i < samples.length; i++) {
      bd.setInt16(44 + i * 2, samples[i], Endian.little);
    }
    return bd.buffer.asUint8List();
  }
}
