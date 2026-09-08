# Minsur pilot readiness: sync, IRIS, no mock content, social notifications, web

Date: 2026-09-07. Status: approved 2026-09-07. Ponytail mode full.

Decisions taken (2026-09-07, "go with recommendations"):

1. Server boundary is plugin-only. Anything under `eme-plugin-testu` (templates, groovy services, field xml, lists, events) is ours to ship. Java skills in `eme-server-minsur` belong to EnterMedia; changes there become a written request, never a local edit.
2. Question reports get wired through the plugin, not hidden.
3. Sequencing (revised 2026-09-07, user: "all of this must go"): parts A to E all ship in the first store build. The store submission slips as needed; Part A is still done first so a build can be cut at any point.

## Scope

Four Flutter surfaces share one repo: mobile learner app (`lib/main_testu.dart`), learner web (`app-genailabs-learn-web` worktree, branch `learn-web`, same entry point), admin console (`lib/main_admin.dart`). One server plugin (`eme-plugin-testu`) feeds all three.

Out of scope, stated so nobody waits for it: push notifications to the OS (FCM/APNs), IRIS posting inside social threads, mention autocomplete while typing, notification preferences, Vueling demo changes (every live change stays behind `testuLive`).

## Part A: no mock content in the live build

Rule: in a live build every string, number and image on screen comes from the signed-in user, the server, or a neutral fallback that admits it has no data. Nothing invented.

| Site | Today | Change |
|---|---|---|
| `testu_client.dart:99-107` persona/personaFull/personaAvatar | hardcoded "Diego" | top-level `testuFirstName` / `testuFullName` getters in `testu_live.dart`: live reads `AuthService.currentUser` (`firstName`, `lastName`, `displayName`), demo keeps persona. Six call sites (splash, shell, tutor, session, profile, social) switch to the getters. Avatar live: initials circle, no preset photo. |
| `testu_profile.dart:469-473`, `:341-348` | invented job title, certification status | Live shows email and team from `personas/me.json`; certification block hidden. |
| `testu_shell.dart:296`, `testu_dashboard.dart:320-323`, `testu_tutor.dart:210-213` | "Minsur · Lima", "PREPARACIÓN DEL ROL · OPERACIONES", "Tutor Minsur Operaciones" | Live: organisation name from `tutorpersona.organization` (already returned by `me.json`); role eyebrow removed; tutor header = persona name only. |
| `testu_shell.dart:502-508`, `testu_topics.dart:145,255` | mine hero and aviation covers as fallbacks | Neutral cover: flat colour block with the topic initial. No photo fallback live. |
| `testu_topics.dart:908` | `required: true` on every live resource | Show the badge only when the server says so; today it never does, so omit it live. |
| `testu_tutor.dart:79-90,254-274` | progress load fails silently | Same error card and "Reintentar" pattern as `_LiveTopics`. |
| `testu_tutor.dart:236-239` | "siempre citan sus fuentes" | Copy becomes a promise we keep: "Responde con la fuente cuando la encuentra; si no la encuentra, te lo dice." |
| `testu_signin.dart:241` | hint `ana.ruiz@minsur.com` | Hint `correo@empresa.com`. |
| `testu_lock.dart:339` | "Bienvenida" | Neutral "Hola, {firstName}". |
| `testu_question_source.dart:79` | default topic "Seguridad en rampa" | Live default is the tutorial name or "Tema". |
| `testu_i18n.dart:32` `G()` | masculine Spanish for everyone (demo `gender: 'm'`) | Live returns the neutral slash form ("seguro/a"); accounts carry no gender field. |
| `build_store.sh` | no privacy URL | `--dart-define=TESTU_PRIVACY_URL=…` once the page exists; until then the row stays hidden, which the code already does. |

Verification: rebuild both store artifacts with `build_store.sh`, run the existing string scan for demo names ("Diego", "Ana Ruiz", "Lima", "rampa", "OPERACIONES") against the built bundle, sign in as the test learner and walk the four tabs and the profile in the simulator. pbxproj back at `objectVersion = 60` before finishing.

## Part B: IRIS, short, sourced, honest

### Prompt (plugin override)

New file `eme-plugin-testu/html/ai/default/calls/chat_tutor_usercomment.json`. It overrides the server default because the resolution order ends at `/ai/default/calls/`. Same variables the skill already fills (`${lesson}`, `${refs}`, `${learnerprompt}`), same `response_format` `{message}`, so no Java change.

Rules in the system prompt, mirrored from the console's `analytics_ask.json` which already works:

- Speak as the tutor persona (name and greeting from `tutorpersona`; the `personality` field is finally used, injected as one line).
- Two or three sentences, never more than 60 words. One idea per reply. End with at most two short follow-up offers, each on its own line prefixed `>> `.
- Every factual claim carries a citation in the existing app grammar `[Título, p. N]` or `[Título, m:ss]`, taken only from `${refs}`. Never invent a title or page.
- If `${refs}` does not support the answer, reply exactly with the sentence "No lo encuentro en las fuentes de este tema." plus one follow-up offer. No guessing.
- Spanish, tutor register (tú), no emojis, no headers.

Because the skill only forwards `message`, the follow-up lines and the not-found sentence ride inside `message`; the app recognises them the same way it already recognises `[[hl …]]` and `> quote`.

### App (`testu_session.dart`, `testu_sully.dart`)

- Parse `>> ` lines into follow-up chips under the bubble; tapping sends that text as the next question. The learner asks for more instead of getting more.
- Recognise the not-found sentence and render it in the unsourced style (no source block, muted).
- A reply that carries no citation and is not the not-found sentence renders with a small "Sin fuente" label. It is shown, never hidden.
- Distinct failure lines: no connection, server error, timeout after 90 s. Late replies still append.
- Resources sheet gets the same 90 s timeout and error line; today it can wait forever.

### Speed

Speed lives in EnterMedia's skill (RAG call, breaker, model). Our levers: shorter output cap in the template (fewer tokens to generate), the 90 s ceiling with an honest line, and a written request to EnterMedia for two changes in `AdaptiveTutorialUserCommentSkill.java`: verify citations against `${refs}` before returning, and scope the 30 minute breaker per tutorial instead of JVM-wide. Request text is a deliverable of this spec; it does not block the build.

### Data on screen

Wherever the app shows IRIS "saying" something outside a chat (Today card, tutor tab header, empty states) the text is a fixed template filled from real data (progress, last topic, last question) or omitted. No generated copy outside the chat.

## Part C: learner data sync gaps

State today: answers, mastery, usage events and IRIS questions already sync. Missing: IRIS history read-back, question reports, social threads, notifications.

### C1. IRIS history

`tutorhistory.json` already returns the channel's messages. The IRIS tab loads the last 50 on open, so a learner switching between phone and web sees the same conversation.

### C2. Question reports

New plugin entity `questionflag` (`data/fields/questionflag.xml`): id, user, datecreated, entitytutorial, entityquestion, reason (list `questionflagreason`: wrong, unclear, outdated, other), note, status (open, resolved). Endpoint `services/testu/social/flag.json` saves one row. `reportFlag` in `testu_question_source.dart` posts to it; the report sheet copy becomes "Enviado al equipo de contenido". Console: the question row in the reading screen shows an open-flag count; resolving is a later console task.

### C3. Social threads (question conversations and topic reviews)

Reuse the server's chatterbox: one channel per question (`q-<entityquestion>`) and per topic review (`t-<entitytutorial>`). A comment is a `chatterbox` row (`message`, `user`, `replytoid` for replies, `date`). A reaction is a `chatterboxreaction` row (`messageid`, `user`, `name` = like, applause, support, love, idea, laugh).

Plugin endpoints under `services/testu/social/`, all learner-visible (`<permission name="view"><user/></permission>` like `usage/track`):

| Endpoint | Does |
|---|---|
| `thread.json?channel=` | Comments with author name, role badge (learner, instructor, tutor), reactions grouped, my reaction. |
| `comment.json` | Saves a chatterbox row. Body: channel, message, replytoid, mentions[] (user ids chosen from the picker). Creates notifications (see D). |
| `react.json` | Toggles a reaction (same logic as `ChatModule.toggleReaction`, rewritten in groovy so we do not depend on the websocket module). Creates a notification for the comment author. |
| `mentionables.json` | Learners in my team plus instructors and managers: id, display name. Feeds the `@` picker. |

App: `TestuComment` gains `id`, `userId`, `date`; `TestuThread` takes a `channel` and loads from `thread.json` when live, mock list when demo. Composer gains an `@` button that opens the mentionables list and inserts `@Nombre`; the picked ids travel in `mentions[]`, so the server parses nothing. Review tab and `SocialThreadEntry` become visible live again once this lands.

Console: new screen `admin_threads.dart` ("Conversaciones"): recent comments across the manager's scope, open a thread, reply, react. Same endpoints, role badge from `userprofile.settingsgroup`. This is the only way an instructor or manager replies.

## Part D: notifications

### Server

New entity `learnernotification` (`data/fields/learnernotification.xml`): id, user (recipient), datecreated, type (list `learnernotificationtype`: reply, mention, reaction, tutorreply), actor (user id), actorname, text (one line), channel, messageid, entitytutorial, entityquestion, read (boolean).

Producers, all inside the plugin:

- `comment.json`: reply → parent comment author; mention → each id in `mentions[]`; both skip self.
- `react.json`: reaction → comment author, skip self. One row per actor per comment, updated in place when the reaction changes, so a learner is not flooded by toggling.
- Tutor reply: the IRIS reply lands on the learner's tutor channel through the existing websocket. When the app is not on the IRIS tab, the app itself inserts a local `tutorreply` notice; nothing server-side, because the reply already reaches only that learner.
- Instructor or manager reply from the console goes through `comment.json`, so it is a `reply` with the role badge.

Endpoints: `notifications.json` (mine, newest first, 50, with unread count) and `markread.json` (ids[] or all).

### App (mobile and web, same code)

- `testuNotices` becomes a live store: fetched on app start, on resume, on tab change, and every 60 s while foregrounded. `ponytail: polling, switch to the websocket channel when EnterMedia exposes a per-user channel.`
- Bell dot = unread count > 0. Opening the screen calls `markread.json` for the visible rows; the existing swipe actions keep working on the local copy.
- Tap on a notification navigates to the origin: `reply`, `mention`, `reaction` open the session screen at that question (or the topic review tab) with the thread expanded and the comment highlighted for two seconds; `tutorreply` opens the IRIS tab. Navigation reuses the shell's tab switch and the existing screen constructors, with a `highlightMessageId` parameter added to `TestuThread`.
- On web the same tap sets the URL (Part E), so a notification link can be shared or reopened.

Local-only notifications (`addTestuNotice`) remain for on-device events in demo mode only.

## Part E: web

Work happens on `learn-web` after the uncommitted Part A changes are committed on `testu/impeccable` and merged into `learn-web` (impeccable is the ancestor, so the merge is clean apart from the files both touched: `testu_session.dart`, `testu_notifications.dart`, `testu_sully.dart`, `testu_report_sheet.dart`, `testu_live.dart`; resolve toward impeccable, then re-apply the web deltas).

### E1. TestuPressable

Add `FocusableActionDetector` with a 2 px focus ring in the accent colour, hover tint, `Semantics(button: true, label:)` and Enter/Space activation. One widget, every button in the app inherits it.

### E2. Per-tab URLs and Back

Same approach the console already uses in `admin_shell.dart` (`SystemNavigator.routeInformationUpdated` plus `WidgetsBindingObserver.didPushRouteInformation`), no router package. Paths: `/hoy`, `/temas`, `/temas/<tutorialId>`, `/iris`, `/dashboard`, plus `?q=<questionId>&c=<messageId>` for a thread deep link. Path strategy stays hash-free because the learn build already serves from `/site/mediadb/learn/` with its own base href. Mobile ignores the observer.

### E3. Close out the branch

Push `learn-web`, fold it into the open PR #2 and plugin PR #3 as commits, or merge locally into `testu/impeccable` when the user says so. No push or merge without an explicit instruction.

## Error handling

Every live fetch has three states: loading, data, error with a retry button and a one-line honest message. No fetch falls back to demo data in a live build. Sending a comment, reaction or flag that fails shows a snackbar and keeps the composer text.

## Testing

- Unit: reply parser for `>> ` follow-ups and the not-found sentence; notification tap routing table; URL round-trip for every route.
- Widget: `TestuThread` renders live rows with badges and highlights `highlightMessageId`; `TestuPressable` focus ring and keyboard activation.
- Groovy: run each new endpoint against the local server with the test learner, verify rows in `chatterbox`, `chatterboxreaction`, `learnernotification`, `questionflag`.
- Console: `build_admin.sh` then `deploy.sh` run by the user, eyeballed at `:8080` per the console-verify recipe.
- Smoke on simulator and Chrome: comment as learner A, react and reply as learner B, confirm A's bell, tap through to the highlighted comment.

## Deliverables outside code

- Written request to EnterMedia: citation verification and per-tutorial breaker in `AdaptiveTutorialUserCommentSkill.java`; per-user notification channel on the websocket.
- Runbook step for production: load list `learnernotificationtype`, `questionflagreason`, and the `tutorpersona` row already in step 2.2, now including `personality`.
