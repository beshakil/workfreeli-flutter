import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// Call log entry model
class CallLogEntry {
  final String contactName;
  final String? avatarUrl;
  final bool isVideoCall;
  final CallType callType;
  final DateTime timestamp;
  final int callCount;
  final bool isGroupCall;
  final int? participantCount;

  CallLogEntry({
    required this.contactName,
    this.avatarUrl,
    required this.isVideoCall,
    required this.callType,
    required this.timestamp,
    this.callCount = 1,
    this.isGroupCall = false,
    this.participantCount,
  });
}

enum CallType { missed, dialed, received }

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CallLogEntry> get _demoCalls => [
        CallLogEntry(
          contactName: 'Sarah Mitchell',
          isVideoCall: true,
          callType: CallType.missed,
          timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
        ),
        CallLogEntry(
          contactName: 'Project Alpha Team',
          isVideoCall: true,
          callType: CallType.received,
          timestamp:
              DateTime.now().subtract(const Duration(hours: 1, minutes: 30)),
          isGroupCall: true,
          participantCount: 5,
        ),
        CallLogEntry(
          contactName: 'James Rodriguez',
          isVideoCall: false,
          callType: CallType.received,
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        CallLogEntry(
          contactName: 'Emily Chen',
          isVideoCall: true,
          callType: CallType.dialed,
          timestamp:
              DateTime.now().subtract(const Duration(hours: 3, minutes: 45)),
        ),
        CallLogEntry(
          contactName: 'Michael Thompson',
          isVideoCall: false,
          callType: CallType.missed,
          timestamp: DateTime.now().subtract(const Duration(hours: 5)),
          callCount: 3,
        ),
        CallLogEntry(
          contactName: 'Design Review Meeting',
          isVideoCall: true,
          callType: CallType.dialed,
          timestamp: DateTime.now().subtract(const Duration(hours: 6)),
          isGroupCall: true,
          participantCount: 8,
        ),
        CallLogEntry(
          contactName: 'Olivia Parker',
          isVideoCall: true,
          callType: CallType.received,
          timestamp: DateTime.now().subtract(const Duration(hours: 8)),
        ),
        CallLogEntry(
          contactName: 'David Kim',
          isVideoCall: false,
          callType: CallType.dialed,
          timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
        ),
        CallLogEntry(
          contactName: 'Marketing Team Sync',
          isVideoCall: false,
          callType: CallType.missed,
          timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
          isGroupCall: true,
          participantCount: 6,
          callCount: 2,
        ),
        CallLogEntry(
          contactName: 'Sophia Anderson',
          isVideoCall: true,
          callType: CallType.missed,
          timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 5)),
          callCount: 2,
        ),
      ];

  String _formatRelativeTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  String _formatTime(DateTime timestamp) {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Color _getCallStatusColor(CallType callType) {
    switch (callType) {
      case CallType.missed:
        return AppTheme.danger;
      case CallType.dialed:
      case CallType.received:
        return AppTheme.success;
    }
  }

  IconData _getCallStatusIcon(CallType callType) {
    switch (callType) {
      case CallType.missed:
        return Icons.call_received;
      case CallType.dialed:
        return Icons.call_made;
      case CallType.received:
        return Icons.call_received;
    }
  }

  Widget _buildAvatar(String name, String? avatarUrl, bool isGroupCall) {
    if (avatarUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(isGroupCall ? 14 : 25),
        child: CircleAvatar(
          radius: 25,
          backgroundImage: NetworkImage(avatarUrl),
        ),
      );
    }

    final initials = name.split(' ').map((e) => e[0]).take(2).join();
    // Match chat_screen.dart gradient patterns
    final gradients = [
      const [Color(0xFF6366F1), Color(0xFF8B5CF6)], // Indigo to Purple
      const [Color(0xFFEC4899), Color(0xFFF43F5E)], // Pink to Rose
      const [Color(0xFF3B82F6), Color(0xFF06B6D4)], // Blue to Cyan
      const [Color(0xFF10B981), Color(0xFF059669)], // Emerald to Green
      const [Color(0xFFF59E0B), Color(0xFFEF4444)], // Amber to Red
    ];
    final gradientIndex = name.hashCode.abs() % gradients.length;
    final borderRadius = isGroupCall ? 14.0 : 25.0;

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradients[gradientIndex],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: Text(
          initials.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildCallEntry(CallLogEntry call) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(
          bottom: BorderSide(color: AppTheme.border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          _buildAvatar(call.contactName, call.avatarUrl, call.isGroupCall),
          const SizedBox(width: 14),
          // Contact info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          if (call.isGroupCall)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.group_rounded,
                                    size: 12,
                                    color: AppTheme.accent,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${call.participantCount}',
                                    style: AppTheme.caption.copyWith(
                                      color: AppTheme.accent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: Text(
                              call.contactName,
                              style: AppTheme.bodyLarge.copyWith(
                                fontWeight: FontWeight.w600,
                                color: call.callType == CallType.missed
                                    ? AppTheme.danger
                                    : AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (call.callCount > 1)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${call.callCount}',
                          style: AppTheme.caption.copyWith(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      _getCallStatusIcon(call.callType),
                      size: 14,
                      color: _getCallStatusColor(call.callType),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatRelativeTime(call.timestamp),
                      style: AppTheme.bodySmall,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '•',
                      style: AppTheme.bodySmall,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(call.timestamp),
                      style: AppTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Call type indicator
          Icon(
            call.isVideoCall ? Icons.videocam_rounded : Icons.phone_rounded,
            size: 20,
            color: AppTheme.textMuted,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredCalls = _applySearchFilter(_demoCalls);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            // Call log list
            Expanded(
              child: filteredCalls.isEmpty && _searchQuery.isNotEmpty
                  ? _buildNoResults()
                  : ListView.builder(
                      itemCount: filteredCalls.length,
                      itemBuilder: (context, index) {
                        return _buildCallEntry(filteredCalls[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: AppTheme.bgCard,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.bgElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: TextField(
          controller: _searchController,
          style: AppTheme.bodyMedium,
          onChanged: (v) => setState(() => _searchQuery = v),
          decoration: InputDecoration(
            hintText: 'Search calls…',
            hintStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.textDim),
            prefixIcon:
                Icon(Icons.search_rounded, color: AppTheme.textDim, size: 18),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: Icon(Icons.close_rounded,
                        color: AppTheme.textDim, size: 18),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: AppTheme.textDim),
          const SizedBox(height: 16),
          Text('No results for "$_searchQuery"',
              style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  List<CallLogEntry> _applySearchFilter(List<CallLogEntry> calls) {
    if (_searchQuery.isEmpty) {
      return calls;
    }

    return calls
        .where((call) =>
            call.contactName.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }
}
