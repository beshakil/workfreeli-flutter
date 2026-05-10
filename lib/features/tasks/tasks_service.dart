import '../../core/network/graphql_client.dart';
import 'task_models.dart';

// ── List query ────────────────────────────────────────────────────────────────

// `read_all: "yes"` mirrors the React web client — tells the backend to return
// all tasks the user has access to, not only tasks directly assigned to them.
// `status` uses [String!] — React uses the same type; the backend schema
// rejects [String] (nullable-item list) with a type-mismatch error.
const _getTasksQuery = '''
query Tasks(
  \$view_type: String!
  \$page: Int!
  \$limit: Int!
  \$read_all: String
  \$status: [String!]
) {
  tasks(
    view_type: \$view_type
    page: \$page
    limit: \$limit
    read_all: \$read_all
    status: \$status
  ) {
    status
    message
    data {
      _id
      task_title
      status
      priority
      start_date
      end_date
      due_time
      progress
      notes
      description
      assign_to
      key_words
      observers
      conversation_id
      conversation_name
      project_id
      project_title
      is_archive
      has_delete
      created_by
      created_at
    }
  }
}
''';

// ── Detail query ──────────────────────────────────────────────────────────────

const _getTaskDetailQuery = '''
query GetTaskDetail(\$id: String!) {
  task(_id: \$id) {
    _id
    task_title
    status
    priority
    start_date
    end_date
    due_time
    progress
    notes
    description
    assign_to
    key_words
    observers
    owned_by
    conversation_id
    conversation_name
    project_id
    project_title
    is_archive
    has_delete
    created_by
    created_at
    checklists {
      _id
      item_title
      checked
    }
    files {
      _id
      originalname
      file_type
      file_size
      location
      created_at
      uploaded_by
      tag_list_details {
        tag_id
        title
        tag_color
      }
    }
    discussion {
      _id
      msg_body
      created_by
      created_at
      attach_files {
        allfiles {
          originalname
          file_type
          location
          file_size
        }
      }
    }
    hour_breakdown {
      _id
      fdate
      tdate
      forecasted_hours
      actual_hour
      note
    }
    cost_breakdown {
      _id
      cost_title
      forecasted_cost
      actual_cost
    }
  }
}
''';

// ── Mutations ─────────────────────────────────────────────────────────────────

// Schema-verified: create_quick_tasks returns [TaskType] directly —
// no {status, message, data} wrapper unlike the tasks query.
// createTaskInput required fields: task_title, conversation_id,
// conversation_name, participants (all must be provided, even as empty).
const _createTaskMutation = '''
mutation CreateTask(\$input: [createTaskInput!]!) {
  create_quick_tasks(input: \$input) {
    _id
    task_title
    status
    priority
    start_date
    end_date
    assign_to
    key_words
    conversation_id
    conversation_name
    project_id
    project_title
    created_by
    created_at
  }
}
''';

const _updateTaskMutation = '''
mutation UpdateTask(\$input: updateTaskInput!) {
  update_single_task(input: \$input) {
    status
    message
    data {
      _id
      task_title
      status
      priority
      start_date
      end_date
      due_time
      progress
      notes
      description
      assign_to
      key_words
      observers
      conversation_id
      conversation_name
      is_archive
      created_by
      created_at
    }
  }
}
''';

const _deleteTaskMutation = '''
mutation DeleteTask(\$input: deleteTaskInput!) {
  delete_task(input: \$input) {
    status
    message
  }
}
''';

// ── Service ───────────────────────────────────────────────────────────────────

class TasksService {
  TasksService._();

  static Future<List<Task>> getTasks({
    int page = 1,
    int limit = 100,
    List<String>? statusFilter,
  }) async {
    final data = await GraphQLService.call(
      _getTasksQuery,
      variables: {
        'view_type': 'list',
        'page': page,
        'limit': limit,
        'read_all': 'yes',
        if (statusFilter != null && statusFilter.isNotEmpty)
          'status': statusFilter,
      },
    );

    final response = data['tasks'] as Map<String, dynamic>? ?? {};
    final list = response['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => Task.fromJson(e as Map<String, dynamic>))
        .where((t) => t.id.isNotEmpty && !t.isArchived)
        .toList();
  }

  static Future<Task> getTaskDetail(String id) async {
    final data = await GraphQLService.call(
      _getTaskDetailQuery,
      variables: {'id': id},
    );

    final taskData = data['task'] as Map<String, dynamic>?;
    if (taskData == null) throw const GqlException('Task detail not found.');
    return Task.fromJson(taskData);
  }

  // createTaskInput only accepts these fields (schema-verified):
  //   task_title!, conversation_id!, conversation_name!, participants!,
  //   project_id, created_at, start_date, end_date, status,
  //   assign_to, observers, key_words
  //
  // priority/notes/description/due_time are NOT in createTaskInput.
  // If priority is provided, a follow-up updateTask call sets it.
  // React fallback (CreateQuickTask.js:70-72): when not inside a conversation,
  // conversation_id = user.id, participants = [user.id], conversation_name = full name.
  static Future<Task> createTask({
    required String title,
    required String creatorId,
    required String creatorName,
    String status = 'not_started',
    String? priority,
    String? startDate,
    String? endDate,
    String? conversationId,
    String? projectId,
    List<String> assignTo = const [],
    List<String> keywords = const [],
  }) async {
    final resolvedConvId = (conversationId != null && conversationId.isNotEmpty)
        ? conversationId
        : creatorId;

    final input = {
      'task_title': title,
      'status': status,
      'conversation_id': resolvedConvId,
      'conversation_name': creatorName,
      'participants': [creatorId],
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (projectId != null) 'project_id': projectId,
      if (assignTo.isNotEmpty) 'assign_to': assignTo,
      if (keywords.isNotEmpty) 'key_words': keywords,
    };

    final data = await GraphQLService.call(
      _createTaskMutation,
      variables: {'input': [input]},
    );

    // ignore: avoid_print
    print('[createTask] server raw: ${data['create_quick_tasks']}');

    final rawResult = data['create_quick_tasks'];
    if (rawResult == null) {
      // Server swallowed an error — check backend console for [create_tasks] OUTER CATCH
      throw const GqlException(
          'Task creation failed on server. Check server logs.');
    }
    final list = rawResult as List<dynamic>;
    if (list.isEmpty) {
      // Backend returned [] — either plan limit reached or create_tasks failed silently
      throw const GqlException(
          'Task creation failed: plan limit reached or server error. Check server logs.');
    }
    Task task = Task.fromJson(list.first as Map<String, dynamic>);

    // priority is not in createTaskInput — set via a follow-up update.
    if (priority != null) {
      try {
        task = await updateTask(id: task.id, priority: priority);
      } catch (_) {
        // Non-fatal: task was created, priority just didn't apply.
      }
    }
    return task;
  }

  static Future<Task> updateTask({
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
    final input = <String, dynamic>{'_id': id};
    if (title != null) input['task_title'] = title;
    if (status != null) input['status'] = status;
    if (priority != null) input['priority'] = priority;
    if (startDate != null) input['start_date'] = startDate;
    if (endDate != null) input['end_date'] = endDate;
    if (dueTime != null) input['due_time'] = dueTime;
    if (progress != null) input['progress'] = progress;
    if (notes != null) input['notes'] = notes;
    if (description != null) input['description'] = description;
    if (assignTo != null) input['assign_to'] = assignTo;
    if (keywords != null) input['key_words'] = keywords;
    if (observers != null) input['observers'] = observers;
    if (saveType != null) input['save_type'] = saveType;

    final data = await GraphQLService.call(
      _updateTaskMutation,
      variables: {'input': input},
    );

    final response =
        data['update_single_task'] as Map<String, dynamic>? ?? {};
    final taskData = response['data'] as Map<String, dynamic>?;
    if (taskData == null) {
      throw const GqlException('Task update returned no data.');
    }
    return Task.fromJson(taskData);
  }

  static Future<void> deleteTask(String id) async {
    await GraphQLService.call(
      _deleteTaskMutation,
      variables: {
        'input': {'_id': id},
      },
    );
  }
}
