import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'task_models.dart';
import 'tasks_service.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class TasksState {
  final List<Task> tasks;
  final bool isLoading;
  final bool isMutating;
  final String? error;

  const TasksState({
    this.tasks = const [],
    this.isLoading = false,
    this.isMutating = false,
    this.error,
  });

  TasksState copyWith({
    List<Task>? tasks,
    bool? isLoading,
    bool? isMutating,
    String? error,
    bool clearError = false,
  }) =>
      TasksState(
        tasks: tasks ?? this.tasks,
        isLoading: isLoading ?? this.isLoading,
        isMutating: isMutating ?? this.isMutating,
        error: clearError ? null : (error ?? this.error),
      );

  Map<String, List<Task>> get grouped {
    final map = <String, List<Task>>{
      'not_started': [],
      'inprogress': [],
      'on_hold': [],
      'canceled': [],
      'completed': [],
    };
    for (final task in tasks) {
      (map[task.normalizedStatus] ??= []).add(task);
    }
    return map;
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class TasksNotifier extends StateNotifier<TasksState> {
  TasksNotifier() : super(const TasksState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final tasks = await TasksService.getTasks();
      state = state.copyWith(tasks: tasks, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<bool> createTask({
    required String title,
    required String companyId,
    String status = 'todo',
    String? priority,
    String? startDate,
    String? endDate,
    String? conversationId,
    String? projectId,
    List<String> assignTo = const [],
    String? notes,
    String? description,
  }) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final task = await TasksService.createTask(
        title: title,
        companyId: companyId,
        status: status,
        priority: priority,
        startDate: startDate,
        endDate: endDate,
        conversationId: conversationId,
        projectId: projectId,
        assignTo: assignTo,
        notes: notes,
        description: description,
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
