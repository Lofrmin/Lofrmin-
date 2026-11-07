# Menu and First-loop Onboarding Implementation Plan

**Goal:** A deliberate start screen, safe continue/new investigation choices, skippable manual intro, readable goals and context-sensitive controls.
**Architecture:** Reuse interface.gd immediate-mode UI and game.gd mode handling. Preserve existing cinematic background and profile API; fixture gets only a fake exterior. No station/map/collision/asset changes.
**Spec:** User approved menu, first-round guidance and concise task text before jumping or extra hunters. Continue resumes banked chapter/evidence, not an exact position; label that honestly. No new puzzle rules or spoilers.

- [x] Add failing tests for menu/intro inactivity, keyboard/mouse paths, cancel/new save safety, late profile callbacks, controls return state and wrapping.
- [x] Implement menu/controls/manual intro modes, preserve confirmation before destructive new game, guard against late profile restoring an explicitly abandoned investigation.
- [x] Tighten objective and interaction copy; wrap HUD, terminal notices and subtitles; contextual guidance distinguishes map preview from actual phase travel.
- [x] Verify new UI at 1280x720 and 1920x1080, run all existing regressions, inspect actual cinematic screenshot and export/smoke-test with isolated configuration if needed.

**Boundaries:** Do not change station.gd, maps, obstacle placement, physics, assets, profile.gd or teammate working files. No jump claim in controls. Commit locally; do not push shared main during teammate map work without a request.

## Verification and handoff
- MENU_TEST: 28 checks / 0 failures, including confirmation, cancel, continue, delayed profile response and completed-save return.
- CORE_LOOP_TEST: 36 / 0; AUDIO_TEST: 37 / 0; MAP_ROUTES_TEST: 393 / 0.
- MENU_VISUAL_TEST and existing VISUAL_INPUT_TEST pass at 1280x720 and 1920x1080. Real cinematic menu/controls/intro/first objective screenshots inspected; added a solid hint background after the initial capture was hard to read against the window.
- Existing real audio capture still passes left/right panning and far-range silence.
- Windows export exit 0; packaged launcher smoke-test exit 0 using default Vulkan Forward+ on the local RTX 3060.
- Host APPDATA/Godot remains inaccessible; builds/tests use process-local isolated APPDATA, and Play-Local.cmd keeps test saves apart. No global config or real user saves modified.
- Ruling: continue returns to A-01 with banked evidence, as the existing save format does not store coordinates. The menu says so explicitly rather than promising an exact resume.
- Ruling: new-case intent wins over a late backend read; the existing profile API is reused, and profile.gd is unchanged.
- Only interface/game/copy/tests/docs changed. Teammate map, station geometry, physics and asset files remain untouched. No jump or new pursuer added. No shared-main push in this task.
