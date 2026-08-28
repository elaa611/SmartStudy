import 'package:flutter/material.dart';

/// One chat message.
class _ChatMessage {
  const _ChatMessage({required this.text, required this.fromUser});

  final String text;
  final bool fromUser;
}

/// Chat content rendered inside the modal bottom sheet.
class ChatModal extends StatefulWidget {
  const ChatModal({super.key});

  @override
  State<ChatModal> createState() => _ChatModalState();
}

class _ChatModalState extends State<ChatModal> {
  static const Color primaryNavy = Color(0xFF0B1F5C);
  static const Color background = Color(0xFFF3F5F9);

  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = const [
    _ChatMessage(text: 'Bonjour! Je suis ton assistant SmartStudy.', fromUser: false),
  ];

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(text: text, fromUser: true));
      _inputController.clear();
    });
    _scrollToBottom();
    // TODO: wire this up to the SmartStudy AI backend. For now it only echoes
    // the user's message locally so the input bar isn't a dead button.
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle + close button
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                const SizedBox(width: 48),
                Expanded(
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          // Header: SmartStudy title + AI Chat badge
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                Text(
                  'SmartStudy',
                  style: TextStyle(
                    fontFamily: 'Pacifico',
                    fontSize: 22,
                    color: primaryNavy,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 222, 230, 255),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.smart_toy_outlined,
                          size: 16, color: primaryNavy),
                      SizedBox(width: 4),
                      Text(
                        'AI Chat',
                        style: TextStyle(
                          color: primaryNavy,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE0E3EB)),
          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                return _MessageBubble(text: m.text, fromUser: m.fromUser);
              },
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE0E3EB)),
          // Input bar (rises above the keyboard)
          Padding(
            padding: EdgeInsets.only(
              left: 12,
              right: 4,
              top: 8,
              bottom: 8 + bottomInset,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: primaryNavy),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: primaryNavy),
                  onPressed: _sendMessage,
                  tooltip: 'Send',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.text, required this.fromUser});

  final String text;
  final bool fromUser;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: fromUser ? const Color(0xFF0B1F5C) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: fromUser ? const Radius.circular(16) : Radius.zero,
            bottomRight: fromUser ? Radius.zero : const Radius.circular(16),
          ),
          border: fromUser ? null : Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: fromUser ? Colors.white : const Color(0xFF1A1A2E),
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

/// Opens the AI chat as a modal bottom sheet that slides up from the bottom.
Future<void> showChatModal(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFF3F5F9),
    barrierColor: Colors.black54,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      final height = MediaQuery.of(context).size.height * 0.9;
      return SizedBox(
        height: height,
        child: const ChatModal(),
      );
    },
  );
}