# EndoReels Feature Specification

## North Star Principles
1. **Clinical fidelity over flash**: edits must never misrepresent anatomy, timing, or outcomes. Enhancement is allowed; manipulation is not.  
2. **Speed to first draft**: clinicians should get a polished storyboard in minutes between cases.  
3. **Structured by default**: every edit enriches metadata for search, CME, and curation.  
4. **De-identification woven into creation**: PHI is surfaced and fixable during editing—before export/publish.  

---

## Core Features

### A. Ingest & Media Management (mobile first)
- Secure import of scope clips, room captures, CT/fluoro stills, pathology images.  
- One tap import from device gallery, Files/Drive, or institutional upload link.  
- Lossless capture of originals to a Quarantine container; local proxy generation (e.g., 540p) for editing.  
- Smart preprocessing: frame rate normalization (30 fps), audio normalization, time zero alignment if multiple clips belong to one case.  
- Batch ingest assistant detects similar clips and suggests stitching.  

**Why it matters:** Reliable, fast handling of large surgical videos without draining resources.  
**How to implement:** Local proxy creation, perceptual hashing (pHash), sanitized metadata storage.  

### B. Storyboard & Timeline Editing
- Two-axis UI (vertical = case, horizontal = steps).  
- Magnetic timeline with scrubber and keyframe snapping.  
- Step templates (Diagnostic bronchoscopy, EBUS staging, GI bleeding control).  
- Scene change detector suggests cut points.  
- Step notes + 1–2 key takeaways per step.  

**Why it matters:** Keeps viewers oriented and supports fast structured teaching.  
**How to implement:** Server-side scene detection; annotations surfaced in UI.  

### C. Cutting, Speed & Timing Tools
- Ripple trim & join with crossfade.  
- Speed ramping with audio ducking or mute.  
- Freeze frame with caption.  
- Loop segment for emphasis.  

**Why it matters:** Concise reels without losing teaching value.  

### D. Picture in Picture (PiP), Split Screen & Side by Side
- PiP overlays (e.g., endoscopy + fluoro).  
- Split screen 50/50 or 70/30 with sync.  
- Before/After slider.  

### E. Annotation Suite (Clinically Tuned)
- Timed callouts (text, arrows, circles).  
- Spotlight/magnifier zoom.  
- Label presets from controlled vocabularies.  
- Checklists & counters (stations sampled, complications).  
- Color-blind friendly defaults.  

### F. Audio: Narration, Cleanup & Captions
- One-tap narration per step, retakes supported.  
- Noise reduction, de-ess, loudness normalization.  
- Script helper with AI TTS fallback.  
- Captions with editor + WebVTT export.  

### G. De-identification Embedded in Editing (Safety by Design)
- PHI heatmap via OCR/NER.  
- Auto-tracked blur for faces/logos.  
- Audio PHI scan with bleep/replace.  
- Metadata scrub preview.  

### H. Layout, Aspect Ratio & Branding
- Smart 9:16 framing.  
- Title cards and metadata ribbons.  
- Canvas backfill for consistency.  

### I. Visual Enhancement (Fidelity Safe)
- Stabilization, deflicker, denoise.  
- White balance/exposure correction.  
- Guardrails on sharpening.  

### J. Templates, Macros & Case Blueprints
- Procedure templates.  
- Reusable annotation packs.  
- Author macros for batch actions.  

### K. Quality Control & Polishing
- Black/freeze/duplicate frame detection.  
- Exposure/contrast analyzer.  
- Loudness & clipping meters.  
- Pre-publish checklist (consent, PHI cleared, captions, tags).  

### L. Collaboration, Review & Versioning
- Share drafts with private review links.  
- Time-coded comments and pin/resolve.  
- Version snapshots with restore/compare.  

### M. Rendering & Export (Fast and Consistent)
- Proxy edit → server render.  
- HLS ladder for streaming.  
- Archival master retention.  
- Export: MP4, PDF storyboard, PowerPoint deck.  

### N. Accessibility & Inclusivity
- Tap to replay, long press slow mo.  
- Captions default on.  
- High contrast themes.  

### O. Performance & UX Polish
- Instant scrubbing, haptics.  
- Gesture controls.  
- Autosave with offline resilience.  
- Undo/redo stack.  

---

## Guardrails (Clinical Integrity)
- Integrity mode caps sharpening and grading.  
- Disclosure ribbons auto-inserted if stabilization/speed ramping used.  
- Export watermark with author, verification tier, date.  

---

## Suggested Default Presets
- Project: 1080×1920, 30 fps.  
- Cuts: hard cut; 150 ms crossfade.  
- Audio: AAC 48 kHz, −16 LUFS target.  
- Titles: 2.0 s; freeze frame ≤ 1.5 s.  
- Annotations: appear 0.2 s after step start.  

---

## Build Sequencing
1. **MVP spine**: trim/split, title cards, narration, captions, proxy edit → render.  
2. **Annotations & safety**: arrows/text, PHI detection/masking.  
3. **Multimodal**: PiP, side by side, scene assist, speed ramping.  
4. **Templates & macros**: reusable packs, QC analyzers, export to PDF/PPT.  
5. **Enhancements & polish**: stabilization, magnifier, before/after slider, offline resilience.  

---

# Extended Feature Specifications

## 1. Pro Level Timeline Editing
Features include frame-accurate edits, ripple/roll/slip/slide operations, markers, A/B loop, speed ramping, freeze frames, duplicate detection.  
Acceptance: proxy parity, undoable gestures, fast render.  

## 2. Storyboard (Steps that Teach Clearly)
Features: step templates, scene cut assist, thumbnails, reordering, time-boxed steps.  
Acceptance: 5-step storyboard from 2–3 min clip in ≤3 min.  

## 3. Clinical Annotation & Tracking
Features: timed callouts, optical flow object lock, magnifier, before/after slider, measurement tools, style presets.  
Acceptance: annotation stability within 12 px of target.  

## 4. Multimodal Layouts
Features: PiP, side-by-side, modality sync.  
Acceptance: layouts preserve sync and captions.  

## 5. Audio, Narration & Captions
Features: narration with retakes, DSP cleanup, ASR captions, HIPAA TTS fallback.  
Acceptance: WER ≤10%, audio level consistency.  

## 6. De-identification as Safety by Design
Features: PHI heatmap, mask brush with auto track, audio PHI scan, metadata scrub, publish gate.  
Acceptance: masks persist ≥90% frames.  

## 7. Clinical Integrity Guardrails
Features: integrity mode, disclosure ribbons, effect whitelist.  
Acceptance: block excessive edits.  

## 8. Templates, Macros & Libraries
Features: blueprints, annotation packs, author macros.  
Acceptance: first-time author ships EBUS case in ≤10 min.  

## 9. Review, Versioning & Collaboration
Features: review links, time-coded comments, snapshots.  
Acceptance: 10 comments in <60 s.  

## 10. QC “Linting” & Pre-Publish
Features: detects long silences, clipped audio, small text, low contrast, missing captions.  
Acceptance: ≤3 warnings before publish.  

## 11. Performance, UX & Ergonomics
Features: proxy workflow, gestures, shortcuts, autosave.  
Acceptance: cold open ≤1.5 s, scrubbing latency ≤50 ms.  

## 12. Export & Deliverables
Features: deterministic render, archival master, PDF/PPT exports, watermarks.  
Acceptance: checksum reproducibility.  

## 13. Clinical Overlays (IP & GI)
Features: EBUS lymph node maps, device libraries, complication tags.  
Acceptance: selecting a station auto-tags case.  

---

# Backlog Summary
| Priority | Area        | Feature                                  | Notes                          |
|----------|------------|------------------------------------------|--------------------------------|
| P0       | Timeline    | Frame accurate edits, markers, A/B loop  | Foundation for all edits        |
| P0       | Storyboard  | Step templates, scene assist, chapter    | Drives structure & speed        |
| P0       | Safety      | PHI heatmap, mask brush, publish gate    | HIPAA by default                |
| P0       | Audio       | Narration, cleanup, captions editor      | Professional sound              |
| P1       | Annotations | Object tracking, magnifier, style presets| Clinical clarity                 |
| P1       | Multimodal  | PiP, split screen, modality sync         | Correlating modalities          |
| P1       | QC          | Linting, auto fix, disclosure ribbons    | Consistency & trust             |
| P2       | Templates   | Blueprints, macros                       | Scale educator output           |
| P2       | Review      | Time-coded comments, versioning          | Society workflows               |
| P2       | Ergonomics  | Gestures, shortcuts, offline drafts      | Day-to-day comfort              |
| P2       | Overlays    | EBUS maps, device libraries              | Specialty delight               |

---

# Developer Handoff Notes
- **Data model**: annotations = vector objects; masks = polygon + keyframes; steps = ordered clips with metadata.  
- **Render contract**: recipe JSON defines all edits; server renderer enforces deterministic outputs.  
- **Testing**: golden reference renders for canonical cases; audio loudness checks; PHI red team set.  
