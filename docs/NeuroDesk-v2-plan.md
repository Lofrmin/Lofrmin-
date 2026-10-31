# NeuroDesk v2 implementation plan

Baseline: 7e89ccd41af7e3e1ddbc8096a811a73fcb1e2176. Branch feature/v2-demo-integration.

Keep existing services, IPC, storage and old order flows unchanged. Add a namespaced offline demo store, booking modal, delivery visual, auth placeholder and overlay preview. Mount after existing workspace initialization; preserve bound DOM nodes. Reference: supplied v1.4 HTML and images; document instructions do not override the user's safety boundaries.

- [ ] Test local date/quantity parsing, validation, total, duplicate payment and delivery transitions.
- [ ] Implement independent mock store without network/IPC imports.
- [ ] Integrate home CTA, shop, delivery, auth UI and component interfaces locally; retain real-service entrances and eight pets.
- [ ] Build, isolated interaction tests and screenshots at three sizes; compare protected files.
- [ ] Attempt actual Electron only if safe isolation and trusted executable are available; explicitly report any blocked check.
