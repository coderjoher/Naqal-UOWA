# Design system — "Clear first"

Reference: the two mood-board shots (TripWay-style booking app and the Metropolitan University bus
app). We keep their **light, airy layout, white rounded cards, one strong blue, big readable times
and pill controls**. We drop their gradients, glass blur and decorative photos.

## Principles (in priority order)

1. **Clarity over decoration.** A student half-awake at 7:00 must answer three questions in under
   2 seconds: *Do I have a seat? Which bus? When does it arrive?* Every screen leads with
   that answer in the largest text on the screen.
2. **Flat colour only.** No gradients, no glassmorphism, no background images behind text. Depth
   comes from a white surface on a tinted background plus one soft shadow.
3. **One primary action per screen.** It is the only solid blue button. Everything else is
   secondary (outline) or a text link.
4. **Status is never colour alone.** Every status has colour + icon + word (e.g. green ● "Assigned").
5. **RTL first.** Layouts are designed in Arabic first and mirrored for English. Use
   `start`/`end`, never `left`/`right`. Numbers and times stay LTR inside RTL text.
6. **Big targets.** ≥ 48 dp everywhere, ≥ 56 dp in the driver app (used while parked, with
   gloves, in sunlight).

## Tokens (`packages/design-tokens/tokens.json` is the single source)

### Colour — light

| Token | Hex | Use |
|-------|-----|-----|
| `bg` | `#EEF2F8` | App background (soft blue-grey, like the references) |
| `surface` | `#FFFFFF` | Cards, sheets, inputs |
| `surface-muted` | `#F5F7FB` | Inner rows, disabled fields |
| `border` | `#E2E8F0` | 1 px dividers and input outlines |
| `text` | `#0F172A` | Primary text |
| `text-muted` | `#56627A` | Labels, secondary text (≥ 5.4:1 on `bg`, 6.1:1 on white) |
| `primary` | `#2563EB` | The single primary action, active tab, bus marker |
| `primary-soft` | `#EEF3FE` | Selected nav item, icon circles (primary text on it ≥ 4.6:1) |
| `on-primary` | `#FFFFFF` | Text on primary |
| `ink` | `#1E1B4B` | Strong dark buttons on the dashboard (navy from reference 2) |
| `success` | `#047857` | Assigned, active subscription, verified run |
| `warning` | `#B45309` | Waitlisted, expiring soon |
| `danger` | `#B91C1C` | Cancelled, rejected, errors |
| `female-only` | `#7C3AED` | Female-only bus badge (solid violet, not a stereotype pink) |

Each status colour also has a `*-soft` background; text in the status colour on its soft
background meets WCAG AA (≥ 4.5:1). This is checked by the Flutter accessibility test in
`packages/naql_ui/test/components_test.dart`.

Dark theme is defined later (P8) by swapping the same token names.

### Type

- Family: **IBM Plex Sans Arabic** (covers Arabic + Latin, excellent legibility); numbers use
  tabular figures so times do not jump.
- Scale (sp/px): `display 32/40 semibold` (time of pickup), `title 22/28 semibold`,
  `headline 18/24 semibold`, `body 16/24 regular`, `label 14/20 medium`, `caption 12/16 regular`.

### Shape, space, elevation

- Spacing: 4-pt grid → `4, 8, 12, 16, 20, 24, 32, 40`. Screen padding 20.
- Radius: `sm 10` (chips), `md 16` (inputs, rows), `lg 24` (cards, sheets), `pill 999` (buttons, nav).
- Elevation: one shadow only, `0 4 16 rgba(15,23,42,0.06)`. Cards on `bg` use it; nested cards don't.
- Motion: 200 ms ease-out for state changes, 280 ms for sheets. Respect reduce-motion.

## Key screens

**Student**
- *Home*: greeting + subscription chip at the top; one **Next ride card** (big pickup time,
  point → campus, bus chip, status). Primary button: "Request ride" or "Track bus".
- *Request sheet*: wave chips (like the date tabs in reference 1), gathering point row,
  price line, single confirm button.
- *Trip card* (reference 1, middle phone): `08:40 ── 🚌 ── 09:20`, point / campus underneath,
  driver + plate on the bottom row, status pill on the end.
- *Tracking*: full-screen muted map (custom MapLibre style: grey roads, no POI clutter), bus marker
  in `primary`, bottom card with ETA in `display` size and "updated 4 s ago".
- *Waitlist*: circular countdown + plain sentence "We'll notify you if a seat frees up".
- *Notifications*: list like reference 2; unread row has a `primary-soft` background, not a
  full-colour block.

**Driver**
- *Today*: run cards in order with time, wave, passenger count, female-only badge.
- *Run mode*: one huge contextual button at the bottom (Start → Arrived at stop → Continue →
  End run), stop list above it, passenger checklist per stop, "Navigate" opens Maps/Waze.
- *Cash fare*: two taps — choose passenger, confirm prefilled tier price.

**Dashboard (office / super admin)**
- Left (RTL: right) sidebar, white content cards on `bg`, dense but calm tables, map pages
  full-height. Navy `ink` for strong table actions, `primary` for the page's main action.

## Flutter — making it *not* look like a stock Flutter app

All UI lives in `packages/naql_ui`. Apps never use raw Material widgets for visible UI.

- `NaqlTheme` as a `ThemeExtension` generated from tokens; `ThemeData` only sets the basics.
- `splashFactory: NoSplash.splashFactory`, `highlightColor: transparent`. Press feedback is a
  custom `NaqlPressable` (scale to 0.97 + 8 % darken) with haptic tick.
- Own components: `NaqlButton`, `NaqlCard`, `NaqlField` (pill, label above), `NaqlChip`,
  `StatusPill`, `TripCard`, `NaqlBottomSheet` (24 radius, grab handle), `NaqlTopBar`
  (no Material AppBar elevation/tint), and a **floating pill bottom nav** with a solid blue
  circular active item (reference 1, first phone).
- Custom page transitions (shared-axis slide + fade, mirrored for RTL) and skeleton loaders
  instead of `CircularProgressIndicator`.
- Custom icon set (Phosphor or Lucide, 1.75 stroke) instead of Material icons.
- Every component has golden tests in LTR + RTL (T0-03) and a widget test forbidding ink splashes (T0-04).

## React dashboard

- Tailwind config reads the generated CSS variables; no hard-coded hex values (lint rule).
- Radix UI primitives (dialog, dropdown, tabs, toast) styled with our tokens, so they look
  custom and stay accessible. TanStack Table for tables, MapLibre GL with the same map style
  as the apps.
