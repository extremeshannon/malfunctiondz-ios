# MalfunctionDZCore

Swift Package — **single source of truth** for networking, auth, theming, and shared UI primitives used by:

- **Staff / operations** iOS app (full manifest, aircraft, LMS, etc.)
- **Alaska Skydive Center** member app (slim shell; same backend)

Both apps depend on this package as a **local** Swift package (`Packages/MalfunctionDZCore`). Same backend, same credentials; each app has its own bundle ID and keychain namespace (derived from `Bundle.main.bundleIdentifier`).

## Adding the ASC app target

1. Duplicate the staff app target in Xcode.
2. Set bundle ID, display name, and App Icon.
3. Link **MalfunctionDZCore** (already a dependency — same as staff).
4. Build a slim root UI; keep all API calls in this package or call through thin view models.

## Tests

```bash
cd Packages/MalfunctionDZCore && swift test
```

(Requires Swift toolchain; full UI flows are tested in the app targets.)
