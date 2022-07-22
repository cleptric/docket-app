import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:docket/components/iconsnackbar.dart';
import 'package:docket/components/taskcheckbox.dart';
import 'package:docket/components/dueon.dart';
import 'package:docket/components/projectbadge.dart';
import 'package:docket/models/task.dart';
import 'package:docket/providers/session.dart';
import 'package:docket/providers/tasks.dart';
import 'package:docket/theme.dart';

enum Menu {move, reschedule, delete}

class TaskItem extends StatelessWidget {
  final Task task;

  /// Should the date + evening icon be shown?
  final bool showDate;

  /// Should the project badge be shown?
  final bool showProject;

  const TaskItem({
    required this.task,
    this.showDate = false,
    this.showProject = false,
    super.key
  });

  @override
  Widget build(BuildContext context) {
    List<Widget> attributes = [];
    if (showProject) {
      attributes.add(ProjectBadge(text: task.projectName, color: task.projectColor));
    }
    if (showDate) {
      attributes.add(DueOn(dueOn: task.dueOn, evening: task.evening, showIcon: true));
    }
    // TODO include subtask summary

    return ListTile(
      dense: true,
      leading: TaskCheckbox(task),
      title: Text(
        task.title,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: task.completed ? Colors.grey : Colors.black,
          decoration: task.completed
            ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Wrap(
        runAlignment: WrapAlignment.center,
        spacing: space(0.5),
        children: attributes,
      ),
      trailing: TaskActions(task),
      onTap: () {
        Navigator.pushNamed(context, '/tasks/${task.id}/view');
      }
    );
  }
}

class TaskActions extends StatelessWidget {
  final Task task;

  const TaskActions(this.task, {super.key});

  @override
  Widget build(BuildContext context) {
    var session = Provider.of<SessionProvider>(context);
    var tasksProvider = Provider.of<TasksProvider>(context);

    Future<void> _handleMove() async {
      // Open project picker. Perhaps as a sheet?
    }

    Future<void> _handleDelete() async {
      var messenger = ScaffoldMessenger.of(context);
      try {
        await tasksProvider.deleteTask(session.apiToken, task);
        messenger.showSnackBar(
          successSnackBar(context: context, text: 'Task Deleted')
        );
      } catch (e) {
        messenger.showSnackBar(
          errorSnackBar(context: context, text: 'Could not delete task')
        );
      }
    }

    Future<void> _handleReschedule() async {
      // Show reschedule menu. Perhaps as a sheet?
    }

    var theme = Theme.of(context);
    var customColors = theme.extension<DocketColors>()!;

    return PopupMenuButton<Menu>(
      onSelected: (Menu item) {
        var actions = {
          Menu.move: _handleMove,
          Menu.reschedule: _handleReschedule,
          Menu.delete: _handleDelete,
        };
        actions[item]?.call();
      },
      itemBuilder: (BuildContext context) {
        return <PopupMenuEntry<Menu>>[
          PopupMenuItem<Menu>(
            value: Menu.move,
            child: ListTile(
              leading: Icon(Icons.drive_file_move, color: customColors.actionEdit),
              title: const Text('Move To'),
            ),
          ),
          PopupMenuItem<Menu>(
            value: Menu.reschedule,
            child: ListTile(
              leading: Icon(Icons.calendar_today, color: customColors.dueToday),
              title: const Text('Reschedule'),
            ),
          ),
          PopupMenuItem<Menu>(
            value: Menu.delete,
            child: ListTile(
              leading: Icon(Icons.delete, color: customColors.actionDelete),
              title: const Text('Delete'),
            ),
          ),
        ];
      }
    );
  }
}
