# Privacy Policy — Yuvomi for iOS

**Last updated:** 2026-08-10

Yuvomi for iOS (“the App”) is an open-source native client for the [self-hosted Yuvomi](https://github.com/ulsklyc/yuvomi) family planner.

## Who we are

This client is maintained as a community open-source project. There is **no Yuvomi vendor cloud** operated by this app.

## Data we process

- **Server URL** you enter (so the app can connect to *your* instance).
- **Credentials you choose**: API token and/or session material for that server.
- **Household data** returned by your server (tasks, calendar, shopping, health, documents, etc.).

All of that data is sent only to the **base URL you configure**. The App does not sell data, run ads, or include third-party analytics SDKs in the default open-source build.

## Storage on device

- Auth material is stored in the **iOS Keychain** when available, with a local file fallback if Keychain is unavailable.
- A **read cache** of recently fetched lists may be stored in Application Support for offline viewing.
- Downloaded documents may be written temporarily for Quick Look preview.

## Notifications

If you allow notifications, the App schedules **local notifications** on this device for pending reminders fetched from your server. No Apple Push Notification service (APNs) relay is required for that feature.

## Apple Health (HealthKit)

If you opt in, the App can **read** selected vital types from Apple Health on this device (for example weight, blood pressure, glucose, SpO₂, heart rate) and upload them to **your** Yuvomi server as private health vitals for the signed-in member. The App does not sell Health data. You can revoke access in iOS Settings → Health → Data Access & Devices.

## Account deletion

Accounts and household data live on **your Yuvomi server**. Use the web app (or server admin tools) to remove members or wipe data. Signing out of the iOS app clears local credentials and cache on this device.

## Children

The App is a general household tool. Health-related features are not medical devices. Configure visibility and parental controls on your server as appropriate for your household.

## Contact

Open an issue on the project repository: [github.com/ajthom90/yuvomi-ios](https://github.com/ajthom90/yuvomi-ios).

## Changes

We may update this policy as the App evolves. Material changes will be reflected in this file and the app version notes.
