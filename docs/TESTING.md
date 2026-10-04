# Try Naql yourself

Everything up to **P4 (ride requests and dispatch)** works end to end: the office sets up the
service, students subscribe and request rides, the dispatcher puts them on buses, and drivers see
their runs. Live bus tracking, push notifications and driver settlement come in P5–P6.

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
6 approved drivers available all week, 40 students (half of the activated ones subscribed) and
22 ride requests waiting for the next morning wave.

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

### E. Office: onboarding
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

| Coming in | What |
|-----------|------|
| P5 | Live bus map and ETA, driver "start run / boarded / no-show", push notifications, live operations map |
| P6 | Driver earnings and monthly settlement, money reports, super-admin revenue |
| P7 | Moving students between buses, extra runs, reports, announcements |
