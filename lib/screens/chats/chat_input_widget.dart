import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/conversation_models.dart';
import '../../features/conversations/conversations_providers.dart';
import '../../features/files/file_models.dart' show TagDetails;
import '../../features/xmpp/xmpp_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/tag_selection_sheet.dart';
import 'comming_soon.dart';

class ChatInputWidget extends ConsumerStatefulWidget {
  const ChatInputWidget({
    super.key,
    required this.room,
    required this.selfId,
    required this.msgController,
    required this.focusNode,
    required this.hasText,
    required this.onSendMessage,
    required this.onTextChanged,
  });

  final Room room;
  final String selfId;
  final TextEditingController msgController;
  final FocusNode focusNode;
  final bool hasText;
  final VoidCallback onSendMessage;
  final VoidCallback onTextChanged;

  @override
  ConsumerState<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends ConsumerState<ChatInputWidget> {
  // ── File picker ─────────────────────────────────────────────────────────────

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;

    final args = (
      roomId: widget.room.id,
      selfId: widget.selfId,
      companyId: widget.room.companyId ?? '',
      participantsJoined: widget.room.participants.join(','),
    );
    final notifier = ref.read(messagesProvider(args).notifier);
    for (final f in result.files) {
      if (f.path != null) notifier.addPendingFile(File(f.path!));
    }
  }

  // ── Send (with optional tag selection) ─────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = widget.msgController.text.trim();
    final args = (
      roomId: widget.room.id,
      selfId: widget.selfId,
      companyId: widget.room.companyId ?? '',
      participantsJoined: widget.room.participants.join(','),
    );
    final hasPendingFiles =
        ref.read(messagesProvider(args)).pendingFiles.isNotEmpty;
    if (text.isEmpty && !hasPendingFiles) return;

    // Check XMPP state
    final xmppOnline =
        ref.read(xmppServiceProvider).state == XmppState.connected;
    if (!xmppOnline) {
      debugPrint(
          '[ChatInputWidget] XMPP not connected — message will be sent via GraphQL but real-time push may be delayed');
    }

    // If there are files, offer tag selection before sending.
    List<TagDetails>? selectedTags;
    if (hasPendingFiles) {
      final tags = await showTagSelectionSheet(
        context,
        conversationId: widget.room.id,
      );
      // null means user dismissed the sheet → abort send.
      if (tags == null) return;
      // tags == [] means "skip tags" → proceed with send.
      if (tags.isNotEmpty) selectedTags = tags;
    }

    widget.msgController.clear();

    ref
        .read(messagesProvider(args).notifier)
        .sendMessage(text, selectedTags: selectedTags);
  }

  @override
  Widget build(BuildContext context) {
    final args = (
      roomId: widget.room.id,
      selfId: widget.selfId,
      companyId: widget.room.companyId ?? '',
      participantsJoined: widget.room.participants.join(','),
    );
    final state = ref.watch(messagesProvider(args));
    final isDisabled = widget.room.isClosedFor;

    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: isDisabled
          ? Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_rounded, size: 14, color: AppTheme.textDim),
                  const SizedBox(width: 6),
                  Text('This conversation is closed', style: AppTheme.caption),
                ],
              ),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // ── Text input with integrated icons ──
                Expanded(
                  child: Container(
                    constraints:
                        const BoxConstraints(minHeight: 48, maxHeight: 160),
                    decoration: BoxDecoration(
                      color: AppTheme.bgElevated,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Stack(
                      children: [
                        // Text input (expandable area)
                        Padding(
                          padding: const EdgeInsets.only(
                              left: 84, right: 80, top: 12, bottom: 10),
                          child: TextField(
                            controller: widget.msgController,
                            focusNode: widget.focusNode,
                            style: AppTheme.bodyMedium,
                            maxLines: null,
                            minLines: 1,
                            textInputAction: TextInputAction.send,
                            onChanged: (_) => widget.onTextChanged(),
                            onSubmitted: (_) => _sendMessage(),
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              hintStyle: AppTheme.bodyMedium
                                  .copyWith(color: AppTheme.textDim),
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                              isCollapsed: true,
                            ),
                          ),
                        ),
                        // Left icons: Lock, AI (fixed position)
                        Positioned(
                          left: 6,
                          bottom: 6,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildInlineIcon(
                                icon: Icons.lock_outline_rounded,
                                onTap: () {
                                  _showComingSoon(
                                    title: 'Message Encryption',
                                    description:
                                        'End-to-end encryption for secure messaging is coming soon.',
                                    icon: Icons.lock_outline_rounded,
                                  );
                                },
                              ),
                              const SizedBox(width: 2),
                              _buildInlineIcon(
                                icon: Icons.auto_awesome_rounded,
                                onTap: () {
                                  _showComingSoon(
                                    title: 'AI Assistant',
                                    description:
                                        'AI-powered features to help you write better messages and get quick answers.',
                                    icon: Icons.auto_awesome_rounded,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        // Right icons: Emoji, Camera, Attachment (fixed position)
                        Positioned(
                          right: 6,
                          bottom: 6,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: _buildInlineIcon(
                                  icon: Icons.emoji_emotions_outlined,
                                  onTap: () {
                                    _showComingSoon(
                                      title: 'Emoji Picker',
                                      description:
                                          'Browse and send emojis and stickers in your messages.',
                                      icon: Icons.emoji_emotions_outlined,
                                    );
                                  },
                                ),
                              ),
                              if (!widget.hasText) ...[
                                const SizedBox(width: 2),
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: _buildInlineIcon(
                                    icon: Icons.camera_alt_outlined,
                                    onTap: () {
                                      _showComingSoon(
                                        title: 'Camera',
                                        description:
                                            'Take photos and capture moments directly from the chat.',
                                        icon: Icons.camera_alt_outlined,
                                      );
                                    },
                                  ),
                                ),
                              ],
                              const SizedBox(width: 2),
                              _buildInlineIcon(
                                icon: Icons.attach_file_rounded,
                                onTap: state.isSending ? null : _pickFiles,
                                iconColor: state.pendingFiles.isNotEmpty
                                    ? AppTheme.primary
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Voice/Microphone icon (when not typing) OR Send icon (when typing) - Rightmost position
                if (!widget.hasText)
                  _buildInputIconButton(
                    icon: Icons.mic_none_rounded,
                    onTap: () {
                      _showComingSoon(
                        title: 'Voice Messages',
                        description:
                            'Record and send voice messages to your teammates.',
                        icon: Icons.mic_none_rounded,
                      );
                    },
                    backgroundColor: const Color(0xFF0F2750),
                    iconColor: Colors.white,
                    showBorder: false,
                    iconSize: 22,
                  )
                else
                  SizedBox(
                    height: 48,
                    child: GestureDetector(
                      onTap: state.isSending ? null : _sendMessage,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 48,
                        height: 48,
                        margin: const EdgeInsets.only(bottom: 0),
                        decoration: BoxDecoration(
                          color: state.isSending
                              ? AppTheme.bgElevated
                              : const Color(0xFF0F2750),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: state.isSending
                            ? const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildInlineIcon({
    required IconData icon,
    required VoidCallback? onTap,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        child: Icon(icon, color: iconColor ?? AppTheme.textDim, size: 22),
      ),
    );
  }

  Widget _buildInputIconButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? backgroundColor,
    Color? iconColor,
    bool showBorder = true,
    double iconSize = 20,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: backgroundColor ?? AppTheme.bgElevated,
          borderRadius: BorderRadius.circular(999),
          border: showBorder
              ? Border.all(
                  color: AppTheme.border.withValues(alpha: 0.6),
                  width: 1,
                )
              : null,
        ),
        child: Icon(icon, color: iconColor ?? AppTheme.textDim, size: iconSize),
      ),
    );
  }

  void _showComingSoon({
    required String title,
    String? description,
    IconData? icon,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ComingSoonModal(
        title: title,
        description: description,
        icon: icon,
      ),
    );
  }
}
