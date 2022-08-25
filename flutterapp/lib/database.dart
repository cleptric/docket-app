import 'dart:developer' as developer;
import 'package:json_cache/json_cache.dart';
import 'package:localstorage/localstorage.dart';

import 'package:docket/formatters.dart' as formatters;
import 'package:docket/models/apitoken.dart';
import 'package:docket/models/task.dart';
import 'package:docket/models/project.dart';

class StaleDataError implements Exception {}

const isStale = '__is_stale__';

class LocalDatabase {
  // Configuration
  static const String dbName = 'docket-localstorage';

  // Storage keys.
  static const String apiTokenKey = 'v1:apitoken';
  static const String taskMapKey = 'v1:taskmap';

  /// Key used to lazily expire data.
  /// Contains a structure of `{key: timestamp}`
  /// Where key is one of the keys above, and timestamp
  /// is the expiration time for the key.
  static const String expiredKey = 'v1:expired';

  JsonCache? _database;

  late TodayView today;
  late UpcomingView upcoming;
  late TaskDetailsView taskDetails;
  late ProjectMapView projectMap;
  late ProjectDetailsView projectDetails;
  late ProjectArchiveView projectArchive;

  LocalDatabase() {
    var db = database();
    today = TodayView(db, const Duration(hours: 1));
    upcoming = UpcomingView(db, const Duration(hours: 1));
    taskDetails = TaskDetailsView(db, const Duration(hours: 1));
    projectMap = ProjectMapView(db, const Duration(hours: 1));
    projectDetails = ProjectDetailsView(db, const Duration(hours: 1));
    projectArchive = ProjectArchiveView(db, const Duration(hours: 1));
  }

  /// Lazily create the database.
  JsonCache database() {
    if (_database != null) {
      return _database!;
    }
    final LocalStorage storage = LocalStorage(dbName);
    _database = JsonCacheMem(JsonCacheLocalStorage(storage));
    return _database!;
  }

  /// Locate which date based views a task would be involved in.
  ///
  /// When tasks are added/removed we need to update or expire
  /// the view entries those tasks will be displayed in.
  ///
  /// In a SQL based storage you'd be able to remove/update the row
  /// individually. Because our local database is view-based. We need
  /// custom logic to locate the views and then update those views.
  List<String> _taskViews(Task task) {
    var now = DateTime.now();
    List<String> views = [];

    // If the task has a due date expire upcoming and possibly
    // today views.
    if (task.dueOn != null) {
      var delta = task.dueOn?.difference(now);
      if (delta != null && delta.inDays <= 0) {
        views.add(TodayView.name);
      }
      views.add(UpcomingView.name);
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
  Future<void> _expireTaskViews(Task task) async {
    List<Future> futures = [];

    // Remove the project key so we read fresh data next time.
    futures.add(projectDetails.remove(task.projectSlug));

    for (var key in _taskViews(task)) {
      switch (key) {
        case TodayView.name:
          futures.add(today.clear());
          break;
        case UpcomingView.name:
          futures.add(upcoming.clear());
          break;
        default:
          throw 'Unknown view key of $key';
      }
    }
    await Future.wait(futures);
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

  /// Store a list of Tasks.
  ///
  /// Each task will added to the relevant date/project
  /// views as well as the task lookup map
  Future<void> addTasks(List<Task> tasks, {bool expire = false}) async {
    List<Future> futures = [];
    for (var task in tasks) {
      // Refresh task in taskDetails lookup.
      futures.add(taskDetails.set(task));

      if (expire) {
        // Update the pending view updates.
        for (var view in _taskViews(task)) {
          switch (view) {
            case TodayView.name:
              futures.add(today.clear());
              break;
            case UpcomingView.name:
              futures.add(upcoming.clear());
              break;
            default:
              throw 'Unknown view to clear "$view"';
          }
        }
        futures.add(projectDetails.remove(task.projectSlug));
      }
    }

    await Future.wait(futures);
  }

  /// Replace a task in the local database.
  /// This will update all task views with the new data.
  Future<void> updateTask(Task task) async {
    await addTasks([task]);
    return _expireTaskViews(task);
  }

  Future<void> deleteTask(Task task) async {
    var id = task.id;
    if (id == null) {
      return;
    }
    await taskDetails.remove(id);

    return _expireTaskViews(task);
  }
  // }}}

  // Project methods {{{

  /// Add a list of projects to the local database.
  Future<void> addProjects(List<Project> projects) async {
    await Future.wait(projects.map((item) => projectMap.set(item)).toList());
  }

  /// Update a project in the project list state.
  Future<void> updateProject(Project project) async {
    await Future.wait([
      projectMap.set(project),
      projectDetails.remove(project.slug),
    ]);
  }
  // }}}

  // Clearing methods {{{
  Future<List<void>> clearTasks() async {
    return Future.wait([
      taskDetails.clear(),
      today.clear(),
      upcoming.clear(),
      projectDetails.clear(),
    ]);
  }

  Future<List<void>> clearProjects() async {
    return Future.wait([
      projectMap.clear(),
      projectDetails.clear(),
      projectArchive.clear(),
    ]);
  }
  // }}}
}

/// Abstract class that will act as the base of the ViewCache based database implementation.
abstract class ViewCache<T> {
  late JsonCache _database;
  Duration duration;

  Map<String, dynamic>? _state;

  ViewCache(JsonCache database, this.duration) {
    _database = database;
  }

  Future<bool> isFresh() async {
    var data = await _database.value(keyName()) ?? {};
    var updated = data['updatedAt'];
    if (updated == null) {
      return false;
    }
    var timestamp = DateTime.parse(updated);
    var expires = DateTime.now()..subtract(duration);
    if (timestamp.isBefore(expires)) {
      return false;
    }
    return true;
  }

  /// Refresh the data stored for the 'today' view.
  Future<void> _set(Map<String, dynamic> data) async {
    var payload = {'updatedAt': formatters.dateString(DateTime.now()), 'data': data};
    _state = data;
    await _database.refresh(keyName(), payload);
  }

  /// Refresh the data stored for the 'today' view.
  Future<Map<String, dynamic>?> _get() async {
    if (_state != null) {
      return _state;
    }
    var payload = await _database.value(keyName());
    if (payload == null) {
      return null;
    }
    _state = payload['data'];

    return payload['data'];
  }

  Future<void> clear() async {
    _state = null;
    return _database.remove(keyName());
  }

  /// Get the keyname for this viewcache,
  String keyName();

  /// Set data into the view cache.
  Future<void> set(T data);
}

class TodayView extends ViewCache<TaskViewData> {
  static const String name = 'today';

  TodayView(JsonCache database, Duration duration) : super(database, duration);

  @override
  String keyName() {
    return 'v1:$name';
  }

  /// Refresh the data stored for the 'today' view.
  @override
  Future<void> set(TaskViewData todayData) async {
    return _set(todayData.toMap());
  }

  Future<TaskViewData> get() async {
    var data = await _get();
    // Likely loading.
    if (data == null || data['tasks'] == null) {
      return TaskViewData(missingData: true, tasks: [], calendarItems: []);
    }
    return TaskViewData.fromMap(data);
  }
}

class UpcomingView extends ViewCache<TaskViewData> {
  static const String name = 'upcoming';

  UpcomingView(JsonCache database, Duration duration) : super(database, duration);

  @override
  String keyName() {
    return 'v1:$name';
  }

  /// Refresh the data stored for the 'upcoming' view.
  @override
  Future<void> set(TaskViewData data) async {
    return _set(data.toMap());
  }

  Future<TaskViewData> get() async {
    var data = await _get();
    // Likely loading.
    if (data == null || data['tasks'] == null) {
      return TaskViewData(missingData: true, tasks: [], calendarItems: []);
    }
    return TaskViewData.fromMap(data);
  }
}

// A map based view data provider
class TaskDetailsView extends ViewCache<Task> {
  static const String name = 'taskdetails';

  TaskDetailsView(JsonCache database, Duration duration) : super(database, duration);

  @override
  String keyName() {
    return 'v1:$name';
  }

  /// Set a task into the details view.
  @override
  Future<void> set(Task task) async {
    var current = await _get() ?? {};
    current[task.id.toString()] = task.toMap();

    return _set(current);
  }

  Future<Task?> get(int id) async {
    var taskId = id.toString();
    var data = await _get();
    // Likely loading.
    if (data == null || data[taskId] == null) {
      return null;
    }
    return Task.fromMap(data[taskId]);
  }

  Future<void> remove(int id) async {
    var data = await _get() ?? {};
    var taskId = id.toString();

    data.remove(taskId);
    return _set(data);
  }
}

// A map based view data provider
class ProjectMapView extends ViewCache<Project> {
  static const String name = 'projectmap';

  ProjectMapView(JsonCache database, Duration duration) : super(database, duration);

  @override
  String keyName() {
    return 'v1:$name';
  }

  /// Set a project into the lookup
  @override
  Future<void> set(Project project) async {
    var current = await _get() ?? {};
    current[project.slug] = project.toMap();

    return _set(current);
  }

  Future<void> addMany(List<Project> projects) async {
    var current = await _get() ?? {};
    for (var project in projects) {
      current[project.slug] = project.toMap();
    }
    return _set(current);
  }

  Future<Project?> get(String slug) async {
    var data = await _get();
    // Likely loading.
    if (data == null || data[slug] == null) {
      return null;
    }
    return Project.fromMap(data[slug]);
  }

  Future<List<Project>> all() async {
    var data = await _get();
    if (data == null) {
      return [];
    }
    var projects = data.values.map((item) => Project.fromMap(item)).toList();
    projects.sort((a, b) => a.ranking.compareTo(b.ranking));
    return projects;
  }

  Future<void> remove(String slug) async {
    var data = await _get() ?? {};
    data.remove(slug);
    return _set(data);
  }

  Future<void> removeById(int id) async {
    var data = await _get() ?? {};
    data.removeWhere((key, value) => value['id'] == id);
    return _set(data);
  }
}

// A map based view data provider
class ProjectDetailsView extends ViewCache<ProjectWithTasks> {
  static const String name = 'projectdetails';

  ProjectDetailsView(JsonCache database, Duration duration) : super(database, duration);

  @override
  String keyName() {
    return 'v1:$name';
  }

  /// Set a project into the lookup
  @override
  Future<void> set(ProjectWithTasks view) async {
    var current = await _get() ?? {};
    current[view.project.slug] = view.toMap();

    return _set(current);
  }

  Future<ProjectWithTasks> get(String slug) async {
    var data = await _get();
    // Likely loading.
    if (data == null || data[slug] == null) {
      return ProjectWithTasks(
        project: Project.blank(),
        tasks: [],
        missingData: true,
      );
    }
    var projectTasks = ProjectWithTasks.fromMap(data[slug]);
    return projectTasks;
  }

  Future<void> remove(String slug) async {
    var data = await _get() ?? {};
    data.remove(slug);
    return _set(data);
  }
}

class ProjectArchiveView extends ViewCache<List<Project>> {
  static const String name = 'projectarchive';

  ProjectArchiveView(JsonCache database, Duration duration) : super(database, duration);

  @override
  String keyName() {
    return 'v1:$name';
  }

  /// Refresh the data stored for the 'upcoming' view.
  @override
  Future<void> set(List<Project> data) async {
    return _set({'projects': data.map((project) => project.toMap()).toList()});
  }

  Future<List<Project>?> get() async {
    var data = await _get();
    // Likely loading.
    if (data == null || data['projects'] == null) {
      return null;
    }

    return (data['projects'] as List).map<Project>((item) => Project.fromMap(item)).toList();
  }
}
