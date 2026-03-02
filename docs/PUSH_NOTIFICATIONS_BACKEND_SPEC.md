# Push Notifications — Backend Spec (Notify Instructor)

The iOS app registers for push notifications and sends the device token to the backend. When a student taps **"Notify Instructor I'm Ready"** in Ground School, the backend should send a push notification to all instructors (and optionally chief pilot / ops) so they see it on their devices or when they next open the app.

## iOS app behavior

- After login (and on app launch when the user is already logged in), the app requests notification permission and calls `registerForRemoteNotifications()`.
- When Apple returns a device token, the app sends it to the backend via **POST `/api/push/register.php`** (see below).
- **Xcode:** You must enable **Push Notifications** in the app target: **Signing & Capabilities → + Capability → Push Notifications.** You also need an Apple Developer account and an APNs key or certificate for production.

## Backend: store device tokens

### POST `/api/push/register.php`

**Purpose:** Store or update the current user’s device token for push notifications.

**Headers:** `Authorization: Bearer <token>`

**Body (JSON):**
```json
{
  "device_token": "<hex string from APNs>",
  "platform": "ios"
}
```

**Backend should:**
- Identify the user from the Bearer token.
- Store the mapping `user_id → device_token` (and optionally `platform`) in a table, e.g. `push_tokens` (`user_id`, `device_token`, `platform`, `updated_at`). Replace any existing token for that user (or that user + platform) so each user has one current token per device type.

**Response:** `{ "ok": true }` or error.

## Backend: send push when student requests sign-off

When a student submits a sign-off request (e.g. **"Notify Instructor I'm Ready"** or **"Request Jump Sign-Off"**), the existing LMS signoff API (e.g. `POST /api/lms/signoff.php`) should:

1. Create or update the pending sign-off record as it does now.
2. **Notify instructors:** Look up all users with instructor (or lms_instructor) role — and optionally chief pilot / ops — and get their stored `device_token` values from `push_tokens`.
3. **Send a push** via Apple Push Notification service (APNs) to each token. Payload can be minimal, e.g.:
   - **title:** "Sign-off requested"
   - **body:** "A student is awaiting your sign-off" (or include student name / course if desired)
   - **data:** optional `course_id`, `module_id`, or `pending_count` for deep linking later.

Use HTTP/2 APNs API with your app’s bundle ID and APNs key (or certificate). If a token returns 410 (Unregistered) or 400 (BadDeviceToken), remove that token from your database.

## Summary

| Item | Action |
|------|--------|
| **iOS** | Registers for push, sends token to `POST /api/push/register.php` after login. |
| **Backend** | Implements `register.php` to store `user_id` + `device_token` (+ platform). |
| **Backend** | When sign-off is requested, loads tokens for instructors (and optionally chief pilot/ops), sends push via APNs. |
| **Xcode** | Add **Push Notifications** capability; configure APNs in Apple Developer portal. |

Instructors will receive the push when the app is in the background or closed; when they open the app they already see the **Students awaiting check-offs** section on the dashboard and can tap through to Ground School.
