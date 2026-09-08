# Part C2/C3: Question Reports and Social Threads Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Question reports reach the server (`questionflag`) and social threads (question conversations, topic reviews) read and write the server's `chatterbox` through five plugin endpoints, in the learner app and in a new console screen "Conversaciones".

**Architecture:** Server side is plugin-only: entity xml + list + five groovy services under `eme-plugin-testu/html/services/testu/social/` (`flag`, `thread`, `comment`, `react`, `mentionables`), each the same `name.json` + `name.xconf` + `scripts/name.groovy` triple `usage/track` uses. App side, one new file `lib/testu/testu_social_api.dart` holds the models (`TestuComment`, `TestuReaction` move there) and `TestuSocialApi` over `EmeHttp`; `TestuThread` gains a `channel` and loads/writes live while the demo keeps its mock list; the console reuses `TestuThread` verbatim inside `lib/admin/admin_threads.dart`. Part D (notifications) is a separate plan: `comment.groovy` and `react.groovy` end with a marked hook point that names the variables Part D needs.

**Tech Stack:** EnterMedia/eMe plugin (groovy scripts, `data/fields/*.xml`, `data/lists/*.xml`), Flutter 3.44.6 / Dart ^3.12, `eme_app_package` `EmeHttp` + `FakeEmeHttp`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-07-minsur-pilot-readiness-design.md`, Part C2 and C3 (lines 78-96), "Error handling" (line 138) and "Testing" (line 142).

## Global Constraints

- Never commit or push; every task ends with "leave uncommitted for the user". Never switch branches. Never run `deploy.sh` or `build_store.sh`. `ios/Runner.xcodeproj/project.pbxproj` stays `objectVersion = 60` (if tooling flips it to 54: `git checkout -- ios/Runner.xcodeproj/project.pbxproj`).
- `app-genailabs` has 24 uncommitted modified files (tonight's store fixes) including `testu_live.dart`, `testu_session.dart`, `testu_social.dart`, `testu_topics.dart`, `testu_report_sheet.dart`. Edit in place; never revert, stash or checkout them.
- Ponytail mode full: minimal diffs, reuse existing helpers, `// ponytail:` on deliberate shortcuts, no new dependencies, no new abstractions.
- Every live-only behaviour is gated with `testuLive` (`const bool testuLive` in `lib/testu/testu_live.dart:26`) so the Vueling demo build is byte-for-byte unchanged.
- App never offers signup. Spanish UI strings go through `L('en','es')` / `CL(...)` from `testu_i18n.dart`.
- Server boundary is plugin-only: nothing under `eme-server-minsur` is edited. Learner-visible endpoints carry `<permission name="view"><user/></permission>`; every `scripts/` directory carries `_site.xconf` denying direct access.
- Channel ids: `q-<entityquestion>` for a question conversation, `t-<entitytutorial>` for a topic review. Social chatterbox rows are marked `functionname = "testu_social"` so `computemastery.groovy` (which keys on `functionname = chat_tutor_usercomment`, `catalog/events/scripts/testu/computemastery.groovy:117`) never counts them as tutor questions.
- Spec error rule: every live fetch has loading / data / error-with-retry; a comment, reaction or flag that fails to send shows a snackbar (or an inline error in the report sheet) and keeps the text.
- Runtime paths: plugin root `/Users/DSANJORGE/Code/EME-GenAI Labs/eme-plugin-testu`, app root `/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs`. Run app commands from the app root: `flutter test <file>`, `flutter analyze`.

---

## File structure

Server (`eme-plugin-testu/`):

| File | Responsibility |
|---|---|
| `data/fields/questionflag.xml` | Entity: one row per question report. |
| `data/lists/questionflagreason.xml` | List: wrong, unclear, outdated, other. |
| `html/services/testu/social/scripts/_site.xconf` | Denies direct script access (copy of `usage/scripts/_site.xconf`). |
| `html/services/testu/social/flag.{json,xconf}` + `scripts/flag.groovy` | POST: saves a `questionflag`. |
| `html/services/testu/social/thread.{json,xconf}` + `scripts/thread.groovy` | GET `?channel=`: one thread with authors, roles, reactions, my reaction. GET without channel: the console's recent comments + open flags, scoped through `personas/scripts/scope.groovy`. |
| `html/services/testu/social/comment.{json,xconf}` + `scripts/comment.groovy` | POST: saves a chatterbox row (Part D hook at the end). |
| `html/services/testu/social/react.{json,xconf}` + `scripts/react.groovy` | POST: sets/toggles my reaction (Part D hook at the end). |
| `html/services/testu/social/mentionables.{json,xconf}` + `scripts/mentionables.groovy` | GET: my teammates plus managers, training and orgadmins. |

App (`app-genailabs/`):

| File | Responsibility |
|---|---|
| Create `lib/testu/testu_social_api.dart` | `TestuReaction`, `TestuComment` (moved here, gain `id`, `userId`, `date`, nullable `avatar`), `Mentionable`, `RecentComment`, `QuestionFlagRow`, `SocialRecent`, `TestuSocialApi`, `testuSocial`, `testuFlagReasons`, `flagReasonLabel`, `roleBadge`. |
| Modify `lib/testu/testu_social.dart` | `TestuThread` takes `channel`/`api`/`onCount`, loads live, posts comments and reactions, `@` picker; `SocialThreadEntry` takes `channel`; initials avatar when `avatar == null`. Re-exports the moved types. |
| Modify `lib/testu/testu_report_sheet.dart` | `onSend` may return a Future; the sheet awaits it, shows an inline error and keeps the form on failure; optional `sentText`. |
| Modify `lib/testu/testu_question_source.dart:91-98` | `reportFlag` returns `Future<void>`. |
| Modify `lib/testu/testu_live.dart:120-199, 349-385` | `EmeQuestionSource.reportFlag` posts `flag.json`; `TopicProgress.tutorialId`. |
| Modify `lib/testu/testu_session.dart:1279-1346, 1425-1426` | Report sheet wired to reason ids and live copy; `SocialThreadEntry(channel:)` live. |
| Modify `lib/testu/testu_topics.dart:481-487, 952-967` | Review tab visible live on `t-<tutorialId>`. |
| Modify `lib/admin/admin_api.dart:31-33` | `AdminApi.social`. |
| Create `lib/admin/admin_threads.dart` | Console "Conversaciones": recent comments, open flags, open a thread, reply, react. |
| Modify `lib/admin/admin_shell.dart:36-49, 216-245` | Section `threads` + route. |
| Tests | `test/testu_social_api_test.dart` (new), `test/testu_thread_test.dart` (new), `test/admin_threads_test.dart` (new), `test/admin_shell_test.dart:22-27` (expectations), `test/testu_tutor_progress_test.dart:33` (unchanged, named param is optional). |

---

### Task 1: `questionflag` entity, its reason list, and `flag.json`

**Files:**
- Create: `eme-plugin-testu/data/fields/questionflag.xml`
- Create: `eme-plugin-testu/data/lists/questionflagreason.xml`
- Create: `eme-plugin-testu/html/services/testu/social/scripts/_site.xconf`
- Create: `eme-plugin-testu/html/services/testu/social/flag.json`
- Create: `eme-plugin-testu/html/services/testu/social/flag.xconf`
- Create: `eme-plugin-testu/html/services/testu/social/scripts/flag.groovy`

**Interfaces:**
- Consumes: the request context the other plugin scripts use (`context.getUser()`, `context.getRequestParameter`, `context.getPageValue("mediaarchive")`, `context.putPageValue("json", ...)`), exactly as `html/services/testu/usage/scripts/track.groovy:7-20`.
- Produces: `POST services/testu/social/flag.json` form fields `entityquestion` (required), `entitytutorial` (optional), `reason` (one of `wrong|unclear|outdated|other`), `note` (optional, cut at 1000 chars) → `{ok:true, id}`; `400 {ok:false,error}` on bad input, `401` when not signed in, `404` when the question does not exist. Rows land in searcher `questionflag` with `status = "open"`. Task 4's `TestuSocialApi.flag` and Task 2's flags listing depend on these names.

- [ ] **Step 1: Write the entity xml**

`eme-plugin-testu/data/fields/questionflag.xml` (same shape as `data/fields/tutorquestion.xml`):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!-- Pilot readiness C2: one row per question a learner reported from the app (services/testu/social/flag).
     user comes from the session, never the body. status is open until a later console task resolves it. -->
<properties beanname="dataSearcher">
  <property id="id" index="true" stored="true" editable="false" keyword="true"><name><language id="en">ID</language></name></property>
  <property id="user" index="true" stored="true" editable="false" type="list" listid="user"><name><language id="en">User</language><language id="es">Usuario</language></name></property>
  <property id="datecreated" index="true" stored="true" editable="false" type="date"><name><language id="en">Date</language><language id="es">Fecha</language></name></property>
  <property id="entitytutorial" index="true" stored="true" editable="false" type="list" listid="entitytutorial"><name><language id="en">Tutorial</language></name></property>
  <property id="entityquestion" index="true" stored="true" editable="false" type="list" listid="entityquestion"><name><language id="en">Question</language><language id="es">Pregunta</language></name></property>
  <property id="reason" index="true" stored="true" editable="false" type="list" listid="questionflagreason"><name><language id="en">Reason</language><language id="es">Motivo</language></name></property>
  <property id="note" index="false" stored="true" editable="false" type="textarea"><name><language id="en">Note</language><language id="es">Nota</language></name></property>
  <property id="status" index="true" stored="true" editable="true" keyword="true"><name><language id="en">Status</language><language id="es">Estado</language></name></property>
</properties>
```

- [ ] **Step 2: Write the reason list**

`eme-plugin-testu/data/lists/questionflagreason.xml` (same shape as `data/lists/usageeventtype.xml`):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<questionflagreasons>
  <questionflagreason id="wrong"><name><![CDATA[Incorrecta]]></name></questionflagreason>
  <questionflagreason id="unclear"><name><![CDATA[Confusa o mal redactada]]></name></questionflagreason>
  <questionflagreason id="outdated"><name><![CDATA[Desactualizada]]></name></questionflagreason>
  <questionflagreason id="other"><name><![CDATA[Otro]]></name></questionflagreason>
</questionflagreasons>
```

- [ ] **Step 3: Deny direct script access and add the request page**

`eme-plugin-testu/html/services/testu/social/scripts/_site.xconf` (byte-identical to `usage/scripts/_site.xconf`):

```xml
<page>
  <permission name="view"><boolean value="false"/></permission>
</page>
```

`eme-plugin-testu/html/services/testu/social/flag.json`:

```
$json
```

`eme-plugin-testu/html/services/testu/social/flag.xconf`:

```xml
<page>
  <path-action name="Script.run"><script>/${applicationid}/services/testu/social/scripts/flag.groovy</script></path-action>
  <permission name="view"><user/></permission>
</page>
```

- [ ] **Step 4: Write `flag.groovy`**

`eme-plugin-testu/html/services/testu/social/scripts/flag.groovy`:

```groovy
import groovy.json.JsonOutput
import org.entermediadb.asset.MediaArchive
import org.openedit.Data

void reply(Map m) { context.putPageValue("json", JsonOutput.toJson(m)) }
void fail(int code, String msg) { context.getResponse().setStatus(code); reply([ok: false, error: msg]); context.setCancelActions(true) }
// Mirrors data/lists/questionflagreason.xml; the app sends the id, never the label.
Set REASONS = ["wrong", "unclear", "outdated", "other"] as Set

MediaArchive archive = context.getPageValue("mediaarchive")
String userid = context.getUser()?.getId()
if (!userid) { fail(401, "not signed in"); return }
String question = context.getRequestParameter("entityquestion") ?: ""
if (!question) { fail(400, "entityquestion required"); return }
String reason = context.getRequestParameter("reason") ?: ""
if (!(reason in REASONS)) { fail(400, "bad reason"); return }
if (archive.getData("entityquestion", question) == null) { fail(404, "no such question"); return }
String note = (context.getRequestParameter("note") ?: "").trim()
if (note.length() > 1000) note = note.substring(0, 1000)
String tutorial = context.getRequestParameter("entitytutorial") ?: ""

def searcher = archive.getSearcher("questionflag")
Data d = searcher.createNewData()
d.setValue("user", userid); d.setValue("datecreated", new Date())
d.setValue("entityquestion", question); if (tutorial) d.setValue("entitytutorial", tutorial)
d.setValue("reason", reason); d.setValue("note", note); d.setValue("status", "open")
archive.saveData("questionflag", d)
reply([ok: true, id: d.getId()])
```

- [ ] **Step 5: Ask the user to deploy, then smoke it with curl**

`deploy.sh` is the user's to run (never run it yourself). Once they confirm the plugin is deployed on the local server, sign in as the test learner and post one flag:

```bash
BASE=http://localhost:8080/site/mediadb
EMAIL=testuser@eme.world            # the learner the simulator signs in with; OTP is fixed on test accounts
curl -s -X POST $BASE/services/authentication/sendusercode.json -d email=$EMAIL
TOKEN=$(curl -s -X POST $BASE/services/authentication/token.json -d grant_type=otp -d email=$EMAIL -d code=666666 \
  | python3 -c 'import json,sys;print(json.load(sys.stdin)["access_token"])')
H="Authorization: Bearer $TOKEN"
TUT=$(curl -s "$BASE/services/module/entitytutorial/tutorials.json" -H "$H" | python3 -c 'import json,sys;print(json.load(sys.stdin)["tutorials"][0]["id"])')
# Any question id of that tutorial: tutorial.json lists the sections and their MCQs.
curl -s "$BASE/services/module/entitytutorial/tutorial.json?entitytutorial=$TUT" -H "$H" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(json.dumps(d)[:1500])'
Q=<one entityquestion id from that output>

curl -s -X POST $BASE/services/testu/social/flag.json -H "$H" -d entityquestion=$Q -d entitytutorial=$TUT -d reason=unclear -d note="curl smoke"
```

Expected: `{"ok":true,"id":"<generated id>"}`. Then two negative checks:

```bash
curl -s -X POST $BASE/services/testu/social/flag.json -H "$H" -d entityquestion=$Q -d reason=nonsense   # -> {"ok":false,"error":"bad reason"} with HTTP 400
curl -s -X POST $BASE/services/testu/social/flag.json -d entityquestion=$Q -d reason=other              # no token -> not signed in / 401
```

(If the local learner is `diego`, the memory note says the local OTP is `123456`; the recipe is the same with `EMAIL`/`code` swapped.)

- [ ] **Step 6: Leave uncommitted for the user**

No `git commit`. Mention in the report that `questionflag.xml` and `questionflagreason.xml` were added and that production needs the list loaded (runbook, see "Deliverables outside code" at the end of this plan).

---

### Task 2: `thread.json` (one channel, or the console's recent listing)

**Files:**
- Create: `eme-plugin-testu/html/services/testu/social/thread.json`
- Create: `eme-plugin-testu/html/services/testu/social/thread.xconf`
- Create: `eme-plugin-testu/html/services/testu/social/scripts/thread.groovy`

**Interfaces:**
- Consumes: `personas/scripts/scope.groovy` (puts `scopeteams` on the page: `null` = every team, else the set of team ids the caller manages; `html/services/testu/personas/scripts/scope.groovy:13,25`), chatterbox fields `channel`, `user`, `date`, `message`, `replytoid`, `functionname`, `moduleid`, `entityid` (`eme-server-minsur/plugins/catalog/html/data/fields/chatterbox.xml`), `chatterboxreaction` fields `messageid`, `user`, `name`, `date`, and the `questionflag` rows of Task 1.
- Produces:
  - `GET thread.json?channel=q-<id>|t-<id>` → `{ok:true, channel, comments:[{id, userId, name, role, date, text, reacts:{like:3,...}, mine:"like"|null, replies:[same shape]}]}`. `role` is the raw `userprofile.settingsgroup` (`users|manager|training|orgadmin`); the app turns it into a badge.
  - `GET thread.json` (no channel) → `{ok:true, recent:[{id, channel, moduleid, entityid, label, userId, name, role, date, text, replytoid}], flags:[{id, entityquestion, entitytutorial, label, reason, note, userId, name, date}]}`, newest first, 50 each, authors filtered to the caller's scope. A learner manages no team, so their scope set is empty and both lists come back empty.
  - Task 4's `TestuSocialApi.thread` / `.recent` parse exactly these keys.

- [ ] **Step 1: Request page and xconf**

`eme-plugin-testu/html/services/testu/social/thread.json`:

```
$json
```

`eme-plugin-testu/html/services/testu/social/thread.xconf` (scope first, like `personas/users.xconf:2-3`, then the script; `allowduplicates` because both are `Script.run`):

```xml
<page>
  <path-action name="Script.run"><script>/${applicationid}/services/testu/personas/scripts/scope.groovy</script></path-action>
  <path-action name="Script.run" allowduplicates="true"><script>/${applicationid}/services/testu/social/scripts/thread.groovy</script></path-action>
  <permission name="view"><user/></permission>
</page>
```

- [ ] **Step 2: Write `thread.groovy`**

`eme-plugin-testu/html/services/testu/social/scripts/thread.groovy`:

```groovy
import groovy.json.JsonOutput
import org.entermediadb.asset.MediaArchive
import org.openedit.Data
import org.openedit.hittracker.HitTracker

void reply(Map m) { context.putPageValue("json", JsonOutput.toJson(m)) }
void fail(int code, String msg) { context.getResponse().setStatus(code); reply([ok: false, error: msg]); context.setCancelActions(true) }

MediaArchive archive = context.getPageValue("mediaarchive")
String me = context.getUser()?.getId()
if (!me) { fail(401, "not signed in"); return }

// Author lookups, memoised per request. Name from the user record (users.groovy reads the same two fields),
// role from userprofile.settingsgroup (person.groovy's role source).
Map users = [:], roles = [:]
def userOf = { String uid -> if (!users.containsKey(uid)) users[uid] = archive.getUserManager().getUser(uid); users[uid] }
def nameOf = { String uid -> def u = userOf(uid); String n = u == null ? "" : "${u.get('firstName') ?: ''} ${u.get('lastName') ?: ''}".trim(); n ?: uid }
def roleOf = { String uid -> if (!roles.containsKey(uid)) roles[uid] = archive.getSearcher("userprofile").searchById(uid)?.get("settingsgroup") ?: "users"; roles[uid] }
def iso = { Date d -> d?.format("yyyy-MM-dd'T'HH:mm:ssXXX") }
def row = { Data m -> String uid = m.get("user")
  return [id: m.getId(), userId: uid, name: nameOf(uid), role: roleOf(uid), date: iso(m.getDate("date")), text: m.get("message") ?: ""] }

String channel = context.getRequestParameter("channel") ?: ""
if (channel) {
  if (!(channel ==~ /[qt]-[A-Za-z0-9_\-]+/)) { fail(400, "bad channel"); return }
  HitTracker rows = archive.query("chatterbox").exact("channel", channel).exact("functionname", "testu_social").sort("dateUp").search()
  rows.enableBulkOperations()
  List ids = rows.collect { it.getId() }
  Map reacts = [:], mine = [:]   // messageid -> [name: count], messageid -> my reaction name (ChatModule.loadReactions, grouped)
  if (ids) for (Data r in archive.query("chatterboxreaction").orgroup("messageid", ids).search()) {
    String mid = r.get("messageid"); String name = r.get("name")
    Map c = reacts.get(mid); if (c == null) { c = [:]; reacts[mid] = c }
    c[name] = (c[name] ?: 0) + 1
    if (r.get("user") == me) mine[mid] = name
  }
  Map byId = [:]; List top = []
  for (Data m in rows) {
    Map c = row(m) + [reacts: reacts[m.getId()] ?: [:], mine: mine[m.getId()], replies: []]
    byId[m.getId()] = c
    // dateUp: a parent always precedes its replies. comment.groovy pins replies to a top-level parent,
    // so an orphan (parent deleted) simply lists at the top rather than vanishing.
    Map parent = m.get("replytoid") ? byId[m.get("replytoid")] : null
    (parent == null ? top : parent.replies) << c
  }
  reply([ok: true, channel: channel, comments: top]); return
}

// No channel: the console's cross-thread listing, scoped like users.json. scope.groovy ran first.
Set scope = context.getPageValue("scopeteams")
def inScope = { String uid -> scope == null || (userOf(uid)?.get("team") in scope) }
def labelOf = { String moduleid, String entityid ->
  if (!moduleid || !entityid) return entityid ?: ""
  Data d = archive.getData(moduleid, entityid)
  if (d == null) return entityid
  return (moduleid == "entityquestion" ? (d.get("question") ?: d.getName()) : d.getName()) ?: entityid }
// ponytail: newest 200 scanned, 50 kept -- one request per console open, pilot volumes; page it when a client outgrows that.
HitTracker all = archive.query("chatterbox").exact("functionname", "testu_social").sort("dateDown").search(); all.enableBulkOperations()
List recent = []; int scanned = 0
for (Data m in all) {
  if (recent.size() >= 50 || scanned++ >= 200) break
  if (!inScope(m.get("user"))) continue
  recent << row(m) + [channel: m.get("channel"), moduleid: m.get("moduleid"), entityid: m.get("entityid"), label: labelOf(m.get("moduleid"), m.get("entityid")), replytoid: m.get("replytoid")]
}
List flags = []; scanned = 0
HitTracker fl = archive.query("questionflag").exact("status", "open").sort("datecreatedDown").search(); fl.enableBulkOperations()
for (Data f in fl) {
  if (flags.size() >= 50 || scanned++ >= 200) break
  String uid = f.get("user"); if (!inScope(uid)) continue
  flags << [id: f.getId(), entityquestion: f.get("entityquestion"), entitytutorial: f.get("entitytutorial"), label: labelOf("entityquestion", f.get("entityquestion")),
            reason: f.get("reason"), note: f.get("note") ?: "", userId: uid, name: nameOf(uid), date: iso(f.getDate("datecreated"))]
}
reply([ok: true, recent: recent, flags: flags])
```

- [ ] **Step 3: Ask the user to deploy, then curl both shapes**

With `$BASE`, `$H`, `$Q` from Task 1 step 5:

```bash
curl -s "$BASE/services/testu/social/thread.json?channel=q-$Q" -H "$H"
```

Expected: `{"ok":true,"channel":"q-<Q>","comments":[]}` (nothing posted yet; Task 3 fills it). Then:

```bash
curl -s "$BASE/services/testu/social/thread.json" -H "$H"
```

Expected for the learner: `{"ok":true,"recent":[],"flags":[]}` (a learner manages no team). The flag from Task 1 shows up here only for a manager of the learner's team or an orgadmin/training account; that is verified in the console in Task 8 step 8.

Bad channel:

```bash
curl -s "$BASE/services/testu/social/thread.json?channel=x" -H "$H"    # -> {"ok":false,"error":"bad channel"}, HTTP 400
```

- [ ] **Step 4: Leave uncommitted for the user**

---

### Task 3: `comment.json`, `react.json`, `mentionables.json` (with the Part D hook points)

**Files:**
- Create: `eme-plugin-testu/html/services/testu/social/comment.json`, `comment.xconf`, `scripts/comment.groovy`
- Create: `eme-plugin-testu/html/services/testu/social/react.json`, `react.xconf`, `scripts/react.groovy`
- Create: `eme-plugin-testu/html/services/testu/social/mentionables.json`, `mentionables.xconf`, `scripts/mentionables.groovy`

**Interfaces:**
- Consumes: `ChatModule.toggleReaction` logic (`eme-server-minsur/plugins/finder/code/org/entermediadb/websocket/chat/ChatModule.java:284-314`: find my reaction on the message; same name → delete; else create/update `name` + `date`), chatterbox save fields (`ChatModule.java:466-483`: `channel`, `user`, `date`, `entityid`, `moduleid`).
- Produces:
  - `POST comment.json` fields `channel`, `message`, `replytoid` (optional), `mentions` (JSON array of user ids) → `{ok:true, id, replytoid, mentions}`.
  - `POST react.json` fields `messageid`, `name` (`like|applause|support|love|idea|laugh` or empty = clear) → `{ok:true, mine:"like"|null, reacts:{...}}`. Same name twice toggles off.
  - `GET mentionables.json` → `{ok:true, people:[{id, name, role}]}`, sorted by name, self excluded, disabled users excluded.
  - Part D hook: the last lines of `comment.groovy` and `react.groovy` carry the comment `// Part D: notifications are created here` followed by the exact variables in scope. Part D adds its code below that comment and nowhere else.

- [ ] **Step 1: The three request pages and xconfs**

Each `.json` file is one line:

```
$json
```

`comment.xconf`:

```xml
<page>
  <path-action name="Script.run"><script>/${applicationid}/services/testu/social/scripts/comment.groovy</script></path-action>
  <permission name="view"><user/></permission>
</page>
```

`react.xconf`:

```xml
<page>
  <path-action name="Script.run"><script>/${applicationid}/services/testu/social/scripts/react.groovy</script></path-action>
  <permission name="view"><user/></permission>
</page>
```

`mentionables.xconf`:

```xml
<page>
  <path-action name="Script.run"><script>/${applicationid}/services/testu/social/scripts/mentionables.groovy</script></path-action>
  <permission name="view"><user/></permission>
</page>
```

- [ ] **Step 2: Write `comment.groovy`**

`eme-plugin-testu/html/services/testu/social/scripts/comment.groovy`:

```groovy
import groovy.json.JsonOutput
import groovy.json.JsonSlurper
import org.entermediadb.asset.MediaArchive
import org.openedit.Data

void reply(Map m) { context.putPageValue("json", JsonOutput.toJson(m)) }
void fail(int code, String msg) { context.getResponse().setStatus(code); reply([ok: false, error: msg]); context.setCancelActions(true) }

MediaArchive archive = context.getPageValue("mediaarchive")
String me = context.getUser()?.getId()
if (!me) { fail(401, "not signed in"); return }
String channel = context.getRequestParameter("channel") ?: ""
if (!(channel ==~ /[qt]-[A-Za-z0-9_\-]+/)) { fail(400, "bad channel"); return }
String message = (context.getRequestParameter("message") ?: "").trim()
if (!message) { fail(400, "empty message"); return }
if (message.length() > 2000) { fail(400, "message too long"); return }

def chats = archive.getSearcher("chatterbox")
// Replies nest one level (the app's LinkedIn rule): a reply to a reply hangs off the same parent.
String replytoid = context.getRequestParameter("replytoid") ?: ""
Data parent = null
if (replytoid) {
  parent = chats.searchById(replytoid)
  if (parent == null || parent.get("channel") != channel) { fail(400, "bad replytoid"); return }
  if (parent.get("replytoid")) { replytoid = parent.get("replytoid"); parent = chats.searchById(replytoid) ?: parent }
}
// The app sends the ids it picked from mentionables.json; nothing is parsed out of the text.
List mentions = []
try {
  def m = new JsonSlurper().parseText(context.getRequestParameter("mentions") ?: "[]")
  if (!(m instanceof List)) { fail(400, "bad mentions"); return }
  mentions = m.collect { it.toString() }.findAll { it && it != me }.unique().take(20)
} catch (Exception e) { fail(400, "bad mentions"); return }
def um = archive.getUserManager()
mentions = mentions.findAll { um.getUser(it) != null }

Data d = chats.createNewData()
d.setValue("channel", channel); d.setValue("user", me); d.setValue("date", new Date())
d.setValue("message", message); d.setValue("messageplain", message)
// The marker every social query keys on; keeps computemastery's chat_tutor_usercomment pass clear of these rows.
d.setValue("functionname", "testu_social")
d.setValue("moduleid", channel.startsWith("q-") ? "entityquestion" : "entitytutorial"); d.setValue("entityid", channel.substring(2))
if (replytoid) d.setValue("replytoid", replytoid)
archive.saveData("chatterbox", d)
String messageid = d.getId()
String parentauthor = parent?.get("user")

// Part D: notifications are created here.
//   me            actor user id
//   messageid     id of the chatterbox row just saved
//   channel       "q-<entityquestion>" | "t-<entitytutorial>"; d.get("moduleid") / d.get("entityid") split it
//   replytoid     parent comment id, "" when top level
//   parentauthor  parent comment's author user id (null when top level) -> "reply" recipient, skip when == me
//   mentions      List<String> of user ids: de-duplicated, self removed, verified to exist -> "mention" recipients
//   message       the text, for the one-line preview
reply([ok: true, id: messageid, replytoid: replytoid ?: null, mentions: mentions])
```

- [ ] **Step 3: Write `react.groovy`**

`eme-plugin-testu/html/services/testu/social/scripts/react.groovy`:

```groovy
import groovy.json.JsonOutput
import org.entermediadb.asset.MediaArchive
import org.openedit.Data

void reply(Map m) { context.putPageValue("json", JsonOutput.toJson(m)) }
void fail(int code, String msg) { context.getResponse().setStatus(code); reply([ok: false, error: msg]); context.setCancelActions(true) }
// The app's TestuReaction enum, by name.
Set NAMES = ["like", "applause", "support", "love", "idea", "laugh"] as Set

MediaArchive archive = context.getPageValue("mediaarchive")
String me = context.getUser()?.getId()
if (!me) { fail(401, "not signed in"); return }
String messageid = context.getRequestParameter("messageid") ?: ""
String name = context.getRequestParameter("name") ?: ""
if (name && !(name in NAMES)) { fail(400, "bad reaction"); return }
Data msg = archive.getSearcher("chatterbox").searchById(messageid)
if (msg == null || msg.get("functionname") != "testu_social") { fail(404, "no such comment"); return }

// ChatModule.toggleReaction, in groovy: one row per user per message; the same name again removes it.
// An empty name is an explicit clear (the app knows the new state, so it never has to send the old name).
def reactions = archive.getSearcher("chatterboxreaction")
Data found = archive.query("chatterboxreaction").exact("messageid", messageid).exact("user", me).searchOne()
String mine = null
if (!name || (found != null && found.get("name") == name)) {
  if (found != null) reactions.delete(found, context.getUser())
} else {
  if (found == null) { found = reactions.createNewData(); found.setValue("messageid", messageid); found.setValue("user", me) }
  found.setValue("date", new Date()); found.setValue("name", name)
  archive.saveData("chatterboxreaction", found)
  mine = name
}
Map counts = [:]
for (Data r in archive.query("chatterboxreaction").exact("messageid", messageid).search()) counts[r.get("name")] = (counts[r.get("name")] ?: 0) + 1
String author = msg.get("user")

// Part D: notifications are created here.
//   me         actor user id
//   author     the comment's author user id -> "reaction" recipient, skip when == me
//   messageid  the comment reacted to; channel = msg.get("channel"); msg.get("moduleid") / msg.get("entityid")
//   mine       the reaction now standing (null = removed). One notification row per actor per comment:
//              update it in place when mine changes, delete it when mine is null, never add a second.
reply([ok: true, mine: mine, reacts: counts])
```

- [ ] **Step 4: Write `mentionables.groovy`**

`eme-plugin-testu/html/services/testu/social/scripts/mentionables.groovy`:

```groovy
import groovy.json.JsonOutput
import org.entermediadb.asset.MediaArchive
import org.openedit.Data

void reply(Map m) { context.putPageValue("json", JsonOutput.toJson(m)) }
void fail(int code, String msg) { context.getResponse().setStatus(code); reply([ok: false, error: msg]); context.setCancelActions(true) }
Set STAFF = ["manager", "training", "orgadmin"] as Set

MediaArchive archive = context.getPageValue("mediaarchive")
def who = context.getUser()
String me = who?.getId()
if (!me) { fail(401, "not signed in"); return }
String myteam = who.get("team") ?: ""
Map roles = [:]
for (Data p in archive.query("userprofile").all().search()) roles[p.getId()] = p.get("settingsgroup")
// Learners in my team plus everyone who can answer from the console. Same roster walk as users.groovy.
List out = []
def hits = archive.query("user").all().search(); hits.enableBulkOperations()
for (Data u in hits) {
  String id = u.getId()
  if (id == me || "false".equals(String.valueOf(u.get("enabled")))) continue
  String role = roles[id] ?: "users"
  boolean teammate = myteam && u.get("team") == myteam
  if (!teammate && !(role in STAFF)) continue
  String name = "${u.get('firstName') ?: ''} ${u.get('lastName') ?: ''}".trim()
  out << [id: id, name: name ?: id, role: role]
}
out.sort { it.name.toLowerCase() }
reply([ok: true, people: out])
```

- [ ] **Step 5: Ask the user to deploy, then curl a full round trip**

With `$BASE`, `$H`, `$Q` from Task 1 step 5:

```bash
curl -s "$BASE/services/testu/social/mentionables.json" -H "$H"
# -> {"ok":true,"people":[{"id":"...","name":"...","role":"orgadmin"}, ...]}  (admin accounts at least; teammates if the learner has a team)

C1=$(curl -s -X POST $BASE/services/testu/social/comment.json -H "$H" -d channel=q-$Q -d message="Primer comentario desde curl" -d mentions='[]' \
  | python3 -c 'import json,sys;print(json.load(sys.stdin)["id"])')
curl -s -X POST $BASE/services/testu/social/comment.json -H "$H" -d channel=q-$Q -d message="Respuesta" -d replytoid=$C1 -d mentions='[]'
# -> {"ok":true,"id":"...","replytoid":"<C1>","mentions":[]}

curl -s -X POST $BASE/services/testu/social/react.json -H "$H" -d messageid=$C1 -d name=idea     # -> {"ok":true,"mine":"idea","reacts":{"idea":1}}
curl -s -X POST $BASE/services/testu/social/react.json -H "$H" -d messageid=$C1 -d name=idea     # -> {"ok":true,"mine":null,"reacts":{}}   (toggle off)
curl -s -X POST $BASE/services/testu/social/react.json -H "$H" -d messageid=$C1 -d name=like     # -> {"ok":true,"mine":"like","reacts":{"like":1}}

curl -s "$BASE/services/testu/social/thread.json?channel=q-$Q" -H "$H"
```

Expected last output: one top-level comment with `"name"`, `"role":"users"`, `"reacts":{"like":1}`, `"mine":"like"` and one entry in `replies`.

Negative checks: `-d name=hug` → `400 bad reaction`; `-d messageid=nope` → `404 no such comment`; `-d channel=q-$Q -d message=""` → `400 empty message`.

- [ ] **Step 6: Leave uncommitted for the user**

---

### Task 4: `testu_social_api.dart` (models + typed client) with unit tests

**Files:**
- Create: `lib/testu/testu_social_api.dart`
- Test: `test/testu_social_api_test.dart`

**Interfaces:**
- Consumes: `EmeHttp.getJson(path, {query})` / `postForm(path, fields)` (`eme_app_package/lib/eme_http.dart:46-57`), `DioEmeHttp()` default like `lib/testu/testu_usage.dart:26-27`, `L()` from `testu_i18n.dart`.
- Produces (every later task uses these exact names):
  - `enum TestuReaction { like, applause, support, love, idea, laugh }` (moved out of `testu_social.dart:436`).
  - `class TestuComment(who, role, avatar, text, {reacts, id = '', userId = '', date})` with `String? avatar`, `factory TestuComment.fromJson(Map)`.
  - `TestuReaction? reactionOf(String name)`, `String? roleBadge(String role)`, `const testuFlagReasons = ['wrong','unclear','outdated','other']`, `String flagReasonLabel(String id)`.
  - `class Mentionable(id, name, role)`, `class RecentComment`, `class QuestionFlagRow`, `class SocialRecent(comments, flags)`.
  - `class TestuSocialApi({EmeHttp? http})` with `thread(channel)`, `comment({channel, text, replyToId, mentions})`, `react(messageId, TestuReaction?)`, `mentionables()`, `recent()`, `flag({questionId, tutorialId, reason, note})`; global `final testuSocial = TestuSocialApi()`.

- [ ] **Step 1: Write the failing unit tests**

`test/testu_social_api_test.dart`:

```dart
import 'package:eme_app_package/testing/fake_eme_http.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/testu/testu_social_api.dart';

const _thread = 'services/testu/social/thread.json';
const _comment = 'services/testu/social/comment.json';
const _react = 'services/testu/social/react.json';
const _people = 'services/testu/social/mentionables.json';
const _flag = 'services/testu/social/flag.json';

Map<String, dynamic> _threadJson() => {
      'ok': true,
      'channel': 'q-Q1',
      'comments': [
        {
          'id': 'c1',
          'userId': 'lucia',
          'name': 'Lucía Mendoza',
          'role': 'users',
          'date': '2026-09-07T10:00:00-05:00',
          'text': 'Me confundió a quiénes aplican.',
          'reacts': {'like': 3, 'support': 1, 'bogus': 9},
          'mine': 'like',
          'replies': [
            {
              'id': 'c2',
              'userId': 'jorge',
              'name': 'Jorge Paredes',
              'role': 'training',
              'date': '2026-09-07T10:05:00-05:00',
              'text': 'Aplican a todas las personas.',
              'reacts': {},
              'mine': null,
              'replies': [],
            },
          ],
        },
      ],
    };

void main() {
  late FakeEmeHttp http;
  late TestuSocialApi api;
  setUp(() {
    http = FakeEmeHttp();
    api = TestuSocialApi(http: http);
  });

  test('thread parses comments, replies, reactions and my reaction', () async {
    http.canned[_thread] = _threadJson();
    final rows = await api.thread('q-Q1');
    expect(http.requests.single.$1, _thread);
    expect(http.requests.single.$2, containsPair('channel', 'q-Q1'));
    final c = rows.single;
    expect(c.id, 'c1');
    expect(c.userId, 'lucia');
    expect(c.who, 'Lucía Mendoza');
    expect(c.role, isNull, reason: 'a learner wears no badge');
    expect(c.avatar, isNull, reason: 'live rows draw initials');
    expect(c.date, DateTime.parse('2026-09-07T10:00:00-05:00'));
    // Unknown reaction names from the server are dropped, never crash the parse.
    expect(c.reacts, {TestuReaction.like: 3, TestuReaction.support: 1});
    expect(c.myReact, TestuReaction.like);
    expect(c.replies.single.role, 'INSTRUCTOR');
    expect(c.replies.single.myReact, isNull);
  });

  test('comment posts channel, message, replytoid and mentions as ids', () async {
    http.canned[_comment] = {'ok': true, 'id': 'c9'};
    final id = await api.comment(
        channel: 'q-Q1', text: 'Hola @Jorge Paredes', replyToId: 'c1', mentions: ['jorge']);
    expect(id, 'c9');
    final f = http.posted.single.fields;
    expect(http.posted.single.path, _comment);
    expect(f['channel'], 'q-Q1');
    expect(f['message'], 'Hola @Jorge Paredes');
    expect(f['replytoid'], 'c1');
    expect(f['mentions'], '["jorge"]');
  });

  test('a top-level comment sends no replytoid and an empty mentions list', () async {
    http.canned[_comment] = {'ok': true, 'id': 'c9'};
    await api.comment(channel: 't-TUT1', text: 'Buena actualización');
    final f = http.posted.single.fields;
    expect(f.containsKey('replytoid'), isFalse);
    expect(f['mentions'], '[]');
  });

  test('react sends the reaction name, or an empty name to clear it', () async {
    http.canned[_react] = {'ok': true, 'mine': 'idea', 'reacts': {'idea': 1}};
    await api.react('c1', TestuReaction.idea);
    await api.react('c1', null);
    expect(http.posted[0].fields, {'messageid': 'c1', 'name': 'idea'});
    expect(http.posted[1].fields, {'messageid': 'c1', 'name': ''});
  });

  test('mentionables parses people', () async {
    http.canned[_people] = {
      'ok': true,
      'people': [
        {'id': 'jorge', 'name': 'Jorge Paredes', 'role': 'training'},
        {'id': 'rosa', 'name': 'Rosa Jiménez', 'role': 'users'},
      ],
    };
    final p = await api.mentionables();
    expect(p.map((m) => m.id), ['jorge', 'rosa']);
    expect(p.first.role, 'training');
  });

  test('recent parses comments and open flags', () async {
    http.canned[_thread] = {
      'ok': true,
      'recent': [
        {
          'id': 'c1',
          'channel': 'q-Q1',
          'moduleid': 'entityquestion',
          'entityid': 'Q1',
          'label': '¿Qué son los Derechos Humanos?',
          'userId': 'lucia',
          'name': 'Lucía Mendoza',
          'role': 'users',
          'date': '2026-09-07T10:00:00-05:00',
          'text': 'Me confundió.',
          'replytoid': null,
        },
      ],
      'flags': [
        {
          'id': 'f1',
          'entityquestion': 'Q1',
          'entitytutorial': 'TUT1',
          'label': '¿Qué son los Derechos Humanos?',
          'reason': 'unclear',
          'note': 'curl smoke',
          'userId': 'lucia',
          'name': 'Lucía Mendoza',
          'date': '2026-09-07T09:00:00-05:00',
        },
      ],
    };
    final r = await api.recent();
    expect(http.requests.single.$2, isEmpty, reason: 'no channel means the recent listing');
    expect(r.comments.single.channel, 'q-Q1');
    expect(r.comments.single.label, '¿Qué son los Derechos Humanos?');
    expect(r.flags.single.reason, 'unclear');
    expect(r.flags.single.questionId, 'Q1');
  });

  test('flag posts question, tutorial, reason and note', () async {
    http.canned[_flag] = {'ok': true, 'id': 'f1'};
    await api.flag(questionId: 'Q1', tutorialId: 'TUT1', reason: 'wrong', note: 'p. 3 dice otra cosa');
    expect(http.posted.single.fields,
        {'entityquestion': 'Q1', 'entitytutorial': 'TUT1', 'reason': 'wrong', 'note': 'p. 3 dice otra cosa'});
  });

  test('a 2xx body with ok:false throws with the server message', () async {
    http.canned[_flag] = {'ok': false, 'error': 'bad reason'};
    await expectLater(
        api.flag(questionId: 'Q1', reason: 'x'), throwsA(predicate((e) => '$e'.contains('bad reason'))));
  });

  test('reason ids and labels line up', () {
    expect(testuFlagReasons, ['wrong', 'unclear', 'outdated', 'other']);
    expect(flagReasonLabel('unclear'), 'Confusing or badly worded');
    expect(roleBadge('users'), isNull);
    expect(roleBadge('manager'), 'MANAGER');
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/testu_social_api_test.dart`
Expected: compile error, `Target of URI doesn't exist: 'package:genai_labs/testu/testu_social_api.dart'`.

- [ ] **Step 3: Write `lib/testu/testu_social_api.dart`**

```dart
import 'dart:convert';

import 'package:eme_app_package/eme_http.dart';

import 'testu_i18n.dart';

/// Social threads and question reports: the plugin's services/testu/social/*
/// endpoints, one typed method each. Shared by the learner app (TestuThread)
/// and the console (Conversaciones); the console hands it its own http.
/// The server takes the user from the session, so nothing here says who.

/// App-wide reaction vocabulary (replaced TestuVote 2026-09-01). The names
/// are the wire format: react.json takes `name`, thread.json returns them.
enum TestuReaction { like, applause, support, love, idea, laugh }

TestuReaction? reactionOf(String name) =>
    TestuReaction.values.where((r) => r.name == name).firstOrNull;

/// The badge a `userprofile.settingsgroup` earns in a thread; learners wear
/// none. IRIS never posts in threads (out of scope), so there is no tutor badge live.
String? roleBadge(String role) => switch (role) {
      'training' => L('INSTRUCTOR', 'INSTRUCTOR'),
      'manager' => 'MANAGER',
      'orgadmin' => L('ADMIN', 'ADMIN'),
      _ => null,
    };

/// `questionflagreason` ids, in the order the report sheet lists them.
const testuFlagReasons = ['wrong', 'unclear', 'outdated', 'other'];

String flagReasonLabel(String id) => switch (id) {
      'wrong' => L('Incorrect', 'Incorrecta'),
      'unclear' => L('Confusing or badly worded', 'Confusa o mal redactada'),
      'outdated' => L('Outdated', 'Desactualizada'),
      _ => L('Other', 'Otro'),
    };

class TestuComment {
  TestuComment(this.who, this.role, this.avatar, this.text,
      {Map<TestuReaction, int>? reacts, this.id = '', this.userId = '', this.date})
      : reacts = reacts ?? {};

  /// Server id, author id and time; empty/null on the demo's mock rows.
  final String id;
  final String userId;
  final DateTime? date;
  final String who;
  final String? role; // badge, null = learner

  /// Asset path of a demo avatar; null draws initials (live has no photos).
  final String? avatar;
  final String text;
  final List<TestuComment> replies = [];
  final Map<TestuReaction, int> reacts;
  TestuReaction? myReact;
  bool reported = false;

  /// One `comments[]` row of thread.json, replies included. Unknown reaction
  /// names are dropped rather than crashing the parse.
  factory TestuComment.fromJson(Map j) {
    final reacts = <TestuReaction, int>{};
    for (final e in ((j['reacts'] as Map?) ?? const {}).entries) {
      final r = reactionOf('${e.key}');
      if (r != null) reacts[r] = (e.value as num?)?.toInt() ?? 0;
    }
    final c = TestuComment(
      '${j['name'] ?? j['userId'] ?? ''}',
      roleBadge('${j['role'] ?? 'users'}'),
      null,
      '${j['text'] ?? ''}',
      reacts: reacts,
      id: '${j['id'] ?? ''}',
      userId: '${j['userId'] ?? ''}',
      date: DateTime.tryParse('${j['date'] ?? ''}'),
    )..myReact = reactionOf('${j['mine'] ?? ''}');
    for (final r in (j['replies'] as List? ?? const [])) {
      c.replies.add(TestuComment.fromJson(r as Map));
    }
    return c;
  }
}

/// One entry of the `@` picker.
class Mentionable {
  Mentionable(this.id, this.name, this.role);
  final String id, name, role;

  factory Mentionable.fromJson(Map j) => Mentionable(
      '${j['id'] ?? ''}', '${j['name'] ?? j['id'] ?? ''}', '${j['role'] ?? 'users'}');
}

/// One row of the console's recent list (thread.json without a channel).
class RecentComment {
  RecentComment({
    required this.id,
    required this.channel,
    required this.label,
    required this.who,
    required this.role,
    required this.text,
    this.date,
    this.replyToId,
  });
  final String id, channel, label, who, role, text;
  final DateTime? date;
  final String? replyToId;

  factory RecentComment.fromJson(Map j) => RecentComment(
        id: '${j['id'] ?? ''}',
        channel: '${j['channel'] ?? ''}',
        label: '${j['label'] ?? j['entityid'] ?? ''}',
        who: '${j['name'] ?? j['userId'] ?? ''}',
        role: '${j['role'] ?? 'users'}',
        text: '${j['text'] ?? ''}',
        date: DateTime.tryParse('${j['date'] ?? ''}'),
        replyToId: j['replytoid']?.toString(),
      );
}

/// One open question report, for the console.
class QuestionFlagRow {
  QuestionFlagRow({
    required this.id,
    required this.questionId,
    required this.label,
    required this.reason,
    required this.note,
    required this.who,
    this.date,
  });
  final String id, questionId, label, reason, note, who;
  final DateTime? date;

  factory QuestionFlagRow.fromJson(Map j) => QuestionFlagRow(
        id: '${j['id'] ?? ''}',
        questionId: '${j['entityquestion'] ?? ''}',
        label: '${j['label'] ?? j['entityquestion'] ?? ''}',
        reason: '${j['reason'] ?? 'other'}',
        note: '${j['note'] ?? ''}',
        who: '${j['name'] ?? j['userId'] ?? ''}',
        date: DateTime.tryParse('${j['date'] ?? ''}'),
      );
}

class SocialRecent {
  SocialRecent(this.comments, this.flags);
  final List<RecentComment> comments;
  final List<QuestionFlagRow> flags;
}

class TestuSocialApi {
  TestuSocialApi({EmeHttp? http}) : _http = http ?? DioEmeHttp();
  final EmeHttp _http;
  static const _base = 'services/testu/social/';

  /// Every endpoint answers `{ok:true,...}` or `{ok:false,error}` with a
  /// non-2xx status; the transport already throws on the status, this
  /// catches a 2xx that still says no.
  Map<String, dynamic> _ok(Map<String, dynamic> j) {
    if (j['ok'] != true) throw Exception('${j['error'] ?? 'error'}');
    return j;
  }

  Future<List<TestuComment>> thread(String channel) async {
    final j = _ok(await _http.getJson('${_base}thread.json', query: {'channel': channel}));
    return [for (final c in j['comments'] as List? ?? const []) TestuComment.fromJson(c as Map)];
  }

  /// Returns the new comment's id. [mentions] are user ids from
  /// [mentionables]; the server parses nothing out of [text].
  Future<String> comment({
    required String channel,
    required String text,
    String? replyToId,
    List<String> mentions = const [],
  }) async {
    final j = _ok(await _http.postForm('${_base}comment.json', [
      MapEntry('channel', channel),
      MapEntry('message', text),
      if (replyToId != null) MapEntry('replytoid', replyToId),
      MapEntry('mentions', jsonEncode(mentions)),
    ]));
    return '${j['id'] ?? ''}';
  }

  /// Sets my reaction on [messageId]; null clears it.
  Future<void> react(String messageId, TestuReaction? r) async {
    _ok(await _http.postForm('${_base}react.json', [
      MapEntry('messageid', messageId),
      MapEntry('name', r?.name ?? ''),
    ]));
  }

  Future<List<Mentionable>> mentionables() async {
    final j = _ok(await _http.getJson('${_base}mentionables.json'));
    return [for (final p in j['people'] as List? ?? const []) Mentionable.fromJson(p as Map)];
  }

  /// The console's listing: newest comments and open flags in my scope.
  Future<SocialRecent> recent() async {
    final j = _ok(await _http.getJson('${_base}thread.json'));
    return SocialRecent(
      [for (final c in j['recent'] as List? ?? const []) RecentComment.fromJson(c as Map)],
      [for (final f in j['flags'] as List? ?? const []) QuestionFlagRow.fromJson(f as Map)],
    );
  }

  Future<void> flag({
    required String questionId,
    String? tutorialId,
    required String reason,
    String? note,
  }) async {
    _ok(await _http.postForm('${_base}flag.json', [
      MapEntry('entityquestion', questionId),
      if (tutorialId != null) MapEntry('entitytutorial', tutorialId),
      MapEntry('reason', reason),
      if (note != null) MapEntry('note', note),
    ]));
  }
}

/// The app's single social client. Lazily built (top-level finals are), so
/// it never runs before Dio is up -- same rule as [testuUsage].
final testuSocial = TestuSocialApi();
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/testu_social_api_test.dart`
Expected: `All tests passed!` (9 tests).

- [ ] **Step 5: Leave uncommitted for the user**

---

### Task 5: `TestuThread` live (load, comment, react, `@` picker), `SocialThreadEntry(channel:)`

**Files:**
- Modify: `lib/testu/testu_social.dart:1-40` (imports, moved types), `:42-97` (`TestuThread` + state head), `:99-131` (`_commentBlock`), `:154-220` (`_comment` avatar + reactions), `:366-431` (`SocialThreadEntry`), `:436-436` (enum removed)
- Test: `test/testu_thread_test.dart`

**Interfaces:**
- Consumes: Task 4's `TestuSocialApi`, `TestuComment`, `TestuReaction`, `Mentionable`, `roleBadge`, `testuSocial`; existing `TestuComposer({hint, controller, onSend})` (`testu_widgets.dart:372-396`), `showTestuListSheet(context, {title, rows})` with `TestuSheetRow` records (`testu_widgets.dart:800-816`), `TestuSkeletonRow({thumb, pill})` (`:944`), `TestuAct(label, {onTap})` (`:141-149`), `TestuPressable`, `TestuReactions` (unchanged).
- Produces:
  - `TestuThread({List<TestuComment>? comments, String? channel, TestuSocialApi? api, required composerHint, required reportEyebrow, required reportTitle, VoidCallback? onChanged, ValueChanged<int>? onCount})`. Exactly one of `comments` (demo) / `channel` (live) is given.
  - `SocialThreadEntry({String? channel})`: null = mock thread (demo), else live.
  - `testu_social.dart` re-exports `TestuComment` and `TestuReaction`, so `testu_session.dart:16` and `testu_topics.dart:10` keep compiling without new imports.

- [ ] **Step 1: Write the failing widget tests**

`test/testu_thread_test.dart`:

```dart
import 'package:eme_app_package/testing/fake_eme_http.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/testu/testu_social.dart';
import 'package:genai_labs/testu/testu_social_api.dart';
import 'package:genai_labs/testu/testu_theme.dart';

const _thread = 'services/testu/social/thread.json';
const _comment = 'services/testu/social/comment.json';
const _react = 'services/testu/social/react.json';
const _people = 'services/testu/social/mentionables.json';

Map<String, dynamic> _threadJson() => {
      'ok': true,
      'channel': 'q-Q1',
      'comments': [
        {
          'id': 'c1',
          'userId': 'lucia',
          'name': 'Lucía Mendoza',
          'role': 'users',
          'date': '2026-09-07T10:00:00-05:00',
          'text': 'Me confundió a quiénes aplican.',
          'reacts': {'like': 3},
          'mine': null,
          'replies': [
            {
              'id': 'c2',
              'userId': 'jorge',
              'name': 'Jorge Paredes',
              'role': 'training',
              'date': '2026-09-07T10:05:00-05:00',
              'text': 'Aplican a todas las personas.',
              'reacts': {},
              'mine': null,
              'replies': [],
            },
          ],
        },
      ],
    };

Future<FakeEmeHttp> _pump(WidgetTester tester, {bool canned = true, void Function(int)? onCount}) async {
  final http = FakeEmeHttp();
  if (canned) http.canned[_thread] = _threadJson();
  http.canned[_comment] = {'ok': true, 'id': 'c9'};
  http.canned[_react] = {'ok': true, 'mine': 'idea', 'reacts': {'idea': 1}};
  http.canned[_people] = {
    'ok': true,
    'people': [
      {'id': 'jorge', 'name': 'Jorge Paredes', 'role': 'training'},
    ],
  };
  await tester.pumpWidget(MaterialApp(
    theme: testuTheme(),
    home: Scaffold(
      body: SingleChildScrollView(
        child: TestuThread(
          channel: 'q-Q1',
          api: TestuSocialApi(http: http),
          composerHint: 'Reply to the thread…',
          reportEyebrow: 'CONVERSATION · REPORT',
          reportTitle: 'Report this comment',
          onCount: onCount,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return http;
}

void main() {
  testWidgets('renders live rows with names, badges, initials and reply counts', (tester) async {
    await _pump(tester);
    expect(find.text('Lucía Mendoza'), findsOneWidget);
    expect(find.text('Me confundió a quiénes aplican.'), findsOneWidget);
    // Threads start closed: the reply and its INSTRUCTOR badge appear on «Reply 1».
    expect(find.text('Jorge Paredes'), findsNothing);
    expect(find.text('1'), findsOneWidget);
    expect(find.byType(Image), findsNothing, reason: 'live rows draw initials, no asset photo');
    expect(find.text('LM'), findsOneWidget);
    await tester.tap(find.text('Reply'));
    await tester.pumpAndSettle();
    expect(find.text('Jorge Paredes'), findsOneWidget);
    expect(find.text('INSTRUCTOR'), findsOneWidget);
  });

  testWidgets('sending posts to comment.json, reloads and clears the composer', (tester) async {
    final http = await _pump(tester);
    await tester.enterText(find.byType(TextField).first, 'Hola a todos');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(http.posted.single.path, _comment);
    expect(http.posted.single.fields['channel'], 'q-Q1');
    expect(http.posted.single.fields['message'], 'Hola a todos');
    expect(http.posted.single.fields['mentions'], '[]');
    // thread.json was fetched twice: on open and after the send.
    expect(http.requests.where((r) => r.$1 == _thread).length, 2);
    expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, isEmpty);
  });

  testWidgets('a failed send keeps the text and says so', (tester) async {
    final http = await _pump(tester);
    http.canned.remove(_comment); // 404 from the fake
    await tester.enterText(find.byType(TextField).first, 'Se queda');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(find.text('Could not send. Try again.'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, 'Se queda');
  });

  testWidgets('a reaction posts to react.json', (tester) async {
    final http = await _pump(tester);
    await tester.tap(find.text('Like'));
    await tester.pumpAndSettle();
    expect(http.posted.single.path, _react);
    expect(http.posted.single.fields, {'messageid': 'c1', 'name': 'like'});
  });

  testWidgets('the @ picker inserts the name and sends the id', (tester) async {
    final http = await _pump(tester);
    // The `@` button's child is a Text('@'); no semantics handle needed.
    await tester.tap(find.text('@'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jorge Paredes'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, '@Jorge Paredes ');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(http.posted.single.fields['mentions'], '["jorge"]');
  });

  testWidgets('a failed load shows the error and Retry refetches', (tester) async {
    final http = await _pump(tester, canned: false);
    expect(find.text('Could not load the conversation.'), findsOneWidget);
    http.canned[_thread] = _threadJson();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Lucía Mendoza'), findsOneWidget);
  });

  testWidgets('onCount reports comments plus replies', (tester) async {
    int? seen;
    await _pump(tester, onCount: (n) => seen = n);
    expect(seen, 2);
  });

  testWidgets('the demo entry still shows the mock thread', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: testuTheme(),
      home: const Scaffold(body: SingleChildScrollView(child: SocialThreadEntry())),
    ));
    await tester.pumpAndSettle();
    // _mockThread(): two top-level comments, the first with two replies.
    expect(find.textContaining('Conversations on this question · 4'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/testu_thread_test.dart`
Expected: compile errors (`channel`, `api`, `onCount` are not defined for `TestuThread`; `TestuSocialApi` unresolved until Task 4 landed, resolved after it).

- [ ] **Step 3: Move the types and re-export them**

In `lib/testu/testu_social.dart`, replace lines 1-9 (imports) with:

```dart
import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'testu_i18n.dart';
import 'testu_icons.dart';
import 'testu_report_sheet.dart';
import 'testu_social_api.dart';
import 'testu_theme.dart';
import 'testu_widgets.dart';
import 'testu_client.dart';

export 'testu_social_api.dart' show TestuComment, TestuReaction;
```

Delete lines 26-40 (the `ponytail: thread data is mock` doc line and the whole `class TestuComment { ... }`), and delete line 436 (`enum TestuReaction { like, applause, support, love, idea, laugh }`). Replace the deleted doc line with:

```dart
/// Thread data: the demo passes a mock list; live passes a channel and the
/// thread reads/writes services/testu/social/* through [TestuSocialApi].
```

- [ ] **Step 4: Rewrite `TestuThread` and its state head (old lines 42-97)**

```dart
/// Reusable thread: comments with vote/reply/report + bottom composer.
/// Demo: mutates [comments] in place. Live: [channel] is loaded from
/// thread.json and every send/reaction goes to the server, which is the
/// source of truth (author name, id, time) -- so a successful send reloads
/// instead of appending a local guess. [onChanged] lets the host refresh.
class TestuThread extends StatefulWidget {
  const TestuThread({
    super.key,
    this.comments,
    this.channel,
    this.api,
    required this.composerHint,
    required this.reportEyebrow,
    required this.reportTitle,
    this.onChanged,
    this.onCount,
  }) : assert(comments != null || channel != null, 'demo list or live channel');

  /// Demo rows, mutated in place. Null when [channel] is live.
  final List<TestuComment>? comments;

  /// `q-<entityquestion>` or `t-<entitytutorial>`. Null = demo.
  final String? channel;

  /// Live transport; the app's singleton unless a test or the console hands one in.
  final TestuSocialApi? api;
  final String composerHint;
  final String reportEyebrow;
  final String reportTitle;
  final VoidCallback? onChanged;

  /// Comments + replies on screen, after every load or send (the entry row's count).
  final ValueChanged<int>? onCount;

  @override
  State<TestuThread> createState() => _TestuThreadState();
}

class _TestuThreadState extends State<TestuThread> {
  late List<TestuComment> _comments = widget.comments ?? [];
  bool _loading = false;
  Object? _error;

  /// Parent comment whose inline reply composer is open, if any.
  TestuComment? _replyingTo;

  /// Who the composer addresses — the person whose Reply was tapped
  /// (a reply's author, not its parent, when tapped on a reply row).
  String _replyName = '';

  /// Parents whose replies are shown. Threads start CLOSED — only main
  /// comments listed; tapping «Reply N» opens that comment's replies and
  /// the composer underneath (tap again to fold).
  final _expanded = <TestuComment>{};

  // Live composers own their controllers so a failed send keeps the text.
  // Each composer keeps the ids picked from the @ sheet for its own send.
  final _draft = TextEditingController();
  final _replyDraft = TextEditingController();
  final _draftMentions = <String>{};
  final _replyMentions = <String>{};
  List<Mentionable>? _people;

  bool get _live => widget.channel != null;
  TestuSocialApi get _api => widget.api ?? testuSocial;
  int get _count => _comments.fold(_comments.length, (a, c) => a + c.replies.length);

  @override
  void initState() {
    super.initState();
    if (_live) _load();
  }

  @override
  void dispose() {
    _draft.dispose();
    _replyDraft.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _api.thread(widget.channel!);
      if (!mounted) return;
      // Unfolded parents stay unfolded across a reload: match by id.
      final open = {for (final c in _expanded) c.id};
      setState(() {
        _comments = rows;
        _expanded
          ..clear()
          ..addAll(rows.where((c) => open.contains(c.id)));
        _replyingTo = rows.where((c) => c.id == _replyingTo?.id).firstOrNull;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    if (mounted) widget.onCount?.call(_count);
  }

  void _mutate(VoidCallback fn) {
    setState(fn);
    widget.onChanged?.call();
    widget.onCount?.call(_count);
  }

  void _snack(String text) =>
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));

  /// Live send. On failure the text stays where it was.
  Future<void> _post(TextEditingController ctl, Set<String> mentions, {TestuComment? parent}) async {
    final text = ctl.text.trim();
    if (text.isEmpty) return;
    try {
      await _api.comment(
          channel: widget.channel!, text: text, replyToId: parent?.id, mentions: mentions.toList());
    } catch (_) {
      _snack(L('Could not send. Try again.', 'No se pudo enviar. Inténtalo de nuevo.'));
      return;
    }
    ctl.clear();
    mentions.clear();
    if (parent != null) {
      _expanded.add(parent);
      _replyingTo = null;
    }
    await _load();
    widget.onChanged?.call();
  }

  /// Optimistic: TestuReactions already moved the counts; a failed write
  /// reloads so the row shows the server's truth again.
  void _react(TestuComment c, TestuReaction? r) {
    _mutate(() => c.myReact = r);
    if (!_live) return;
    unawaited(_api.react(c.id, r).catchError((Object _) {
      _snack(L('Could not save your reaction.', 'No se pudo guardar tu reacción.'));
      _load();
    }));
  }

  /// The `@` picker: people from mentionables.json (fetched once per thread),
  /// a pick appends `@Nombre ` to the field and keeps the id for the send.
  Future<void> _pickMention(TextEditingController ctl, Set<String> mentions) async {
    HapticFeedback.selectionClick();
    try {
      _people ??= await _api.mentionables();
    } catch (_) {
      _snack(L('Could not load people.', 'No se pudo cargar la lista de personas.'));
      return;
    }
    if (!mounted) return;
    final people = _people!;
    if (people.isEmpty) {
      _snack(L('Nobody to mention yet.', 'Todavía no hay a quién mencionar.'));
      return;
    }
    await showTestuListSheet(
      context,
      title: L('MENTION', 'MENCIONAR'),
      rows: [
        for (final p in people)
          (
            tag: null,
            label: p.name,
            trailing: roleBadge(p.role),
            selected: mentions.contains(p.id),
            indent: false,
            onTap: () {
              mentions.add(p.id);
              final t = ctl.text;
              ctl.text = '${t.isEmpty || t.endsWith(' ') ? t : '$t '}@${p.name} ';
              ctl.selection = TextSelection.collapsed(offset: ctl.text.length);
            },
          ),
      ],
    );
  }

  /// Live composer: the house pill plus the `@` button.
  Widget _composer(TestuTokens t,
          {required String hint,
          required TextEditingController ctl,
          required Set<String> mentions,
          required Future<void> Function() onSend}) =>
      Row(children: [
        Expanded(child: TestuComposer(hint: hint, controller: ctl, onSend: (_) => onSend())),
        const SizedBox(width: 6),
        Semantics(
          button: true,
          label: L('Mention someone', 'Mencionar a alguien'),
          child: TestuPressable(
            onTap: () => _pickMention(ctl, mentions),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: t.line2)),
              child: Text('@',
                  style: TextStyle(fontFamily: 'GeistMono', fontSize: 13, color: t.mut)),
            ),
          ),
        ),
      ]);

  Widget _errorRow(TestuTokens t) => Row(children: [
        Expanded(
          child: Text(L('Could not load the conversation.', 'No se pudo cargar la conversación.'),
              style: TextStyle(fontFamily: 'Geist', fontSize: 12, color: t.mut)),
        ),
        TestuAct(L('Retry', 'Reintentar'), onTap: _load),
      ]);

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    if (_live && _loading && _comments.isEmpty) {
      return const Column(children: [
        TestuSkeletonRow(thumb: 20, pill: false),
        TestuSkeletonRow(thumb: 20, pill: false),
      ]);
    }
    if (_live && _error != null && _comments.isEmpty) return _errorRow(t);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_live && _comments.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
                L('Nobody has commented yet. Be the first.',
                    'Nadie ha comentado todavía. Sé la primera persona.'),
                style: TextStyle(fontFamily: 'Geist', fontSize: 12, color: t.mut)),
          ),
        for (final c in _comments) ..._commentBlock(t, c),
        const SizedBox(height: 4),
        if (_live)
          _composer(t,
              hint: widget.composerHint,
              ctl: _draft,
              mentions: _draftMentions,
              onSend: () => _post(_draft, _draftMentions))
        else
          TestuComposer(
            hint: widget.composerHint,
            onSend: (text) => _mutate(() => _comments.add(TestuComment(
                '${client.persona} ${client.personaFull.split(' ').last[0]}.',
                null,
                client.personaAvatar,
                text))),
          ),
      ],
    );
  }
```

- [ ] **Step 5: Reply composer inside `_commentBlock` (old lines 115-128)**

Replace the `if (_replyingTo == c) Padding(...)` block with:

```dart
                if (_replyingTo == c)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _live
                        ? _composer(t,
                            hint: L('Reply to $_replyName…', 'Responde a $_replyName…'),
                            ctl: _replyDraft,
                            mentions: _replyMentions,
                            onSend: () => _post(_replyDraft, _replyMentions, parent: c))
                        : TestuComposer(
                            hint: L('Reply to $_replyName…', 'Responde a $_replyName…'),
                            onSend: (text) => _mutate(() {
                              c.replies.add(TestuComment(
                                  '${client.persona} ${client.personaFull.split(' ').last[0]}.',
                                  null,
                                  client.personaAvatar,
                                  text));
                              _expanded.add(c);
                              _replyingTo = null;
                            }),
                          ),
                  ),
```

- [ ] **Step 6: Avatar and reactions inside `_comment` (old lines 176-180 and 217-221)**

Replace the `ClipOval(child: Image.asset(c.avatar, ...))` at old lines 176-180 with:

```dart
              c.avatar == null
                  ? _initials(t, c.who, reply ? 16 : 20)
                  : ClipOval(
                      child: Image.asset(c.avatar!,
                          width: reply ? 16 : 20, height: reply ? 16 : 20, fit: BoxFit.cover)),
```

Replace `onChanged: (r) => _mutate(() => c.myReact = r),` at old line 219 with:

```dart
                onChanged: (r) => _react(c, r),
```

Add this method to `_TestuThreadState` (after `_errorRow`):

```dart
  /// Live rows have no photo: two initials on the house disc (Part A's rule).
  Widget _initials(TestuTokens t, String who, double size) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration:
            BoxDecoration(color: t.card2, shape: BoxShape.circle, border: Border.all(color: t.line2)),
        child: Text(
          who.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase(),
          style: TextStyle(
              fontFamily: 'Geist', fontSize: size * 0.42, fontWeight: FontWeight.w600, color: t.mut),
        ),
      );
```

- [ ] **Step 7: `SocialThreadEntry` takes a channel (old lines 366-431)**

```dart
/// Social learning thread on a question — appears under the verdict, only
/// after answer AND confidence are submitted, expanding INLINE in the
/// transcript (chosen over sheet/screen variants, 2026-08-31).
class SocialThreadEntry extends StatefulWidget {
  const SocialThreadEntry({super.key, this.channel});

  /// Live channel (`q-<entityquestion>`); null shows the demo's mock thread.
  final String? channel;

  @override
  State<SocialThreadEntry> createState() => _SocialThreadEntryState();
}

class _SocialThreadEntryState extends State<SocialThreadEntry> {
  late final List<TestuComment>? _thread = widget.channel == null ? _mockThread() : null;
  bool _open = false;

  /// Live: known once the thread has loaded (it loads on first open), so the
  /// row reads "Conversaciones sobre esta pregunta" until then.
  int? _liveCount;

  int? get _count => _thread == null
      ? _liveCount
      : _thread!.fold(_thread!.length, (a, c) => a + c.replies.length);

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    final n = _count;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TestuPressable(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _open = !_open);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                TestuIcon(TestuGlyph.chat, size: 13, color: t.faint),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    n == null
                        ? L('Conversations on this question', 'Conversaciones sobre esta pregunta')
                        : L('Conversations on this question · $n',
                            'Conversaciones sobre esta pregunta · $n'),
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 10.5,
                      letterSpacing: 0.42,
                      color: t.mut,
                    ),
                  ),
                ),
                TestuIcon(_open ? TestuGlyph.minus : TestuGlyph.plus,
                    size: 13, color: t.faint),
              ],
            ),
          ),
        ),
        if (_open)
          TestuThread(
            comments: _thread,
            channel: widget.channel,
            composerHint: L('Reply to the thread…', 'Responde al hilo…'),
            reportEyebrow:
                L('CONVERSATION · REPORT', 'CONVERSACIÓN · REPORTAR'),
            reportTitle: L('Report this comment', 'Reportar este comentario'),
            onChanged: () => setState(() {}),
            onCount: (c) {
              if (mounted) setState(() => _liveCount = c);
            },
          ),
      ],
    );
  }
}
```

- [ ] **Step 8: Run the tests**

Run: `flutter test test/testu_thread_test.dart test/testu_social_api_test.dart test/landscape_shots_test.dart`
Expected: `All tests passed!`. (`landscape_shots_test.dart:329,463` only uses `showTestuReactionsSheet` and `TestuReaction`, which the re-export keeps in place.)

Then `flutter analyze` and fix any lint in `testu_social.dart` (unused import of `testu_social_api.dart` is impossible here: `Mentionable`, `roleBadge`, `testuSocial` are used).

- [ ] **Step 9: Leave uncommitted for the user**

---

### Task 6: Question reports reach the server (report sheet, `reportFlag`, session copy)

**Files:**
- Modify: `lib/testu/testu_report_sheet.dart:1-31, 52-68, 132-138, 148-156`
- Modify: `lib/testu/testu_question_source.dart:91-98`
- Modify: `lib/testu/testu_live.dart:120-128, 170-199`
- Modify: `lib/testu/testu_session.dart:1279-1346` (`_VerdictExtras`), `:1425-1426`
- Test: `test/testu_social_api_test.dart` (add one test), `test/testu_question_source_test.dart` (unchanged, must still pass)

**Interfaces:**
- Consumes: Task 4's `testuFlagReasons`, `flagReasonLabel`, `TestuSocialApi.flag`; Task 5's `SocialThreadEntry(channel:)`.
- Produces: `showTestuReportSheet(..., required FutureOr<void> Function(String reason, String? note) onSend, String? sentText)`; `TestuQuestionSource.reportFlag` returns `Future<void>`; `EmeQuestionSource.reportFlag` posts `flag.json` with `entityquestion = q.questionId`, `entitytutorial = _liveTutorialId`.

- [ ] **Step 1: Add the failing test for the live source**

Append to `test/testu_social_api_test.dart` (add `import 'package:genai_labs/testu/testu_live.dart';` and `import 'package:genai_labs/testu/testu_question_source.dart';` at the top):

```dart
  test('EmeQuestionSource.reportFlag posts flag.json for a backend question', () async {
    final http = FakeEmeHttp();
    http.canned[_flag] = {'ok': true, 'id': 'f1'};
    final src = EmeQuestionSource(http: http);
    await src.reportFlag(
        q: const TestuQ(questionId: 'Q1', framing: [], kicker: '', text: '', opts: [], okIdx: 0),
        reason: 'outdated',
        note: null);
    expect(http.posted.single.path, _flag);
    expect(http.posted.single.fields['entityquestion'], 'Q1');
    expect(http.posted.single.fields['reason'], 'outdated');
    // A demo question (no id) never reaches the server.
    await src.reportFlag(
        q: const TestuQ(framing: [], kicker: '', text: '', opts: [], okIdx: 0), reason: 'other');
    expect(http.posted.length, 1);
  });
```

Run: `flutter test test/testu_social_api_test.dart`
Expected: FAIL, `The argument type 'void' can't be assigned...` / `await` on a void expression (`reportFlag` still returns `void`).

- [ ] **Step 2: `reportFlag` returns a Future (`testu_question_source.dart:91-98`)**

Replace lines 91-98 with:

```dart
  /// The user flagged a question for the content team. No-op for local
  /// data; the live adapter posts it. Completes (or throws) so the report
  /// sheet can say whether it went through.
  Future<void> reportFlag({
    required TestuQ q,
    required String reason,
    String? note,
  }) async {}
```

- [ ] **Step 3: `EmeQuestionSource` posts it (`testu_live.dart`)**

Add `import 'testu_social_api.dart';` to the imports at the top of `testu_live.dart` (after `import 'testu_session_engine.dart' show Attempt;`).

Replace lines 120-122 (constructor) with:

```dart
class EmeQuestionSource extends TestuQuestionSource {
  EmeQuestionSource({this.topicId, this.sectionId, EmeHttp? http})
      : _service = TopicService(http: http),
        _social = TestuSocialApi(http: http);
```

After line 128 (`final TopicService _service;`) add:

```dart
  final TestuSocialApi _social;
```

After the `reportAttempt` override (old line 198 `}`), add:

```dart
  /// Posts the report to services/testu/social/flag.json. [reason] is a
  /// `questionflagreason` id (testuFlagReasons). Throws on failure so the
  /// sheet keeps the form.
  @override
  Future<void> reportFlag({
    required TestuQ q,
    required String reason,
    String? note,
  }) async {
    if (q.questionId == null) return;
    await _social.flag(
        questionId: q.questionId!, tutorialId: _liveTutorialId, reason: reason, note: note);
  }
```

- [ ] **Step 4: The report sheet awaits the send (`testu_report_sheet.dart`)**

Replace lines 1-31 with:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'testu_i18n.dart';
import 'testu_theme.dart';
import 'testu_widgets.dart';

/// THE report surface — question reports, comment reports, any future
/// "send this to a human team" flow. One visual grammar for all of them:
/// the app's bottom-sheet language (same chrome as the schedule sheet),
/// reason chips + optional note, and the shared green check-pulse success.
/// No Material AlertDialog anywhere in this app.
///
/// [onSend] may return a Future: the sheet waits for it, and a failure
/// keeps the form (reason and note intact) under a one-line error so the
/// retry is one tap. [sentText] is the line under "Sent"; the default admits
/// the report stayed on this device (the demo's truth).
Future<void> showTestuReportSheet(
  BuildContext context, {
  required String eyebrow,
  required String title,
  required String subtitle,
  required List<String> reasons,
  required FutureOr<void> Function(String reason, String? note) onSend,
  String? sentText,
}) {
  return showTestuSheet<void>(
    context,
    builder: (_) => _ReportSheetBody(
      eyebrow: eyebrow,
      title: title,
      subtitle: subtitle,
      reasons: reasons,
      onSend: onSend,
      sentText: sentText,
    ),
  );
}
```

In `_ReportSheetBody` (old lines 33-50) add the field and constructor parameter:

```dart
  const _ReportSheetBody({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.reasons,
    required this.onSend,
    this.sentText,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final List<String> reasons;
  final FutureOr<void> Function(String reason, String? note) onSend;
  final String? sentText;
```

Replace the state's fields and `_send` (old lines 53-68) with:

```dart
  int? _picked;
  bool _sent = false;
  bool _sending = false;
  String? _error;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onSend(
          widget.reasons[_picked!], _note.text.trim().isEmpty ? null : _note.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = L('Could not send. Check your connection and try again.',
            'No se pudo enviar. Revisa la conexión e inténtalo de nuevo.');
      });
    }
  }
```

Replace the `TestuButton(...)` at old lines 132-138 with:

```dart
        TestuButton(
          _picked == null
              ? L('PICK A REASON TO SEND', 'ELIGE UN MOTIVO PARA ENVIAR')
              : _sending
                  ? L('SENDING…', 'ENVIANDO…')
                  : L('SEND REPORT', 'ENVIAR REPORTE'),
          variant: TestuButtonVariant.primary,
          onTap: _picked == null || _sending ? null : _send,
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!,
              style: TextStyle(fontFamily: 'Geist', fontSize: 12, height: 1.5, color: t.redText)),
        ],
```

Replace the sent copy at old lines 154-155 with:

```dart
                widget.sentText ??
                    L('Recorded on this device. Thanks for flagging it.',
                        'Registrado en este dispositivo. Gracias por avisar.'),
```

- [ ] **Step 5: Session: reason ids, live copy, live thread entry (`testu_session.dart`)**

Add `import 'testu_social_api.dart';` after `import 'testu_social.dart';` (line 16).

Replace the `onFlag` field at lines 1289-1290 with:

```dart
  /// Report sheet confirmed: hand (reason id, optional note) to the source.
  /// Resolves when the server has it (live) or at once (demo).
  final Future<void> Function(String reason, String? note) onFlag;
```

The call site at line 577 (`_source.reportFlag(q: q, reason: reason, note: note),`) is unchanged: `reportFlag` now returns the Future the field type asks for.

Replace `_openFlagDialog` (lines 1313-1346, doc comment included) with:

```dart
  /// One report surface app-wide: the shared sheet (testu_report_sheet.dart).
  /// Live, the send lands in services/testu/social/flag.json through
  /// [TestuQuestionSource.reportFlag]; the demo records nothing and says so.
  void _openFlagDialog() {
    HapticFeedback.selectionClick();
    final labels = [for (final r in testuFlagReasons) flagReasonLabel(r)];
    showTestuReportSheet(
      context,
      eyebrow: L('QUESTION · REPORT', 'PREGUNTA · REPORTAR'),
      title: L('Report this question', 'Reportar esta pregunta'),
      subtitle: testuLive
          ? L('Goes to the content team with your name and this question.',
              'Llega al equipo de contenido con tu nombre y esta pregunta.')
          : L('Your report is recorded on this device.',
              'Tu reporte queda registrado en este dispositivo.'),
      reasons: labels,
      sentText: testuLive
          ? L('Sent to the content team. Thanks for flagging it.',
              'Enviado al equipo de contenido. Gracias por avisar.')
          : null,
      onSend: (reason, note) async {
        await widget.onFlag(testuFlagReasons[labels.indexOf(reason)], note);
        // Demo only: the local bell. Live notices are Part D's.
        if (!testuLive) {
          addTestuNotice(
            L('Question report recorded', 'Reporte de pregunta registrado'),
            L('“$reason” — recorded on this device.',
                '«$reason» — registrado en este dispositivo.'),
          );
        }
        if (mounted) _tap(() => _flagged = true);
      },
    );
  }
```

Replace line 1425-1426 (`// Social thread: inline ...` + `if (!testuLive) const SocialThreadEntry(),`) with:

```dart
        // Social thread: inline (decided 2026-08-31). Live on the question's
        // channel; the demo keeps its mock thread.
        if (!testuLive || q.questionId != null)
          SocialThreadEntry(
              channel: testuLive && q.questionId != null ? 'q-${q.questionId}' : null),
```

- [ ] **Step 6: Run the tests**

Run: `flutter test test/testu_social_api_test.dart test/testu_question_source_test.dart test/testu_session_scroll_test.dart test/landscape_shots_test.dart`
Expected: `All tests passed!`.

Run: `flutter analyze`
Expected: `No issues found!`.

- [ ] **Step 7: Leave uncommitted for the user**

---

### Task 7: Topic review tab visible live on `t-<tutorialId>`

**Files:**
- Modify: `lib/testu/testu_live.dart:349-385` (`_topicProgress`, `TopicProgress`)
- Modify: `lib/testu/testu_topics.dart:481-487, 952-967`
- Test: `test/testu_tutor_progress_test.dart` (unchanged; verifies the constructor stays compatible)

**Interfaces:**
- Consumes: Task 5's `TestuThread(channel:)`.
- Produces: `TopicProgress.tutorialId` (`String?`, named optional constructor parameter).

- [ ] **Step 1: `TopicProgress.tutorialId` (`testu_live.dart`)**

Replace line 357 (`return TopicProgress(topic, tutorial.title, sections, answers, last);`) with:

```dart
  return TopicProgress(topic, tutorial.title, sections, answers, last, tutorialId: tutorial.id);
```

Replace lines 362-366 (constructor + first two fields) with:

```dart
  TopicProgress(this.topic, this.tutorialTitle, this.sections, this.answers, this.last,
      {this.tutorialId});
  final Topic topic;
  final String tutorialTitle;

  /// The first tutorial's id (the review thread's channel is `t-<id>`);
  /// null when the topic has no tutorial yet.
  final String? tutorialId;
```

Run: `flutter test test/testu_tutor_progress_test.dart`
Expected: PASS (line 33 still calls the positional form).

- [ ] **Step 2: Review tab always listed (`testu_topics.dart:481-487`)**

```dart
  List<String> get _tabsL => [
        L('Overview', 'Resumen'),
        L('Subtopics', 'Subtemas'),
        L('Resources', 'Recursos'),
        L('Review', 'Reseñas'),
      ];
```

- [ ] **Step 3: The review pane (`testu_topics.dart:952-967`)**

```dart
  // ---- Review ----

  /// The topic's review tab IS the house thread (full-alignment rule:
  /// vote, reply, report work here exactly like the question conversation).
  /// Live it is the tutorial's `t-<id>` channel; the demo keeps its sample.
  List<Widget> _review(TestuTokens t) {
    final tutorialId = _live?.tutorialId;
    if (testuLive && tutorialId == null) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
          child: Text(
              _loaded
                  ? L('This topic has no tutorial yet, so no reviews.',
                      'Este tema aún no tiene tutorial, así que no hay reseñas.')
                  : L('Loading…', 'Cargando…'),
              style: TextStyle(fontFamily: 'Geist', fontSize: 12.5, color: t.mut)),
        ),
      ];
    }
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
        child: TestuThread(
          key: ValueKey('review-${tutorialId ?? 'demo'}'),
          comments: testuLive ? null : _reviews,
          channel: testuLive ? 't-$tutorialId' : null,
          composerHint: L('Add a review or comment…',
              'Añade una reseña o comentario…'),
          reportEyebrow: L('REVIEWS · REPORT', 'RESEÑAS · REPORTAR'),
          reportTitle: L('Report this review', 'Reportar esta reseña'),
        ),
      ),
    ];
  }
```

- [ ] **Step 4: Analyze and run the topic tests**

Run: `flutter analyze && flutter test test/testu_question_source_test.dart test/testu_tutor_progress_test.dart test/landscape_shots_test.dart`
Expected: `No issues found!` and `All tests passed!`.

- [ ] **Step 5: Leave uncommitted for the user**

---

### Task 8: Console "Conversaciones" (`admin_threads.dart`) with reply and react

**Files:**
- Modify: `lib/admin/admin_api.dart:1-6, 31-33`
- Create: `lib/admin/admin_threads.dart`
- Modify: `lib/admin/admin_shell.dart:9-22 (imports), 36-49 (sectionsFor), 216-245 (_page)`
- Modify: `test/admin_shell_test.dart:21-28`
- Test: `test/admin_threads_test.dart`

**Interfaces:**
- Consumes: Task 4's `TestuSocialApi`, `SocialRecent`, `RecentComment`, `QuestionFlagRow`, `flagReasonLabel`, `roleBadge`; Task 5's `TestuThread(channel:, api:)`; console widgets `AdminTable`/`AdminColumn` (`admin_ui.dart:1480-1529`), `ConsolePanelError`, `Skeleton`, `EmptyState`, `ConsoleAct`, `crossfade`, `AdminTokens` (`eyebrow`, `table`, `mono(size)`, `footnote`), `date()` from `admin_reading.dart:21`, `roleLabel` from `admin_models.dart:84`.
- Produces: `AdminApi.social` (`TestuSocialApi` on the same transport); `AdminThreads({api, me})`; section id `threads` labelled "Conversations"/"Conversaciones", listed for `personas` + `personas_view` (managers, training, orgadmin) after `teams`.

- [ ] **Step 1: Update the shell expectations and write the failing console tests**

`test/admin_shell_test.dart:21-28` becomes:

```dart
  test('a manager sees the three analytics screens, people and conversations, never teams', () {
    final ids = sectionsFor(_me({'personas_view', 'analytics_view'})).map((s) => s.id).toList();
    expect(ids, ['overview', 'activity', 'mastery', 'people', 'threads']);
  });
  test('training also sees teams', () {
    expect(sectionsFor(_me({'personas_operate', 'personas_view', 'analytics_view'})).map((s) => s.id),
        ['overview', 'activity', 'mastery', 'people', 'teams', 'threads']);
  });
```

and line 30 becomes:

```dart
    expect(sectionsFor(_me({'personas_view', 'analytics_view'}, analytics: false)).map((s) => s.id), ['people', 'threads']);
```

`test/admin_threads_test.dart`:

```dart
import 'package:eme_app_package/testing/fake_eme_http.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/admin/admin_api.dart';
import 'package:genai_labs/admin/admin_models.dart';
import 'package:genai_labs/admin/admin_threads.dart';
import 'package:genai_labs/admin/admin_ui.dart';
import 'package:genai_labs/testu/testu_social.dart';
import 'package:genai_labs/testu/testu_social_api.dart';
import 'package:genai_labs/testu/testu_theme.dart';

const _thread = 'services/testu/social/thread.json';
const _comment = 'services/testu/social/comment.json';

final _manager = AdminMe('m', 'm@x', 'Lider', 'manager', {'analytics_view', 'personas_view'}, const []);

/// FakeEmeHttp keys canned replies by path, and recent() and thread(channel)
/// share thread.json -- so one canned map carries both shapes: `recent` +
/// `flags` for the listing, `comments` for the opened thread.
Map<String, dynamic> _both() => {
      'ok': true,
      'recent': [
        {
          'id': 'c1',
          'channel': 'q-Q1',
          'moduleid': 'entityquestion',
          'entityid': 'Q1',
          'label': '¿Qué son los Derechos Humanos?',
          'userId': 'lucia',
          'name': 'Lucía Mendoza',
          'role': 'users',
          'date': '2026-09-07T10:00:00-05:00',
          'text': 'Me confundió a quiénes aplican.',
          'replytoid': null,
        },
      ],
      'flags': [
        {
          'id': 'f1',
          'entityquestion': 'Q2',
          'entitytutorial': 'TUT1',
          'label': '¿Qué característica los define?',
          'reason': 'unclear',
          'note': 'La opción B se parece a la C',
          'userId': 'rosa',
          'name': 'Rosa Jiménez',
          'date': '2026-09-07T09:00:00-05:00',
        },
      ],
      'comments': [
        {
          'id': 'c1',
          'userId': 'lucia',
          'name': 'Lucía Mendoza',
          'role': 'users',
          'date': '2026-09-07T10:00:00-05:00',
          'text': 'Me confundió a quiénes aplican.',
          'reacts': {'like': 3},
          'mine': null,
          'replies': [],
        },
      ],
    };

Future<FakeEmeHttp> _pump(WidgetTester tester, {Map<String, dynamic>? recent}) async {
  tester.view.physicalSize = const Size(1440, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final http = FakeEmeHttp();
  if (recent != null) http.canned[_thread] = recent;
  http.canned[_comment] = {'ok': true, 'id': 'c9'};
  await tester.pumpWidget(MaterialApp(
    theme: testuTheme(),
    home: Scaffold(
      body: SingleChildScrollView(child: AdminThreads(api: AdminApi(http: http), me: _manager)),
    ),
  ));
  await tester.pumpAndSettle();
  return http;
}

void main() {
  testWidgets('lists recent comments and open question reports', (tester) async {
    await _pump(tester, recent: _both());
    expect(find.text('QUESTION REPORTS · 1'), findsOneWidget);
    expect(find.text('Confusing or badly worded'), findsOneWidget);
    expect(find.text('Rosa Jiménez'), findsOneWidget);
    expect(find.text('RECENT COMMENTS'), findsOneWidget);
    expect(find.text('Lucía Mendoza'), findsOneWidget);
    expect(find.byType(AdminTable<RecentComment>), findsOneWidget);
    expect(find.byType(TestuThread), findsNothing, reason: 'no thread open yet');
  });

  testWidgets('a row opens its thread and a reply posts through comment.json', (tester) async {
    final http = await _pump(tester, recent: _both());
    await tester.tap(find.text('Me confundió a quiénes aplican.').first);
    await tester.pumpAndSettle();
    expect(find.byType(TestuThread), findsOneWidget);
    expect(find.text('¿Qué son los Derechos Humanos?'), findsWidgets);
    await tester.enterText(find.byType(TextField).first, 'Respuesta del manager');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(http.posted.single.path, _comment);
    expect(http.posted.single.fields['channel'], 'q-Q1');
    expect(http.posted.single.fields['message'], 'Respuesta del manager');
  });

  testWidgets('empty scope reads as an empty state, not a blank card', (tester) async {
    await _pump(tester, recent: {'ok': true, 'recent': [], 'flags': []});
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Nobody has commented or reported a question yet.'), findsOneWidget);
  });

  testWidgets('a failed load shows the error panel with Retry', (tester) async {
    final http = await _pump(tester);
    expect(find.byType(ConsolePanelError), findsOneWidget);
    http.canned[_thread] = _both();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Lucía Mendoza'), findsOneWidget);
  });
}
```

Run: `flutter test test/admin_threads_test.dart test/admin_shell_test.dart`
Expected: FAIL (`admin_threads.dart` missing; the section lists lack `threads`).

- [ ] **Step 2: `AdminApi.social` (`admin_api.dart`)**

Add `import '../testu/testu_social_api.dart';` after `import 'admin_models.dart';` (line 6). Replace lines 31-33 with:

```dart
class AdminApi {
  AdminApi({EmeHttp? http}) : this._(http ?? DioEmeHttp());
  AdminApi._(this._http) : social = TestuSocialApi(http: _http);
  final EmeHttp _http;

  /// Threads and question reports on the same transport (Conversaciones).
  final TestuSocialApi social;
```

- [ ] **Step 3: Write `lib/admin/admin_threads.dart`**

```dart
import 'package:flutter/material.dart';

import '../testu/testu_i18n.dart';
import '../testu/testu_social.dart';
import '../testu/testu_social_api.dart';
import '../testu/testu_theme.dart';
import 'admin_api.dart';
import 'admin_models.dart';
import 'admin_reading.dart' show date;
import 'admin_theme.dart';
import 'admin_ui.dart';

/// Conversaciones: the newest comments across the viewer's scope, the open
/// question reports, and the one place an instructor or manager replies.
/// The thread itself is the app's own TestuThread on the console's http:
/// reply, react and report work exactly as they do on the phone.
class AdminThreads extends StatefulWidget {
  const AdminThreads({super.key, required this.api, required this.me});
  final AdminApi api;
  final AdminMe me;

  @override
  State<AdminThreads> createState() => _AdminThreadsState();
}

class _AdminThreadsState extends State<AdminThreads> {
  SocialRecent? _data;
  Object? _error;
  RecentComment? _open;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await widget.api.social.recent();
      if (!mounted) return;
      setState(() {
        _data = d;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) => crossfade(_body(context));

  Widget _body(BuildContext context) {
    if (_error != null) {
      return ConsolePanelError(
        text: L('Could not load conversations.', 'No se pudieron cargar las conversaciones.'),
        onRetry: _load,
      );
    }
    final d = _data;
    if (d == null) return const Skeleton(lines: 6, height: 22);
    if (d.comments.isEmpty && d.flags.isEmpty) {
      return EmptyState(
        eyebrow: L('Conversations', 'Conversaciones'),
        text: L('Nobody has commented or reported a question yet.',
            'Nadie ha comentado ni reportado una pregunta todavía.'),
      );
    }
    final t = TestuTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (d.flags.isNotEmpty) ...[
          Text(L('QUESTION REPORTS · ${d.flags.length}', 'REPORTES DE PREGUNTAS · ${d.flags.length}'),
              style: AdminTokens.eyebrow),
          const SizedBox(height: 8),
          _flags(d.flags, t),
          const SizedBox(height: 6),
          // ponytail: read-only list; resolving is a later console task (spec C2).
          Text(L('Open reports from learners in your scope.', 'Reportes abiertos de colaboradores en tu ámbito.'),
              style: AdminTokens.footnote),
          const SizedBox(height: 24),
        ],
        Text(L('RECENT COMMENTS', 'COMENTARIOS RECIENTES'), style: AdminTokens.eyebrow),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: _recent(d.comments, t)),
            if (_open != null) ...[
              const SizedBox(width: 24),
              SizedBox(width: 440, child: _thread(_open!, t)),
            ],
          ],
        ),
        if (_open == null) ...[
          const SizedBox(height: 10),
          Text(L('Click a comment to open its conversation.', 'Haz clic en un comentario para abrir la conversación.'),
              style: AdminTokens.footnote),
        ],
      ],
    );
  }

  Widget _flags(List<QuestionFlagRow> rows, TestuTokens t) => AdminTable<QuestionFlagRow>(
        rows: rows,
        columns: [
          AdminColumn(L('Date', 'Fecha'), (f) => Text(date(f.date), style: AdminTokens.mono(11.5)),
              sortKey: (f) => f.date?.millisecondsSinceEpoch ?? 0, width: 100),
          AdminColumn(L('Question', 'Pregunta'),
              (f) => Text(f.label, maxLines: 2, overflow: TextOverflow.ellipsis),
              sortKey: (f) => f.label, flex: 3),
          AdminColumn(L('Reason', 'Motivo'), (f) => Text(flagReasonLabel(f.reason)),
              sortKey: (f) => f.reason, width: 180),
          AdminColumn(L('Note', 'Nota'),
              (f) => Text(f.note, style: TextStyle(color: t.mut), maxLines: 2, overflow: TextOverflow.ellipsis),
              flex: 3),
          AdminColumn(L('By', 'De'), (f) => Text(f.who, maxLines: 1, overflow: TextOverflow.ellipsis),
              sortKey: (f) => f.who, flex: 2),
        ],
      );

  Widget _recent(List<RecentComment> rows, TestuTokens t) => AdminTable<RecentComment>(
        rows: rows,
        onTap: (r) => setState(() => _open = r),
        emptyText: L('No comments yet.', 'Todavía no hay comentarios.'),
        columns: [
          AdminColumn(L('Date', 'Fecha'), (r) => Text(date(r.date), style: AdminTokens.mono(11.5)),
              sortKey: (r) => r.date?.millisecondsSinceEpoch ?? 0, width: 100),
          AdminColumn(
            L('Who', 'Quién'),
            (r) => Text(
                roleBadge(r.role) == null ? r.who : '${r.who} · ${roleBadge(r.role)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            sortKey: (r) => r.who,
            flex: 2,
          ),
          AdminColumn(L('Where', 'Dónde'),
              (r) => Text(r.label, style: TextStyle(color: t.mut), maxLines: 1, overflow: TextOverflow.ellipsis),
              sortKey: (r) => r.label, flex: 3),
          AdminColumn(L('Comment', 'Comentario'),
              (r) => Text(r.text, maxLines: 2, overflow: TextOverflow.ellipsis), flex: 4),
        ],
      );

  Widget _thread(RecentComment r, TestuTokens t) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(r.label,
                  style: AdminTokens.table.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            ConsoleAct(L('Close', 'Cerrar'), onTap: () => setState(() => _open = null)),
          ]),
          const SizedBox(height: 12),
          TestuThread(
            key: ValueKey('console-${r.channel}'),
            channel: r.channel,
            api: widget.api.social,
            composerHint: L('Reply as ${roleLabel(widget.me.role)}…',
                'Responde como ${roleLabel(widget.me.role)}…'),
            reportEyebrow: L('CONVERSATION · REPORT', 'CONVERSACIÓN · REPORTAR'),
            reportTitle: L('Report this comment', 'Reportar este comentario'),
            // A reply from here is a new recent row too.
            onChanged: _load,
          ),
        ],
      );
}
```

- [ ] **Step 4: Wire the section and the route (`admin_shell.dart`)**

Add `import 'admin_threads.dart';` after `import 'admin_teams.dart';` (line 21).

Replace `sectionsFor` (lines 36-49) with:

```dart
List<AdminSection> sectionsFor(AdminMe me) {
  final web = me.webModules.map((m) => m.id).toSet();
  final analytics = web.contains('analytics') && me.can('analytics_view');
  final personas = web.contains('personas');
  return [
    if (analytics) ...[
      AdminSection('overview', L('Overview', 'Resumen')),
      AdminSection('activity', L('Activity', 'Actividad')),
      AdminSection('mastery', L('Mastery', 'Dominio')),
    ],
    if (personas && me.can('personas_view')) AdminSection('people', L('People', 'Colaboradores')),
    if (personas && me.can('personas_operate')) AdminSection('teams', L('Teams', 'Equipos')),
    // Conversaciones rides the personas module: it is the roster's scope
    // (scope.groovy) that decides which comments a manager sees.
    if (personas && me.can('personas_view')) AdminSection('threads', L('Conversations', 'Conversaciones')),
  ];
}
```

In `_page` (lines 216-245) add, before `_ => _notYet(route.section),`:

```dart
    'threads' => AdminThreads(api: widget.api, me: widget.me),
```

- [ ] **Step 5: Run the console tests**

Run: `flutter test test/admin_threads_test.dart test/admin_shell_test.dart test/admin_api_test.dart test/admin_states_test.dart test/admin_people_test.dart`
Expected: `All tests passed!`.

Run: `flutter analyze`
Expected: `No issues found!`.

- [ ] **Step 6: Build the console and ask the user to deploy**

Run: `./build_admin.sh` from the app root (this only builds; `eme-plugin-testu/deploy.sh` is the user's to run, per the console-verify recipe).

- [ ] **Step 7: Eyeball at :8080 (console-verify recipe)**

With the user's deploy done, open `http://localhost:8080/site/mediadb/admin/` as `admin/admin` (orgadmin: scope = every team), click "Conversaciones":
- The "REPORTES DE PREGUNTAS · 1" table shows the Task 1 curl flag ("curl smoke", reason "Confusa o mal redactada").
- "COMENTARIOS RECIENTES" lists the Task 3 curl comment and its reply.
- Clicking the comment opens the thread on the right; tapping "Responder" under it, typing a reply and sending posts it; the row list refreshes; the reply carries the "ADMIN" badge when read back from the phone.
- Long-press (mouse down ~500 ms) "Me gusta" opens the reaction pill; choosing one persists (reload the page: it is still selected).

- [ ] **Step 8: Leave uncommitted for the user**

---

### Task 9: End-to-end smoke and close-out

**Files:**
- No new files. Verification only.

**Interfaces:**
- Consumes: everything above.
- Produces: the report to the user.

- [ ] **Step 1: Whole suite and analyzer**

Run: `flutter analyze && flutter test`
Expected: `No issues found!` then `All tests passed!` (the new files: `testu_social_api_test.dart` 10 tests, `testu_thread_test.dart` 8, `admin_threads_test.dart` 4; the pre-existing `admin_shell_test.dart` with its updated lists).

- [ ] **Step 2: Simulator smoke (learner app, live build)**

Build and run the minsur live app on the simulator (`lib/main_testu.dart`, `--dart-define=TESTU_CLIENT=minsur --dart-define=TESTU_LIVE=true`, per the `drive-simulator` skill), sign in as the test learner, and:
1. Start a session, answer one question, submit confidence. Under the verdict: "Conversaciones sobre esta pregunta" (no count yet). Tap it: the curl comment from Task 3 appears with initials, "Responder 1" unfolds the reply; the header now says "· 2".
2. Type a comment, tap `@`, pick a person, send. The row appears with your name from the server (not "Diego"), the composer is empty.
3. Long-press "Me gusta" on the curl comment, pick "Idea"; kill and relaunch the app, reopen the thread: "Idea" is still yours.
4. Tap "Reportar pregunta", pick "Confusa o mal redactada", add a note, send: the sheet shows "Enviado al equipo de contenido. Gracias por avisar." Turn Wi-Fi off in the simulator (or point `TESTU_MEDIADB` at a dead port), report another question: the sheet keeps the reason and note under "No se pudo enviar. Revisa la conexión e inténtalo de nuevo."
5. Temas → the topic → "Reseñas" tab: the live thread (empty state "Nadie ha comentado todavía. Sé la primera persona." on a fresh tutorial); post a review; it appears.
6. Console (Task 8 step 7) now shows both the new flag and the new comments; reply from the console; back on the phone, reopen the thread: the reply carries the "ADMIN" (or "INSTRUCTOR"/"MANAGER") badge.

- [ ] **Step 3: Demo build untouched**

Run: `flutter test test/landscape_shots_test.dart test/testu_thread_test.dart` (the last test in `testu_thread_test.dart` proves `SocialThreadEntry()` without a channel still renders the mock thread with "· 5"). Optionally run the vueling build (`--dart-define=TESTU_CLIENT=vueling`) on the simulator and open a question thread and the "Reseñas" tab: mock content, no network calls (nothing in the debug console from `EmeHttp`).

- [ ] **Step 4: pbxproj guard**

Run: `git -C "/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs" diff --stat ios/Runner.xcodeproj/project.pbxproj`
Expected: empty. If it shows `objectVersion = 54`: `git checkout -- ios/Runner.xcodeproj/project.pbxproj`.

- [ ] **Step 5: Leave everything uncommitted; report**

Report to the user: the list of created/modified files in both repos, the curl transcript from Tasks 1-3, the console and simulator observations, and the two items under "Deliverables outside code".

---

## Deliverables outside code (say them in the final report; do not create documents)

- Production runbook step: load list `questionflagreason` (`data/lists/questionflagreason.xml`) on the production catalog next to `usageeventtype` and `tutorquestiontheme`; `questionflag` and the new chatterbox rows need no migration (searchers are created from `data/fields/` on first save).
- Part D hook points: `comment.groovy` and `react.groovy` end with `// Part D: notifications are created here` and list every variable available (actor `me`, `messageid`, `channel`, `replytoid`/`parentauthor`, `mentions`, `message`, and for reactions `author`, `mine`). Part D's plan adds its `learnernotification` writes below those comments only.
- Deviation from the spec's C2 wording, for the record: the console has no per-question row anywhere today (`lib/admin/` has no question-level screen), so the open-flag count lives on the new Conversaciones screen as the "REPORTES DE PREGUNTAS · N" table instead of on a question row. Resolving flags stays a later console task.

## Self-review notes

- Spec C2: entity (Task 1), list (Task 1), `flag.json` (Task 1), `reportFlag` posts (Task 6), sheet copy "Enviado al equipo de contenido" (Task 6 step 5), console flag count (Task 8, see deviation above).
- Spec C3: chatterbox reuse with `q-`/`t-` channels (Tasks 2-3), `thread.json` with author/role/reactions/mine (Task 2), `comment.json` with `mentions[]` ids (Task 3), `react.json` toggle (Task 3), `mentionables.json` (Task 3), `TestuComment` gains `id`/`userId`/`date` (Task 4), `TestuThread` takes `channel` and loads live (Task 5), `@` button and picker (Task 5), review tab and `SocialThreadEntry` visible live (Tasks 6-7), console screen with reply and react and role badge from `settingsgroup` (Task 8).
- Error handling: thread loading/data/error+retry (Task 5), failed comment keeps text + snackbar (Task 5), failed reaction snackbar + resync (Task 5), failed flag keeps the form + inline error (Task 6), console error panel + retry (Task 8).
- Testing: API unit tests with a fake client (Task 4, 6), `TestuThread` live rendering widget test (Task 5), console widget test (Task 8), curl recipes (Tasks 1-3), console eyeball (Task 8), simulator smoke (Task 9).
- Names used across tasks were checked against their definitions: `TestuSocialApi.thread/comment/react/mentionables/recent/flag`, `TestuThread(comments, channel, api, onCount)`, `SocialThreadEntry(channel)`, `TopicProgress.tutorialId`, `AdminApi.social`, `AdminThreads(api, me)`, `testuFlagReasons`, `flagReasonLabel`, `roleBadge`.
