import 'package:flutter/material.dart';

import 'package:docket/actions.dart' as actions;
import 'package:docket/database.dart';
import 'package:docket/models/task.dart';
import 'package:docket/components/tasksorter.dart';
import 'package:docket/formatters.dart' as formatters;
import 'package:docket/grouping.dart' as grouping;


class UpcomingViewModel extends ChangeNotifier {
  late LocalDatabase _database;

  /// Whether data is being refreshed from the server or local cache.
  bool _loading = false;
  bool _silentLoading = false;

  /// Task list for the day/evening
  List<TaskSortMetadata> _taskLists = [];

  /// Any overdue tasks
  TaskSortMetadata? _overdue;

  UpcomingViewModel(LocalDatabase database) {
    _database = database;
    _database.upcoming.addListener(listener);
  }

  @override
  void dispose() {
    _database.upcoming.removeListener(listener);
    super.dispose();
  }

  void listener() {
    loadData();
  }

  bool get loading => (_loading && !_silentLoading);
  TaskSortMetadata? get overdue => _overdue;
  List<TaskSortMetadata> get taskLists => _taskLists;

  /// Load data. Should be called during initState()
  Future<void> loadData() async {
    var taskView = await _database.upcoming.get();
    if (taskView.isEmpty == false) {
      _buildTaskLists(taskView);
    }
    if (!_loading && taskView.isEmpty) {
      return refresh();
    }
    if (!_loading && !_database.upcoming.isFresh()) {
      return refreshTasks();
    }
  }

  /// Refresh from the server.
  Future<void> refresh() async {
    _loading = true;

    var tasksView = await actions.fetchUpcomingTasks(_database.apiToken.token);
    await _database.upcoming.set(tasksView);
    _buildTaskLists(tasksView);
  }

  /// Refresh tasks from server state. Does not use loading
  /// state.
  Future<void> refreshTasks() async {
    _loading = _silentLoading = true;

    var taskView = await actions.fetchUpcomingTasks(_database.apiToken.token);
    _database.upcoming.set(taskView);

    _loading = _silentLoading = false;
    _buildTaskLists(taskView);
  }

  void _buildTaskLists(TaskViewData data) {
    var grouperFunc = grouping.createGrouper(DateTime.now(), 28);
    var grouped = grouperFunc(data.tasks);
    var groupedCalendarItems = grouping.groupCalendarItems(data.calendarItems);

    _taskLists = [];
    for (var group in grouped) {
      var groupDate = group.key;
      var isEvening = groupDate.contains('evening:');
      if (isEvening) {
        groupDate = groupDate.replaceFirst('evening:', '');
      }
      var dateVal = DateTime.parse('$groupDate 00:00:00');

      late TaskSortMetadata metadata;
      if (isEvening) {
        // Evening sections only have a subtitle and no calendar items.
        metadata = TaskSortMetadata(
            subtitle: 'Evening',
            tasks: group.items,
            onReceive: (Task task, int newIndex) {
              Map<String, dynamic> updates = {
                'day_order': newIndex,
                'evening': true,
              };
              task.dayOrder = newIndex;
              task.evening = true;

              if (task.dueOn != dateVal) {
                task.previousDueOn = task.dueOn;
                task.dueOn = dateVal;
                updates['due_on'] = formatters.dateString(dateVal);
              }

              return updates;
            });
      } else {
        var title = formatters.compactDate(dateVal);
        var subtitle = formatters.monthDay(dateVal);
        if (title == subtitle) {
          subtitle = '';
        }

        metadata = TaskSortMetadata(
            title: title,
            subtitle: subtitle,
            showButton: true,
            buttonArgs: TaskSortButtonArgs(dueOn: dateVal),
            tasks: group.items,
            calendarItems: groupedCalendarItems.get(groupDate),
            onReceive: (Task task, int newIndex) {
              Map<String, dynamic> updates = {
                'day_order': newIndex,
                'evening': false,
              };
              task.dayOrder = newIndex;
              task.evening = false;

              if (task.dueOn != dateVal) {
                task.previousDueOn = task.dueOn;
                task.dueOn = dateVal;
              }

              return updates;
            });
      }
      _taskLists.add(metadata);
    }

    _loading = false;

    notifyListeners();
  }

  /// Re-order a task
  Future<void> reorderTask(int oldItemIndex, int oldListIndex, int newItemIndex, int newListIndex) async {
    var task = _taskLists[oldListIndex].tasks[oldItemIndex];

    // Get the changes that need to be made on the server.
    var updates = _taskLists[newListIndex].onReceive(task, newItemIndex);

    // Update local state assuming server will be ok.
    _taskLists[oldListIndex].tasks.removeAt(oldItemIndex);
    _taskLists[newListIndex].tasks.insert(newItemIndex, task);

    // Update the moved task and reload from server async
    await actions.moveTask(_database.apiToken.token, task, updates);
    await _database.upcoming.updateTask(task);
    _database.expireTask(task);
  }

  Future<void> insertAt(Task task, int listIndex, int itemIndex) async {
    // Calculate position of adding to a end.
    // Generally this will be zero but it is possible to add to the
    // bottom of a populated list too.
    var targetList = _taskLists[listIndex];
    if (itemIndex == -1) {
      itemIndex = targetList.tasks.length;
    }
    // Get the changes that need to be made on the server.
    var updates = _taskLists[listIndex].onReceive(task, itemIndex);
    _taskLists[listIndex].tasks.insert(itemIndex, task);

    // Update the moved task and reload from server async
    await actions.moveTask(_database.apiToken.token, task, updates);
    _database.expireTask(task);
  }
}
