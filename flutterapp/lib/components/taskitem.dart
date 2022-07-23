import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:docket/components/iconsnackbar.dart';
import 'package:docket/components/taskcheckbox.dart';
import 'package:docket/components/dueon.dart';
import 'package:docket/components/projectbadge.dart';
import 'package:docket/dialogs/changedueon.dart';
import 'package:docket/dialogs/changeproject.dart';
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
    var navigator = Navigator.of(context);
    var messenger = ScaffoldMessenger.of(context);

    Future<void> _handleChangeProject() async {
      void changeComplete(projectId) {
        task.projectId = projectId;
        tasksProvider.updateTask(session.apiToken, task);
        messenger.showSnackBar(
          successSnackBar(context: context, text: 'Task Updated')
        );
        navigator.pop();
      }
      showChangeProjectDialog(context, task.projectId, changeComplete);
    }

    Future<void> _handleDelete() async {
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
      void changeComplete(dueOn, evening) {
        task.dueOn = dueOn;
        task.evening = evening;
        tasksProvider.updateTask(session.apiToken, task);
        messenger.showSnackBar(
          successSnackBar(context: context, text: 'Task Updated')
        );
        navigator.pop();
      }
      showChangeDueOnDialog(context, task.dueOn, task.evening, changeComplete);
    }

    var theme = Theme.of(context);
    var customColors = theme.extension<DocketColors>()!;

    return PopupMenuButton<Menu>(
      onSelected: (Menu item) {
        var actions = {
          Menu.move: _handleChangeProject,
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
              title: const Text('Change Project'),
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
