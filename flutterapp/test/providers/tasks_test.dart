import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';

import 'package:docket/actions.dart' as actions;
import 'package:docket/formatters.dart' as formatters;
import 'package:docket/database.dart';
import 'package:docket/models/task.dart';
import 'package:docket/providers/session.dart';
import 'package:docket/providers/tasks.dart';

// Parse a list response into a list of tasks.
List<Task> parseTaskList(String data) {
  var decoded = jsonDecode(data);
  if (!decoded.containsKey('tasks')) {
    throw 'Cannot parse tasks without tasks key';
  }
  List<Task> tasks = [];
  for (var item in decoded['tasks']) {
    tasks.add(Task.fromMap(item));
  }
  return tasks;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TasksProvider provider;

  int listenerCallCount = 0;
  var today = DateUtils.dateOnly(DateTime.now());

  var file = File('test_resources/tasks_today.json');
  final tasksTodayResponseFixture = file.readAsStringSync().replaceAll('__TODAY__', formatters.dateString(today));

  file = File('test_resources/project_details.json');
  final projectDetailsResponseFixture = file.readAsStringSync();

  file = File('test_resources/task_create_today.json');
  final taskCreateTodayResponseFixture = file.readAsStringSync().replaceAll('__TODAY__', formatters.dateString(today));

  Future<void> setTodayView(List<Task> tasks) async {
    var db = LocalDatabase();
    var taskView = TaskViewData(tasks: tasks, calendarItems: []);
    await db.today.set(taskView);
  }

  group('$TasksProvider', () {
    var db = LocalDatabase();
    var session = SessionProvider(db)..set('api-token');

    setUp(() async {
      listenerCallCount = 0;
      provider = TasksProvider(db, session)
        ..addListener(() {
          listenerCallCount += 1;
        });
      await provider.clear();
    });

    test('getToday() and fetchToday() work together', () async {
      actions.client = MockClient((request) async {
        expect(request.url.path, equals('/tasks/today'));

        return Response(tasksTodayResponseFixture, 200);
      });
      var viewData = await provider.getToday();
      expect(viewData.pending, equals(true));
      expect(viewData.tasks.length, equals(0));

      await provider.fetchToday();
      var taskData = await provider.getToday();
      expect(taskData.pending, equals(false));
      expect(taskData.tasks.length, equals(2));
      expect(taskData.tasks[0].title, equals('clean dishes'));
      expect(taskData.calendarItems.length, equals(1));
      expect(taskData.calendarItems[0].title, equals('Get haircut'));
      expect(listenerCallCount, greaterThanOrEqualTo(1));
    });

    test('fetchToday() handles server errors', () async {
      actions.client = MockClient((request) async {
        return Response('{"errors": ["bad things"]}', 400);
      });

      try {
        await provider.fetchToday();
      } on actions.ValidationError catch (e) {
        expect(e.toString(), contains('Could not load'));
      }
    });

    test('getUpcoming() and fetchUpcoming() work together', () async {
      actions.client = MockClient((request) async {
        expect(request.url.path, equals('/tasks/upcoming'));

        return Response(tasksTodayResponseFixture, 200);
      });
      var viewData = await provider.getUpcoming();
      expect(viewData.pending, equals(true));

      await provider.fetchUpcoming();
      var taskData = await provider.getUpcoming();
      expect(taskData.tasks.length, equals(2));
      expect(taskData.tasks[0].title, equals('clean dishes'));
      expect(taskData.calendarItems.length, equals(1));
      expect(taskData.calendarItems[0].title, equals('Get haircut'));
      expect(listenerCallCount, greaterThanOrEqualTo(1));
    });

    test('toggleComplete() sends complete request', () async {
      actions.client = MockClient((request) async {
        expect(request.url.path, contains('/tasks/1/complete'));
        return Response('', 204);
      });

      var db = LocalDatabase();

      var tasks = parseTaskList(tasksTodayResponseFixture);
      await db.addTasks(tasks);
      var provider = TasksProvider(db, session);

      await provider.toggleComplete(tasks[0]);

      expect(listenerCallCount, greaterThan(0));

      var updated = await db.today.get();
      expect(updated.tasks.length, equals(0));
      expect(updated.calendarItems.length, equals(0));
    });

    test('toggleComplete() expires local data', () async {
      actions.client = MockClient((request) async {
        return Response('', 204);
      });

      var tasks = parseTaskList(tasksTodayResponseFixture);
      await setTodayView(tasks);

      var provider = TasksProvider(db, session);
      await provider.toggleComplete(tasks[0]);

      // Data should be expired as task was from today.
      var updated = await db.today.get();
      expect(updated.tasks.length, equals(0));
    });

    test('deleteTask() removes task', () async {
      actions.client = MockClient((request) async {
        expect(request.url.path, contains('/tasks/1/delete'));
        return Response('', 204);
      });

      var tasks = parseTaskList(tasksTodayResponseFixture);
      await setTodayView(tasks);

      var provider = TasksProvider(db, session);
      await provider.deleteTask(tasks[0]);

      expect(listenerCallCount, greaterThan(0));

      var updated = await provider.getToday();
      expect(updated.pending, equals(true));
      expect(updated.tasks.length, equals(0));
    });

    test('getById() reads tasks', () async {
      actions.client = MockClient((request) async {
        throw Exception('No request should be sent.');
      });

      var db = LocalDatabase();
      var tasks = parseTaskList(tasksTodayResponseFixture);
      await db.addTasks(tasks);
      var provider = TasksProvider(db, session);

      var task = await provider.getById(1);
      expect(task, isNotNull);
      expect(task!.id, equals(1));
    });

    test('getById() throws error on network failure', () async {
      actions.client = MockClient((request) async {
        return Response('error', 500);
      });

      try {
        await provider.getById(1);
        fail('Should not get here');
      } catch (err) {
        expect(err.toString(), contains('Could not load'));
      }
    });

    test('createTask() calls API, clears date views & project view', () async {
      actions.client = MockClient((request) async {
        expect(request.url.path, equals('/tasks/add'));

        return Response(taskCreateTodayResponseFixture, 200);
      });

      // Seed the today view
      var tasks = parseTaskList(tasksTodayResponseFixture);
      await setTodayView(tasks);

      var task = Task.blank();
      // This data has to match the fixture file.
      task.title = "fold the towels";
      task.projectId = 1;
      task.dueOn = today;

      var created = await provider.createTask(task);
      expect(created.id, equals(1));

      var todayData = await provider.getToday();
      expect(todayData.tasks.length, equals(0));
    });

    test('updateTask() call API, and clears today view', () async {
      actions.client = MockClient((request) async {
        expect(request.url.path, equals('/tasks/1/edit'));

        return Response(taskCreateTodayResponseFixture, 200);
      });

      var tasks = parseTaskList(tasksTodayResponseFixture);
      await setTodayView(tasks);

      var task = Task.blank();
      // This data has to match the fixture file.
      task.id = 1;
      task.title = "fold the towels";
      task.projectId = 1;
      task.projectSlug = 'home';
      task.dueOn = today;

      var updated = await provider.updateTask(task);
      print('update complete');
      expect(updated.id, equals(1));
      expect(updated.title, equals('fold the towels'));

      var todayData = await provider.getToday();
      expect(todayData.pending, equals(false));
      expect(todayData.tasks.length, equals(0));
    });
  });
}
