import '../../core/network/graphql_client.dart';
import 'task_models.dart';

// ── Queries ───────────────────────────────────────────────────────────────────

// `read_all: "yes"` mirrors the React web client — tells the backend to return
// all tasks the user has access to, not only tasks directly assigned to them.
// `status` uses [String!] (non-null items) — React uses the same type and the
// backend schema rejects [String] with a type-mismatch error.
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

// ── Mutations ─────────────────────────────────────────────────────────────────

const _createTaskMutation = '''
mutation CreateTask(\$input: [createTaskInput!]!) {
  create_quick_tasks(input: \$input) {
    status
    message
    data {
      _id
      task_title
      status
      priority
      start_date
      end_date
      assign_to
      conversation_id
      conversation_name
      project_id
      project_title
      created_by
      created_at
    }
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

  static Future<Task> createTask({
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
    final input = {
      'task_title': title,
      'company_id': companyId,
      'status': status,
      if (priority != null) 'priority': priority,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (conversationId != null) 'conversation_id': conversationId,
      if (projectId != null) 'project_id': projectId,
      if (assignTo.isNotEmpty) 'assign_to': assignTo,
      if (notes != null) 'notes': notes,
      if (description != null) 'description': description,
    };

    final data = await GraphQLService.call(
      _createTaskMutation,
      variables: {'input': [input]},
    );

    final response = data['create_quick_tasks'] as Map<String, dynamic>? ?? {};
    final list = response['data'] as List<dynamic>? ?? [];
    if (list.isEmpty) throw const GqlException('Task creation returned no data.');
    return Task.fromJson(list.first as Map<String, dynamic>);
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

    final data = await GraphQLService.call(
      _updateTaskMutation,
      variables: {'input': input},
    );

    final response = data['update_single_task'] as Map<String, dynamic>? ?? {};
    final taskData = response['data'] as Map<String, dynamic>?;
    if (taskData == null) throw const GqlException('Task update returned no data.');
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
