# SwiftCMS Roadmap

This document outlines the long-term vision, timeline, and risk management strategy for SwiftCMS, as defined in the **Master Plan V2 (February 2026)**.

## Timeline & Milestones ✨🗓️

| Phase | Weeks | Milestone | Key Deliverable |
|---|---|---|---|
| **Wave 1: Foundation** | 1–3 | Server boots with auth + modules + EventBus | Vapor + PostgreSQL + Redis + Auth0 + CMSModule lifecycle + EventBus |
| **Wave 1.5: Admin UI Overhaul** | *Bonus* | Beyond Strapi aesthetics | 7 redesigned templates, 5 phases, snapshot testing |
| **Wave 2: Content Engine** | 4–6 | Functional headless CMS | Content types + REST API + admin panel + media + search + webhooks + DLQ |
| **Wave 3: Production** | 7–10 | Production-grade system | GraphQL + lifecycle states + i18n + caching + security + observability + load tests (6 tasks queued!) |
| **Wave 4: Ecosystem** | 11–14 | Developer platform | SDK codegen + plugins + Strapi migration + versioning + WebSocket + static export + docs |
| **Stabilization** | 15–16 | v1.0.0 release | Bug fixes, performance tuning, documentation review, community launch prep |
| **Post-Launch** | 17–20 | Community growth | Plugin ecosystem seeding, conference talks, hackathon demos, feedback iteration |

## Risk Assessment & Mitigation ⚠️🔮

| Risk | Severity | Probability | Mitigation Strategy |
|---|---|---|---|
| **Dynamic schema performance** | High | Medium | GIN indexes + expression indexes. Materialization path for ultra-high traffic. |
| **Auth provider lock-in** | Medium | Low | `AuthProvider` protocol ships with 3 providers. Environment-only switching. |
| **Merge conflicts** | Medium | Medium | Strict module boundaries; each agent owns a specific library/directory. |
| **Ecosystem maturity** | Medium | High | Use SSWG Graduated packages; raw SQLKit fallback for Fluent gaps. |
| **Maintainer burnout** | High | High | Multi-agent dev momentum; comprehensive docs; plugin architecture for community scaling. |
| **Documentation chaos** | Low | 🪄 **Vanquished!** | AI CODING RULES enchantment cast! All docs now sparkle with emoji magic ✨ |

## Lessons from Prior Swift CMS Projects 📚🦉

SwiftCMS is built on the lessons learned from previous community efforts:

- **Pigeon CMS (2019)**: Learned that compile-time content types were too rigid. SwiftCMS uses **JSONB** for runtime flexibility while maintaining type safety via SDK generation.
- **Feather CMS (2020–2023)**: Adopted the hook-based module system and DTO separation, but avoided repo fragmentation (monorepo approach) and focused on **headless-first** rather than template-first.

**Newly Discovered Wisdom (2026-02-14)** 🧙‍♂️:
- Never anger the Swift Documentation Spirits—they demand proper `///` syntax!
- Token-based authentication requires clear separation of access vs refresh responsibilities
- Every code change is an opportunity for whimsical commentary ✨

## Deferred Features (Post-v1.0) 🌙🗓️
- **SSO / SAML**: Deferred to post-v1.0 (handled by Auth0/Firebase at the provider level for now).
- **Approval Workflow Chains**: Role-level permissions sufficient for MVP.
- **Collaborative Editing**: CRDT/OT complexity deferred.
- **Serverless (Lambda)**: Blocked on upstream Swift-on-Lambda maturity for the full CMS stack.
- **SwiftUI Native Admin**: Web admin (HTMX) prioritized for accessibility.

**Not Deferred (Just Completed!)** 🎉:
- ✅ Emoji-rich code comments (everywhere!)
- ✅ Magical error handling with whimsical prose
- ✅ AI CODING RULES codified into our development grimoire
