---
target: "http://localhost:8080/site/mediadb/learn/ (learner web, rail nav)"
total_score: 20
p0_count: 2
p1_count: 3
timestamp: 2026-09-07T23-01-30Z
slug: localhost-site-mediadb-learn
---
Method: dual-agent (A: critique-A design review · B: critique-B detector + browser evidence)
Target: http://localhost:8080/site/mediadb/learn/ (Flutter web, minsur client, app branch learn-web @ 026ea76, plugin 46beb4a)

## Design Health Score — 20/40 (Acceptable)

| # | Heuristic | Score | Key issue |
|---|---|---|---|
| 1 | Visibility of system status | 2 | 14–20 s cold start on a near-black splash with no wordmark or progress; hero illustration is a blank 165px gap on every cold load |
| 2 | Match system / real world | 3 | Copy is excellent; `CONTINUAR MODO APRENDER` kicker at 9.5px orange over a light illustration (~2.8:1) |
| 3 | User control and freedom | 1 | Browser Back from the root route lands on about:blank; Escape does not pop a pushed screen; reload always resets to Today |
| 4 | Consistency and standards | 1 | All four rail labels carry Flutter's yellow double underline (no Material ancestor); no hover/focus/Back/URL conventions |
| 5 | Error prevention | 3 | Email CTA gated on a valid address; schedule CTA states its precondition. OTP error text persists while retyping |
| 6 | Recognition over recall | 3 | Rail keeps all four tabs visible; at 10px/1.2 tracking they are recognised by shape, not read |
| 7 | Flexibility and efficiency | 1 | No keyboard access, no addressable URLs, no use of width beyond 720px |
| 8 | Aesthetic and minimalist design | 3 | Restrained and premium; side-stripe cards and nested cards on Today/Dashboard; 400–540px voids |
| 9 | Error recovery | 1 | Disabled server accounts surface as "El código no coincide"; no recovery from the Back exit |
| 10 | Help and documentation | 2 | IRIS is the help system; the privacy disclosure is set in t.faint at ~10px (3.9:1) |

## Anti-patterns verdict
Not AI slop: hand-designed, one white CTA per screen, accent semantics enforced. Two absolute-ban patterns survive on Today/Dashboard: coloured side-stripe left borders on the Certificación / Necesita refuerzo cards, and the Calibración de confianza card nesting four bordered sub-cards. Deterministic scan: detect.mjs supports no .dart files; web/index.html is Flutter bootstrap (0 findings, 0 files effectively scanned). Browser overlay impossible: the app renders to canvas (2 canvas/glass-pane nodes, no UI DOM).

## Priority issues
- [P0] Rail labels render with a yellow double underline. TestuFrame is mounted in MaterialApp.builder (lib/main_testu.dart:197) and wraps the rail in a bare ColoredBox (lib/testu/testu_web.dart:40); the app's fallback DefaultTextStyle is the "missing Material" error style whose underline survives the merge. Pixel colour #5F5F07. The phone bottom nav (inside Scaffold) has no underline. Fix: ColoredBox → Material(color: t.bg). The wordmark Text for logo-less clients has the same defect.
- [P0] Browser Back leaves the app (about:blank from the root); no URL per tab or screen; reload resets to Today. Fix: Router with /hoy /temas /iris /dashboard /tema/:id, or minimally a history pushState on tab change plus PopScope.
- [P1] Rail labels are the smallest, lowest-contrast text in the product: 10px GeistMono, t.faint #6B6F78 on #0A0A0B = 3.93:1 (fails AA); ~32px hit height. Fix: 12px, tracking ~1.0, inactive t.mut (6.1:1), vertical padding 12.
- [P1] No hover, focus or keyboard states anywhere: TestuPressable is a bare GestureDetector; MouseRegion used once (cursor only); flt-semantics node count 0. Fix in TestuPressable: hover lift, focus ring, Semantics(button).
- [P1] Phone metrics inside a desktop frame: 396px empty gutter at 1280; 110px bottom padding reserved for a bottom nav that is null on desktop (testu_shell.dart:237,260; testu_dashboard.dart:68; testu_topics.dart:299); IRIS leaves 440px between last message and composer; Dashboard chart 7 bars across 650px. Fix: conditional padding, bottom-align IRIS, per-route width override (Dashboard ~1040).
- [P2] Pinned Today header holds 175px on an 800px window with a 16px fade that lets cards ghost through. Fix: collapse greeting on scroll, deepen fade to ~32px.

## Persona red flags
- Alex (power user): no second-tab/bookmark/share, Back exits, Tab reaches nothing, 1280 shows the same as 700.
- Sam (keyboard/AT): unusable; empty semantics tree; 3 of 4 nav labels below AA; no focus indicator; Escape trapped on pushed screens.
- Ana (ramp agent, desk PC, Lima): 15 s black screen; underlined nav reads as a broken install; blank hero card on cold load; Back makes the system vanish; 600–699px window gets the phone UI with no "get the app" explanation (nudge <600, rail ≥700).

## Minor observations
- OTP error does not clear on re-entry; sign-in screen is a stretched phone (400px dead space, 92px-wide OTP boxes).
- showTestuDialog has no maxWidth: every modal is ~636px wide.
- Schedule dialog mixes four interaction models; "Ahora no" weighs as much as the CTA.
- Topic Home back chevron sits top-right (close-button position on desktop).
- Temas/IRIS/Dashboard have no top padding on desktop (H1 ~14px from the window edge).
- Rail is 29% of a 700px window; phone layout at 690px runs ~100-char lines.
- Zero-value days in the 7-day chart are indistinguishable from missing data.
- Side-stripe borders on Today cards; nested cards in Calibración de confianza.

## Questions
1. If 1280px only centres a phone, what does the desktop build buy beyond the rail? The Dashboard is the one screen that earns width and is the one capped at 720.
2. Is the product TestU Learn or a page at a URL? Without addressable state, managers will share screenshots, not links.
3. Should the desktop frame carry a type-scale multiplier (~×1.15 above 700px), or should one honest size set serve both?
