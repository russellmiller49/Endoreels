# High Priority Implementation Roadmap

This roadmap translates the High (H1–H7) initiatives into phased, implementation-ready work packages. Each work package lists new modules, API dependencies, and recommended sequencing.

## Phase 0 – Platform Foundations
- **Create shared modules**
  - `Auth` package (Supabase client, JWT/session management).
  - `Networking` layer with async `APIClient` + request signing.
  - `Persistence` layer (CoreData/SQLite) for caching credits, reels, user progress.
- **Introduce state containers**
  - `AppState` observable storing authenticated user, credits, feature flags.
  - Modular feature coordinators (FeedCoordinator, CreatorCoordinator).
- **Tooling**
  - Set up feature flag framework.
  - Add logging/analytics abstraction to prevent PHI leakage.

## H1 – Secure Auth & Credits
1. **Data Models**
   - Local models: `User`, `CreditBalance`, `CreditTransaction`.
   - API DTOs & codable structs.
2. **Networking**
   - Implement `/api/credits` GET/POST with idempotency headers.
   - Add request middlewares for JWT + Idempotency-Key.
3. **UI/UX**
   - Credits banner component for Creator.
   - `CreditsView` (history list, remaining balance).
   - Inject credit status into AI processing actions.
4. **State Management**
   - `CreditsStore` (fetch, deduct, refund, grant).
   - Admin guard rails in UI.
5. **Testing**
   - Unit tests for CreditsStore idempotency.
   - Snapshot/UI tests for banner & history.

## H2 – First-Run Onboarding & Demo Cases
1. **User Profile**
   - Extend `UserProfile` with `role` enum.
   - Persist onboarding completion.
2. **Coach Marks**
   - Create reusable `OnboardingFlowView` with three cards.
3. **Role Selector**
   - Hook into profile; set default feed filters/creator templates.
4. **Demo Mode**
   - Bundle sample reel assets under `/Demo`.
   - Provide “Start with sample case” CTA linking to Creator.

## H3 – Search & Discovery v1
1. **Search Module**
   - `SearchStore` with debounced autocomplete + paginated search.
   - Integrate with `/api/autocomplete`, `/api/search`.
2. **Filters**
   - Filter chips for Recency, Verification Tier, Difficulty.
3. **Continue Watching**
   - Local progress cache + `/api/continue-watching` integration.
4. **Player Hook**
   - Emit progress events via `/api/progress`.

## H4 – Feed v1 Enhancements
1. **Infinite Scroll**
   - Cursor-based feed store; integrate with `/api/feed`.
2. **Long-Press Preview**
   - Quick peek overlay with cached thumbnail, pearls, duration.
3. **Caching**
   - Prefetch hero & preview metadata.
4. **Haptics & Accessibility**
   - Add haptic feedback + VoiceOver descriptions.

## H5 – Player v1
1. **Step Rail**
   - Timeline component aligned to case steps.
2. **Teaching Pearls Drawer**
   - Collapsible drawer synced to timestamps.
3. **Integrity Banner**
   - Reflect enhancements (stabilization, narration edits, transcripts).
4. **Data Sync**
   - Extend reel metadata to include step timings and enhancement log.

## H6 – Creator Studio v1 Upgrades
1. **Timeline Enhancements**
   - Drag & drop reordering using `EditMode`/custom gestures.
   - Duplicate & bulk delete functionality.
2. **Split Preview Layout**
   - Resizable view with storyboard + video preview.
3. **AI Assist**
   - “Quick Draft” calling `/api/process-video` with scene detection.
   - Enhanced processing behind credit deduction.
   - Show progress checklist (metadata, PHI, quality score).
4. **Refactoring**
   - Extract Step editor components for reuse.

## H7 – PHI Review v1
1. **Unified Queue View**
   - Combine OCR, audio transcript, metadata flags in queue screen.
2. **Confidence Chips & Slider**
   - Visualize detection confidence; provide before/after slider.
3. **Publish Gate**
   - Block publish when `phi_findings` contain unresolved entries (client + server).
4. **API Integration**
   - `/api/phi/{reel_id}` GET/POST, `/api/publish/{reel_id}` with validation.

## Shared Risks & Mitigations
- **Backend availability**: align with Supabase/servless endpoints before UI integration.
- **PHI leakage**: enforce redaction in logs, transcript storage policy.
- **Offline workflows**: cache key data; queue mutations.
- **QA scope**: add instrumentation for performance budgets (fetched < 200 ms, etc.).

## Recommended Sequencing
1. Phase 0 foundations → H1 (credits) → H7 (publish gate) to secure core loop.
2. Parallelize H2 & H3 once auth/backbone stable.
3. Layer H4–H6 after foundational APIs are live.

