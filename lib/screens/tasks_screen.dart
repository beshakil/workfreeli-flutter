import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../features/tasks/task_models.dart';
import '../features/tasks/tasks_providers.dart';
import '../features/user/user_providers.dart';
import 'task_detail_screen.dart';

// Assignee name color — web uses #2440bd; now resolved via AppTheme.primary
const _kAssigneeColor = Color(0xFF2440BD);

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  // Web column order: Not Started → In Progress → Completed → On Hold → Canceled
  static const _columns = [
    _ColumnConfig('not_started', 'Not Started', Color(0xFF94A3B8)),
    _ColumnConfig('inprogress',  'In Progress',  Color(0xFF6366F1)),
    _ColumnConfig('completed',   'Completed',     Color(0xFF10B981)),
    _ColumnConfig('on_hold',     'On Hold',       Color(0xFFF59E0B)),
    _ColumnConfig('canceled',    'Canceled',      Color(0xFFEF4444)),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kanbanAsync = ref.watch(kanbanTasksProvider);
    final taskState   = ref.watch(tasksNotifierProvider);
    // Resolve user IDs → display names; falls back to {} while loading
    final usersMap    = ref.watch(usersMapProvider).value ?? const {};

    return Stack(
      children: [
        Column(
          children: [
            _buildHeader(context, ref, taskState),
            if (taskState.error != null)
              _buildErrorBanner(
                taskState.error!,
                onDismiss: () =>
                    ref.read(tasksNotifierProvider.notifier).clearError(),
              ),
            Expanded(
              child: kanbanAsync.when(
                loading: () => _buildLoadingBoard(),
                error: (err, _) => _buildError(
                  err.toString().replaceFirst('Exception: ', ''),
                  onRetry: () =>
                      ref.read(tasksNotifierProvider.notifier).load(),
                ),
                data: (grouped) => ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 16, 2, 16),
                  itemCount: _columns.length,
                  itemBuilder: (context, i) {
                    final col   = _columns[i];
                    final tasks = grouped[col.key] ?? [];
                    return _KanbanColumn(
                      column: col,
                      tasks: tasks,
                      usersMap: usersMap,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        Positioned(
          bottom: 20,
          right: 20,
          child: _CreateTaskFab(),
        ),
      ],
    );
  }

  Widget _buildHeader(
      BuildContext context, WidgetRef ref, TasksState state) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 20,
        right: 20,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Task Board', style: AppTheme.headingMedium),
              const SizedBox(height: 2),
              Text('${state.tasks.length} tasks', style: AppTheme.caption),
            ],
          ),
          GestureDetector(
            onTap: state.isLoading
                ? null
                : () => ref.read(tasksNotifierProvider.notifier).load(),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                gradient:
                    state.isLoading ? null : AppTheme.accentGradient,
                color: state.isLoading ? AppTheme.bgElevated : null,
                borderRadius: BorderRadius.circular(10),
              ),
              child: state.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.accent),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.refresh_rounded,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text('Refresh',
                            style: AppTheme.bodySmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String msg, {required VoidCallback onDismiss}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.danger.withValues(alpha: 0.12),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppTheme.danger, size: 16),
          const SizedBox(width: 8),
          Expanded(
              child: Text(msg,
                  style: AppTheme.caption.copyWith(color: AppTheme.danger))),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close_rounded,
                color: AppTheme.danger, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingBoard() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (_, __) => Container(
        width: 240,
        margin: const EdgeInsets.only(right: 14),
        child: Column(children: [
          Container(
            height: 40,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.bgElevated,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          ...List.generate(
            3,
            (_) => Container(
              height: 80,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildError(String message, {required VoidCallback onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.assignment_late_outlined,
                size: 48, color: AppTheme.textDim),
            const SizedBox(height: 16),
            Text('Could not load tasks',
                style: AppTheme.bodyMedium
                    .copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(message,
                style: AppTheme.caption, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                  foregroundColor: AppTheme.accent),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Column config ─────────────────────────────────────────────────────────────

class _ColumnConfig {
  final String key;
  final String title;
  final Color color;
  const _ColumnConfig(this.key, this.title, this.color);
}

// ── Kanban Column ─────────────────────────────────────────────────────────────

class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({
    required this.column,
    required this.tasks,
    required this.usersMap,
  });

  final _ColumnConfig          column;
  final List<Task>             tasks;
  final Map<String, String>    usersMap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column header: "Not Started >"  [count badge]  — matches web
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(children: [
              Expanded(
                child: Row(children: [
                  Text(
                    column.title,
                    style: AppTheme.bodySmall
                        .copyWith(fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded,
                      size: 16, color: AppTheme.textDim),
                ]),
              ),
              // Count badge — filled circle, column color
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: column.color,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${tasks.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ]),
          ),

          // Task cards
          Expanded(
            child: tasks.isEmpty
                ? Center(
                    child: Text('No tasks',
                        style: AppTheme.caption
                            .copyWith(color: AppTheme.textDim)),
                  )
                : ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (_, i) => _TaskCard(
                      task: tasks[i],
                      usersMap: usersMap,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Task Card ─────────────────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.usersMap});

  final Task                task;
  final Map<String, String> usersMap;

  String get _assigneeLabel {
    if (task.assignTo.isEmpty) return 'N/A';
    final id = task.assignTo.first;
    // Resolve user ID → display name from the company users map
    final name = usersMap[id];
    if (name != null && name.isNotEmpty) return name;
    // Fallback: if ID looks like an email show the username part
    final atIdx = id.indexOf('@');
    if (atIdx > 0) return id.substring(0, atIdx);
    return 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    final isDone     = task.normalizedStatus == 'completed';
    final isCanceled = task.normalizedStatus == 'canceled';
    final cardDate   = task.formattedCardDate;
    final isOverdue  = task.isOverdue && !isDone && !isCanceled;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOverdue
                ? AppTheme.danger.withValues(alpha: 0.5)
                : AppTheme.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: task title + bell icon  (matches web exactly)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: AppTheme.bodySmall.copyWith(
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                      color: isDone || isCanceled
                          ? AppTheme.textDim
                          : AppTheme.textPrimary,
                      decoration: isDone || isCanceled
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: AppTheme.textDim,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  // Filled bell when completed (matches web purple bell)
                  isDone
                      ? Icons.notifications_rounded
                      : Icons.notifications_none_rounded,
                  size: 15,
                  color: isDone ? _kAssigneeColor : AppTheme.textDim,
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Row 2: date or "Due" (left) + assignee name (right)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  cardDate.isEmpty ? 'Due' : cardDate,
                  style: AppTheme.caption.copyWith(
                    color: cardDate.isEmpty
                        ? AppTheme.textDim
                        : isOverdue
                            ? AppTheme.danger
                            : AppTheme.textMuted,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _assigneeLabel,
                    style: AppTheme.caption.copyWith(
                      color: _kAssigneeColor,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Create Task FAB ───────────────────────────────────────────────────────────

class _CreateTaskFab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CreateTaskFab> createState() => _CreateTaskFabState();
}

class _CreateTaskFabState extends ConsumerState<_CreateTaskFab> {
  final _titleCtrl = TextEditingController();
  String  _status    = 'not_started';
  String? _priority;
  String? _startDate;
  String? _endDate;
  final List<String> _assignTo = [];
  final List<String> _keywords = [];

  static const _statusOptions = [
    ('not_started', 'Not Started'),
    ('inprogress',  'In Progress'),
    ('completed',   'Completed'),
    ('on_hold',     'On Hold'),
    ('canceled',    'Canceled'),
  ];
  static const _priorityOptions = [
    (null,     'None'),
    ('low',    'Low'),
    ('medium', 'Medium'),
    ('high',   'High'),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate(
    BuildContext ctx,
    String? current,
    void Function(String?) onPicked,
  ) async {
    final initial = (current != null ? DateTime.tryParse(current) : null) ?? DateTime.now();
    final picked = await showDatePicker(
      context: ctx,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppTheme.primary,
            onPrimary: Colors.white,
            surface: AppTheme.bgCard,
          ),
          dialogTheme: DialogThemeData(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) onPicked(picked.toIso8601String());
  }

  void _showCreateSheet() {
    _titleCtrl.clear();
    _status    = 'not_started';
    _priority  = null;
    _startDate = null;
    _endDate   = null;
    _assignTo.clear();
    _keywords.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppTheme.border)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_box_outlined,
                        color: AppTheme.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Create a task', style: AppTheme.headingSmall),
                          Text('Fill in the details below',
                              style: AppTheme.caption.copyWith(
                                  color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded,
                          color: AppTheme.textMuted, size: 20),
                    ),
                  ],
                ),
              ),

              // ── Body ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.bgElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: TextField(
                        controller: _titleCtrl,
                        style: AppTheme.bodyMedium,
                        autofocus: true,
                        maxLines: 2,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: 'Task title…',
                          hintStyle: AppTheme.bodyMedium
                              .copyWith(color: AppTheme.textDim),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          border: InputBorder.none,
                          suffixIcon: ValueListenableBuilder(
                            valueListenable: _titleCtrl,
                            builder: (_, v, __) => v.text.isNotEmpty
                                ? GestureDetector(
                                    onTap: () => setModal(_titleCtrl.clear),
                                    child: const Icon(Icons.close_rounded,
                                        color: AppTheme.textDim, size: 18),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Status + Priority
                    Row(children: [
                      Expanded(
                        child: _DropdownField<String>(
                          label: 'Status',
                          value: _status,
                          items: _statusOptions
                              .map((e) => DropdownMenuItem(
                                    value: e.$1,
                                    child: Text(e.$2,
                                        style: AppTheme.bodySmall.copyWith(
                                            color: AppTheme.textPrimary)),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setModal(() => _status = v ?? 'not_started'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DropdownField<String?>(
                          label: 'Priority',
                          value: _priority,
                          items: _priorityOptions
                              .map((e) => DropdownMenuItem(
                                    value: e.$1,
                                    child: Text(e.$2,
                                        style: AppTheme.bodySmall.copyWith(
                                            color: AppTheme.textPrimary)),
                                  ))
                              .toList(),
                          onChanged: (v) => setModal(() => _priority = v),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),

                    // Dates
                    Row(children: [
                      Expanded(
                        child: _DatePickerField(
                          label: 'Start Date',
                          value: _fmtDate(_startDate),
                          icon: Icons.event_rounded,
                          onTap: () => _pickDate(ctx, _startDate, (v) =>
                              setModal(() => _startDate = v)),
                          onClear: _startDate != null
                              ? () => setModal(() => _startDate = null)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DatePickerField(
                          label: 'Due Date',
                          value: _fmtDate(_endDate),
                          icon: Icons.event_available_rounded,
                          onTap: () => _pickDate(ctx, _endDate, (v) =>
                              setModal(() => _endDate = v)),
                          onClear: _endDate != null
                              ? () => setModal(() => _endDate = null)
                              : null,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),

                    // Keywords chips
                    if (_keywords.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: _keywords
                            .map((kw) => GestureDetector(
                                  onTap: () =>
                                      setModal(() => _keywords.remove(kw)),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: AppTheme.primary
                                              .withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(kw,
                                            style: AppTheme.caption.copyWith(
                                                color: AppTheme.primary,
                                                fontWeight: FontWeight.w600)),
                                        const SizedBox(width: 5),
                                        const Icon(Icons.close_rounded,
                                            size: 11, color: AppTheme.primary),
                                      ],
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Add keyword button
                    GestureDetector(
                      onTap: () => _showAddKeywordDialog(ctx, setModal),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.bgElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add_rounded,
                                size: 15, color: AppTheme.primary),
                            const SizedBox(width: 6),
                            Text('Add a keyword',
                                style: AppTheme.caption.copyWith(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Create button
                    Consumer(builder: (ctx, ref, _) {
                      final loading =
                          ref.watch(tasksNotifierProvider).isMutating;
                      return GestureDetector(
                        onTap: loading ? null : () => _submit(ctx, ref),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          height: 50,
                          decoration: BoxDecoration(
                            gradient:
                                loading ? null : AppTheme.accentGradient,
                            color: loading ? AppTheme.bgElevated : null,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppTheme.accent),
                                  )
                                : Text(
                                    'Create Task',
                                    style: AppTheme.bodyMedium.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddKeywordDialog(BuildContext ctx, StateSetter setModal) {
    final ctrl = TextEditingController();
    showDialog<String>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add Keyword', style: AppTheme.headingSmall),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: AppTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: 'Keyword…',
            hintStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.textDim),
            filled: true,
            fillColor: AppTheme.bgElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.border),
            ),
          ),
          onSubmitted: (v) => Navigator.pop(dctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: Text('Cancel',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dctx, ctrl.text.trim()),
            child: Text('Add',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.primary)),
          ),
        ],
      ),
    ).then((kw) {
      if (kw != null && kw.isNotEmpty && !_keywords.contains(kw)) {
        setModal(() => _keywords.add(kw));
      }
    });
  }

  Future<void> _submit(BuildContext sheetCtx, WidgetRef ref) async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    final me = ref.read(meProvider).value;
    if (me == null) return;

    final sheetNav = Navigator.of(sheetCtx);

    final ok = await ref.read(tasksNotifierProvider.notifier).createTask(
          title: title,
          // Mirror React: conversation_id = user.id, participants = [user.id]
          // when creating from the tasks board (not inside a conversation).
          creatorId: me.id,
          creatorName: me.fullName,
          status: _status,
          priority: _priority,
          startDate: _startDate,
          endDate: _endDate,
          assignTo: List.unmodifiable(_assignTo),
          keywords: List.unmodifiable(_keywords),
        );

    if (!mounted) return;
    sheetNav.pop();
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(tasksNotifierProvider).error ?? 'Failed to create task',
            style: AppTheme.bodySmall.copyWith(color: Colors.white),
          ),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showCreateSheet,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          gradient: AppTheme.accentGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String                     label;
  final T                          value;
  final List<DropdownMenuItem<T>>  items;
  final void Function(T?)          onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTheme.caption.copyWith(color: AppTheme.textMuted)),
        const SizedBox(height: 6),
        Container(
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
              style: AppTheme.bodySmall
                  .copyWith(color: AppTheme.textPrimary),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.onClear,
  });

  final String     label;
  final String     value;
  final IconData   icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final hasValue = value.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTheme.caption.copyWith(color: AppTheme.textMuted)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: hasValue
                  ? AppTheme.primary.withValues(alpha: 0.07)
                  : AppTheme.bgElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasValue
                    ? AppTheme.primary.withValues(alpha: 0.4)
                    : AppTheme.border,
              ),
            ),
            child: Row(
              children: [
                Icon(icon,
                    size: 14,
                    color: hasValue ? AppTheme.primary : AppTheme.textDim),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    hasValue ? value : 'Set date',
                    style: AppTheme.bodySmall.copyWith(
                      color: hasValue ? AppTheme.primary : AppTheme.textDim,
                      fontWeight:
                          hasValue ? FontWeight.w500 : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onClear != null && hasValue)
                  GestureDetector(
                    onTap: onClear,
                    child: const Icon(Icons.close_rounded,
                        size: 14, color: AppTheme.textDim),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
