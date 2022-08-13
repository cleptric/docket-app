import 'package:docket/screens/projectadd.dart';
import 'package:flutter/material.dart';

import 'package:docket/components/projectsorter.dart';
import 'package:docket/theme.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var customColors = theme.extension<DocketColors>()!;

    return Drawer(
        child: ListView(shrinkWrap: true, padding: EdgeInsets.zero, children: [
      const DrawerHeader(
        child: Text('Docket'),
      ),
      ListTile(
        onTap: () {
          Navigator.pushNamed(context, '/tasks/today');
        },
        leading: Icon(Icons.today, color: customColors.dueToday),
        title: const Text('Today'),
      ),
      ListTile(
        onTap: () {
          Navigator.pushNamed(context, '/tasks/upcoming');
        },
        leading: Icon(Icons.calendar_today, color: customColors.dueTomorrow),
        title: const Text('Upcoming'),
      ),
      ListTile(
        title: Text('Projects', style: theme.textTheme.subtitle1),
      ),
      const ProjectSorter(),
      ListTile(
          title: Text('Add Project', style: TextStyle(color: theme.colorScheme.primary)),
          onTap: () {
            Navigator.pushNamed(context, ProjectAddScreen.routeName);
          }),
      ListTile(
          title: Text('Archived Projects', style: TextStyle(color: customColors.dueNone)),
          onTap: () {
            Navigator.pushNamed(context, '/projects/add');
          }),
    ]));
  }
}
