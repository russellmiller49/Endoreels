EndoReels — Master Implementation Plan (Prioritized)

Purpose: One master document that describes what to build and how it should work (at a product + technical level), ranked into High, Moderate, and Low priority. This is implementation‑ready vision (not code).

⸻

0) Product North Star

Mission: A safe, fast, and credible platform for creating and sharing short, step‑wise endoscopic teaching cases—optimized for trainees and teaching attendings—where clinical integrity and privacy are first‑class.

Core loop: Discover → Watch → Create → PHI Review → Publish/Share → Learn.

User roles:
	•	Learner (student/resident/fellow): consumes, searches, saves, quizzes.
	•	Educator (attending/faculty): creates, annotates, exports, moderates.
	•	Admin (you + trusted reviewers): verifies users, grants credits, audits, moderates.

Guiding principles:
	•	Safety by design (no publish with unresolved PHI, clear integrity indicators).
	•	Time‑to‑value (sample cases, quick creation templates, resume watching).
	•	Offline‑friendly (ORs, poor connectivity).
	•	Privacy‑preserving analytics (no PHI in logs; minimal necessary telemetry).

Non‑functional standards (apply to all priorities):
	•	Scroll and playback at 60 fps on recent iPhones; no hard UI jank.
	•	Viewer plays in < 1.5 s after tapping a case (from warm cache).
	•	All write endpoints derive identity from verified JWT (never from client payload).
	•	Files at rest use NSFileProtectionComplete; cloud vendors hold de‑identified data only until BAAs exist.
	•	RLS on all user‑scoped tables.

⸻

1) HIGH PRIORITY (TestFlight‑ready)

These features establish a credible, safe MVP and the measurable learning/creation loop.

H1. Secure Auth + Credits (Must‑Fix Foundation)

Goal: Make AI‑assisted processing safe and predictable to operate.

What:
	•	Server verifies Supabase JWT, derives user_id. Ignore client user_id.
	•	Credit deduct is idempotent (Idempotency‑Key header).
	•	Refund requires a matching debit (same reel_id).
	•	Admin actions (grant) require JWT‑verified admin user in admin_users.
	•	Audit log on every credit mutation with reason, tier, idempotency key.

UX:
	•	Credits banner in Composer and a dedicated “AI Credits” view (remaining, history).
	•	Clear cost labels: Quick (Free), Enhanced (1 credit).

Data/API:
	•	Tables: user_credits, credit_transactions, admin_users.
	•	Endpoints: /api/credits, /api/process-video, /api/admin/grant-credits.
	•	Events: deduct_success, refund_success, processing_failed.

Definition of Done (DoD):
	•	Double‑tap of “Process” never double‑charges.
	•	Non‑admin cannot grant.
	•	All mutations are visible in a user’s transaction history within seconds.

Risks/Mitigations:
	•	Risk: Retries charge twice → Mitigation: Idempotency + unique index on (user, idempotency_key).
	•	Risk: Logging PII → Mitigation: No media URLs or transcripts in logs.

⸻

H2. First‑Run Onboarding + Demo Cases

Goal: Eliminate blank‑screen friction and orient each role.

What:
	•	3‑screen coach marks (Create, PHI Review, Discover).
	•	Role selector (Learner / Trainee / Educator) → sets default feed facets and creator template.
	•	Demo Mode with three bundled sample reels to touch end‑to‑end.

UX:
	•	“Start with a sample case” CTA visible on first launch.
	•	Role badge on profile; editable later.

Data/API:
	•	user_profile.role (enum).
	•	Local sample assets packaged under /Demo.

DoD:
	•	First‑time user can open a sample case in ≤ 2 taps, and reach the creator in ≤ 3.

⸻

H3. Search & Discovery v1 (Autocomplete + Filters + Continue Watching)

Goal: Get learners from intent → watching in seconds.

What:
	•	Autocomplete for titles and tags (anatomy, pathology, device, procedure).
	•	Filter chips: Recent, Verification Tier (Gold/Blue), Difficulty.
	•	“Continue Watching” shelf (resume position).

UX:
	•	Search bar with inline suggestions grouped by category.
	•	Chips persist at top of results.

Data/API:
	•	FTS index on reels; tags and reel_tags; user_progress.
	•	Endpoints: /api/autocomplete, /api/search?q=&filters=, /api/continue-watching, /api/progress (POST).

DoD:
	•	Typing “EBUS” shows suggestions in < 200 ms (warm cache).
	•	Resume restarts within 1 s at prior position.

⸻

H4. Feed v1 (Infinite Scroll + Long‑Press Preview)

Goal: Browsing feels modern and informative without navigating away.

What:
	•	Infinite scroll feed (time‑based cursor).
	•	Long‑press Quick Peek: title, thumbnail of step 1, top 2 teaching pearls, duration.

UX:
	•	Haptic feedback on long‑press; swipe to dismiss preview.

Data/API:
	•	GET /api/feed?cursor= returns compact card data + precomputed preview.

DoD:
	•	No pagination buttons; no visual reflows.
	•	Preview opens in < 200 ms with cached thumbnail.

⸻

H5. Player v1 (Step Rail + Teaching Pearls + Integrity Banner)

Goal: Turn passive viewing into structured learning.

What:
	•	Bottom step rail (scrubbable), haptics on step boundaries.
	•	Collapsible Teaching Pearls drawer tied to timestamps.
	•	Clinical Integrity banner whenever visual/audio enhancements are applied.

UX:
	•	Tap a pearl → seek to timestamp; subtle callout the first time.

Data/API:
	•	Case metadata includes steps {start_s, end_s, title}.
	•	Enhancements log {type, parameters} serialized per reel.

DoD:
	•	Seeking to step is instant; pearl tap jumps precisely.
	•	Integrity banner always reflects current playback settings.

⸻

H6. Creator Studio v1 (Drag‑Drop + Duplicate + Split Preview + AI Assist)

Goal: Lower the barrier to publish high‑quality cases.

What:
	•	Drag‑and‑drop step reordering.
	•	Duplicate step; bulk delete multiple steps.
	•	Split Preview (timeline ↔ player).
	•	Quick Draft (scene detection → step suggestions).
	•	Enhanced (AI metadata/pearls) behind credit.

UX:
	•	Side checklist: Metadata completeness, PHI review, quality score (progress).
	•	Clear “Process Free / Process with 1 credit” actions.

Data/API:
	•	Steps array persisted with order index.
	•	/api/process-video returns scenes, suggested titles, pearls.

DoD:
	•	Reordering feels instant; suggestions insert correctly; Enhanced deducts once.

⸻

H7. PHI Review v1 (Single Queue + Confidence + Publish Gate)

Goal: Make privacy review unavoidable and efficient.

What:
	•	One PHI queue combining OCR, audio transcript, and metadata flags.
	•	Confidence chips (High / Medium / Low).
	•	Before/After slider for each finding.
	•	Publish Gate: cannot publish until all findings are resolved (Redacted or False Positive).

UX:
	•	“Resolve all to publish” summary bar; tap jumps to next unresolved.

Data/API:
	•	phi_findings with status enum; server refuses publish if any open.
	•	Endpoint: GET/POST /api/phi/{reel_id}; POST /api/publish/{reel_id} enforces gate.

DoD:
	•	Attempting to publish with open findings fails server‑side and explains why.
	•	Slider visually confirms redaction.

⸻

H8. Offline Playback + Resume

Goal: Support OR/clinic realities.

What:
	•	Download case proxy for offline viewing; show “Downloaded” badge.
	•	Resume position across online/offline.

UX:
	•	“Available offline” indicator; manage storage (delete downloads).

Data/API:
	•	Local secured cache; user_progress syncs when online.

DoD:
	•	Playback works in Airplane Mode; resume persists after relaunch.

⸻

H9. Dark Mode + Accessibility Pass

Goal: Professional polish and inclusivity.

What:
	•	Full dark mode; large tap targets; VoiceOver labels; Dynamic Type; Reduce Motion.

DoD:
	•	All core flows pass contrast AA; key controls have accessibility labels and traits.

⸻

H10. Privacy‑Safe Analytics & Observability (Minimum)

Goal: Understand usage without risk.

What:
	•	Event counters (view_start, view_complete, like, save, resume, download).
	•	No raw media/transcripts/PII in logs.
	•	Basic health metrics: API p95 latency, failure rate.

DoD:
	•	Dashboard (even simple) shows adoption and failure hotspots; no PHI passes through.

⸻

H11. Admin Panel (Verification + Credits)

Goal: Operate the alpha effectively.

What:
	•	View users (email, created_at, credits_remaining, used_total).
	•	Grant credits to selected users; view recent transactions.

DoD:
	•	Non‑admin cannot access; actions reflected in transaction logs.

⸻

2) MODERATE PRIORITY (High value, not essential for MVP)

These extend learning depth, creation comfort, and content quality. Build after the High set is solid.

M1. Saved Searches & Collections
	•	What: Save filter combos; build Collections (e.g., “Difficult EBUS”).
	•	UX: “Save search” star; “Collections” in Knowledge Hub.
	•	DoD: One‑tap apply; shareable collection links (internal).

M2. Trending & Related Cases
	•	What: “Trending this week” from engagement; “Cases like this” via tag similarity (Jaccard).
	•	DoD: Obvious variety; no single account dominates.

M3. Creator Media Tools (Batch import + Quick Trim + Tagging)
	•	What: Multi‑select import; thumbnails with durations; pre‑timeline trims; asset tags (anatomy/device).
	•	DoD: Time from import → organized timeline drops meaningfully.

M4. Annotation Track v1 (Library + Time‑synced)
	•	What: Save/reuse common callouts; timeline track indicates annotation spans; undo/redo.
	•	DoD: Drag to adjust timing; library appears across cases.

M5. Collaboration v1 (Private Share + Comments)
	•	What: Invite individuals to view/comment on drafts; threaded comments pinned to timestamps.
	•	DoD: Comment notifications in‑app; resolve/mark addressed.

M6. Quizzes (Non‑CME) & Learning Paths
	•	What: 3–5 MCQs tied to a reel; lightweight paths by difficulty.
	•	DoD: Completion confers badge; wrong answers show teaching pearls.

M7. Export to PowerPoint/PDF with Notes
	•	What: Auto‑generate deck/report with steps, pearls, and PHI audit appendix.
	•	DoD: Opens in Keynote/PowerPoint/Preview with correct ordering and speaker notes.

M8. Moderation Tools (Flag Review + Verification Tiers)
	•	What: Flag queue; verify clinicians (Blue/Gold) with simple checklist; remove/restore content.
	•	DoD: SLA on flags; visible verification check on content.

M9. Rate Limiting & Cost Controls
	•	What: Per‑user daily cap for Enhanced; server‑side throttles to protect spend.
	•	DoD: Friendly errors; no burst drains credits.

M10. “Institution Mode” Foundation
	•	What: Workspace concept (org‑scoped library, roles); not full SSO yet.
	•	DoD: Content visibility scoped to workspace or public.

M11. Performance Work (Prefetch + Proxies + Memory)
	•	What: Predictive prefetch of next case; ensure proxy generation for consistent decode load; memory audits.
	•	DoD: Lower abandonment on cell networks; fewer OOMs.

⸻

3) LOW PRIORITY (Strategic / advanced)

Pursue once the platform is sticky and institutional needs emerge.

L1. CME Integration (ACCME‑aligned)
	•	Certificates, objectives, post‑viewing assessments, audit trails.

L2. SSO, EMR Links, DICOM Export
	•	Hospitals’ IdPs, de‑identified EMR references, imaging exports with metadata.

L3. Real‑time Co‑editing & Version Control
	•	Multi‑author edit sessions; diff/rollback.

L4. Advanced Annotations & Measurements
	•	Rulers/diameters, heat maps, measurement logging.

L5. AR/3D/Multiview
	•	CT reconstructions, multi‑angle sync, AR overlays.

L6. Translation & Voice‑over
	•	Multilingual captions; synthetic voice with localization.

L7. Gamification at Scale
	•	Leaderboards, challenges, mentorship matching, study groups.

L8. Institutional Branding & Compliance Reports
	•	White labeling, granular usage/competency exports.

⸻

4) Cross‑Cutting Requirements (applies to all tiers)

Security & Privacy
	•	JWT‑derived identity on server; never trust client user_id.
	•	All user‑scoped tables RLS‑protected.
	•	No PHI in logs; redact before persistence; vendors without BAA handle only de‑identified assets.
	•	Server‑enforced Publish Gate: zero open PHI findings required.
	•	Idempotency for any chargeable operation; audit every mutation.

Accessibility
	•	Dynamic Type, VoiceOver labels, Reduce Motion alternatives, high contrast modes; touch targets ≥ 44pt.

Observability
	•	Privacy‑safe events (no PHI): view_start, view_complete, like, save, resume, download, publish_attempt, publish_blocked_phi, process_started/succeeded/failed.
	•	Backend metrics: p95 latency per endpoint, error rate, queue depth (processing).

App Quality
	•	Snapshot tests for Feed, Player, PHI Review, Creator.
	•	“Safety tests” that attempt publish with unresolved PHI, missing consent, or insufficient credits.

⸻

5) Dependencies & Build Order (no dates)
	1.	H1 Secure Auth + Credits → prerequisite for Enhanced processing and Admin Panel.
	2.	H2 Onboarding/Demo → unblocks meaningful first use of Feed/Player/Creator.
	3.	H3/H4/H5 Search/Feed/Player → core consumption experience.
	4.	H6 Creator Studio v1 → authoring value; integrates H1.
	5.	H7 PHI Review v1 → mandatory safety gate; blocks H6 publish.
	6.	H8/H9/H10 Offline, A11y, Observability → reliability & polish.
	7.	H11 Admin Panel → operations.
	8.	M‑tier features layer on top (Saved searches, Related, Media tools, Collaboration, Quizzes, Export…).
	9.	L‑tier follows proven stickiness and institutional demand.

⸻

6) Acceptance Criteria (global)
	•	Safety: It is impossible (client and server) to publish a case with any unresolved PHI findings.
	•	Integrity: Any applied visual/audio enhancement is clearly disclosed during playback.
	•	Performance: Feed scroll and player scrubbing are smooth; typical case opens quickly from cache.
	•	Usability: A first‑time learner reaches a relevant case in under 15 seconds; an educator creates a draft with steps in under 5 minutes using Quick Draft.
	•	Operability: Credits are predictable, transparent, and reversible only under controlled conditions (refund rules); admin tasks are auditable.

⸻

7) Appendix – Minimal Data Entities (for shared language)
	•	Reel: id, title, abstract, duration, verification_tier, difficulty, integrity_flags, published_at.
	•	Step: reel_id, index, title, start_s, end_s, overlay_annotations[].
	•	Tag: id, name, kind (anatomy/pathology/device/procedure).
	•	ReelTag: reel_id, tag_id.
	•	PHIFinding: reel_id, kind (ocr/audio/metadata), start_s, end_s, bbox[], text_snippet, confidence, status (open/redacted/false_positive), resolved_by, resolved_at.
	•	UserProgress: user_id, reel_id, position_seconds, updated_at.
	•	UserCredits: user_id, credits_remaining, credits_used_total, last_granted_at.
	•	CreditTransaction: user_id, amount, balance_after, reason, reel_id, processing_tier, idempotency_key, metadata, created_at.
	•	UserEvents: user_id, reel_id, event, created_at.
	•	UserProfile: user_id, role (learner/trainee/educator/admin).

⸻

Final note

If you drop this file into /docs/master-implementation-plan.md, it can serve as the source of truth for product, design, and engineering. The High section is your TestFlight bar; Moderate extends depth once the loop is sticky; Low captures strategic horizons without distracting the MVP.