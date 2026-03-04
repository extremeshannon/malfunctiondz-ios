# iOS Prompt: Calendar, Events, and Staff Shifts

**Context:** This prompt is for Cursor on Mac, working on the Alaska Skydive Center iOS app. The backend APIs are already built and running. You need to add calendar views (events + shifts) and integrate with the existing auth/push setup.

---

## Backend Base URL

- **Dev:** `https://your-dev-domain.local/api` or `http://localhost:8080/api`
- **Production:** `https://your-vps-domain.com/api`

All endpoints below are relative to that base (e.g. `/api/calendar/events.php`).

---

## Authentication

The app already uses API token auth. After login:

- **Login:** `POST /api/login.php`  
  Body: `{"username": "...", "password": "..."}`  
  Response: `{"ok": true, "token": "…", "user": {...}, "domains": [...]}`

- **Auth header for all protected endpoints:**  
  `Authorization: Bearer {token}`

- Store the token and send it on every request that requires login.

---

## 1. Events Calendar (public, no auth)

**Endpoint:** `GET /api/calendar/events.php?from=YYYY-MM-DD&to=YYYY-MM-DD`

- No `Authorization` header needed.
- Returns only **public** events (shown on the website too).

**Response:**
```json
{
  "ok": true,
  "events": [
    {
      "id": 1,
      "title": "Spring Boogie",
      "description": "Annual spring boogie...",
      "event_date": "2025-04-15",
      "start_time": "09:00:00",
      "end_time": "17:00:00",
      "location": "Palmer DZ",
      "is_public": 1,
      "notify_push": 0
    }
  ]
}
```

**iOS tasks:**
- Add an **Events** screen that fetches events for a date range (e.g. current month ±1).
- Display in a calendar-style or list view.
- Allow tapping an event to see details (title, date, time, location, description).
- Pull-to-refresh.

---

## 2. Staff Shifts (auth required)

### 2a. List Shifts

**Endpoint:** `GET /api/calendar/shifts.php?from=YYYY-MM-DD&to=YYYY-MM-DD`  
**Auth:** Bearer token required.

**Response:**
```json
{
  "ok": true,
  "shifts": [
    {
      "id": 1,
      "shift_date": "2025-03-15",
      "position_key": "pilot",
      "slot_key": "half_am",
      "user_id": null,
      "status": "available",
      "full_name": null,
      "first_name": null,
      "last_name": null
    },
    {
      "id": 2,
      "shift_date": "2025-03-15",
      "position_key": "manifest",
      "slot_key": "full",
      "user_id": 5,
      "status": "approved",
      "full_name": "Jane Doe",
      "first_name": "Jane",
      "last_name": "Doe"
    }
  ]
}
```

**Position keys:** `pilot`, `tandem_instructor`, `packer`, `manifest`, `videographer`, `aff_instructor`, `coach`, `truck_driver`, `rigger`

**Slot keys:** `half_am` (8am–12pm), `half_pm` (12pm–6pm), `full` (8am–6pm)

**Status values:**
- `available` — Open, no one assigned
- `pending` — Someone claimed it, awaiting Ops approval
- `approved` — Locked to assigned staff
- `release_requested` — Assigned staff asked to be released

**Display rules:**
- `available`: Show "Open" and a **Pick** button (only if user has matching role — see 2b)
- `pending`: Show assignee name + "(pending)"
- `approved`: Show assignee name; if it's the current user's shift, show **Request Release**
- `release_requested`: Show assignee name + "(release requested)"

**Role-to-position:** User can only pick shifts for positions they have the role for. Roles match 1:1: `pilot`, `tandem_instructor`, `packer`, `manifest`, `videographer`, `aff_instructor`, `coach`, `truck_driver`, `rigger`. Use the `roles` array from the login/user response to decide if "Pick" is shown.

### 2b. Claim Shift

**Endpoint:** `POST /api/calendar/shift_claim.php`  
**Auth:** Bearer token required.  
**Body:** `{"shift_id": 1}` (JSON)

**Success:** `{"ok": true, "message": "Shift claimed, pending approval"}`  
**Errors:** 403 (wrong role or not available), 409 (no longer available)

### 2c. Request Release

**Endpoint:** `POST /api/calendar/shift_request_release.php`  
**Auth:** Bearer token required.  
**Body:** `{"shift_id": 1}` (JSON)

Only works for shifts where the current user is the assigned staff and status is `approved`.

**Success:** `{"ok": true, "message": "Release requested"}`  
**Error:** 403 (not your shift or wrong status)

---

## 3. Push Notifications (auth required)

**Endpoint:** `POST /api/push/register.php`  
**Auth:** Bearer token required.  
**Body:**
```json
{
  "device_token": "…",
  "platform": "ios"
}
```

- Call after successful login (and whenever the token changes).
- Use the device token from `UNUserNotificationCenter` / `didRegisterForRemoteNotificationsWithDeviceToken`.
- `platform` defaults to `"ios"` if omitted.

**Success:** `{"ok": true}`

---

## 4. iOS Implementation Summary

**Add or extend:**

1. **Events screen** — Fetch from `/api/calendar/events.php`, display in list or calendar. No auth.
2. **Shifts screen** — Fetch from `/api/calendar/shifts.php`, show date picker or week view. Group by date and position/slot.
3. **Pick button** — On available shifts where user has matching role → POST to `/api/calendar/shift_claim.php`.
4. **Request Release button** — On approved shifts owned by current user → POST to `/api/calendar/shift_request_release.php`.
5. **Push registration** — After login, register device token with `/api/push/register.php`.

**UX notes:**
- Shifts are read-only for everyone; staff can only pick available shifts and request release from their own.
- Ops Manager approve/deny is web-only, not in the iOS app.
- Show clear feedback when claiming (e.g. "Pending approval") and when requesting release.

---

## 5. Error Handling

All API responses use:

- `{"ok": true, ...}` — Success
- `{"ok": false, "error": "message"}` — Failure

HTTP status codes: 400 (bad request), 401 (not authenticated), 403 (forbidden), 404, 409 (conflict), 422 (validation).

---

## 6. Slot Labels (for display)

| slot_key | Label        | Time      |
|----------|--------------|-----------|
| half_am  | Half Day AM  | 8am–12pm  |
| half_pm  | Half Day PM  | 12pm–6pm  |
| full     | Full Day     | 8am–6pm   |

## 7. Position Labels (for display)

| position_key      | Label           |
|-------------------|-----------------|
| pilot             | Pilot           |
| tandem_instructor | Tandem Instructor |
| packer            | Packer          |
| manifest          | Manifest        |
| videographer      | Videographer    |
| aff_instructor    | AFF Instructor  |
| coach             | Coach           |
| truck_driver      | Truck Driver    |
| rigger            | Rigger          |
