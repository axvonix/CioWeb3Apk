# Changelog

## v3.5
- **New banner (`card`)**: framed card, per-letter gradient title, status panel; powerline-style coloured "tabs" header on sub-screens. Old styles kept (`big`, `medium`, `mini`, `off`).
- **Animated build**: spinner + gradient progress bar with pulsing current cell, per-step timer, gradient "BUILD SUCCESS"; same animation for installs, downloads, mirroring and lookups. Auto-off for pipes / `--no-anim`.
- **Auto tool bootstrap**: every command installs only the missing tools it needs, once (retry with `pkg update`, mirror tip). New `setup`, `--no-auto-install`; `android.jar` fetched automatically.
- **New: `social` profile lookup** via official/public APIs only (GitHub, GitLab, Bluesky, Mastodon, Reddit, Hacker News, Stack Overflow, Lichess, Chess.com, DEV, YouTube with key). No email/location, no scraping, no monitoring; remote text sanitised. `keys` for optional API keys (`.keys`, owner-only).
- **New: `webzip`**: GitHub/GitLab repos via official archive APIs, websites via polite wget mirror (robots.txt, delay, size cap, same domain, permission prompt), `--wayback` via Internet Archive API; private/local addresses refused; ZIP can be uploaded to the temporary CDN.
- **Fix (build blocker)**: aapt2 `expected reference but got (raw string) #FFFFFF` - colours now go through `res/values/colors.xml`.
- **Fix**: wrong hint ("install imagemagick") - hints now read only the failed step; error box shows only that step.
- **Fix**: ImageMagick 7 "convert is deprecated" - uses `magick` when present; default icon is now a gradient with the app initial.
- **Fix**: all `*.vercel.app` / `netlify.app` / `github.io` ... sites got the same package name (`com.vercel.app`) - now derived from the site name.
- **Fix**: output folder not created when storage permission is missing; `social --json` printed banner text.
- Menu: `8` social, `9` webzip, `t` more tools, `d` doctor, `s` setup.


## v3.4
- **New banner**: gradient logo (big / medium / mini), white "CIO" + gradient "WEB3APK", gradient rules, info bar (version, dev, Ready/Setup, builds, CDN), short intro animation on first menu draw. Auto-fits the screen (`banner_style auto`), narrow-phone layout, compact header on sub-screens.
- 6 themes now carry 256-colour gradients (cyan, green, magenta, yellow, blue, mono).
- New: `banner [style]` preview, `--banner`, Build options c/d (style, animation). Colours auto-off for pipes, `NO_COLOR` and `TERM=dumb`.

## v3.3
- **Temporary CDN upload**: `upload`, `links`, `--upload --ttl 1h|12h|24h|72h --cdn`, menu entries; hosts litterbox / 0x0 / tmpfiles with automatic fallback, link log with time left, clipboard + QR + share link.
- **Fix (critical)**: main menu and sub-menus were broken by an earlier patch (`menu: command not found`, so the `cioweb3apk` shortcut did nothing). Menus restored; new `selftest` command guards against missing functions.
- **Fix**: separator / progress-bar glyphs printed as garbage in Termux (multibyte `tr`).
- **Fix**: `android.jar missing` even with `aapt` installed. Now searched in several places, plus `jar` command (auto-download with validation, or use your own file/link) and `doctor --fix` handles it.

## v3.2
- Icon (and loading image/video) from **direct image link**: validation (real file type, 404/403, web page, SVG, size), auto-convert imgur / GitHub blob / Google Drive / Dropbox share links, `icon set|test|reset`, menu 7, `--icon-url`.
- `auto URL`: fill app name, package, project, ColorPrimaryDark and icon from the website.
- Camera / mic / location for websites, block screenshots (secure mode).
- Profiles: safe plain-text format, `profile export` / `profile import` (file or link), values sanitized (no code execution).
- Fixes: web-permission entries missing in manifest, User-Agent line printed twice in menu, banner error on first run, better error hints (only last log lines), free port for `serve`, IP-host package guess, sign-step command display.
- Optimizer: icon cache, PNG shrink (pngquant/optipng), cache auto-prune, wake-lock during build.
- UI: status chip (Ready / Setup needed), `log` command (steps + commands), redesigned menu, Quick start help.
- README rewritten step by step (Indonesian). Added `.gitignore`, `install.sh`, `LICENSE`.

## v3.0
Profiles, batch, dry run, verify step, random keystore password, Wi-Fi share, themes, more app features.
