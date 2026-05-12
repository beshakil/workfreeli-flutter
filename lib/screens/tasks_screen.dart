import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../features/tasks/task_models.dart';
import '../features/tasks/tasks_providers.dart';
import '../core/models/conversation_models.dart';
import '../features/conversations/conversations_providers.dart';
import '../features/user/user_models.dart';
import '../features/user/user_providers.dart';
import 'task_detail_screen.dart';

const _kAssigneeColor = Color(0xFF2440BD);

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _statusFilter; // null = all, otherwise a normalizedStatus key

  // Web column order
  static const _columns = [
    _ColumnConfig('not_started', 'Not Started', Color(0xFF94A3B8)),
    _ColumnConfig('inprogress', 'In Progress', Color(0xFF6366F1)),
    _ColumnConfig('completed', 'Completed', Color(0xFF10B981)),
    _ColumnConfig('on_hold', 'On Hold', Color(0xFFF59E0B)),
    _ColumnConfig('canceled', 'Canceled', Color(0xFFEF4444)),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await ref.read(tasksNotifierProvider.notifier).load();
  }

  List<Task> _applyFilter(List<Task> all) {
    var tasks = all;
    if (_statusFilter != null) {
      tasks = tasks.where((t) => t.normalizedStatus == _statusFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      tasks = tasks
          .where((t) =>
              t.title.toLowerCase().contains(q) ||
              (t.conversationName?.toLowerCase().contains(q) ?? false) ||
              (t.projectTitle?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    return tasks;
  }

  @override
  Widget build(BuildContext context) {
    final kanbanAsync = ref.watch(kanbanTasksProvider);
    final taskState = ref.watch(tasksNotifierProvider);
    final usersMap = ref.watch(usersMapProvider).value ?? const {};

    return Stack(
      children: [
        Column(
          children: [
            _buildHeader(context, taskState),
            _buildSearchBar(),
            _buildFilterChips(),
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
                  onRetry: _refresh,
                ),
                data: (grouped) {
                  final allTasks = taskState.tasks;
                  final filtered = _applyFilter(allTasks);

                  if (_searchQuery.isNotEmpty || _statusFilter != null) {
                    return _buildListView(filtered, usersMap);
                  }
                  return _buildKanbanBoard(grouped, usersMap);
                },
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

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, TasksState state) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 20,
        right: 20,
        bottom: 14,
      ),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Task Board', style: AppTheme.headingMedium),
              const SizedBox(height: 2),
              Text('${state.tasks.length} tasks', style: AppTheme.caption),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: state.isLoading ? null : _refresh,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                gradient: state.isLoading ? null : AppTheme.accentGradient,
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

  // ── Search bar ─────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Container(
      color: AppTheme.bgCard,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: AppTheme.bgElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: TextField(
          controller: _searchCtrl,
          style: AppTheme.bodySmall,
          onChanged: (v) => setState(() => _searchQuery = v.trim()),
          decoration: InputDecoration(
            hintText: 'Search tasks…',
            hintStyle: AppTheme.bodySmall.copyWith(color: AppTheme.textDim),
            prefixIcon:
                const Icon(Icons.search_rounded, color: AppTheme.textDim, size: 17),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: const Icon(Icons.close_rounded,
                        color: AppTheme.textDim, size: 16),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 9),
          ),
        ),
      ),
    );
  }

  // ── Filter chips ───────────────────────────────────────────────────────────

  Widget _buildFilterChips() {
    return Container(
      color: AppTheme.bgCard,
      padding: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _filterChip(null, 'All', const Color(0xFF64748B)),
            ..._columns.map(
              (c) => _filterChip(c.key, c.title, c.color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String? key, String label, Color color) {
    final selected = _statusFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _statusFilter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : AppTheme.bgElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : AppTheme.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            Text(
              label,
              style: AppTheme.caption.copyWith(
                color: selected ? Colors.white : AppTheme.textMuted,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Kanban board (no filter active) ────────────────────────────────────────

  Widget _buildKanbanBoard(
      Map<String, List<Task>> grouped, Map<String, String> usersMap) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppTheme.primary,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 16, 2, 16),
        itemCount: _columns.length,
        itemBuilder: (context, i) {
          final col = _columns[i];
          final tasks = grouped[col.key] ?? [];
          return _KanbanColumn(column: col, tasks: tasks, usersMap: usersMap);
        },
      ),
    );
  }

  // ── List view (filter/search active) ───────────────────────────────────────

  Widget _buildListView(List<Task> tasks, Map<String, String> usersMap) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _searchQuery.isNotEmpty
                  ? Icons.search_off_rounded
                  : Icons.assignment_outlined,
              size: 48,
              color: AppTheme.textDim,
            ),
            const SizedBox(height: 14),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No tasks match "$_searchQuery"'
                  : 'No tasks in this status',
              style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text('Try a different filter or search term',
                style: AppTheme.caption),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: tasks.length,
        itemBuilder: (_, i) => _ListTaskCard(
          task: tasks[i],
          usersMap: usersMap,
        ),
      ),
    );
  }

  // ── Error banner ───────────────────────────────────────────────────────────

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

  // ── Loading skeleton ───────────────────────────────────────────────────────

  Widget _buildLoadingBoard() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (_, __) => Container(
        width: 220,
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

  // ── Full error state ───────────────────────────────────────────────────────

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
                style:
                    AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(message,
                style: AppTheme.caption, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.accent),
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

  final _ColumnConfig column;
  final List<Task> tasks;
  final Map<String, String> usersMap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                    style: AppTheme.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded,
                      size: 16, color: AppTheme.textDim),
                ]),
              ),
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
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ]),
          ),
          Expanded(
            child: tasks.isEmpty
                ? Center(
                    child: Text('No tasks',
                        style: AppTheme.caption
                            .copyWith(color: AppTheme.textDim)),
                  )
                : ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (_, i) =>
                        _TaskCard(task: tasks[i], usersMap: usersMap),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Task Card (Kanban) ─────────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.usersMap});

  final Task task;
  final Map<String, String> usersMap;

  String get _assigneeLabel {
    if (task.assignTo.isEmpty) return 'N/A';
    final id = task.assignTo.first;
    final name = usersMap[id];
    if (name != null && name.isNotEmpty) return name;
    final atIdx = id.indexOf('@');
    if (atIdx > 0) return id.substring(0, atIdx);
    return 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    final isDone = task.normalizedStatus == 'completed';
    final isCanceled = task.normalizedStatus == 'canceled';
    final cardDate = task.formattedCardDate;
    final isOverdue = task.isOverdue && !isDone && !isCanceled;

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
                  isDone
                      ? Icons.notifications_rounded
                      : Icons.notifications_none_rounded,
                  size: 15,
                  color: isDone ? _kAssigneeColor : AppTheme.textDim,
                ),
              ],
            ),
            // Priority badge (if set)
            if (task.priority != null && task.priority!.isNotEmpty) ...[
              const SizedBox(height: 6),
              _PriorityBadge(priority: task.priority!),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (isOverdue)
                      const Icon(Icons.warning_amber_rounded,
                          size: 11, color: AppTheme.danger),
                    if (isOverdue) const SizedBox(width: 3),
                    Text(
                      cardDate.isEmpty ? 'No date' : cardDate,
                      style: AppTheme.caption.copyWith(
                        color: cardDate.isEmpty
                            ? AppTheme.textDim
                            : isOverdue
                                ? AppTheme.danger
                                : AppTheme.textMuted,
                        fontWeight:
                            isOverdue ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
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

// ── List Task Card (filtered/search view) ─────────────────────────────────────

class _ListTaskCard extends StatelessWidget {
  const _ListTaskCard({required this.task, required this.usersMap});

  final Task task;
  final Map<String, String> usersMap;

  @override
  Widget build(BuildContext context) {
    final isDone = task.normalizedStatus == 'completed';
    final isCanceled = task.normalizedStatus == 'canceled';
    final isOverdue = task.isOverdue && !isDone && !isCanceled;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOverdue
                ? AppTheme.danger.withValues(alpha: 0.5)
                : AppTheme.border,
          ),
        ),
        child: Row(
          children: [
            // Status dot
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 12, top: 2),
              decoration: BoxDecoration(
                color: _statusColor(task.normalizedStatus),
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: AppTheme.bodySmall.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isDone || isCanceled
                          ? AppTheme.textDim
                          : AppTheme.textPrimary,
                      decoration: isDone || isCanceled
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: AppTheme.textDim,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      if (task.priority != null && task.priority!.isNotEmpty) ...[
                        _PriorityBadge(priority: task.priority!, compact: true),
                        const SizedBox(width: 8),
                      ],
                      if (task.formattedDueDate.isNotEmpty) ...[
                        Icon(
                          isOverdue
                              ? Icons.warning_amber_rounded
                              : Icons.event_rounded,
                          size: 11,
                          color: isOverdue ? AppTheme.danger : AppTheme.textDim,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          task.formattedDueDate,
                          style: AppTheme.caption.copyWith(
                            color: isOverdue ? AppTheme.danger : AppTheme.textMuted,
                            fontWeight:
                                isOverdue ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (task.conversationName?.isNotEmpty == true)
                        Flexible(
                          child: Text(
                            task.conversationName!,
                            style: AppTheme.caption
                                .copyWith(color: AppTheme.textDim),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (task.assignTo.isNotEmpty)
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: _kAssigneeColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: _kAssigneeColor.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Text(
                    _initials(usersMap[task.assignTo.first] ?? '?'),
                    style: const TextStyle(
                        color: _kAssigneeColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Color _statusColor(String s) {
    switch (s) {
      case 'not_started':
        return const Color(0xFF94A3B8);
      case 'inprogress':
        return const Color(0xFF6366F1);
      case 'completed':
        return const Color(0xFF10B981);
      case 'on_hold':
        return const Color(0xFFF59E0B);
      case 'canceled':
        return const Color(0xFFEF4444);
      default:
        return AppTheme.textDim;
    }
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty
        ? name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase()
        : '?';
  }
}

// ── Priority badge ─────────────────────────────────────────────────────────────

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority, this.compact = false});

  final String priority;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = priority.toLowerCase();
    final Color color;
    final IconData icon;
    switch (p) {
      case 'high':
        color = AppTheme.danger;
        icon = Icons.keyboard_double_arrow_up_rounded;
        break;
      case 'medium':
        color = AppTheme.warning;
        icon = Icons.remove_rounded;
        break;
      case 'low':
        color = AppTheme.success;
        icon = Icons.keyboard_double_arrow_down_rounded;
        break;
      default:
        color = AppTheme.textDim;
        icon = Icons.remove_rounded;
    }

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 2),
          Text(
            _capitalize(p),
            style: AppTheme.caption.copyWith(
                color: color, fontWeight: FontWeight.w600, fontSize: 10),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            _capitalize(p),
            style: AppTheme.caption.copyWith(
                color: color, fontWeight: FontWeight.w600, fontSize: 10),
          ),
        ],
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

// ── Create Task FAB ───────────────────────────────────────────────────────────

class _CreateTaskFab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CreateTaskFab> createState() => _CreateTaskFabState();
}

class _CreateTaskFabState extends ConsumerState<_CreateTaskFab> {
  final _titleCtrl = TextEditingController();
  String _status = 'Not Started';
  String? _priority;
  String? _startDate;
  String? _endDate;
  final List<String> _keywords = [];
  String? _conversationId;
  String? _conversationName;
  final List<String> _selectedAssigneeIds = [];

  static const _statusOptions = [
    ('Not Started', 'Not Started'),
    ('In Progress', 'In Progress'),
    ('Completed', 'Completed'),
    ('On Hold', 'On Hold'),
    ('Canceled', 'Canceled'),
  ];
  static const _priorityOptions = [
    (null, 'None'),
    ('low', 'Low'),
    ('medium', 'Medium'),
    ('high', 'High'),
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
    final initial =
        (current != null ? DateTime.tryParse(current) : null) ?? DateTime.now();
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16))),
        ),
        child: child!,
      ),
    );
    if (picked != null) onPicked(picked.toUtc().toIso8601String());
  }

  void _showCreateSheet() {
    _titleCtrl.clear();
    _status = 'Not Started';
    _priority = null;
    _startDate = null;
    _endDate = null;
    _keywords.clear();
    _conversationId = null;
    _conversationName = null;
    _selectedAssigneeIds.clear();

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
              // Header
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
                              style: AppTheme.caption
                                  .copyWith(color: AppTheme.textMuted)),
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
              // Body
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title field
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
                        maxLength: 72,
                        decoration: InputDecoration(
                          hintText: 'Task title…',
                          hintStyle: AppTheme.bodyMedium
                              .copyWith(color: AppTheme.textDim),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          border: InputBorder.none,
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Room picker
                    _buildRoomField(setModal),
                    const SizedBox(height: 14),
                    // Assigned to picker
                    _buildAssigneeField(setModal),
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
                          onTap: () => _pickDate(context, _startDate,
                              (v) => setModal(() => _startDate = v)),
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
                          onTap: () => _pickDate(context, _endDate,
                              (v) => setModal(() => _endDate = v)),
                          onClear: _endDate != null
                              ? () => setModal(() => _endDate = null)
                              : null,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    // Keywords
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
                            gradient: loading ? null : AppTheme.accentGradient,
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
            hintStyle:
                AppTheme.bodyMedium.copyWith(color: AppTheme.textDim),
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
                style:
                    AppTheme.bodySmall.copyWith(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dctx, ctrl.text.trim()),
            child: Text('Add',
                style:
                    AppTheme.bodySmall.copyWith(color: AppTheme.primary)),
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
          creatorId: me.id,
          creatorName: me.fullName,
          status: _status,
          priority: _priority,
          startDate: _startDate,
          endDate: _endDate,
          keywords: List.unmodifiable(_keywords),
          conversationId: _conversationId,
          assignTo: List.unmodifiable(_selectedAssigneeIds),
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

  // ── Room picker field widget ─────────────────────────────────────────────────

  Widget _buildRoomField(StateSetter setModal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Room',
            style: AppTheme.caption.copyWith(color: AppTheme.textMuted)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _showRoomPicker(setModal),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _conversationId != null
                  ? AppTheme.primary.withValues(alpha: 0.07)
                  : AppTheme.bgElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _conversationId != null
                    ? AppTheme.primary.withValues(alpha: 0.4)
                    : AppTheme.border,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.forum_outlined,
                    size: 15,
                    color: _conversationId != null
                        ? AppTheme.primary
                        : AppTheme.textDim),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _conversationName ?? 'Select a room',
                    style: AppTheme.bodySmall.copyWith(
                      color: _conversationId != null
                          ? AppTheme.primary
                          : AppTheme.textDim,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.expand_more_rounded,
                    size: 16, color: AppTheme.textDim),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Assignee field widget ────────────────────────────────────────────────────

  Widget _buildAssigneeField(StateSetter setModal) {
    final users = ref.read(companyUsersProvider).value ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Assigned to',
            style: AppTheme.caption.copyWith(color: AppTheme.textMuted)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _showAssigneePicker(setModal),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.bgElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_add_alt_1_rounded,
                    size: 15, color: AppTheme.textDim),
                const SizedBox(width: 8),
                Expanded(
                  child: _selectedAssigneeIds.isEmpty
                      ? Text('Assign to…',
                          style: AppTheme.bodySmall
                              .copyWith(color: AppTheme.textDim))
                      : Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: _selectedAssigneeIds.map((id) {
                            final user = users
                                .cast<CompanyUser?>()
                                .firstWhere((u) => u?.id == id,
                                    orElse: () => null);
                            final label = user?.fullName ??
                                (id.length > 12
                                    ? '${id.substring(0, 10)}…'
                                    : id);
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.primary
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                label.length > 14
                                    ? '${label.substring(0, 12)}…'
                                    : label,
                                style: AppTheme.caption.copyWith(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ),
                const Icon(Icons.expand_more_rounded,
                    size: 16, color: AppTheme.textDim),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Room picker bottom sheet ─────────────────────────────────────────────────

  Future<void> _showRoomPicker(StateSetter setModal) async {
    final rooms = ref.read(roomsProvider).value ?? [];
    String query = '';
    var filtered = List<Room>.from(rooms);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
                decoration: BoxDecoration(
                    border:
                        Border(bottom: BorderSide(color: AppTheme.border))),
                child: Row(children: [
                  const Icon(Icons.forum_outlined,
                      color: AppTheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text('Select Room',
                          style: AppTheme.headingSmall)),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetCtx),
                    icon: const Icon(Icons.close_rounded,
                        color: AppTheme.textMuted, size: 20),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.bgElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: TextField(
                    autofocus: true,
                    style: AppTheme.bodySmall,
                    onChanged: (v) {
                      query = v.toLowerCase();
                      setSheet(() {
                        filtered = rooms
                            .where((r) =>
                                r.title.toLowerCase().contains(query))
                            .toList();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search rooms…',
                      hintStyle: AppTheme.bodySmall
                          .copyWith(color: AppTheme.textDim),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppTheme.textDim, size: 17),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text('No rooms found',
                            style: AppTheme.caption
                                .copyWith(color: AppTheme.textDim)))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final room = filtered[i];
                          final selected = room.id == _conversationId;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            onTap: () {
                              setModal(() {
                                _conversationId = room.id;
                                _conversationName = room.title;
                              });
                              Navigator.pop(sheetCtx);
                            },
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color:
                                    AppTheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                room.isGroup
                                    ? Icons.group_rounded
                                    : Icons.person_rounded,
                                size: 18,
                                color: AppTheme.primary,
                              ),
                            ),
                            title: Text(room.title,
                                style: AppTheme.bodySmall.copyWith(
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500)),
                            trailing: selected
                                ? const Icon(Icons.check_circle_rounded,
                                    color: AppTheme.primary, size: 20)
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Assignee picker bottom sheet ─────────────────────────────────────────────

  Future<void> _showAssigneePicker(StateSetter setModal) async {
    final users = ref.read(companyUsersProvider).value ?? [];
    String query = '';
    var filtered = List<CompanyUser>.from(users);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
                decoration: BoxDecoration(
                    border:
                        Border(bottom: BorderSide(color: AppTheme.border))),
                child: Row(children: [
                  const Icon(Icons.person_add_alt_1_rounded,
                      color: AppTheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                      child:
                          Text('Assign To', style: AppTheme.headingSmall)),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetCtx),
                    icon: const Icon(Icons.close_rounded,
                        color: AppTheme.textMuted, size: 20),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.bgElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: TextField(
                    autofocus: true,
                    style: AppTheme.bodySmall,
                    onChanged: (v) {
                      query = v.toLowerCase();
                      setSheet(() {
                        filtered = users
                            .where((u) =>
                                u.fullName.toLowerCase().contains(query) ||
                                (u.email?.toLowerCase().contains(query) ??
                                    false))
                            .toList();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search users…',
                      hintStyle: AppTheme.bodySmall
                          .copyWith(color: AppTheme.textDim),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppTheme.textDim, size: 17),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text('No users found',
                            style: AppTheme.caption
                                .copyWith(color: AppTheme.textDim)))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final user = filtered[i];
                          final selected =
                              _selectedAssigneeIds.contains(user.id);
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 2),
                            onTap: () {
                              setModal(() {
                                if (selected) {
                                  _selectedAssigneeIds.remove(user.id);
                                } else {
                                  _selectedAssigneeIds.add(user.id);
                                }
                              });
                              setSheet(() {});
                            },
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppTheme.primary
                                    : AppTheme.primary
                                        .withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  user.initials,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            title: Text(user.fullName,
                                style: AppTheme.bodySmall),
                            subtitle: user.email != null
                                ? Text(user.email!,
                                    style: AppTheme.caption)
                                : null,
                            trailing: Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: selected
                                  ? AppTheme.primary
                                  : AppTheme.textDim,
                              size: 20,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
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

// ── Shared dropdown field ─────────────────────────────────────────────────────

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;

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
              style:
                  AppTheme.bodySmall.copyWith(color: AppTheme.textPrimary),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shared date picker field ──────────────────────────────────────────────────

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final String value;
  final IconData icon;
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
