import {Fragment} from 'react';
import {Menu, MenuList, MenuButton} from '@reach/menu-button';

import {t} from 'app/locale';

type Props = {
  children: React.ReactNode;
  /**
   * A render function that must return an element
   * to trigger showing the menu. The `props` parameter
   * has event handlers.
   */
  button?: () => React.ReactNode;
};

function defaultButton() {
  return <MenuButton>{t('Open')}</MenuButton>;
}

function DropdownMenu({button, children}: Props): JSX.Element {
  return (
    <Menu>
      {({isExpanded}) => (
        <Fragment>
          {button ? button() : defaultButton()}
          {isExpanded && <MenuList>{children}</MenuList>}
        </Fragment>
      )}
    </Menu>
  );
}
export default DropdownMenu;
