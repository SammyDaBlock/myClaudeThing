---
name: "summarize-notes"
description: "Clean up, fact-check and summarize school notes or lesson transcripts (typed, handwriting photos, speech-to-text) into a study summary, in chat or saved to Apple Notes (written from the NAS through iCloud, no Mac needed). Use whenever the user shares notes or a transcript, or asks to tidy or summarize them."
---

# Summarize notes

The input is either notes the user wrote (typed, or a photo of handwriting) or a transcript of what the teacher said during the lesson (speech-to-text). Either way it's messy: spelling mistakes, missing or misheard words, abbreviations, half sentences and jumps between topics. That's normal, so don't comment on it. Turn it into something clean the user can actually study from. Most of these are school notes that get learned for tests, so being accurate matters more than being short.

This also triggers on vague asks like "fix this" or "make this readable" with pasted notes or a pasted transcript, or just a photo of notes with no text. It also covers "summarize my note about X" for a note that's already in Apple Notes: read it from the NAS with `~/icloud-notes/notes search X` and `notes read ID` (see "Apple Notes" below for how to run them).

## 0. Ask where the summary goes

The summary can go in the chat, into the user's Apple Notes school folders, or both.

**Skip the question when:**
- The user already said where ("put this in my notes", "just summarize it here"). Do that.
- Another skill (like `clean-school-notes`) loaded this skill only for its cleanup rules. Then just follow the cleanup rules and let that skill decide the output.
- AskUserQuestion isn't available (scheduled or unattended run). Default to chat.
- The NAS can't be reached (no Custom MCP `server_run` tool and you're not on the NAS), or it says the iCloud session expired. Default to chat and say in one line at the end that saving to Notes wasn't possible right now.

**Otherwise ask before doing the work:**
1. Get the subject folder list first (`~/icloud-notes/notes folders` on the NAS; subject folders are the ones directly inside `School-Notes` whose name doesn't start with `#`) and guess which subject the notes belong to from their content.
2. Ask one AskUserQuestion with these options:
   - `Apple Notes: <guessed subject>` (Recommended, if you're fairly sure of the subject)
   - `Just chat`
   - `Both`
   The user can pick Other to type a different subject.
3. If you can't tell the subject at all, drop the subject from the label and add a second question listing the 2-4 most likely subject folders.

Keep the question short. The user doesn't like reading much.

## Why the notes look like this

The user writes these notes live while the teacher is talking, and the teacher's explanations can be confusing and jump around. On top of that, the user is dyslexic. So expect:
- **Things in the wrong order.** Events, steps or causes written down in the order the teacher mentioned them, not the order they actually happened.
- **Misheard or swapped words.** A word that sounds or looks like the right one but isn't (similar-sounding names, terms, numbers with swapped digits).
- **Mixed-up connections.** A cause attached to the wrong effect, or a fact that ended up under the wrong topic.
- **Unfinished thoughts** where the teacher moved on before the user finished writing.

Your job is to make the notes actually make sense, not just fix the spelling. If a sentence is confusing, work out what the teacher most likely meant and write that clearly.

## Lesson transcripts

A transcript is easy to spot: spoken style, filler words ("ehm", "takže", "jo"), the teacher talking to the class, student questions, often very long, sometimes with timestamps or `Speaker 1:` labels. It has different problems than handwritten notes:

- **Speech-to-text errors.** Names, technical terms and foreign words get turned into similar-sounding nonsense, especially in Czech. Numbers can come out as words or wrong digits. Work out the right word from context. If you really can't, write `[?]`.
- **Classroom chatter.** Drop everything that isn't lesson content: discipline ("Novák, sedni si"), attendance, "open your books to page 40", jokes and side stories, technical problems with the projector, small talk. Keep a side story only if it actually explains a concept.
- **Questions from students.** Drop the question itself, but work the teacher's answer into the right topic if it adds content.
- **Repetition.** Teachers repeat things a lot. Keep the point once. If the teacher stressed something or said it'll be on a test ("tohle bude v testu", "tohle si zapište"), mark it with `(na test!)` (or the same in the notes' language) after the point.
- **Homework, tests and deadlines.** Collect anything like "for Monday do exercise 5" or "test next Thursday on chapter 3" into a short last section called `Úkoly a testy` (or the same in the notes' language). Keep the dates here, they matter.
- **Length.** A transcript holds way more than handwritten notes. Still aim for medium length: keep every fact, definition and formula the teacher taught, but cut the talking around it.

The teacher's spoken words are usually more reliable than the user's handwritten notes for content, but less reliable for spelling of names and terms (because of transcription). Fact-check accordingly.

## 1. Read the notes

- **Photo of handwriting:** transcribe it first. If a word is hard to read, work it out from context. If you honestly can't tell what it says, write `[?]` instead of guessing. A confident wrong guess is worse than a gap.
- **Typed notes or transcript:** read the whole thing before changing anything, so you know the topic before you start fixing.

## 2. Pick the output language

Write the summary in the same language as the notes. If they mix languages, use the one most of the text is in. Keep technical terms the way the notes use them (English terms inside Czech notes stay English), since that's probably how the teacher says them.

## 3. Lesson dates

Remove any date that just records when the notes were written from the text: a date at the top of the page or next to a heading (like `29.9.`, `12/3/2026`, `Po 5.10.`), a weekday or "today"/"dnes" marker, a lesson or class number tied to a date, transcript timestamps. The summary is a study sheet the user comes back to weeks later, and the lesson date is just noise in the text.

But remember the lesson date: when the summary goes to Apple Notes, it becomes the note's `Datum:` line (see Output). If the notes don't say when the lesson was, it was today (pasted into chat right after class), unless the user or the content says otherwise. If unsure, the Bakaláři timetable (`bakalari_get_timetable`) shows which day that subject had a lesson with a matching topic.

This is only about the lesson's own date. Dates that are part of what's being taught stay, like the year a war started, when a law was passed, or a birth and death year in a biography. Those are exactly what gets asked on tests. Homework and test dates in the `Úkoly a testy` section also stay. If you can't tell whether a date is a lesson date or course content, keep it.

## 4. Fix spelling, grammar and misheard words

Fix everything silently. No lists of corrections, no "I fixed X". This includes words that are spelled fine but are clearly the wrong word for the context (a misheard or swapped term). Replace them with the word that fits.

## 5. Put things in the right order

Make the notes follow a logical order, even if they were written in a different one:
- **Anything with a timeline** (history, stories, biographies, processes over time): put it in chronological order.
- **Processes and steps** (science, math, how something works): put them in the order they actually happen.
- **Cause and effect:** make sure each cause is linked to the right effect.
- Move facts that landed under the wrong topic to where they belong.

## 6. Fact-check and fill gaps

Correct wrong facts and add important missing context so the notes make sense on their own. Blend these in naturally, with no markings. The user chose this on purpose.

Because nothing gets marked, the user can't tell your additions from their own notes. So keep the bar high:
- Only fix or add solid, standard textbook knowledge you're confident about.
- Don't invent specific dates, numbers, names or formulas you aren't sure of.
- If something looks off but you're not sure it's actually wrong, keep the notes' version. The teacher may have taught it that way.
- Add context only where a point would be confusing without it. Don't pad the notes with facts beyond what the class covered.

## 7. Organize and summarize

Aim for medium length: easy to skim, but with enough explanation to learn from. Keep it easy to read for someone with dyslexia.

- Group by topic with a short heading each, even if the original notes jump around.
- Under each heading use bullets: a point plus 1-2 sentences of explanation when needed.
- Separate each topic from the next with a line of `==============================` so the topics are easy to tell apart at a glance. Put it only between topics, not before the first one or after the last one.
- Always leave an empty line above and below that separator line. In markdown, a line of `=` directly under text turns that text into a big heading, so without the empty lines the separator disappears and messes up the layout.
- Use short, simple sentences. Avoid long walls of text and complicated sentence structure.
- **Bold** key terms and definitions.
- Keep every important fact, definition, date that's part of the content, name and formula. Only cut repetition, filler, classroom chatter and lesson dates.

Structure (chat output):

```
## [Topic 1]
- **Key term**: what it means, short explanation.
- Point, with a short explanation if needed.

==============================

## [Topic 2]
- ...

==============================

## Úkoly a testy
- ...
```

The `Úkoly a testy` section only appears when there's homework or a test announcement (usually only in transcripts).

### Check the timetable for that subject
When the Bakaláři tools are available, also look at the next lessons of this subject in the timetable (`bakalari_get_timetable` for this and next week). If a teacher already wrote a topic like `test`, `písemka`, `písemná práce`, `prověrka`, `opakování`, `prezentace` or `odevzdání` for an upcoming lesson, add it to `Úkoly a testy` with that lesson's date and "(podle rozvrhu)". Also use it to give a date to a test the notes mention without one ("příště test" = the next lesson of that subject). Skip this quietly if Bakaláři isn't reachable.

## 8. Output

### Chat
Return only the summary. No intro like "Here is your summary", no recap of what you did. If something was unreadable (`[?]`) or you weren't sure about a fact, add one short line at the very end saying so, nothing else.

### Apple Notes
Apple Notes is written from the NAS, which talks to Sammy's iCloud directly (no Mac needed): `~/icloud-notes/notes`, run through the Custom MCP `server_run` tool (or Bash, if you're Claude Code on the NAS). Load the `clean-school-notes` skill with the Skill tool and follow its rules for these parts only. Don't run its full batch workflow: never touch other notes in the folder beyond what's listed here. Its "Never delete anything" rule applies here too.
- **How to run the tool, and what to do if iCloud is signed out:** "How you reach Apple Notes" in `clean-school-notes`.
- **Stay inside the school folders** and use the subject folder the user picked.
- **Format:** the clean note Markdown format from `clean-school-notes` step 5 (`# Title`, `*Datum: ...*`, `## Sections`, bullets), no `=====` separators. Empty line before every section heading.
- **Date line.** Every note gets the `*Datum: ...*` line right under its title, with the lesson date from step 3, following "Lesson dates" in `clean-school-notes` (when merging into a note that already has one, add the new date to it).
- **One note per topic.** If the summary has several topics, each gets its own note, created in the order they were taught (`notes create` without `--created` gives them "now", which is right for a lesson from today; create them one by one, oldest topic first).
- **Merge with existing notes.** `notes info "<Subject>"` and check for a note on the same topic. If one exists, merge the new content into it with `notes write` instead of making a duplicate. If that existing note is messy (an unprocessed original): create the merged clean note first, then move the original to `#ARCHIVE` with `notes move`, exactly like `clean-school-notes` step 5. If it has images or tables, `notes write` refuses it: make a separate `<topic> (pokračování)` note instead and say so.
- **New note names** (the first line) must not match any other note name in that folder.
- **Archive the raw input.** Save the original pasted text (or your transcription of a handwriting photo) as a new note in `#ARCHIVE` (`notes create "School-Notes/#ARCHIVE"`), named after the topic (add ` (2)` etc. if `notes info "#ARCHIVE"` shows the name is taken), with this info line under the name:
  ```markdown
  <topic name>
  *Předmět: Fyzika · Vloženo z chatu: 2. 10. 2026 12:05*

  ...original text, unchanged...
  ```
  Photos from the chat can't be attached to notes, so the archive copy holds the transcription only.
- **Leave `Úkoly a testy` out of the note.** Notes are study sheets, homework goes stale. Put that section in the chat reply instead, and add it to the class site's tests list (below).
- **Check** the first note you wrote by reading it back with `notes read ID` (title, date line, headings, empty lines, bullets, no raw symbols), like `clean-school-notes` step 6.
- **Sync the class site and the #ARCHIVE backup.** Run `~/icloud-notes/site-sync` (see `clean-school-notes` step 7), so the notes you just wrote are on https://zapisky.sammydablock-nas.site and the archived raw input is in Sammy's private backup. Handle `EXTRA` lines only if they're caused by this run (a note you renamed or merged away): archive those with `publish --hide` (never `--delete`). Leave other `EXTRA` lines alone and just mention them. If the NAS can't be reached, say so in one line.
- **Tests list.** If the summary has an `Úkoly a testy` section, add those items to the site's list: get the current list with `~/school-notes/publish --tasks-show`, take its live automatic items (leave out the ones marked `manual` or `archived`, and drop the `id`, `manual` and `archived*` fields), add the new items (format in `clean-school-notes` step 8; `sure: true` only if the teacher clearly announced it with a date or the timetable names it; `source: "zápisky"` or `"rozvrh"`), and save that list back with `publish --tasks`. Sammy's own and archived items are kept automatically. Keep existing items' subject and title exactly as they were, so their votes stay attached. Never leave out other live items here, or they'd move to the archive.

Then reply in chat with only:
- One line per note: created or updated, and which folder.
- One line: synced to the class site and `#ARCHIVE` backed up (or why not).
- The `Úkoly a testy` section, if there is one.
- One short line if something was unreadable or a fact was uncertain.

### Both
Do the Apple Notes part, then post the full chat summary (including `Úkoly a testy`) followed by the one-line-per-note list and the site line.
