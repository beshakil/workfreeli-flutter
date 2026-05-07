import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../features/tasks/task_models.dart';
import '../features/tasks/tasks_providers.dart';

class TaskDetailScreen extends ConsumerStatefulWidget {
  const TaskDetailScreen({super.key, required this.task});
  final Task task;

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _descCtrl;

  late String _status;
  late String? _priority;

  bool _dirty = false;

  static const _statuses = [
  'not_started',
  'inprogress',
  'completed',
  'on_hold',
  'canceled',
];

static const _statusLabels = {
  'not_started': 'Not Started',
  'inprogress': 'In Progress',
  'completed': 'Completed',
  'on_hold': 'On Hold',
  'canceled': 'Canceled',
};
  static const _priorities = ['low', 'medium', 'high'];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.task.title);
    _notesCtrl = TextEditingController(text: widget.task.notes ?? '');
    _descCtrl = TextEditingController(text: widget.task.description ?? '');
    _status = widget.task.normalizedStatus;
    _priority = widget.task.priority?.toLowerCase();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      _showSnack('Title cannot be empty.');
      return;
    }
    final ok = await ref.read(tasksNotifierProvider.notifier).updateTask(
          id: widget.task.id,
          title: _titleCtrl.text.trim(),
          status: _status,
          priority: _priority,
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
      _showSnack('Task saved.');
    } else {
      _showSnack(
        ref.read(tasksNotifierProvider).error ?? 'Failed to save task.',
        isError: true,
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: Text('Delete task?', style: AppTheme.headingSmall),
        content: Text(
          'This action cannot be undone.',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.textMuted)),
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
      _showSnack(
        ref.read(tasksNotifierProvider).error ?? 'Failed to delete task.',
        isError: true,
      );
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: AppTheme.bodySmall.copyWith(color: Colors.white)),
        backgroundColor: isError ? AppTheme.danger : AppTheme.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskState = ref.watch(tasksNotifierProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          _buildHeader(context, taskState.isMutating),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Title'),
                  const SizedBox(height: 8),
                  _inputField(_titleCtrl, 'Task title', onChanged: (_) => _markDirty()),
                  const SizedBox(height: 20),

                  Row(children: [
                    Expanded(child: _buildStatusPicker()),
                    const SizedBox(width: 12),
                    Expanded(child: _buildPriorityPicker()),
                  ]),
                  const SizedBox(height: 20),

                  if (widget.task.endDate != null) ...[
                    _sectionLabel('Due date'),
                    const SizedBox(height: 8),
                    _infoChip(
                      widget.task.formattedDueDate,
                      icon: Icons.calendar_today_rounded,
                      color: widget.task.isOverdue ? AppTheme.danger : AppTheme.textMuted,
                    ),
                    const SizedBox(height: 20),
                  ],

                  if (widget.task.assignTo.isNotEmpty) ...[
                    _sectionLabel('Assigned to'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: widget.task.assignTo
                          .map((uid) => _assigneeChip(uid))
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  _sectionLabel('Description'),
                  const SizedBox(height: 8),
                  _inputField(
                    _descCtrl,
                    'Add a description…',
                    maxLines: 4,
                    onChanged: (_) => _markDirty(),
                  ),
                  const SizedBox(height: 20),

                  _sectionLabel('Notes'),
                  const SizedBox(height: 8),
                  _inputField(
                    _notesCtrl,
                    'Add notes…',
                    maxLines: 3,
                    onChanged: (_) => _markDirty(),
                  ),
                  const SizedBox(height: 32),

                  // Save / Delete
                  Row(children: [
                    Expanded(
                      child: _primaryButton(
                        label: 'Save changes',
                        onTap: _dirty && !taskState.isMutating ? _save : null,
                        loading: taskState.isMutating && _dirty,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _dangerButton(
                      onTap: taskState.isMutating ? null : _delete,
                    ),
                  ]),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, bool loading) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 6,
        left: 4,
        right: 12,
        bottom: 10,
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
            child: Text('Task Details', style: AppTheme.headingSmall),
          ),
          if (loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppTheme.primary),
            ),
        ],
      ),
    );
  }

  // ── Pickers ─────────────────────────────────────────────────────────────────

  Widget _buildStatusPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Status'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.bgElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _status,
              isExpanded: true,
              dropdownColor: AppTheme.bgCard,
              style: AppTheme.bodyMedium,
              items: _statuses
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(
                          _statusLabels[s] ?? s,
                          style: AppTheme.bodySmall.copyWith(
                              color: _statusColor(s)),
                        ),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _status = v);
                  _markDirty();
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Priority'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.bgElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _priority,
              isExpanded: true,
              dropdownColor: AppTheme.bgCard,
              style: AppTheme.bodyMedium,
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text('None',
                      style: AppTheme.bodySmall
                          .copyWith(color: AppTheme.textDim)),
                ),
                ..._priorities.map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(
                        _capitalize(p),
                        style: AppTheme.bodySmall.copyWith(
                            color: _priorityColor(p)),
                      ),
                    )),
              ],
              onChanged: (v) {
                setState(() => _priority = v);
                _markDirty();
              },
            ),
          ),
        ),
      ],
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Widget _sectionLabel(String label) => Text(
        label,
        style: AppTheme.bodySmall
            .copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w600),
      );

  Widget _inputField(
    TextEditingController ctrl,
    String hint, {
    int maxLines = 1,
    void Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: TextField(
        controller: ctrl,
        style: AppTheme.bodyMedium,
        maxLines: maxLines,
        minLines: 1,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.textDim),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _infoChip(String label,
      {required IconData icon, Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? AppTheme.textMuted),
          const SizedBox(width: 6),
          Text(label,
              style: AppTheme.bodySmall
                  .copyWith(color: color ?? AppTheme.textMuted)),
        ],
      ),
    );
  }

  Widget _assigneeChip(String uid) {
    final initials = uid.length >= 2 ? uid.substring(0, 2).toUpperCase() : uid;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(initials,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 6),
        Text(uid.length > 8 ? '${uid.substring(0, 6)}…' : uid,
            style: AppTheme.caption),
      ]),
    );
  }

  Widget _primaryButton({
    required String label,
    VoidCallback? onTap,
    bool loading = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 48,
        decoration: BoxDecoration(
          gradient: onTap != null ? AppTheme.primaryGradient : null,
          color: onTap == null ? AppTheme.bgElevated : null,
          borderRadius: BorderRadius.circular(12),
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
                    color: onTap != null ? Colors.white : AppTheme.textDim,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _dangerButton({VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppTheme.danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: AppTheme.danger, size: 20),
      ),
    );
  }

  static Color _statusColor(String s) {
    switch (s) {
      case 'todo':
        return AppTheme.textDim;
      case 'inprogress':
        return AppTheme.primary;
      case 'review':
        return AppTheme.warning;
      case 'done':
        return AppTheme.success;
      default:
        return AppTheme.textMuted;
    }
  }

  static Color _priorityColor(String p) {
    switch (p) {
      case 'high':
        return AppTheme.danger;
      case 'medium':
        return AppTheme.warning;
      case 'low':
        return AppTheme.success;
      default:
        return AppTheme.textMuted;
    }
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
