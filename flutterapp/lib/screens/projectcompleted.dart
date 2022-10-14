import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:docket/components/appdrawer.dart';
import 'package:docket/components/loadingindicator.dart';
import 'package:docket/components/taskitem.dart';
import 'package:docket/models/project.dart';
import 'package:docket/models/task.dart';
import 'package:docket/providers/projects.dart';
import 'package:docket/providers/tasks.dart';
import 'package:docket/theme.dart';

class ProjectCompletedScreen extends StatefulWidget {
  final Project project;

  const ProjectCompletedScreen(this.project, {super.key});

  @override
  State<ProjectCompletedScreen> createState() => _ProjectCompletedScreenState();
}

class _ProjectCompletedScreenState extends State<ProjectCompletedScreen> {
  @override
  void initState() {
    _refresh();

    super.initState();
  }

  Future<List<void>> _refresh() {
    var projectsProvider = Provider.of<ProjectsProvider>(context, listen: false);

    return Future.wait([
      projectsProvider.fetchCompletedTasks(widget.project.slug),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ProjectsProvider, TasksProvider>(builder: (context, projectsProvider, tasksProvider, child) {

      projectsProvider.fetchCompletedTasks(widget.project.slug);
      var projectFuture = projectsProvider.getCompletedTasks(widget.project.slug);

      return FutureBuilder<ProjectWithTasks?>(
          future: projectFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return buildWrapper(context: context, project: widget.project, child: const Card(child: Text("Something terrible happened")));
            }
            var data = snapshot.data;
            if (data == null || data.pending || data.missingData) {
              return buildWrapper(context: context, project: widget.project, child: const LoadingIndicator());
            }

            return buildWrapper(
                context: context,
                project: data.project,
                child: ListView.builder(
                    itemCount: data.tasks.length,
                    prototypeItem: TaskItem(task: data.tasks.isNotEmpty ? data.tasks.first : Task.blank(), showDate: true),
                    itemBuilder: (BuildContext context, int index) {
                      return TaskItem(task: data.tasks[index], showDate: true);
                    },
                  ));
          });
    });
  }

  Widget buildWrapper({required BuildContext context, required Widget child, required Project project}) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: getProjectColor(project.color),
        title: Text("Completed ${project.name} Tasks"),
        leading: IconButton(onPressed: () {
          Navigator.pop(context);
        }, icon: const Icon(Icons.arrow_back)),
      ),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: child,
      ),
    );
  }
}