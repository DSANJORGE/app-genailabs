# Request to EnterMedia: tutor skill hardening and a per-user notification channel

From: Diego San Jorge (GenAI Labs), 2026-09-07
For: Shakil, Christopher, Cristobal
Repo: eme-server-minsur (`plugins/finder`), the TestU fork in production at minsur.genailabs.tech

Context: the TestU learner app (Minsur pilot, store submission in preparation) now ships a
plugin-side override of `ai/default/calls/chat_tutor_usercomment.json` that makes the tutor
answer in two or three sentences, cite only the reference excerpts as `[Title, p. N]` /
`[Title, m:ss]`, admit "No lo encuentro en las fuentes de este tema." when they do not cover
the question, and end with `>> ` follow-up offers the app turns into chips. That override only
shapes the local-template path of `AdaptiveTutorialUserCommentSkill` (lines 99-164); the four
changes below are in Java, which we do not modify, and would make the pilot noticeably more
reliable. None of them blocks our build.

## 1. `/chat` path: no length/grammar contract enforced, and `citeFromSources` cites sources the model never used (AdaptiveTutorialUserCommentSkill)

On the `/chat` (RAG) path the answer prose is generated inside the embedding server, so our
length and follow-up rules — enforced only by the Velocity template's prompt on the local-template
path — never apply there: replies can run to several paragraphs, with no `>> ` follow-up and no
not-found sentence even when the question is genuinely off-topic. Verified against two live calls
on the same tutor channel (`.superpowers/sdd/2026-09-07-part-b-iris-tutor/task-7-report.md`):
- On-topic ("¿Qué es la debida diligencia en derechos humanos?"): a 513-word markdown reply with a
  `##` heading and a full markdown table, zero `>> ` follow-up markers anywhere in it.
- Off-topic ("¿Cuánto cobra Luis al mes?", not answerable from the tutorial's sources): a 126-word
  reply that never utters "No lo encuentro en las fuentes de este tema." — no not-found sentence at
  all, and no `>> ` follow-ups either.

Worse: `citeFromSources` (line 86) unconditionally appends up to two `[Title, p. N]` citations
picked from the RAG call's `sources[]`, regardless of whether the model's own answer text actually
drew on them — the off-topic run above came back with two
`[Plan Nacional de Acción sobre Empresas y Derechos Humanos 2021-2025 (Perú), p. N]` citations even
though the answer states outright that it has no information on the question. On this path the app
cannot tell an unsourced answer from a sourced one: every RAG reply looks cited whether or not the
model used the sources.

Requested: if the `ai-llama-index` service can take an optional system instruction (or
`max_tokens`) in the `/chat` payload, pass the same length/follow-up/not-found rules we use in the
template. Separately, gate `citeFromSources`'s citation append on some signal that the answer text
actually engaged with the retrieved sources (or drop it below a retrieval-score threshold) — right
now a confident wrong answer and a grounded one are visually identical to the learner.

Also (finding from `.superpowers/sdd/2026-09-07-part-b-iris-tutor/spike-skill-path.md`):
`getLlmConnection("embedding")` at `AdaptiveTutorialUserCommentSkill.java:55` is resolved
unconditionally, outside any try/catch — a missing or misconfigured `embedding` `aiserver` record
throws `OpenEditException` and kills the whole skill instead of degrading to the template path the
rest of the skill is built to fall back to. Requested: guard that lookup so a missing/misconfigured
embedding server degrades the same way an empty `parentIds` or a failed `/chat` call already does.

## 2. Verify citations against the reference excerpts before returning (AdaptiveTutorialUserCommentSkill)

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

## 3. Scope the embedding-server breaker per tutorial (AdaptiveTutorialUserCommentSkill)

`embedFailedAt` is a single static field (lines 30-31, tested at 62, set at 95), so one failed
`/chat` call silences the RAG path for every tutorial on the JVM for 30 minutes — including
tutorials whose documents are embedded and whose `/chat` works. Minsur runs two courses
(DDHH, Ciberseguridad) on one server.

Requested: a `Map<String, Long>` keyed by `tutorialid` (or by the embedding server root when
you prefer), same 30 min window, and an INFO log line on open/close so we can read the state
in the Tomcat log. If you also expose the window as a catalog setting
(`tutor.embedretryminutes`), we can shorten it during the pilot.

## 4. A per-user notification channel on the chat websocket (ChatServer / AssistantManager)

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

Thanks — happy to test any of this against our local checkout the same day.

---

## Added 2026-09-08 from Parts C and D

Two more items surfaced while we built the notifications and social-sync plugin pieces after
this request was first drafted. Neither blocks our build; both come from things we hit and
worked around on our side.

### 5. Per-user notification channel — confirmed as the blocker for dropping our poll

This is the same ask as item 4 above; we're citing it again because our own end-to-end smoke
testing confirmed it's now the single concrete blocker against dropping our poll. Today the app
polls `services/testu/social/notifications.json` every 60 seconds while the app is in the
foreground, and we would switch that to a per-user websocket channel the moment one exists — the
swap is a small, isolated edit on our side once the channel is available.

Requested: unchanged from item 4 — a `user-<userid>` channel id accepted on connect for that
user only, plus a Groovy-callable `broadcastToUser(userid, JSONObject)` hook.

Why it matters: it's the last piece standing between us and removing a poll that hits the
server every 60 seconds per signed-in learner, for every learner, all pilot long.

### 6. Field-definition behaviours we'd like documented or guarded upstream

Building the social-sync (`questionflag`) and notifications (`learnernotification`) plugin
fields, we hit three eMe field-XML behaviours that cost us a debugging session each and aren't
obvious from declaring the fields the way Lucene-style XML would suggest:

- **`index="false"` drops the property's value at save time, not just at search time.**
  `BaseElasticSearcher.updateIndex` skips any property where `!detail.isIndex()` before it ever
  reaches the document — there is no "stored but not indexed" path, despite the separate
  `stored` attribute implying one. We hit this on `questionflag.note` (declared
  `index="false" stored="true"`; every learner note was discarded on save, though the response
  still returned `{"ok":true}`), and found the identical bug already present in
  `tutorquestion.query`.
- **`exact()` on a string property needs `indextype="not_analyzed"`; `keyword="true"` alone is
  not consulted.** `PropertyDetail.isAnalyzed()` only looks at `type`/`datatype`/`analyzer`/
  `indextype` — a property declared only `keyword="true"` is still treated as analyzed, so
  `BaseElasticSearcher.buildNewTerm` sends the `exact()` query against a `.exact` sub-field the
  Elasticsearch mapping may not have. The query returns zero hits, with no error. We hit this on
  `questionflag.status` (our console's flag list came back empty).
- **A literal `--` inside an XML comment in a field definition breaks the whole type.** We wrote
  a comment containing `-- see defects-report.md. -->`; the double hyphen is only legal as the
  comment's own closing delimiter, so the field XML became unparseable. That broke every
  endpoint touching `learnernotification` (not just the script we were editing) with a
  500-style `OpenEditException`: `"The string \"--\" is not permitted within comments."`

Requested: we're not asking for a Java change here — all three were fixable on our side once
diagnosed (add `indextype="not_analyzed"`, change `index="false"` to `index="true"`, reword the
comment). We'd like them written into whatever field-XML reference exists for plugin authors,
or, if it's cheap, a boot-time validation pass that logs a warning for the two silent cases
(`index="false"` on a field a script writes; `keyword="true"` without `indextype`) — the third,
the XML comment, at least throws today.

Why it matters: two of the three fail silently — the flag list came back empty with no error,
and the note field returned a success response while quietly discarding the data. Those are the
expensive kind to catch, and we'd rather other plugin authors (and our future selves) not
rediscover them the same way.
