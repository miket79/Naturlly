// Checkpoint: Before Long Audio Integration (synthesizeLongAudio)

// Date: 2026-01-01

// This checkpoint captures the current state and key files involved before integrating Google Cloud Text-to-Speech v1beta1 long audio (synthesizeLongAudio) flow.

// Key files and roles:

// - LibraryView.swift
//   - Document library UI (selection, deletion, navigation)

// - ContentView.swift
//   - Main UI for TTS generation, section playback, book mode, caching
//   - Calls GoogleTTSService.synthesizeSpeech for audio generation

// - GoogleTTSService.swift
//   - Current short/long text TTS via classic v1 endpoint (chunking + merge)

// - GeminiTTSService.swift
//   - Alternative TTS via Generative Language API (not currently wired in UI)

// - NaturalLanguageService.swift
//   - Optional text analysis to adjust speaking rate and pitch

// - AudioPlayerManager.swift
//   - Playback management and Now Playing integration

// - Any other files indirectly referenced by above should remain unchanged by upcoming edits.

// Planned changes (high level):
// - Add a new service for v1beta1 synthesizeLongAudio (job-based, GCS output) or client stub to call backend.
// - Minimal UI hooks to trigger long-audio path (behind a flag or automatic for large texts).
// - No changes to existing GoogleTTSService behavior unless explicitly toggled.

// Rollback plan:
// - Revert to this checkpoint by discarding new files and reverting edits in the files listed above.
// - This file exists solely as a marker; no functional changes were made at this point.
