go_router configuration of the driver app (apps/driver_app/lib/router.dart, `routerProvider`, initialLocation /today). The redirect is re-evaluated on changes of applicationProvider and isTaxiDriverProvider:
- application loading -> /splash; no application (signed out) -> onboarding (/welcome, /university, /phone, /code)
- DriverStatus.draft -> /apply; pending or suspended -> /status; rejected -> /status (may open /apply to resubmit)
- approved -> leaving onboarding/apply/status lands on /today
- taxi drivers (P10) are redirected from /schedule and /run/* to /today.
Approved drivers live in a 4-branch StatefulShellRoute.indexedStack with a floating NaqlTabBar; /run/:id sits outside the shell so the road screen has no tab bar.
