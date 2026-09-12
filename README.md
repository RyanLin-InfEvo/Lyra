<!--
SPDX-FileCopyrightText: 2026 Tzu-Ting Lin

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Lyra

> Group covers, remixes, and audio qualities cleanly, deduplicate files, and stream lossless audio via LAN straight to AirPlay & HEOS amps. Cross-platform.

---

Lyra is a digital audio asset manager and music player built for people who actually care about their music collection. 

Instead of treating your library as a messy pile of files with fragile ID3 tags, Lyra organizes music from the ground up: grouping every cover and remix under the same composition, deduplicating identical files at the storage layer, and letting you stream bit-perfect audio straight to your living room gear without keeping a bulky PC turned on.

---

## Why Lyra?

### 1. Group Covers & Remixes Under One Work
Traditional players scatter your library when you have five versions of the same song—original, acoustic, DJ remix, sped-up version, and movie soundtrack. 

Lyra structures your music in four distinct layers:
* **Work**: The composition itself (e.g., Mozart's *Queen of the Night*, or a modern song).
* **Track**: Specific recordings, covers, remixes, or acoustic takes linked to that Work.
* **Audio**: The acoustic recording. Lyra evaluates sample rate, bit depth, and bitrate to automatically recommend the best master recording while keeping other versions accessible.
* **Asset**: The underlying physical file (`.flac`, `.wav`, etc.).

```text
Work (e.g., "Queen of the Night")
  ├── Track A (Original Studio Recording)
  │     ├── Audio 1 (24-bit / 96 kHz Hi-Res FLAC) ★ Recommended Master
  │     └── Audio 2 (16-bit / 44.1 kHz ALAC)
  ├── Track B (Movie Soundtrack Version)
  │     └── Audio 3 (16-bit / 44.1 kHz WAV)
  ├── Track C (DJ Club Remix)
  │     └── Audio 4 (320 kbps MP3)
  └── Track D (Acoustic Cover)
        └── Audio 5 (FLAC)
```

### 2. Zero-Waste Storage (CAS Deduplication)
If you download the same track twice, or keep both a `.flac` and a `.wav` of the identical audio stream, Lyra will not waste double disk space. 
* Files are stored in Content-Addressable Storage (CAS) based on cryptographic content hashes (`/objects/xx/yy/[hash]`).
* Multiple database tracks can reference the same physical asset safely.

### 3. Stream to AirPlay & HEOS Amps over LAN (No PC Required)
Tired of turning on a power-hungry desktop PC just to feed optical S/PDIF into your amplifier?
* Lyra's audio engine is built on an extensible **"Everything is a Sink"** C-ABI.
* Play and control music directly from your phone, laptop, or tablet, streaming lossless PCM over your local network straight to Apple AirPlay gear or HEOS-enabled network amplifiers (e.g., Marantz, Denon) without physical cables.

### 4. Content Over Container (Never Mess Up Your Tags)
* Lyra identifies tracks by decoding them and calculating the raw PCM acoustic fingerprint (S32LE SHA-256), not by filenames or easily corrupted ID3 tags.
* Your original audio files are treated as read-only historical artifacts. Lyra **never** rewrites tags into your source files—the database is the single source of truth.

---

## Architecture at a Glance

```text
[ Storage & Ingestion ]
  Raw Files ──> Ingest & Deduplicate ──> CAS Object Store (/objects/xx/yy/...)
                     │
                     └── In-Process FFmpeg ──> Extract Raw PCM Hash (Audio Entity)

[ Audio Playback Pipeline ]
  Audio File ──> AudioDecoder (In-Process FFmpeg)
                     │ (32-bit Float PCM)
                 AudioEngine (Double-buffered, Gapless, Sample-accurate Seek)
                     │
                     └── C-ABI LyraAudioSink Plugin Interface
                           ├── LocalAudioSink (miniaudio: ALSA, PulseAudio, WASAPI, CoreAudio)
                           ├── NullAudioSink (Headless / Testing)
                           └── NetworkAudioSink (AirPlay RAOP / HEOS LAN streaming)
```

* **Core**: Modern C++20 with SQLite WAL mode, in-process FFmpeg decoding, and miniaudio.
* **Interface**: Clean, stateless C-ABI (`lyra_c_api.h` and `lyra_plugin_api.h`) with a responsive Flutter client.

---

## The Philosophy: Digital Ownership in a Subscription World

> *"If this keeps going on, people in the future won't own anything. Cars, PCs, e-books, media, printers, and services might all be subscription-based; owning nothing is terrible."*  
> — [Watch the discussion that sparked this thought on YT](https://www.youtube.com/watch?v=BlUcAzPvo24)

Lyra was started with a simple belief: **You should truly own what you pay for.**

* **Pay As You Go**: You buy the right to use the media. For online services, you pay only for the storage, processing, and transfer bandwidth you actually use—not an endless monthly rent.
* **No Artificial Locks**: Once media is downloaded to your device, it is yours. No arbitrary DRM expirations or forced proprietary lock-in.
* **Open Source Stewardship**: If a paid hosted service is offered in the future, profit margins won't go to bloated advertising. A dedicated portion will serve as a forced donation back to the upstream open-source projects Lyra depends upon.

---

## Getting Started & Development

Lyra uses **Nix** to ensure deterministic, reproducible builds across environments.

### Prerequisites
Make sure Nix is installed with Flakes or `nix-shell` enabled.

### Build the C++ Core & CLI
```bash
./build.sh
```

### Run Automated Tests
Lyra maintains a dual-layer test suite (C++ unit tests + Python FFI integration tests):
```bash
./test.sh
```

### Run the Flutter UI (Desktop)
```bash
./flutter.sh pub get
./flutter.sh run -d linux
```

---

## 🗺️ Roadmap

- [x] Content-Addressable Storage (CAS) physical deduplication
- [x] In-process FFmpeg Raw PCM acoustic fingerprinting
- [x] Single-level star topology for audio versions & automated master quality ranking
- [x] Gapless playback engine with miniaudio local sink
- [x] Cross-platform Flutter desktop client foundation
- [ ] Automated Work-level grouping and derivative track ingestion pipeline
- [ ] Source tracking table (`Source_Data`) for file provenance and URL history
- [ ] Network Audio Sink plugins (Apple AirPlay & HEOS / UPnP LAN streaming)
- [ ] Mobile interface optimizations (iOS & Android)

---

## License

Lyra is available under a **Dual Licensing** model:

1. **Community Edition (Open Source)**:  
   For personal use, educational purposes, and open-source projects, Lyra is licensed under the **GNU Affero General Public License v3.0 (AGPLv3)**.
2. **Commercial Edition (Enterprise)**:  
   If you wish to integrate Lyra into proprietary commercial hardware, embedded audio gear, or closed-source SaaS offerings without distributing your source code under AGPLv3, a commercial license is required.