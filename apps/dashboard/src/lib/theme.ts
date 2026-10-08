import { useEffect, useState } from 'react';

export type ThemeChoice = 'system' | 'light' | 'dark';
const KEY = 'naql.theme';
const ORDER: ThemeChoice[] = ['system', 'light', 'dark'];

function stored(): ThemeChoice {
  try {
    const v = localStorage.getItem(KEY);
    return v === 'light' || v === 'dark' ? v : 'system';
  } catch {
    return 'system';
  }
}

/** Pins (or releases) the colour scheme on <html data-theme>; "system" follows the device. */
export function applyTheme(choice: ThemeChoice = stored()) {
  const root = document.documentElement;
  if (choice === 'system') delete root.dataset.theme;
  else root.dataset.theme = choice;
}

export function useTheme() {
  const [choice, setChoice] = useState<ThemeChoice>(stored);
  useEffect(() => {
    applyTheme(choice);
    try {
      if (choice === 'system') localStorage.removeItem(KEY);
      else localStorage.setItem(KEY, choice);
    } catch {
      /* private mode: the choice lasts for this visit */
    }
  }, [choice]);
  return { choice, cycle: () => setChoice((c) => ORDER[(ORDER.indexOf(c) + 1) % ORDER.length]) };
}
