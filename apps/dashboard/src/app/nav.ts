import { Building2, Bus, HandCoins, History, Radio, Route, CreditCard, CalendarClock, FileCheck2, GraduationCap, LayoutDashboard, Layers, MapPin, Users, type LucideIcon } from 'lucide-react';
import type { Role } from '../lib/api';
import type { MessageKey } from '../lib/i18n';

export interface NavItem {
  to: string;
  label: MessageKey;
  icon: LucideIcon;
  roles: Role[];
}

export interface NavGroup {
  label: MessageKey;
  items: NavItem[];
}

/** Single source for menu items and route permissions. */
export const NAV: NavGroup[] = [
  {
    label: 'nav.group.main',
    items: [
      { to: '/', label: 'nav.overview', icon: LayoutDashboard, roles: ['office', 'super_admin'] },
      { to: '/live', label: 'nav.live', icon: Radio, roles: ['office'] },
      { to: '/dispatch', label: 'nav.dispatch', icon: Route, roles: ['office'] },
      { to: '/subscriptions', label: 'nav.subscriptions', icon: CreditCard, roles: ['office'] },
      { to: '/settlement', label: 'nav.settlement', icon: HandCoins, roles: ['office'] },
      { to: '/drivers', label: 'nav.drivers', icon: Bus, roles: ['office'] },
      { to: '/students', label: 'nav.students', icon: GraduationCap, roles: ['office'] },
      { to: '/users', label: 'nav.users', icon: Users, roles: ['office'] },
    ],
  },
  {
    label: 'nav.group.settings',
    items: [
      { to: '/settings/tiers', label: 'nav.tiers', icon: Layers, roles: ['office'] },
      { to: '/settings/points', label: 'nav.points', icon: MapPin, roles: ['office'] },
      { to: '/settings/waves', label: 'nav.waves', icon: CalendarClock, roles: ['office'] },
      { to: '/settings/requirements', label: 'nav.requirements', icon: FileCheck2, roles: ['office'] },
    ],
  },
  {
    label: 'nav.group.platform',
    items: [
      { to: '/universities', label: 'nav.universities', icon: Building2, roles: ['super_admin'] },
      { to: '/audit', label: 'nav.audit', icon: History, roles: ['office', 'super_admin'] },
    ],
  },
];

export const ALL_ITEMS = NAV.flatMap((g) => g.items);
