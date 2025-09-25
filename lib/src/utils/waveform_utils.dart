import 'dart:math';

/// 🌊 Utilidades para generar y procesar waveforms de audio
class WaveformUtils {
  /// Genera waveform simulado para UI
  static List<int> generateSimulatedWaveform({
    final int length = 50,
    final int maxAmplitude = 100,
    final int? seed,
  }) {
    final random = Random(seed ?? DateTime.now().millisecondsSinceEpoch);
    return List.generate(length, (final i) => random.nextInt(maxAmplitude));
  }

  /// Procesa bytes de audio reales para extraer waveform
  static List<int> extractWaveformFromBytes(
    final List<int> audioBytes, {
    final int targetLength = 50,
    final int maxAmplitude = 100,
  }) {
    if (audioBytes.isEmpty) return List.filled(targetLength, 0);

    // Samplear los bytes de audio
    final step = audioBytes.length / targetLength;
    final waveform = <int>[];

    for (int i = 0; i < targetLength; i++) {
      final index = (i * step).floor();
      if (index < audioBytes.length) {
        // Normalizar el byte a rango 0-maxAmplitude
        final normalizedValue =
            (audioBytes[index].abs() / 255 * maxAmplitude).round();
        waveform.add(normalizedValue);
      } else {
        waveform.add(0);
      }
    }

    return waveform;
  }

  /// Anima waveform durante grabación
  static List<int> animateRecordingWaveform(
    final Duration recordingDuration, {
    final int length = 50,
    final int maxAmplitude = 100,
  }) {
    final millis = recordingDuration.inMilliseconds;
    final seed = millis ~/ 100; // Cambia cada 100ms
    return generateSimulatedWaveform(
      length: length,
      maxAmplitude: maxAmplitude,
      seed: seed,
    );
  }
}
