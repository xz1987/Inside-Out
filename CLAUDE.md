# Project notes for Claude

- Progress is tracked in `sprint.md`. After finishing any item, tick its checkbox (`[x]`, or `[~]` if partial) and append a dated entry to the 「进度日志」 section at the bottom describing what changed and which files/commits.
- Scope baseline: `docs/retrospective-memory-ios-prd.md` Section 28–37.
- Build for simulator:
  `cd apps/ios && xcodebuild -project InsideOutApp.xcodeproj -scheme InsideOutApp -sdk iphonesimulator -destination 'name=iPhone 17 Pro' -derivedDataPath build CODE_SIGNING_ALLOWED=NO build`
- Run the backend for the app: `cd apps/api && npm run dev` (needs `apps/api/.env` with `OPENAI_API_KEY`; the app falls back to local keyword matching if it can't reach `http://localhost:3000`).
- Backend checks: `cd apps/api && npm test && npm run typecheck`. `npm run try:input` spends real quota.
