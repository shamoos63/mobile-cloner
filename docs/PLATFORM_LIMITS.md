# Platform limits

What Android does not let a normal (non-system) app do, and what Mobile Cloner does instead.

| Item | Limit | What we do |
|------|-------|------------|
| Installed apps | APKs (including splits) can be copied and installed with the user's confirmation, but each app's private data (`/data/data`) is unreachable without root. | The user picks apps; each moves as its base APK plus split APKs and is installed with a `PackageInstaller` session (Android confirms every app, "Install unknown apps" must be on). From a computer backup over USB, `adb install-multiple`. App data and sign-ins stay behind, except where the app has its own backup (WhatsApp). Splits made for the old phone's CPU or screen can fail on a very different phone (`INSTALL_FAILED_NO_MATCHING_ABIS`); the app is then reported, not installed. |
| SMS / MMS | Reading needs `READ_SMS`; writing requires being the **default SMS app** while restoring. Play Store policy restricts these permissions. | Planned: ask the user to make Mobile Cloner the default SMS app during restore, then switch back. Likely a sideload-only feature. |
| WhatsApp on Android 11+ | `Android/media/com.whatsapp` belongs to WhatsApp; plain file APIs can't read or write it. | Storage Access Framework: the user grants the folder once in the system picker. Sideload builds can use All-files access instead. |
| Starting a WhatsApp backup | WhatsApp has no public intent to trigger a backup. | We show the age of the newest `msgstore` and open WhatsApp so the user taps Back up. |
| WhatsApp restore | WhatsApp only offers "Restore" on first setup with the same phone number. | After the transfer we tell the user to (re)install WhatsApp, verify the number and tap Restore. |
| Contacts | No limit, but formats vary by vendor. | We use Android's own vCard exporter and hand the file to the Contacts app to import. |
| Android 6 support | Flutter 3.35+ requires API 24. | Flutter is pinned to 3.32.8. |

## Package visibility (Android 11+)

Listing installed apps needs `QUERY_ALL_PACKAGES`. Sideloaded builds can use it freely; a Play Store release must justify it under Google's policy (device-transfer apps are an accepted use), or fall back to a `<queries>` block for the launcher intent, which only lists apps that have a launcher icon.

