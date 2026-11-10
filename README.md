# 📻 Kosmo Radio Player

A native macOS internet radio player (SwiftUI + AVFoundation) that lives in your menu bar, with a curated **Rap & Hip-Hop hub**, stations from **Ukraine 🇺🇦** and **New York City 🗽**, and **40,000+ stations from all over the world 🌍** via the open [Radio Browser](https://www.radio-browser.info) catalogue.

## ✨ Features

- **Menu bar player** with quick tabs: ⭐ Favorites, 🎤 Rap, 🇺🇦 UA, 🗽 NYC.
- **Explore window** to browse and search the worldwide catalogue by country, genre or name.
- **Rap & Hip-Hop hub** with 8 sub-genres, each mixing hand-picked stations with live catalogue search:
  NYC & East Coast Boom Bap · Old School & 90s Golden Era · West Coast & G-Funk · Trap, Drill & Phonk · Underground & Conscious · Lo-Fi & Chillhop · UK, Europe & Ukraine Rap.
- **Ukraine** (Suspilne, Radio Promin, Radio Kultura, Radio NV, Hromadske Radio, Radio ROKS…) and **New York City** (Hot 97, Power 105.1, WNYC, WQXR, WBGO, WFMU, WFUV…).
- **Synced lyrics** for the current track, when available, from [LRCLIB](https://lrclib.net).
- **Visualizer** with several presets, including a full-window mode.
- **Bilingual UI (English / Italian)**: follows the macOS language, with a quick 🌐 Auto / 🇬🇧 EN / 🇮🇹 IT switch.
- Sleep timer, favorites, recently played, media keys and Now Playing integration.

## 🚀 Build (macOS)

Requires macOS 14+ and the Xcode Command Line Tools (`xcode-select --install`). No Xcode project needed.

```zsh
cd macos
./build.sh
open KosmoRadio.app
```

`build.sh` compiles a universal binary (Apple Silicon + Intel), ad-hoc signs it and also produces `KosmoRadio-Mac.zip` and `KosmoRadio-Installer.dmg`.

The app is not notarized: on first launch, right-click → **Open**, or run the **Unlock and Open** script included in the DMG.

## 🙏 Credits

- Station catalogue: [Radio Browser](https://www.radio-browser.info), a free and open community database.
- Lyrics: [LRCLIB](https://lrclib.net).
- All streams, names and logos belong to their respective broadcasters. Kosmo Radio Player only plays their public streams and is not affiliated with any of them.

## 📄 License

[MIT](LICENSE)
