---
name: "clean-school-notes"
description: "Go through Sammy's School-Notes folders in Apple Notes (read and written from the NAS through iCloud, no Mac needed), clean up messy notes, merge same-topic notes, split into one note per topic, and move the originals to #ARCHIVE. Use when asked to clean, sort or fix school notes in Apple Notes."
---

# Clean school notes in Apple Notes (through the NAS)

Go through the school notes in Apple Notes, turn the messy ones into clean study notes (one note per topic), merge notes that cover the same topic, and move every original into `#ARCHIVE`. Then make sure the class notes site (https://zapisky.sammydablock-nas.site) and the private `#ARCHIVE` backup match Apple Notes, publish the `#Materialy` links and PDFs to the site's Učebnice page, refresh the site's list of possible tests and homework (from Bakaláři, the timetable, messages, the notes and classmates' votes), and check what classmates sent in.

## How you reach Apple Notes

Everything goes through the NAS, which reads and writes Sammy's iCloud notes directly. No Mac, no AppleScript.
- **Running it:** use the Custom MCP `server_run` tool (load it with ToolSearch if it's deferred). If you are Claude Code running on the NAS itself, use Bash instead. Same commands either way.
- **The tool:** `~/icloud-notes/notes`. Run it with no arguments to see the help. The commands you need:
  - `notes folders`: the folder tree of `School-Notes`.
  - `notes info [FOLDER]`: one JSON line per note: `id`, `folder`, `title`, `created`, `modified`, `datum` (the `Datum:` line, or null), `images`, `tables`, `other_attachments`, `locked`.
  - `notes read ID`: one note as Markdown. Images and tables show up as `[attachment: ...]` / `[table]` placeholders.
  - `notes create "School-Notes/<Subject>" --created <ISO> < note.md`: new note from Markdown, with the creation date you give it.
  - `notes write ID < note.md`: replaces a note's whole text (images included, see "Images, tables and files"). The old version is saved on the NAS first (`~/nas-browser/config/icloud-notes/backups/`). It refuses notes that have tables or files.
  - `notes move ID "School-Notes/#ARCHIVE"`: moves a note to another folder, completely unchanged (images, tables and its creation date included). It also logs which subject it came from (`~/nas-browser/config/icloud-notes/moves.jsonl`).
  - `notes files ID DIR`: saves a note's images and files, numbered like `[image N]` in `notes read`.
  - `notes html ID`: used by the site sync.
- **Feeding Markdown in:** use a quoted heredoc so nothing gets mangled:
  ```bash
  cat <<'EOF' | ~/icloud-notes/notes create "School-Notes/Dějepis" --created 2026-09-25T12:16:05
  # Sámova říše
  *Datum: 25. 9. 2026*
  ...
  EOF
  ```
- **Timeouts:** `server_run` calls can cut off after about 60 seconds. `notes info` on all of School-Notes takes about 10 seconds. If something times out, check the result (`notes info`, `notes read`) before you retry, so you don't create a note twice.
- **Signed out:** if a command says the iCloud session expired, stop. Run `~/icloud-notes/notes login`, tell Sammy to log in at https://browser.sammydablock-nas.site (tick "Keep me signed in", close that window when done), and continue after he says it's done. NAS Status also alerts him about this.

## Never delete anything

- **Notes:** never delete a note. Originals go to `#ARCHIVE` with `notes move`. Never move a note to Recently Deleted.
- **Class site notes** that shouldn't be public anymore: `~/school-notes/publish --hide '<subject>' '<title>'`. Never `publish --delete` on your own.
- **Tests, homework, other items**: just leave them out of the list you send with `publish --tasks`. Anything you don't send moves to the Archive by itself (admin page, with Restore and Delete buttons). Past items move there on their own too.
- **Presentations**: Sammy's list, don't touch them.
- **Classmate uploads and votes**: never delete them.
- **The private `#ARCHIVE` backup**: it only ever adds and updates.

## Stay inside the school folders

The iCloud account has lots of personal notes that have nothing to do with school. Only ever list, read or change notes inside the subject folders from step 0, `#Materialy` (read only) and `#ARCHIVE`. The `notes` tool works on `School-Notes` by default: never pass `--root` in this skill.
- Leave the `Notebooks` note in the top-level `School-Notes` folder alone.
- If a note inside a subject folder clearly isn't school material, leave it alone.

## Folders

### 0. Find the subject folders
Run `notes folders`. Every folder directly inside `School-Notes` is a subject folder, except the special ones whose name starts with `#`:
- `#ARCHIVE`: the originals (step 5), backed up privately by the site sync.
- `#Materialy`: Sammy's list of study materials (where to buy books and workbooks, book PDFs). It is NOT cleaned, archived or published as notes. Only read it in step 7c. Never change, move or rename its notes.
- Any other folder starting with `#`: leave it alone and mention it in the report.

Use the names exactly as printed (diacritics and capitals must match). If a subject folder shows up that you haven't seen in earlier runs, it's a new subject: process it like the rest and mention it in the report.

## Images, tables and files

Notes can contain images, tables and files (PDFs, drawings).

**Images work.** `notes read` shows each one as `[image N]` at its spot in the text. To carry images into a clean note:
1. Clear the folder and save the original's images: `rm -rf ~/nas-browser/config/icloud-notes/tmp && mkdir -p ~/nas-browser/config/icloud-notes/tmp`, then `notes files ID /config/icloud-notes/tmp`. Each `[image N]` becomes `/config/icloud-notes/tmp/NN-<name>` (`[image 2]` -> `02-...`). If you merge several originals, save each one's images into its own subfolder (`/config/icloud-notes/tmp/a`, `/b`, ...) so the numbers don't clash.
2. In the clean note's Markdown, put each image on its own line, right under the text it illustrates (usually where it was relative to that text), keeping their original order: `![](/config/icloud-notes/tmp/02-img1.png)`.
3. `notes create` / `notes write` upload the images and place them. TIFFs and other formats get turned into PNG on the way.
4. Check: `notes read` the new note and count the `[image N]` lines. It must have as many images as the originals had (minus any you left out on purpose, like a duplicate photo). Never end up with fewer images than the original without saying so in the report.
5. Delete the tmp folder when the run is done.

`notes write` on a note that already has images replaces them too: save them with `notes files` first and put them back in the new Markdown, or they're gone from that note (the old version stays in the backup on the NAS).

**Tables and files don't work yet.** `notes write` refuses notes with a table or a file (PDF, drawing), and `notes create` can't make them. So:
- **An original with a table or file** (`tables` > 0 or `other_attachments` in `notes info`): don't build a clean note from it. Leave it where it is and list it in the report under "needs the Mac".
- **A clean note with a table or file** that a new topic should be merged into: don't merge into it. Make the merged content a separate note (`<topic> (pokračování)`) and mention it in the report.
- Photo-only notes like `F2=` in Fyzika (a `com.apple.paper` drawing): leave them alone, mention them in the report.

## Lesson dates (the `Datum:` line)

Every clean note has one date line right under its title, saying when the topic was taught:

```markdown
*Datum: 25. 9. 2026*
```

The class site shows it as a 📅 badge and sorts each subject by it, and the site sync uses it to tell clean notes from messy ones. So a clean note without it won't get published.

Where the date comes from, best first:
1. **A date Sammy wrote in the notes** next to that part (`23. 9.`, `Po 5.10.`). Missing year = the school year's current year.
2. **The original's creation date** (`created` in `notes info`; for originals already in `#ARCHIVE`, also `moves.jsonl`).
3. **Bakaláři timetable** (`bakalari_get_timetable` for that week): the lesson whose `topic` matches. Use this to check or pin down a date when 1 and 2 are vague.

Format rules:
- Several lessons merged into one note: `Datum: 25. 9. a 2. 10. 2026` (oldest first). A range: `Datum: 23. 9. – 24. 9. 2026`.
- Only an upper bound known (the original was written later than the lesson): `Datum: nejpozději 23. 9. 2026`.
- Never invent a date. If none of the sources give one, use the original's creation date.
- When merging new content into a note that already has a date line, add the new date to it instead of replacing it.
- Lesson dates stay out of the note text itself. The `Datum:` line is the only place for them.

## Order by date created

Sammy sorts notes by date created, oldest at the top, and wants topics in the order they were learned. `notes create --created` sets the creation date, so:
- A new clean note gets the **creation date of the original it came from** (the oldest one, if several were merged). For a topic split off a note, use the original's creation date plus one second per topic, in the order they were taught (`12:16:05`, `12:16:06`, ...).
- A note you update with `notes write` keeps its own creation date.
- **Process originals oldest first** (by `created`).
- **Inside one note, topics go oldest to newest.** Notes are written top to bottom during class, so a topic higher up is older. If the note has lesson dates next to parts, use those to order the topics, then move the dates into each topic's `Datum:` line.

This ordering is only about which note comes first. Inside a note, content still follows the logical order from step 4.

## Workflow

### 1. Collect
Run step 0. Then `notes info` once for everything (all subject folders, `#ARCHIVE` and `#Materialy` in one go) and `notes read ID` for each note you need to look at. The Markdown mirror in `~/icloud-notes/mirror/School-Notes/` (refreshed every 30 minutes) is fine for a quick look across many notes; always use `notes read` for the note you're about to change.

Also check the site (on the NAS):
- `~/school-notes/publish --list` shows which notes are on the site.
- `~/school-notes/publish --inbox` shows what classmates sent in through the site (missing notes, corrections, photos).
- `~/school-notes/publish --tasks-show` shows the current tests/homework list, archived items included (they have `archived: true`).
- `~/school-notes/publish --votes` shows how classmates voted on those items (see step 8).
- `~/school-notes/publish --materials-show` shows the Učebnice page list (PDFs and #Materialy links).

### 2. Decide what needs work
- **Messy notes** (typos, half sentences, no structure, several topics mashed together, lesson dates in the text, raw `transcript:` / `Speaker 1:` speech-to-text dumps, no `Datum:` line): these get cleaned.
- **Already clean notes** (has a `Datum:` line, headings, bullet points, one topic): leave them, but they count as the home for their topic when merging. Small fixes that need no archiving, done with `notes write`: a missing `Datum:` line, or missing empty lines before section headings (put its images back, see "Images, tables and files").
- **Images, tables, files:** see "Images, tables and files".

Even if nothing needs cleaning, always run steps 7 (site sync), 7c (materials) and 8 (tests and homework).

### 3. Group by topic
Within each subject, figure out the topics across all messy notes plus existing clean notes.
- A **topic** is roughly what a teacher would put as the title of a lesson or a test chapter ("Punské války", "Kinematika", "Elektrický náboj"). Closely related sub-parts stay together as sections inside one note. Unrelated things get split into separate notes.
- Two notes (messy or clean) about the same topic get merged into one.
- Don't mix subjects. A topic note stays in its subject's folder.
- Note each topic's original creation date and lesson date for the ordering rules.

### 4. Clean the content
Use the same cleanup rules as the `summarize-notes` skill (load it with the Skill tool if it's available). In short:
- Notes are written live during class by a dyslexic student: expect wrong order, misheard or swapped words, causes attached to the wrong effect, unfinished thoughts. Work out what the teacher meant and write it clearly.
- Transcripts are full of chatter between classmates, names and swearing: keep only the teaching. No classmates' names, no private talk.
- Write in the notes' language. Keep technical terms as the notes use them.
- Lesson dates (`23. 9.`, `Po 5.10.`, "dnes") come out of the text and go into the `Datum:` line. Keep dates that are course content (years of events, etc.). If unsure, keep it.
- Fix spelling, grammar and wrong words silently.
- Put timelines in chronological order, processes in the order they happen, causes next to the right effects.
- Fix wrong facts and fill gaps only with solid textbook knowledge. Don't invent dates, numbers or names. If unsure, keep the notes' version.
- Keep every important fact, definition, content date, name and formula. Cut repetition and filler.
- Mark things the teacher said will be on a test with `(na test!)`.
- Short, simple sentences, easy to read with dyslexia. Bold key terms.
- Homework, test announcements and page numbers to do (`Učebnice 18/2-6`, "píšeme v pátek") don't go in the note. Collect them for step 8.

Differences from `summarize-notes`: no `=====` separator lines. Each topic is its own note instead. Unreadable bits stay as `[?]`.

Classmate submissions from the inbox are NOT merged in on your own: they can be wrong. List them in the report, and only work them into the notes if Sammy says so.

### 5. Write the notes
Work through originals oldest first. For each topic:
1. **Write the clean version first, then archive.** Never move an original before its content is safely in a clean note (created or updated, and read back), so nothing can get lost.
   - Topic already has a clean note: `notes write` that note with the merged content (its own images and the originals' images included).
   - Otherwise: `notes create "School-Notes/<Subject>" --created <original's created>` (see "Order by date created").
2. **Then move every original that went into it** to `#ARCHIVE` with `notes move ID "School-Notes/#ARCHIVE"`. The original stays exactly as it was (images included), so there is no copy to make and nothing for Sammy to delete by hand.
   - **Same name already in `#ARCHIVE`?** The private backup is keyed by note name, so two archived notes with the same name would overwrite each other there. Check `notes info "#ARCHIVE"` first. If the name is taken, rename the original before moving: `notes read` it (and `notes files` its images), change only its first line to `<name> (2)` (or `(3)`, ...), `notes write` it back otherwise unchanged with its images in place, then move it. If it has a table or file, move it anyway and mention it in the report.
3. **Names:** a new clean note's name (its first line) must not match any other note in that folder.

Clean note format (Markdown, which `notes create` / `notes write` turn into real Apple Notes formatting):
```markdown
# Topic name
*Datum: 25. 9. 2026*
- Intro point, if the topic has one.

## Section
- **Key term**: short explanation.
- Point, with a short explanation if needed.
  - Sub-point (2 spaces of indent per level).

## Next section
- ...
```
- The first line is the title (`# ...`), with no lesson date. The `*Datum: ...*` line comes right after it.
- One empty line before every section heading (`##`), except a heading that sits directly under the title and date line.
- Only one empty line per gap, and no empty lines at the very end.
- Images sit on their own line right after the bullets they belong to: `![](/config/icloud-notes/tmp/01-img1.png)`.
- What works: `#`, `##`, `###`, `- ` bullets, `1. ` numbered lists, `- [ ] ` / `- [x] ` checklists, `**bold**`, `*italic*`, `~~strike~~`, `[text](https://...)`, `![](image path)` on its own line. Nothing else (no tables, no code blocks, no `>` quotes).

### 6. Check
Read back the first clean note you wrote with `notes read ID` and make sure it looks right (title, date line, headings, empty lines before headings, bullets, no raw `**` or `#` symbols in the text) before writing the rest. For every note with images, do the image count check from "Images, tables and files". After moving originals, check with `notes info "#ARCHIVE"` that they arrived.

### 7. Sync the class site and the #ARCHIVE backup
Run `~/icloud-notes/site-sync`. It compares every clean note (has a `Datum:` line, in a subject folder) with the site, publishes what's missing or changed straight from iCloud (images included), then does the same for `#ARCHIVE` into the private backup. It also runs by itself every 30 minutes, but run it now so this run's changes are live. It takes about 10-30 seconds; if it times out, just run it again (it only redoes what's still missing).

What it prints:
- `published:` / `updated:` lines, with the number of images.
- `SKIPPED ...: has a table`: tables can't be exported from iCloud yet, so that note's site copy stays as it was. Mention it in the report.
- `EXTRA <subject> <title>`: on the site but not a clean note in Apple Notes (renamed, merged away, or moved). If it's a clean note that's only missing its `Datum:` line, add the line and run the sync again. Otherwise archive it on the site with `~/school-notes/publish --hide '<subject>' '<title>'`. **Never delete it.**
- `ARCHIVED  N hidden notes kept on the server`: fine.
- `OK  N up to date, ...` under `== site` and `OK  N backed up, ...` under `== #ARCHIVE backup`: done when there are no `FAILED` or `EXTRA` lines left. (Counts are from before this run's publishes, so they can be a bit behind.)
- `FAILED ...`: try once more, then mention it in the report.

The `#ARCHIVE` backup lives only in the admin page (button `🗄️ #ARCHIVE backup`, https://school-notes.sammydablock-nas.site/admin/archive). Never link or copy anything from it to a public place.

### 7c. Study materials from #Materialy
Sammy keeps a list of study materials in the `#Materialy` folder: where to buy textbooks, workbooks and exercise books, and book PDFs. They go on the site's **Učebnice** page (`/ucebnice`, school login needed) and in the box at the top of each subject page. Never change, move or rename the `#Materialy` notes themselves.

1. **Read them**: `notes info "#Materialy"`, then `notes read ID` for each. One note per subject, named loosely, like `Matika Priklady:`, `Anglictina Sesity:`, `Literatura Knihy:`. Match the name to a subject folder name (`Matika` = `Matematika`, `Anglictina` = `Anglický Jazyk`, `Cestina` = `Čeština`, ...). Notes with no links and no attachments are still being filled in: skip them and mention them in one line.
2. **Links** (`https://...` in the text): strip tracking junk from the URL (`utm_*`, `gad_*`, `gclid`, `gbraid`, `wbraid`, `fbclid` params). Look the page up with WebFetch to get the real title (book name, authors, publisher). Shop pages (Luxor, Knihy Dobrovský, Kosmas, Alza, the publisher's shop...) are `"kind": "koupit"`; other links are `"kind": "odkaz"`. Put a price in `detail` only if Sammy wrote it in the note.
3. **PDFs** (`other_attachments` in `notes info`): save them with `notes files ID /config/icloud-notes/tmp-files` (that's `~/nas-browser/config/icloud-notes/tmp-files` on the NAS), then copy each to `~/school-notes/data/files/` under a slug name (lowercase, no diacritics, dashes, `.pdf`, like `gateway-b1-workbook.pdf`) and list it with `"file": "<slug>.pdf"`. Skip a PDF that's already on the page with the same content (compare with `cmp` or `md5sum`). Delete `tmp-files` afterwards. PDFs are only for the class, never put them anywhere public.
4. **Save** all of them at once (the whole #Materialy list, every run):
   ```json
   {"items": [
     {"subject": "Matematika", "title": "Sbírka úloh z matematiky pro SOŠ a SO SOU a nástavbové studium (Hudcová, Kubičíková)",
      "url": "https://www.luxor.cz/v/1973787/sbirka-uloh-z-matematiky-pro-sos-a-so-sou-a-nastavbove-studium",
      "kind": "koupit", "detail": "sbírka příkladů, nakladatelství Prometheus"},
     {"subject": "Anglický Jazyk", "title": "Gateway to the World B1: Workbook", "file": "gateway-b1-workbook.pdf", "kind": "pdf", "detail": "pracovní sešit"}
   ]}
   ```
   Pipe it into `~/school-notes/publish --materials`. It replaces only the items that came from #Materialy and keeps the PDFs Sammy added himself. It prints `saved N #Materialy items (M other items kept)` and `SKIPPED` lines for a bad URL or a PDF that isn't on the NAS.
5. Something in #Materialy that is really a test date or homework ("koupit sešit do pondělí") also goes on the tests list in step 8 as `jine`.

### 8. Possible tests and homework
The site has a "Možné testy a úkoly" list (sidebar, home page and `/testy`). Rebuild it every run from everything available, then save it with `publish --tasks`. What happens to the items:
- Items you send are live (or updated).
- Your earlier items that you don't send anymore move to the Archive by themselves, with their votes. Nothing is ever deleted. Sending an archived item again brings it back.
- Items Sammy added, edited or restored in the admin page are marked `manual` and are always kept. Never change or remove them yourself, and don't send them again.
- Items Sammy archived or deleted himself stay that way, so sending them again does nothing. That's on purpose.
- Presentations are Sammy's list (admin page, `publish --presentations`). Don't touch them.
- Votes and item ids stick to subject + title. So when an item hasn't really changed, send it again with exactly the same subject and title, or its votes get lost.

Where to look (all read-only, never send or mark anything):
- **Bakaláři homework**: `bakalari_get_homework` (about 30 days ahead). Officially assigned, so `sure: true`.
- **Bakaláři events**: `bakalari_get_events` (`my`) for tests, trips, school events coming up.
- **Timetable (rozvrh)**: see "Reading the timetable" below. Teachers often write what the next lessons will be about.
- **Komens**: `bakalari_get_messages` (last ~3 weeks) and `bakalari_get_noticeboard`. Teachers announce tests here ("Zadání písemné práce ze ZSV, termín 5. 10."). Watch for corrections of earlier dates and use the newest one.
- **School email**: `bakalari_email_list` (last ~3 weeks), read the ones from teachers, Moodle or Techambition. New Techambition tasks are homework (often no deadline given).
- **The notes**: things written in class like "příště test", "na pátek", page numbers to do (`Učebnice 18/2-6`), and messy originals you cleaned this run.
- **Grades**: `bakalari_get_grades`. Only use them to spot tests that already happened (a mark on that topic and date means that test is done, so leave it out and it gets archived) and how often a subject has short tests, for guesses. **Grades never go on the site**, not even in details.
- **Old list**: `publish --tasks-show`. Send the live automatic items that are still relevant again (same subject and title). Leave out finished ones, so they get archived.
- **Classmates' votes**: `publish --votes` (see "Using the votes" below).

#### Reading the timetable
Call `bakalari_get_timetable` for this week and the next 2 weeks (one call per week, pass a `day` in that week). Each lesson has a `topic` (what the teacher wrote it will be about, often only filled in shortly before) and a `change` (substitutions, cancelled or moved lessons).
- **Upcoming lessons with a topic**: look for words like `test`, `písemka`, `písemná práce`, `prověrka`, `zkoušení`, `opakování` (often right before a test), `prezentace`, `referát`, `odevzdání`, `laboratořní práce`, `úkol`. Make an item on that lesson's date. If the topic names it directly ("Písemná práce: etapy života"), it's `sure: true`, `source: "rozvrh"`. If it only hints ("opakování před testem", "opakování"), it's `sure: false` with a detail like "V rozvrhu je opakování, možná bude test."
- **Pin down dates**: if an item from another source has no date ("test z mocnin", "příští týden test"), and an upcoming lesson of that subject has a matching topic or is the only lesson of that subject in that week, use that lesson's date.
- **Changes**: a cancelled or moved lesson (`change` filled, or a lesson missing compared to the usual week) goes in as `jine` ("Odpadá fyzika", "Supluje ..." without teacher names). If a test was planned for a lesson that's now cancelled, keep the test but drop its date and say so in the detail.
- **Past lessons** (this week so far): a topic like "Písemná práce" on a past date means that test is done, so leave matching items out (they get archived).
- The timetable also helps with "Lesson dates": a past lesson's topic shows when a note's topic was taught.

#### Using the votes
On `/testy` classmates vote per item: `done` (already happened / handed in), `wrong` (not true) or `date` (different date, often with a short note). Each person has one vote per item. Votes are hints from classmates, not proof:
- **Mostly `done` (3 or more, and more than half the votes):** look for confirmation (a grade on that topic around that date, a past timetable topic like "Písemná práce", a Komens message). If it's confirmed, or the item was only a guess (`sure: false`), leave it out so it gets archived. If it's an official item with a future date and nothing confirms it, keep it and mention it in the report.
- **Mostly `wrong` (3 or more):** re-check where the item came from. If it was a guess or a note mention, leave it out (archived). If an official source still says it, keep it and mention it in the report.
- **`date` votes with notes:** read the notes ("je to až ve čtvrtek") and check them against Komens and the timetable. Move the date if a source agrees, or if several classmates name the same date (then set `sure: false`). Never copy a note's text onto the site word for word.
- Fewer than 3 votes: just keep them in mind, no action needed.
- Votes on Sammy's `manual` items: don't change those items. List them in the report so Sammy can decide.

#### What goes on the list
- Only class stuff: tests, homework, things to bring, schedule changes, school events relevant to the class.
- Nothing private: no grades, no names of classmates or teachers' private matters, nothing from personal Komens conversations, no payments or trip money.
- `sure: true` only when it's officially announced with a date (Bakaláři homework or event, a teacher's Komens or email, a timetable topic that names it, or the teacher saying it in class with a clear day). Everything guessed or only hinted is `sure: false` and the site shows it as "možná".
- Educated guesses are fine if they're labelled as guesses, like "Krátký test: mocniny" with the detail "z matiky bývají krátké testy často, termín zatím neoznámený". Don't invent dates: unknown date = `null`.
- Czech, short. Subject names like the Apple Notes folders.

Format (pipe it into `~/school-notes/publish --tasks`):
```json
{"items": [
  {"date": "2026-10-05", "subject": "Základy Společenských Věd", "kind": "test",
   "title": "Písemná práce: vývoj, osobnost, etapy života", "detail": "Oznámeno v Komensu.",
   "source": "Komens", "sure": true},
  {"date": null, "subject": "Matematika", "kind": "ukol", "title": "Učebnice str. 18, cv. 2–6",
   "detail": "Zapsané v hodině 2. 10.", "source": "zápisky", "sure": false}
]}
```
`kind` is `test`, `ukol` or `jine`. `source` says where it came from (`Bakaláři`, `rozvrh`, `Komens`, `e-mail`, `zápisky`, `odhad podle Bakalářů`, ...). Don't include `id`, `manual` or any `archived` fields. It prints `saved N items (M Sammy's own kept, K moved to the archive, nothing deleted)`.

### 9. Report
Keep it short, Sammy doesn't like reading much:
- Per subject: which topic notes were created or updated, in the order they were made, and how many originals went to `#ARCHIVE`.
- **Needs the Mac:** notes with tables or files that were left alone, photo-only/drawing notes, archived notes whose name clashed in `#ARCHIVE`, and any note that ended up with fewer images than its original.
- New subject folders found this run.
- One line if something was unreadable, a fact was uncertain, or a date had to be guessed.
- **Class site:** the final `OK` numbers, how many notes were published, updated, skipped (tables) or hidden, and any that failed.
- **#ARCHIVE backup:** one line with the final `OK` numbers.
- **Materials:** one line: what went on the Učebnice page from #Materialy this run, and which #Materialy notes are still empty.
- **Tests and homework:** the upcoming ones with a date in the next 2 weeks, one line each (mark the ones found in the timetable), and how many moved to the archive.
- **Votes:** one line per item with 3+ same votes: what classmates said and what you did. Votes on Sammy's own items: what they say, so he can decide.
- **From classmates:** if the inbox has submissions, one line each (subject, note, what they say, how many files) and ask if Sammy wants them worked in. He marks them done in the admin page (https://school-notes.sammydablock-nas.site/admin).
