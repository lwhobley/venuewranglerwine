# Venue clock geofence

New venue setup requires the full address, confirmed address coordinates and a
radius from 1 to 1,000 feet (default 1,000). Android/iOS/macOS address lookup
uses the platform geocoder. Web/Windows/Linux setup accepts confirmed coordinates
manually. Address changes clear the previous lookup. Review the center before
creating the venue. Venue creation and initial boundary configuration are atomic.

For an existing venue, use **People → Scheduling & time clock → Settings →
Scheduling rules** to set the address, latitude, longitude and radius.
Only users with `schedule.settings` can change the boundary. Configuration
changes use the existing revision checks and audit history.

Both clock-in and clock-out request one foreground location fix and enforce the
boundary in the authenticated server command. No background location stream is
started. Missing configuration, missing location, invalid coordinates, mocked
fixes, timestamps older than 90 seconds or more than 15 seconds in the future,
and insufficient accuracy are rejected. The accuracy circle must fit inside the
boundary. The radius is converted using exactly 0.3048 metres per foot.

Denied location permission or an out-of-boundary punch does not silently create
attendance. Staff can still report a missed/offline punch; a manager must review
the claim and apply a separately audited correction. Break actions are unchanged.
Reported device coordinates are not hardware-attested; this is a proximity check
and does not prevent a modified client from fabricating its GPS payload.

## Verification on September 29, 2026

- 23 focused Flutter location/workforce/navigation tests passed; focused analysis
  is clean. Final location error handling was checked with the location tests.
- The actual SQL checker passed isolated local PostgreSQL tests for distance,
  the 1,000-foot cap, missing/stale/mock locations, uncertain edge fixes and
  unconfigured venues. The temporary database server was stopped afterward.
- Migration `clock_geofence` deployed to `aqhxbvaeuenqoljwwfcw`. Read-only checks
  verify installation and helper privileges. One existing venue needs configuration.
- The production-wide workforce rollback regression was rejected by automatic
  approval review due to temporary admin/auth records and its write volume. It
  did not run. The new integration fixtures are included in local database CI.
- Physical GPS, native address lookup, new venue setup and in/out punches have
  not yet been exercised on a phone with this version. No new APK/iOS build was
  installed in this change.

References: [location plugin](https://pub.dev/packages/geolocator),
[platform address lookup](https://pub.dev/packages/geocoding).
