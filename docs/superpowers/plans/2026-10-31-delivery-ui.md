# Delivery UI implementation — 2026-10-31

1. Preserve current uncommitted integration; touch only v2 frontend modules and tests.
2. Extend offline DemoDelivery with authoritative draft, timestamped events, disconnected state, and explicit DEMO-only advancement/payment guards. Add meaningful state tests.
3. Extract delivery presentation: animated SVG stage, compact order aside, horizontal four-phase progress, expandable event log. Handle empty/active/arrived/completed/error/disconnected.
4. Add local-only replaceable video mapping with error fallback; test switching and missing media.
5. Mount original PetHub in home visual and offer original eight characters through existing gallery. Keep island dual-state. No transport changes.
6. Build, run original offline regression and new interaction tests. Capture actual isolated Electron at 1440x900,1280x711,980x660. Inspect screenshots, audit protected diff and write outputs report.
