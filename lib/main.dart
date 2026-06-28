import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'chat_message.dart';
import 'llm_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  ));
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmolLM2',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: const ChatScreen(),
      builder: EasyLoading.init(),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6C63FF),
        brightness: brightness,
      ),
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF0F0F13) : const Color(0xFFF6F6FB),
      useMaterial3: true,
      fontFamily: 'Roboto',
    );
  }
}

const List<List<Color>> _gradientSets = [
  [Color(0xFF6C63FF), Color(0xFF48CAE4), Color(0xFF9B59B6)],
  [Color(0xFF48CAE4), Color(0xFF9B59B6), Color(0xFFFF6584)],
  [Color(0xFF9B59B6), Color(0xFFFF6584), Color(0xFF6C63FF)],
  [Color(0xFFFF6584), Color(0xFF6C63FF), Color(0xFF48CAE4)],
];

List<Color> _lerpGradient(int index, double t) {
  final next = (index + 1) % _gradientSets.length;
  return List.generate(
    3,
    (i) => Color.lerp(_gradientSets[index][i], _gradientSets[next][i], t)!,
  );
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final LLMService _llmService = LLMService();
  bool _isGenerating = false;

  late AnimationController _gradientController;
  int _gradientIndex = 0;

  @override
  void initState() {
    super.initState();
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _gradientIndex = (_gradientIndex + 1) % _gradientSets.length;
          });
          _gradientController.forward(from: 0);
        }
      });
    _gradientController.forward();
    _initModel();
  }

  @override
  void dispose() {
    _gradientController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initModel() async {
    try {
      await _llmService.loadDefaultModel();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load model: $e')),
        );
      }
    }
  }

  void _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty || !_llmService.isLoaded || _isGenerating) return;

    _textController.clear();

    setState(() {
      _messages.add(ChatMessage(
        text: text,
        sender: MessageSender.user,
        timestamp: DateTime.now(),
      ));
      _isGenerating = true;
      _messages.add(ChatMessage(
        text: '',
        sender: MessageSender.ai,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();

    // Show modern global loading overlay
    EasyLoading.show(status: 'Thinking...');

    try {
      await for (final cleaned in _llmService.generateResponse(text)) {
        if (!mounted) break;
        
        // Hide overlay as soon as first token arrives
        if (EasyLoading.isShow) EasyLoading.dismiss();

        setState(() {
          _messages.last = ChatMessage(
            text: cleaned,
            sender: MessageSender.ai,
            timestamp: _messages.last.timestamp,
          );
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.last = ChatMessage(
            text: 'Error: $e',
            sender: MessageSender.ai,
            timestamp: _messages.last.timestamp,
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
        EasyLoading.dismiss();
      }
    }
  }

  void _pickModel() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      try {
        await _llmService.loadModel(path);
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Model loaded!')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
      if (mounted) setState(() {});
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPad = MediaQuery.of(context).padding.top;
    final botPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: _buildBackground(isDark),
          ),
          Column(
            children: [
              _AnimatedHeader(
                controller: _gradientController,
                gradientIndex: _gradientIndex,
                isDark: isDark,
                isLoaded: _llmService.isLoaded,
                topPad: topPad,
                onClear: () => setState(() {
                  _messages.clear();
                  _llmService.clearHistory();
                }),
                onPickModel: _pickModel,
              ),
              Expanded(
                child: _llmService.isLoading
                    ? _buildLoadingState()
                    : _messages.isEmpty && !_llmService.isLoaded
                        ? _buildEmptyState(isDark)
                        : _buildMessageList(isDark),
              ),
              _buildInputArea(isDark, botPad),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(bool isDark) {
    final bgColor = isDark ? const Color(0xFF0F0F13) : const Color(0xFFF6F6FB);

    return AnimatedBuilder(
      animation: _gradientController,
      builder: (context, _) {
        final colors = _lerpGradient(_gradientIndex, _gradientController.value);
        return Container(
          decoration: BoxDecoration(color: bgColor),
          child: Align(
            alignment: Alignment.topCenter,
            child: FractionallySizedBox(
              heightFactor: 0.55,
              widthFactor: 1.0,
              child: ShaderMask(
                shaderCallback: (rect) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Colors.transparent],
                  stops: [0.0, 1.0],
                ).createShader(rect),
                blendMode: BlendMode.dstIn,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colors[0].withAlpha((0.55 * 255).toInt()),
                        colors[1].withAlpha((0.35 * 255).toInt()),
                        colors[2].withAlpha((0.20 * 255).toInt()),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Preparing AI model…'),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _GradientIcon(
              controller: _gradientController,
              gradientIndex: _gradientIndex,
            ),
            const SizedBox(height: 24),
            Text(
              'How can I help you?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'SmolLM2 runs fully offline on your device',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? Colors.white54
                    : const Color(0xFF1A1A2E).withAlpha((0.5 * 255).toInt()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(bool isDark) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) =>
          _ChatBubble(message: _messages[index], isDark: isDark),
    );
  }

  Widget _buildInputArea(bool isDark, double botPad) {
    final bgColor = isDark ? const Color(0xFF1C1C26) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withAlpha((0.08 * 255).toInt())
        : Colors.black.withAlpha((0.06 * 255).toInt());

    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        botPad > 0 ? botPad + 12 : 24,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((isDark ? 0.35 : 0.08 * 255).toInt()),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: TextField(
                  controller: _textController,
                  enabled: _llmService.isLoaded,
                  maxLines: 5,
                  minLines: 1,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Message SmolLM2…',
                    hintStyle: TextStyle(
                      color: Colors.grey,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  onSubmitted: (_) => _handleSend(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 8),
              child: AnimatedBuilder(
                animation: _gradientController,
                builder: (context, _) {
                  final colors = _lerpGradient(_gradientIndex, _gradientController.value);
                  final isEnabled = _llmService.isLoaded && !_isGenerating;
                  
                  return GestureDetector(
                    onTap: isEnabled ? _handleSend : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isEnabled
                            ? LinearGradient(
                                colors: [colors[0], colors[2]],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isEnabled ? null : Colors.grey.withAlpha(80),
                      ),
                      child: const Icon(Icons.arrow_upward_rounded,
                          color: Colors.white, size: 20),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedHeader extends StatelessWidget {
  final AnimationController controller;
  final int gradientIndex;
  final bool isDark;
  final bool isLoaded;
  final double topPad;
  final VoidCallback onClear;
  final VoidCallback onPickModel;

  const _AnimatedHeader({
    required this.controller,
    required this.gradientIndex,
    required this.isDark,
    required this.isLoaded,
    required this.topPad,
    required this.onClear,
    required this.onPickModel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Container(
          child: child,
        );
      },
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, topPad + 12, 8, 16),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(50),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_awesome,
                  color: theme.colorScheme.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SmolLM2',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Offline · On-device',
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (isLoaded)
              IconButton(
                onPressed: onClear,
                icon: Icon(Icons.add_comment_outlined,
                    color: textColor, size: 20),
                tooltip: 'New chat',
              ),
            IconButton(
              onPressed: onPickModel,
              icon: Icon(Icons.folder_open_outlined,
                  color: textColor, size: 20),
              tooltip: 'Load model',
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientIcon extends StatelessWidget {
  final AnimationController controller;
  final int gradientIndex;

  const _GradientIcon({required this.controller, required this.gradientIndex});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final colors = _lerpGradient(gradientIndex, controller.value);
        return Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [colors[0], colors[2]]),
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 32),
        );
      },
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isDark;

  const _ChatBubble({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == MessageSender.user;
    final userBg = isDark ? const Color(0xFF3A3A5C) : const Color(0xFF6C63FF);
    final aiBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final userFg = Colors.white;
    final aiFg = isDark ? Colors.white : const Color(0xFF1A1A2E);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF48CAE4)],
                      ),
                    ),
                    child: const Icon(Icons.auto_awesome,
                        size: 10, color: Colors.white),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'SmolLM2',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
          Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? userBg : aiBg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((isDark ? 0.25 : 0.06 * 255).toInt()),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.text.isEmpty && !isUser ? 'Thinking…' : message.text,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: isUser ? userFg : aiFg,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
