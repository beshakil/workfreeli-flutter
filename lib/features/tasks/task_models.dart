import 'package:intl/intl.dart';

/// Safely converts any JSON value to a nullable String.
String? _toStr(dynamic v) {
  if (v == null) return null;
  if (v is String) return v.isEmpty ? null : v;
  return v.toString();
}

/// Parses an ISO 8601 string OR a millisecond-epoch integer/string.
DateTime? _parseDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw) ??
      (int.tryParse(raw) != null
          ? DateTime.fromMillisecondsSinceEpoch(int.parse(raw))
          : null);
}

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

String _formatFileSize(dynamic raw) {
  if (raw == null) return '';
  final bytes = raw is int ? raw : int.tryParse(raw.toString()) ?? 0;
  if (bytes <= 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

// ── Checklist item ─────────────────────────────────────────────────────────────

class TaskChecklist {
  final String id;
  final String title;
  final bool checked;

  const TaskChecklist({
    required this.id,
    required this.title,
    this.checked = false,
  });

  factory TaskChecklist.fromJson(Map<String, dynamic> json) => TaskChecklist(
        id: json['_id'] as String? ?? '',
        title: json['item_title'] as String? ?? '',
        checked: json['checked'] == true,
      );

  TaskChecklist copyWith({String? title, bool? checked}) => TaskChecklist(
        id: id,
        title: title ?? this.title,
        checked: checked ?? this.checked,
      );
}

// ── Cost breakdown entry ───────────────────────────────────────────────────────

class TaskCostEntry {
  final String id;
  final String? title;
  final double forecastedCost;
  final double actualCost;

  const TaskCostEntry({
    required this.id,
    this.title,
    this.forecastedCost = 0,
    this.actualCost = 0,
  });

  factory TaskCostEntry.fromJson(Map<String, dynamic> json) => TaskCostEntry(
        id: json['_id'] as String? ?? '',
        title: json['cost_title'] as String?,
        forecastedCost: _toDouble(json['forecasted_cost']),
        actualCost: _toDouble(json['actual_cost']),
      );

  double get variance => forecastedCost - actualCost;
}

// ── Hour breakdown entry ───────────────────────────────────────────────────────

class TaskHourEntry {
  final String id;
  final String? fromDate;
  final String? toDate;
  final double forecastedHours;
  final double actualHours;
  final String? note;

  const TaskHourEntry({
    required this.id,
    this.fromDate,
    this.toDate,
    this.forecastedHours = 0,
    this.actualHours = 0,
    this.note,
  });

  factory TaskHourEntry.fromJson(Map<String, dynamic> json) => TaskHourEntry(
        id: json['_id'] as String? ?? '',
        fromDate: _toStr(json['fdate']),
        toDate: _toStr(json['tdate']),
        forecastedHours: _toDouble(json['forecasted_hours']),
        actualHours: _toDouble(json['actual_hour']),
        note: json['note'] as String?,
      );

  double get variance => forecastedHours - actualHours;
}

// ── Task file item ─────────────────────────────────────────────────────────────

class TaskFileItem {
  final String id;
  final String name;
  final String? fileType;
  final String? fileSize;
  final String? location;
  final String? uploadedBy;
  final String? createdAt;
  final List<Map<String, dynamic>> rawTags;

  const TaskFileItem({
    required this.id,
    required this.name,
    this.fileType,
    this.fileSize,
    this.location,
    this.uploadedBy,
    this.createdAt,
    this.rawTags = const [],
  });

  factory TaskFileItem.fromJson(Map<String, dynamic> json) => TaskFileItem(
        id: json['_id'] as String? ?? '',
        name: json['originalname'] as String? ?? 'Unknown file',
        fileType: json['file_type'] as String?,
        fileSize: _formatFileSize(json['file_size']),
        location: json['location']?.toString(),
        uploadedBy: json['uploaded_by']?.toString(),
        createdAt: json['created_at']?.toString(),
        rawTags: (json['tag_list_details'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [],
      );

  bool get isImage {
    final t = fileType?.toLowerCase() ?? '';
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    return t == 'image' ||
        RegExp(r'^(png|jpg|jpeg|gif|webp|bmp|svg)$').hasMatch(ext);
  }

  bool get isVideo {
    final t = fileType?.toLowerCase() ?? '';
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    return t == 'video' ||
        RegExp(r'^(mp4|webm|mov|avi|mkv)$').hasMatch(ext);
  }

  String get displayExt {
    final ext = name.contains('.')
        ? name.split('.').last.toUpperCase()
        : (fileType?.toUpperCase() ?? '');
    return ext.length > 4 ? ext.substring(0, 4) : ext;
  }

  String get formattedDate {
    final dt = _parseDate(createdAt);
    if (dt == null) return '';
    return DateFormat('MMM d, yyyy').format(dt.toLocal());
  }
}

// ── Task message ───────────────────────────────────────────────────────────────

class TaskMessage {
  final String id;
  final String? body;
  final String? createdBy;
  final String? createdAt;
  final List<TaskFileItem> attachments;

  const TaskMessage({
    required this.id,
    this.body,
    this.createdBy,
    this.createdAt,
    this.attachments = const [],
  });

  factory TaskMessage.fromJson(Map<String, dynamic> json) {
    final attachFiles = json['attach_files'] as Map<String, dynamic>?;
    final allFiles = attachFiles?['allfiles'] as List<dynamic>? ?? [];

    return TaskMessage(
      id: json['_id'] as String? ?? '',
      body: json['msg_body'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: _toStr(json['created_at']),
      attachments: allFiles
          .whereType<Map<String, dynamic>>()
          .map((e) => TaskFileItem.fromJson(e))
          .toList(),
    );
  }

  String get formattedTime {
    final dt = _parseDate(createdAt);
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return DateFormat('h:mm a').format(dt.toLocal());
    return DateFormat('MMM d').format(dt.toLocal());
  }

  String get dayLabel {
    final dt = _parseDate(createdAt);
    if (dt == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(msgDay).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('MMM d, yyyy').format(dt.toLocal());
  }
}

// ── Task ───────────────────────────────────────────────────────────────────────

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

  // Detail fields — populated only by getTaskDetail()
  final List<String> keywords;
  final List<String> observers;
  final List<String> owners;
  final List<TaskChecklist> checklists;
  final List<TaskFileItem> taskFiles;
  final List<TaskMessage> discussion;
  final List<TaskHourEntry> hourBreakdown;
  final List<TaskCostEntry> costBreakdown;

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
    this.keywords = const [],
    this.observers = const [],
    this.owners = const [],
    this.checklists = const [],
    this.taskFiles = const [],
    this.discussion = const [],
    this.hourBreakdown = const [],
    this.costBreakdown = const [],
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
        hasDelete: switch (json['has_delete']) {
          bool b => b,
          List l => l.isNotEmpty,
          _ => false,
        },
        createdBy: json['created_by'] as String? ?? '',
        createdAt: _toStr(json['created_at']),
        keywords: (json['key_words'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        observers: (json['observers'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        owners: (json['owned_by'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        checklists: (json['checklists'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(TaskChecklist.fromJson)
                .toList() ??
            [],
        taskFiles: (json['files'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(TaskFileItem.fromJson)
                .toList() ??
            [],
        discussion: (json['discussion'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(TaskMessage.fromJson)
                .toList() ??
            [],
        hourBreakdown: (json['hour_breakdown'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(TaskHourEntry.fromJson)
                .toList() ??
            [],
        costBreakdown: (json['cost_breakdown'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(TaskCostEntry.fromJson)
                .toList() ??
            [],
      );

  Task copyWith({
    String? title,
    String? status,
    String? priority,
    String? startDate,
    String? endDate,
    String? dueTime,
    int? progress,
    String? notes,
    String? description,
    List<String>? assignTo,
    List<String>? keywords,
    List<String>? observers,
    List<TaskChecklist>? checklists,
    List<TaskFileItem>? taskFiles,
    List<TaskMessage>? discussion,
    List<TaskHourEntry>? hourBreakdown,
    List<TaskCostEntry>? costBreakdown,
  }) =>
      Task(
        id: id,
        title: title ?? this.title,
        status: status ?? this.status,
        priority: priority ?? this.priority,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        dueTime: dueTime ?? this.dueTime,
        progress: progress ?? this.progress,
        notes: notes ?? this.notes,
        description: description ?? this.description,
        assignTo: assignTo ?? this.assignTo,
        conversationId: conversationId,
        conversationName: conversationName,
        projectId: projectId,
        projectTitle: projectTitle,
        isArchived: isArchived,
        hasDelete: hasDelete,
        createdBy: createdBy,
        createdAt: createdAt,
        keywords: keywords ?? this.keywords,
        observers: observers ?? this.observers,
        owners: owners,
        checklists: checklists ?? this.checklists,
        taskFiles: taskFiles ?? this.taskFiles,
        discussion: discussion ?? this.discussion,
        hourBreakdown: hourBreakdown ?? this.hourBreakdown,
        costBreakdown: costBreakdown ?? this.costBreakdown,
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

  /// Absolute "d MMM" date for the Kanban card.
  String get formattedCardDate {
    final dt =
        _parseDate(startDate) ?? _parseDate(endDate) ?? _parseDate(createdAt);
    if (dt == null) return '';
    return DateFormat('d MMM').format(dt);
  }

  String get formattedDueDate {
    final dt = _parseDate(endDate);
    if (dt != null) return _shortDate(dt);
    return '';
  }

  String get formattedStartDate {
    final dt = _parseDate(startDate);
    if (dt != null) return _shortDate(dt);
    return '';
  }

  String get formattedCreatedAt {
    final dt = _parseDate(createdAt);
    if (dt == null) return '';
    return _relativeTime(dt);
  }

  static String _shortDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year) return DateFormat('MMM d').format(dt);
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
