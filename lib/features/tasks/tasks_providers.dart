import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'task_models.dart';
import 'tasks_service.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class TasksState {
  final List<Task> tasks;
  final bool isLoading;
  final bool isMutating;
  final String? error;
  final List<String>? assignToFilter; // null = all tasks, non-empty = filter by assignee

  const TasksState({
    this.tasks = const [],
    this.isLoading = false,
    this.isMutating = false,
    this.error,
    this.assignToFilter,
  });

  TasksState copyWith({
    List<Task>? tasks,
    bool? isLoading,
    bool? isMutating,
    String? error,
    bool clearError = false,
    List<String>? assignToFilter,
  }) =>
      TasksState(
        tasks: tasks ?? this.tasks,
        isLoading: isLoading ?? this.isLoading,
        isMutating: isMutating ?? this.isMutating,
        error: clearError ? null : (error ?? this.error),
        assignToFilter: assignToFilter ?? this.assignToFilter,
      );

  Map<String, List<Task>> get grouped {
    final map = <String, List<Task>>{
      'not_started': [],
      'inprogress': [],
      'completed': [],
      'on_hold': [],
      'canceled': [],
    };
    for (final t in tasks) {
      map[t.normalizedStatus]?.add(t);
    }
    return map;
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class TasksNotifier extends StateNotifier<TasksState> {
  TasksNotifier() : super(const TasksState()) {
    load();
  }

  Future<void> load({List<String>? assignTo}) async {
    state = state.copyWith(isLoading: true, clearError: true, assignToFilter: assignTo);
    try {
      final all = await TasksService.getTasks();
      final tasks = assignTo != null && assignTo.isNotEmpty
          ? all.where((t) => t.assignTo.any(assignTo.contains)).toList()
          : all;
      state = state.copyWith(tasks: tasks, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void filterMyTasks(String userId) {
    load(assignTo: [userId]);
  }

  void clearFilter() {
    load(assignTo: null);
  }

  Future<bool> createTask({
    required String title,
    required String creatorId,
    required String creatorName,
    String status = 'Not Started',
    String? priority,
    String? startDate,
    String? endDate,
    String? conversationId,
    String? projectId,
    List<String> assignTo = const [],
    List<String> keywords = const [],
  }) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final task = await TasksService.createTask(
        title: title,
        creatorId: creatorId,
        creatorName: creatorName,
        status: status,
        priority: priority,
        startDate: startDate,
        endDate: endDate,
        conversationId: conversationId,
        projectId: projectId,
        assignTo: assignTo,
        keywords: keywords,
      );
      state = state.copyWith(
        tasks: [...state.tasks, task],
        isMutating: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isMutating: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> updateTask({
    required String id,
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
    String? saveType,
  }) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final updated = await TasksService.updateTask(
        id: id,
        title: title,
        status: status,
        priority: priority,
        startDate: startDate,
        endDate: endDate,
        dueTime: dueTime,
        progress: progress,
        notes: notes,
        description: description,
        assignTo: assignTo,
        keywords: keywords,
        observers: observers,
        saveType: saveType,
      );
      state = state.copyWith(
        tasks: state.tasks.map((t) => t.id == id ? updated : t).toList(),
        isMutating: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isMutating: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> deleteTask(String id) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      await TasksService.deleteTask(id);
      state = state.copyWith(
        tasks: state.tasks.where((t) => t.id != id).toList(),
        isMutating: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isMutating: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}

// ── Providers ─────────────────────────────────────────────────────────────────

final tasksNotifierProvider =
    StateNotifierProvider.autoDispose<TasksNotifier, TasksState>((_) => TasksNotifier());

// Convenience alias — derived from the notifier so mutations keep the board live
final kanbanTasksProvider =
    Provider.autoDispose<AsyncValue<Map<String, List<Task>>>>((ref) {
  final state = ref.watch(tasksNotifierProvider);
  if (state.isLoading) return const AsyncValue.loading();
  if (state.error != null && state.tasks.isEmpty) {
    return AsyncValue.error(state.error!, StackTrace.empty);
  }
  return AsyncValue.data(state.grouped);
});