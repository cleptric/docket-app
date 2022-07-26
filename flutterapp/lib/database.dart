import 'dart:developer' as developer;
import 'package:docket/models/calendaritem.dart';
import 'package:json_cache/json_cache.dart';
import 'package:localstorage/localstorage.dart';

import 'package:docket/models/apitoken.dart';
import 'package:docket/models/task.dart';
import 'package:docket/models/project.dart';

class StaleDataError implements Exception {

}

class LocalDatabase {
  // Configuration
  static const String dbName = 'docket-localstorage';

  // Storage keys.
  static const String apiTokenKey = 'v1:apitoken';
  static const String todayTasksKey = 'v1:todaytasks';
  static const String upcomingTasksKey = 'v1:upcomingtasks';
  static const String taskMapKey = 'v1:taskmap';
  static const String projectsKey = 'v1:projects';
  static const String projectTaskMapKey = 'v1:projecttasks';
  static const String calendarItemMapKey = 'v1:calendaritems';
  static const String todayCalendarItemKey = 'v1:todaycalendaritems';
  static const String upcomingCalendarItemKey = 'v1:upcomingcalendaritems';

  /// Key used to lazily expire data.
  /// Contains a structure of `{key: timestamp}`
  /// Where key is one of the keys above, and timestamp
  /// is the expiration time for the key.
  static const String expiredKey = 'v1:expired';

  JsonCache? _database;

  /// Lazily create the database.
  JsonCache database() {
    if (_database != null) {
      return _database!;
    }
    final LocalStorage storage = LocalStorage(dbName);
    _database = JsonCacheMem(JsonCacheLocalStorage(storage));
    return _database!;
  }

  void close() {
    if (_database == null) {
      return;
    }
    _database = null;
  }

  /// See if the storage key is old, or force expired.
  /// We don't want to eagerly refresh data from the server
  /// so we flag data as expired and then refresh next time
  /// data is used.
  Future<bool> _isDataStale(String key, bool useStale) async {
    // TODO implement date checks so that local cache expires automatically
    // every few hours.
    final db = database();
    var staleData = await db.value(expiredKey);
    if (staleData == null || staleData[key] == null || useStale) {
      return false;
    }
    var time = DateTime.now().millisecondsSinceEpoch;
    var isStale = staleData[key] < time;
    staleData.remove(key);
    await db.refresh(expiredKey, staleData);

    return isStale;
  }

  /// Locate which date based views a task would be involved in.
  ///
  /// When tasks are added/removed we need to update or expire
  /// the view entries those tasks will be displayed in.
  ///
  /// In a SQL based storage you'd be able to remove/update the row
  /// individually. Because our local database is view-based. We need
  /// custom logic to locate the views and then update those views.
  Future<List<String>> _taskViews(Task task) async {
    var now = DateTime.now();
    List<String> views = [];

    // If the task has a due date expire upcoming and possibly
    // today views.
    if (task.dueOn != null) {
      var delta = task.dueOn?.difference(now);
      if (delta != null && delta.inDays <= 0) {
        views.add(todayTasksKey);
      }
      views.add(upcomingTasksKey);
    }

    return views;
  }

  /// Expire task views for a task.
  /// When a task is updated or created we need to
  /// clear the local cache so that the new item is visible.
  ///
  /// In a SQL based storage you'd be able to remove/update the row
  /// individually. Because our local database is view-based. We need
  /// custom logic to remove cached data for the impacted views.
  /// This ensures that we don't provide stale state to the Provider
  /// layer and instead Providers fetch fresh data from the Server.
  void _expireTask(Task task) async {
    final db = database();

    // Remove the project key so we read fresh data next time.
    var projectIndex = await db.value(projectTaskMapKey);
    projectIndex ??= {};
    projectIndex.remove(task.projectSlug);
    await db.refresh(projectTaskMapKey, projectIndex);

    var current = await db.value(expiredKey);
    current ??= {};

    var now = DateTime.now();
    var views = await _taskViews(task);
    for (var key in views) {
      current[key] = now.millisecondsSinceEpoch;
    }
    await db.refresh(expiredKey, current);
  }

  /// Directly set a key. Avoid use outside of tests.
  Future<void> set(String key, Map<String, Object?> value) async {
    await database().refresh(key, value);
  }

  // ApiToken methods. {{{
  Future<ApiToken> createApiToken(ApiToken apiToken) async {
    await database().refresh(apiTokenKey, apiToken.toMap());

    return apiToken;
  }

  Future<ApiToken?> fetchApiToken() async {
    final db = database();
    var result = await db.value(apiTokenKey);
    if (result != null) {
      return ApiToken.fromMap(result);
    }
    return null;
  }
  // }}}

  // Task Methods. {{{

  /// Add records to the 'today' view store.
  Future<void> setTodayTasks(List<Task> tasks) async {
    await database().remove(todayTasksKey);
    await addTasks(tasks);
  }

  /// Add records to the 'today' view store.
  Future<void> setUpcomingTasks(List<Task> tasks) async {
    await database().remove(upcomingTasksKey);
    await addTasks(tasks);
  }

  Map<int, List<String>> viewUpdates = {};

  /// Store a list of Tasks.
  /// 
  /// Each task will added to the relevant date/project
  /// views as well as the task lookup map
  Future<void> addTasks(List<Task> tasks) async {
    final db = database();

    Map<String, List<int>> viewUpdates = {};
    Map<String, List<int>> projectUpdates = {};

    var taskMap = await db.value(taskMapKey) ?? {};
    for (var task in tasks) {
      var id = task.id;
      if (id == null) {
        continue;
      }
      taskMap[id.toString()] = task.toMap();

      // Update the pending view updates.
      for (var view in await _taskViews(task)) {
        if (!viewUpdates.containsKey(view)) {
          viewUpdates[view] = [];
        }
        viewUpdates[view]?.add(id);
      }

      // Update pending project tasks
      var projectSlug = task.projectSlug;
      if (!projectUpdates.containsKey(projectSlug)) {
        projectUpdates[projectSlug] = [];
      }
      projectUpdates[projectSlug]?.add(id);
    }

    // Update task mapping.
    await db.refresh(taskMapKey, taskMap);

    // Update date views
    for (var view in viewUpdates.keys) {
      var viewData = await db.value(view) ?? {"tasks": []};
      viewData["tasks"].addAll(viewUpdates[view]);
      await db.refresh(view, viewData);
    }

    // Update Project views.
    var projectTasks = await db.value(projectTaskMapKey) ?? {};
    for (var projectSlug in projectUpdates.keys) {
      if (!projectTasks.containsKey(projectSlug)) {
        projectTasks[projectSlug] = [];
      }
      projectTasks[projectSlug].addAll(projectUpdates[projectSlug]);
    }
    await db.refresh(projectTaskMapKey, projectTasks);
  }

  /// Fetch all tasks for a single project.
  Future<void> addProjectTasks(Project project, List<Task> tasks) async {
    // Add tasks and project to the shared stores.
    await addTasks(tasks);
    await addProjects([project]);

    // Update the project : task mapping.
    final db = database();
    var indexed = await db.value(projectTaskMapKey) ?? {};
    var taskIds = tasks.map((task) => task.id).toList();
    indexed[project.slug] = taskIds;

    await db.refresh(projectTaskMapKey, indexed);
  }

  /// Fetch all records in the 'today' view store.
  Future<List<Task>> fetchTodayTasks({useStale = false}) async {
    final db = database();
    var isStale = await _isDataStale(todayTasksKey, useStale);
    if (isStale) {
      throw StaleDataError();
    }
    var results = await db.value(todayTasksKey);
    if (results == null || results['tasks'] == null) {
      throw StaleDataError();
    }
    List<int> taskIds = results['tasks'].cast<int>();

    return getTasksById(taskIds);
  }

  /// Fetch all records in the 'upcoming' view store.
  Future<List<Task>> fetchUpcomingTasks({useStale = false}) async {
    var isStale = await _isDataStale(upcomingTasksKey, useStale);
    if (isStale) {
      throw StaleDataError();
    }
    var results = await database().value(upcomingTasksKey);
    if (results == null || results['tasks'] == null) {
      throw StaleDataError();
    }
    List<int> taskIds = results['tasks'].cast<int>();

    return getTasksById(taskIds);
  }

  /// Fetch all tasks for a single project.
  Future<List<Task>> fetchProjectTasks(String slug, {useStale = false}) async {
    // Update the project : task mapping.
    var isStale = await _isDataStale(projectTaskMapKey, useStale);
    if (isStale) {
      return [];
    }
    var results = await database().value(projectTaskMapKey);
    if (results == null || results[slug] == null) {
      return [];
    }
    List<int> taskIds = results[slug].cast<int>();

    return getTasksById(taskIds);
  }

  /// Fetch a list of tasks by id.
  ///
  /// This method will make a best effort to find as manyj
  /// tasks as requested. There are scenarios where tasks could be
  /// missing.
  Future<List<Task>> getTasksById(List<int> taskIds) async {
    var indexed = await database().value(taskMapKey) ?? {};
    List<Task> tasks = [];
    for (var id in taskIds) {
      var record = indexed[id.toString()];
      if (record == null) {
        developer.log('Skipping task with id=$id as it could not be found.');
        continue;
      }
      tasks.add(Task.fromMap(record));
    }
    return tasks;
  }

  /// Fetch a single task by id.
  Future<Task?> fetchTaskById(int id) async {
    var tasks = await getTasksById([id]);
    if (tasks.isNotEmpty) {
      return tasks[0];
    }
    throw Exception('Could not load task');
  }

  /// Replace a task in the local database.
  /// This will update all task views with the new data.
  Future<void> updateTask(Task task) async {
    await addTasks([task]);

    _expireTask(task);
  }

  Future<void> deleteTask(Task task) async {
    if (task.id == null) {
      return;
    }
    final db = database();

    // Remove the task from the task mapping.
    var indexed = await db.value(taskMapKey) ?? {};
    indexed.remove(task.id.toString());
    await db.refresh(taskMapKey, indexed);

    _expireTask(task);
  }
  // }}}

  // Project methods {{{

  Future<void> addProjects(List<Project> projects) async {
    final db = database();
    var projectMap = await db.value(projectsKey) ?? {};
    for (var project in projects) {
      projectMap[project.slug] = project.toMap();
    }
    await db.refresh(projectsKey, projectMap);
  }

  /// Get an individual project by slug.
  Future<Project> fetchProjectBySlug(String slug) async {
    final db = database();
    var projectMap = await db.value(projectsKey);
    if (projectMap == null || projectMap[slug] == null) {
      throw StaleDataError();
    }
    return Project.fromMap(projectMap[slug]);
  }

  /// Get a list of projects sorted by the `ranking` field.
  Future<List<Project>> fetchProjects() async {
    final db = database();
    var projectMap = await db.value(projectsKey);
    if (projectMap == null) {
      throw StaleDataError();
    }
    List<Project> projects = [];
    for (var item in projectMap.values) {
      projects.add(Project.fromMap(item));
    }
    projects.sort((a, b) => a.ranking.compareTo(b.ranking));

    return projects;
  }
  // }}}

  // Calendar Item Methods {{{

  /// Add a list of calendar items to the canonical lookup.
  Future<void> addCalendarItems(List<CalendarItem> calendarItems) async {
    final db = database();
    var indexed = await db.value(calendarItemMapKey) ?? {};
    for (var calendarItem in calendarItems) {
      indexed[calendarItem.id] = calendarItem.toMap();
    }
    await db.refresh(calendarItemMapKey, indexed);
  }

  /// Get a list of calendar items for the today view
  Future<List<CalendarItem>> fetchTodayCalendarItems({useStale = false}) async {
    final db = database();
    var isStale = await _isDataStale(todayCalendarItemKey, useStale);
    if (isStale) {
      throw StaleDataError();
    }
    var results = await db.value(todayCalendarItemKey);
    if (results == null || results['items'] == null) {
      throw StaleDataError();
    }
    List<String> ids = results['items'];

    return _getCalendarItemsById(ids);
  }

  /// Get a list of calendar items for the upcoming view
  Future<List<CalendarItem>> fetchUpcomingCalendarItems({useStale = false}) async {
    final db = database();
    var isStale = await _isDataStale(upcomingCalendarItemKey, useStale);
    if (isStale) {
      throw StaleDataError();
    }
    var results = await db.value(upcomingCalendarItemKey);
    if (results == null || results['items'] == null) {
      throw StaleDataError();
    }
    List<String> ids = results['items'];

    return _getCalendarItemsById(ids);
  }

  /// Add records to the 'today' view store.
  Future<void> setTodayCalendarItems(List<CalendarItem> items) async {
    await addCalendarItems(items);

    final db = database();
    await db.refresh(todayCalendarItemKey, {
      'items': items.map((item) => item.id).toList(),
    });
  }

  /// Add records to the 'today' view store.
  Future<void> setUpcomingCalendarItems(List<CalendarItem> items) async {
    await addCalendarItems(items);

    final db = database();
    await db.refresh(upcomingCalendarItemKey, {
      'items': items.map((item) => item.id).toList(),
    });
  }

  /// Get a list of calendar items by id.
  ///
  /// Used by fetch methods to read results from the local mapping
  /// of items.
  Future<List<CalendarItem>> _getCalendarItemsById(List<String> ids) async {
    final db = database();
    var indexed = await db.value(calendarItemMapKey);
    indexed ??= {};
    List<CalendarItem> items = [];
    for (var id in ids) {
      var record = indexed[id];
      if (record == null) {
        developer.log('Skipping item with id=$id as it could not be found.');
        continue;
      }
      items.add(CalendarItem.fromMap(record));
    }
    return items;
  }
  // }}}

  // Data Erasing Methods {{{
  Future<void> clearExpired() async {
    final db = database();
    return db.remove(expiredKey);
  }

  Future<List<void>> clearTasks() async {
    final db = database();
    return Future.wait([
      db.remove(taskMapKey),
      db.remove(todayTasksKey),
      db.remove(upcomingTasksKey),
      db.remove(projectTaskMapKey),
    ]);
  }

  Future<List<void>> clearProjects() async {
    final db = database();
    return Future.wait([
      db.remove(projectsKey),
      db.remove(projectTaskMapKey),
    ]);
  }
  // }}}
}
