# Task Management System - Implementation Guide

## Overview
This document describes the task management system implementation across the Flutter mobile app, Node.js GraphQL backend, and React web app.

## Architecture

### Backend (Node.js GraphQL)
- **Location**: `server_project/graphql_apollo_server/`
- **Schema**: `typeDefs/taskSchema.js`
- **Resolvers**: `Resolvers/task.js`
- **Utils**: `utils/task.js`

### Flutter Mobile App
- **Location**: `freeli_app/lib/`
- **Models**: `features/tasks/task_models.dart`
- **Providers**: `features/tasks/tasks_providers.dart`
- **Service**: `features/tasks/tasks_service.dart`
- **UI**: `screens/tasks_screen.dart`

### React Web App  
- **Location**: `Client/bun_web/src/`
- **Components**: `Components/TasksManagement/`
- **Styles**: `Stylesheets/tasks/`

## GraphQL Schema

### New Mutation: `create_task`
```graphql
mutation CreateTask($input: createSingleTaskInput!) {
  create_task(input: $input) {
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
      # ... other fields
    }
  }
}
```

### Input Type: `createSingleTaskInput`
```graphql
input createSingleTaskInput {
  title: String!                    # Task title (required)
  status: String                    # Status: Not Started, In Progress, etc.
  priority: String                  # Priority: low, medium, high
  start_date: String                # ISO date string
  end_date: String                  # ISO date string  
  due_time: String                  # Time string
  description: String               # Task description
  notes: String                     # Additional notes
  conversation_id: String           # Conversation ID (auto-generated if not provided)
  conversation_name: String         # Conversation name
  project_id: String                # Associated project
  assign_to: [String!]              # Array of user IDs to assign
  observers: [String!]              # Array of observer user IDs
  owned_by: [String!]               # Array of owner user IDs
  key_words: [String!]              # Array of keyword strings
  checklists: [ChecklistInput!]     # Array of checklist items
  progress: Int                     # Progress percentage (0-100)
}
```

## Backend Implementation

### Task Creation Flow
1. **Validation**: Check required fields (title)
2. **Conversation Setup**: Create or use provided conversation
3. **Task Creation**: Save task to MongoDB
4. **Checklists**: Create associated checklist items if provided
5. **Keywords**: Create new keywords and link to task
6. **XMPP Messaging**: Send notifications to participants
7. **Notifications**: Create system notifications for assignees

### Key Functions

#### Enhanced Task Creation (`utils/task.js`)
- Handles creation from Flutter, React, and web clients
- Supports nested data (checklists, keywords, observers)
- Auto-generates conversation IDs for standalone tasks
- Sets up XMPP messages and notifications
- Returns fully-formed task object

#### Task Update
- Supports all task fields including nested relationships
- Handles status and progress changes
- Updates associated checklists and keywords

## Flutter Integration

### Service Layer (`tasks_service.dart`)
```dart
static Future<Task> createTask({
  required String title,
  String status = 'not_started',
  String? priority,
  String? startDate,
  String? endDate,
  String? conversationId,
  String? projectId,
  List<String> assignTo = const [],
  List<String> keywords = const [],
  List<String> observers = const [],
  List<Map<String, dynamic>> checklists = const [],
}) async {
  // Maps status to backend format
  // Sends GraphQL mutation
  // Returns Task object
}
```

### Status Mapping
| Flutter Status | Backend Status |
|---------------|----------------|
| not_started | Not Started |
| inprogress | In Progress |
| completed | Completed |
| on_hold | On Hold |
| canceled | Canceled |

## React Integration

### Task Context
The React app uses a `TaskContext` to manage task state:
- Task list
- Filtering (status, progress, assignee, keywords)
- Pagination
- Sorting

### Components
- **TaskListView**: Main task listing with filters
- **TaskList**: Individual task cards
- **TaskKanbanView**: Kanban board view
- **TaskModal**: Create/edit task modal
- **Calendar**: Task calendar integration

### API Calls
Tasks are managed via GraphQL queries:
- `tasks`: List tasks with filters
- `task`: Get single task detail
- `create_task`: Create new task
- `update_single_task`: Update existing task
- `delete_task`: Delete task

## Usage Examples

### Flutter - Create Task
```dart
final task = await TasksService.createTask(
  title: 'Complete project report',
  status: 'not_started',
  priority: 'high',
  assignTo: ['user123', 'user456'],
  startDate: '2024-01-15',
  endDate: '2024-01-20',
  notes: 'Include Q4 metrics',
);
```

### GraphQL - Create Task
```graphql
mutation {
  create_task(input: {
    title: "Review design mockups"
    status: "In Progress"
    priority: "medium"
    assign_to: ["user123"]
    start_date: "2024-01-15"
    end_date: "2024-01-18"
    checklists: [
      { item_title: "Check color scheme" }
      { item_title: "Verify typography" }
    ]
  }) {
    status
    message
    data {
      _id
      task_title
      status
    }
  }
}
```

### React - Filter Tasks
```javascript
const { fetchByFilter } = useTaskContext();

const filters = [
  ['status', 'Not Started'],
  ['assignees', 'user123'],
  ['dateRange', startDate, endDate]
];

fetchByFilter(filters);
```

## Error Handling

### Backend Errors
- **Invalid Input**: Returns 400 with error message
- **Missing Fields**: Returns 422 with field list
- **Database Errors**: Returns 500 with operation details

### Client-Side Errors
- **Network Errors**: Retry with exponential backoff
- **GraphQL Errors**: Display error message to user
- **Validation Errors**: Show field-specific messages

## Best Practices

1. **Always validate input** on both client and server
2. **Use transactions** for multi-document operations
3. **Index frequently queried fields** (status, assign_to, created_by)
4. **Implement pagination** for large datasets
5. **Cache task lists** when possible
6. **Use optimistic updates** for responsive UI
7. **Handle offline scenarios** gracefully

## Testing

### Backend Tests
```bash
cd server_project/graphql_apollo_server
npm test
```

### Flutter Tests
```bash
cd freeli_app
flutter test
```

### React Tests
```bash
cd Client/bun_web
npm test
```

## Monitoring

- **Logging**: All task operations are logged
- **Metrics**: Track create/read/update/delete operations
- **Alerts**: Failed operations trigger alerts
- **Performance**: Monitor query execution times

## Future Enhancements

1. Task dependencies and subtasks
2. Time tracking integration
3. AI-powered task suggestions
4. Advanced reporting and analytics
5. Mobile push notifications
6. Email notifications
7. Calendar integration APIs
8. Task templates