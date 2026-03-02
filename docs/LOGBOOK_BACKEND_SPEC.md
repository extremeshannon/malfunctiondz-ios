# Skydiver Logbook — Backend & DB Spec

This doc describes the database and API needed for the **skydiver logbook** feature used by the LMS (e.g. ASP – Alaska Skydiver Program). The iOS app already has the models and UI; the website and API need to implement this contract.

## Overview

- **Logbook** = per-student, per-course list of **jump entries**.
- Each entry corresponds to one **jump sign-off** (pass/repeat) and holds the fields from the printable logbook layout.
- **Two sign-off types** in the LMS (already present):
  1. **Clear to jump** (instructor_ready) – instructor has reviewed; student is ready to jump. Can be reflected in “Other training / comments” or a separate flag.
  2. **Jump** (jump_result) – the actual jump: pass or repeat (no “failed”), with full jump details and instructor signature.

- **Printable**: The logbook screen is designed so it can later be rendered to PDF (same layout).
- **Signature**: Phase 1 can store instructor name + license number + `signed_at`. Phase 2 can add a stored signature image/data and “lock” the entry when signed.

---

## Database

### Table: `skydiver_logbook_entries` (or equivalent)

| Column                     | Type         | Nullable | Description |
|----------------------------|-------------|----------|-------------|
| `id`                       | INT         | NO       | PK, auto-increment |
| `user_id`                  | INT         | NO       | Student (skydiver) |
| `course_id`                | INT         | NO       | LMS course (e.g. ASP) |
| `module_id`                | INT         | NO       | LMS module this jump belongs to |
| `jump_number`              | INT         | NO       | Sequential jump # (e.g. 1, 2, 3) |
| `dz`                       | VARCHAR(?)  | YES      | Drop zone name |
| `altitude`                 | VARCHAR(?)  | YES      | e.g. "13,500 ft" |
| `delay`                    | VARCHAR(?)  | YES      | Freefall delay |
| `date`                     | DATE/VARCHAR | YES     | Jump date |
| `aircraft`                  | VARCHAR(?)  | YES      | Aircraft type/id |
| `equipment`                | VARCHAR(?)  | YES      | Rig/equipment |
| `total_time`               | VARCHAR(?)  | YES      | Total freefall/time |
| `jump_type`                | VARCHAR(?)  | YES      | e.g. AFF, solo, tandem |
| `comments`                 | TEXT        | YES      | Comments (pass/repeat notes, etc.) |
| `result`                   | VARCHAR(20) | YES      | `pass` \| `repeat` (no “failed”) |
| `signed_by`                | VARCHAR(?)  | YES      | Instructor name |
| `instructor_license_number` | VARCHAR(?)  | YES      | Instructor license # |
| `signed_at`                | DATETIME    | YES      | When signed |
| `is_locked`                | TINYINT(1)  | NO       | 0/1 – locked after sign (no edits) |
| `created_at`                | DATETIME    | NO       | |
| `updated_at`                | DATETIME    | NO       | |

- Optional: link to `lms_signoff_requests` or equivalent (e.g. `signoff_request_id`) so one logbook row = one jump sign-off.
- Indexes: `(user_id, course_id)`, `(course_id, module_id)`, `user_id`.

### “Other training / comments”

- Either a separate table (e.g. `skydiver_logbook_notes`: `user_id`, `course_id`, `module_id?`, `notes` TEXT, `updated_at`) or a column on enrollment/course progress. iOS expects a single string per course: `other_training_notes`.

---

## API

### GET `/api/lms/logbook.php`

**Purpose:** Return logbook entries (and optional “other training / comments”) for a student in a course.

**Query:**

- `course_id` (required): LMS course id.
- `user_id` (optional): Student user id. If omitted, use the authenticated user (so students see their own logbook). Instructors can pass `user_id` to view a student’s logbook.

**Auth:** Bearer token (instructor or the student themselves).

**Response (JSON):**

```json
{
  "ok": true,
  "entries": [
    {
      "id": 1,
      "jump_number": 1,
      "dz": "Alaska Skydive Center",
      "altitude": "13500",
      "delay": "60",
      "date": "2025-03-01",
      "aircraft": "Cessna 182",
      "equipment": "Student rig",
      "total_time": "60",
      "jump_type": "AFF",
      "comments": "Pass. Good arch.",
      "result": "pass",
      "signed_by": "Jane Instructor",
      "instructor_license_number": "D-12345",
      "signed_at": "2025-03-01T14:30:00Z",
      "is_locked": true,
      "course_id": 1,
      "module_id": 1
    }
  ],
  "other_training_notes": "Clear to jump – 2025-02-28. Ground training completed."
}
```

- Snake_case keys match the iOS model `CodingKeys` (e.g. `jump_number`, `signed_at`, `instructor_license_number`, `other_training_notes`).
- If no entries: `entries: []`. If no notes: `other_training_notes: ""` or omit.

---

### POST `/api/lms/logbook.php` (create/update entry)

**Purpose:** Create a new logbook entry or update one (e.g. when instructor fills jump details and signs). Optional for Phase 1 if all sign-offs are done from the existing signoff flow and you create logbook rows there.

**Body (JSON):**

- `course_id`, `module_id`, `user_id` (student)
- Jump fields: `jump_number`, `dz`, `altitude`, `delay`, `date`, `aircraft`, `equipment`, `total_time`, `jump_type`, `comments`, `result` (`pass` | `repeat`)
- Signing: `signed_by`, `instructor_license_number`; server can set `signed_at` = now and `is_locked` = 1 when these are present.

**Auth:** Instructor (or admin) only.

**Response:** `{ "ok": true, "id": 123 }` or error.

---

### PATCH `/api/lms/logbook_notes.php` (optional)

**Purpose:** Set “Other training / comments” for a course/student.

**Body:** `course_id`, `user_id` (optional), `notes` (string).

**Auth:** Instructor or the student.

---

## Integration with existing LMS signoffs

- When an instructor completes a **jump_result** sign-off (existing `signoff.php` or equivalent), the backend should create or update a row in `skydiver_logbook_entries` with the jump details and set `result` = pass/repeat, `signed_by`, `instructor_license_number`, `signed_at`, `is_locked` = 1.
- “Clear to jump” (instructor_ready) can update `other_training_notes` or a separate “clear to jump” note used in the printable logbook.

---

## iOS usage

- **Models:** `SkydiverLogbook.swift` (`SkydiverLogbookEntry`, `SkydiverLogbookResponse`).
- **API:** `GET /api/lms/logbook.php?course_id=<id>` (and optional `user_id`). Decodes into `SkydiverLogbookResponse`; empty or 404 is treated as empty logbook.
- **UI:** Ground School → course → **Logbook** → list of entries (printable-style) + “Other training / comments” at bottom. No create/edit in app yet; that can be added when the backend supports POST and, later, signature-on-phone.

---

## Summary

1. Add table `skydiver_logbook_entries` (and optionally a store for “other training / comments”).
2. Implement `GET /api/lms/logbook.php?course_id=&user_id=` returning `{ ok, entries, other_training_notes }`.
3. When instructor signs off a jump (existing flow), insert/update a logbook entry and set signature fields and `is_locked`.
4. (Optional) Add POST for logbook entry create/update and an endpoint for “other training / comments” so the app or website can edit them later.
