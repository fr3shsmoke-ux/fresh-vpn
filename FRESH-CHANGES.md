# Fresh VPN: what we changed in AmneziaVPN

Fresh VPN is a fork of [AmneziaVPN](https://github.com/amnezia-vpn/amnezia-client).
The tunnel itself, the protocols and the cryptography are Amnezia's work. We
changed the shell around them.

The GNU GPL v3, under which the original is published, asks anyone who
distributes a modified build to say what was modified. This file is that
statement, kept up to date on purpose rather than left to the commit log.

**Upstream point we forked from:** `890103a1`, synced with `dev` at `327e5985`
(5.0.2.1, September 2026) on branch `sync-upstream-5.0.2.1`.
**Licence:** GNU General Public License v3, unchanged. See [LICENSE](LICENSE).

Fresh VPN is not affiliated with, endorsed by, or supported by the Amnezia
project. Please do not send us their bugs, and do not send them ours.

---

## Brand and naming

- Application, installer, tray menu and window title renamed to Fresh VPN.
- Android application id changed to `online.fr3sh.vpn`, so our build no longer
  installs over Amnezia's and cannot be mistaken for it.
- Colour scheme, icons and the About screen redrawn (graphite and lime).
- Setup wizard artwork replaced; links to Amnezia's site and documentation
  replaced with ours or removed.

## Behaviour we added

- **Connection health.** Live latency and jitter under the connect button and on
  the Statistics screen.
- **Speed test.** Download and upload measured through the active tunnel against
  public endpoints, so it does not depend on our servers.
- **Leak detector.** Checks that the visible address and DNS really belong to
  the tunnel.
- **Smart server picker.** Sorts servers by measured latency instead of order in
  the file.
- **Russian sites go direct.** A curated list of domains routed outside the
  tunnel by default, so banks and government sites keep working.
- **AmneziaWG by default** for imported subscriptions when the server offers it.
- **Setup guide opens on the operating system the application is running on.**
- **Clipboard key on first launch.** On the very first run, when no servers
  exist yet, the app checks the clipboard: if it holds a Fresh subscription
  link or a share URI, it offers to add it with one tap, so a key copied in
  the mini app does not have to be pasted by hand.

## Behaviour we fixed

- Black screen on Android caused by the content area collapsing to zero width.
- Onboarding subtitle overflowing the screen on phones.
- Tab screens rescaled to fit the height without scrolling.
- Android builds now produce both `arm64-v8a` and `x86_64`, and the pipeline
  checks that both landed in the package.
- `amnezia-libxray`: keep the `go.mod` shipped with the release, instead of the
  generated one.

## Build

- GitHub Actions workflows for Windows and Android added.
- Android builds are signed with a persistent release key, so updates install
  over previous versions.
- `deploy/build.sh` defaults the upstream branding knobs to Fresh values
  (`CLIENT_TARGET_NAME`/`CLIENT_APPLICATION_NAME` to `FreshVPN`,
  `CLIENT_ANDROID_PACKAGE` to `online.fr3sh.vpn`, so the APK, launcher label
  and Play lookup use Fresh). The keychain name intentionally stays
  `AmneziaVPN-Keychain` so updates keep reading existing encrypted settings.
  All overridable via the environment.
- `deploy/data/windows/vc_redist.x64.exe` is bundled so the Windows installer
  can install the Microsoft runtime on machines that lack it. It is
  redistributed under Microsoft's own terms and is not part of this project's
  source.

---

## Building it yourself

Build instructions from the original project apply unchanged; see
[README.md](README.md). Nothing in the build depends on our servers or on any
credential of ours.
