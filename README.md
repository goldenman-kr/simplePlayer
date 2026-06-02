# SimplePlayer

SimplePlayer is a lightweight macOS media player for local video and audio playback.

It is designed to open dropped files quickly, preserve the source video's aspect ratio during playback, and avoid distortion when the window is resized. Video content is shown using the media file's real dimensions by default, while letterboxing or pillarboxing is only added when the user changes the app window to a different aspect ratio.

Current features:

- Drag and drop playback for local media files
- Video playback with aspect-ratio-safe rendering
- MKV playback through VLCKit
- SRT and SMI subtitle overlay support
- Full-screen playback and basic transport controls
- Audio playback with embedded artwork when available
- Simple window scaling shortcuts for video content

## Development Setup

SimplePlayer uses CocoaPods for VLCKit. After cloning the repository, install
the pods before opening or building the app:

```sh
pod install
```

Open the generated workspace, not the project file:

```sh
open SimplePlayer.xcworkspace
```

Command-line release build:

```sh
xcodebuild -workspace SimplePlayer.xcworkspace -scheme SimplePlayer -configuration Release build
```
