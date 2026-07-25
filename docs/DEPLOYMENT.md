# Deploying to the family's phones and tablets

How to get the game onto Apple and Android devices **without publishing it
anywhere**, what each path costs, and what to know before trying. Written for
this project specifically: a private, non-commercial family game that must
stay off public stores while the Tiga/Zero skins are in it.

The project is already mobile-ready: GL Compatibility renderer, 1280×720
canvas-items stretch (fills any screen), touch input throughout,
`sensor_landscape` orientation so the tablet works held either way round.

---

## The short answers

**Does it have to be officially published?** No. Both platforms have
first-party ways to run your own app on your own devices with no store, no
review, and no public listing. That is exactly the right channel for this
game (see the licence note at the end).

**What does it cost?**

| Path | Cost | Catch |
|---|---|---|
| Godot engine + export templates | Free (MIT) | — |
| **Android: install your own APK** | **Free** | Google is phasing in developer verification for installs starting late 2026, region by region (see below) |
| Android: Google Play | $25 once | Public distribution — not for this build; personal accounts also need a 12-tester / 14-day closed test before production |
| **iOS: free Apple ID + Xcode** | **Free** | App stops launching after 7 days; re-install from Xcode weekly; max 3 apps |
| iOS: Apple Developer Program | $99 / year | Removes the 7-day limit: Ad Hoc installs last ~1 year; TestFlight builds last 90 days |
| iOS: App Store | $99 / year (same membership) | Public distribution + review — not for this build |

**Recommendation:** Android tablet → free APK install, ten minutes, done.
iPhone/iPad → bite the $99/year and use Ad Hoc installs if weekly
re-plugging would annoy you; the free tier is fine for trying it out.

---

## macOS (this computer — the two-minute path)

One-time: open the project in Godot once, then *Editor → Manage Export
Templates → Download and Install* (~1 GB, per Godot version).

Then **double-click `tools/build_mac.command`**. It exports with the bundled
"macOS" preset (universal binary, the drawn-hero app icon, ad-hoc signed),
unzips `build/Little Heroes Growth Island.app`, strips the quarantine flag,
and opens the folder. Drag the .app to /Applications; it launches like any
app from then on. If macOS still complains on first open: right-click the
.app → Open → Open.

The same preset works from the editor UI (*Project → Export → macOS →
Export Project*) if you prefer buttons. `export_presets.cfg` ships
pre-configured; it is gitignored, so it stays local to this machine.

## Android (free, no account)

One-time setup in Godot: *Editor → Manage Export Templates → Download*, and
install Android Studio (or just its command-line tools) plus OpenJDK 17.
Point Godot at them in *Editor Settings → Export → Android*, and let Godot
create a debug keystore.

1. *Project → Export → Add → Android*.
2. Export `heroes_island.apk` (debug keystore is fine for family use).
3. Get the APK onto the tablet — USB cable, cloud drive link, or email.
4. On the tablet, open the APK; Android asks to allow installs from that app
   ("install unknown apps") — allow it once.

Updates are the same steps again; the new APK installs over the old one and
save data survives (it lives in the app's user directory).

**The 2026 change to know about:** Google is rolling out mandatory developer
identity verification for apps installed on certified Android devices —
starting with a few countries (Brazil, Indonesia, Singapore, Thailand) in
September 2026 and expanding globally in 2027. When it reaches your region,
plain APK installs of unverified apps will be blocked on retail devices, with
an ADB (developer-tools) install path remaining for hobbyists, and Google has
described a free lighter verification tier for hobbyist/student developers
with device-limited installs. Installing via ADB (`adb install
heroes_island.apk` with USB debugging on) is the future-proof fallback and
works today too.

## iOS (needs this Mac + Xcode, both free)

Godot exports an Xcode project; Xcode signs it and puts it on the device.
One-time setup: install Xcode from the Mac App Store, and download Godot's
iOS export templates.

1. *Project → Export → Add → iOS*, set a bundle identifier like
   `com.yourfamily.heroesisland`, export the Xcode project.
2. Open it in Xcode, plug in the iPad/iPhone, select your team under
   *Signing & Capabilities*, press Run.

With a **free Apple ID** ("personal team"): the installed app runs for
**7 days**, then must be re-installed from Xcode (10 seconds with the cable;
save data survives). Limit of 3 apps signed this way.

With the **Apple Developer Program ($99/year)**: two better options.
*Ad Hoc* — register the family devices' UDIDs, export with an Ad Hoc
profile, install via Finder/Apple Configurator; the app keeps working for
about a year per profile, fully offline, nothing uploaded anywhere.
*TestFlight* — upload the build to App Store Connect and family installs it
from the TestFlight app; slickest updates, builds last 90 days, but the
build lives on Apple's servers (see the licence note).

## The licence note (why "no stores" is the rule for this build)

The Tiga and Zero skins are recognisable Tsuburaya characters. On your own
family devices that is your own business; **any public channel — App Store,
Google Play, itch.io, a group chat — is distribution**, and this build must
not go there. If you ever want a shareable version: delete the `tiga` and
`zero` entries from `data/characters.json` and the game cleanly falls back
to the original Light Hero and the procedural monsters, all of which are
this project's own designs. For iOS specifically, prefer direct Xcode / Ad
Hoc installs over TestFlight for the Ultraman build, since TestFlight means
uploading the build to Apple.

## Odds and ends

- `export_presets.cfg` is gitignored (it can hold keystore paths); each
  machine keeps its own.
- Test on the tablet early: colours and touch-target sizes read differently
  on glass than on a monitor, and the first session with your son will tell
  you more than any checklist (README §14 has the order to watch).
- If performance ever stutters on an old device, the 1920×1080 background
  PNGs are the first thing to downscale to 1280×720 — visually identical on
  a 720p viewport, half the memory.
