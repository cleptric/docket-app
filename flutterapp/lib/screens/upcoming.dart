import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:docket/components/appdrawer.dart';
import 'package:docket/components/calendaritemlist.dart';
import 'package:docket/components/floatingcreatetaskbutton.dart';
import 'package:docket/components/loadingindicator.dart';
import 'package:docket/components/taskaddbutton.dart';
import 'package:docket/components/taskgroup.dart';
import 'package:docket/formatters.dart' as formatters;
import 'package:docket/models/task.dart';
import 'package:docket/providers/tasks.dart';
import 'package:docket/grouping.dart' as grouping;
import 'package:docket/theme.dart';

class UpcomingScreen extends StatefulWidget {
  static const routeName = '/tasks/upcoming';

  const UpcomingScreen({super.key});

  @override
  State<UpcomingScreen> createState() => _UpcomingScreenState();
}

class _UpcomingScreenState extends State<UpcomingScreen> {
  @override
  void initState() {
    super.initState();
    var tasksProvider = Provider.of<TasksProvider>(context, listen: false);

    tasksProvider.fetchUpcoming();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TasksProvider>(builder: (context, tasks, child) {
      var theme = Theme.of(context);
      var taskViewData = tasks.getUpcoming();

      return Scaffold(
          appBar: AppBar(),
          drawer: const AppDrawer(),
          floatingActionButton: const FloatingCreateTaskButton(),
          body: ListView(padding: const EdgeInsets.all(4), children: [
            Text('Upcoming', style: theme.textTheme.titleLarge),
            FutureBuilder<TaskViewData>(
                future: taskViewData,
                builder: (context, snapshot) {
                  var data = snapshot.data;
                  if (data == null) {
                    return const LoadingIndicator();
                  }
                  var grouperFunc = grouping.createGrouper(DateTime.now(), 28);
                  var grouped = grouperFunc(data.tasks);
                  var groupedCalendarItems = grouping.groupCalendarItems(data.calendarItems);

                  return Column(
                    children: grouped.map<Widget>((group) {
                      var calendarItems = groupedCalendarItems.get(group.key);

                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        TaskGroupHeading(dateKey: group.key),
                        SizedBox(height: space(0.5)),
                        CalendarItemList(calendarItems: calendarItems),
                        TaskGroup(tasks: group.items, showProject: true),
                      ]);
                    }).toList(),
                  );
                }),
          ]));
    });
  }
}

class TaskGroupHeading extends StatelessWidget {
  // Uses the keys format generated by grouping.createGrouper() and Task.dateKey
  final String dateKey;

  const TaskGroupHeading({required this.dateKey, super.key});

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var docketColors = theme.extension<DocketColors>()!;
    var heading = dateKey;

    var isEvening = heading.contains('evening:');
    if (isEvening) {
      heading = 'Evening';
    }

    Widget subheading = const SizedBox(width: 0);
    Widget icon = const SizedBox(width: 0);
    if (!isEvening) {
      var dateVal = DateTime.parse('$dateKey 00:00:00');
      heading = formatters.compactDate(dateVal);
      icon = TaskAddButton(dueOn: dateVal);

      var subheadingContent = formatters.monthDay(dateVal);

      if (subheadingContent != heading) {
        subheading = Text(formatters.monthDay(dateVal),
            style: theme.textTheme.titleSmall!.copyWith(color: docketColors.secondaryText));
      }
    }

    var headingStyle = theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w500);
    if (isEvening) {
      headingStyle = theme.textTheme.titleSmall!.copyWith(color: docketColors.secondaryText);
    }

    return Column(
      children: [
        SizedBox(height: isEvening ? space(0.5) : space(3)),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(heading, style: headingStyle),
          SizedBox(width: space(0.5)),
          subheading,
          icon,
        ]),
      ],
    );
  }
}
