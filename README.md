# qbittorrent-nox for macOS

A script that builds qbittorrent-nox, qBittorrent without the GUI, for macOS. It compiles the unmodified upstream sources of qBittorrent, libtorrent, Qt, OpenSSL and Boost and links them statically, so the binary depends only on libraries that ship with macOS and keeps working whatever you install or update in Homebrew.

This is the same build as the qbittorrent-nox that [Lizard](https://nagornyi.su/lizard/?ref=github) installs, without signing and notarization.

## What Gets Built

| Component | Version | Notes |
| --- | --- | --- |
| qBittorrent | 5.2.4 | `-DGUI=OFF` |
| libtorrent | 2.0.11 | |
| Qt | 6.8.3 | qtbase without GUI, Linguist tools from qttools |
| OpenSSL | 3.5.0 | |
| Boost | 1.88.0 | headers only |

The binary is built for the architecture of the Mac you run the script on (arm64 or x86_64), with macOS 13 as the minimum version (`MACOS_DEPLOYMENT_TARGET` at the top of the script). To build other versions, change the numbers there.

## Requirements

- **Xcode.** Command Line Tools alone aren't enough: Qt checks the Xcode version before building. The App Store offers only the latest Xcode; for an earlier macOS, download the matching version from [Apple Developer](https://developer.apple.com/download/all/?q=xcode):

  | macOS | Xcode |
  | --- | --- |
  | Sonoma 14.0–14.4 | 15.4 |
  | Sonoma 14.5 – Sequoia 15.2 | 16.2 |
  | Sequoia 15.3–15.5 | 16.4 |
  | Sequoia 15.6 – Tahoe 26.5 | 26.3 |
  | Tahoe 26.6 or later | [App Store](https://apps.apple.com/app/xcode/id497799835) |

  Select it and accept its license:

  ```bash
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer && sudo xcodebuild -license accept
  ```

- **CMake and Ninja**, for example from [Homebrew](https://brew.sh):

  ```bash
  brew install cmake ninja
  ```

- About 3 GB of free disk space and an internet connection: the script downloads all sources from their official sites.

## Usage

```bash
curl -fLO https://raw.githubusercontent.com/NikcN22/qbittorrent-nox-macos/main/build-qbittorrent-nox.sh
chmod +x build-qbittorrent-nox.sh
./build-qbittorrent-nox.sh
```

The script builds OpenSSL, libtorrent, Qt and qBittorrent one after another, checks that the result links only to system libraries and prints the version of the binary. The binary ends up in `qbt-build/qbittorrent-nox`. To use another folder, set `BUILD_DIR`:

```bash
BUILD_DIR="$HOME/qbt" ./build-qbittorrent-nox.sh
```

Downloaded archives stay in `qbt-build/src/archives`, so a rebuild doesn't download them again. On a Mac with M4 Pro, a full build takes about 5 minutes with downloads and about 2.5 minutes without them. Most of the time goes to Qt.

## Running qbittorrent-nox

Copy the binary to a permanent place and start it:

```bash
mkdir -p ~/.local/bin && cp qbt-build/qbittorrent-nox ~/.local/bin/
```

```bash
~/.local/bin/qbittorrent-nox --profile="$HOME/Library/Application Support/qbittorrent-nox" --confirm-legal-notice
```

qBittorrent prints the Web UI address and a temporary password for the `admin` user. To start it at login with a LaunchAgent, see [Run qbittorrent-nox in the background](https://nagornyi.su/lizard/qbittorrent-nox-mac/?ref=github#run-qbittorrent-nox-in-the-background).

The binary isn't signed with a Developer ID or notarized. It runs on the Mac where it was built. If you copy it to another Mac, Gatekeeper may block it: build it there instead, or sign and notarize it with your own Developer ID.

## Troubleshooting

**`Qt requires at least version 15 of Xcode`.** The script found only Command Line Tools. Install Xcode and select it with `xcode-select` as shown above, then delete the build folder left from the failed attempt and run the script again. The downloaded archives are kept.

```bash
rm -rf qbt-build/work && ./build-qbittorrent-nox.sh
```

**`tried including <stdint.h> but didn't find libc++'s <stdint.h> header`.** The build folder was set up with Command Line Tools, and the script ran again after switching to Xcode. Delete the folder and run the script again with the command above.

## License

The script is available under the [MIT License](LICENSE).

The binary it builds combines qBittorrent with libtorrent, Qt, OpenSSL and Boost, each under its own license. qBittorrent is licensed under the GPL, so if you distribute the binary, you must also offer its complete source code.
