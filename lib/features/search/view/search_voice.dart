import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Microphone search. Hidden by the page once the recognizer cannot start.
class SearchVoice {
  SpeechToText? _speech;
  var available = true;
  var listening = false;
  var _disposed = false;
  var _reported = false;

  Future<void> stop() async {
    listening = false;
    final speech = _speech;
    if (speech == null) return;
    try {
      await speech.stop();
    } on Object {
      // The recognizer was never started, or the plugin is missing in tests.
    }
  }

  void dispose() {
    _disposed = true;
    unawaited(stop());
  }

  Future<void> toggle({
    required ValueChanged<String> onTranscript,
    required VoidCallback onUpdate,
    required ValueChanged<String> onUnavailable,
  }) async {
    if (_disposed) return;
    if (listening) {
      await stop();
      if (!_disposed) onUpdate();
      return;
    }
    _reported = false;
    final speech = _speech ??= SpeechToText();
    try {
      final ready = await speech.initialize(
        onError: (error) {
          listening = false;
          if (_disposed) return;
          onUpdate();
          if (!_shouldToast(error) || _reported) return;
          _reported = true;
          if (error.permanent && _missingRecognizer(error)) available = false;
          onUnavailable(_message(error));
        },
        onStatus: (status) {
          if (_disposed) return;
          if (status == 'listening') {
            listening = true;
            onUpdate();
          } else if (status == 'notListening' || status == 'done') {
            listening = false;
            onUpdate();
          }
        },
      );
      if (_disposed) return;
      if (!ready) {
        available = false;
        listening = false;
        if (!_reported) onUnavailable('Voice search needs microphone access.');
        return;
      }
      await speech.listen(
        onResult: (result) {
          if (_disposed) return;
          final words = result.recognizedWords.trim();
          if (words.isEmpty) return;
          onTranscript(words);
          if (result.finalResult) {
            listening = false;
            onUpdate();
          }
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.search,
          cancelOnError: true,
          pauseFor: const Duration(seconds: 3),
          listenFor: const Duration(seconds: 20),
        ),
      );
      if (_disposed) return;
      listening = true;
      onUpdate();
    } on Object {
      if (_disposed) return;
      available = false;
      listening = false;
      if (!_reported) onUnavailable("Voice search isn't available right now.");
    }
  }
}

bool _shouldToast(SpeechRecognitionError error) {
  final message = error.errorMsg.toLowerCase();
  if (message.contains('no_match') || message.contains('timeout')) return false;
  if (message.contains('permission') || message.contains('denied') || message.contains('notallowed')) return true;
  return error.permanent || _missingRecognizer(error);
}

bool _missingRecognizer(SpeechRecognitionError error) {
  final message = error.errorMsg.toLowerCase();
  return message.contains('recognizer') || message.contains('not_available') || message.contains('unavailable');
}

String _message(SpeechRecognitionError error) {
  final message = error.errorMsg.toLowerCase();
  if (message.contains('permission') || message.contains('denied') || message.contains('notallowed')) {
    return 'Voice search needs microphone access.';
  }
  return "Voice search isn't available right now.";
}
