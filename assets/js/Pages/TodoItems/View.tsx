import React, {useState} from 'react';
import axios from 'axios';
import {Inertia} from '@inertiajs/inertia';

import {TodoItemDetailed, ValidationErrors} from 'app/types';
import LoggedIn from 'app/layouts/loggedIn';
import Modal from 'app/components/modal';
import TodoItemQuickForm from 'app/components/todoItemQuickForm';
import TodoItemNotes from 'app/components/todoItemNotes';
import TodoItemSubtasks from 'app/components/todoItemSubtasks';
import ProjectBadge from 'app/components/projectBadge';
import {InlineIcon} from '@iconify/react';

type Props = {
  todoItem: TodoItemDetailed;
  referer: string;
};

export default function TodoItemsView({referer, todoItem}: Props) {
  const [editing, setEditing] = useState(false);
  const [errors, setErrors] = useState<ValidationErrors>({});

  function handleClose() {
    Inertia.visit(referer);
  }

  function handleSubmit(event: React.FormEvent) {
    event.preventDefault();
    const formData = new FormData(event.target as HTMLFormElement);

    // Do an XHR request so we can handle validation errors
    // inside the modal.
    axios
      .post(`/todos/${todoItem.id}/edit`, formData)
      .then(() => {
        Inertia.visit(referer);
      })
      .catch(error => {
        if (error.response) {
          setErrors(error.response.data.errors);
        }
      });
  }

  function handleCancel() {
    setEditing(false);
  }

  return (
    <LoggedIn>
      <Modal onClose={handleClose}>
        <div className="todoitems-view">
          {editing ? (
            <TodoItemQuickForm
              onSubmit={handleSubmit}
              onCancel={handleCancel}
              todoItem={todoItem}
              errors={errors}
            />
          ) : (
            <TodoItemSummary todoItem={todoItem} onClick={() => setEditing(true)} />
          )}
          <TodoItemNotes todoItem={todoItem} />
          <TodoItemSubtasks todoItem={todoItem} />
        </div>
      </Modal>
    </LoggedIn>
  );
}

type SummaryProps = {
  todoItem: TodoItemDetailed;
  onClick: () => void;
};

function TodoItemSummary({todoItem, onClick}: SummaryProps) {
  const handleComplete = (e: React.MouseEvent<HTMLInputElement>) => {
    e.stopPropagation();
    Inertia.post(
      `/todos/${todoItem.id}/${todoItem.completed ? 'incomplete' : 'complete'}`
    );
  };

  return (
    <div className="summary">
      <input
        className="completed"
        type="checkbox"
        value="1"
        onClick={handleComplete}
        defaultChecked={todoItem.completed}
      />
      <a href="#" onClick={onClick}>
        <h3>{todoItem.title}</h3>
        <div className="attributes">
          {<ProjectBadge project={todoItem.project} />}
          {todoItem.due_on && (
            <time className="due-on" dateTime={todoItem.due_on}>
              <InlineIcon icon="calendar" />
              {todoItem.due_on}
            </time>
          )}
        </div>
      </a>
    </div>
  );
}