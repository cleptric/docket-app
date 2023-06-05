import 'dart:io';
import 'package:docket/models/apitoken.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';

import 'package:docket/actions.dart' as actions;
import 'package:docket/database.dart';
import 'package:docket/formatters.dart' as formatters;
import 'package:docket/models/task.dart';
import 'package:docket/viewmodels/taskdetails.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var today = DateUtils.dateOnly(DateTime.now());

  var file = File('test_resources/task_details.json');
  final taskResponseFixture = file.readAsStringSync().replaceAll('__TODAY__', formatters.dateString(today));

  file = File('test_resources/task_create_today.json');
  final taskCreateTodayResponseFixture = file.readAsStringSync().replaceAll('__TODAY__', formatters.dateString(today));

  file = File('test_resources/subtask_update.json');
  final subtaskUpdateResponse = file.readAsStringSync();

  group('$TaskDetailsViewModel', () {
    var db = LocalDatabase(inTest: true);

    setUp(() async {
      await db.apiToken.set(ApiToken.fake());
      await db.taskDetails.clearSilent();
    });

    test('loadData() refreshes from server', () async {
      actions.client = MockClient((request) async {
        if (request.url.path == '/tasks/1/view') {
          return Response(taskResponseFixture, 200);
        }
        throw "Unexpected request to ${request.url.path}";
      });

      var viewmodel = TaskDetailsViewModel(db);
      viewmodel.setId(1);

      await viewmodel.loadData();
      expect(viewmodel.task.id, equals(1));
    });

    test('update() sends server request', () async {
      actions.client = MockClient((request) async {
        if (request.url.path == '/tasks/1/view') {
          return Response(taskResponseFixture, 200);
        }
        if (request.url.path == '/tasks/1/edit') {
          return Response(taskResponseFixture, 200);
        }
        throw "Unexpected request to ${request.url.path}";
      });

      var viewmodel = TaskDetailsViewModel(db);
      viewmodel.setId(1);
      var callCounter = CallCounter();
      viewmodel.addListener(callCounter);

      await viewmodel.loadData();
      var task = viewmodel.task;

      await viewmodel.update(task);
      expect(callCounter.callCount, greaterThan(0));
    });

    test('create() sends request, updates local', () async {
      actions.client = MockClient((request) async {
        expect(request.url.path, equals('/tasks/add'));

        return Response(taskCreateTodayResponseFixture, 200);
      });

      var viewmodel = TaskDetailsViewModel(db);
      viewmodel.setId(0);
      var task = Task.blank();

      // This data has to match the fixture file.
      task.title = "fold the towels";
      task.projectId = 1;
      task.dueOn = today;

      var created = await viewmodel.create(task);
      expect(created.id, equals(1));
      expect(viewmodel.id, equals(created.id));
      expect(viewmodel.task.id, equals(created.id));
    });

    test('reorderSubtask() sends request, updates local', () async {
      var requestCounter = CallCounter();
      actions.client = MockClient((request) async {
        if (request.url.path == '/tasks/1/view') {
          requestCounter();
          return Response(taskResponseFixture, 200);
        }
        if (request.url.path == '/tasks/1/subtasks/1/move') {
          return Response('', 200);
        }
        throw "Unexpected request to ${request.url.path}";
      });

      var viewmodel = TaskDetailsViewModel(db);
      viewmodel.setId(1);
      var callCounter = CallCounter();
      viewmodel.addListener(callCounter);

      await viewmodel.loadData();
      await viewmodel.reorderSubtask(0, 0, 1, 0);
      expect(requestCounter.callCount, equals(1));
      expect(callCounter.callCount, greaterThan(0));
    });

    test('reorderSubtask() only updates local for new task', () async {
      actions.client = MockClient((request) async {
        throw "Unexpected request to ${request.url.path}";
      });

      var task = Task.pending();
      task.title = 'Has a title';
      task.subtasks = [
        Subtask(title: 'subtask one'),
        Subtask(title: 'subtask two'),
      ];
      await db.taskDetails.set(task);

      var viewmodel = TaskDetailsViewModel(db);
      viewmodel.setId(task.id!);
      await viewmodel.loadData();

      var callCounter = CallCounter();
      viewmodel.addListener(callCounter);

      await viewmodel.reorderSubtask(0, 0, 1, 0);
      expect(callCounter.callCount, greaterThan(0));
    });

    test('saveSubtask() call API and update local task', () async {
      actions.client = MockClient((request) async {
        expect(request.url.path, equals('/tasks/1/subtasks/1/edit'));

        return Response(subtaskUpdateResponse, 200);
      });

      var task = Task.blank();
      task.id = 1;
      task.projectId = 1;
      task.projectSlug = 'home';
      task.title = "Do laundry";
      var subtask = Subtask(id: 1, title: 'replaced by server data');
      task.subtasks.add(subtask);

      var viewmodel = TaskDetailsViewModel(db);
      viewmodel.setId(task.id!);
      var callCounter = CallCounter();
      viewmodel.addListener(callCounter);
      await viewmodel.saveSubtask(task, subtask);

      var updated = await db.taskDetails.get(task.id!);
      var updatedSubtask = updated!.subtasks[0];
      expect(updatedSubtask, isNotNull);
      expect(updatedSubtask.completed, isFalse);
      expect(updatedSubtask.title, equals('fold big towels'));
      expect(callCounter.callCount, greaterThan(1));
    });

    test('saveSubtask() uses create API and update local task', () async {
      actions.client = MockClient((request) async {
        expect(request.url.path, equals('/tasks/1/subtasks'));

        return Response(subtaskUpdateResponse, 200);
      });

      var task = Task.blank();
      task.id = 1;
      task.projectId = 1;
      task.projectSlug = 'home';
      task.title = "Do laundry";
      var subtask = Subtask(title: 'replaced by server data');
      task.subtasks.add(subtask);

      var viewmodel = TaskDetailsViewModel(db);
      viewmodel.setId(task.id!);
      await viewmodel.saveSubtask(task, subtask);

      var updated = await db.taskDetails.get(task.id!);
      var updatedSubtask = updated!.subtasks[0];
      expect(updatedSubtask, isNotNull);
      expect(updatedSubtask.id, equals(1));
      expect(updatedSubtask.completed, isFalse);
      expect(updatedSubtask.title, equals('fold big towels'));
    });

    test('saveSubtask() updates local only for new task', () async {
      actions.client = MockClient((request) async {
        throw 'No requests should be sent';
      });

      var task = Task.pending();
      task.projectId = 1;
      task.projectSlug = 'home';
      task.title = "Do laundry";
      var subtask = Subtask(title: 'fold big towels');
      task.subtasks.add(subtask);

      var viewmodel = TaskDetailsViewModel(db);
      viewmodel.setId(task.id!);
      await viewmodel.saveSubtask(task, subtask);

      var updated = await db.taskDetails.get(task.id!);
      var updatedSubtask = updated!.subtasks[0];
      expect(updatedSubtask, isNotNull);
      expect(updatedSubtask.id, isNull);
      expect(updatedSubtask.completed, isFalse);
      expect(updatedSubtask.title, equals('fold big towels'));
    });

    test('deleteSubtask() uses API and update local task', () async {
      actions.client = MockClient((request) async {
        expect(request.url.path, equals('/tasks/1/subtasks/2/delete'));

        return Response(subtaskUpdateResponse, 200);
      });

      var task = Task.blank();
      task.id = 1;
      task.projectId = 1;
      task.projectSlug = 'home';
      task.title = "fold the towels";
      var subtask = Subtask(id: 2, title: 'get the towels');
      task.subtasks.add(subtask);

      var viewmodel = TaskDetailsViewModel(db);
      viewmodel.setId(task.id!);
      await viewmodel.deleteSubtask(task, subtask);

      var updated = await db.taskDetails.get(task.id!);
      expect(updated?.subtasks.length, equals(0));
    });

    test('deleteSubtask() updates local only for new task', () async {
      actions.client = MockClient((request) async {
        throw 'No requests expected';
      });

      var task = Task.pending();
      task.projectId = 1;
      task.projectSlug = 'home';
      task.title = "fold the towels";
      var subtask = Subtask(title: 'get the towels');
      task.subtasks.add(subtask);

      var viewmodel = TaskDetailsViewModel(db);
      viewmodel.setId(task.id!);
      await viewmodel.deleteSubtask(task, subtask);

      var updated = await db.taskDetails.get(task.id!);
      expect(updated?.subtasks.length, equals(0));
    });
  });
}
