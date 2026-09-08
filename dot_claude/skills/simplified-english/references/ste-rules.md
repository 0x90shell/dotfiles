# ASD-STE100 rules as applied here

<!-- slop-check: ignore (this file names the constructions it removes) -->

## Sentences

- One idea per sentence.
- Procedural sentences: 20 words maximum.
- Descriptive sentences: 25 words maximum.
- Paragraphs: 6 sentences maximum.
- Start a procedural sentence with the verb. "Run the dedup tier", not "The dedup
  tier should be run".
- Active voice everywhere. Passive hides who acts, which is exactly the
  information a reader needs.
- Present tense for how things behave. Past tense only for what actually happened.
- No sentence whose subject is "there" or "it" standing for nothing.

## One word, one meaning

Pick one term per concept and repeat it. Varying vocabulary for style makes the
reader ask whether you mean something different.

Collapse these into one word each:

| Use | Instead of |
| --- | --- |
| make sure that | check, verify, confirm, validate, ensure |
| start | initiate, kick off, commence, spin up |
| use | utilize, leverage, employ |
| about | approximately, roughly, in the region of |
| but | however, nevertheless, that said |
| so | therefore, thus, hence, consequently |
| also | additionally, furthermore, moreover |
| before | prior to, in advance of |
| after | subsequent to, following |
| do | perform, execute, carry out |
| find | identify, ascertain, determine |
| fix | remediate, address, resolve |
| show | demonstrate, illustrate, highlight |
| let | enable, allow, facilitate |
| need | require, necessitate |
| enough | sufficient, adequate |
| build | construct, assemble, provision |
| change | modify, alter, adjust |

## Banned outright

- Em dashes. Two sentences, or a colon.
- Semicolons joining independent clauses. Two sentences.
- delve, robust, seamless, comprehensive, crucial, pivotal, landscape, realm,
  testament, underscore, myriad, intricate, nuanced, holistic, paradigm,
  "deep dive", "at the end of the day", "in today's world".
- "It's not X, it's Y" and every variant. State the thing.
- Tricolons used for rhythm: "faster, cleaner, simpler". Say which one you mean.
- Openers: "Great question", "Certainly", "Absolutely", "Let's dive in".
- Closers: "I hope this helps", "Let me know if", "Feel free to".
- A final paragraph that summarises the document above it.
- Rhetorical questions used as headings.
- Noun stacks over two deep. "ROM hash index build failure" becomes "the build of
  the ROM hash index failed".

## Hedging

Hedge only where there is real uncertainty, and then name it precisely.

- Bad: "This may potentially help somewhat in certain cases."
- Good: "This is untested on the patch tier."

Never stack hedges. One qualifier per claim.

## Numbers and evidence

- Keep every figure from the source.
- Attach a figure to what produced it: "52s, measured directly" beats "slow".
- Distinguish measured from inferred, in the text, every time.
