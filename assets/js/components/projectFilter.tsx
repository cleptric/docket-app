import React from 'react';
import {InertiaLink} from '@inertiajs/inertia-react';

import {Project} from 'app/types';
import DragContainer from 'app/components/dragContainer';
import ProjectItem from 'app/components/projectItem';
import ProjectSorter from 'app/components/projectSorter';
import NewProjectModal from 'app/components/modals/newProjectModal';

function ProjectFilter() {
  const [showModal, setShowModal] = React.useState(false);
  const showNewProject = () => {
    setShowModal(true);
  };

  return (
    <div className="project-filter">
      <ul>
        <li>
          <InertiaLink href="/todos/today">Today</InertiaLink>
        </li>
        <li>
          <InertiaLink href="/todos/upcoming">Upcoming</InertiaLink>
        </li>
      </ul>
      <h3>Projects</h3>
      <ul className="drag-container-left-offset">
        <ProjectSorter>
          {({projects, handleOrderChange}) => (
            <DragContainer
              itemElement={<li />}
              items={projects}
              renderItem={(project: Project) => (
                <ProjectItem key={project.slug} project={project} />
              )}
              onChange={handleOrderChange}
            />
          )}
        </ProjectSorter>
      </ul>
      <div className="button-bar-vertical">
        <a className="button-muted" href="/projects/archived">
          Archived Projects
        </a>
        <button className="button-secondary" onClick={showNewProject}>
          Create Project
        </button>
      </div>
      <NewProjectModal showModal={showModal} onClose={() => setShowModal(false)} />
    </div>
  );
}

export default ProjectFilter;
