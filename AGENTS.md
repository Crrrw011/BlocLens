# BlocLens Project Instructions

## Safety boundary

- The exact authorised project boundary is `/Users/uuuuuyu/Documents/ChatGPT/BlocLens`.
- Never read, create, move, rename, or modify files outside that boundary.
- Never run destructive Git or filesystem commands.
- Never commit secrets, credentials, tokens, private keys, or environment files.

## Product source of truth

- `Docs/BlocLens_MVP_PRD_v1.1.docx` is the product source of truth.
- Requirements are frozen for the MVP. New features belong in a Post-MVP Backlog unless scope is explicitly unfrozen.
- BlocLens is a climbing tool first. Social behaviour is secondary and exists only when it improves route discovery, beta quality, or practical climbing records.
- Beta media is external-public-link-only. Never add direct video upload, hosted video storage, transcoding, compression, caching, mirroring, or media delivery.
- Wall navigation uses named wall-zone lists and attributes. Never add a 2D floor plan or clickable wall map to the MVP.
- Logbook records, notes, Projects, and statistics are private by default and must never become public without a separate explicit contribution action.

## Engineering rules

- Build a native SwiftUI iPhone application targeting iOS 17 or later.
- Prefer Apple platform frameworks and do not add third-party dependencies without explicit approval.
- Do not force-unwrap optionals without a nearby documented reason that explains why the invariant is safe.
- Do not perform unrelated refactors or overwrite unrelated work.
- Every implementation task must end with a successful build or relevant test run.
- Preserve light and dark appearance support and localise user-facing copy.
