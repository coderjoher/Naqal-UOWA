go_router configuration of the student app (apps/student_app/lib/router.dart, `routerProvider`). initialLocation is /home; a global `redirect` re-evaluated on every change of authProvider or universitySlugProvider decides where the user may be:
- auth still loading -> /splash
- signed out -> onboarding routes only (/welcome, /university, /sign-in, /activate); /sign-in and /activate require a chosen university first
- signed in without defaultPoint -> /choose-point
- otherwise onboarding/splash/choose-point bounce to /home.
Home is a map-first hub with no tab bar: every other screen is pushed on top of it and returns to it.
