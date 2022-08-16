import 'package:docket/screens/projectedit.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:docket/components/iconsnackbar.dart';
import 'package:docket/models/project.dart';
import 'package:docket/providers/projects.dart';
import 'package:docket/theme.dart';

enum Menu {
  archive,
  edit,
}

class ProjectActions extends StatelessWidget {
  final Project project;

  const ProjectActions(this.project, {super.key});

  @override
  Widget build(BuildContext context) {
    var projectProvider = Provider.of<ProjectsProvider>(context);
    var messenger = ScaffoldMessenger.of(context);

    Future<void> _handleArchive() async {
      projectProvider.archive(project);
      messenger.showSnackBar(successSnackBar(context: context, text: 'Project Updated'));
    }

    void _handleEdit() {
      var route = ProjectEditScreen.routeName.replaceAll('{slug}', project.slug);
      Navigator.pushNamed(context, route);
    }

    var theme = Theme.of(context);
    var customColors = theme.extension<DocketColors>()!;

    return PopupMenuButton<Menu>(onSelected: (Menu item) {
      var actions = {
        Menu.edit: _handleEdit,
        Menu.archive: _handleArchive,
        // TODO add project deletion
      };
      actions[item]?.call();
    }, itemBuilder: (BuildContext context) {
      return <PopupMenuEntry<Menu>>[
        PopupMenuItem<Menu>(
          value: Menu.edit,
          child: ListTile(
            leading: Icon(Icons.edit_outlined, color: customColors.actionEdit),
            title: const Text('Edit Project'),
          ),
        ),
        PopupMenuItem<Menu>(
          value: Menu.archive,
          child: ListTile(
            leading: Icon(Icons.archive_outlined, color: customColors.dueNone),
            title: const Text('Archive'),
          ),
        ),
      ];
    });
  }
}