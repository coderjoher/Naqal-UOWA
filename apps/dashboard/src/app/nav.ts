import type { Role } from '../lib/api';
import type { MessageKey } from '../lib/i18n';

export interface NavItem {
  to: string;
  label: MessageKey;
  roles: Role[];
}

/** Single source for menu items and route permissions. */
export const NAV: NavItem[] = [
  { to: '/', label: 'nav.overview', roles: ['office', 'super_admin'] },
  { to: '/universities', label: 'nav.universities', roles: ['super_admin'] },
  { to: '/users', label: 'nav.users', roles: ['office'] },
];
