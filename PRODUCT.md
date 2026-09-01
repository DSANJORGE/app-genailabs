# TestU Learn (app-genailabs)

Flutter prototype of **TestU Learn** — an AI-tutored workplace learning app,
demoed as **Vueling ground operations** training. Built on the EME app
structure; the durable design source is the Traycer artifact
`testu-learn-design-spec` (final, from prototype v6, 2026-08-29).

## Register

product — app UI. Design serves the product.

## Users & purpose

- Learner persona: **Ana Ruiz**, Ramp Agent (Safety Lead track), BCN.
  Uses the app on her phone, on shift breaks, often outdoors/in transit.
- Tutor persona: **Sully** (org-configurable). Every screen shows Sully or
  IS a conversation with Sully; sessions are chats.
- Purpose: evidence-based mastery of safety-critical role knowledge, with
  confidence calibration (misconception = incorrect-while-certain is the
  headline finding).

## Brand personality

**Corporate-premium, never Duolingo.** MasterClass restraint: near-black
surfaces, photography-led, hairlines, muted palette, subtle haptics. Zero
emoji, zero confetti, no gamification chrome.

### The five laws (non-negotiable, every screen)

1. One white CTA per screen — the adaptive recommendation; all else quiet
   bordered ghosts.
2. Corporate-premium, never Duolingo.
3. Mastery is labels, never bare numbers ("Competent · Review soon");
   concrete counts fine, abstract scores never.
4. Sully is present everywhere; sources always cited, source links blue.
5. Ends with meaning, not a score — interpretation first, every metric
   explainable.

## Anti-references

Duolingo (chunky/3D/streaks), generic SaaS dashboards, emoji-forward
learning apps.

## System facts

- Fonts: Sora (display), Geist (UI), GeistMono (labels/eyebrows/numbers).
- Tokens live in `lib/testu/testu_theme.dart` (`TestuTokens`); shared
  widgets in `lib/testu/testu_widgets.dart`.
- Bilingual EN/ES via `L(en, es)` + gendered Spanish via `G(masc, fem)`
  (`lib/testu/testu_i18n.dart`); Spanish runs ~20–30% longer — every
  layout must survive it.
- Bottom nav: translucent blurred bar, mono uppercase labels, 2px orange
  tick, no icons. Bottom sheets are the universal flow container.
