# iOS API parity matrix (app ↔ FastAPI ↔ legacy PHP)

One-page reference: which **iOS** paths are implemented in **`platform/platform-py` (FastAPI)**, which exist only as **legacy PHP** under `platform/legacy/app/public/api/`, and production routing notes.

**Legend:** ✅ FastAPI | ⚠️ Partial / stub | ❌ Not in FastAPI (PHP or missing)

| iOS / client path | FastAPI | Legacy PHP | Notes |
|-------------------|---------|------------|-------|
| `POST /api/login(.php)` | ✅ `auth.py` | ✅ | MFA step: `POST /api/login/mfa(.php)` |
| `GET /api/me(.php)` | ✅ `me.py` | ✅ | |
| `GET /api/config(.php)` | ✅ `config.py` | ✅ | |
| `GET /api/roles(.php)` | ✅ `config.py` | ✅ | Auth required |
| `GET /api/users(.php)` | ✅ `users_api.py` | ✅ | |
| `GET /api/user(.php)?id=` | ✅ `users_api.py` | ✅ | Compatibility GET added |
| `PUT /api/user(.php)?id=` | ✅ `users_api.py` | ✅ | Profile fields (matches iOS save) |
| `GET /api/user_roles(.php)?id=` | ✅ `users_api.py` | ✅ | |
| `PUT /api/user_roles(.php)?id=` | ✅ `users_api.py` | ✅ | Role list replace |
| `PATCH /api/users/{id}(.php)` | ✅ `users_api.py` | — | Alternative to PUT user + PUT user_roles |
| `POST /api/user_send_reset.php` | ⚠️ stub `users_api.py` | ✅ | Stub OK message if no mailer |
| `GET /api/users/jump_check.php` | ✅ `users_api.py` | ✅ | Ops/admin jump counts |
| `GET /api/calendar/events(.php)` | ✅ `calendar_events_api.py` | ✅ | |
| `GET /api/calendar/shifts(.php)` | ✅ `calendar_shifts_api.py` | ✅ | |
| `POST /api/calendar/shift_claim(.php)` | ✅ | ✅ | |
| `POST /api/calendar/shift_request_release(.php)` | ✅ | ✅ | |
| `GET /api/dz/status` / `.php` | ✅ `dz_status_api.py` | ✅ | |
| `POST/PUT /api/dz/status_update` / `.php` | ✅ | ✅ | |
| `POST /api/push/register` / `.php` | ✅ `push_api.py` | ✅ | |
| `GET /api/push/notifications` / `.php` | ✅ `push_api.py` (broadcast log) | ✅ `push/notifications.php` | Same global history as PHP; empty if table missing |
| `GET /api/aircraft/list(.php)` | ✅ `aircraft_api.py` | ✅ | |
| `GET /api/aircraft/summary(.php)` | ✅ | ✅ | |
| `GET /api/aircraft/squawks(.php)` … | ✅ | ✅ | |
| `POST /api/aircraft/flight_start(.php)` | ✅ | ✅ | |
| `GET /api/aircraft/flights.php` | ✅ `pax_ios_api.py` | ✅ | Pax state: `get_pax_state` |
| `GET /api/aircraft/pilots.php` | ✅ | ❌ | Was missing in repo; added FastAPI |
| `POST /api/aircraft/flight_log.php` | ✅ | ❌ | One-shot closed flight log |
| `POST /api/aircraft/load_add/delete.php` | ✅ | ✅ | |
| `POST /api/aircraft/flight_close.php` | ✅ | ✅ | |
| `GET /api/flights/today.php` | ✅ `flights_ios_api.py` | ✅ | |
| `GET /api/flights/my_flights.php` | ✅ | ✅ | |
| `GET /api/loft/list(.php)`, `/loft/rigs(.php)` | ✅ `loft_api.py` | ✅ | |
| `GET/POST /api/loft/dz_rigs(.php)` | ✅ `loft_api.py` + service | ✅ | Uses `dz_rigs_ios_service.py` |
| `GET /api/lms/*` (courses, my_courses, quiz manage, …) | ✅ `lms_api.py`, `lms_ios_api.py` | ✅ | |
| `GET /api/lms/pending_signoffs.php` | ✅ `lms_api.py` | ✅ | |
| `GET/POST /api/lms/quiz.php?id=` | ✅ `lms_api.py` | ✅ | iOS: strip `is_correct` on GET |
| `GET /api/lms/logbook*.php`, rigs, … | ✅ `lms_ios_api.py` (included in `main.py`) | ✅ | |
| `GET /api/weather/metar(.php)` | ✅ `weather_api.py` | ✅ | |
| `GET /api/checkin/status(.php)` | ✅ `checkin_api.py` | — | `.php` aliases added |
| `POST /api/checkin(.php)` | ✅ | — | |
| `GET /api/checkin/eligible-users(.php)` | ✅ maps to list semantics | ✅ | Aliased for iOS |
| `GET /api/pilots/profile.php`, `upload.php` | ❌ | ⚠️ | Not implemented in this pass |

**Production routing:** If nginx sends `/api/*.php` only to PHP-FPM, FastAPI routes that omit `.php` still work when traffic hits uvicorn. Prefer routing **all `/api/*`** to FastAPI when PHP is retired; keep `.php` duplicates on FastAPI for compatibility (already pattern in routers).

**Multi-tenant:** FastAPI uses `X-Dropzone-Slug` / default dropzone. iOS does not send the header; single-DZ installs are fine.
