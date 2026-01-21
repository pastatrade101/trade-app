import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import 'package:stock_investment_flutter/app/app_icons.dart';

class MessageInput extends StatefulWidget {
  const MessageInput({
    super.key,
    required this.enabled,
    required this.onSend,
    this.hintText,
  });

  final bool enabled;
  final ValueChanged<String> onSend;
  final String? hintText;

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty || text.length > 1000 || !widget.enabled) {
      return;
    }
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: tokens.shadow,
              blurRadius: 12,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: widget.enabled,
                maxLength: 1000,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: widget.hintText ?? 'Type a message',
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: widget.enabled ? _handleSend : null,
              icon: const Icon(AppIcons.send),
            ),
          ],
        ),
      ),
    );
  }
}
