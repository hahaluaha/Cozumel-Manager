# Commit Review Gate — Design

**Date:** 2026-08-06
**Status:** Approved, pending implementation plan

## Problem

Commits currently go out with no enforced review step. The intent is that every
commit Claude makes is reviewed against the exact diff being committed, and that
no commit can carry a secret into git history.

Enforcement must not depend on remembering to review. It has to be structural.

## Scope

- Applies globally, to every repo worked on with Claude Code (config lives in
  `~/.claude/settings.json`).
- Gates only commits made through Claude's Bash tool. Commits made directly by
  the user in a terminal or in Xcode are out of scope.
- graudit-style vulnerability scanning (SQLi, XSS) is explicitly **not** part of
  this gate. It stays a manual sweep in the Kali VM. Rationale in Appendix A.

## Architecture

Two artifacts:

| File | Role |
|------|------|
| `~/.claude/hooks/commit-gate.sh` | The entire gate — detection, secret scan, token check, token writing |
| `~/.claude/settings.json` | `PreToolUse` hook entry, matcher `Bash`, invoking the script |

A `PreToolUse` hook receives the tool input on stdin and can block by exiting 2,
with stderr fed back to Claude. It cannot itself run a code review. The gate
therefore works as a two-step handshake: block the commit, force a review, let
the retry through.

### Control flow

```
Bash tool invoked
  |
  v
[1] Does the command invoke `git commit`?  -- no --> exit 0 (silent, ~1ms)
  |
 yes
  v
[2] Resolve repo root from cwd (`git rev-parse --show-toplevel`)
      not a repo / nothing staged --> exit 0
  |
  v
[3] Determine review target:
      default  -> `git diff --cached`
      -a/--all -> staged + unstaged tracked changes
  |
  v
[4] gitleaks scan of the target
      any finding, or gitleaks missing/erroring --> exit 2 BLOCK (no override)
  |
  v
[5] Hash target; compare to `.git/claude-review-ok`
      match    --> exit 0 ALLOW
      mismatch --> exit 2 BLOCK ("review this diff first")
      missing  --> exit 2 BLOCK
```

### Command detection (step 1)

Regex against the command string, matching `git commit` at a command boundary so
that chains and flags are handled:

- `git commit -m "..."`
- `git -C /path commit`
- `git add -A && git commit -m "..."`

Must not match the string appearing inside quoted text (e.g. `echo "git commit"`).
Best-effort; see Known Gaps.

### Review target (step 3)

`git commit -a` sweeps up unstaged changes to tracked files. If the gate hashed
and scanned only `git diff --cached`, it would be reviewing a smaller diff than
the one that actually lands. Detecting `-a`/`--all` and widening the target
closes that hole.

### The review token (step 5)

- Path: `.git/claude-review-ok` — inside `.git`, so never committed and never
  visible in `git status`. Naturally per-repo.
- Contents: two lines, both computed at approval time:

  ```
  staged=<hash of `git diff --cached`>
  all=<hash of staged + unstaged tracked changes>
  ```

- Written only by `commit-gate.sh --approve`, which recomputes both hashes
  itself. Claude never hand-writes a hash.

Two hashes are stored because `--approve` runs before the commit and cannot know
whether that commit will use `-a`. The gate selects which line to compare
against using the same `-a`/`--all` detection from step 3. A review that covered
only the staged diff therefore cannot authorize an `-a` commit that sweeps up
additional unstaged work — the `all` hash won't match unless the review actually
saw that wider set.

Keying the token to the diff hash is what makes the gate honest. Review, then
stage one more file, and the hash changes — the token is dead and the gate
blocks again. A single review cannot authorize later code.

## Enforcement model

The two gates are enforced very differently. Stating this precisely matters,
because the setup could otherwise imply more rigor than it has.

**gitleaks — machine-enforced, no override.** Any finding blocks. Claude has no
say. No token unlocks it. If gitleaks is absent or errors, the gate blocks
rather than passing: a secret scanner that fails open is worse than none,
because it invites trust it hasn't earned.

**Code review — the script enforces only that a review happened against this
exact diff.** It cannot judge the review's quality. What to do about findings is
a rule Claude follows, not one the script checks:

- Correctness / security / data-loss findings → do **not** write the token.
  Fix them, or raise them with the user and get explicit approval to proceed.
- Style and preference nits → report in the commit summary, non-blocking.

The script guarantees the review was fresh and covered the real diff. Claude
guarantees the response to it. The second is only as good as Claude's
discipline, and no part of this design changes that.

### Review depth

Inline review of the staged diff is the default — fast, cheap, appropriate for
commit frequency. The `/code-review` skill is reserved for larger changes at
Claude's or the user's discretion.

## Secret scanning

gitleaks, installed via `brew install gitleaks`. Not currently present on this
Mac (it exists only in the Kali VM); installing it is a prerequisite of the
implementation plan.

A built-in regex scanner was considered as a no-install alternative and rejected:
roughly 60% of gitleaks' recall, for the saving of a single brew command.

False positives are handled by gitleaks' own allowlist config rather than a
bespoke mechanism.

## Bypass

`CLAUDE_COMMIT_GATE=off git commit ...` skips the **token check only**. It never
skips gitleaks.

Every bypass appends a line to `~/.claude/logs/commit-gate.log` with timestamp,
repo, and command.

Known limitation, accepted deliberately: a bypass Claude can type is a bypass
Claude can abuse. It exists for the user's emergencies. The log makes use of it
visible after the fact; that visibility is the only real control on it.

## Known gaps

- Commits not produced by `git commit`: `git revert`, `git merge`,
  `git rebase --continue`. Not detected. Documented, not chased.
- Commits made outside Claude Code entirely (terminal, Xcode UI). Out of scope
  by design — see Scope.
- Command detection is regex against a string, not shell parsing. Exotic
  constructions can evade it.
- Hook configuration loads at session start. Edits require a Claude Code restart.

## Testing

A test script feeds `commit-gate.sh` synthetic stdin payloads and asserts exit
codes:

| Case | Expected |
|------|----------|
| Non-git command (`ls -la`) | exit 0, silent |
| `git commit`, no token | exit 2, block |
| `git commit`, stale token (diff changed since review) | exit 2, block |
| `git commit`, fresh matching token | exit 0, allow |
| `git commit -a` where unstaged changes are outside the token's hash | exit 2, block |
| Staged fake AWS key, valid token present | exit 2, block (gitleaks wins) |
| gitleaks binary absent | exit 2, block (fails closed) |
| `CLAUDE_COMMIT_GATE=off`, no token | exit 0, allow + log line |
| `CLAUDE_COMMIT_GATE=off`, staged fake secret | exit 2, block |

## Appendix A — why graudit is not in the gate

graudit is grep against curated signature lists. No severity model, no dataflow
analysis. It flags every `$_GET`, every `echo`, every concatenated query, and
leaves triage to a human — which is exactly right for a deliberate audit pass and
exactly wrong for a blocking hook.

In the commit path it would fire on most PHP commits, nearly all false, and
train reflexive use of the bypass. A gate that is routinely bypassed is worse
than no gate, because it stops carrying signal. gitleaks survives this test
because a secret match is nearly always a true positive.

Scope reinforces it: SQLi and XSS are website concerns. The Mac app is Swift,
with no SQL and no HTML rendering, and its Supabase work uses typed filter
methods per project convention.

graudit remains a manual sweep in the Kali VM, run against the website repo at
the user's discretion.
