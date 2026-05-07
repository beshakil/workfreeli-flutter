import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ChannelModel {
  final String name;
  final String subtitle;
  final String icon;
  final Color iconBgColor;
  final Color iconColor;
  final LinearGradient? iconGradient;
  final String lastMessage;
  final String time;
  final int unread;
  final bool isDM;

  ChannelModel({
    required this.name,
    required this.subtitle,
    required this.icon,
    this.iconBgColor = Colors.transparent,
    this.iconColor = Colors.white,
    this.iconGradient,
    required this.lastMessage,
    required this.time,
    this.unread = 0,
    this.isDM = false,
  });
}

class MessageModel {
  final String sender;
  final String text;
  final String time;
  final LinearGradient avatarGradient;
  final String avatarText;
  final bool isSelf;
  final String? fileName;
  final String? fileSize;
  final String? fileType;

  MessageModel({
    required this.sender,
    required this.text,
    required this.time,
    this.avatarGradient = const LinearGradient(colors: [Color(0xFF667EEA), Color(0xFF764BA2)]),
    required this.avatarText,
    this.isSelf = false,
    this.fileName,
    this.fileSize,
    this.fileType,
  });
}

class TaskModel {
  final String title;
  final List<TaskTag> tags;
  final List<TaskAssignee> assignees;
  final String dueDate;
  final bool isDone;

  TaskModel({
    required this.title,
    required this.tags,
    required this.assignees,
    required this.dueDate,
    this.isDone = false,
  });
}

class TaskTag {
  final String label;
  final Color bgColor;
  final Color textColor;

  TaskTag({required this.label, required this.bgColor, required this.textColor});
}

class TaskAssignee {
  final String initials;
  final LinearGradient gradient;

  TaskAssignee({required this.initials, required this.gradient});
}

class FileModel {
  final String name;
  final String type;
  final String size;
  final String author;
  final String time;
  final Color iconBg;
  final Color iconColor;

  FileModel({
    required this.name,
    required this.type,
    required this.size,
    required this.author,
    required this.time,
    required this.iconBg,
    required this.iconColor,
  });
}

// ===== Sample Data =====

List<ChannelModel> sampleChannels = [
  ChannelModel(
    name: '# general',
    subtitle: '12 members · 4 online',
    icon: '#',
    iconBgColor: AppTheme.primaryLight.withValues(alpha: 0.15),
    iconColor: AppTheme.primaryLight,
    lastMessage: 'Sarah: Updated the roadmap',
    time: '2m',
    unread: 3,
  ),
  ChannelModel(
    name: '# design-team',
    subtitle: '6 members · 2 online',
    icon: '#',
    iconBgColor: AppTheme.accent.withValues(alpha: 0.15),
    iconColor: AppTheme.accent,
    lastMessage: 'Mike: New mockups ready',
    time: '18m',
  ),
  ChannelModel(
    name: '# dev-ops',
    subtitle: '8 members · 3 online',
    icon: '#',
    iconBgColor: AppTheme.warning.withValues(alpha: 0.15),
    iconColor: AppTheme.warning,
    lastMessage: 'CI/CD pipeline fixed',
    time: '1h',
  ),
  ChannelModel(
    name: 'Sarah Lee',
    subtitle: 'Online',
    icon: 'SL',
    iconGradient: AppTheme.avatarPink,
    lastMessage: 'Can you review the PR?',
    time: '32m',
    unread: 1,
    isDM: true,
  ),
  ChannelModel(
    name: 'Mike Johnson',
    subtitle: 'Last seen 30m ago',
    icon: 'MJ',
    iconGradient: AppTheme.avatarBlue,
    lastMessage: "Sounds good, let's sync",
    time: '2h',
    isDM: true,
  ),
  ChannelModel(
    name: 'Alex Chen',
    subtitle: 'Online',
    icon: 'AC',
    iconGradient: AppTheme.avatarPurple,
    lastMessage: 'The API docs are updated',
    time: '5h',
    isDM: true,
  ),
];

List<MessageModel> sampleMessages = [
  MessageModel(
    sender: 'Sarah Lee',
    text: "Hey team! I've just pushed the updated roadmap for Q2. Please take a look when you get a chance.",
    time: '9:42 AM',
    avatarGradient: AppTheme.avatarPink,
    avatarText: 'SL',
    fileName: 'Q2_Roadmap_v3.pdf',
    fileSize: '2.4 MB',
    fileType: 'PDF',
  ),
  MessageModel(
    sender: 'Mike Johnson',
    text: 'Looks great, Sarah! I especially like the new timeline view. One suggestion — maybe we should add milestones for the design reviews?',
    time: '9:58 AM',
    avatarGradient: AppTheme.avatarBlue,
    avatarText: 'MJ',
  ),
  MessageModel(
    sender: 'Alex Chen',
    text: "Agreed with Mike. Also, the API documentation has been updated — all v2 endpoints are now live. Let me know if anything breaks.",
    time: '10:15 AM',
    avatarGradient: AppTheme.avatarPurple,
    avatarText: 'AC',
  ),
  MessageModel(
    sender: 'You',
    text: "I'll review the roadmap this afternoon. Thanks for putting this together, Sarah! 🙌",
    time: '10:22 AM',
    avatarGradient: AppTheme.avatarIndigo,
    avatarText: 'FR',
    isSelf: true,
  ),
  MessageModel(
    sender: 'Sarah Lee',
    text: "Thanks everyone! @Mike good call on the milestones — I'll add those now. Also, the sprint retro is at 3 PM today, don't forget!",
    time: '10:32 AM',
    avatarGradient: AppTheme.avatarPink,
    avatarText: 'SL',
  ),
];

final List<String> botReplies = [
  "That's a great point! Let me look into it.",
  "Thanks for sharing! I'll follow up on this.",
  "Noted! We can discuss this more in the standup.",
  "Sounds good, I'll update the task board.",
  "On it! Give me a few minutes to check.",
];

List<List<TaskModel>> sampleTasks = [
  // To Do
  [
    TaskModel(
      title: 'Implement dark mode toggle for mobile app',
      tags: [TaskTag(label: 'Feature', bgColor: AppTheme.primaryLight.withValues(alpha: 0.15), textColor: AppTheme.primaryLight)],
      assignees: [TaskAssignee(initials: 'MJ', gradient: AppTheme.avatarBlue)],
      dueDate: 'Apr 25',
    ),
    TaskModel(
      title: 'Fix notification badge not clearing on iOS',
      tags: [
        TaskTag(label: 'Bug', bgColor: AppTheme.danger.withValues(alpha: 0.15), textColor: AppTheme.danger),
        TaskTag(label: 'Urgent', bgColor: AppTheme.warning.withValues(alpha: 0.15), textColor: AppTheme.warning),
      ],
      assignees: [TaskAssignee(initials: 'AC', gradient: AppTheme.avatarPurple)],
      dueDate: 'Apr 22',
    ),
    TaskModel(
      title: 'Update onboarding flow illustrations',
      tags: [TaskTag(label: 'Design', bgColor: AppTheme.accent.withValues(alpha: 0.15), textColor: AppTheme.accent)],
      assignees: [TaskAssignee(initials: 'SL', gradient: AppTheme.avatarPink)],
      dueDate: 'Apr 28',
    ),
  ],
  // In Progress
  [
    TaskModel(
      title: 'Real-time collaborative editing for shared notes',
      tags: [TaskTag(label: 'Feature', bgColor: AppTheme.primaryLight.withValues(alpha: 0.15), textColor: AppTheme.primaryLight)],
      assignees: [
        TaskAssignee(initials: 'FR', gradient: AppTheme.avatarIndigo),
        TaskAssignee(initials: 'AC', gradient: AppTheme.avatarPurple),
      ],
      dueDate: 'Apr 24',
    ),
    TaskModel(
      title: 'Redesign channel settings modal',
      tags: [TaskTag(label: 'Design', bgColor: AppTheme.accent.withValues(alpha: 0.15), textColor: AppTheme.accent)],
      assignees: [TaskAssignee(initials: 'SL', gradient: AppTheme.avatarPink)],
      dueDate: 'Apr 23',
    ),
  ],
  // Review
  [
    TaskModel(
      title: 'Push notification scheduling system',
      tags: [TaskTag(label: 'Feature', bgColor: AppTheme.primaryLight.withValues(alpha: 0.15), textColor: AppTheme.primaryLight)],
      assignees: [
        TaskAssignee(initials: 'AC', gradient: AppTheme.avatarPurple),
        TaskAssignee(initials: 'FR', gradient: AppTheme.avatarIndigo),
      ],
      dueDate: 'Apr 21',
    ),
  ],
  // Done
  [
    TaskModel(
      title: 'New emoji reaction picker UI',
      tags: [TaskTag(label: 'Design', bgColor: AppTheme.accent.withValues(alpha: 0.15), textColor: AppTheme.accent)],
      assignees: [TaskAssignee(initials: 'SL', gradient: AppTheme.avatarPink)],
      dueDate: 'Done',
      isDone: true,
    ),
    TaskModel(
      title: 'OAuth2 integration for SSO login',
      tags: [TaskTag(label: 'Feature', bgColor: AppTheme.primaryLight.withValues(alpha: 0.15), textColor: AppTheme.primaryLight)],
      assignees: [TaskAssignee(initials: 'AC', gradient: AppTheme.avatarPurple)],
      dueDate: 'Done',
      isDone: true,
    ),
  ],
];

List<FileModel> sampleFiles = [
  FileModel(name: 'Q2_Roadmap_v3.pdf', type: 'PDF', size: '2.4 MB', author: 'Sarah Lee', time: '2h ago', iconBg: AppTheme.danger.withValues(alpha: 0.12), iconColor: AppTheme.danger),
  FileModel(name: 'Mobile_Redesign.fig', type: 'FIG', size: '18.2 MB', author: 'Mike Johnson', time: '1d ago', iconBg: AppTheme.primaryLight.withValues(alpha: 0.12), iconColor: AppTheme.primaryLight),
  FileModel(name: 'Sprint_Metrics.xlsx', type: 'XLS', size: '340 KB', author: 'Alex Chen', time: '2d ago', iconBg: AppTheme.accent.withValues(alpha: 0.12), iconColor: AppTheme.accent),
  FileModel(name: 'API_Docs_v2.docx', type: 'DOC', size: '1.1 MB', author: 'Alex Chen', time: '3d ago', iconBg: AppTheme.warning.withValues(alpha: 0.12), iconColor: AppTheme.warning),
  FileModel(name: 'Brand_Guidelines.png', type: 'PNG', size: '4.8 MB', author: 'Sarah Lee', time: '5d ago', iconBg: const Color(0xFFA78BFA).withValues(alpha: 0.12), iconColor: const Color(0xFFA78BFA)),
  FileModel(name: 'Frontend_Assets.zip', type: 'ZIP', size: '22 MB', author: 'Mike Johnson', time: '1w ago', iconBg: const Color(0xFF60A5FA).withValues(alpha: 0.12), iconColor: const Color(0xFF60A5FA)),
];
