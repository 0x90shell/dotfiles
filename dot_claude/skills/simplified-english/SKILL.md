---
name: simplified-english
description: Rewrite a document into ASD-STE100 Simplified Technical English. Use when the user says "/simplified-english", "de-slop this", "rewrite in plain english", "simplify this doc", "make this readable", "strip the AI voice", or when producing a findings file, report, plan document, README or commit body that someone else will have to read.
argument-hint: "[path/to/file] (blank = the document just written)"
---

<!-- slop-check: ignore (this file names the constructions it removes) -->

Rewrite a DOCUMENT to ASD-STE100 Simplified Technical English, the controlled
language used for aerospace maintenance manuals. It exists so that a procedure
reads the same way to every reader, which is the same property a findings file or
a plan needs.

This is the heavy pass, for text that gets read more than once. Chat replies are
already governed by the `plain` output style; do not run this on them.

## Do not touch

Code, identifiers, file paths, command lines, log excerpts, error strings and
quoted material from someone else. A variable named `robust_parse` is a name, not
prose. Rewriting quoted text falsifies it.

## The pass

1. **Read the whole document first.** The most common failure is rewriting
   sentence by sentence and losing the argument.
2. **Fix structure before wording.** If the conclusion is at the bottom, move it
   to the top. No amount of sentence polish rescues a buried finding.
3. **Apply the rules** in `references/ste-rules.md`. Load that file now if you have
   not already; it carries the sentence rules, the approved-word substitutions and
   the banned constructions.
4. **Cut what the document does not need.** Restated headings, a summary that
   repeats the section above it, throat-clearing before a list, and any sentence
   that only announces what the next sentence says.
5. **Check the claims survived.** Every number, path, exit code and measurement in
   the original must still be present and still attached to the same subject. This
   is where a simplification pass does real damage, so verify it explicitly.

## Verify by counting, not by feel

The measurable properties are the point. Before and after, count:

```sh
wc -w FILE                     # words
grep -o '[.!?]' FILE | wc -l   # sentences
grep -o '—' FILE | wc -l       # em dashes: must end at 0
```

Report the before and after numbers. If word count did not fall and em dashes did
not reach zero, the pass did not do anything and you should say so rather than
claim success.

## Scope discipline

Shortening is not the goal; clarity is. A document that loses a necessary caveat,
a measurement or a named uncertainty has been damaged, not improved. When a
sentence is long because the idea is genuinely conditional, split it into two
sentences rather than deleting the condition.
