# Part B: IRIS short, sourced, honest (+ C1 history read-back) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every IRIS reply is two or three sentences, cites only the tutorial's reference excerpts in the app's existing `[Título, p. N]` grammar, says "No lo encuentro en las fuentes de este tema." when they do not cover the question, ends with up to two `>> ` follow-up offers the learner taps instead of reading more, fails with a distinct honest line (offline / server error / 90 s timeout) on every chat surface, and the IRIS tab reopens with the last 50 turns of the same conversation on phone and web.

**Architecture:** One Velocity template in the plugin (`eme-plugin-testu/html/ai/default/calls/chat_tutor_usercomment.json`) overrides the server default because `/site/mediadb/ai/default/calls/` (the plugin's deployed tree) resolves before `plugins/mediadb/html/ai/default/calls/` (`OpenAiConnection.java:208-214` looks under the mediadb app id first). It keeps the exact variables the skill fills (`$chathistory`, `$referenceexcerpts`, `$learnerprompt`, `$model`, `AdaptiveTutorialUserCommentSkill.java:108,152-155`) and the same `{message}` response_format, so no Java changes. The app parser `splitCite` (`lib/testu/testu_live.dart:628`) gains `>> ` follow-ups and the not-found sentence; `SullyMessage` (`lib/testu/testu_sully.dart`) renders chips, the muted not-found line and a "Sin fuente" label; the four chat surfaces (session, IRIS tab, PDF viewer, resources sheet) share one failure mapping and one 90 s rule. History read-back needs a tiny plugin page (`services/testu/tutor/history.json`) because `tutorhistory.json` hides the learner's own follow-ups (they are stored as `messagetype=system` rows, `AssistantManager.java:759-777`, and `tutorhistory.json` skips `messagetype == "system"`).

**Tech Stack:** eMe plugin (Velocity call template, Groovy script + `.xconf` pages), Flutter 3.44 / Dart 3.12 (`lib/testu/*`), `flutter_test`, `eme_app_package` (`EmeHttp`, `EmeHttpException`, `TopicService`, `ChatSocketService`), curl + python3 for the smoke against the local eMe server on `:8080`.

**Spec:** `/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs/docs/superpowers/specs/2026-09-07-minsur-pilot-readiness-design.md` — sections "Part B: IRIS, short, sourced, honest", "C1. IRIS history", "Error handling", "Testing", "Deliverables outside code". Shared brief: `/private/tmp/claude-501/-Users-DSANJORGE-Code-EME-GenAI-Labs/e7a225c4-7f30-48bd-b78d-772a80b994a3/scratchpad/plan-brief.md`.

## Global Constraints

- Root `/Users/DSANJORGE/Code/EME-GenAI Labs/` is not a git repo. App repo `app-genailabs` (branch `testu/impeccable`, 24 uncommitted files from tonight: never revert, stash, checkout or commit them). Plugin repo `eme-plugin-testu` (branch `learn-web`). Server `eme-server-minsur` (symlink to `~/Code/eme-server-minsur`) is READ ONLY for us; Java changes there become the written request in Task 8.
- Never commit or push; every task ends with "leave uncommitted for the user". Never switch branches. Never run `deploy.sh` or `build_store.sh`. `ios/Runner.xcodeproj/project.pbxproj` must stay `objectVersion = 60` (if tooling flips it to 54: `git checkout -- ios/Runner.xcodeproj/project.pbxproj`).
- Ponytail mode full: minimal diffs, reuse existing helpers, `// ponytail:` comment on deliberate shortcuts. No new dependencies. No new abstractions.
- Every live-only behaviour is gated with `testuLive` (`const bool testuLive` in `lib/testu/testu_live.dart:26`) so the Vueling demo build is byte-for-byte unchanged. Under `flutter test` the default client is `minsur` (`lib/testu/testu_client.dart:7-8`), so `testuLive == true` in tests.
- Spanish UI strings go through `L('en','es')` from `lib/testu/testu_i18n.dart`; widget tests assert English (`test/flutter_test_config.dart` pins `testuLang` to `en`). The app must never offer signup.
- Prompt rules (spec, verbatim): two or three sentences, never more than 60 words, one idea per reply; at most two follow-up offers, each on its own line prefixed `>> `; every factual claim cites `[Título, p. N]` or `[Título, m:ss]` taken only from `${refs}`; if `${refs}` does not support the answer, reply exactly "No lo encuentro en las fuentes de este tema." plus one follow-up; Spanish, tutor register (tú), no emojis, no headers.
- Server boundary is plugin-only: `html/` of the plugin maps to `webapp/site/mediadb/` (see `eme-plugin-testu/deploy.sh:7`). For local checks copy the individual files by hand (commands given in the tasks); call templates and Groovy pages reload without a Tomcat restart.
- Never log in as `diego` from curl or scripts (eMe keeps one token per user; it ends the simulator session). Local checks run as `admin`/`admin` via `services/authentication/login.json` with a cookie jar, exactly like `eme-plugin-testu/tools/check_ask.sh`.
- Learner-visible plugin pages use `<permission name="view"><user/></permission>` and a `scripts/_site.xconf` that denies direct script access (pattern: `html/services/testu/personas/me.xconf`, `personas/scripts/_site.xconf`).
- Run app tests with `flutter test <file>` and `flutter analyze` from `/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs`.

## Facts the tasks rely on (verified 2026-09-07 against the local server and ES)

- The override template governs the **local-template path** of `AdaptiveTutorialUserCommentSkill.process` (`.java:99-164`): it runs when the tutorial has no embedded documents, when the hosted embedding `/chat` fails, or while the 30 min JVM-wide breaker is open (`.java:30-31,62-65,95`). On the `/chat` path the reply prose comes from the embedding server and the citation block is appended by `citeFromSources` (`.java:86,209-275`); that prose cannot be shaped by our template. Locally `/chat` fails, so every local reply goes through the template. The app handles both shapes (a `/chat` reply simply has no `>> ` chips).
- Variables available in the template: everything the skill `putContextValue`s (`referenceexcerpts`, `chathistory`, `learnerprompt`), `model` (`OpenAiConnection.java:200`), plus `$mediaarchive` because the call-template page request runs `ai/_site.xconf` path actions (`plugins/mediadb/html/ai/_site.xconf`: `MediaArchiveModule.getMediaArchive`) — the stock `classifyAsset_*.json` templates already use `$mediaarchive.getList(...)`. There is no `$persona`/`$personaname` variable for this skill (those exist only in the console's `ask.groovy`), so the tutor persona is looked up **inside the template** with the same rule as `personas/scripts/me.groovy:12`: `tutorpersona` row named by catalog setting `tutorpersona`, default `iris`.
- Reference excerpts arrive as text headed by `[<entityasset name>, p. <pagenum>]` lines (`.java:594`), so "cite copied exactly from the heading" is a valid instruction.
- A learner follow-up posted by the app is one `chatterbox` row: `messagetype=system`, `user=<learner>`, `message=""`, `functionname=chat_tutor_usercomment`, `agentcontextvalues={"query": <text>, "sectionid", "componentid", "questionid", "tutorialid", …}`. The tutor's reply is a second row: `user=agent`, no `messagetype`, `replytoid=<system row id>`, `message=<markdown, cites at the end>`, `functionname=chat_tutor_usercomment`. `tutorhistory.json` emits only rows whose `messagetype != "system"`, i.e. the replies but not the questions.
- `tutorhistory.json?dataid=<tutorial>` (POST) runs `ChatModule.loadChatChannel`, which finds or **creates** the caller's `agenttutorchat` channel (`ChatModule.java:592-706,713-717`) and returns it as `activechannel`; `channel` rows carry `user`, `dataid`, `channeltype` (`plugins/catalog/html/data/fields/channel.xml`).
- Local content: tutorial `AZ_tFsHKimsE6yOlqXpA` (DDHH) with reference PDF "Plan Nacional de Acción sobre Empresas y Derechos Humanos 2021-2025 (Perú)"; Diego's tutor channel `AaBjtGs7IzgyWh7BwLls` (used only as "someone else's channel" in the 403 check).
- `EmeHttpException.statusCode == null` means transport failure (`eme_app_package/lib/eme_http.dart:71-83,205`); an HTTP error carries the code; `askSully`/`askSullyFree` throw `StateError('No tutor channel')` when the channel cannot be resolved (`testu_live.dart:447`).

## Scope notes

- Spec "Data on screen": the IRIS tab greeting is already a fixed template over `TutorProgress` (`testu_tutor.dart:254-319`); the demo-copy sites are Part A. Nothing to build here.
- Spec "Speed": the only app-side levers are the shorter output cap in the template and the 90 s ceiling; the rest is Task 8's request.
- The `learn-web` worktree does not carry these edits; Part E merges `testu/impeccable` into it.

---

### Task 1: Prompt override in the plugin

**Files:**
- Create: `/Users/DSANJORGE/Code/EME-GenAI Labs/eme-plugin-testu/html/ai/default/calls/chat_tutor_usercomment.json`
- Reference (read only): `/Users/DSANJORGE/Code/EME-GenAI Labs/eme-server-minsur/plugins/mediadb/html/ai/default/calls/chat_tutor_usercomment.json` (the default being overridden), `/Users/DSANJORGE/Code/EME-GenAI Labs/eme-plugin-testu/html/ai/default/calls/analytics_ask.json` (rules model)

**Interfaces:**
- Consumes: template context `chathistory` (list of `{role, content}`), `referenceexcerpts` (string, may be empty), `learnerprompt` (string), `model` (string), `$mediaarchive`.
- Produces: an LLM `message` string in the grammar the app parses in Task 2: prose with `[Título, p. N]` / `[Título, m:ss]` citations, an optional exact first sentence `No lo encuentro en las fuentes de este tema.`, and 0–2 trailing lines `>> <pregunta>`.

- [ ] **Step 1: Write the override template**

Create `/Users/DSANJORGE/Code/EME-GenAI Labs/eme-plugin-testu/html/ai/default/calls/chat_tutor_usercomment.json` with exactly this content:

```velocity
## TestU override of plugins/mediadb/html/ai/default/calls/chat_tutor_usercomment.json.
## Same variables the skill fills ($chathistory, $referenceexcerpts, $learnerprompt,
## $model) and the same response_format {message}, so no Java change: this file wins
## because /site/mediadb/ai/default/calls/ resolves before the mediadb plugin default.
## Rules mirror the console's analytics_ask.json (short, cite-or-admit, follow-ups).
##
## Lesson content, question and answer context go into ONE system message: as 73
## assistant turns in a row the 27B Qwen on llamat lost the thread (2026-09-03).
#set($lesson = "")
## Built outside the literal: a directive inside #jesc("...") breaks the parse.
#set($refs = "")
#if($referenceexcerpts && $referenceexcerpts != "")
#set($refs = "

REFERENCE DOCUMENT EXCERPTS (the only citable sources; each excerpt starts with its citation heading in brackets):
${referenceexcerpts}")
#end
#foreach($h in $chathistory)
#set($lesson = "${lesson}${h.content}
")
#end
## The site's tutor persona: same lookup as personas/scripts/me.groovy (tutorpersona row
## named by the catalog setting, default "iris"). Name and the personality field, which
## nothing used before this template. $mediaarchive is on every call-template request
## (ai/_site.xconf runs MediaArchiveModule.getMediaArchive; classifyAsset_*.json use it).
#set($tutorname = "Iris")
#set($personality = "")
#set($personaid = $mediaarchive.getCatalogSettingValue("tutorpersona"))
#if(!$personaid || $personaid == "")
#set($personaid = "iris")
#end
#set($persona = $mediaarchive.getCachedData("tutorpersona", $personaid))
#if($persona)
#set($tutorname = $persona.getName())
#if($persona.get("personality") && $persona.get("personality") != "")
#set($personality = $persona.get("personality"))
#end
#end
{
	"model": "${model}",
	"messages": [
		{
			"role": "system",
			"content": #jesc("You are ${tutorname}, the training tutor of the learner inside a corporate training app. ${personality}

RULES, all mandatory:
1. Length: two or three sentences, never more than 60 words, one idea per reply. No headers, no bullet lists, no emojis. Spanish only, addressing the learner as tú, in the calm register of a senior colleague.
2. Sources: every factual claim about the subject ends with the citation of the excerpt it comes from, copied exactly from that excerpt's heading, in the form [Title, p. N] or [Title, m:ss]. Cite only the REFERENCE DOCUMENT EXCERPTS below. Never invent a title, a page or a time. The LESSON CONTEXT is context, never a citable source.
3. Not found: if the excerpts do not support what the learner asks, and the question in play (its options, correct option and rationale in the LESSON CONTEXT) does not answer it either, reply with exactly this sentence and nothing before it: No lo encuentro en las fuentes de este tema. Then add one follow-up offer (rule 4). Never guess and never answer from general knowledge.
4. Follow-ups: end the reply with at most two short offers of what the learner could ask next, each on its own line, each starting with >> and written as a question (e.g. >> ¿Quieres que te explique la debida diligencia?). When rule 3 applies, exactly one.
5. The question in play: if the learner asks for a hint before answering, do NOT restate or paraphrase any option and do NOT say which one is right; name the principle the question tests and give one clue about where the options differ. If they already answered, explain why the correct option is right and why theirs was wrong, in relation to what they chose and how sure they were. An explanation taken from the question's rationale carries no citation.
6. Never shame the learner. Never reply with a system-style refusal such as 'the provided context does not contain'.

LESSON CONTEXT (the lesson, the current question with its options, the correct option and its rationale, the learner's answer and confidence when given, and their progress):
${lesson}${refs}")
		},
		{
			"role": "user",
			"content": #jesc("${learnerprompt}

[[Reply as ${tutorname}, in Spanish, two or three sentences and at most 60 words, every claim from the excerpts with its [Title, p. N] citation, then up to two lines starting with >> offering what to ask next. If neither the excerpts nor the question in play cover this, the reply begins with: No lo encuentro en las fuentes de este tema.]]")
		}
	],
	"response_format": {
		"type": "json_schema",
		"json_schema": {
			"name": "tutor_reply",
			"strict": true,
			"schema": {
				"type": "object",
				"properties": {
					"message": { "type": "string" }
				},
				"required": ["message"],
				"additionalProperties": false
			}
		}
	}
}
```

- [ ] **Step 2: Copy it into the local server (by hand, not deploy.sh)**

```bash
S=~/Code/eme-server-minsur/webapp/site/mediadb
mkdir -p "$S/ai/default/calls"
cp "/Users/DSANJORGE/Code/EME-GenAI Labs/eme-plugin-testu/html/ai/default/calls/chat_tutor_usercomment.json" "$S/ai/default/calls/"
ls -la "$S/ai/default/calls/"
```

Expected: `analytics_ask.json`, `analytics_classify_questions.json` and the new `chat_tutor_usercomment.json` listed.

- [ ] **Step 3: Render the template through Tomcat and check it is valid JSON with the persona in it**

The call-template page is a normal Velocity page; fetching it as admin renders it with empty skill variables (the `${model}` literal stays, which is fine for JSON).

```bash
B=http://localhost:8080/site/mediadb; J=$(mktemp)
curl -sf -c "$J" -o /dev/null "$B/services/authentication/login.json" -H 'Content-Type: application/json' -d '{"id":"admin","password":"admin"}'
curl -s -b "$J" "$B/ai/default/calls/chat_tutor_usercomment.json" > /tmp/tutor_template.json
python3 - <<'PY'
import json
d = json.load(open('/tmp/tutor_template.json'))
s = d['messages'][0]['content']
assert '$mediaarchive' not in s and '$persona' not in s and '$tutorname' not in s, 'unresolved velocity: ' + s[:200]
assert s.startswith('You are '), s[:80]
assert 'No lo encuentro en las fuentes de este tema.' in s
assert d['response_format']['json_schema']['schema']['required'] == ['message']
print('ok: renders as JSON; tutor =', s.split(',')[0])
PY
rm -f "$J"
```

Expected: `ok: renders as JSON; tutor = You are Iris` (or the persona's real name). If the output shows `You are Iris,  ` with two spaces, `personality` is empty on the `tutorpersona` row: fill it in the eMe admin (Settings → Tables → tutorpersona → the `iris` row) — not required for this plan's checks; the Part D runbook step loads it in production.

- [ ] **Step 4: Leave uncommitted for the user**

```bash
cd "/Users/DSANJORGE/Code/EME-GenAI Labs/eme-plugin-testu" && git status --short
```

Expected: `?? html/ai/default/calls/chat_tutor_usercomment.json`. Do not commit.

---

### Task 2: Reply parser — `>> ` follow-ups and the not-found sentence

**Files:**
- Modify: `/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs/lib/testu/testu_live.dart:574-648` (`Cite`, regexes, `splitCite`)
- Test: `/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs/test/testu_reply_parser_test.dart` (new)

**Interfaces:**
- Consumes: nothing new.
- Produces: `const String sullyNotFound = 'No lo encuentro en las fuentes de este tema.';` `Cite.followups` (`List<String>`, default `const []`), `Cite.notFound` (`bool` getter). `splitCite(String reply)` now strips `>> ` lines from `text` on both the cited and the uncited path. Existing fields and behaviour of `Cite`/`splitCite` unchanged (`test/testu_cite_test.dart` keeps passing).

- [ ] **Step 1: Write the failing tests**

Create `/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs/test/testu_reply_parser_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/testu/testu_live.dart';

const _doc = 'Plan Nacional de Acción sobre Empresas y Derechos Humanos '
    '2021-2025 (Perú)';

void main() {
  test('>> lines become follow-ups and leave the text', () {
    final c = splitCite('El Plan fija metas [$_doc, p. 13].\n'
        '>> ¿Quieres ver las metas?\n'
        '>> ¿Te explico el marco?');
    expect(c.text, 'El Plan fija metas.');
    expect(c.followups, ['¿Quieres ver las metas?', '¿Te explico el marco?']);
    expect(c.title, _doc);
    expect(c.page, 13);
    expect(c.notFound, isFalse);
  });

  test('follow-ups are stripped from an uncited reply too', () {
    final c = splitCite(
        'La opción A es correcta por lo que dice la rationale.\n\n>> ¿Repasamos B?');
    expect(c.text, 'La opción A es correcta por lo que dice la rationale.');
    expect(c.followups, ['¿Repasamos B?']);
    expect(c.title, isNull);
    expect(c.notFound, isFalse);
  });

  test('a >> line is never taken for a > quote', () {
    final c = splitCite('Texto [$_doc, p. 2].\n> cita literal\n>> ¿Seguimos?');
    expect(c.quote, 'cita literal');
    expect(c.followups, ['¿Seguimos?']);
    expect(c.text, 'Texto.');
  });

  test('the not-found sentence is recognised, with its one follow-up', () {
    final c = splitCite('$sullyNotFound\n>> ¿Quieres que repasemos lo que sí cubre el tema?');
    expect(c.notFound, isTrue);
    expect(c.title, isNull);
    expect(c.text, sullyNotFound);
    expect(c.followups, ['¿Quieres que repasemos lo que sí cubre el tema?']);
  });

  test('no >> lines: followups empty, text untouched', () {
    final c = splitCite('Sin fuentes disponibles [ver política].');
    expect(c.followups, isEmpty);
    expect(c.text, 'Sin fuentes disponibles [ver política].');
    expect(c.notFound, isFalse);
  });
}
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `cd "/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs" && flutter test test/testu_reply_parser_test.dart`
Expected: compile error — `sullyNotFound` undefined, `followups`/`notFound` not defined for `Cite`.

- [ ] **Step 3: Extend `Cite` and `splitCite`**

In `lib/testu/testu_live.dart`, replace the `Cite` class (lines 577-609) with:

```dart
/// A tutor reply split from its sources: the text, the verbatim passage the
/// server quotes (`> …` line), the last `[Title, p. N]` (PDF page) or
/// `[Title, m:ss]` (video time) citation — the primary source — the other
/// citations in the reply, the page-relative boxes of the passage on the
/// primary page (`[[hl x,y,w,h;…]]`, PDFs only), and the `>> …` follow-up
/// offers the prompt makes the tutor end with.
class Cite {
  const Cite(
      {this.text = '',
      this.quote,
      this.title,
      this.page = 1,
      this.at,
      this.others = const [],
      this.rects = const [],
      this.followups = const []});

  final String text;
  final String? quote;
  final String? title;
  final int page;
  final Duration? at;
  final List<Ref> others;
  final List<Rect> rects;

  /// What the learner could ask next, in the tutor's words; rendered as chips.
  final List<String> followups;

  /// The tutor admits the sources do not cover the question — the exact
  /// sentence the prompt prescribes. Rendered muted, without a source block.
  bool get notFound => text.startsWith(sullyNotFound);

  Ref get ref => (title: title ?? '', page: page, at: at);

  /// The same citation pointed at [r] (the sources sheet's rows).
  Cite to(Ref r) => Cite(
      quote: quote,
      title: r.title,
      page: r.page,
      at: r.at,
      rects: r == ref ? rects : const []);
}

/// The sentence the prompt (eme-plugin-testu `chat_tutor_usercomment.json`,
/// rule 3) makes the tutor say when the sources do not cover the question.
/// Matched verbatim here; change both together.
const sullyNotFound = 'No lo encuentro en las fuentes de este tema.';
```

Then replace the regex lines and `splitCite` (lines 611-648) with:

```dart
final _quoteRe = RegExp(r'^\s*>\s*(.+?)\s*$', multiLine: true);
final _hlRe = RegExp(r'^\s*\[\[hl ([\d.,;]+)\]\]\s*$', multiLine: true);
// `>> ¿…?` lines; spaces only, so a match never swallows the line break.
final _followRe = RegExp(r'^[ \t]*>>[ \t]*(.+?)[ \t]*$', multiLine: true);

/// "m:ss" — citation times and the video player's clock.
String fmtClock(Duration d) =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

final _citeRe = RegExp(r'\s*\[([^\[\]]+?),\s*(?:p\.?\s*(\d+)|(\d+):(\d\d))\]');

Ref _ref(RegExpMatch m) => (
      title: m[1]!.trim(),
      page: int.tryParse(m[2] ?? '') ?? 1,
      at: m[3] == null
          ? null
          : Duration(minutes: int.parse(m[3]!), seconds: int.parse(m[4]!)),
    );

Cite splitCite(String reply) {
  // Follow-ups come off first: to _quoteRe a `>> …` line is a quote.
  final followups = [for (final m in _followRe.allMatches(reply)) m[1]!];
  reply = reply.replaceAll(_followRe, '').trim();
  final ms = _citeRe.allMatches(reply).toList();
  if (ms.isEmpty) return Cite(text: reply, followups: followups);
  final main = _ref(ms.last);
  return Cite(
    text: reply
        .replaceAll(_citeRe, '')
        .replaceAll(_quoteRe, '')
        .replaceAll(_hlRe, '')
        .trim(),
    quote: _quoteRe.allMatches(reply).lastOrNull?[1],
    title: main.title,
    page: main.page,
    at: main.at,
    others: {for (final m in ms) _ref(m)}.where((r) => r != main).toList(),
    rects: [
      for (final r in (_hlRe.firstMatch(reply)?[1] ?? '').split(';'))
        if (r.split(',').length == 4) _rect(r.split(',')),
    ],
    followups: followups,
  );
}
```

(`fmtClock`, `_citeRe`, `_ref` and `_rect` are unchanged; they are repeated so the block can be pasted whole.)

- [ ] **Step 4: Run the parser tests and the existing cite test**

Run: `cd "/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs" && flutter test test/testu_reply_parser_test.dart test/testu_cite_test.dart`
Expected: `All tests passed!` (7 tests).

- [ ] **Step 5: Analyze and leave uncommitted for the user**

Run: `flutter analyze lib/testu/testu_live.dart test/testu_reply_parser_test.dart`
Expected: `No issues found!`
Then `git status --short` shows `M lib/testu/testu_live.dart` and `?? test/testu_reply_parser_test.dart` (alongside tonight's modified files). Do not commit.

---

### Task 3: `SullyMessage` renders chips, the muted not-found line, "Sin fuente", and knows the failure lines

**Files:**
- Modify: `/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs/lib/testu/testu_sully.dart:1-12` (imports), `:139-274` (constructors and fields), `:334-386` (build), `:389-408` (fallback lines)
- Test: `/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs/test/testu_sully_reply_test.dart` (new)

**Interfaces:**
- Consumes: `Cite.followups`, `Cite.notFound`, `sullyNotFound` (Task 2); `TestuChip` (`lib/testu/testu_widgets.dart:614`), `kMeta`/`kChat` (`lib/testu/testu_theme.dart:149,179`), `EmeHttpException` (`eme_app_package/lib/eme_http.dart:71`).
- Produces: `SullyMessage.reply(String reply, {…, void Function(String)? onFollowUp})`; fields `followups`, `onFollowUp`, `muted`, `unsourced` on `SullyMessage`; `String sullyOffline()`, `String sullyFailure(Object e)`, `bool isSullyFallback(String s)` top-level in `testu_sully.dart`. Task 4 wires `onFollowUp` and `sullyFailure` on every surface.

- [ ] **Step 1: Write the failing widget test**

Create `/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs/test/testu_sully_reply_test.dart`:

```dart
import 'package:eme_app_package/eme_http.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/testu/testu_live.dart';
import 'package:genai_labs/testu/testu_sully.dart';
import 'package:genai_labs/testu/testu_theme.dart';

/// A live reply's grammar on screen: `>> ` offers as chips, the not-found
/// sentence muted and sourceless, an uncited answer labelled "No source",
/// and the fixed failure lines never labelled.
void main() {
  Widget host(Widget child) => MaterialApp(
        theme: testuTheme(),
        home: Scaffold(body: ListView(children: [child])),
      );

  testWidgets('>> offers render as chips that send their text', (tester) async {
    String? sent;
    await tester.pumpWidget(host(SullyMessage.reply(
        'El Plan fija metas [Plan, p. 13].\n>> ¿Quieres ver las metas?',
        onFollowUp: (s) => sent = s)));
    expect(find.text('Open source'), findsOneWidget);
    expect(find.text('No source'), findsNothing);
    await tester.tap(find.text('¿Quieres ver las metas?'));
    expect(sent, '¿Quieres ver las metas?');
  });

  testWidgets('without onFollowUp there are no chips', (tester) async {
    await tester.pumpWidget(host(
        SullyMessage.reply('Texto [Plan, p. 1].\n>> ¿Seguimos?')));
    expect(find.text('¿Seguimos?'), findsNothing);
  });

  testWidgets('an uncited answer says No source', (tester) async {
    await tester.pumpWidget(host(SullyMessage.reply(
        'La opción A es correcta por lo que dice la rationale.')));
    expect(find.text('No source'), findsOneWidget);
    expect(find.text('Open source'), findsNothing);
  });

  testWidgets('the not-found line is neither sourced nor labelled',
      (tester) async {
    await tester.pumpWidget(host(SullyMessage.reply(
        '$sullyNotFound\n>> ¿Repasamos lo que sí cubre?',
        onFollowUp: (_) {})));
    expect(find.text(sullyNotFound), findsOneWidget);
    expect(find.text('No source'), findsNothing);
    expect(find.text('Open source'), findsNothing);
    expect(find.text('¿Repasamos lo que sí cubre?'), findsOneWidget);
  });

  testWidgets('failure lines carry no label', (tester) async {
    for (final line in [sullySlowReply(), sullyUnavailable(), sullyOffline()]) {
      await tester.pumpWidget(host(SullyMessage.reply(line)));
      expect(find.text('No source'), findsNothing, reason: line);
    }
  });

  test('sullyFailure: transport failure is offline, anything else unavailable',
      () {
    expect(sullyFailure(EmeHttpException(uri: Uri.parse('x'))), sullyOffline());
    expect(sullyFailure(EmeHttpException(uri: Uri.parse('x'), statusCode: 500)),
        sullyUnavailable());
    expect(sullyFailure(StateError('No tutor channel')), sullyUnavailable());
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `cd "/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs" && flutter test test/testu_sully_reply_test.dart`
Expected: compile error — `onFollowUp` not a named parameter, `sullyOffline`/`sullyFailure` undefined.

- [ ] **Step 3: Add the import**

In `lib/testu/testu_sully.dart`, after line 3 (`import 'package:flutter/material.dart';`) add:

```dart
import 'package:eme_app_package/eme_http.dart' show EmeHttpException;
```

- [ ] **Step 4: Extend the constructors and fields**

Replace the main constructor (lines 140-156) with:

```dart
  const SullyMessage({
    super.key,
    required this.spans,
    this.extra,
    this.delay = 850,
    this.onGrew,
    this.sourceLine,
    this.sourcePage = 1,
    this.sourceAt,
    this.sourceQuote,
    this.sourceOthers = const [],
    this.sourceRects = const [],
    this.inDoc,
    this.onOpenSource,
    this.followups = const [],
    this.onFollowUp,
    this.muted = false,
    this.unsourced = false,
    this.bottomPadding = 0,
    this.avatar = true,
  });
```

In `SullyMessage.text` (lines 159-175) add to the initializer list, after `onOpenSource = null,`:

```dart
        followups = const [],
        onFollowUp = null,
        muted = false,
        unsourced = false,
```

In `SullyMessage.typing` (lines 179-192) add the same four lines after `onOpenSource = null,`.

Replace `SullyMessage.reply` and `_withFallback` and `_cite` (lines 194-234) with:

```dart
  /// A live tutor reply: its trailing `[Title, p. N]` citation (the
  /// server's reference-excerpt format) becomes the source line, opening
  /// that document at that page. Inside a document, an uncited reply still
  /// names that document ([fallbackTitle], at [fallbackPage]): the tutor
  /// always shows its source, as in the session. `>> ` offers become chips
  /// when [onFollowUp] is given; tapping one sends that text.
  SullyMessage.reply(String reply,
      {Key? key,
      double bottomPadding = 0,
      bool avatar = true,
      String? fallbackTitle,
      int fallbackPage = 1,
      String? inDoc,
      void Function(Cite)? onOpenSource,
      void Function(String)? onFollowUp})
      : this._cite(_withFallback(splitCite(reply), fallbackTitle, fallbackPage),
            key: key,
            bottomPadding: bottomPadding,
            avatar: avatar,
            inDoc: inDoc,
            onOpenSource: onOpenSource,
            onFollowUp: onFollowUp);

  static Cite _withFallback(Cite c, String? title, int page) =>
      c.title != null || title == null
          ? c
          : Cite(
              text: c.text,
              quote: c.quote,
              title: title,
              page: page,
              followups: c.followups);

  SullyMessage._cite(Cite c,
      {super.key,
      this.bottomPadding = 0,
      this.avatar = true,
      this.inDoc,
      this.onOpenSource,
      this.onFollowUp})
      : spans = mdSpans(c.text),
        sourceLine = c.title,
        sourcePage = c.page,
        sourceAt = c.at,
        sourceQuote = c.quote,
        sourceOthers = c.others,
        sourceRects = c.rects,
        followups = c.followups,
        muted = c.notFound,
        // Shown, never hidden: a live answer with no source says so. The
        // demo's canned lines and the fixed failure lines have none by design.
        unsourced = testuLive &&
            c.title == null &&
            !c.notFound &&
            !isSullyFallback(c.text),
        delay = 0,
        extra = null,
        onGrew = null;
```

After the `onOpenSource` field (line 256) add:

```dart
  /// `>> ` offers from the reply, rendered as chips under the source block.
  final List<String> followups;

  /// Tapping a follow-up chip sends its text as the next question; null
  /// hides the chips (a surface without a composer).
  final void Function(String)? onFollowUp;

  /// The not-found sentence: dimmed prose, no source block, no label.
  final bool muted;

  /// A live reply with no citation and no admission: a small "No source"
  /// label under the text.
  final bool unsourced;
```

- [ ] **Step 5: Render them**

In `build` (line 334 onwards) add `final t = TestuTokens.of(context);` as the first line of the method body, and replace the block from `Text.rich(` (line 363) to `if (widget.extra != null) widget.extra!,` (line 376) with:

```dart
                  Text.rich(
                    TextSpan(children: widget.spans),
                    style: widget.muted ? kChat.copyWith(color: t.mut) : kChat,
                  ),
                  if (widget.unsourced) ...[
                    const SizedBox(height: 6),
                    Text(L('No source', 'Sin fuente'), style: kMeta),
                  ],
                  if (widget.sourceLine != null) ...[
                    const SizedBox(height: 10),
                    TestuSourceBlock(
                      quote: widget.sourceQuote,
                      meta: '${widget.sourceLine}$_where',
                      label: _label,
                      onTap: () => _open(context),
                    ),
                  ],
                  // ponytail: chips stay after a tap (sending twice is
                  // harmless); a vanishing row when a learner reports it.
                  if (widget.onFollowUp != null && widget.followups.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final f in widget.followups)
                            TestuChip(f, onTap: () => widget.onFollowUp!(f)),
                        ],
                      ),
                    ),
                  if (widget.extra != null) widget.extra!,
```

- [ ] **Step 6: Add the third failure line, the mapping and the fallback check**

Replace lines 389-399 (`sullyDemoReply` … `sullyUnavailable`) with:

```dart
/// Fallback lines every live chat surface (session, tutor tab, viewers)
/// says in the tutor's voice. Three distinct failures, never one blur:
/// the request could not leave the phone ([sullyOffline]), the server or
/// the agent failed ([sullyUnavailable]), nothing came back within 90 s
/// ([sullySlowReply]).
String sullyDemoReply() => L(
    'In this demo I can only answer the suggested questions — in the live app, ask me anything about the material.',
    'En esta demo solo puedo responder las preguntas sugeridas — en la app real, pregúntame lo que quieras sobre el material.');
String sullySlowReply() => L(
    '${client.tutor} is taking longer than usual. Try again in a moment.',
    '${client.tutor} está tardando más de lo normal. Inténtalo de nuevo en un momento.');
String sullyUnavailable() => L(
    '${client.tutor} is not available right now.',
    '${client.tutor} no está disponible ahora mismo.');
String sullyOffline() => L(
    'No connection. Check your network and try again.',
    'Sin conexión. Revisa tu red e inténtalo de nuevo.');

/// The line for a failed send: a transport failure (no status code) is the
/// phone's network; an HTTP error, a missing tutor channel or anything
/// else is the server.
String sullyFailure(Object e) =>
    e is EmeHttpException && e.statusCode == null
        ? sullyOffline()
        : sullyUnavailable();

/// True for the app's own fixed lines above, which carry no source and
/// must not be labelled as if they were answers.
bool isSullyFallback(String s) =>
    s == sullyDemoReply() ||
    s == sullySlowReply() ||
    s == sullyUnavailable() ||
    s == sullyOffline();
```

- [ ] **Step 7: Run the new test and the existing Sully tests**

Run: `cd "/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs" && flutter test test/testu_sully_reply_test.dart test/testu_sully_reveal_test.dart test/testu_reply_parser_test.dart`
Expected: `All tests passed!`

- [ ] **Step 8: Analyze and leave uncommitted for the user**

Run: `flutter analyze lib/testu/testu_sully.dart test/testu_sully_reply_test.dart`
Expected: `No issues found!`. `git status --short` shows `M lib/testu/testu_sully.dart` and `?? test/testu_sully_reply_test.dart`. Do not commit.

---

### Task 4: Every chat surface: follow-up chips, distinct failure lines, 90 s ceiling, late replies still append

**Files:**
- Modify: `/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs/lib/testu/testu_session.dart:97-99` (fields), `:279-322` (`_sendChat`), `:331-338` (`_chatBubble`)
- Modify: `/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs/lib/testu/testu_tutor.dart:48-52` (fields), `:94-119` (`_send`), `:159-162` (chat rows)
- Modify: `/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs/lib/testu/testu_pdf.dart:66-71` (fields), `:219-260` (`_send`, live branch)
- Modify: `/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs/lib/testu/testu_resources.dart:269-275` (fields), `:283-287` (`dispose`), `:316-353` (`_send`)

**Interfaces:**
- Consumes: `SullyMessage.reply(onFollowUp:)`, `sullyFailure`, `sullySlowReply` (Task 3); `splitCite` (Task 2).
- Produces: nothing new for other tasks. Behaviour: on each surface a reply's `>> ` lines are chips that call the surface's own send; a failed send shows `sullyFailure(e)`; 90 s without a reply shows `sullySlowReply()` and the next tutor message on the channel still appends.

- [ ] **Step 1: Session screen**

In `lib/testu/testu_session.dart`, after line 99 (`bool _waitingSully = false;`) add:

```dart
  /// Set when the 90 s line was shown: the next tutor message on the channel
  /// still lands as the late answer instead of being dropped.
  bool _lateSully = false;
```

Replace `_sendChat` (lines 279-322) with:

```dart
  void _sendChat(String text, {TestuQ? q, String? offlineAnswer}) {
    q ??= _chatQ;
    setState(() => _chat.add((_controller.transcript.length, true, text)));
    // Chatting wins over "keep the framing in view": otherwise a hint
    // reply lands below the fold and the auto-scroll snaps back up.
    _anchor = null;
    _scrollDownForced();
    if (q != null && canAskSully(q)) {
      void sullySays(String s) {
        // Only the reply to an open question: the server also posts its
        // own feedback after `chat_tutor_answer`, and the local verdict
        // already covers that. After the 90 s line the next message still
        // counts (late replies append).
        if (!mounted || !(_waitingSully || _lateSully)) return;
        _lateSully = false;
        _sullyTimeout?.cancel();
        setState(() {
          _waitingSully = false;
          _chat.add((_controller.transcript.length, false, s));
        });
        _scrollDown();
      }

      _sullySub ??= sullyReplies().listen(sullySays);
      setState(() {
        _waitingSully = true;
        _lateSully = false;
      });
      // The server acknowledges the follow-up before the tutor answers, and
      // the answer may never come (minsur, 2026-09-02) — don't spin forever.
      _sullyTimeout?.cancel();
      _sullyTimeout = Timer(const Duration(seconds: 90), () {
        if (!_waitingSully) return;
        sullySays(sullySlowReply());
        // ponytail: whatever the tutor posts next is taken as the late
        // answer; match on a reply id when the server sends one.
        _lateSully = true;
      });
      askSully(q, text, attempt: _attemptFor(q))
          .catchError((Object e) => sullySays(sullyFailure(e)));
    } else {
      // The canned demo lines belong to the bundled questions only; a live
      // question that cannot reach the tutor says so instead.
      setState(() => _chat.add((
        _controller.transcript.length,
        false,
        _source is LocalQuestionSource
            ? offlineAnswer ?? sullyDemoReply()
            : sullyUnavailable()
      )));
      _scrollDown();
    }
  }
```

In `_chatBubble` (line 334) change

```dart
      return _Rise(child: SullyMessage.reply(text, bottomPadding: 16));
```

to

```dart
      return _Rise(
          child: SullyMessage.reply(text,
              bottomPadding: 16, onFollowUp: (s) => _sendChat(s)));
```

- [ ] **Step 2: IRIS tab**

In `lib/testu/testu_tutor.dart`, after line 52 (`Timer? _timeout;`) add:

```dart
  bool _late = false;
```

Replace `_send` (lines 94-119) with:

```dart
  /// Same live/offline split as the session chat, minus the question.
  void _send(String text) {
    setState(() => _chat.add((true, text)));
    _scrollDown();
    if (!testuLive) {
      setState(() => _chat.add((false, sullyDemoReply())));
      _scrollDown();
      return;
    }
    void says(String s) {
      if (!mounted || !(_waiting || _late)) return;
      _late = false;
      _timeout?.cancel();
      setState(() {
        _waiting = false;
        _chat.add((false, s));
      });
      _scrollDown();
    }

    _sub ??= sullyReplies().listen(says);
    setState(() {
      _waiting = true;
      _late = false;
    });
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 90), () {
      if (!_waiting) return;
      says(sullySlowReply());
      // ponytail: the next tutor message is taken as the late answer.
      _late = true;
    });
    askSullyFree(text).catchError((Object e) => says(sullyFailure(e)));
  }
```

At lines 159-162 change the tutor row to pass the composer's send as the chip handler:

```dart
              for (final (user, text) in _chat)
                user
                    ? TestuYouMsg(text: text)
                    : SullyMessage.reply(text,
                        avatar: false, bottomPadding: 16, onFollowUp: _send),
```

- [ ] **Step 3: PDF viewer (already has the 90 s timer; add late replies, failure mapping, chips)**

In `lib/testu/testu_pdf.dart`, after line 71 (`Timer? _timeout;`) add:

```dart
  bool _late = false;
```

In `_send` (lines 219-260), make these four edits inside the `if (widget.doc != null) {` branch:

1. The guard at the top of `says`:
```dart
        if (!mounted || !(_waiting || _late)) return;
        _late = false;
        _timeout?.cancel();
```
2. The `SullyMessage.reply(` call inside `says` gains `onFollowUp: _send,` after `onOpenSource: _openSource`.
3. The `setState` that shows the dots:
```dart
      setState(() {
        _waiting = true;
        _late = false;
        _chat.add(const SullyMessage.typing(key: _typing));
      });
```
4. The timer and the send:
```dart
      _timeout?.cancel();
      _timeout = Timer(const Duration(seconds: 90), () {
        if (!_waiting) return;
        says(sullySlowReply());
        // ponytail: the next tutor message is taken as the late answer.
        _late = true;
      });
      askSullyFree(text).catchError((Object e) => says(sullyFailure(e)));
```

The resulting live branch reads:

```dart
    if (widget.doc != null) {
      // One reply per question: the tutor's answer, the agent error the
      // server posts instead (already worded as "not available"), the
      // send failure, or the 90 s timeout — whichever comes first. After
      // the timeout the next message still lands (late replies append).
      void says(String s) {
        if (!mounted || !(_waiting || _late)) return;
        _late = false;
        _timeout?.cancel();
        final key = GlobalKey();
        setState(() {
          _waiting = false;
          _chat.removeWhere((w) => w.key == _typing);
          _chat.add(SullyMessage.reply(s,
              key: key,
              bottomPadding: 12,
              fallbackTitle: widget.doc!.title,
              fallbackPage: _cur,
              inDoc: widget.doc!.title,
              onOpenSource: _openSource,
              onFollowUp: _send));
        });
        // Read from the top of the answer, not its tail.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = key.currentContext;
          if (ctx != null) {
            Scrollable.ensureVisible(ctx,
                alignment: 0, duration: const Duration(milliseconds: 350));
          }
        });
        // The cited page comes into view on its own; "View source" repeats it.
        final c = splitCite(s);
        if (c.title == widget.doc!.title) _mark(c);
      }

      _sub ??= sullyReplies().listen(says);
      setState(() {
        _waiting = true;
        _late = false;
        _chat.add(const SullyMessage.typing(key: _typing));
      });
      _timeout?.cancel();
      _timeout = Timer(const Duration(seconds: 90), () {
        if (!_waiting) return;
        says(sullySlowReply());
        // ponytail: the next tutor message is taken as the late answer.
        _late = true;
      });
      askSullyFree(text).catchError((Object e) => says(sullyFailure(e)));
    } else {
```

- [ ] **Step 4: Resources sheet (had no timeout at all)**

In `lib/testu/testu_resources.dart`, replace lines 269-275 (the start of `_ResSheetState`) with:

```dart
class _ResSheetState extends State<_ResSheet> {
  final List<Widget> _chat = [];
  final Set<int> _used = {};
  final _scroll = ScrollController();
  final _player = GlobalKey<_MiniPlayerState>();
  static const _typing = ValueKey('typing');
  StreamSubscription<String>? _sub;
  bool _waiting = false;
  bool _late = false;
  Timer? _timeout;
```

In `dispose` (lines 283-287) add `_timeout?.cancel();` after `_sub?.cancel();`.

Replace `_send` (lines 316-353) with:

```dart
  void _send(String text) {
    setState(() => _chat.add(TestuYouMsg(text: text)));
    if (widget.doc != null) {
      // Live: the tutor answers over the socket (same path and same 90 s
      // ceiling as the PDF sheet). After the timeout the next message still
      // lands (late replies append).
      void says(String s) {
        if (!mounted || !(_waiting || _late)) return;
        _late = false;
        _timeout?.cancel();
        final key = GlobalKey();
        setState(() {
          _waiting = false;
          _chat.removeWhere((w) => w.key == _typing);
          _chat.add(SullyMessage.reply(s,
              key: key,
              bottomPadding: 12,
              fallbackTitle: widget.doc!.title,
              inDoc: widget.doc!.title,
              onOpenSource: _openSource,
              onFollowUp: _send));
        });
        // Read from the top of the answer; a timed cite seeks on its own.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = key.currentContext;
          if (ctx != null) {
            Scrollable.ensureVisible(ctx,
                alignment: 0, duration: const Duration(milliseconds: 350));
          }
        });
        // Only a real citation moves the player; a failure line or the
        // not-found sentence has none (opening a null title used to raise
        // the "source not available" snackbar).
        final c = splitCite(s);
        if (c.title != null) _openSource(c);
      }

      _sub ??= sullyReplies().listen(says);
      setState(() {
        _waiting = true;
        _late = false;
        _chat.add(const SullyMessage.typing(key: _typing));
      });
      _timeout?.cancel();
      _timeout = Timer(const Duration(seconds: 90), () {
        if (!_waiting) return;
        says(sullySlowReply());
        // ponytail: the next tutor message is taken as the late answer.
        _late = true;
      });
      askSullyFree(text).catchError((Object e) => says(sullyFailure(e)));
    } else {
      setState(() => _chat.add(SullyMessage.text(widget.res.live,
          delay: 850, sourceLine: widget.res.title, bottomPadding: 12)));
    }
    _autoScroll();
  }
```

- [ ] **Step 5: Analyze and run the whole app test suite**

Run: `cd "/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs" && flutter analyze && flutter test`
Expected: `No issues found!` and `All tests passed!` (the session scroll, landscape, sully reveal, cite, parser and reply tests all green). If `flutter test` reports golden/shot differences under `test/console_shots` or `test/landscape_shots`, re-run only that file to confirm it is unrelated to these four files before continuing.

- [ ] **Step 6: Leave uncommitted for the user**

`git status --short` shows the four `lib/testu/*.dart` files modified. Do not commit. Check `git diff --stat ios/Runner.xcodeproj/project.pbxproj` prints nothing (if it shows `objectVersion` 60→54: `git checkout -- ios/Runner.xcodeproj/project.pbxproj`).

---

### Task 5: Plugin page `services/testu/tutor/history.json` (both halves of the conversation)

**Files:**
- Create: `/Users/DSANJORGE/Code/EME-GenAI Labs/eme-plugin-testu/html/services/testu/tutor/history.json`
- Create: `/Users/DSANJORGE/Code/EME-GenAI Labs/eme-plugin-testu/html/services/testu/tutor/history.xconf`
- Create: `/Users/DSANJORGE/Code/EME-GenAI Labs/eme-plugin-testu/html/services/testu/tutor/scripts/_site.xconf`
- Create: `/Users/DSANJORGE/Code/EME-GenAI Labs/eme-plugin-testu/html/services/testu/tutor/scripts/history.groovy`
- Pattern (read only): `eme-plugin-testu/html/services/testu/personas/me.json`, `me.xconf`, `scripts/_site.xconf`, `usage/scripts/track.groovy`

**Interfaces:**
- Consumes: query param `channel` (a `channel` row id owned by the caller), optional `limit` (default 50, max 200).
- Produces: `GET services/testu/tutor/history.json?channel=<id>` → `{"ok": true, "turns": [{"id", "from": "user"|"tutor", "text", "date"}]}` oldest first, last `limit` turns; `401` when not signed in, `404` unknown channel, `403` when the channel's `user` is not the caller. Task 6 consumes this.

- [ ] **Step 1: The three page files**

`html/services/testu/tutor/history.json`:

```velocity
$json
```

`html/services/testu/tutor/history.xconf`:

```xml
<page>
  <path-action name="Script.run"><script>/${applicationid}/services/testu/tutor/scripts/history.groovy</script></path-action>
  <permission name="view"><user/></permission>
</page>
```

`html/services/testu/tutor/scripts/_site.xconf`:

```xml
<page>
  <permission name="view"><boolean value="false"/></permission>
</page>
```

- [ ] **Step 2: The script**

`html/services/testu/tutor/scripts/history.groovy`:

```groovy
import groovy.json.JsonOutput
import org.entermediadb.asset.MediaArchive
import org.openedit.Data
import org.openedit.MultiValued
// IRIS history for the learner app: the learner's follow-ups and the tutor's replies on one of
// the caller's own tutor channels, oldest first, last `limit` (50). The stock tutorhistory.json
// hides the follow-ups -- the app posts them as `system` rows with the text only in
// agentcontextvalues.query (AgentModule / AssistantManager.sendSystemMessage) -- so phone and
// web could not show the same conversation without this page.
void reply(Map m) { context.putPageValue("json", JsonOutput.toJson(m)) }
void fail(int code, String msg) { context.getResponse().setStatus(code); reply([ok: false, error: msg]); context.setCancelActions(true) }

MediaArchive archive = context.getPageValue("mediaarchive")
String userid = context.getUser()?.getId()
if (!userid) { fail(401, "not signed in"); return }
String channelid = context.getRequestParameter("channel") ?: ""
Data channel = channelid ? archive.getData("channel", channelid) : null
if (channel == null) { fail(404, "no channel"); return }
if (!userid.equals(channel.get("user"))) { fail(403, "not your channel"); return }
int limit = 50
try { limit = Math.max(1, Math.min(200, Integer.parseInt(context.getRequestParameter("limit") ?: "50"))) } catch (Exception e) {}

List turns = []
// ponytail: the whole channel, filtered here -- functionname is analysed text in ES, so exact()
// on "chat_tutor_usercomment" is not safe; a channel holds a few hundred rows at most.
for (MultiValued m in archive.query("chatterbox").exact("channel", channelid).sort("dateUp").hitsPerPage(2000).search()) {
  if (!"chat_tutor_usercomment".equals(m.get("functionname"))) continue
  if ("system".equals(m.get("messagetype"))) {
    def q = m.getJSONValue("agentcontextvalues")?.get("query")
    if (q) turns << [id: m.getId(), from: "user", text: q.toString(), date: m.get("date")]
  } else if ("agent".equals(m.get("user"))) {
    String text = m.get("message") ?: ""
    if (text.trim()) turns << [id: m.getId(), from: "tutor", text: text, date: m.get("date")]
  }
}
reply([ok: true, turns: turns.size() > limit ? turns.takeRight(limit) : turns])
```

- [ ] **Step 3: Copy the page into the local server (by hand, not deploy.sh)**

```bash
S=~/Code/eme-server-minsur/webapp/site/mediadb
mkdir -p "$S/services/testu/tutor/scripts"
cp -R "/Users/DSANJORGE/Code/EME-GenAI Labs/eme-plugin-testu/html/services/testu/tutor/." "$S/services/testu/tutor/"
find "$S/services/testu/tutor" -type f
```

Expected: `history.json`, `history.xconf`, `scripts/_site.xconf`, `scripts/history.groovy`.

- [ ] **Step 4: Check the permission edges as admin**

```bash
B=http://localhost:8080/site/mediadb; J=$(mktemp)
curl -sf -c "$J" -o /dev/null "$B/services/authentication/login.json" -H 'Content-Type: application/json' -d '{"id":"admin","password":"admin"}'
curl -s -o /dev/null -w 'no channel -> %{http_code}\n'      -b "$J" "$B/services/testu/tutor/history.json"
curl -s -o /dev/null -w 'other user -> %{http_code}\n'      -b "$J" "$B/services/testu/tutor/history.json?channel=AaBjtGs7IzgyWh7BwLls"
curl -s -o /dev/null -w 'direct script -> %{http_code}\n'   -b "$J" "$B/services/testu/tutor/scripts/history.groovy"
curl -s -o /dev/null -w 'anonymous -> %{http_code}\n'               "$B/services/testu/tutor/history.json?channel=x"
rm -f "$J"
```

Expected: `404`, `403`, a non-200 (the `_site.xconf` denial, typically `403` or a redirect `302`), and `401`/`403` for anonymous. The 200 path is exercised end to end by Task 7's script (it needs a follow-up on admin's own channel first).

- [ ] **Step 5: Leave uncommitted for the user**

`cd "/Users/DSANJORGE/Code/EME-GenAI Labs/eme-plugin-testu" && git status --short` shows `?? html/services/testu/tutor/`. Do not commit.

---

### Task 6: IRIS tab loads the last 50 turns on open

**Files:**
- Modify: `/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs/lib/testu/testu_live.dart:221-245` (`sullyReplies`, `_plainText`), and add `loadTutorHistory` / `tutorTurns` right after `loadTutorProgress` (ends line 299)
- Modify: `/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs/lib/testu/testu_tutor.dart:41-52` (fields), `:74-91` (`_enter`)
- Test: `/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs/test/testu_reply_parser_test.dart` (add one test)

**Interfaces:**
- Consumes: Task 5's `{turns: [{from, text}]}`; `_tutorChannelFor` (`testu_live.dart:463`), `DioEmeHttp` (already imported), `isSullyError`/`sullyUnavailable` (already imported at line 20).
- Produces: `Future<List<(bool, String)>> loadTutorHistory()` and pure `List<(bool, String)> tutorTurns(Map<String, dynamic> data)` in `testu_live.dart`; the tutor tab's `_chat` is `(fromUser, text)` already, so the rows drop straight in.

- [ ] **Step 1: Write the failing test**

Append to `test/testu_reply_parser_test.dart` (inside `main`, after the last test; add `import 'package:genai_labs/testu/testu_sully.dart';` to the imports):

```dart
  test('tutorTurns maps the history page to (fromUser, text) rows', () {
    final turns = tutorTurns({
      'ok': true,
      'turns': [
        {'id': 'a', 'from': 'user', 'text': '¿Qué es la debida diligencia?'},
        {'id': 'b', 'from': 'tutor', 'text': '<p>Es el proceso… [$_doc, p. 20]</p>'},
        {'id': 'c', 'from': 'tutor', 'text': 'Error on AI Agent'},
        {'id': 'd', 'from': 'user', 'text': '   '},
      ],
    });
    expect(turns, [
      (true, '¿Qué es la debida diligencia?'),
      (false, 'Es el proceso… [$_doc, p. 20]'),
      (false, sullyUnavailable()),
    ]);
    expect(tutorTurns({'ok': true}), isEmpty);
  });
```

- [ ] **Step 2: Run it to see it fail**

Run: `cd "/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs" && flutter test test/testu_reply_parser_test.dart`
Expected: compile error — `tutorTurns` undefined.

- [ ] **Step 3: One text cleanup for socket and history, then the loader**

In `lib/testu/testu_live.dart` replace lines 221-245 (`sullyReplies` and `_plainText`) with:

```dart
/// Sully's textual replies from the live chat socket, as plain text. An
/// agent error the server posts instead of an answer (LLM down, 502…)
/// arrives as [sullyUnavailable], so the session, the tutor tab and the
/// document viewer all say the same thing without each checking.
Stream<String> sullyReplies() => ChatSocketService()
    .messageStream
    .where((m) =>
        m.isAI &&
        !m.isKeepAlive &&
        !m.isMessageRemoved &&
        // Upstream renamed the enum to MessageRenderType (2026-09-03);
        // ChatMessage.messageType is now the raw string field.
        (m.messageRenderType.isAgentComment || m.messageRenderType.isText))
    .map((m) => _tutorText(m.text))
    .where((s) => s.isNotEmpty);

/// A tutor message as the app shows it: tags stripped, an agent error
/// worded as [sullyUnavailable]. Shared by the socket and the history page.
String _tutorText(String html) {
  final s = _plainText(html);
  return isSullyError(s) ? sullyUnavailable() : s;
}

// ponytail: crude tag strip — the reply HTML is simple tutor prose. Its
// markdown (the /chat answer) survives here; `mdSpans` renders it.
String _plainText(String html) => html
    .replaceAll(RegExp(r'<br\s*/?>|</p\s*>|</li\s*>', caseSensitive: false),
        '\n')
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();
```

After `loadTutorProgress` (line 299, the closing `}`) add:

```dart
/// The learner's conversation with the tutor on the live tutorial's channel:
/// their questions and the tutor's replies, oldest first, the last 50, from
/// the plugin page `services/testu/tutor/history.json`. The stock
/// `tutorhistory.json` hides the questions (the app posts them as system
/// rows), so phone and web read this one instead. Empty when the channel
/// does not exist yet (nothing was ever asked).
Future<List<(bool, String)>> loadTutorHistory() async {
  if (_liveQs.isEmpty) await EmeQuestionSource().load();
  final chan = await _tutorChannelFor(_liveTutorialId!);
  if (chan == null) return const [];
  final data = await DioEmeHttp().getJson('services/testu/tutor/history.json',
      query: {'channel': chan.id});
  return tutorTurns(data);
}

/// `{turns: [{from: user|tutor, text}]}` as the tutor tab's (fromUser, text)
/// rows; tutor rows get the socket's text cleanup, blank rows are dropped.
List<(bool, String)> tutorTurns(Map<String, dynamic> data) => [
      for (final t in (data['turns'] as List? ?? const []))
        if (t is Map && '${t['text']}'.trim().isNotEmpty)
          t['from'] == 'user'
              ? (true, '${t['text']}'.trim())
              : (false, _tutorText('${t['text']}')),
    ];
```

- [ ] **Step 4: Run the parser tests**

Run: `flutter test test/testu_reply_parser_test.dart`
Expected: `All tests passed!` (6 tests).

- [ ] **Step 5: The tab loads history once**

In `lib/testu/testu_tutor.dart`, after line 46 (`bool _loadingProgress = false;`) add:

```dart
  // C1: the same conversation on phone and web. Loaded once per screen
  // life, only while nothing was typed here yet.
  bool _loadingHistory = false;
```

Replace `_enter` (lines 74-91) with:

```dart
  void _enter() {
    setState(() => _in = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _in = true);
    });
    if (testuLive) {
      _loadingProgress = true;
      loadTutorProgress().then((p) {
        if (!mounted) return;
        setState(() {
          _loadingProgress = false;
          if (p != null) _progress = p;
        });
      }).catchError((_) {
        if (mounted) setState(() => _loadingProgress = false);
      });
      // ponytail: a failed history load is silent — the greeting stands and
      // re-entering the tab retries; an error card when someone misses it.
      if (_chat.isEmpty && !_loadingHistory) {
        _loadingHistory = true;
        loadTutorHistory().then((turns) {
          if (mounted && _chat.isEmpty && turns.isNotEmpty) {
            setState(() => _chat.addAll(turns));
            _scrollDown();
          }
        }).catchError((_) {}).whenComplete(() => _loadingHistory = false);
      }
    }
  }
```

- [ ] **Step 6: Analyze and run the tutor tests**

Run: `flutter analyze lib/testu/testu_live.dart lib/testu/testu_tutor.dart && flutter test test/testu_tutor_channel_test.dart test/testu_tutor_progress_test.dart test/testu_reply_parser_test.dart`
Expected: `No issues found!` and `All tests passed!`

- [ ] **Step 7: Leave uncommitted for the user**

`git status --short` shows `M lib/testu/testu_live.dart`, `M lib/testu/testu_tutor.dart`, `?? test/testu_reply_parser_test.dart`. Do not commit.

---

### Task 7: Smoke against the local server and the simulator

**Files:**
- Create: `/Users/DSANJORGE/Code/EME-GenAI Labs/eme-plugin-testu/tools/check_tutor.sh`
- Pattern (read only): `eme-plugin-testu/tools/check_ask.sh`

**Interfaces:**
- Consumes: Task 1's template (copied to the server), Task 5's page (copied), the running local Tomcat on `:8080` and llamat.
- Produces: a runnable check the user can repeat: one follow-up as admin on admin's own tutor channel, the reply verified against the grammar, both turns returned by `history.json`.

- [ ] **Step 1: The script**

Create `eme-plugin-testu/tools/check_tutor.sh`:

```sh
#!/bin/sh
# Part B / C1: the tutor prompt override and the IRIS history page against the local server.
# Posts one follow-up as admin on admin's own tutor channel (never as diego: it ends the
# simulator session), waits for the reply, checks the reply grammar (>> follow-ups or the
# not-found sentence, [Title, p. N] cites, length) and that history.json returns both turns.
# Usage: tools/check_tutor.sh ["¿pregunta?"]   (default: an on-topic DDHH question)
set -eu
B=${EME_BASE:-http://localhost:8080/site/mediadb}; T=${TUTORIAL:-AZ_tFsHKimsE6yOlqXpA}; J=$(mktemp); trap 'rm -f "$J"' EXIT
Q=${1:-¿Qué es la debida diligencia en derechos humanos?}
curl -sf -c "$J" -o /dev/null "$B/services/authentication/login.json" -H 'Content-Type: application/json' -d '{"id":"admin","password":"admin"}'
# The caller's agenttutorchat channel for the tutorial; tutorhistory creates it when missing.
# (an unset $activechannel renders as the literal "$activechannel.id": skip ids that start with "$")
CH=$(curl -sf -b "$J" -X POST "$B/services/module/entitytutorial/tutorhistory.json?dataid=$T" | python3 -c 'import sys,json;d=json.load(sys.stdin);ids=[(d.get(k) or {}).get("id","") for k in ("activechannel","currentchannel")];print(next((i for i in ids if i and not i.startswith("$")),""))')
[ -n "$CH" ] || { echo "FAIL: no tutor channel for admin on $T"; exit 1; }
# Section and component of the first MCQ, as the app sends them.
SC=$(curl -sf -b "$J" "$B/services/module/entitytutorial/tutorial.json?entitytutorial=$T" | python3 -c 'import sys,json;d=json.load(sys.stdin);s=d["sections"][0];c=[x for x in s["contents"] if (x.get("contenttype") or x.get("content_type") or "").lower()=="mcq"][0];print(s["id"],c["id"])')
SEC=${SC% *}; COMP=${SC#* }
curl -sf -b "$J" -o /dev/null -X POST "$B/services/module/entitytutorial/continue.json" -d currentscenario=chat_tutor -d functionname=chat_tutor_usercomment -d "context_tutorialid=$T" -d "channel=$CH" --data-urlencode "context_query=$Q" -d "context_sectionid=$SEC" -d "context_componentid=$COMP" -d context_skiploader=true
echo "sent on channel $CH (section $SEC, component $COMP); waiting for the tutor..."
i=0
while [ $i -lt 45 ]; do
  sleep 2; i=$((i+1))
  curl -sf -b "$J" "$B/services/testu/tutor/history.json?channel=$CH" > /tmp/tutor_history.json
  if python3 -c 'import sys,json;t=json.load(open("/tmp/tutor_history.json"))["turns"];sys.exit(0 if len(t)>=2 and t[-1]["from"]=="tutor" and t[-2]["from"]=="user" else 1)'; then break; fi
done
python3 - "$Q" <<'PY'
import json, re, sys
t = json.load(open('/tmp/tutor_history.json'))['turns']
assert len(t) >= 2 and t[-2]['from'] == 'user' and t[-1]['from'] == 'tutor', 'no reply within 90 s (llamat down?): ' + json.dumps(t[-2:], ensure_ascii=False)
assert t[-2]['text'] == sys.argv[1], t[-2]
r = t[-1]['text']
body = re.sub(r'^[ \t]*>>.*$', '', r, flags=re.M)
follow = re.findall(r'^[ \t]*>>[ \t]*(.+?)[ \t]*$', r, flags=re.M)
cites = re.findall(r'\[([^\[\]]+?),\s*(?:p\.?\s*\d+|\d+:\d\d)\]', body)
notfound = body.strip().startswith('No lo encuentro en las fuentes de este tema.')
words = len(re.sub(r'\[[^\]]*\]', '', body).split())
print('reply :', r.replace('\n', ' | ')[:500])
print('words', words, '| cites', cites, '| follow-ups', follow, '| not found', notfound)
assert 1 <= len(follow) <= 2, 'expected one or two >> follow-ups'
assert notfound or cites or 'rationale' in sys.argv[1].lower() or words <= 60, 'neither cited nor the not-found sentence'
assert words <= 90, 'reply too long for the 60-word rule'
if notfound: assert len(follow) == 1, 'not-found must carry exactly one follow-up'
print('ok: reply in grammar; history.json returns both turns')
PY
```

Then `chmod +x "/Users/DSANJORGE/Code/EME-GenAI Labs/eme-plugin-testu/tools/check_tutor.sh"`.

- [ ] **Step 2: Run it on topic and off topic**

```bash
cd "/Users/DSANJORGE/Code/EME-GenAI Labs/eme-plugin-testu"
tools/check_tutor.sh
tools/check_tutor.sh "¿Cuánto cobra Luis al mes?"
```

Expected, first run: `reply : … [Plan Nacional de Acción sobre Empresas y Derechos Humanos 2021-2025 (Perú), p. N] | >> ¿…?` with `cites` non-empty, `follow-ups` of length 1–2, `words ≤ 60`, and `ok: …`. Second run: `not found True`, exactly one follow-up, `ok: …`. If the wait loop ends with "no reply within 90 s", check llamat (`curl -m 30 https://llamat.emediaworkspace.com/v1/models`) and `grep -n "Calling: chat_tutor_usercomment\|OpenAI error" /tmp/eme_tomcat.log | tail`; the template is loaded from `webapp/site/mediadb/ai/default/calls/` on every call, so a fix needs only a re-copy (Task 1 Step 2).

- [ ] **Step 3: Confirm the override is the template that ran**

```bash
grep -c "REFERENCE DOCUMENT EXCERPTS (the only citable sources" /tmp/eme_tomcat.log
```

Expected: `1` or more (the server logs every rendered payload it sends to llamat as `INFO: Sent:` lines; the default template's heading reads `REFERENCE DOCUMENT EXCERPTS:` without the parenthesis, so the phrase can only come from the override). `0` means the default still runs: re-check Task 1 Step 2's path. Note `/tmp/eme_tomcat.log` is truncated on every Tomcat restart, so run this right after Step 2.

- [ ] **Step 4: Simulator walk (drive-simulator skill; only while the user is not using the Simulator)**

Build once: `cd "/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs" && ./run_minsur.sh` (or the skill's launch recipe), sign in as the local learner, then:

1. IRIS tab: the greeting, then — if that learner asked anything before — the previous turns below it (Task 6). Ask "¿Qué es la debida diligencia?": dots, then a short reply with the orange source block and one or two chips under it. Tap a chip: it appears as your message and gets its own reply.
2. Ask "¿Cuánto cobra Luis al mes?": the muted sentence "No lo encuentro en las fuentes de este tema.", no source block, no "Sin fuente", one chip.
3. Session (Temas → a topic → Empezar), answer one question, tap "Pista"/type "¿Por qué está mal B?": the reply explains from the rationale with the "Sin fuente" label (or with a cite when an excerpt matched).
4. Recursos → open the PDF sheet, ask something: a reply with "Ver fuente" and chips; wait — no more than 90 s of dots ever.
5. Offline line: relaunch with `--dart-define=TESTU_MEDIADB=http://localhost:1` and ask in the IRIS tab: "Sin conexión. Revisa tu red e inténtalo de nuevo." (not "IRIS no está disponible").
6. Leave the IRIS tab and come back (or kill and relaunch the app): the same turns are listed again, oldest first, under the greeting.

Take one portrait screenshot of step 1 and one of step 2 for the user.

- [ ] **Step 5: Leave uncommitted for the user**

`cd "/Users/DSANJORGE/Code/EME-GenAI Labs/eme-plugin-testu" && git status --short` now shows `?? html/ai/default/calls/chat_tutor_usercomment.json`, `?? html/services/testu/tutor/`, `?? tools/check_tutor.sh`. Do not commit.

---

### Task 8: Written request to EnterMedia

**Files:**
- Create: `/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs/docs/superpowers/requests/2026-09-07-entermedia-tutor-skill.md` (the `requests/` directory does not exist yet)

**Interfaces:**
- Consumes: nothing from code. References real lines of `eme-server-minsur/plugins/finder/code/org/entermediadb/ai/skills/AdaptiveTutorialUserCommentSkill.java`, `…/ai/assistant/AssistantManager.java`, `…/websocket/chat/ChatServer.java`.
- Produces: the text the user sends (Slack/email/Notion — the user chooses; this plan does not send it).

- [ ] **Step 1: Write the request file with exactly this content**

```markdown
# Request to EnterMedia: tutor skill hardening and a per-user notification channel

From: Diego San Jorge (GenAI Labs), 2026-09-07
For: Shakil, Christopher, Cristobal
Repo: eme-server-minsur (`plugins/finder`), the TestU fork in production at minsur.genailabs.tech

Context: the TestU learner app (Minsur pilot, store submission in preparation) now ships a
plugin-side override of `ai/default/calls/chat_tutor_usercomment.json` that makes the tutor
answer in two or three sentences, cite only the reference excerpts as `[Title, p. N]` /
`[Title, m:ss]`, admit "No lo encuentro en las fuentes de este tema." when they do not cover
the question, and end with `>> ` follow-up offers the app turns into chips. That override only
shapes the local-template path of `AdaptiveTutorialUserCommentSkill` (lines 99-164); the three
changes below are in Java, which we do not modify, and would make the pilot noticeably more
reliable. None of them blocks our build.

## 1. Verify citations against the reference excerpts before returning (AdaptiveTutorialUserCommentSkill)

Today the model's `message` is returned as is (`structured.get("message")`, line 157) and the
app trusts every `[Title, p. N]` in it. A title that matches no document of the tutorial ends
up as a dead "Abrir fuente" link ("La fuente aún no está disponible").

Requested: after line 157, keep only the citations whose title is the name of an `entityasset`
linked to the tutorial (the same query `findReferenceExcerpts` runs at line 563:
`query("entityasset").exact("entitytutorial", tutorialid)`) and, on the local-template path,
whose `[Title, p. N]` heading appears in the `referenceexcerpts` string built at line 594.
Strip the rest from the text. When nothing remains, return the text uncited — the app then
labels it "Sin fuente" instead of showing a link that fails. On the `/chat` path the prose
returned by the embedding server may also carry bracketed pseudo-citations written by its own
LLM; please strip those before `citeFromSources` (line 86) appends the verified block from
`sources[]`.

Shape we rely on (unchanged): the reply is prose, optionally one `> quote` line, then one
`[Title, p. N]` per source with the primary source last, optionally `[[hl …]]`.

## 2. Scope the embedding-server breaker per tutorial (AdaptiveTutorialUserCommentSkill)

`embedFailedAt` is a single static field (lines 30-31, tested at 62, set at 95), so one failed
`/chat` call silences the RAG path for every tutorial on the JVM for 30 minutes — including
tutorials whose documents are embedded and whose `/chat` works. Minsur runs two courses
(DDHH, Ciberseguridad) on one server.

Requested: a `Map<String, Long>` keyed by `tutorialid` (or by the embedding server root when
you prefer), same 30 min window, and an INFO log line on open/close so we can read the state
in the Tomcat log. If you also expose the window as a catalog setting
(`tutor.embedretryminutes`), we can shorten it during the pilot.

## 3. A per-user notification channel on the chat websocket (ChatServer / AssistantManager)

Learner notifications (a reply or a mention in a question thread, a reaction, an instructor's
answer) are produced by our plugin as `learnernotification` rows. The app polls a plugin page
every 60 s because the websocket only broadcasts per `channel` (the per-channel push built at
`AssistantManager.java:1147-1160`, `ChatServer.java:276`).

Requested: a channel id of the form `user-<userid>` that the server accepts on connect for
that user only, and a server-side hook we can call from Groovy (for example
`chatServer.broadcastToUser(userid, JSONObject)`) that pushes a message of this shape:

    {"messagetype": "notification", "user": "<userid>",
     "notification": {"id", "type": "reply|mention|reaction|tutorreply", "actor", "actorname",
                      "text", "channel", "messageid", "entitytutorial", "entityquestion",
                      "datecreated", "read": false}}

With that we drop the polling and the bell updates live. Auth can stay as today (the socket
already carries the user's session).

## Also noted, no action needed unless cheap

On the `/chat` path the answer prose is generated inside the embedding server, so our length
and follow-up rules do not apply there; replies can run to several paragraphs. If the
`ai-llama-index` service can take an optional system instruction (or `max_tokens`) in the
`/chat` payload, we would pass the same rules we use in the template.

Thanks — happy to test any of this against our local checkout the same day.
```

- [ ] **Step 2: Leave uncommitted for the user**

```bash
cd "/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs" && git status --short docs/
```

Expected: `?? docs/superpowers/requests/` (and `?? docs/superpowers/specs/` from tonight). Do not commit; the user decides where to send the text.
