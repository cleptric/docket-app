import React from 'react';
import {sortBy} from 'lodash';

import {Task} from 'app/types';
import LoggedIn from 'app/layouts/loggedIn';
import TaskGroup from 'app/components/taskGroup';
import TaskGroupedSorter, {GroupedItems} from 'app/components/taskGroupedSorter';
import {toDateString, formatDateHeading, parseDate, ONE_DAY_IN_MS} from 'app/utils/dates';

type Props = {
  tasks: Task[];
};

/**
 * Fill out the sparse input data to have all the days.
 */
function zeroFillItems(groups: GroupedItems): GroupedItems {
  const sorted = sortBy(groups, group => group.key);

  const first = (sorted.length ? parseDate(sorted[0].key) : new Date()).getTime();
  // XXX: Time based views are for 28 days at a time.
  const end = first + 28 * ONE_DAY_IN_MS;

  const complete: GroupedItems = [];
  for (let i = first; i < end; i += ONE_DAY_IN_MS) {
    const date = new Date(i);
    const dateKey = toDateString(date);
    if (sorted.length && sorted[0].key === dateKey) {
      const values = sorted.shift();
      if (values) {
        complete.push(values);
      }
    } else {
      complete.push({key: dateKey, items: []});
    }
  }
  return complete;
}

export default function TasksIndex({tasks}: Props) {
  return (
    <LoggedIn>
      <h1>Upcoming</h1>
      <TaskGroupedSorter tasks={tasks} scope="day">
        {({groupedItems}) => {
          const calendarGroups = zeroFillItems(groupedItems);
          return (
            <React.Fragment>
              {calendarGroups.map(({key, items}) => (
                <React.Fragment key={key}>
                  <h2>{formatDateHeading(key)}</h2>
                  <TaskGroup
                    dropId={key}
                    tasks={items}
                    defaultDate={key}
                    showProject
                  />
                </React.Fragment>
              ))}
            </React.Fragment>
          );
        }}
      </TaskGroupedSorter>
    </LoggedIn>
  );
}