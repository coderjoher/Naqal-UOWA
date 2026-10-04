import { createContext, useContext, useEffect, useState, type ReactNode } from 'react';

const ar = {
  appName: 'نقل جامعة وارث',
  'login.title': 'تسجيل الدخول',
  'login.subtitle': 'لوحة مكتب النقل والإدارة',
  'login.email': 'البريد الإلكتروني',
  'login.password': 'كلمة المرور',
  'login.submit': 'دخول',
  'login.error': 'البريد الإلكتروني أو كلمة المرور غير صحيحة',
  'nav.overview': 'نظرة عامة',
  'nav.universities': 'الجامعات',
  'nav.users': 'المستخدمون',
  'nav.logout': 'تسجيل الخروج',
  'overview.welcome': 'أهلاً',
  'overview.soon': 'ستظهر هنا مؤشرات التشغيل في المراحل القادمة.',
  'universities.title': 'الجامعات',
  'universities.name': 'الاسم',
  'universities.slug': 'المعرّف',
  'universities.commission': 'العمولة',
  'universities.waitlist': 'مدة الانتظار',
  'users.title': 'المستخدمون',
  'users.name': 'الاسم',
  'users.email': 'البريد',
  'users.role': 'الدور',
  'users.status': 'الحالة',
  'role.student': 'طالب',
  'role.driver': 'سائق',
  'role.office': 'مكتب النقل',
  'role.super_admin': 'مدير المنصة',
  'status.active': 'فعّال',
  'status.suspended': 'موقوف',
  'common.empty': 'لا توجد بيانات بعد',
  'common.loading': 'جارٍ التحميل…',
  'common.error': 'تعذّر تحميل البيانات',
  'common.minutes': 'دقيقة',
  'lang.switch': 'English',
};

const en: Record<keyof typeof ar, string> = {
  appName: 'Naql Jamiat Warith',
  'login.title': 'Sign in',
  'login.subtitle': 'Transport office & admin dashboard',
  'login.email': 'Email',
  'login.password': 'Password',
  'login.submit': 'Sign in',
  'login.error': 'Incorrect email or password',
  'nav.overview': 'Overview',
  'nav.universities': 'Universities',
  'nav.users': 'Users',
  'nav.logout': 'Sign out',
  'overview.welcome': 'Hello',
  'overview.soon': 'Operational metrics will appear here in later phases.',
  'universities.title': 'Universities',
  'universities.name': 'Name',
  'universities.slug': 'Slug',
  'universities.commission': 'Commission',
  'universities.waitlist': 'Waitlist',
  'users.title': 'Users',
  'users.name': 'Name',
  'users.email': 'Email',
  'users.role': 'Role',
  'users.status': 'Status',
  'role.student': 'Student',
  'role.driver': 'Driver',
  'role.office': 'Transport office',
  'role.super_admin': 'Platform admin',
  'status.active': 'Active',
  'status.suspended': 'Suspended',
  'common.empty': 'Nothing here yet',
  'common.loading': 'Loading…',
  'common.error': 'Could not load data',
  'common.minutes': 'min',
  'lang.switch': 'العربية',
};

export type Lang = 'ar' | 'en';
export type MessageKey = keyof typeof ar;
export const messages: Record<Lang, Record<MessageKey, string>> = { ar, en };

interface I18n {
  lang: Lang;
  t: (key: MessageKey) => string;
  toggle: () => void;
}

const Ctx = createContext<I18n | null>(null);
const STORE_KEY = 'naql.lang';

function initialLang(): Lang {
  try {
    return localStorage.getItem(STORE_KEY) === 'en' ? 'en' : 'ar';
  } catch {
    return 'ar';
  }
}

/** Arabic RTL by default (ST-12 applies to the dashboard too). */
export function I18nProvider({ children }: { children: ReactNode }) {
  const [lang, setLang] = useState<Lang>(initialLang);
  useEffect(() => {
    document.documentElement.lang = lang;
    document.documentElement.dir = lang === 'ar' ? 'rtl' : 'ltr';
    try {
      localStorage.setItem(STORE_KEY, lang);
    } catch {
      /* private mode */
    }
  }, [lang]);
  const value: I18n = { lang, t: (k) => messages[lang][k], toggle: () => setLang((l) => (l === 'ar' ? 'en' : 'ar')) };
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useI18n() {
  const v = useContext(Ctx);
  if (!v) throw new Error('useI18n outside I18nProvider');
  return v;
}
