import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:docket/theme.dart';

import 'package:docket/components/dueon.dart';
import 'package:docket/dialogs/changedueon.dart';

/// Form layout widget.
/// Includes a leading element that is expected to be ~18px wide
/// Generally an icon but can also be an interactive wiget like a checkbox.
class FormIconRow extends StatelessWidget {
  final Widget child;
  final Widget? icon;

  const FormIconRow({this.icon, required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    late Widget iconWidget;
    if (icon != null) {
      iconWidget = Padding(padding: EdgeInsets.fromLTRB(0, space(1), space(2), 0), child: icon);
    } else {
      iconWidget = const SizedBox(width: 34);
    }

    return Container(
      padding: EdgeInsets.all(space(1)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          iconWidget,
          Expanded(child: child),
        ]
      )
    );
  }
}

/// Form widget for updating the dueOn attribute of a task.
class DueOnInput extends StatelessWidget {
  final DateTime? dueOn;
  final bool evening;

  final Function(DateTime? dueOn, bool evening) onUpdate;

  const DueOnInput({
    required this.onUpdate,
    required this.dueOn,
    required this.evening,
    super.key
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      child: DueOn(dueOn: dueOn, evening: evening, showNull: true),
      onPressed: () {
        showChangeDueOnDialog(context, dueOn, evening, onUpdate);
      }
    );
  }
}

/// Render text as markdown. Switch to TextInput on tap
/// for editing. Once editing is complete, the onChange
/// callback is triggered.
class MarkdownInput extends StatefulWidget {
  final String value;
  final String label;
  final Function(String newText) onChange;

  const MarkdownInput({
    required this.value,
    required this.onChange,
    this.label = "Notes",
    super.key
  });

  @override
  State<MarkdownInput> createState() => _MarkdownInputState();
}

class _MarkdownInputState extends State<MarkdownInput> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    if (!_editing) {
      var body = widget.value.isNotEmpty ? widget.value : 'Tap to edit';

      return MarkdownBody(
        key: const ValueKey('markdown-preview'),
        data: body,
        selectable: true,
        onTapText: () {
          setState(() {
            _editing = true;
          });
        }
      );
    }

    return TextFormField(
      key: const ValueKey('markdown-input'),
      keyboardType: TextInputType.multiline,
      minLines: 1,
      maxLines: null,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: widget.label,
      ),
      initialValue: widget.value,
      onSaved: (value) {
        if (value != null) {
          widget.onChange(value);
          setState(() {
            _editing = false;
          });
        }
      }
    );
  }
}