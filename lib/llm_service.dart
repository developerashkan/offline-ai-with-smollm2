import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smollm2/smollm2.dart';

/// A single message in the conversation history.
class _Message {
  final String role; // 'system' | 'user' | 'assistant'
  final String content;
  const _Message(this.role, this.content);
}

class LLMService {
  SmolLM2? _model;
  bool _isLoading = false;

  // Structured history – never stored as a raw prompt string.
  final List<_Message> _history = [];

  static const String _systemPrompt =
      'You are a helpful, concise offline assistant running on a mobile device.';

  bool get isLoaded => _model != null;
  bool get isLoading => _isLoading;

  // ---------------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------------

  Future<void> loadDefaultModel() async {
    _isLoading = true;
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/smollm2-q16.bin';
      final file = File(path);

      if (!await file.exists()) {
        final data = await rootBundle.load('assets/smollm2-q16.bin');
        final bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await file.writeAsBytes(bytes);
      }

      await loadModel(path);
    } finally {
      _isLoading = false;
    }
  }

  Future<void> loadModel(String path) async {
    _isLoading = true;
    try {
      final model = SmolLM2();
      await model.load(path);
      _model = model;
      _resetHistory();
    } finally {
      _isLoading = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Generation
  // ---------------------------------------------------------------------------

  Stream<String> generateResponse(String userPrompt) async* {
    if (_model == null) {
      yield 'Error: Model not loaded';
      return;
    }

    // Add user turn to structured history.
    _history.add(_Message('user', userPrompt));

    // Build the full prompt string fresh from structured history.
    final prompt = _buildPrompt();

    final controller = StreamController<String>();
    String rawAccumulated = '';

    _model!
        .generate(
      prompt,
      maxTokens: 500,
      temperature: 0.7,
      onTokenEmitted: (token, text, origin) {
        rawAccumulated += text;
        // Stream the cleaned incremental output.
        controller.add(_extractNewOutput(rawAccumulated, prompt));
      },
    )
        .then((result) {
      // Store only the clean assistant reply in history.
      final finalClean = _extractNewOutput(result.output, prompt);
      _history.add(_Message('assistant', finalClean));
      controller.close();
    })
        .catchError((e) {
      controller.addError(e);
      controller.close();
    });

    await for (final cleaned in controller.stream) {
      yield cleaned;
    }
  }

  // ---------------------------------------------------------------------------
  // Prompt builder
  // ---------------------------------------------------------------------------

  /// Builds the raw prompt string the model expects, in
  /// [role\ncontent] format used by SmolLM2's ChatSession.
  String _buildPrompt() {
    final sb = StringBuffer();
    for (final msg in _history) {
      sb.write('[${msg.role}\n${msg.content}]\n\n\n');
    }
    // Append the opening assistant tag so the model knows to continue as AI.
    sb.write('[assistant\n');
    return sb.toString();
  }

  // ---------------------------------------------------------------------------
  // Output cleaning
  // ---------------------------------------------------------------------------

  /// Strips the echoed prompt from the model output and returns only
  /// the new assistant text. Works correctly even during streaming.
  String _extractNewOutput(String rawOutput, String prompt) {
    String cleaned = rawOutput;

    // Strategy 1 – the model echoed the full prompt at the start.
    if (cleaned.startsWith(prompt)) {
      cleaned = cleaned.substring(prompt.length);
    } else if (prompt.startsWith(cleaned)) {
      // Still streaming through the prompt portion – nothing to show yet.
      return '';
    }

    // Strategy 2 – find the LAST [assistant marker and take everything after.
    // This is the robust fallback when the model doesn't echo perfectly.
    const assistantTag = '[assistant';
    final lastIdx = cleaned.lastIndexOf(assistantTag);
    if (lastIdx != -1) {
      final afterTag = cleaned.substring(lastIdx + assistantTag.length);
      // Skip the role delimiter (newline after [assistant).
      final newlineIdx = afterTag.indexOf('\n');
      cleaned = newlineIdx != -1
          ? afterTag.substring(newlineIdx + 1)
          : afterTag;
    }

    // Strip any stray role tags that may have leaked through.
    cleaned = cleaned
        .replaceAll(RegExp(r'\[/?system[^\]]*\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[/?user[^\]]*\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[/?assistant[^\]]*\]', caseSensitive: false), '')
    // Remove the closing ] the model appends at end of turn.
        .replaceAll(RegExp(r'\]\s*$'), '')
        .trim();

    return cleaned;
  }

  // ---------------------------------------------------------------------------
  // History management
  // ---------------------------------------------------------------------------

  void clearHistory() => _resetHistory();

  void _resetHistory() {
    _history.clear();
    _history.add(_Message('system', _systemPrompt));
  }
}