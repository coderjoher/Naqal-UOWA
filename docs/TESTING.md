# Try Naql yourself

Everything up to **P6 (settlement)** works end to end: the office sets up the service, students
subscribe and request rides, the dispatcher puts them on buses, drivers run their routes with live
GPS, students and the office follow the buses on a map, and at month end the office computes,
approves and exports the driver payouts.

## 1. Start everything (one command)

You need [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Windows, macOS or Linux).

```bash
git clone https://github.com/coderjoher/Naqal-UOWA.git
cd Naqal-UOWA
docker compose up -d --build --wait
```

The first start takes **10–20 minutes**: it downloads the Iraq road map for OSRM and builds the
two Flutter apps. Later starts take seconds.

| What | Address |
|------|---------|
| Office dashboard | http://localhost:8080 |
| Student app (web) | http://localhost:8081 |
| Driver app (web) | http://localhost:8082 |
| API documentation | http://localhost:3000/docs |

**On your phone:** connect it to the same Wi-Fi as the computer and open
`http://<computer-ip>:8081` (student) or `:8082` (driver). Find the computer's IP with
`ipconfig` (Windows) or `ipconfig getifaddr en0` (macOS). Use "Add to home screen" for an app-like experience.

## 2. Demo accounts

Demo data is loaded automatically on the first start: Warith Al-Anbiyaa University, tiers A/B/C,
8 gathering points in Karbala, waves 08:00 / 10:00 (to campus) and 14:00 / 16:00 (home) every day,
6 approved drivers available all week, 40 students (half of the activated ones subscribed),
22 ride requests waiting for the next morning wave, and **last month already driven** (GPS-tracked
runs of three drivers, subscriptions and cash fares) so it can be settled.

| Role | Where | Sign in |
|------|-------|---------|
| Transport office | Dashboard | `office@uowa.edu.iq` / `password123` |
| Super admin | Dashboard | `admin@naql.app` / `password123` |
| Student | Student app | University **Warith**, student number `W-1001` … `W-1030`, password `student123` |
| New student (first sign-in) | Student app | "First time?" → `W-1031` … `W-1040`, code `246810`, choose a password |
| Driver | Driver app | Phone `07800000001` … `07800000006` — the sign-in code is shown on screen in demo mode |
| Driver applying | Driver app | Any other Iraqi mobile number, e.g. `07712345678` |

`W-1001` (female) and `W-1002` (male) have no requests yet, so they are good for trying the request flow.

## 3. Things to try

### A. Office: dispatch a wave
1. Dashboard → **التوزيع (Dispatch)**. The next morning wave shows 22 new requests.
2. Press **وزّع الآن (Dispatch now)**. Within a few seconds the buses appear: female-only and male
   buses are separate, stops are ordered, each with pickup time and riders.
   (Without pressing it, waves are dispatched automatically one hour before their time.)

### B. Student: request a ride and get a bus
1. Student app → sign in as `W-1001` / `student123`.
2. **اطلب رحلة (Request a ride)** → choose a time and a gathering point → **أرسل الطلب**.
3. If that wave is already dispatched, the bus appears within ~5 seconds: pickup time, driver,
   plate, stop number and what to pay. Otherwise press **Dispatch now** in the dashboard.
4. Fill a bus to see the **waitlist** with its countdown; cancel someone else's ride and watch the
   waiting student get the seat.
5. Cancel your own request from the card.

### C. Office: cash subscription → app updates by itself
1. Keep the student app open on `W-1001` (subscription card says "لا يوجد اشتراك").
2. Dashboard → **الاشتراكات** → student number `W-1001` → **تسجيل الدفع النقدي**.
3. Download the Arabic PDF receipt. The student app turns **اشتراك فعّال** within 5 seconds, and
   the next ride is free (or costs only the tier difference from a farther point).

### D. Driver: runs and schedule
1. Driver app → phone `07800000001` → the code is shown on screen → enter it.
2. **اليوم (Today)**: runs with departure time, stops, seats and cash to collect. Tap a run for
   the stop timeline and tap a stop to see who boards there.
3. **جدولي (Schedule)**: choose which waves you drive this week; dispatched waves are locked.

### E. Live: drive a run and watch it
1. Dispatch a wave (A), then sign in as the bus's driver in the driver app (Dispatch shows who).
2. Open the run: **ابدأ الرحلة** → **وصلت إلى المحطة** → tap riders as they board → **انطلق** …
   If a rider is missing, the bus must wait 3 minutes before it can leave (no-show, no penalty).
   Pay-per-ride riders show **استلمت 2,000 د.ع** — tap it when the cash is handed over.
3. In a browser the driver app cannot send GPS like a phone does, so to see buses move run the
   simulator, which drives every dispatched run of today along its stops:
   `docker compose exec api npx ts-node scripts/simulate.ts`
4. Watch it in the dashboard → **التشغيل المباشر**, and in the student app: the assignment card
   gets **تتبّع الحافلة** (map with the bus, ETA, "updated X ago"); the **الإشعارات** tab shows
   "seat confirmed", "bus is close", "bus is here".
5. Turn off Wi-Fi on a phone running the driver APK during a run, keep going, turn it back on: all
   points and actions arrive, nothing twice.

### F. Month end: settle the drivers
1. Dashboard → **التسوية الشهرية (Monthly settlement)**. Last month is selected.
2. **احسب التسوية (Compute settlement)**: subscription money per tier, commission, and one line per
   driver: runs counted, cash they collected, payout. Payout = share of the tier's subscriptions by
   GPS-verified runs after commission − commission on the cash they kept.
3. **رحلات تحتاج مراجعة (Runs to review)**: one run has a GPS jump and one was never finished, so
   neither counts. Press **قرّر** to count or exclude it with a reason, then recompute.
4. **اعتمد (Approve)**: the month is locked for good (even the database refuses changes). Download
   the Arabic **PDF** and the **Excel** file; their totals match the screen.
5. Driver app → sign in as `07800000001` → **الأرباح (Earnings)**: this month's estimate, the runs
   behind it, and last month once approved.
6. **سجل التغييرات (Audit log)**: the approval and every review decision, with before/after.
   Sign in as the super admin to see revenue and commission for every university on the overview,
   and change a university's commission to see it in the audit log.

### G. Office: onboarding
- **السائقون (Drivers)**: review the pending application (ياسر كاظم), open documents, approve or reject.
- **الطلبة (Students)**: import a roster (CSV) and issue activation codes.
- **الإعدادات (Settings)**: distance tiers and prices, gathering points on the map, waves, driver requirements.
- Switch to English with the button at the top.

## 4. Android APKs (optional)

GitHub → **Actions** → **Android test builds** → latest run → **Artifacts**:
`naql-student_app-apk`, `naql-driver_app-apk`. Install on a phone (allow "unknown sources").
On the welcome screen, tap the **server** button (top corner) and enter the computer's IP, e.g.
`192.168.1.20` — the apps then talk to your `docker compose` stack.

## 5. Reset or stop

```bash
docker compose down          # stop (data is kept)
docker compose down -v       # stop and delete all data; the next start loads fresh demo data
DEMO=false docker compose up -d --build --wait   # empty database, no codes shown on screen
```

## Not built yet

Push notifications to the phone's lock screen need a Firebase project (google-services.json and
an FCM service account) from the university; until then notifications show inside the apps.

| Coming in | What |
|-----------|------|
| P7 | Moving students between buses, extra runs, reports, announcements, ride history and ratings |
