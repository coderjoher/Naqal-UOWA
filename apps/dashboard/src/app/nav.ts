import {
  BarChart3,
  Building2,
  CalendarClock,
  CarTaxiFront,
  CreditCard,
  FileCheck2,
  GraduationCap,
  HandCoins,
  History,
  Inbox,
  Layers,
  LayoutDashboard,
  MapPin,
  Megaphone,
  MessagesSquare,
  Radio,
  Route,
  Settings,
  Bus,
  Users,
  UsersRound,
  type LucideIcon,
} from 'lucide-react';
import type { Role } from '../lib/api';
import type { MessageKey } from '../lib/i18n';

export interface NavItem {
  to: string;
  /** Full name: the link's accessible name, page search and flyout rows. */
  label: MessageKey;
  /** One or two words under the icon in the rail. */
  short: MessageKey;
  icon: LucideIcon;
  roles: Role[];
}

export interface NavGroup {
  label: MessageKey;
  /**
   * `rail`: each item is its own rail button. `flyout`: one rail button (icon + label) that opens
   * a popover with the items, for less-used pages. A flyout with one visible item shows that
   * item directly.
   */
  display: 'rail' | 'flyout';
  icon?: LucideIcon;
  /** Pinned to the bottom of the rail. */
  bottom?: boolean;
  items: NavItem[];
}

/** Single source for menu items and route permissions. */
export const NAV: NavGroup[] = [
  {
    label: 'nav.group.main',
    display: 'rail',
    items: [
      { to: '/', label: 'nav.overview', short: 'nav.short.overview', icon: LayoutDashboard, roles: ['office', 'super_admin'] },
      { to: '/live', label: 'nav.live', short: 'nav.short.live', icon: Radio, roles: ['office'] },
      { to: '/dispatch', label: 'nav.dispatch', short: 'nav.short.dispatch', icon: Route, roles: ['office'] },
      { to: '/taxi', label: 'nav.taxi', short: 'nav.short.taxi', icon: CarTaxiFront, roles: ['office'] },
      { to: '/subscriptions', label: 'nav.subscriptions', short: 'nav.short.subscriptions', icon: CreditCard, roles: ['office'] },
      { to: '/settlement', label: 'nav.settlement', short: 'nav.short.settlement', icon: HandCoins, roles: ['office'] },
      { to: '/reports', label: 'nav.reports', short: 'nav.short.reports', icon: BarChart3, roles: ['office'] },
    ],
  },
  {
    label: 'nav.group.comms',
    display: 'flyout',
    icon: MessagesSquare,
    items: [
      { to: '/inbox', label: 'nav.inbox', short: 'nav.short.inbox', icon: Inbox, roles: ['office'] },
      { to: '/announcements', label: 'nav.announcements', short: 'nav.short.announcements', icon: Megaphone, roles: ['office'] },
    ],
  },
  {
    label: 'nav.group.people',
    display: 'flyout',
    icon: UsersRound,
    items: [
      { to: '/drivers', label: 'nav.drivers', short: 'nav.drivers', icon: Bus, roles: ['office'] },
      { to: '/students', label: 'nav.students', short: 'nav.students', icon: GraduationCap, roles: ['office'] },
      { to: '/users', label: 'nav.users', short: 'nav.users', icon: Users, roles: ['office'] },
    ],
  },
  {
    label: 'nav.group.platform',
    display: 'rail',
    items: [{ to: '/universities', label: 'nav.universities', short: 'nav.universities', icon: Building2, roles: ['super_admin'] }],
  },
  {
    label: 'nav.group.settings',
    display: 'flyout',
    icon: Settings,
    bottom: true,
    items: [
      { to: '/settings/tiers', label: 'nav.tiers', short: 'nav.short.tiers', icon: Layers, roles: ['office'] },
      { to: '/settings/points', label: 'nav.points', short: 'nav.short.points', icon: MapPin, roles: ['office'] },
      { to: '/settings/waves', label: 'nav.waves', short: 'nav.waves', icon: CalendarClock, roles: ['office'] },
      { to: '/settings/requirements', label: 'nav.requirements', short: 'nav.short.requirements', icon: FileCheck2, roles: ['office'] },
      { to: '/audit', label: 'nav.audit', short: 'nav.short.audit', icon: History, roles: ['office', 'super_admin'] },
    ],
  },
];

export const ALL_ITEMS = NAV.flatMap((g) => g.items);

/** Groups with only the items this user may open (empty groups dropped). */
export function visibleNav(can: (...roles: Role[]) => boolean): NavGroup[] {
  return NAV.map((g) => ({ ...g, items: g.items.filter((n) => can(...n.roles)) })).filter((g) => g.items.length > 0);
}
