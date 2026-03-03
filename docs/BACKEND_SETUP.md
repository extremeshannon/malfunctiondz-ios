# Backend Setup Guide — MAMP / Local

This guide covers running the Platform PHP backend locally with MAMP so the MalfunctionDZ iOS app can connect to it.

---

## 1. Prerequisites

- **MAMP** (or MAMP Pro) installed — provides Apache + PHP + MySQL
- **Platform repo** cloned (e.g. `git clone git@github.com:extremeshannon/platform.git` into your workspace)
- **MalfunctionDZ** iOS app (expects API at `kServerURL` — change for local: see §5)

---

## 2. MAMP Configuration

### Document root

Point MAMP’s document root to the Platform **public** folder:

- **Path:** `.../platform/app/public`
- Example: `/Users/shannon/Desktop/Projects/MalfunctionDZ/platform/app/public`

So URLs like `http://localhost:8888/api/login.php` resolve to `app/public/api/login.php`.

### MySQL

- Start MySQL in MAMP.
- Create a database (e.g. `platform`).
- Default MAMP MySQL: host `localhost`, port `3306`, user `root`, password `root`.

---

## 3. Database Connection (MAMP vs Docker)

The app reads DB settings from **environment variables** first, then `app/shared/config/config.php`.

**For MAMP**, edit `platform/app/shared/config/config.php`:

```php
return [
  'env' => 'local',
  'db' => [
    'host' => '127.0.0.1',   // or 'localhost'
    'port' => 3306,
    'name' => 'platform',
    'user' => 'root',
    'pass' => 'root',
    'charset' => 'utf8mb4',
  ],
];
```

`Db::connect()` falls back to this config when env vars are unset (typical for MAMP).

---

## 4. Migrations

Run migrations so tables exist (including `skydiver_logbook_entries`, `skydiver_logbook_notes`, `skydiver_logbook_settings`, `push_tokens`):

```bash
cd platform
php app/database/migrate.php
```

The migrate script uses the same config as the app (env vars first, then `config.php`). Ensure `config.php` has the right DB values before running.

---

## 5. iOS App — Point to Local Backend

For local testing, change the server URL in the iOS app:

- **File:** `MalfunctionDZ/App/Foundation.swift`
- **Variable:** `kServerURL` (or equivalent)
- **Local value:** `http://localhost:8888` (or your MAMP port, e.g. `8888`)

If you use `http://`, you may need to allow arbitrary loads in `Info.plist` (App Transport Security) for local HTTP.

---

## 6. API Endpoints Used by the App

| Endpoint | Purpose |
|----------|----------|
| `GET /api/config.php` | App config (dz name, module labels) — no auth |
| `POST /api/login.php` | Login (returns token) |
| `GET /api/me.php` | Current user — Bearer |
| `GET /api/lms/logbook.php?course_id=X` | Logbook entries (course_id optional for standalone) — Bearer |
| `GET/POST /api/lms/logbook_settings.php` | Prior jump count — Bearer |
| `POST /api/lms/logbook_add.php` | Add jump entry (skydivers only, 25+ jumps) — Bearer |
| `POST /api/push/register.php` | Store device token — Bearer |

---

## 7. Summary Checklist

- [ ] MAMP running (Apache + MySQL)
- [ ] Document root = `platform/app/public`
- [ ] Database `platform` created in MySQL
- [ ] `config.php` updated for MAMP MySQL (host `127.0.0.1`, user/pass)
- [ ] Migrations run (`php app/database/migrate.php`)
- [ ] iOS `kServerURL` set to `http://localhost:8888` for local testing
- [ ] ATS allows local HTTP if needed
