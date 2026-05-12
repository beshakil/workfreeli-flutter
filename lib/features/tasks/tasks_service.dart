import '../../core/network/graphql_client.dart';
import 'task_models.dart';

// ── List query ────────────────────────────────────────────────────────────────

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

// create_quick_tasks returns [TaskType] directly — no {status,message,data} wrapper.
// createTaskInput required: task_title, conversation_id, conversation_name, participants.
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
    observers
    conversation_id
    conversation_name
    project_id
    project_title
    created_by
    created_at
  }
}
''';

// CRITICAL: update_single_task returns [TaskType] directly — NOT {status,message,data}.
// Requesting {status,message,data} makes every field resolve to null → "no data" error.
const _updateTaskMutation = '''
mutation UpdateTask(\$input: updateTaskInput!) {
  update_single_task(input: \$input) {
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
    created_by
    created_at
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

  // createTaskInput fields: task_title!, conversation_id!, conversation_name!,
  // participants!, project_id, created_at, start_date, end_date, status,
  // assign_to, observers, key_words.
  // React always sends assign_to/observers/key_words as [] (never omits them).
  static Future<Task> createTask({
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
    List<String> observers = const [],
  }) async {
    final resolvedConvId = (conversationId != null && conversationId.isNotEmpty)
        ? conversationId
        : creatorId;

    final input = <String, dynamic>{
      'task_title': title,
      'status': status,
      'conversation_id': resolvedConvId,
      'conversation_name': creatorName,
      'participants': [creatorId],
      'assign_to': assignTo,
      'observers': observers,
      'key_words': keywords,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (projectId != null && projectId.isNotEmpty) 'project_id': projectId,
    };

    // ignore: avoid_print
    print('[createTask] payload: $input');

    final data = await GraphQLService.call(
      _createTaskMutation,
      variables: {'input': [input]},
    );

    final rawResult = data['create_quick_tasks'];
    // ignore: avoid_print
    print('[createTask] server response: $rawResult');

    if (rawResult == null) {
      throw const GqlException('Task creation failed on server. Check server logs.');
    }
    final list = rawResult as List<dynamic>;
    if (list.isEmpty) {
      throw const GqlException(
          'Task creation failed: plan limit reached or server error.');
    }
    Task task = Task.fromJson(list.first as Map<String, dynamic>);

    // priority is not in createTaskInput — set via a follow-up update.
    if (priority != null) {
      try {
        task = await updateTask(id: task.id, priority: priority);
      } catch (_) {}
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

    // ignore: avoid_print
    print('[updateTask] payload: $input');

    final data = await GraphQLService.call(
      _updateTaskMutation,
      variables: {'input': input},
    );

    // update_single_task returns [TaskType] directly — parse as list.
    final rawList = data['update_single_task'] as List<dynamic>?;
    // ignore: avoid_print
    print('[updateTask] server response: $rawList');

    if (rawList == null || rawList.isEmpty) {
      throw const GqlException('Task update returned no data.');
    }
    return Task.fromJson(rawList.first as Map<String, dynamic>);
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
