import 'package:flutter/material.dart';
import 'package:docket/models/task.dart';
import 'package:docket/formatters.dart' as formatters;

/// Module for task grouping logic.
/// This code is adapted from the javascript
/// code used in Tasks/index.tsx

class GroupedItem {
  String key;
  List<Task> items;
  List<String> ids;
  bool? hasAdd;

  GroupedItem({
    required this.key,
    required this.items,
    required this.ids,
    this.hasAdd,
  });
}

///
/// Fill out the sparse input data to have all the days.
///
List<GroupedItem> zeroFillItems(
  DateTime firstDate,
  int numDays,
  List<GroupedItem> groups
) {
  firstDate = DateUtils.dateOnly(firstDate);
  var endDate = firstDate.add(Duration(days: numDays));

  List<GroupedItem> complete = [];
  var date = firstDate;
  var index = 0;
  while (true) {
    // Gone past the end.
    if (date.isAfter(endDate) || index >= groups.length) {
      break;
    }

    var dateKey = formatters.dateString(date);
    if (groups[index].key == dateKey) {
      complete.add(groups[index]);
      index++;
    } else {
      complete.add(GroupedItem(key: dateKey, items: [], ids: []));
    }

    // Could advance past the end of the list.
    if (index >= groups.length) {
      continue;
    }

    if (index <= groups.length && groups[index].key == 'evening:$dateKey') {
      complete.add(groups[index]);
      index++;
    }

    // Increment for next loop. We are using a while/break
    // because incrementing timestamps fails when DST happens.
    date = date.add(const Duration(days: 1));
  }
  return complete;
}

Function(List<Task>) createGrouper(DateTime start, int numDays) {
  List<GroupedItem> taskGrouper(List<Task> items) {
    Map<String, List<Task>> byDate = {};
    for (var task in items) {
      var key = task.dateKey;
      if (byDate[key] == null) {
        byDate[key] = [];
      }
      byDate[key]?.add(task);
    }
    List<GroupedItem> grouped = [];
    for (var entry in byDate.entries) {
      grouped.add(GroupedItem(
          key: entry.key,
          items: entry.value,
          ids: entry.value.map((task) => task.id.toString()).toList(),
      ));
    }
    return zeroFillItems(start, numDays, grouped);
  }
  final function = taskGrouper;

  return function;
}

/*
type GroupedCalendarItems = Record<string, CalendarItem[]>;

function groupCalendarItems(items: CalendarItem[]): GroupedCalendarItems {
  return items.reduce<GroupedCalendarItems>((acc, item) => {
    let keys = [];
    if (item.all_day) {
      keys = getRangeInDays(parseDate(item.start_date), parseDate(item.end_date));
    } else {
      keys = getRangeInDays(new Date(item.start_time), new Date(item.end_time));
    }

    keys.forEach(key => {
      if (typeof acc[key] === 'undefined') {
        acc[key] = [];
      }
      acc[key].push(item);
    });

    return acc;
  }, {});
}
*/