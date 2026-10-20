# Architecture

```
app/ (Flutter)                          packages/cloner_core/ (pure Dart)
  ui/phone, ui/desktop  ─┐                protocol/   LocalSend v2 DTOs + Cloner extension
  services/ClonerService ├──────────────▶ discovery/  multicast, subnet scan, QR pairing, ADB bridge
  sources/ (media, contacts, WhatsApp)    server/     HTTPS receiver, sessions, resume offsets
  restore/ (MediaStore, SAF, journal)     client/     pinned-TLS client
  platform/AndroidBridge ── Kotlin        transfer/   SendJob (parallel, retries, resume), checkpoint, speed
                                          migration/  categories, WhatsApp layout, restore planner, safe paths
                                          storage/    backup store + manifest, file writer
```

## Transfer

LocalSend v2 (`/api/localsend/v2/*`): `register` for discovery, `prepare-upload` to propose files,
`upload` per file. Every device runs the HTTPS server; the sender is the HTTP client.

TLS uses a self-signed RSA certificate per device. Its SHA-256 is the device fingerprint, announced over
multicast or carried in the pairing QR code, and the client pins it on connect.

### Cloner extension

Extra fields LocalSend ignores, plus routes under `/api/cloner/v1`:

- `info.cloner`: platform, Android `sdkInt`, capabilities.
- `file.cloner`: `category` (photos, whatsapp, ...), `relPath` (logical path inside the category), `takenAt`, `album`.
- `prepare-upload` response `cloner.offsets`: bytes the receiver already holds per file; `upload?offset=N` appends.
  A wrong offset gets `416` with the real one.
- `POST /api/cloner/v1/status`: heartbeat both ways with battery, charging, free space.
- `POST /api/cloner/v1/finish`: end of session with a per-category summary; receiver post-processes.

### Resume

- File ids are stable (`sha1(category|relPath|size|mtime)`), so a new session after a restart lines up.
- Receivers write `<name>.part` and rename on commit; partial data stays for the next attempt.
- The sender's `TransferCheckpoint` (done ids, peer fingerprint, last address, interrupt reason) is saved
  with write-then-rename after each file and every 2 s.
- The phone receiver keeps a journal of restored ids per sender so nothing is inserted twice into the gallery.
- A sender reconnecting with the same fingerprint takes over its own stale session, which is how a
  transfer moves from Wi-Fi to cable.
- The heartbeat interrupts the job when either battery is critical (5%, not charging); 15% raises a warning.

## WhatsApp mapping

| | Android 10 and older (API ≤ 29) | Android 11+ (API ≥ 30) |
|---|---|---|
| WhatsApp | `/sdcard/WhatsApp` | `/sdcard/Android/media/com.whatsapp/WhatsApp` |
| WhatsApp Business | `/sdcard/WhatsApp Business` | `/sdcard/Android/media/com.whatsapp.w4b/WhatsApp Business` |

The sender sends paths relative to the WhatsApp folder; the receiver picks its root by its own API level
(`WhatsAppLayout.rootFor`). Scopes: "chats only" (`Databases`, `Backups`) or full (minus `.Shared`,
`.trash`, `.Thumbs`, `.StickerThumbs`, `.Statuses`).

## Connections

| Mode | How peers find each other |
|------|---------------------------|
| Same Wi-Fi | Multicast 224.0.0.167:53317, HTTP register reply |
| Hotspot | Receiver starts a local-only hotspot; SSID/password in the QR; scanner joins via `WifiNetworkSpecifier` |
| USB cable phone-to-phone | USB tethering creates a link; QR code or /24 subnet scan |
| Computer over USB | Desktop runs `adb reverse tcp:53319 tcp:53320` and `adb forward tcp:53318 tcp:53320`; 53320 is a plain-HTTP listener bound to 127.0.0.1 only |

## Performance

- Files are read in 1 MB blocks (vs 64 KB), one socket write each.
- Five upload lanes, at most two of them on large files (8 MB+). Small files are latency bound, so the
  extra lanes keep the link busy; large files would only split it.
- Over the ADB cable, TLS is skipped: the loopback listener is not reachable from the network, and TLS is
  the main CPU cost.

Measured in the container (separate AOT processes):

| Case | Before | After |
|------|--------|-------|
| 1,500 × 300 KB, loopback | 54 MB/s | 65 MB/s |
| 1,500 × 300 KB, 6 ms RTT (Wi-Fi-like) | 35 MB/s | 43 MB/s |
| 3 × 150 MB, HTTPS | 65 MB/s | 67 MB/s |
| 3 × 150 MB, cable path (plain HTTP) | 67 MB/s | 465 MB/s |

Real links cap lower: USB 2 ADB ~35-40 MB/s, Wi-Fi 5 ~30-60 MB/s.
