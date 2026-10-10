Page structure and navigation flow of the three user-facing frontends:
- Dashboard (React 19 + react-router, BrowserRouter) for office staff and super admins.
- Student app (Flutter + go_router, Riverpod-driven redirects), map-first hub without a tab bar.
- Driver app (Flutter + go_router), status-gated onboarding then a 4-tab StatefulShellRoute.
The apps never link to each other directly; edges show where an action on one surface changes what another surface shows (through the API and Socket.IO).
