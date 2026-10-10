Per-process, non-shared caches inside each API cluster worker (lost on restart, never authoritative):
- userCache / TokenCache (apps/api/src/auth/user-cache.ts, NF-06): auth guard's user lookup (id, role, universityId, status) for AUTH_CACHE_MS (default 10 s, 0 disables) and verified JWT payloads until exp; suspension is forgotten at once on the process that made it, within 10 s elsewhere.
- officeViews SwrCache (apps/api/src/common/swr-cache.ts): 5 s stale-while-revalidate cache for heavy office read models (ops board, wave views), invalidated by dispatch, rides, runs and waves services.
- LiveService route cache (apps/api/src/live/live.service.ts): run stops, riders and travel legs for 15 s per run.
- FCM OAuth access token (apps/api/src/notifications/push.ts) until shortly before expiry.
