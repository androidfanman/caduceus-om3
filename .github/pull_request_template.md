<!--
This title and every commit subject share the Conventional Commits 1.0.0 format:
https://www.conventionalcommits.org/en/v1.0.0/

  <type>(<scope>)?!?: [<issue>]? <imperative summary>

  types    build, chore, ci, docs, feat, fix, perf, refactor, revert, style, test
  (scope)  the module changed, in parentheses. Optional
  !        optional, marks a breaking change
  [issue]  the main ticket ID in brackets. Omit when there is no ticket
  :        required, followed by one space

  feat(auth): [YCOM-21] add device-code login
  refactor(api)!: drop v1 response envelope

Never wrap a line yourself. GitHub turns each newline into a visible break.
One bullet is one line, however long.

Shortest body a reviewer can review from, under 256 words. Bullets, one line
each, not paragraphs. Delete a section marked optional when it has nothing to
say. A heading, an attribution footer, and an embedded screenshot or recording do
not count against the budget. Add one where seeing the change beats reading
about it, usually a UX change, not as a matter of course.

Never in the body: a retelling of the ticket, the path taken to the change,
alternatives rejected, counts of files or lines or tests, timings, coverage or
benchmark numbers nobody asked for, a tour of the code, or a note about your own
machine. A reviewer reads the diff and can click the ticket.

Write ASD-STE100 Simplified Technical English, for Zinsser's simplicity, brevity,
clarity, and humanity.

- Active voice, imperative for an instruction: "Run the test", not "The test should be run".
- Simple present or past tense. No perfect and no progressive.
- One idea per sentence, 20 words max. No clause-chains: split them.
- Cut every word that changes nothing for the reader. Simplicity, then brevity.
- Plain and direct, never stiff. Write for a person, not for a committee.
- No `-ing` form as a noun: "before you run it", not "before running it".
- Condition before action: "If the check fails, the run stops."
- Same word for the same thing every time. No synonym for variety.
- Serial comma before the `and` or `or` closing a list: `a, b, and c`.
- American English spellings: `color` not `colour`, `analyze` not `analyse`.
- Short common word: `use` not `utilize`, `fix` not `remediate`, `start` not `initiate`.
- Max three nouns in a row. Break a longer cluster with a preposition or a verb.
- Keep articles and relative pronouns. No slang, idiom, or metaphor. Technical names and code stay exact.
- No hedging unless the uncertainty is real.
- No em-dashes, no semicolons, no parenthetical asides, no antithesis, no aphorisms, no meta-commentary.

Leave no empty headings.
-->

## What

<!-- One or two sentences: what changed and where. Link every ticket this belongs to (Jira, Linear) as a URL, the one in the title first. No ticket: link nothing. -->

## Why

<!-- The problem, one or two sentences. Skip if What covers it. -->

## Changes

<!--
One bullet per significant change. One line each, six at most. Starts with an
imperative verb, design decisions or other crucial details may follow.

Example:
- Add `TokenCache` in front of the Athenz client, keyed by domain and role, so a burst of parallel requests triggers one token fetch instead of N.
- Refresh tokens at 80% of their lifetime rather than on expiry. A refresh that fails still leaves a usable token for the remaining 20%.
- Return the stale token when refresh fails and the token has not expired.
-->

## Verification

<!-- Only checks CI can't show: a manual repro, a one-off check. One line each. Never the standard build, test, lint, or hooks. Else delete. -->

## Notes / Follow-ups

<!-- Only what a reviewer or merger would be wrong not to know: a gap this PR doesn't fix, merge ordering, a dependent PR. One line each. Else delete. -->
