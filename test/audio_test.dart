import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stickman_physics/game/audio.dart';

/// Reads a WAV header: (channels, sample rate, bits, seconds).
(int, int, int, double) _wavInfo(File f) {
  final b = f.readAsBytesSync();
  final d = b.buffer.asByteData();
  expect(String.fromCharCodes(b.sublist(0, 4)), 'RIFF');
  expect(String.fromCharCodes(b.sublist(8, 12)), 'WAVE');
  final channels = d.getUint16(22, Endian.little);
  final rate = d.getUint32(24, Endian.little);
  final bits = d.getUint16(34, Endian.little);
  final dataBytes = d.getUint32(40, Endian.little);
  return (channels, rate, bits, dataBytes / (rate * channels * bits / 8));
}

void main() {
  test('audio is disabled automatically under flutter test', () {
    expect(GameAudio.disabled, isTrue);
    GameAudio.instance.play('hit'); // must not throw without an audio device
    GameAudio.instance.music('boss');
  });

  test('every sound and music file the game uses exists and is a valid WAV', () {
    final game = File('lib/game/school_game.dart').readAsStringSync() +
        File('lib/game/audio.dart').readAsStringSync() +
        File('lib/main.dart').readAsStringSync() +
        File('lib/menu_overlay.dart').readAsStringSync() +
        File('lib/pause_overlay.dart').readAsStringSync();
    final used = {
      ...RegExp(r"play\('(\w+)'\)").allMatches(game).map((m) => m.group(1)!),
      ...RegExp(r"play\([^;]*?'(\w+)' : '(\w+)'\)").allMatches(game).expand((m) => [m.group(1)!, m.group(2)!]),
      'menu', 'explore', 'boss', 'final', 'rest', 'demon',
    };
    for (final name in used) {
      final f = File('assets/audio/$name.wav');
      expect(f.existsSync(), isTrue, reason: 'missing assets/audio/$name.wav');
      final (channels, rate, bits, secs) = _wavInfo(f);
      expect((channels, rate, bits), (1, 22050, 16), reason: name);
      expect(secs, greaterThan(0.02), reason: name);
    }
    for (final track in ['menu', 'explore', 'boss', 'final', 'rest', 'demon']) {
      expect(_wavInfo(File('assets/audio/$track.wav')).$4, greaterThan(15), reason: '$track should be a full loop');
    }
    expect(File('pubspec.yaml').readAsStringSync(), contains('- assets/audio/'));
  });
}
