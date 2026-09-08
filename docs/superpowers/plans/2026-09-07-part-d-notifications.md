# Part D: Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A learner's bell shows real notifications — replies, mentions, reactions on their comments, and the tutor's answer when they were on another tab — and tapping one lands on the comment (or the IRIS tab) that caused it.

**Architecture:** One plugin entity `learnernotification`, written inline by Part C's `comment.groovy` / `react.groovy` (the `// Part D: notifications are created here` marker is replaced by a ~20-line block, repeated in both scripts because eMe groovy pages cannot import each other), read by two new learner-visible endpoints `notifications.json` and `markread.json`. The app's existing `testuNotices` ValueNotifier becomes a polled live store (start, resume, tab change, 60 s timer); the bell and the notifications screen keep their widgets and gain tap navigation through a pure `testuNoticeTarget` mapping. Highlighting rides a new `highlightMessageId` parameter down `TestuSessionScreen` → `_VerdictExtras` → `SocialThreadEntry` → `TestuThread` (and `TestuTopicHomeScreen` → `TestuThread` for reviews). `tutorreply` is local-only, inserted by the tutor tab when a reply arrives while it is not the active tab.

**Tech Stack:** eMe plugin (groovy page scripts, `data/fields/*.xml`, `data/lists/*.xml`, `.json` + `.xconf` request pages), Elasticsearch behind `MediaArchive.query`; Flutter 3.44.6 app (`lib/testu/`), `eme_app_package` `EmeHttp` / `DioEmeHttp` / `FakeEmeHttp`; `flutter test`; curl against the local Tomcat on :8080.

**Spec:** `/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs/docs/superpowers/specs/2026-09-07-minsur-pilot-readiness-design.md` — section "Part D: notifications" (lines 98–120), Testing (142–148), Deliverables (150–153).

## Global Constraints

- Repos: app `/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs` (branch `testu/impeccable`, 24 uncommitted modified files — never revert, stash, checkout or commit them), plugin `/Users/DSANJORGE/Code/EME-GenAI Labs/eme-plugin-testu`. The parent folder is not a git repo.
- Never commit or push; every task ends with "leave uncommitted for the user". Never switch branches. Never run `deploy.sh` or `build_store.sh` yourself — the user runs `deploy.sh` and restarts Tomcat when a task says so. Never edit `eme-server-minsur` (read only).
- `ios/Runner.xcodeproj/project.pbxproj` must stay `objectVersion = 60`; if tooling changed it to 54: `git checkout -- ios/Runner.xcodeproj/project.pbxproj`.
- Ponytail mode full: minimal diffs, reuse existing helpers, `// ponytail:` comment on deliberate shortcuts, no new dependencies, no new abstractions.
- Every live-only behaviour is gated with `if (testuLive)` / `if (!testuLive)` (`const bool testuLive` in `lib/testu/testu_live.dart:26`). The Vueling demo build (`TESTU_CLIENT=vueling`) is byte-for-byte unchanged: `_seed()` and the seeded notices, `addTestuNotice`, swipe actions all keep working exactly as today when `!testuLive`.
- App never offers signup. Spanish/English strings go through `L('en', 'es')` from `lib/testu/testu_i18n.dart`; widget tests run in English (`test/flutter_test_config.dart` pins `testuLang.value = 'en'`). In tests the default client is minsur, so `testuLive` is `true` (`test/testu_client_test.dart:11`).
- Plugin page pattern (copy exactly): `name.json` contains `$json`; `name.xconf` contains `<page><path-action name="Script.run"><script>/${applicationid}/services/testu/social/scripts/name.groovy</script></path-action><permission name="view"><user/></permission></page>`; `scripts/_site.xconf` contains `<page><permission name="view"><boolean value="false"/></permission></page>`.
- Groovy conventions from `eme-plugin-testu/html/services/testu/usage/scripts/track.groovy`: `reply(Map)` / `fail(code, msg)` helpers, `MediaArchive archive = context.getPageValue("mediaarchive")`, `String userid = context.getUser()?.getId()`, `new JsonSlurper().parseText(context.getRequestParameter("x") ?: "[]")` for a JSON-encoded form field. Sorting newest first is `sort("datecreatedDown")`; `hitsPerPage(50).search().getPageOfHits()` returns the first page; `exact("read", false)` queries a boolean field; `searcher.delete(data, user)` removes a row (`ChatModule.toggleReaction`).
- Part C contract this plan builds on (do not change it): `services/testu/social/comment.json` saves a `chatterbox` row and `react.json` toggles a `chatterboxreaction` row; both take FORM fields (`channel`, `message`, `replytoid`, `mentions` as a JSON-encoded string; `messageid`, `name`), not a JSON body; channel ids are `q-<entityquestion>` and `t-<entitytutorial>`; both groovy scripts end with the line `// Part D: notifications are created here` followed by a comment listing the variables in scope, then the final `reply([...])` call. At that marker `comment.groovy` has in scope `archive`, `me` (actor user id), `d` (the saved chatterbox `Data`: `getId()`, `get("channel")`, `get("replytoid")`, `get("message")`), `messageid`, `channel`, `replytoid` ("" when top level), `parentauthor` (parent comment's author, null when top level), `mentions` (List of user ids, self removed, verified), `message`; `react.groovy` has `archive`, `me`, `messageid`, `name`, `msg` (the chatterbox `Data` reacted to), `author` (its author), `mine` (the reaction now standing, null when removed). Part C's `TestuThread` takes `channel`; `TestuComment` gains `id`, `userId`, `date`; `SocialThreadEntry` takes `channel`. If Part C is not merged yet when a task here touches those widgets, add the Part D parameter next to wherever Part C's parameter will go and leave a one-line note in the task's report.
- App ↔ plugin transport: `EmeHttp` (`eme_app_package/lib/eme_http.dart`) has `getJson`, `postForm` (x-www-form-urlencoded) and `post` — no JSON-body method. Both Part D endpoints therefore take form fields (`ids` = JSON array string, `all=true`), exactly like `usage/track.json` takes `events`.
- Server user ids: `context.getUser().getId()` is the same value `chatterbox.user` and `chatterboxreaction.user` store (`ChatModule` uses `inReq.getUserName()`; eMe user ids are usernames).
- Local server: `http://localhost:8080/site/mediadb`, admin login `{"id":"admin","password":"admin"}` on `services/authentication/login.json` (cookie jar works for `<user/>`-permission pages); a second account gets a password with `services/authentication/usersave.json -d username=<id> -d field=password -d passwordvalue=<pw>` (as admin). Elasticsearch on `localhost:9200`, index `site_catalog`, one `_type` per entity. Tomcat restart procedure (needed after new `data/fields/*.xml`): kill the `java -Dappname=eme-server-minsur … Bootstrap start` process, then from `/Users/DSANJORGE/Code/eme-server-minsur` run `JAVA_HOME=~/.sdkman/candidates/java/26-tem bin/compile.sh` and `java -Dappname=eme-server-minsur @tomcat/work/tomcat-args.txt org.apache.catalina.startup.Bootstrap start` in a long-lived shell; ready when `curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/site/mediadb/services/testu/personas/me.json` prints `401` or `200`. The user does the deploy and restart; the plan says when to ask.

---

## File map

| File | Responsibility |
|---|---|
| `eme-plugin-testu/data/fields/learnernotification.xml` (create) | Entity: one row per notification for one recipient. |
| `eme-plugin-testu/data/lists/learnernotificationtype.xml` (create) | List `reply`, `mention`, `reaction`, `tutorreply` (console labels; the app never reads it). |
| `eme-plugin-testu/html/services/testu/social/notifications.{json,xconf}` + `scripts/notifications.groovy` (create) | Mine, newest first, 50, plus unread count. |
| `eme-plugin-testu/html/services/testu/social/markread.{json,xconf}` + `scripts/markread.groovy` (create) | Mark `ids[]` or all of mine read. |
| `eme-plugin-testu/html/services/testu/social/scripts/comment.groovy`, `react.groovy` (Part C files, modify at the marker) | Producers. |
| `app-genailabs/lib/testu/testu_notifications.dart` (modify) | `TestuNotice` fields, live store + polling, `testuNoticeTarget`, bell dot key, screen tap + markread + dismiss set. |
| `app-genailabs/lib/main_testu.dart` (modify) | Start/stop polling on session, resume, pause, sign-out. |
| `app-genailabs/lib/testu/testu_shell.dart` (modify) | Refresh on tab change. |
| `app-genailabs/lib/testu/testu_social.dart` (modify) | `highlightMessageId` on `TestuThread` and `SocialThreadEntry`, 2 s tint, auto-expand. |
| `app-genailabs/lib/testu/testu_session.dart`, `testu_live.dart`, `testu_topics.dart` (modify) | Carry `questionId` / `highlightMessageId` / `initialTab` to the thread. |
| `app-genailabs/lib/testu/testu_tutor.dart` (modify) | Local `tutorreply` notice when the tab is not active. |
| `app-genailabs/test/testu_notifications_test.dart` (create) | Target mapping, JSON mapping, markread post, bell dot. |

---

### Task 1: Entity `learnernotification` and list `learnernotificationtype`

**Files:**
- Create: `/Users/DSANJORGE/Code/EME-GenAI Labs/eme-plugin-testu/data/fields/learnernotification.xml`
- Create: `/Users/DSANJORGE/Code/EME-GenAI Labs/eme-plugin-testu/data/lists/learnernotificationtype.xml`

**Interfaces:**
- Consumes: the field format of `eme-plugin-testu/data/fields/tutorquestion.xml` and the list format of `eme-plugin-testu/data/lists/usageeventtype.xml`.
- Produces: entity `learnernotification` with fields `id, user, datecreated, type, actor, actorname, text, channel, messageid, entitytutorial, entitytopic, entityquestion, read` (Tasks 2 and 3 write and read exactly these ids; `entitytopic` is added beyond the spec's list because the app's session screen is keyed by topic, see Task 7).

- [ ] **Step 1: Write the entity xml**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!-- Part D (2026-09-07): one row per notification for one recipient. Written inline by
     services/testu/social/scripts/{comment,react}.groovy, read by notifications.groovy,
     flipped by markread.groovy. `entitytopic` is resolved server-side because the app's
     session screen opens by topic, not by tutorial. -->
<properties beanname="dataSearcher">
  <property id="id" index="true" stored="true" editable="false" keyword="true"><name><language id="en">ID</language></name></property>
  <property id="user" index="true" stored="true" editable="false" type="list" listid="user"><name><language id="en">Recipient</language><language id="es">Destinatario</language></name></property>
  <property id="datecreated" index="true" stored="true" editable="false" type="date"><name><language id="en">Date</language><language id="es">Fecha</language></name></property>
  <property id="type" index="true" stored="true" editable="false" type="list" listid="learnernotificationtype"><name><language id="en">Type</language><language id="es">Tipo</language></name></property>
  <property id="actor" index="true" stored="true" editable="false" type="list" listid="user"><name><language id="en">Actor</language><language id="es">Autor</language></name></property>
  <property id="actorname" index="true" stored="true" editable="false" keyword="true"><name><language id="en">Actor name</language><language id="es">Nombre del autor</language></name></property>
  <property id="text" index="false" stored="true" editable="false" type="textarea"><name><language id="en">Text</language><language id="es">Texto</language></name></property>
  <property id="channel" index="true" stored="true" editable="false" keyword="true"><name><language id="en">Channel</language><language id="es">Canal</language></name></property>
  <property id="messageid" index="true" stored="true" editable="false" keyword="true"><name><language id="en">Message</language><language id="es">Mensaje</language></name></property>
  <property id="entitytutorial" index="true" stored="true" editable="false" type="list" listid="entitytutorial"><name><language id="en">Tutorial</language></name></property>
  <property id="entitytopic" index="true" stored="true" editable="false" type="list" listid="entitytopic"><name><language id="en">Topic</language><language id="es">Tema</language></name></property>
  <property id="entityquestion" index="true" stored="true" editable="false" type="list" listid="entityquestion"><name><language id="en">Question</language><language id="es">Pregunta</language></name></property>
  <property id="read" index="true" stored="true" editable="false" type="boolean" datatype="boolean"><name><language id="en">Read</language><language id="es">Leída</language></name></property>
</properties>
```

- [ ] **Step 2: Write the list xml**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<learnernotificationtypes>
  <learnernotificationtype id="reply"><name><![CDATA[Respuesta a tu comentario]]></name></learnernotificationtype>
  <learnernotificationtype id="mention"><name><![CDATA[Mención]]></name></learnernotificationtype>
  <learnernotificationtype id="reaction"><name><![CDATA[Reacción a tu comentario]]></name></learnernotificationtype>
  <learnernotificationtype id="tutorreply"><name><![CDATA[Respuesta del tutor]]></name></learnernotificationtype>
</learnernotificationtypes>
```

- [ ] **Step 3: Check both files are well-formed**

Run:
```bash
cd "/Users/DSANJORGE/Code/EME-GenAI Labs/eme-plugin-testu"
xmllint --noout data/fields/learnernotification.xml data/lists/learnernotificationtype.xml && echo OK
grep -c '<property id=' data/fields/learnernotification.xml
```
Expected: `OK` and `13`.

- [ ] **Step 4: Ask the user to deploy and restart**

Tell the user: "Task 1 added `data/fields/learnernotification.xml` and `data/lists/learnernotificationtype.xml`. Please run `./deploy.sh` in `eme-plugin-testu` and restart Tomcat (new field definitions load at startup)." Wait for confirmation, then:

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/site/mediadb/services/testu/personas/me.json
```
Expected: `401` (server up; not signed in yet).

- [ ] **Step 5: Leave uncommitted for the user**

Do not run `git add` or `git commit`. Report the two new files.

---

### Task 2: `notifications.json` and `markread.json`

**Files:**
- Create: `/Users/DSANJORGE/Code/EME-GenAI Labs/eme-plugin-testu/html/services/testu/social/notifications.json`
- Create: `/Users/DSANJORGE/Code/EME-GenAI Labs/eme-plugin-testu/html/services/testu/social/notifications.xconf`
- Create: `/Users/DSANJORGE/Code/EME-GenAI Labs/eme-plugin-testu/html/services/testu/social/scripts/notifications.groovy`
- Create: `/Users/DSANJORGE/Code/EME-GenAI Labs/eme-plugin-testu/html/services/testu/social/markread.json`
- Create: `/Users/DSANJORGE/Code/EME-GenAI Labs/eme-plugin-testu/html/services/testu/social/markread.xconf`
- Create: `/Users/DSANJORGE/Code/EME-GenAI Labs/eme-plugin-testu/html/services/testu/social/scripts/markread.groovy`
- Create if Part C has not yet: `/Users/DSANJORGE/Code/EME-GenAI Labs/eme-plugin-testu/html/services/testu/social/scripts/_site.xconf`

**Interfaces:**
- Consumes: entity `learnernotification` (Task 1).
- Produces: `GET/POST services/testu/social/notifications.json` → `{ok: true, unread: <int>, notifications: [{id, type, actor, actorname, text, channel, messageid, entitytutorial, entitytopic, entityquestion, read: <bool>, date: "yyyy-MM-dd'T'HH:mm:ssZ"}]}` newest first, at most 50; `POST services/testu/social/markread.json` with form field `ids=["N1","N2"]` or `all=true` → `{ok: true, marked: <int>}`. Both `401 {ok:false,error:"not signed in"}` when anonymous. Task 4 parses exactly these keys.

- [ ] **Step 1: Request pages and permission files**

`notifications.json` and `markread.json` — each file contains exactly:
```
$json
```

`notifications.xconf`:
```xml
<page>
  <path-action name="Script.run"><script>/${applicationid}/services/testu/social/scripts/notifications.groovy</script></path-action>
  <permission name="view"><user/></permission>
</page>
```

`markread.xconf`:
```xml
<page>
  <path-action name="Script.run"><script>/${applicationid}/services/testu/social/scripts/markread.groovy</script></path-action>
  <permission name="view"><user/></permission>
</page>
```

`scripts/_site.xconf` (only if the file does not exist yet — Part C creates the same content):
```xml
<page>
  <permission name="view"><boolean value="false"/></permission>
</page>
```

- [ ] **Step 2: `notifications.groovy`**

```groovy
import groovy.json.JsonOutput
import org.entermediadb.asset.MediaArchive
import org.openedit.Data

void reply(Map m) { context.putPageValue("json", JsonOutput.toJson(m)) }
void fail(int code, String msg) { context.getResponse().setStatus(code); reply([ok: false, error: msg]); context.setCancelActions(true) }

MediaArchive archive = context.getPageValue("mediaarchive")
String userid = context.getUser()?.getId()
if (!userid) { fail(401, "not signed in"); return }
// Newest 50 of mine. ponytail: no paging; a learner with 50 unread has a bigger problem than a missing "load more".
List rows = archive.query("learnernotification").exact("user", userid).sort("datecreatedDown").hitsPerPage(50).search().getPageOfHits()
int unread = archive.query("learnernotification").exact("user", userid).exact("read", false).search().size()
reply([ok: true, unread: unread, notifications: rows.collect { Data n -> [
  id: n.getId(), type: n.get("type"), actor: n.get("actor"), actorname: n.get("actorname"), text: n.get("text"),
  channel: n.get("channel"), messageid: n.get("messageid"),
  entitytutorial: n.get("entitytutorial"), entitytopic: n.get("entitytopic"), entityquestion: n.get("entityquestion"),
  read: "true".equals(String.valueOf(n.get("read"))),
  date: n.getDate("datecreated")?.format("yyyy-MM-dd'T'HH:mm:ssX", TimeZone.getTimeZone("UTC"))
] }])
```

- [ ] **Step 3: `markread.groovy`**

```groovy
import groovy.json.JsonOutput
import groovy.json.JsonSlurper
import org.entermediadb.asset.MediaArchive
import org.openedit.Data

void reply(Map m) { context.putPageValue("json", JsonOutput.toJson(m)) }
void fail(int code, String msg) { context.getResponse().setStatus(code); reply([ok: false, error: msg]); context.setCancelActions(true) }

MediaArchive archive = context.getPageValue("mediaarchive")
String userid = context.getUser()?.getId()
if (!userid) { fail(401, "not signed in"); return }
def searcher = archive.getSearcher("learnernotification")
List rows
if ("true".equals(context.getRequestParameter("all"))) {
  def hits = archive.query("learnernotification").exact("user", userid).exact("read", false).search()
  hits.enableBulkOperations()
  rows = hits.collect { it }
} else {
  List ids
  try { ids = new JsonSlurper().parseText(context.getRequestParameter("ids") ?: "[]") as List } catch (Exception e) { fail(400, "bad ids"); return }
  if (ids.size() > 200) { fail(400, "too many ids"); return }
  // Only my own rows flip: an id guessed from someone else's feed is ignored, not an error.
  rows = ids.collect { searcher.searchById(it.toString()) }.findAll { it != null && userid.equals(it.get("user")) && !"true".equals(String.valueOf(it.get("read"))) }
}
rows.each { Data n -> n.setValue("read", true) }
if (rows) searcher.saveAllData(rows, null)
reply([ok: true, marked: rows.size()])
```

- [ ] **Step 4: Ask the user to deploy**

"Task 2 added `services/testu/social/{notifications,markread}.{json,xconf}` and their scripts. Please run `./deploy.sh` (no restart needed for page scripts)." Wait for confirmation.

- [ ] **Step 5: Verify with curl**

```bash
B=http://localhost:8080/site/mediadb; J=/private/tmp/claude-501/-Users-DSANJORGE-Code-EME-GenAI-Labs/e7a225c4-7f30-48bd-b78d-772a80b994a3/scratchpad/admin.jar
curl -s -o /dev/null -w '%{http_code}\n' "$B/services/testu/social/notifications.json"          # anonymous
curl -s -c "$J" -o /dev/null "$B/services/authentication/login.json" -H 'Content-Type: application/json' -d '{"id":"admin","password":"admin"}'
curl -s -b "$J" "$B/services/testu/social/notifications.json"; echo
curl -s -b "$J" -X POST "$B/services/testu/social/markread.json" -d 'ids=["nope"]'; echo
curl -s -b "$J" -X POST "$B/services/testu/social/markread.json" -d 'all=true'; echo
curl -s -b "$J" -X POST "$B/services/testu/social/markread.json" -d 'ids=not-json'; echo
curl -s -o /dev/null -w '%{http_code}\n' "$B/services/testu/social/scripts/notifications.groovy"
```
Expected, line by line: `401`; `{"ok":true,"unread":0,"notifications":[]}`; `{"ok":true,"marked":0}`; `{"ok":true,"marked":0}`; `{"ok":false,"error":"bad ids"}`; `403` (scripts dir denied).

- [ ] **Step 6: Leave uncommitted for the user**

Report the six (or seven) new files.

---

### Task 3: Producers inside `comment.groovy` and `react.groovy`

**Files:**
- Modify: `/Users/DSANJORGE/Code/EME-GenAI Labs/eme-plugin-testu/html/services/testu/social/scripts/comment.groovy` (Part C file; replace its last line `// Part D: notifications are created here`)
- Modify: `/Users/DSANJORGE/Code/EME-GenAI Labs/eme-plugin-testu/html/services/testu/social/scripts/react.groovy` (same marker)

**Interfaces:**
- Consumes: Part C's in-scope variables at the marker (see Global Constraints), entity `learnernotification` (Task 1), server entities `chatterbox` (`user`, `message`, `channel`, `replytoid`), `componentcontent` (`questionid`, `componentsectionid`), `componentsection` (`entityid` = tutorial), `entitytutorial` (`entitytopic`), `user` (`firstName`, `lastName`).
- Produces: rows Task 2 serves. Rules: reply → parent comment's author; mention → each id in `mentions` (not repeated for the parent author); reaction → comment author, one row per actor+comment with deterministic id `md5(actor|messageid|reaction)`, updated in place on a change and deleted when the reaction is removed; every producer skips self.

The `notify` function is defined in BOTH scripts, verbatim. eMe evaluates each groovy page script on its own; there is no import between page scripts, and a shared `notify.groovy` would need a Script.run chain that hides the data flow. Twenty repeated lines are the cheaper debt.

- [ ] **Step 1: Read both Part C scripts first**

```bash
cd "/Users/DSANJORGE/Code/EME-GenAI Labs/eme-plugin-testu/html/services/testu/social/scripts"
grep -n "Part D\|^import\|MessageDigest\|md5\|parentauthor\|mentions\|mine\|author\|messageid" comment.groovy react.groovy
```
Expected: one `// Part D: notifications are created here` line in each; note whether `react.groovy` already imports `java.security.MessageDigest` / defines `md5` (track.groovy's helper). If it does, do not redefine it in Step 3.

- [ ] **Step 2: Replace the marker in `comment.groovy`**

Add these imports to the top of the file if missing: `import org.openedit.Data`. Then replace the marker line with:

```groovy
// ---- Part D: notifications. Same `notify` lives in react.groovy: eMe page scripts cannot import each other.
void notify(MediaArchive archive, String recipient, String actor, String type, Data msg, String id = null) {
  if (!recipient || recipient == actor) return   // never notify yourself
  def s = archive.getSearcher("learnernotification")
  Data n = id == null ? null : s.searchById(id)
  if (n == null) { n = s.createNewData(); if (id) n.setId(id) }   // reactions upsert on a fixed id; replies/mentions get an ES id
  String channel = msg.get("channel")?.toString() ?: ""
  String qid = channel.startsWith("q-") ? channel.substring(2) : ""
  String tid = channel.startsWith("t-") ? channel.substring(2) : ""
  if (qid) { def cc = archive.query("componentcontent").exact("questionid", qid).searchOne(); tid = cc ? (archive.getData("componentsection", cc.get("componentsectionid"))?.get("entityid") ?: "") : "" }
  def a = archive.getSearcher("user").searchById(actor)
  n.setValue("user", recipient); n.setValue("actor", actor); n.setValue("type", type)
  n.setValue("datecreated", new Date()); n.setValue("read", false)
  n.setValue("actorname", [a?.get("firstName"), a?.get("lastName")].findAll { it }.join(" ") ?: actor)
  n.setValue("text", (msg.get("message") ?: "").toString().replaceAll(/<[^>]*>/, "").replaceAll(/\s+/, " ").trim().take(120))
  n.setValue("channel", channel); n.setValue("messageid", msg.getId())
  n.setValue("entityquestion", qid); n.setValue("entitytutorial", tid)
  n.setValue("entitytopic", tid ? (archive.getData("entitytutorial", tid)?.get("entitytopic") ?: "") : "")
  s.saveData(n, null)
}
// Part C already computed `parentauthor` (null when top level) and `mentions` (self removed, verified).
notify(archive, parentauthor, me, "reply", d)
mentions.each { String mid -> if (mid != parentauthor) notify(archive, mid, me, "mention", d) }
```

Groovy note: a method declared after top-level statements is still visible to them (page scripts compile as one script class), so `notify` may sit at the end of the file. If Part C's script `return`s early on the success path before the marker, move the block before that `return` — the marker is the contract, not the position.

- [ ] **Step 3: Replace the marker in `react.groovy`**

Add `import org.openedit.Data` and `import java.security.MessageDigest` if missing, and the `md5` helper if the script does not have one:

```groovy
String md5(String s) { MessageDigest.getInstance("MD5").digest(s.bytes).encodeHex().toString() }
```

Insert between the marker comment and the final `reply([...])` line (the `notify` body is identical to Step 2):

```groovy
// ---- Part D: notifications. Same `notify` lives in comment.groovy: eMe page scripts cannot import each other.
void notify(MediaArchive archive, String recipient, String actor, String type, Data msg, String id = null) {
  if (!recipient || recipient == actor) return   // never notify yourself
  def s = archive.getSearcher("learnernotification")
  Data n = id == null ? null : s.searchById(id)
  if (n == null) { n = s.createNewData(); if (id) n.setId(id) }   // reactions upsert on a fixed id; replies/mentions get an ES id
  String channel = msg.get("channel")?.toString() ?: ""
  String qid = channel.startsWith("q-") ? channel.substring(2) : ""
  String tid = channel.startsWith("t-") ? channel.substring(2) : ""
  if (qid) { def cc = archive.query("componentcontent").exact("questionid", qid).searchOne(); tid = cc ? (archive.getData("componentsection", cc.get("componentsectionid"))?.get("entityid") ?: "") : "" }
  def a = archive.getSearcher("user").searchById(actor)
  n.setValue("user", recipient); n.setValue("actor", actor); n.setValue("type", type)
  n.setValue("datecreated", new Date()); n.setValue("read", false)
  n.setValue("actorname", [a?.get("firstName"), a?.get("lastName")].findAll { it }.join(" ") ?: actor)
  n.setValue("text", (msg.get("message") ?: "").toString().replaceAll(/<[^>]*>/, "").replaceAll(/\s+/, " ").trim().take(120))
  n.setValue("channel", channel); n.setValue("messageid", msg.getId())
  n.setValue("entityquestion", qid); n.setValue("entitytutorial", tid)
  n.setValue("entitytopic", tid ? (archive.getData("entitytutorial", tid)?.get("entitytopic") ?: "") : "")
  s.saveData(n, null)
}
// One notification per actor+comment: a change of reaction rewrites it, removing the reaction removes it.
// Part C leaves `msg` (the comment), `author`, `me` and `mine` (null = reaction removed) in scope.
String nid = md5(me + "|" + messageid + "|reaction")
def ns = archive.getSearcher("learnernotification")
if (mine == null) { Data old = ns.searchById(nid); if (old != null) ns.delete(old, context.getUser()) }
else notify(archive, author, me, "reaction", msg, nid)
```

- [ ] **Step 4: Ask the user to deploy**

"Task 3 filled the Part D marker in `comment.groovy` and `react.groovy`. Please run `./deploy.sh`." Wait for confirmation.

- [ ] **Step 5: Verify with curl — two accounts**

Pick a local learner id other than admin (the test learner from the Personas import; `curl -s -b "$J" "$B/services/testu/personas/users.json"` as admin lists ids) and give it a curl-able password. Pick a real question id: `curl -s "localhost:9200/site_catalog/_search?size=1" -H 'Content-Type: application/json' -d '{"query":{"term":{"_type":"entityquestion"}}}'` → `hits.hits[0]._id`. Then:

```bash
B=http://localhost:8080/site/mediadb; S=/private/tmp/claude-501/-Users-DSANJORGE-Code-EME-GenAI-Labs/e7a225c4-7f30-48bd-b78d-772a80b994a3/scratchpad
A=$S/admin.jar; L=$S/learner.jar; U2=<learner id>; Q=<entityquestion id>
curl -s -c "$A" -o /dev/null "$B/services/authentication/login.json" -H 'Content-Type: application/json' -d '{"id":"admin","password":"admin"}'
curl -s -b "$A" -X POST "$B/services/authentication/usersave.json" -d "username=$U2" -d field=password -d passwordvalue=Checkpass123 >/dev/null
curl -s -c "$L" -o /dev/null "$B/services/authentication/login.json" -H 'Content-Type: application/json' -d "{\"id\":\"$U2\",\"password\":\"Checkpass123\"}"

# 1. learner posts a top-level comment (Part C's body shape; adapt field names to what comment.groovy reads)
M1=$(curl -s -b "$L" -X POST "$B/services/testu/social/comment.json" -d "channel=q-$Q" --data-urlencode "message=¿Alguien entiende la opción B?" -d 'mentions=[]' | python3 -c 'import sys,json;print(json.load(sys.stdin)["id"])')
# 2. admin replies to it and mentions the learner in the same message
curl -s -b "$A" -X POST "$B/services/testu/social/comment.json" -d "channel=q-$Q" --data-urlencode "message=Sí: la B es la correcta por la política de DDHH." -d "replytoid=$M1" --data-urlencode "mentions=[\"$U2\"]" >/dev/null
# 3. admin reacts, changes the reaction, removes it
curl -s -b "$A" -X POST "$B/services/testu/social/react.json" -d "messageid=$M1" -d "name=like" >/dev/null
curl -s -b "$L" "$B/services/testu/social/notifications.json" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d["unread"],[ (n["type"],n["actorname"],n["entityquestion"]==sys.argv[1],bool(n["entitytopic"])) for n in d["notifications"]])' "$Q"
curl -s -b "$A" -X POST "$B/services/testu/social/react.json" -d "messageid=$M1" -d "name=idea" >/dev/null
curl -s -b "$L" "$B/services/testu/social/notifications.json" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d["unread"],[n["type"] for n in d["notifications"]])'
curl -s -b "$A" -X POST "$B/services/testu/social/react.json" -d "messageid=$M1" -d "name=idea" >/dev/null
curl -s -b "$L" "$B/services/testu/social/notifications.json" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d["unread"],[n["type"] for n in d["notifications"]])'
# 4. self-actions produce nothing: learner reacts to own comment
curl -s -b "$L" -X POST "$B/services/testu/social/react.json" -d "messageid=$M1" -d "name=like" >/dev/null
curl -s -b "$L" "$B/services/testu/social/notifications.json" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d["unread"],[n["type"] for n in d["notifications"]])'
# 5. mark read
IDS=$(curl -s -b "$L" "$B/services/testu/social/notifications.json" | python3 -c 'import sys,json;print(json.dumps([n["id"] for n in json.load(sys.stdin)["notifications"]]))')
curl -s -b "$L" -X POST "$B/services/testu/social/markread.json" --data-urlencode "ids=$IDS"; echo
curl -s -b "$L" "$B/services/testu/social/notifications.json" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d["unread"],all(n["read"] for n in d["notifications"]))'
```
Expected: after step 3's first read `2 [('reaction', 'admin', True, True), ('reply', 'admin', True, True)]` — exactly one `reply` (the mention of the parent author is folded into it), `entityquestion` matches and `entitytopic` is non-empty when the question is wired into a section (if `entitytopic` is empty, check `componentcontent.questionid` for `$Q` in ES before blaming the script); after the change `2 ['reaction', 'reply']` (still two rows, the reaction rewritten in place — the `date` moved); after removal `1 ['reply']`; after the self-reaction still `1 ['reply']`; markread prints `{"ok":true,"marked":1}` then `0 True`. Actor name is whatever `admin`'s `firstName`/`lastName` hold, falling back to `admin`.

Also check the ES row count once: `curl -s "localhost:9200/site_catalog/_count" -H 'Content-Type: application/json' -d '{"query":{"term":{"_type":"learnernotification"}}}'` → `count: 1` for the learner (plus any for admin if the learner replied to admin).

- [ ] **Step 6: Leave uncommitted for the user**

---

### Task 4: `TestuNotice` model, live store, target mapping, unit tests

**Files:**
- Modify: `/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs/lib/testu/testu_notifications.dart:1-68` (imports, `TestuNotice`, store, `addTestuNotice`)
- Test: `/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs/test/testu_notifications_test.dart` (create)

**Interfaces:**
- Consumes: `EmeHttp`, `DioEmeHttp` (`package:eme_app_package/eme_http.dart`), `FakeEmeHttp` (`package:eme_app_package/testing/fake_eme_http.dart`), `testuLive` (`testu_live.dart:26`), `client.tutor` (`testu_client.dart`), `L()`.
- Produces (used by Tasks 5–8):
  - `class TestuNotice { TestuNotice(String title, String body, String when, {bool unread = true, String? id, String? type, String? channel, String? messageId, String? tutorialId, String? topicId, String? questionId, DateTime? date}); factory TestuNotice.fromJson(Map<String, dynamic> j); bool get isToday; }` — "read" in the spec is the existing `unread` flag inverted; no rename.
  - `String testuNoticeTitle(String type, String actor)`
  - `void addTestuNotice(String title, String body, {String? type})`
  - `typedef TestuNoticeTarget = ({int? tab, String? topicId, String? questionId, String? messageId}); TestuNoticeTarget testuNoticeTarget(TestuNotice n)`
  - `Future<void> refreshTestuNotices({EmeHttp? http})`, `void startTestuNoticePolling()`, `void stopTestuNoticePolling()`, `void clearTestuNotices()`, `Future<void> markTestuNoticesRead(Iterable<String> ids, {EmeHttp? http})`, `void dismissTestuNotice(TestuNotice n)`.

- [ ] **Step 1: Write the failing tests**

`test/testu_notifications_test.dart`:

```dart
import 'package:eme_app_package/testing/fake_eme_http.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/testu/testu_notifications.dart';
import 'package:genai_labs/testu/testu_theme.dart';

const _path = 'services/testu/social/notifications.json';

void main() {
  setUp(() => clearTestuNotices());

  group('testuNoticeTarget', () {
    test('tutorreply selects the IRIS tab', () {
      final t = testuNoticeTarget(TestuNotice('t', 'b', 'Now', type: 'tutorreply'));
      expect(t.tab, 2);
      expect(t.topicId, isNull);
    });
    test('a reply on a question opens that question at the comment', () {
      final n = TestuNotice('t', 'b', 'Now',
          type: 'reply', topicId: 'TOP1', questionId: 'Q1', messageId: 'M1');
      expect(testuNoticeTarget(n),
          (tab: null, topicId: 'TOP1', questionId: 'Q1', messageId: 'M1'));
    });
    test('a reaction on a topic review opens the topic without a question', () {
      final n = TestuNotice('t', 'b', 'Now',
          type: 'reaction', topicId: 'TOP1', messageId: 'M2');
      expect(testuNoticeTarget(n),
          (tab: null, topicId: 'TOP1', questionId: null, messageId: 'M2'));
    });
    test('a mention without a topic and an unknown type go nowhere', () {
      expect(testuNoticeTarget(TestuNotice('t', 'b', 'Now', type: 'mention')),
          (tab: null, topicId: null, questionId: null, messageId: null));
      expect(testuNoticeTarget(TestuNotice('t', 'b', 'Now')),
          (tab: null, topicId: null, questionId: null, messageId: null));
    });
  });

  test('refresh maps the server rows, newest first, and keeps local notices',
      () async {
    final http = FakeEmeHttp();
    http.canned[_path] = {
      'ok': true,
      'unread': 1,
      'notifications': [
        {
          'id': 'N1', 'type': 'mention', 'actorname': 'Rosa J.',
          'text': 'mira esto', 'channel': 'q-Q1', 'messageid': 'M1',
          'entitytutorial': 'TUT1', 'entitytopic': 'TOP1',
          'entityquestion': 'Q1', 'read': false,
          'date': '2026-09-07T10:00:00Z',
        },
        {
          'id': 'N2', 'type': 'reaction', 'actorname': 'Carlos V.',
          'text': 'ok', 'channel': 't-TUT1', 'messageid': 'M2',
          'entitytutorial': 'TUT1', 'entitytopic': 'TOP1',
          'entityquestion': '', 'read': true,
          'date': '2026-09-06T10:00:00Z',
        },
      ],
    };
    addTestuNotice('IRIS answered you', 'body', type: 'tutorreply');
    await refreshTestuNotices(http: http);
    final items = testuNotices.value;
    expect(items.map((n) => n.id), [null, 'N1', 'N2']);
    expect(items[1].title, 'Rosa J. mentioned you');
    expect(items[1].body, 'mira esto');
    expect(items[1].unread, isTrue);
    expect(items[1].date, DateTime.utc(2026, 9, 7, 10).toLocal());
    expect(items[2].unread, isFalse);
    expect(items[2].questionId, isNull); // '' from the server reads as none
    expect(items[2].topicId, 'TOP1');
  });

  test('a dismissed row does not come back on the next refresh', () async {
    final http = FakeEmeHttp();
    http.canned[_path] = {
      'ok': true, 'unread': 0,
      'notifications': [
        {'id': 'N1', 'type': 'reply', 'actorname': 'A', 'text': 't',
         'read': true, 'date': '2026-09-06T10:00:00Z'},
      ],
    };
    await refreshTestuNotices(http: http);
    dismissTestuNotice(testuNotices.value.single);
    expect(testuNotices.value, isEmpty);
    await refreshTestuNotices(http: http);
    expect(testuNotices.value, isEmpty);
  });

  test('a failed refresh keeps what is there', () async {
    addTestuNotice('IRIS answered you', 'body', type: 'tutorreply');
    await refreshTestuNotices(http: FakeEmeHttp()); // no canned reply -> 404
    expect(testuNotices.value.length, 1);
  });

  test('markread posts the ids as one JSON field', () async {
    final http = FakeEmeHttp();
    http.canned['services/testu/social/markread.json'] = {'ok': true, 'marked': 2};
    await markTestuNoticesRead(['N1', 'N2'], http: http);
    expect(http.posted.single.fields['ids'], '["N1","N2"]');
    await markTestuNoticesRead(const [], http: http); // nothing to send
    expect(http.posted.length, 1);
  });

  testWidgets('the bell shows the dot only while something is unread',
      (tester) async {
    testuNotices.value = [TestuNotice('t', 'b', 'Now', id: 'N1', type: 'reply')];
    await tester.pumpWidget(MaterialApp(
        theme: testuTheme(), home: const Scaffold(body: TestuBell())));
    expect(find.byKey(const ValueKey('testu-bell-dot')), findsOneWidget);
    testuNotices.value = [
      TestuNotice('t', 'b', 'Now', id: 'N1', type: 'reply', unread: false)
    ];
    await tester.pump();
    expect(find.byKey(const ValueKey('testu-bell-dot')), findsNothing);
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `cd "/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs" && flutter test test/testu_notifications_test.dart`
Expected: compile errors — `clearTestuNotices`, `testuNoticeTarget`, `refreshTestuNotices`, `type:` not defined.

- [ ] **Step 3: Replace lines 1–68 of `testu_notifications.dart`**

Keep everything from line 70 (`/// Bell for the Today header`) onwards untouched in this task. New top of file:

```dart
import 'dart:async';
import 'dart:convert';

import 'package:eme_app_package/eme_http.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'testu_client.dart';
import 'testu_i18n.dart';
import 'testu_icons.dart';
import 'testu_live.dart';
import 'testu_session.dart';
import 'testu_shell.dart';
import 'testu_theme.dart';
import 'testu_topics.dart';
import 'testu_widgets.dart';

/// Rule of the split: Today carries everything ACTIONABLE (do this now);
/// Notifications carries the non-actionable/informative tail (your report
/// was reviewed, content updated, certificate issued). Nothing informative
/// goes on Today anymore.
class TestuNotice {
  TestuNotice(this.title, this.body, this.when,
      {this.unread = true,
      this.id,
      this.type,
      this.channel,
      this.messageId,
      this.tutorialId,
      this.topicId,
      this.questionId,
      this.date});

  /// One row of `services/testu/social/notifications.json`. Empty ids from
  /// the server (`entityquestion` on a topic review) read as none.
  factory TestuNotice.fromJson(Map<String, dynamic> j) {
    final type = '${j['type'] ?? ''}';
    final date = DateTime.tryParse('${j['date'] ?? ''}')?.toLocal();
    return TestuNotice(
      testuNoticeTitle(type, '${j['actorname'] ?? ''}'.trim()),
      '${j['text'] ?? ''}',
      date == null ? L('Now', 'Ahora') : '${date.day}/${date.month}',
      unread: j['read'] != true,
      id: _nz(j['id']),
      type: type,
      channel: _nz(j['channel']),
      messageId: _nz(j['messageid']),
      tutorialId: _nz(j['entitytutorial']),
      topicId: _nz(j['entitytopic']),
      questionId: _nz(j['entityquestion']),
      date: date,
    );
  }

  final String title;
  final String body;
  final String when; // display string; live rows also carry [date]
  bool unread;

  /// Server identity and origin; null on demo/local rows (`id` null =
  /// never posted to the server, survives a poll).
  final String? id, type, channel, messageId, tutorialId, topicId, questionId;
  final DateTime? date;

  /// The «HOY» group: a real date today, or the demo's "Now" label.
  bool get isToday {
    final d = date;
    if (d == null) return when == L('Now', 'Ahora');
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }
}

String? _nz(Object? v) => v == null || '$v'.isEmpty ? null : '$v';

/// Title line per server type; the actor's display name is the subject.
String testuNoticeTitle(String type, String actor) => switch (type) {
      'reply' => L('$actor replied to you', '$actor te respondió'),
      'mention' => L('$actor mentioned you', '$actor te mencionó'),
      'reaction' => L('$actor reacted to your comment',
          '$actor reaccionó a tu comentario'),
      'tutorreply' =>
        L('${client.tutor} answered you', '${client.tutor} te respondió'),
      _ => actor,
    };

/// Where a tap on [n] lands: a shell tab to select, or a screen to push
/// (question session, else the topic's review tab). Pure, so the routing
/// table is a unit test; the screen turns it into navigation.
typedef TestuNoticeTarget = ({
  int? tab,
  String? topicId,
  String? questionId,
  String? messageId
});

TestuNoticeTarget testuNoticeTarget(TestuNotice n) => switch (n.type) {
      'tutorreply' => (tab: 2, topicId: null, questionId: null, messageId: null),
      'reply' || 'mention' || 'reaction' when n.topicId != null => (
          tab: null,
          topicId: n.topicId,
          questionId: n.questionId,
          messageId: n.messageId
        ),
      _ => (tab: null, topicId: null, questionId: null, messageId: null),
    };

/// Store — demo-seeded lazily so `L()` resolves per language at first use.
/// A live build starts empty and is filled by [refreshTestuNotices].
final testuNotices = ValueNotifier<List<TestuNotice>>([]);
bool _seeded = false;

void _seed() {
  if (_seeded || testuLive) return;
  _seeded = true;
  testuNotices.value = [
    TestuNotice(
      L('Your question report was incorporated',
          'Tu reporte de pregunta fue incorporado'),
      CL('The Cybersecurity question you flagged was corrected by the content team. Thanks!',
          'La pregunta de Ciberseguridad que reportaste fue corregida por el equipo de contenido. ¡Gracias!',
          'The FOD question you flagged was corrected by the content team. Thanks!',
          'La pregunta de FOD que reportaste fue corregida por el equipo de contenido. ¡Gracias!'),
      L('Yesterday', 'Ayer'),
    ),
    TestuNotice(
      CL('New resource in Human Rights', 'Nuevo recurso en Derechos Humanos',
          'New resource in Ramp Safety', 'Nuevo recurso en Seguridad en Rampa'),
      CL('“Grievance mechanisms guide” was added to your topic resources.',
          'Se añadió «Guía de mecanismos de reclamación» a los recursos de tu tema.',
          '“Winter operations addendum” was added to your topic resources.',
          'Se añadió «Anexo de operaciones de invierno» a los recursos de tu tema.'),
      L('Tuesday', 'Martes'),
      unread: false,
    ),
    TestuNotice(
      L('Certificate renewed', 'Certificado renovado'),
      CL('Your Human Rights certificate was renewed and verified by TestU.',
          'Tu certificado de Derechos Humanos fue renovado y verificado por TestU.',
          'Your FOD Prevention certificate was renewed and verified by TestU.',
          'Tu certificado de Prevención de FOD fue renovado y verificado por TestU.'),
      L('Aug 12', '12 ago'),
      unread: false,
    ),
  ];
}

/// A local notice (demo events; live only `tutorreply`, see testu_tutor.dart).
void addTestuNotice(String title, String body, {String? type}) {
  _seed();
  testuNotices.value = [
    TestuNotice(title, body, L('Now', 'Ahora'), type: type),
    ...testuNotices.value,
  ];
}

// ---- Live store.
// ponytail: polling, switch to the websocket channel when EnterMedia exposes a per-user channel.

const _notificationsPath = 'services/testu/social/notifications.json';
const _markreadPath = 'services/testu/social/markread.json';
Timer? _poll;
bool _refreshing = false;

/// Swipe-deleted server rows, so a poll does not resurrect them.
/// ponytail: in memory only; a server-side delete when someone asks for it.
final _dismissed = <String>{};

/// Replaces the server rows with the newest 50; local rows (`id == null`)
/// stay in front. A failure keeps what is on screen.
Future<void> refreshTestuNotices({EmeHttp? http}) async {
  if (!testuLive || _refreshing) return;
  _refreshing = true;
  try {
    final data = await (http ?? DioEmeHttp()).getJson(_notificationsPath);
    testuNotices.value = [
      ...testuNotices.value.where((n) => n.id == null),
      for (final j in (data['notifications'] as List? ?? const []))
        if (!_dismissed.contains('${(j as Map)['id']}'))
          TestuNotice.fromJson(Map<String, dynamic>.from(j)),
    ];
  } catch (e) {
    debugPrint('TestU: notifications ($e)');
  } finally {
    _refreshing = false;
  }
}

/// Fetch now and every 60 s until [stopTestuNoticePolling]. Idempotent.
void startTestuNoticePolling() {
  if (!testuLive) return;
  refreshTestuNotices();
  _poll ??= Timer.periodic(
      const Duration(seconds: 60), (_) => refreshTestuNotices());
}

void stopTestuNoticePolling() {
  _poll?.cancel();
  _poll = null;
}

/// Sign-out: nothing of this learner stays for the next one.
void clearTestuNotices() {
  stopTestuNoticePolling();
  _dismissed.clear();
  testuNotices.value = [];
}

void dismissTestuNotice(TestuNotice n) {
  if (n.id != null) _dismissed.add(n.id!);
  testuNotices.value = [
    for (final x in testuNotices.value)
      if (!identical(x, n)) x
  ];
}

/// Tells the server these rows were seen. Local state is untouched: the
/// screen's leave-marks-read sweep and swipe toggles keep their own rules.
Future<void> markTestuNoticesRead(Iterable<String> ids, {EmeHttp? http}) async {
  final list = ids.toList();
  if (!testuLive || list.isEmpty) return;
  try {
    await (http ?? DioEmeHttp())
        .postForm(_markreadPath, [MapEntry('ids', jsonEncode(list))]);
  } catch (e) {
    debugPrint('TestU: markread ($e)');
  }
}
```

The imports of `testu_session.dart`, `testu_shell.dart` and `testu_topics.dart` are used in Task 5; Dart tolerates the circular imports (`testu_shell.dart:9` and `testu_session.dart:13` already import this file). If `flutter analyze` flags them unused at the end of this task, leave them — Task 5 uses them.

- [ ] **Step 4: Add the dot key in `TestuBell` (so the widget test can find it)**

In the existing `TestuBell.build`, the unread dot `Container` (currently at lines 105–113) gains a key:

```dart
                if (unread)
                  Positioned(
                    top: 1,
                    right: 1,
                    child: Container(
                      key: const ValueKey('testu-bell-dot'),
                      width: 8,
                      height: 8,
```

- [ ] **Step 5: Run the tests**

Run: `flutter test test/testu_notifications_test.dart`
Expected: all 9 pass. If `testuNoticeTitle` for `tutorreply` differs because `client.tutor` is not what you expect, the test does not assert it — it asserts the mention title only.

- [ ] **Step 6: Analyze**

Run: `flutter analyze lib/testu/testu_notifications.dart`
Expected: no errors (unused-import infos acceptable until Task 5).

- [ ] **Step 7: Leave uncommitted for the user**

---

### Task 5: Bell dot from unread, screen: markread on open, tap navigation, dismiss set

**Files:**
- Modify: `/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs/lib/testu/testu_notifications.dart` — `_TestuNotificationsScreenState` (`initState`, `_item`, `_grouped`, the live subtitle copy at the old lines 161–166)

**Interfaces:**
- Consumes: Task 4's store functions; `TestuShell.tabRequest` (`testu_shell.dart:25`); `TestuSessionScreen({topicId, questionId, highlightMessageId})` and `TestuTopicHomeScreen({topicId, initialTab, highlightMessageId})` — both parameters are added in Task 7. Do Task 7 before running the app if you execute out of order; the analyzer will point at the two constructor calls until then.
- Produces: tapping a row navigates; the bell dot is already `items.any((n) => n.unread)` (unchanged — server `read:false` maps to `unread:true` in Task 4).

- [ ] **Step 1: Mark visible rows read on open**

Add to `_TestuNotificationsScreenState` (before `build`):

```dart
  @override
  void initState() {
    super.initState();
    // The server learns these were seen now; the rows stay bold until the
    // learner leaves (dispose sweep) so what is new reads as new.
    markTestuNoticesRead(
        [for (final n in testuNotices.value) if (n.unread && n.id != null) n.id!]);
  }
```

- [ ] **Step 2: Tap navigation**

Add to the same State:

```dart
  /// Reply, mention, reaction → the question's session (that question first,
  /// thread open, comment tinted) or the topic's review tab; tutorreply →
  /// the IRIS tab. Pops this screen first so the origin sits over the shell.
  void _open(TestuNotice n) {
    final target = testuNoticeTarget(n);
    if (target.tab == null && target.topicId == null) return;
    HapticFeedback.selectionClick();
    final nav = Navigator.of(context);
    nav.pop();
    if (target.tab != null) {
      TestuShell.tabRequest.value = target.tab;
      return;
    }
    nav.push(MaterialPageRoute(
        builder: (_) => target.questionId != null
            ? TestuSessionScreen(
                topicId: target.topicId,
                questionId: target.questionId,
                highlightMessageId: target.messageId)
            : TestuTopicHomeScreen(
                topicId: target.topicId,
                initialTab: 3,
                highlightMessageId: target.messageId)));
  }
```

In `_item`, wrap the row and route deletes through the store:

```dart
        onDismissed: (_) => dismissTestuNotice(n),
        child: TestuPressable(
          onTap: n.type == null ? null : () => _open(n),
          child: _row(t, n, showWhen: showWhen),
        ),
```
(replacing the existing `onDismissed: (_) => testuNotices.value = [ for ... if (!identical(x, n)) x ],` and `child: _row(t, n, showWhen: showWhen),`).

- [ ] **Step 3: Group by real date**

In `_grouped`, replace the two `when == L('Now', 'Ahora')` / `!=` filters with `n.isToday` / `!n.isToday`:

```dart
    final today = [
      for (final n in items)
        if (n.isToday) n
    ];
    final earlier = [
      for (final n in items)
        if (!n.isToday) n
    ];
```

- [ ] **Step 4: Live subtitle copy**

The live branch of the subtitle (old lines 162–164) now describes what arrives:

```dart
                testuLive
                    ? L('Replies, mentions and reactions on your comments, and answers from ${client.tutor} you missed. Anything that needs action stays on Today.',
                        'Respuestas, menciones y reacciones a tus comentarios, y respuestas de ${client.tutor} que te perdiste. Lo que requiere acción sigue en Hoy.')
                    : L('Reviews of your reports, content updates, certificates. Anything that needs action stays on Today.',
                        'Revisiones de tus reportes, cambios de contenido, certificados. Lo que requiere acción sigue en Hoy.'),
```

- [ ] **Step 5: Keep the swipe toggle honest**

Above `confirmDismiss` in `_item` add the comment (no code change):

```dart
        // ponytail: right-swipe toggles are local; the server was told "read"
        // on open, so a row kept unread here reads as read after the next poll.
```

- [ ] **Step 6: Widget test for the tap table wiring**

Append to `test/testu_notifications_test.dart` inside `main()`:

```dart
  testWidgets('tapping a tutorreply row asks the shell for the IRIS tab',
      (tester) async {
    testuNotices.value = [
      TestuNotice('IRIS answered you', 'body', 'Now', type: 'tutorreply')
    ];
    await tester.pumpWidget(MaterialApp(
        theme: testuTheme(), home: const TestuNotificationsScreen()));
    await tester.tap(find.text('IRIS answered you'));
    await tester.pump();
    expect(TestuShell.tabRequest.value, 2);
    TestuShell.tabRequest.value = null;
  });
```
with `import 'package:genai_labs/testu/testu_shell.dart';` added at the top. Note the test pushes no route under the screen, so `nav.pop()` pops the home route; `MaterialApp` tolerates that in a test (the tab request is set before). If the pop throws, pump the screen from a `Navigator.push` over a placeholder `Scaffold` instead:

```dart
    await tester.pumpWidget(MaterialApp(theme: testuTheme(), home: Builder(
      builder: (context) => TextButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const TestuNotificationsScreen())),
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
```

- [ ] **Step 7: Run the tests and analyze**

Run: `flutter test test/testu_notifications_test.dart && flutter analyze lib/testu/testu_notifications.dart`
Expected: 10 tests pass; analyze clean once Task 7 has landed (until then two errors on the constructor arguments).

- [ ] **Step 8: Leave uncommitted for the user**

---

### Task 6: Polling hooks — start, resume, pause, tab change, sign-out

**Files:**
- Modify: `/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs/lib/main_testu.dart:7-15` (imports), `:76-87` (`onSessionEnded`), `:96-114` (`didChangeAppLifecycleState`), `:122-138` (`_restore`), `:140-149` (`_onSignedIn`)
- Modify: `/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs/lib/testu/testu_shell.dart:96-99` (nav `onTap`)

**Interfaces:**
- Consumes: `startTestuNoticePolling`, `stopTestuNoticePolling`, `clearTestuNotices`, `refreshTestuNotices` (Task 4). `_TestuAppState` is already a `WidgetsBindingObserver` (`main_testu.dart:50`).
- Produces: the store is populated whenever a signed-in learner is in the foreground.

- [ ] **Step 1: `main_testu.dart`**

Import:
```dart
import 'testu/testu_notifications.dart';
```

`onSessionEnded` (inside `initState`) — add the clear before `popUntil`:
```dart
    TestuAuth.onSessionEnded = () {
      clearTestuNotices();
      if (mounted) {
```

Lifecycle:
```dart
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      testuUsage.pause();
      stopTestuNoticePolling();
      _leftAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      testuUsage.resume();
      if (_signedIn) startTestuNoticePolling();
      final away = _leftAt;
```

`_restore` — after `if (restored) testuUsage.open();`:
```dart
    if (restored) startTestuNoticePolling();
```

`_onSignedIn` — after `testuUsage.open();`:
```dart
    startTestuNoticePolling();
```

- [ ] **Step 2: `testu_shell.dart` tab change**

```dart
      bottomNavigationBar: TestuNav(
        items: _tabs,
        current: _tab,
        onTap: (i) {
          HapticFeedback.selectionClick();
          refreshTestuNotices();
          setState(() => _tab = i);
        },
      ),
```

- [ ] **Step 3: Analyze and run the whole suite**

Run: `flutter analyze lib/main_testu.dart lib/testu/testu_shell.dart && flutter test`
Expected: analyze clean; every test passes (the suite has no test for main; `testu_shell` has none either).

- [ ] **Step 4: Simulator check (live build)**

Run the app on the booted simulator: `flutter run -t lib/main_testu.dart -d <simulator id> --dart-define=TESTU_CLIENT=minsur`, sign in as the local learner (OTP per `~/.claude/.../testu-simulator-driving.md`), then from the terminal fire a reply to one of that learner's comments as admin (Task 3 Step 5, steps 1–2). Within 60 s, or immediately after switching tabs, the bell on Today shows the orange dot. Open the bell: the row reads "<admin name> te respondió" under HOY. Background the app (Home), foreground it: the log shows one `notifications.json` GET on resume (`flutter logs` or the Dio log line).

- [ ] **Step 5: Leave uncommitted for the user**

---

### Task 7: Highlight plumbing — `highlightMessageId` from the notification to the comment

**Files:**
- Modify: `/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs/lib/testu/testu_social.dart:44-58` (`TestuThread` ctor), `:64-75` (State fields), `:150-166` (`_comment` decoration), `:369-379` (`SocialThreadEntry`), `:418-426` (its `TestuThread` call)
- Modify: `/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs/lib/testu/testu_session.dart:72-86` (`TestuSessionScreen` ctor), `:113-118` (`_source`), `:572-578` (`_VerdictExtras(` call), `:1279-1296` (`_VerdictExtras` ctor), `:1426` (`SocialThreadEntry`)
- Modify: `/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs/lib/testu/testu_live.dart:119-128` (`EmeQuestionSource` ctor), `:159-162` (ordering)
- Modify: `/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs/lib/testu/testu_topics.dart:407-428` (`TestuTopicHomeScreen` ctor), `:431` (`_tab`), `:956-967` (`_review`)
- Test: `/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs/test/testu_thread_highlight_test.dart` (create)

**Interfaces:**
- Consumes: Part C's `TestuThread({required channel, …})`, `TestuComment.id`, `SocialThreadEntry({required channel})`. `TestuTokens.amberTint` (`testu_theme.dart:82`).
- Produces:
  - `TestuThread(…, String? highlightMessageId)` — the comment whose `id` matches is tinted `amberTint` for 2 s after the comments are on screen; if it is a reply, its parent is expanded.
  - `SocialThreadEntry({…, String? highlightMessageId})` — starts open when set.
  - `TestuSessionScreen({…, String? questionId, String? highlightMessageId})`; `EmeQuestionSource({…, String? questionId})` puts that question first.
  - `TestuTopicHomeScreen({…, int initialTab = 0, String? highlightMessageId})`.

- [ ] **Step 1: Failing widget test for the thread highlight**

`test/testu_thread_highlight_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/testu/testu_social.dart';
import 'package:genai_labs/testu/testu_theme.dart';

/// A notification tap opens the thread with the parent of the highlighted
/// reply unfolded and the reply's row tinted for two seconds.
void main() {
  Widget host(List<TestuComment> comments, {String? highlight}) => MaterialApp(
        theme: testuTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: TestuThread(
              channel: 'q-Q1',
              comments: comments,
              composerHint: 'Reply…',
              reportEyebrow: 'R',
              reportTitle: 'R',
              highlightMessageId: highlight,
            ),
          ),
        ),
      );

  // Adapt to Part C's TestuComment constructor: the fields used here are
  // `id`, `who`, `text`, `replies`.
  TestuComment c(String id, String text) =>
      TestuComment('Ana', null, 'assets/img/p_laia.jpg', text, id: id);

  testWidgets('highlighted reply: parent expanded, row tinted, tint gone at 2 s',
      (tester) async {
    final parent = c('M1', 'parent');
    parent.replies.add(c('M2', 'the reply'));
    await tester.pumpWidget(host([parent], highlight: 'M2'));
    await tester.pump();
    expect(find.text('the reply'), findsOneWidget); // parent unfolded
    Color? fill() {
      final box = tester.widget<Container>(find.ancestor(
          of: find.text('the reply'), matching: find.byType(Container)).first);
      return (box.decoration as BoxDecoration?)?.color;
    }
    expect(fill(), TestuTokens.instance.amberTint);
    await tester.pump(const Duration(seconds: 2));
    expect(fill(), isNot(TestuTokens.instance.amberTint));
  });

  testWidgets('no highlight: threads start closed', (tester) async {
    final parent = c('M1', 'parent');
    parent.replies.add(c('M2', 'the reply'));
    await tester.pumpWidget(host([parent]));
    expect(find.text('the reply'), findsNothing);
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/testu_thread_highlight_test.dart`
Expected: compile error, `highlightMessageId` is not a named parameter.

- [ ] **Step 3: `TestuThread` in `testu_social.dart`**

Constructor — add after `this.onChanged,`:
```dart
    this.highlightMessageId,
```
and the field after `final VoidCallback? onChanged;`:
```dart
  /// Comment to tint for two seconds when the thread opens from a
  /// notification; its parent unfolds so the row is on screen.
  final String? highlightMessageId;
```

State — add `import 'dart:async';` at the top of the file, then in `_TestuThreadState` after `final _expanded = <TestuComment>{};`:
```dart
  String? _hl;
  Timer? _hlTimer;

  @override
  void initState() {
    super.initState();
    _hl = widget.highlightMessageId;
    if (widget.comments.isNotEmpty) _armHighlight();
  }

  /// Once the comments are there (at once in demo, after Part C's
  /// `thread.json` load when live): unfold the highlighted reply's parent
  /// and start the two-second tint.
  void _armHighlight() {
    if (_hl == null || _hlTimer != null) return;
    for (final c in widget.comments) {
      if (c.replies.any((r) => r.id == _hl)) _expanded.add(c);
    }
    _hlTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _hl = null);
    });
  }

  @override
  void dispose() {
    _hlTimer?.cancel();
    super.dispose();
  }
```
If Part C's `TestuThread` loads live comments asynchronously, call `_armHighlight()` inside its `setState` right after the comments are assigned (and keep the `initState` call for the demo list). If Part C's State already defines `initState`/`dispose`, merge these lines into them.

`_comment` decoration — the card and the reply row both take the tint:
```dart
  Widget _comment(TestuTokens t, TestuComment c, {TestuComment? parent}) {
    final reply = parent != null;
    final hl = c.id != null && c.id == _hl;
    return Container(
      margin: EdgeInsets.only(bottom: reply ? 12 : 10),
      // Replies keep the card's 12px right inset so their Report links
      // align exactly under the parent card's Report.
      padding: reply
          ? const EdgeInsets.only(right: 12)
          : const EdgeInsets.all(12),
      decoration: reply
          ? (hl ? BoxDecoration(color: t.amberTint) : null)
          : BoxDecoration(
              color: hl ? t.amberTint : t.card,
              border: Border.all(color: t.line2),
              borderRadius: BorderRadius.circular(12),
            ),
```
(the rest of `_comment` unchanged).

- [ ] **Step 4: `SocialThreadEntry`**

```dart
class SocialThreadEntry extends StatefulWidget {
  const SocialThreadEntry({super.key, required this.channel, this.highlightMessageId});

  final String channel;

  /// Set by a notification tap: the entry starts open on that comment.
  final String? highlightMessageId;
```
(keep Part C's `channel` exactly as Part C declared it; add only `highlightMessageId`). In the State: `late bool _open = widget.highlightMessageId != null;` replaces `bool _open = false;`, and the `TestuThread(` call inside `build` gains `highlightMessageId: widget.highlightMessageId,`.

- [ ] **Step 5: Run the thread test**

Run: `flutter test test/testu_thread_highlight_test.dart`
Expected: 2 pass.

- [ ] **Step 6: Session: question first, highlight through**

`testu_live.dart` `EmeQuestionSource`:
```dart
  EmeQuestionSource({this.topicId, this.sectionId, this.questionId, EmeHttp? http})
      : _service = TopicService(http: http);

  final String? topicId;

  /// Section to start on: its questions come first, the rest keep their
  /// order. Unknown or null = tutorial order.
  final String? sectionId;

  /// One question to start on (a notification about its thread), ahead of
  /// [sectionId]'s.
  final String? questionId;
```
and the ordering in `load()`:
```dart
    final mcqs = [
      ...all.where((m) => m.question.id == questionId),
      ...all.where((m) => m.question.id != questionId && m.section.id == sectionId),
      ...all.where((m) => m.question.id != questionId && m.section.id != sectionId),
    ];
```

`testu_session.dart` `TestuSessionScreen`:
```dart
  const TestuSessionScreen(
      {super.key,
      this.topicId,
      this.sectionId,
      this.questionId,
      this.highlightMessageId,
      this.source});

  final String? topicId;
  final String? sectionId;

  /// From a notification: start on this question and, once it is answered,
  /// open its thread on [highlightMessageId].
  final String? questionId;
  final String? highlightMessageId;
```
`_source`:
```dart
  late final TestuQuestionSource _source = widget.source ??
      (testuLive
          ? EmeQuestionSource(
              topicId: widget.topicId,
              sectionId: widget.sectionId,
              questionId: widget.questionId)
          : LocalQuestionSource());
```
`_VerdictExtras(` call (line 572):
```dart
      extra: _VerdictExtras(
        q: q,
        highlightMessageId:
            q.questionId != null && q.questionId == widget.questionId
                ? widget.highlightMessageId
                : null,
        onAsk: (text, offline) =>
```
`_VerdictExtras` ctor:
```dart
  const _VerdictExtras(
      {required this.q,
      required this.onAsk,
      required this.onFlag,
      this.highlightMessageId});

  final TestuQ q;

  /// Comment the thread opens on (notification tap); null otherwise.
  final String? highlightMessageId;
```
and the `SocialThreadEntry` line (Part C's replacement of line 1426) gains the argument, e.g.:
```dart
        SocialThreadEntry(
            channel: 'q-${q.questionId}',
            highlightMessageId: widget.highlightMessageId),
```
Keep whatever gate and channel expression Part C wrote; add only `highlightMessageId:`.

- [ ] **Step 7: Topic home: `initialTab` and highlight**

`testu_topics.dart`:
```dart
  const TestuTopicHomeScreen({
    super.key,
    this.topicId,
    this.title,
    this.img = 'ramp.jpg',
    this.pill,
    this.pillColor,
    this.pillBorder,
    this.initialTab = 0,
    this.highlightMessageId,
  });
  …
  final Color? pillBorder;

  /// Notification tap: open on the review tab (3) at that comment.
  final int initialTab;
  final String? highlightMessageId;
```
State: `late int _tab = widget.initialTab;` replaces `int _tab = 0;`. In `_review`, the `TestuThread(` call gains `highlightMessageId: widget.highlightMessageId,`.

- [ ] **Step 8: Analyze and full suite**

Run: `flutter analyze && flutter test`
Expected: analyze clean (this also clears Task 5's two constructor errors); all tests pass, including `testu_session_engine_test.dart`, `testu_session_scroll_test.dart` (the session constructor kept its positional-free shape).

- [ ] **Step 9: Simulator check**

With the Task 3 data in place (admin replied to the learner's comment on question `$Q`): sign in as the learner, open the bell, tap the reply row. Expected: the notifications screen pops, a session opens with `$Q` as question 1; after answering it, the "Conversaciones sobre esta pregunta" entry is already open and admin's reply sits under the learner's comment on an amber card that fades to the normal card after ~2 s. For a topic review notification (react as admin on a `t-<tutorial>` comment), tapping lands on the Topic Home's fourth tab with the comment tinted.

- [ ] **Step 10: Leave uncommitted for the user**

---

### Task 8: Local `tutorreply` notice from the IRIS tab

**Files:**
- Modify: `/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs/lib/testu/testu_tutor.dart:1-11` (imports), `:102-110` (`says`)

**Interfaces:**
- Consumes: `addTestuNotice(title, body, {type})`, `testuNoticeTitle` (Task 4); `TestuTutorScreen.active` (`testu_tutor.dart:28`), `sullyReplies()` (`testu_live.dart:225`).
- Produces: a `tutorreply` row at the top of the bell when a reply lands while another tab is showing. The session screen's own chat gets no notice: it is pushed over the shell, so the learner is looking at it.

- [ ] **Step 1: Import**

```dart
import 'testu_notifications.dart';
```

- [ ] **Step 2: In `_send`, extend `says`**

```dart
    void says(String s) {
      if (!mounted || !_waiting) return;
      _timeout?.cancel();
      setState(() {
        _waiting = false;
        _chat.add((false, s));
      });
      _scrollDown();
      // Reply landed while the learner was on another tab: the bell says so.
      // Local only — the reply already reached only this learner's channel.
      if (testuLive && !widget.active) {
        addTestuNotice(testuNoticeTitle('tutorreply', ''),
            s.length > 120 ? '${s.substring(0, 120)}…' : s,
            type: 'tutorreply');
      }
    }
```
`sullyReplies()` already collapses agent errors into `sullyUnavailable()`, so a failure line becomes the notice body — acceptable: the learner asked and should know it did not land.

- [ ] **Step 3: Analyze**

Run: `flutter analyze lib/testu/testu_tutor.dart`
Expected: clean.

- [ ] **Step 4: Simulator check**

Live build, IRIS tab: type a question, immediately switch to TEMAS. When the reply arrives (up to 90 s), the Today bell gets the dot; the row reads "IRIS te respondió" with the reply's first line; tapping it selects the IRIS tab, where the reply is already in the chat. Switch back and forth again without asking: no new row (no reply, no notice).

- [ ] **Step 5: Leave uncommitted for the user**

---

### Task 9: End-to-end smoke and hand-off

**Files:** none new.

- [ ] **Step 1: pbxproj guard**

```bash
cd "/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs"
git diff --stat ios/Runner.xcodeproj/project.pbxproj
```
If the diff is only `objectVersion = 60` → `54`: `git checkout -- ios/Runner.xcodeproj/project.pbxproj`.

- [ ] **Step 2: Full analyze and tests**

```bash
flutter analyze
flutter test
```
Expected: no issues; all tests pass (the two new files plus the existing suite).

- [ ] **Step 3: Demo build unchanged**

```bash
flutter test --dart-define=TESTU_CLIENT=vueling test/testu_notifications_test.dart
```
Expected: the store tests early-return (`refreshTestuNotices` is a no-op when `!testuLive`) so the "refresh maps the server rows" and "dismissed row" tests FAIL under vueling — that is the demo gate working, not a bug; the target-mapping and bell tests pass. Do not "fix" this; note it in the report. Then run the demo on the simulator once: `flutter run -t lib/main_testu.dart --dart-define=TESTU_CLIENT=vueling`, open the bell: the three seeded notices, swipe right toggles, swipe left deletes, tapping a row does nothing (no `type`), exactly as before.

- [ ] **Step 4: Two-learner smoke (spec "Testing" line 148)**

On the simulator as learner A: answer a question, comment on it. In the terminal as admin (or a second learner with a curl password, Task 3 Step 5): react and reply. On the simulator: within 60 s the bell dots; open it (server marked read: `curl … notifications.json` as A shows `"unread":0` after the screen opened); tap the reply → session → the highlighted comment. Background/foreground the app: one refresh on resume.

- [ ] **Step 5: Report**

List the changed files in both repos, the curl transcript of Task 3 Step 5, and the two follow-ups outside code the spec names (Deliverables): the written request to EnterMedia for a per-user websocket channel (replaces the 60 s poll; the `// ponytail: polling` comment marks the swap point in `testu_notifications.dart`), and the production runbook line: load list `learnernotificationtype` and field set `learnernotification` (deploy + restart) before the first comment is posted. Leave everything uncommitted for the user.

---

## Self-review against the spec

- Server entity and list (spec 102): Task 1. `entitytopic` added beyond the spec's list; reason stated in Task 1 and used in Task 5/7.
- Producers (104–109): Task 3 — reply → parent author, mention → each id (folded when equal to the parent author), reaction → author with in-place update and delete on removal, self skipped; console replies go through the same `comment.json` so they are `reply` rows with no extra code.
- Endpoints (111): Task 2 — newest first, 50, unread count; `ids[]` or `all`.
- Live store: start (`_restore`/`_onSignedIn`), resume, tab change, 60 s timer while foregrounded, `// ponytail: polling` note (Tasks 4, 6).
- Bell dot = unread (unchanged expression, now fed by server rows); `markread.json` on open; swipe actions on the local copy with the ponytail note (Task 5).
- Tap → origin with `highlightMessageId` on `TestuThread`, session at that question, topic review tab, IRIS tab (Tasks 5, 7).
- Web URL on tap is Part E's work: Part E Task 3 replaces the tap body written here with one call, `openLearnerRoute(LearnerRoute(tab, tutorialId:, questionId:, messageId:))`, once `learn-web` has merged this plan. Until then the direct `Navigator` push here is the behaviour on both platforms.
- Local `tutorreply` (108, 120): Task 8; demo `addTestuNotice` unchanged.
- Tests (144–146): unit routing table and JSON mapping (Task 4), bell dot widget test (Task 4), thread highlight widget test (Task 7), curl recipes (Tasks 2, 3), simulator smoke (Tasks 6–9).
- Type consistency: `TestuNotice` named params (`id, type, channel, messageId, tutorialId, topicId, questionId, date`) match `fromJson`, `testuNoticeTarget` and the tests; `TestuNoticeTarget` record fields `(tab, topicId, questionId, messageId)` match Task 5's `_open`; `highlightMessageId` is the same name on `TestuThread`, `SocialThreadEntry`, `_VerdictExtras`, `TestuSessionScreen`, `TestuTopicHomeScreen`; `EmeQuestionSource.questionId` matches `TestuSessionScreen.questionId`.
