# Platform limits

What Android does not let a normal (non-system) app do, and what Mobile Cloner does instead.

| Item | Limit | What we do |
|------|-------|------------|
| Installed apps | APKs (including splits) can be copied and installed with the user's confirmation, but each app's private data (`/data/data`) is unreachable without root. | Planned: send APKs and install via `PackageInstaller`; app data only where the app has its own backup (WhatsApp). |
| SMS / MMS | Reading needs `READ_SMS`; writing requires being the **default SMS app** while restoring. Play Store policy restricts these permissions. | Planned: ask the user to make Mobile Cloner the default SMS app during restore, then switch back. Likely a sideload-only feature. |
| WhatsApp on Android 11+ | `Android/media/com.whatsapp` belongs to WhatsApp; plain file APIs can't read or write it. | Storage Access Framework: the user grants the folder once in the system picker. Sideload builds can use All-files access instead. |
| Starting a WhatsApp backup | WhatsApp has no public intent to trigger a backup. | We show the age of the newest `msgstore` and open WhatsApp so the user taps Back up. |
| WhatsApp restore | WhatsApp only offers "Restore" on first setup with the same phone number. | After the transfer we tell the user to (re)install WhatsApp, verify the number and tap Restore. |
| Contacts | No limit, but formats vary by vendor. | We use Android's own vCard exporter and hand the file to the Contacts app to import. |
| Android 6 support | Flutter 3.35+ requires API 24. | Flutter is pinned to 3.32.8. |
