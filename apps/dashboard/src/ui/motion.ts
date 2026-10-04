import type { Transition, Variants } from 'motion/react';

/** Shared motion language: quick and soft. Everything respects prefers-reduced-motion via MotionConfig. */
export const spring: Transition = { type: 'spring', stiffness: 420, damping: 32, mass: 0.8 };
const EASE_OUT = [0.22, 1, 0.36, 1] as const;
export const ease: Transition = { duration: 0.22, ease: EASE_OUT };

/** Page enter/exit; `dir` mirrors the slide in RTL. */
export const pageVariants: Variants = {
  initial: (rtl: boolean) => ({ opacity: 0, x: rtl ? -16 : 16 }),
  enter: { opacity: 1, x: 0, transition: { duration: 0.28, ease: EASE_OUT } },
  exit: (rtl: boolean) => ({ opacity: 0, x: rtl ? 12 : -12, transition: { duration: 0.16 } }),
};

/** Lists: children fade/slide in one after another. */
export const listVariants: Variants = { hidden: {}, show: { transition: { staggerChildren: 0.04, delayChildren: 0.04 } } };
export const itemVariants: Variants = { hidden: { opacity: 0, y: 6 }, show: { opacity: 1, y: 0, transition: ease } };
