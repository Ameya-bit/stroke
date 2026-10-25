# ArmCanvas — Implementation Plan

Working name. Gamified upper-limb rehab: the iPhone is a tracked paintbrush in AR.
Primary pitch: home rehab exercise companion with measured progress.
Secondary: free-draw level with AI recognition as the reward.

HackPSU Fall 2026, built on-site Oct 24–25. Native iOS (Swift, SwiftUI, ARKit, SceneKit).

## Decisions already made

| Decision | Choice | Why |
|---|---|---|
| Platform | Native iOS, Swift | ARKit is the only reliable phone-pose source; RN AR bindings are dead |
| Rendering | ARSCNView + SceneKit | Cylinder-segment strokes are a 30-line job; RealityKit custom meshes are not |
| Project file | xcodegen from `project.yml` | Reproducible, no clicking through Xcode, diff-friendly |
| Min iOS | 17 | Every ARKit iPhone in the room runs it |
| Persistence | Codable JSON in Documents | SwiftData is overkill for one session list |
| Exercise plans | Hard-coded presets | Therapist portal is a vision slide, not a build |
| AI guess | Claude vision via Messages API, direct from app | Key lives in a gitignored xcconfig |
| Mirror mode | Cut from MVP | Stretch only if Phase 6 lands early |
| Signing | Free Apple ID personal team | 7-day provisioning is fine for a hackathon |

## Build workflow

- Claude writes Swift sources + `project.yml`, runs `xcodegen generate`, then
  `xcodebuild -scheme ArmCanvas -destination 'generic/platform=iOS' build` to catch compile errors.
- Ameya: plug in iPhone, open `ArmCanvas.xcodeproj`, set Signing Team once, Cmd-R.
  First run: on the phone, Settings > General > VPN & Device Management > trust the developer.
- ARKit does not run in the simulator. Every behavioral test is on the phone.
- Test loop per phase: Claude builds clean → Ameya runs on phone → reports what happened in one or two sentences.

## Architecture (files)

```
armcanvas/
  project.yml                 xcodegen spec
  Config/Secrets.xcconfig     ANTHROPIC_API_KEY=...   (gitignored)
  Config/Secrets.example.xcconfig
  ArmCanvas/
    App/            ArmCanvasApp.swift, RootView.swift (flow: Home → Session → Report)
    AR/             ARSessionManager.swift   (ARSCNView, world tracking, per-frame camera pose)
                    BrushTip.swift           (camera pose → tip position, 0.25m ahead)
                    StrokeRenderer.swift     (SceneKit cylinder segments)
    Model/          Stroke.swift, Sample.swift, SessionResult.swift, ExercisePlan.swift
    Exercises/      Exercise.swift (protocol), Calibration.swift, ReachExercise.swift,
                    TraceExercise.swift, FreeDrawExercise.swift
    Scoring/        PathScoring.swift (deviation), Smoothness.swift (normalized jerk),
                    ReachEnvelope.swift (extents, bbox volume)
    AI/             ViewRenderer.swift (offscreen 3-view snapshots), ClaudeGuesser.swift
    Store/          SessionStore.swift (JSON read/write)
    UI/             HUDView.swift, ReportView.swift, HomeView.swift
```

Coordinate frame: at session start the user holds the phone at chest height and taps Start.
That camera position becomes the session origin; all exercise geometry is expressed
relative to it so paths and targets appear in front of the user wherever they stand.

## Phases

Each phase ends with a check Ameya can do on the phone in under a minute.

### Phase 0 — Scaffold (parallel with Xcode download)
- `project.yml`, app target, Info.plist with camera usage string, ARKit required capability.
- Empty SwiftUI shell showing a live ARSCNView camera feed and a tracking-state banner.
- `.gitignore` for Secrets.xcconfig, xcuserdata, DerivedData.
- **Verify:** builds with xcodebuild; runs on phone; camera feed visible; banner says "Tracking normal" after a few seconds of moving.

### Phase 1 — Brush and strokes
- Per-frame camera pose → brush tip. Touch-and-hold on screen records samples at ~60Hz, downsampled to 1cm spacing.
- StrokeRenderer draws cylinder segments; strokes persist in world space.
- Clear button.
- **Verify:** draw a line in the air, walk around it, it stays put and looks like a line from the side.

### Phase 2 — Session origin, calibration, reach envelope
- Start button sets origin. Calibration task: "reach as far as you can in every direction" for 15s, HUD countdown.
- ReachEnvelope: max extent ±X, ±Y, +Z from origin in cm; bounding-box volume in liters.
- Show results on a simple summary card.
- **Verify:** extents are plausible for an adult arm (roughly 50–75cm); a deliberately small reach gives smaller numbers.

### Phase 3 — Reach exercise
- Spawn one target at a time at 0.9–1.05 × calibrated extent in a random direction, ≥20cm from the last.
- Pop when tip within 4cm. Count reps, 10 per set, haptic + sound on pop.
- **Verify:** complete a set of 10; targets sit at the edge of reach, not inside it or behind you.

### Phase 4 — Trace exercise and scoring
- Paths relative to origin: horizontal line (shoulder abduction), vertical line (flexion), circle (circumduction). Figure-8 if cheap.
- Render path as faint dots; dots light up when the tip passes within 3cm, progress = fraction lit.
- Scores: mean deviation (cm), normalized jerk, duration.
- **Verify:** a careful trace scores visibly better than a sloppy one on both deviation and smoothness.

### Phase 5 — Persistence and report
- SessionResult (date, envelope, reach reps, trace scores) saved to JSON after each session.
- ReportView: this session vs previous session, delta arrows on extents, reps, deviation, smoothness.
- Home screen lists past sessions.
- **Verify:** two sessions on the phone, report shows both and the deltas are correct.

### Phase 6 — Free draw and Claude guess
- Prompt word from a list of 3D-friendly objects (house, chair, star, heart, tree, cup).
- Done → ViewRenderer snapshots strokes from front, side, top (offscreen SCNRenderer, white background).
- ClaudeGuesser sends three images, asks for JSON `{guess, confidence}`, no hint given. Score = match + confidence.
- Timeout and offline fallback: show "couldn't reach the judge" and still save the drawing.
- **Verify:** draw a house, Claude says house. Draw scribbles, it doesn't.

### Phase 7 — Flow, polish, demo hardening
- Preset plan: Calibration → Reach ×10 → Trace circle → Free draw → Report.
- Onboarding card: hold phone like a brush, keep the camera uncovered, point it outward.
- Tracking-loss handling: pause exercise, show "move the phone slowly" banner.
- Record a backup demo video. Devpost page, 3-slide pitch.
- **Verify:** full session end to end in under 3 minutes with no dead ends.

### Stretch (only if Phase 6 is done with >4h left)
- Mirror mode: strong arm draws, weak arm reproduces, symmetry score.
- Tremor spectrum from gyro at 100Hz during the trace, dominant frequency shown in the report.
- Forearm-strap mode: flip brush offset so the camera faces outward from the forearm.

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Xcode download slow on venue wifi | Started at plan time; Phase 0–1 code is written while it downloads |
| ARKit loses tracking in a dim, crowded judging room | Tracking banner, pause-on-loss, demo near a textured wall or table, backup video |
| User covers camera with hand | Onboarding card; brush offset in front of camera so it is natural to hold it pointed out |
| Claude call fails on venue wifi | 10s timeout, graceful fallback, pre-cached demo result for the backup |
| Free provisioning expires | 7 days, well past judging |
| Scope creep into mirror/tremor | Hard gate: not before Phase 6 is verified |

## Pitch framing (for Devpost)

- Problem: home upper-limb rehab adherence is low because exercises are boring and untracked.
- Solution: a phone-as-paintbrush AR game that turns prescribed reach and trace movements into play, measures range of motion and smoothness, and shows progress session over session.
- AI: adaptive target placement from the measured envelope; vision model judges the free-draw reward level.
- Honest claim: exercise companion for a prescribed program, not a medical device.

## Known shortcut: API key on device

The Gemini key is injected from the gitignored `Config/Secrets.xcconfig` into Info.plist
and read at runtime. Acceptable only because the build is installed on one personal phone
and never distributed. Cheap hardening to do anyway: in Google Cloud Console restrict the
key to the Generative Language API only and set a daily quota cap. Anything shipped past
the hackathon must move the call behind a backend that holds the key.
