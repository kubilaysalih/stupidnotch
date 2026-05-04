# StupidNotch

Hide the notch on notched MacBook Pro / Air displays. Captures your current wallpaper, draws a black region around the menu bar with smooth rounded corners on all four corners of the screen, and sets the result as your wallpaper.

![StupidNotch in action](docs/screenshot.png)

Lightweight Swift/AppKit menu bar app. No background daemons, no kernel extensions, no private installers. It captures the visible desktop pixels via ScreenCaptureKit and writes a masked image into `~/Library/Application Support/StupidNotch/`. Caches per source so re-applying the same wallpaper is instant.

## Features

- Works with **any wallpaper**: static images, system dynamic wallpapers (Sonoma, Sequoia, Ventura, Macintosh), Aerial / video Live Wallpapers, anything macOS can display
- Rounded corners on all four corners of the wallpaper
- Two corner styles: **Circular** (quadratic) and **Squircle** (Lamé n=5, iOS-icon style)
- 5 radius presets (None / Small / Medium / Large / Huge)
- Universal binary (Apple Silicon + Intel)

## Install

1. Download `StupidNotch-vX.Y.zip` from [Releases](../../releases/latest)
2. Unzip and drag `StupidNotch.app` to `/Applications`
3. **First-time launch**: macOS will block the app because it isn't signed with a paid Apple Developer ID. Either:
   - Right-click `StupidNotch.app` → **Open** → confirm in the dialog, **or**
   - Run this in Terminal to clear the quarantine attribute:
     ```bash
     xattr -cr /Applications/StupidNotch.app
     ```
4. Click the icon in the menu bar to open the popover
5. **First Apply** triggers a Screen Recording permission prompt. The app needs this to read the wallpaper pixels currently displayed (macOS doesn't expose dynamic / system wallpapers through any other API).
   - Open **System Settings → Privacy & Security → Screen Recording**
   - Enable **StupidNotch**
   - Quit and reopen the app, then click Apply again

## Usage

1. Pick the wallpaper you want in **System Settings → Wallpaper** as usual
2. Click the StupidNotch menu bar icon → **Apply notch mask**
3. To change wallpaper later: click **Remove notch mask**, pick a new wallpaper, then **Apply** again

## Build from source

Requires Xcode command-line tools, macOS 14+.

```bash
git clone https://github.com/<you>/stupidnotch.git
cd stupidnotch
./build.sh
open StupidNotch.app
```

## How it works

When you click Apply:
1. Captures the current desktop wallpaper pixels via `ScreenCaptureKit` (`SCScreenshotManager.captureImage`)
2. Saves the capture as `original.png` under `~/Library/Application Support/StupidNotch/cache/<hash>/`
3. Renders a masked PNG with rounded black corners covering the menu bar and the screen edges
4. Saves the masked PNG in the same cache folder (deterministic name based on radius + style)
5. Sets the masked PNG as the wallpaper via `NSWorkspace.setDesktopImageURL(_:for:options:)` with Fill Screen scaling

When you click Remove, the cached `original.png` is set back as the wallpaper.

The notch itself is hardware-black, so the surrounding black region makes it visually disappear. The corner curves match the screen's physical rounded corners.

## Limitations

- Built-in display only (notched MacBook Pro / Air). External displays are ignored.
- macOS 14 Sonoma or later (uses ScreenCaptureKit's `SCScreenshotManager.captureImage`).
- Requires Screen Recording permission. If denied, Apply does nothing.
- After Apply, the wallpaper is a **static** snapshot. Dynamic / Aerial wallpapers stop animating. Click Remove to go back to the live original.

## Credits

The Squircle corner style is implemented using the figma-squircle approximation (smoothness = 1.0):

- [Desperately seeking squircles, Figma blog](https://www.figma.com/blog/desperately-seeking-squircles/): the article explaining the math
- [phamfoo/figma-squircle](https://github.com/phamfoo/figma-squircle): TypeScript implementation that this app's coefficients (`a = 0.4714p`, `b = 0.2357p`, `c = d = 0.1464p`) are ported from
- [MartinRGB/Figma_Squircles_Approximation](https://github.com/MartinRGB/Figma_Squircles_Approximation): the original math derivation

## License

MIT, see [LICENSE](LICENSE).
