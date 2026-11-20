# QA capture notes — issue #26 v1

Captured at PR head (see git log — this commit), Chrome headless (macOS, `--headless=new`),
one Chrome instance driven over CDP.

- Viewports: desktop 1920 px wide, tablet 1024 px wide, mobile 375 px wide.
  The diagram body is ~3k–5k px tall, so each capture is full-page height at that width
  (same approach as the accepted 1440×4400 desktop evidence in
  `docs/skill-routing/screenshots/`): a 1080/768/667-height window shows only the first
  lane because the viewer reveals diagram content by viewport, and the AC evidence must
  show every lane, node, edge and the legend.
- `console-report.json` — `console.error` and uncaught exceptions observed during a full
  render plus interaction probe of each page (0 errors on all three pages).
- Interaction probe per page: node-finder input set to "super-plan" returns matching
  results on all three pages; no console errors during the probe.
- Files: `<set>-<viewport>.png`, one per diagram page per viewport (9 captures).
