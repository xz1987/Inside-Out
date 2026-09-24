# Project notes for Claude

- Progress is tracked in `sprint.md`. After finishing any item, tick its checkbox (`[x]`, or `[~]` if partial) and append a dated entry to the 「进度日志」 section at the bottom describing what changed and which files/commits.
- Scope baseline: `docs/retrospective-memory-ios-prd.md` Section 28–37.
- Build for simulator:
  `cd apps/ios && xcodebuild -project InsideOutApp.xcodeproj -scheme InsideOutApp -sdk iphonesimulator -destination 'name=iPhone 17 Pro' -derivedDataPath build CODE_SIGNING_ALLOWED=NO build`
