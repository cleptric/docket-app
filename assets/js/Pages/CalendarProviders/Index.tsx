import {Inertia} from '@inertiajs/inertia';
import {InertiaLink} from '@inertiajs/inertia-react';
import {useRef} from 'react';

import {t} from 'app/locale';
import {deleteProvider} from 'app/actions/calendars';
import LoggedIn from 'app/layouts/loggedIn';
import Modal from 'app/components/modal';
import OverflowActionBar from 'app/components/overflowActionBar';
import {CalendarProvider, CalendarProviderDetailed, CalendarSource} from 'app/types';
import {InlineIcon} from 'app/components/icon';

import CalendarSources from './calendarSources';

type Props = {
  calendarProviders: CalendarProviderDetailed[];
  activeProvider: CalendarProviderDetailed;
  referer: string;
  unlinked: null | CalendarSource[];
};

function CalendarProvidersIndex({
  activeProvider,
  referer,
  calendarProviders,
  unlinked,
}: Props) {
  // Use a ref to keep track of the first referer.
  // We only want the first one as the sync, update and delete options
  // use redirects to end up on the same calendar list view.
  // These redirects contain the referer *they* came from which is *this*
  // view. Once the 'referer' becomes this view the user can't leave the modal.
  const firstReferer = useRef('');
  if (!firstReferer.current && referer) {
    firstReferer.current = referer;
  }
  function handleClose() {
    Inertia.visit(firstReferer.current);
  }

  const title = t('Synced Calendars');
  return (
    <LoggedIn title={title}>
      <Modal onClose={handleClose} label={title} className="calendar-add">
        <h2>{title}</h2>
        <p>
          {t(
            'Events from linked calendars will be displayed in "today" and "upcoming" views.'
          )}
        </p>
        <div className="button-bar">
          <a className="button-primary" href="/auth/google/authorize">
            <InlineIcon icon="plus" />
            {t('Add Google Account')}
          </a>
        </div>

        <h3>{t('Connected Calendar Accounts')}</h3>
        <ul className="list-items">
          {calendarProviders.map(calendarProvider => {
            const isActive = activeProvider && calendarProvider.id === activeProvider.id;
            return (
              <CalendarProviderItem
                key={calendarProvider.id}
                isActive={isActive}
                provider={calendarProvider}
                unlinked={isActive ? unlinked : null}
              />
            );
          })}
        </ul>
      </Modal>
    </LoggedIn>
  );
}
export default CalendarProvidersIndex;

type ProviderProps = {
  provider: CalendarProvider;
  isActive: boolean;
  unlinked: Props['unlinked'];
};

function CalendarProviderItem({isActive, provider, unlinked}: ProviderProps) {
  async function handleDelete() {
    await deleteProvider(provider);
  }

  function handleManage() {
    Inertia.visit(`/calendars/${provider.id}/sources/add`);
  }

  return (
    <li className="list-item-panel" data-active={isActive}>
      <div className="list-item-panel-header">
        {isActive && (
          <span className="list-item-block">
            <ProviderIcon provider={provider} /> {provider.display_name}
          </span>
        )}
        {!isActive && (
          <InertiaLink
            href={`/calendars?provider=${provider.id}`}
            className="list-item-block"
          >
            <ProviderIcon provider={provider} /> {provider.display_name}
          </InertiaLink>
        )}
        <div className="list-item-block">
          <OverflowActionBar
            label={t('Calendar Actions')}
            foldWidth={700}
            items={[
              {
                buttonClass: 'button-danger',
                menuItemClass: 'delete',
                onSelect: handleDelete,
                label: t('Unlink'),
                icon: <InlineIcon icon="trash" />,
              },
            ]}
          />
        </div>
      </div>
      {unlinked && (
        <div className="list-item-panel-item">
          <CalendarSources calendarProvider={provider} unlinked={unlinked} />
        </div>
      )}
    </li>
  );
}

type ProviderIconProps = {
  provider: CalendarProvider;
};
function ProviderIcon({provider}: ProviderIconProps) {
  if (provider.kind === 'google') {
    return (
      <img
        src="/img/google-calendar-logo.svg"
        alt="Google Calendar logo"
        width="30"
        height="30"
      />
    );
  }
  return <InlineIcon icon="calendar" />;
}
