import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config/app_config.dart';
import '../features/tasks/task_models.dart';
import '../features/tasks/tasks_providers.dart';
import '../features/tasks/tasks_service.dart';
import '../features/user/user_providers.dart';
import '../theme/app_theme.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const _statuses = [
  'not_started',
  'inprogress',
  'completed',
  'on_hold',
  'canceled',
];

const _statusLabels = {
  'not_started': 'Not Started',
  'inprogress': 'In Progress',
  'completed': 'Completed',
  'on_hold': 'On Hold',
  'canceled': 'Canceled',
};

// Maps Flutter internal keys to the status values stored on the server/web.
const _statusServerValues = {
  'not_started': 'Not Started',
  'inprogress': 'In Progress',
  'completed': 'Completed',
  'on_hold': 'On Hold',
  'canceled': 'Canceled',
};

const _progressValues = [0, 25, 50, 75, 100];
const _progressLabels = {
  0: 'Not Defined',
  25: 'Stage 1 (25%)',
  50: 'Stage 2 (50%)',
  75: 'Stage 3 (75%)',
  100: 'Final Stage',
};

// ── Screen ────────────────────────────────────────────────────────────────────

class TaskDetailScreen extends ConsumerStatefulWidget {
  const TaskDetailScreen({super.key, required this.task});

  final Task task;

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _notesCtrl;

  late String _status;
  late int _progress;
  late String? _priority;
  late String? _startDate;
  late String? _endDate;
  late String? _dueTime;

  // Full task detail loaded asynchronously
  Task? _detail;
  bool _detailLoading = true;

  bool _dirty = false;
  bool _trackingExpanded = false;
  bool _discussionExpanded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _titleCtrl = TextEditingController(text: widget.task.title);
    _descCtrl =
        TextEditingController(text: widget.task.description ?? '');
    _notesCtrl = TextEditingController(text: widget.task.notes ?? '');
    _status = widget.task.normalizedStatus;
    final raw = widget.task.progress;
    _progress = _progressValues.contains(raw)
        ? raw
        : _progressValues.reduce((a, b) =>
            (a - raw).abs() <= (b - raw).abs() ? a : b);
    _priority = widget.task.priority?.toLowerCase();
    _startDate = widget.task.startDate;
    _endDate = widget.task.endDate;
    _dueTime = widget.task.dueTime;
    _loadDetail();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    try {
      final detail = await TasksService.getTaskDetail(widget.task.id);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _detailLoading = false;
        // Only update text if not yet dirty
        if (!_dirty) {
          _descCtrl.text = detail.description ?? '';
          _notesCtrl.text = detail.notes ?? '';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _detail = widget.task;
        _detailLoading = false;
      });
    }
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  // ── Save ─────────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      _snack('Title cannot be empty.');
      return;
    }
    final ok = await ref.read(tasksNotifierProvider.notifier).updateTask(
          id: widget.task.id,
          title: _titleCtrl.text.trim(),
          status: _statusServerValues[_status] ?? _status,
          priority: _priority,
          progress: _progress,
          startDate: _startDate,
          endDate: _endDate,
          dueTime: _dueTime,
          notes: _notesCtrl.text.trim().isNotEmpty
              ? _notesCtrl.text.trim()
              : null,
          description: _descCtrl.text.trim().isNotEmpty
              ? _descCtrl.text.trim()
              : null,
        );
    if (!mounted) return;
    if (ok) {
      setState(() => _dirty = false);
      _snack('Task saved.');
      // Reload full detail so all fields (checklists, files, discussion) stay fresh.
      _loadDetail();
    } else {
      _snack(
        ref.read(tasksNotifierProvider).error ?? 'Failed to save task.',
        isError: true,
      );
    }
  }

  // ── Delete ───────────────────────────────────────────────────────────────────

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete task?', style: AppTheme.headingSmall),
        content: Text(
          'This action cannot be undone.',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: AppTheme.bodySmall
                    .copyWith(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style:
                    AppTheme.bodySmall.copyWith(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await ref
        .read(tasksNotifierProvider.notifier)
        .deleteTask(widget.task.id);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      _snack(
        ref.read(tasksNotifierProvider).error ?? 'Failed to delete.',
        isError: true,
      );
    }
  }

  // ── Date pickers ─────────────────────────────────────────────────────────────

  Future<void> _pickStartDate() async {
    final initial = _parseDate(_startDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: _datepickerTheme,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.toIso8601String();
        _dirty = true;
      });
    }
  }

  Future<void> _pickEndDate() async {
    final initial = _parseDate(_endDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: _datepickerTheme,
    );
    if (picked != null) {
      setState(() {
        _endDate = picked.toIso8601String();
        _dirty = true;
      });
    }
  }

  Future<void> _pickDueTime() async {
    final now = TimeOfDay.now();
    TimeOfDay? initial = now;
    if (_dueTime != null && _dueTime!.isNotEmpty) {
      final dt = _parseDate(_dueTime);
      if (dt != null) {
        initial = TimeOfDay(hour: dt.hour, minute: dt.minute);
      }
    }
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: _datepickerTheme,
    );
    if (picked != null) {
      final now = DateTime.now();
      final dt = DateTime(
          now.year, now.month, now.day, picked.hour, picked.minute);
      setState(() {
        _dueTime = dt.toIso8601String();
        _dirty = true;
      });
    }
  }

  Widget _datepickerTheme(BuildContext context, Widget? child) {
    return Theme(
      data: ThemeData.light().copyWith(
        colorScheme: const ColorScheme.light(
          primary: AppTheme.primary,
          onPrimary: Colors.white,
          surface: AppTheme.bgCard,
        ),
        dialogTheme: DialogThemeData(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      child: child!,
    );
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
          Text(msg, style: AppTheme.bodySmall.copyWith(color: Colors.white)),
      backgroundColor: isError ? AppTheme.danger : AppTheme.success,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final taskState = ref.watch(tasksNotifierProvider);
    final usersMap = ref.watch(usersMapProvider).value ?? const {};
    final task = _detail ?? widget.task;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          _buildAppBar(context, task, taskState.isMutating),
          Expanded(
            child: _detailLoading
                ? _buildSkeleton()
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoCard(task),
                        const SizedBox(height: 8),
                        _buildKeywordsSection(task),
                        const SizedBox(height: 8),
                        _buildStatusProgressSection(),
                        const SizedBox(height: 8),
                        _buildDatesSection(),
                        const SizedBox(height: 8),
                        _buildAssignmentsSection(task, usersMap),
                        const SizedBox(height: 8),
                        _buildTabSection(task),
                        const SizedBox(height: 8),
                        _buildTrackingSection(task),
                        const SizedBox(height: 8),
                        _buildDiscussionSection(task),
                        const SizedBox(height: 8),
                        _buildActionRow(taskState),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────────

  Widget _buildAppBar(
      BuildContext context, Task task, bool loading) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 4,
        left: 4,
        right: 8,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppTheme.textMuted, size: 20),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Task Detail', style: AppTheme.headingSmall),
                if (task.conversationName?.isNotEmpty == true)
                  Text(
                    task.conversationName!,
                    style: AppTheme.caption
                        .copyWith(color: AppTheme.primary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppTheme.primary),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                color: AppTheme.textMuted, size: 22),
            color: AppTheme.bgCard,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            onSelected: (v) {
              if (v == 'delete') _delete();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  const Icon(Icons.delete_outline_rounded,
                      color: AppTheme.danger, size: 18),
                  const SizedBox(width: 10),
                  Text('Delete Task',
                      style: AppTheme.bodySmall
                          .copyWith(color: AppTheme.danger)),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Info card (title + meta) ──────────────────────────────────────────────────

  Widget _buildInfoCard(Task task) {
    return Container(
      color: AppTheme.bgCard,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Editable title
          TextField(
            controller: _titleCtrl,
            style: AppTheme.headingSmall
                .copyWith(fontSize: 18, height: 1.3),
            maxLines: 2,
            minLines: 1,
            onChanged: (_) => _markDirty(),
            decoration: InputDecoration(
              hintText: 'Task title…',
              hintStyle: AppTheme.headingSmall.copyWith(
                  fontSize: 18, color: AppTheme.textDim),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 10),
          // Meta row
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              if (task.createdBy.isNotEmpty)
                _metaChip(
                  icon: Icons.person_outline_rounded,
                  label: task.createdBy,
                ),
              if (task.formattedCreatedAt.isNotEmpty)
                _metaChip(
                  icon: Icons.schedule_rounded,
                  label: task.formattedCreatedAt,
                ),
              if (task.projectTitle?.isNotEmpty == true)
                _metaChip(
                  icon: Icons.folder_outlined,
                  label: task.projectTitle!,
                  color: AppTheme.primary,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaChip({
    required IconData icon,
    required String label,
    Color? color,
  }) {
    final c = color ?? AppTheme.textMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 4),
        Text(label,
            style: AppTheme.caption.copyWith(color: c),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ],
    );
  }

  // ── Keywords section ──────────────────────────────────────────────────────────

  Widget _buildKeywordsSection(Task task) {
    return Container(
      color: AppTheme.bgCard,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Keywords'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...task.keywords.map((kw) => _keywordChip(kw)),
              GestureDetector(
                onTap: () => _snack('Keyword management coming soon.'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.bgElevated,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded,
                          size: 13, color: AppTheme.textDim),
                      const SizedBox(width: 4),
                      Text('Add keyword',
                          style: AppTheme.caption
                              .copyWith(color: AppTheme.textMuted)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _keywordChip(String kw) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.label_rounded,
              size: 11, color: AppTheme.primary),
          const SizedBox(width: 5),
          Text(kw,
              style: AppTheme.caption.copyWith(
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }

  // ── Status + Progress ─────────────────────────────────────────────────────────

  Widget _buildStatusProgressSection() {
    return Container(
      color: AppTheme.bgCard,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildStatusDropdown()),
              const SizedBox(width: 12),
              Expanded(child: _buildPriorityDropdown()),
            ],
          ),
          const SizedBox(height: 12),
          _buildProgressDropdown(),
        ],
      ),
    );
  }

  Widget _buildPriorityDropdown() {
    const priorities = ['low', 'medium', 'high'];
    const priorityLabels = {
      'low': 'Low',
      'medium': 'Medium',
      'high': 'High',
    };
    final priorityColors = {
      'low': AppTheme.success,
      'medium': AppTheme.warning,
      'high': AppTheme.danger,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Priority'),
        const SizedBox(height: 8),
        _styledDropdown<String?>(
          value: _priority,
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text('None',
                  style: AppTheme.bodySmall
                      .copyWith(color: AppTheme.textMuted)),
            ),
            ...priorities.map((p) {
              final color = priorityColors[p] ?? AppTheme.textMuted;
              return DropdownMenuItem<String?>(
                value: p,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: color, borderRadius: BorderRadius.circular(4)),
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(priorityLabels[p] ?? p,
                          style: AppTheme.bodySmall.copyWith(color: color),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              );
            }),
          ],
          onChanged: (v) {
            setState(() => _priority = v);
            _markDirty();
          },
        ),
      ],
    );
  }

  Widget _buildStatusDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Status'),
        const SizedBox(height: 8),
        _styledDropdown<String>(
          value: _status,
          items: _statuses.map((s) {
            final color = _statusColor(s);
            return DropdownMenuItem(
              value: s,
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(_statusLabels[s] ?? s,
                        style: AppTheme.bodySmall
                            .copyWith(color: color),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) setState(() => _status = v);
            _markDirty();
          },
        ),
      ],
    );
  }

  Widget _buildProgressDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Progress'),
        const SizedBox(height: 8),
        _styledDropdown<int>(
          value: _progress,
          items: _progressValues.map((v) {
            final color = _progressColor(v);
            return DropdownMenuItem(
              value: v,
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(_progressLabels[v] ?? '$v%',
                        style: AppTheme.bodySmall
                            .copyWith(color: color),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) setState(() => _progress = v);
            _markDirty();
          },
        ),
      ],
    );
  }

  Widget _styledDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: AppTheme.bgCard,
          style: AppTheme.bodySmall,
          icon: const Icon(Icons.expand_more_rounded,
              color: AppTheme.textDim, size: 18),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ── Dates section ─────────────────────────────────────────────────────────────

  Widget _buildDatesSection() {
    return Container(
      color: AppTheme.bgCard,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Dates'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _dateTile(
                  label: 'Start Date',
                  value: _formatDate(_startDate),
                  icon: Icons.event_rounded,
                  onTap: _pickStartDate,
                  onClear: _startDate != null
                      ? () => setState(() {
                            _startDate = null;
                            _dirty = true;
                          })
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _dateTile(
                  label: 'Due Date',
                  value: _formatDate(_endDate),
                  icon: Icons.event_available_rounded,
                  onTap: _pickEndDate,
                  isOverdue: _detail?.isOverdue ?? widget.task.isOverdue,
                  onClear: _endDate != null
                      ? () => setState(() {
                            _endDate = null;
                            _dirty = true;
                          })
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _dateTile(
                  label: 'Due Time',
                  value: _formatTime(_dueTime),
                  icon: Icons.access_time_rounded,
                  onTap: _pickDueTime,
                  onClear: _dueTime != null
                      ? () => setState(() {
                            _dueTime = null;
                            _dirty = true;
                          })
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateTile({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    VoidCallback? onClear,
    bool isOverdue = false,
  }) {
    final hasValue = value.isNotEmpty;
    final displayColor = isOverdue && hasValue
        ? AppTheme.danger
        : hasValue
            ? AppTheme.primary
            : AppTheme.textDim;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: hasValue
              ? displayColor.withValues(alpha: 0.07)
              : AppTheme.bgElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: hasValue
                  ? displayColor.withValues(alpha: 0.4)
                  : AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: displayColor),
                const Spacer(),
                if (onClear != null && hasValue)
                  GestureDetector(
                    onTap: onClear,
                    child: Icon(Icons.close_rounded,
                        size: 12, color: AppTheme.textDim),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: AppTheme.labelSmall.copyWith(fontSize: 9),
            ),
            const SizedBox(height: 2),
            Text(
              value.isNotEmpty ? value : 'Set date',
              style: AppTheme.caption.copyWith(
                color: displayColor,
                fontWeight:
                    hasValue ? FontWeight.w600 : FontWeight.w400,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ── Assignments + Observers ───────────────────────────────────────────────────

  Widget _buildAssignmentsSection(Task task, Map<String, String> usersMap) {
    final hasAssignees = task.assignTo.isNotEmpty;
    final hasObservers = task.observers.isNotEmpty;
    if (!hasAssignees && !hasObservers) return const SizedBox.shrink();

    return Container(
      color: AppTheme.bgCard,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasAssignees) ...[
            _sectionLabel('Assigned To'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: task.assignTo
                  .map((uid) => _avatarChip(uid, usersMap))
                  .toList(),
            ),
          ],
          if (hasAssignees && hasObservers)
            const SizedBox(height: 14),
          if (hasObservers) ...[
            _sectionLabel('Observers'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...task.observers.map((uid) => _avatarChip(
                    uid, usersMap,
                    accentColor: AppTheme.accent)),
                GestureDetector(
                  onTap: () =>
                      _snack('Observer management coming soon.'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.bgElevated,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_rounded,
                            size: 13, color: AppTheme.textDim),
                        const SizedBox(width: 4),
                        Text('Add observer',
                            style: AppTheme.caption
                                .copyWith(color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _avatarChip(String uid, Map<String, String> usersMap,
      {Color? accentColor}) {
    final color = accentColor ?? AppTheme.primary;
    final displayName = usersMap[uid] ?? _shortId(uid);
    final initials = _initialsFromName(displayName);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(initials,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            displayName.length > 16
                ? '${displayName.substring(0, 14)}…'
                : displayName,
            style: AppTheme.caption.copyWith(
                color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  static String _shortId(String uid) {
    final atIdx = uid.indexOf('@');
    if (atIdx > 0) return uid.substring(0, atIdx);
    return uid.length > 8 ? uid.substring(0, 8) : uid;
  }

  static String _initialsFromName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.length >= 2
        ? name.substring(0, 2).toUpperCase()
        : name.toUpperCase();
  }

  // ── Tabs section ─────────────────────────────────────────────────────────────

  Widget _buildTabSection(Task task) {
    final filesCount = task.taskFiles.length;
    final checklistCount = task.checklists.length;

    return Container(
      color: AppTheme.bgCard,
      child: Column(
        children: [
          // Tab bar
          TabBar(
            controller: _tabController,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textMuted,
            labelStyle:
                AppTheme.caption.copyWith(fontWeight: FontWeight.w600),
            unselectedLabelStyle: AppTheme.caption,
            indicatorColor: AppTheme.primary,
            indicatorWeight: 2.5,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: AppTheme.border,
            tabs: [
              const Tab(text: 'Description'),
              const Tab(text: 'Your Notes'),
              Tab(
                  text: filesCount > 0
                      ? 'Files ($filesCount)'
                      : 'Files'),
              Tab(
                  text: checklistCount > 0
                      ? 'Checklist ($checklistCount)'
                      : 'Checklist'),
            ],
          ),
          // Tab content (fixed-height inner switcher — no nested scroll)
          AnimatedBuilder(
            animation: _tabController,
            builder: (context, _) {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: KeyedSubtree(
                  key: ValueKey(_tabController.index),
                  child: _buildTabContent(task),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(Task task) {
    switch (_tabController.index) {
      case 0:
        return _buildDescriptionTab();
      case 1:
        return _buildNotesTab();
      case 2:
        return _buildFilesTab(task);
      case 3:
        return _buildChecklistTab(task);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDescriptionTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Description'),
          const SizedBox(height: 8),
          Container(
            decoration: AppTheme.elevatedDecoration,
            child: TextField(
              controller: _descCtrl,
              style: AppTheme.bodyMedium,
              maxLines: 6,
              minLines: 3,
              onChanged: (_) => _markDirty(),
              decoration: InputDecoration(
                hintText: 'Add a description…',
                hintStyle:
                    AppTheme.bodyMedium.copyWith(color: AppTheme.textDim),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Your Notes'),
          const SizedBox(height: 8),
          Container(
            decoration: AppTheme.elevatedDecoration,
            child: TextField(
              controller: _notesCtrl,
              style: AppTheme.bodyMedium,
              maxLines: 6,
              minLines: 3,
              onChanged: (_) => _markDirty(),
              decoration: InputDecoration(
                hintText: 'Add private notes…',
                hintStyle:
                    AppTheme.bodyMedium.copyWith(color: AppTheme.textDim),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesTab(Task task) {
    if (task.taskFiles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.attach_file_rounded,
                  size: 40, color: AppTheme.textDim),
              const SizedBox(height: 10),
              Text('No files attached',
                  style: AppTheme.bodySmall
                      .copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Files shared in this task appear here',
                  style: AppTheme.caption, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    return Column(
      children: task.taskFiles
          .map((f) => _TaskFileRow(file: f))
          .toList(),
    );
  }

  Widget _buildChecklistTab(Task task) {
    if (task.checklists.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_box_outline_blank_rounded,
                  size: 40, color: AppTheme.textDim),
              const SizedBox(height: 10),
              Text('No checklist items',
                  style: AppTheme.bodySmall
                      .copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Checklist items will appear here',
                  style: AppTheme.caption, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    int done = task.checklists.where((c) => c.checked).length;
    final total = task.checklists.length;
    final progress = total > 0 ? done / total : 0.0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppTheme.bgElevated,
                    valueColor: AlwaysStoppedAnimation(
                        progress >= 1.0
                            ? AppTheme.success
                            : AppTheme.primary),
                    minHeight: 5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('$done/$total',
                  style: AppTheme.caption.copyWith(
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          ...task.checklists.map((item) => _ChecklistRow(item: item)),
        ],
      ),
    );
  }

  // ── Cost & Hours tracking ─────────────────────────────────────────────────────

  Widget _buildTrackingSection(Task task) {
    final hasCost = task.costBreakdown.isNotEmpty;
    final hasHours = task.hourBreakdown.isNotEmpty;
    if (!hasCost && !hasHours) return const SizedBox.shrink();

    return Container(
      color: AppTheme.bgCard,
      child: Column(
        children: [
          // Expand/collapse header
          GestureDetector(
            onTap: () =>
                setState(() => _trackingExpanded = !_trackingExpanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.bar_chart_rounded,
                      color: AppTheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Text('Tracking',
                      style: AppTheme.bodySmall
                          .copyWith(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _trackingExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more_rounded,
                        color: AppTheme.textDim, size: 20),
                  ),
                ],
              ),
            ),
          ),
          if (_trackingExpanded) ...[
            Divider(height: 1, color: AppTheme.border),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasCost) ...[
                    _sectionLabel('Cost Tracking'),
                    const SizedBox(height: 8),
                    _buildCostTable(task.costBreakdown),
                    const SizedBox(height: 16),
                  ],
                  if (hasHours) ...[
                    _sectionLabel('Hours Tracking'),
                    const SizedBox(height: 8),
                    _buildHoursTable(task.hourBreakdown),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCostTable(List<TaskCostEntry> entries) {
    double totalForecast = 0;
    double totalActual = 0;
    for (final e in entries) {
      totalForecast += e.forecastedCost;
      totalActual += e.actualCost;
    }
    final variance = totalForecast - totalActual;

    return Column(
      children: [
        // Header
        _trackingTableHeader(
            ['Title', 'Forecast', 'Actual', 'Variance']),
        ...entries.map((e) => _trackingTableRow([
              e.title ?? '—',
              _currency(e.forecastedCost),
              _currency(e.actualCost),
              _currency(e.variance),
            ], varianceIndex: 3, variance: e.variance)),
        Divider(height: 1, color: AppTheme.border),
        _trackingTableRow([
          'Total',
          _currency(totalForecast),
          _currency(totalActual),
          _currency(variance),
        ], isBold: true, varianceIndex: 3, variance: variance),
      ],
    );
  }

  Widget _buildHoursTable(List<TaskHourEntry> entries) {
    double totalForecast = 0;
    double totalActual = 0;
    for (final e in entries) {
      totalForecast += e.forecastedHours;
      totalActual += e.actualHours;
    }
    final variance = totalForecast - totalActual;

    return Column(
      children: [
        _trackingTableHeader(['From', 'To', 'Forecast', 'Actual', 'Var']),
        ...entries.map((e) => _trackingTableRow([
              _shortDate(e.fromDate),
              _shortDate(e.toDate),
              '${e.forecastedHours.toStringAsFixed(1)}h',
              '${e.actualHours.toStringAsFixed(1)}h',
              '${e.variance.toStringAsFixed(1)}h',
            ], varianceIndex: 4, variance: e.variance)),
        Divider(height: 1, color: AppTheme.border),
        _trackingTableRow([
          '',
          'Total',
          '${totalForecast.toStringAsFixed(1)}h',
          '${totalActual.toStringAsFixed(1)}h',
          '${variance.toStringAsFixed(1)}h',
        ], isBold: true, varianceIndex: 4, variance: variance),
      ],
    );
  }

  Widget _trackingTableHeader(List<String> cols) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(8)),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: cols
            .map((c) => Expanded(
                    child: Text(c,
                        style: AppTheme.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis)))
            .toList(),
      ),
    );
  }

  Widget _trackingTableRow(
    List<String> cols, {
    bool isBold = false,
    int? varianceIndex,
    double variance = 0,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isBold
            ? AppTheme.bgElevated
            : AppTheme.bgCard,
        border: Border(
            left: BorderSide(color: AppTheme.border),
            right: BorderSide(color: AppTheme.border),
            bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: cols.asMap().entries.map((entry) {
          final isVariance = entry.key == varianceIndex;
          Color textColor = AppTheme.textPrimary;
          if (isVariance && varianceIndex != null) {
            textColor = variance > 0
                ? AppTheme.warning
                : variance < 0
                    ? AppTheme.success
                    : AppTheme.textMuted;
          }
          return Expanded(
            child: Text(
              entry.value,
              style: AppTheme.caption.copyWith(
                color: textColor,
                fontWeight:
                    isBold ? FontWeight.w700 : FontWeight.w400,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Discussion section ────────────────────────────────────────────────────────

  Widget _buildDiscussionSection(Task task) {
    if (task.discussion.isEmpty) return const SizedBox.shrink();

    return Container(
      color: AppTheme.bgCard,
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(
                () => _discussionExpanded = !_discussionExpanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.forum_outlined,
                      color: AppTheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Text('Discussion',
                      style: AppTheme.bodySmall
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${task.discussion.length}',
                        style: AppTheme.caption
                            .copyWith(color: AppTheme.primary)),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _discussionExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more_rounded,
                        color: AppTheme.textDim, size: 20),
                  ),
                ],
              ),
            ),
          ),
          if (_discussionExpanded) ...[
            Divider(height: 1, color: AppTheme.border),
            _buildMessageList(task.discussion),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageList(List<TaskMessage> messages) {
    String? lastDay;
    final widgets = <Widget>[];

    for (final msg in messages) {
      final dayLabel = msg.dayLabel;
      if (dayLabel != lastDay) {
        lastDay = dayLabel;
        widgets.add(_daySeparator(dayLabel));
      }
      widgets.add(_MessageBubble(message: msg));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: widgets),
    );
  }

  Widget _daySeparator(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppTheme.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.bgElevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.border),
              ),
              child: Text(label,
                  style: AppTheme.caption.copyWith(fontSize: 10)),
            ),
          ),
          Expanded(child: Divider(color: AppTheme.border)),
        ],
      ),
    );
  }

  // ── Action row ────────────────────────────────────────────────────────────────

  Widget _buildActionRow(TasksState taskState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: _PrimaryButton(
              label: 'Save Changes',
              onTap: _dirty && !taskState.isMutating ? _save : null,
              loading: taskState.isMutating && _dirty,
            ),
          ),
          const SizedBox(width: 12),
          _DangerButton(
            onTap: taskState.isMutating ? null : _delete,
          ),
        ],
      ),
    );
  }

  // ── Skeleton ──────────────────────────────────────────────────────────────────

  Widget _buildSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(
          6,
          (i) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Container(
              height: i == 0 ? 80 : i == 1 ? 44 : 36,
              decoration: BoxDecoration(
                color: AppTheme.bgElevated,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Section helpers ───────────────────────────────────────────────────────────

  Widget _sectionLabel(String label) => Text(
        label,
        style: AppTheme.labelSmall.copyWith(
          color: AppTheme.textMuted,
          fontWeight: FontWeight.w700,
        ),
      );

  // ── Color helpers ─────────────────────────────────────────────────────────────

  static Color _statusColor(String s) {
    switch (s) {
      case 'not_started':
        return AppTheme.textDim;
      case 'inprogress':
        return AppTheme.primary;
      case 'completed':
        return AppTheme.success;
      case 'on_hold':
        return AppTheme.warning;
      case 'canceled':
        return AppTheme.danger;
      default:
        return AppTheme.textMuted;
    }
  }

  static Color _progressColor(int v) {
    if (v == 0) return AppTheme.textDim;
    if (v <= 25) return AppTheme.warning;
    if (v <= 50) return AppTheme.accent;
    if (v <= 75) return AppTheme.primary;
    return AppTheme.success;
  }

  // ── Format helpers ────────────────────────────────────────────────────────────

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = _parseDate(iso);
    if (dt == null) return '';
    return DateFormat('MMM d').format(dt);
  }

  String _formatTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = _parseDate(iso);
    if (dt == null) return '';
    return DateFormat('h:mm a').format(dt);
  }

  String _shortDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final dt = _parseDate(iso);
    if (dt == null) return '—';
    return DateFormat('MMM d').format(dt);
  }

  String _currency(double v) {
    final formatted =
        NumberFormat('#,##0.00').format(v.abs());
    return '${v < 0 ? '-' : ''}\$$formatted';
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw) ??
        (int.tryParse(raw) != null
            ? DateTime.fromMillisecondsSinceEpoch(int.parse(raw))
            : null);
  }
}

// ── Task file row (inside task detail Files tab) ───────────────────────────────

class _TaskFileRow extends StatelessWidget {
  const _TaskFileRow({required this.file});

  final TaskFileItem file;

  static const _typeColors = {
    'PDF': (Color(0xFFEF4444), Color(0x1AEF4444)),
    'DOC': (Color(0xFF3B82F6), Color(0x1A3B82F6)),
    'DOCX': (Color(0xFF3B82F6), Color(0x1A3B82F6)),
    'XLS': (Color(0xFF10B981), Color(0x1A10B981)),
    'XLSX': (Color(0xFF10B981), Color(0x1A10B981)),
    'PNG': (Color(0xFFA78BFA), Color(0x1AA78BFA)),
    'JPG': (Color(0xFFA78BFA), Color(0x1AA78BFA)),
    'JPEG': (Color(0xFFA78BFA), Color(0x1AA78BFA)),
    'MP4': (Color(0xFFF59E0B), Color(0x1AF59E0B)),
    'MP3': (Color(0xFF06D6A0), Color(0x1A06D6A0)),
  };

  @override
  Widget build(BuildContext context) {
    final ext = file.displayExt;
    final colors = _typeColors[ext] ??
        (AppTheme.textMuted, AppTheme.bgElevated);
    final iconColor = colors.$1;
    final iconBg = colors.$2;

    return GestureDetector(
      onTap: () => _openFile(context),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(
                child: file.isImage
                    ? Icon(Icons.image_rounded,
                        color: iconColor, size: 19)
                    : Text(ext,
                        style: TextStyle(
                            color: iconColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(file.name,
                      style: AppTheme.bodySmall
                          .copyWith(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (file.fileSize?.isNotEmpty == true)
                        Text(file.fileSize!,
                            style: AppTheme.caption),
                      if (file.fileSize?.isNotEmpty == true &&
                          file.uploadedBy?.isNotEmpty == true)
                        Text(' · ',
                            style: AppTheme.caption
                                .copyWith(color: AppTheme.textDim)),
                      if (file.uploadedBy?.isNotEmpty == true)
                        Flexible(
                          child: Text(file.uploadedBy!,
                              style: AppTheme.caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.download_rounded,
                size: 18, color: AppTheme.textDim),
          ],
        ),
      ),
    );
  }

  Future<void> _openFile(BuildContext context) async {
    final url = file.location ?? '';
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No URL available for this file.')));
      return;
    }
    final fullUrl = url.startsWith('http')
        ? url
        : '${AppConfig.fileBaseUrl}/$url';
    final uri = Uri.tryParse(fullUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ── Checklist row ─────────────────────────────────────────────────────────────

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.item});

  final TaskChecklist item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: item.checked
                  ? AppTheme.success
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: item.checked
                    ? AppTheme.success
                    : AppTheme.border,
                width: 1.5,
              ),
            ),
            child: item.checked
                ? const Icon(Icons.check_rounded,
                    color: Colors.white, size: 12)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.title,
              style: AppTheme.bodySmall.copyWith(
                decoration: item.checked
                    ? TextDecoration.lineThrough
                    : null,
                color: item.checked
                    ? AppTheme.textDim
                    : AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final TaskMessage message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sender + time
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  gradient: AppTheme.avatarBlue,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: Text(
                    _initials(message.createdBy ?? '?'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message.createdBy ?? 'Unknown',
                  style: AppTheme.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                message.formattedTime,
                style: AppTheme.caption.copyWith(fontSize: 10),
              ),
            ],
          ),
          // Message body
          if (message.body?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(left: 34, top: 4),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.bgElevated,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(message.body!,
                    style: AppTheme.bodySmall.copyWith(height: 1.4)),
              ),
            ),
          // Attachments
          if (message.attachments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 34, top: 6),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: message.attachments
                    .map((a) => _AttachmentChip(file: a))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  String _initials(String s) {
    final parts = s.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].length >= 2
          ? parts[0].substring(0, 2).toUpperCase()
          : parts[0].toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

// ── Attachment chip (inside message) ─────────────────────────────────────────

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({required this.file});

  final TaskFileItem file;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _open(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.bgElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              file.isImage
                  ? Icons.image_rounded
                  : file.isVideo
                      ? Icons.videocam_rounded
                      : Icons.insert_drive_file_rounded,
              size: 14,
              color: AppTheme.textMuted,
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                file.name,
                style: AppTheme.caption.copyWith(
                    fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final url = file.location ?? '';
    if (url.isEmpty) return;
    final fullUrl = url.startsWith('http')
        ? url
        : '${AppConfig.fileBaseUrl}/$url';
    final uri = Uri.tryParse(fullUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ── Shared button widgets ─────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    this.onTap,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 48,
        decoration: BoxDecoration(
          gradient: onTap != null ? AppTheme.primaryGradient : null,
          color: onTap == null ? AppTheme.bgElevated : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: onTap != null
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  label,
                  style: AppTheme.bodySmall.copyWith(
                    color: onTap != null
                        ? Colors.white
                        : AppTheme.textDim,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  const _DangerButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppTheme.danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppTheme.danger.withValues(alpha: 0.3)),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: AppTheme.danger, size: 20),
      ),
    );
  }
}
