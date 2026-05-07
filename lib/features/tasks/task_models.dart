import 'package:intl/intl.dart';

/// Safely converts any JSON value to a nullable String.
/// Handles null, String, num, and bool without throwing.
String? _toStr(dynamic v) {
  if (v == null) return null;
  if (v is String) return v.isEmpty ? null : v;
  return v.toString();
}

/// Parses an ISO 8601 string OR a millisecond-epoch integer string.
DateTime? _parseDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw) ??
      (int.tryParse(raw) != null
          ? DateTime.fromMillisecondsSinceEpoch(int.parse(raw))
          : null);
}

class Task {
  final String id;
  final String title;
  final String status;
  final String? priority;
  final String? startDate;
  final String? endDate;
  final String? dueTime;
  final int progress;
  final String? notes;
  final String? description;
  final List<String> assignTo;
  final String? conversationId;
  final String? conversationName;
  final String? projectId;
  final String? projectTitle;
  final bool isArchived;
  final bool hasDelete;
  final String createdBy;
  final String? createdAt;

  const Task({
    required this.id,
    required this.title,
    required this.status,
    this.priority,
    this.startDate,
    this.endDate,
    this.dueTime,
    this.progress = 0,
    this.notes,
    this.description,
    this.assignTo = const [],
    this.conversationId,
    this.conversationName,
    this.projectId,
    this.projectTitle,
    this.isArchived = false,
    this.hasDelete = false,
    this.createdBy = '',
    this.createdAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['_id'] as String? ?? '',
        title: json['task_title'] as String? ?? 'Untitled',
        status: json['status'] as String? ?? 'todo',
        priority: _toStr(json['priority']),
        startDate: _toStr(json['start_date']),
        endDate: _toStr(json['end_date']),
        dueTime: _toStr(json['due_time']),
        progress: json['progress'] as int? ?? 0,
        notes: _toStr(json['notes']),
        description: _toStr(json['description']),
        assignTo: (json['assign_to'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        conversationId: _toStr(json['conversation_id']),
        conversationName: _toStr(json['conversation_name']),
        projectId: _toStr(json['project_id']),
        projectTitle: _toStr(json['project_title']),
        isArchived: json['is_archive'] as bool? ?? false,
        // has_delete is [String] in backend (list of user IDs with delete rights)
        hasDelete: switch (json['has_delete']) {
          bool b   => b,
          List l   => l.isNotEmpty,
          _        => false,
        },
        createdBy: json['created_by'] as String? ?? '',
        createdAt: _toStr(json['created_at']),
      );

  // Maps ALL known backend status strings to the five Kanban column keys.
  String get normalizedStatus {
    switch (status.toLowerCase().trim()) {
      case 'todo':
      case 'to_do':
      case 'to-do':
      case 'not started':
      case 'notstarted':
      case 'not_started':
        return 'not_started';
      case 'inprogress':
      case 'in_progress':
      case 'in-progress':
      case 'in progress':
      case 'doing':
      case 'review':
      case 'in_review':
      case 'in review':
        return 'inprogress';
      case 'on hold':
      case 'onhold':
      case 'on_hold':
        return 'on_hold';
      case 'canceled':
      case 'cancelled':
        return 'canceled';
      case 'done':
      case 'complete':
      case 'completed':
        return 'completed';
      default:
        return 'not_started';
    }
  }

  /// Absolute "d MMM" date for the Kanban card — prefers startDate, then endDate, then createdAt.
  String get formattedCardDate {
    final dt = _parseDate(startDate) ?? _parseDate(endDate) ?? _parseDate(createdAt);
    if (dt == null) return '';
    return DateFormat('d MMM').format(dt);
  }

  /// Returns a short label like "Jan 15" for the due date.
  String get formattedDueDate {
    final dt = _parseDate(endDate);
    if (dt != null) return _shortDate(dt);
    return '';
  }

  /// "Created X ago" label, always present when createdAt exists.
  String get formattedCreatedAt {
    final dt = _parseDate(createdAt);
    if (dt == null) return '';
    return _relativeTime(dt);
  }

  /// "Jan 15" or "Jan 15, 2024" helper.
  static String _shortDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year) {
      return DateFormat('MMM d').format(dt);
    }
    return DateFormat('MMM d, yyyy').format(dt);
  }

  static String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  bool get isOverdue {
    if (normalizedStatus == 'completed') return false;
    final dt = _parseDate(endDate);
    if (dt == null) return false;
    return dt.isBefore(DateTime.now());
  }
}
