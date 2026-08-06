# Commit Review Gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Block any `git commit` Claude runs until the exact diff being committed has been reviewed and passes a gitleaks secret scan.

**Architecture:** A single bash script registered as a `PreToolUse` hook on the `Bash` tool. It exits 0 silently for non-commit commands, and for commits it runs gitleaks (non-overridable) then compares a hash of the review target against a token at `.git/claude-review-ok`. The token is written only by the same script invoked as `--approve`, after Claude has reviewed.

**Tech Stack:** bash, jq (`/usr/bin/jq`, present), gitleaks (via Homebrew, **not yet installed**), shasum.

**Spec:** `docs/superpowers/specs/2026-08-06-commit-review-gate-design.md`

## Global Constraints

- Script path: `~/.claude/hooks/commit-gate.sh`, mode `0755`.
- Hook registered in `~/.claude/settings.json` (global scope — all repos).
- Log path: `~/.claude/logs/commit-gate.log`.
- Token path: `<git-dir>/claude-review-ok`, resolved via `git rev-parse --absolute-git-dir`.
- Token format: exactly two lines, `staged=<sha256>` and `all=<sha256>`.
- Exit codes: `0` = allow, `2` = block (stderr is fed back to Claude).
- Fail closed: gitleaks missing, or exiting with anything other than 0 (clean) or 1 (leaks found), blocks the commit.
- Bypass token in command text: `CLAUDE_COMMIT_GATE=off`. Skips the token check only, never gitleaks.
- No external dependencies beyond jq, gitleaks, and coreutils/bash already on macOS.

### Versioning decision

The script is versioned in the **`~/.claude` repo** (remote: `hahaluaha/claude-config`, **public**). Its `.gitignore` excludes everything by default, so tracking the script requires explicit allowlist entries (Task 1). The script contains no secrets, so publishing it is safe — but **pushing is the user's decision**; tasks below commit locally only and never run `git push`.

This plan document itself lives in the Cozumel_App_Final repo. The two repos are committed to independently.

---

## File Structure

| File | Repo | Responsibility |
|------|------|----------------|
| `~/.claude/hooks/commit-gate.sh` | `~/.claude` | The entire gate: command parsing, diff targeting, hashing, token I/O, gitleaks, logging |
| `~/.claude/hooks/test-commit-gate.sh` | `~/.claude` | Test harness — builds throwaway git repos, feeds synthetic hook payloads, asserts exit codes |
| `~/.claude/.gitignore` | `~/.claude` | Modified: allowlist `hooks/` |
| `~/.claude/settings.json` | `~/.claude` | Modified: register the `PreToolUse` hook (untracked by `.gitignore` — local only) |

One script rather than several: it is ~200 lines with a single responsibility, and splitting it across files would mean a hook that breaks if any one piece goes missing.

---

### Task 1: Scaffold, install gitleaks, and pin its invocation

**Files:**
- Create: `~/.claude/hooks/commit-gate.sh`
- Create: `~/.claude/hooks/test-commit-gate.sh`
- Modify: `~/.claude/.gitignore`

**Interfaces:**
- Consumes: nothing.
- Produces: `run_gitleaks()` — reads a unified diff on **stdin**, returns `0` clean, `1` leaks found, `3` gitleaks unavailable/errored. Test harness function `assert_exit <expected> <label> <command...>`.

- [ ] **Step 1: Install gitleaks and record the version**

```bash
brew install gitleaks
gitleaks version
```

Expected: a version string, e.g. `8.28.0`. If brew reports it is already installed, that is fine.

- [ ] **Step 2: Determine which subcommand this version supports**

gitleaks renamed its scanning subcommands across 8.x. Check which exists:

```bash
gitleaks dir --help >/dev/null 2>&1 && echo "HAS dir" || echo "NO dir"
gitleaks detect --help >/dev/null 2>&1 && echo "HAS detect" || echo "NO detect"
```

Record the result. `run_gitleaks()` below probes at runtime and supports both, so no code change is needed either way — this step is to confirm at least one is available.

- [ ] **Step 3: Allowlist the hooks directory in `~/.claude/.gitignore`**

The file currently excludes everything (`*`) and allowlists only `CLAUDE.md`. Append:

```gitignore
!hooks/
!hooks/*.sh
```

- [ ] **Step 4: Write the test harness with its first failing test**

Create `~/.claude/hooks/test-commit-gate.sh`:

```bash
#!/bin/bash
# Test harness for commit-gate.sh
set -uo pipefail

GATE="$HOME/.claude/hooks/commit-gate.sh"
PASS=0
FAIL=0

assert_exit() { # $1 = expected code, $2 = label, rest = command
  local expected="$1" label="$2"; shift 2
  "$@" >/dev/null 2>&1
  local actual=$?
  if [ "$actual" -eq "$expected" ]; then
    printf 'PASS  %s\n' "$label"; PASS=$((PASS+1))
  else
    printf 'FAIL  %s (expected %s, got %s)\n' "$label" "$expected" "$actual"; FAIL=$((FAIL+1))
  fi
}

# Builds a throwaway repo, echoes its path
make_repo() {
  local d; d="$(mktemp -d)"
  git -C "$d" init -q
  git -C "$d" config user.email t@t.local
  git -C "$d" config user.name Test
  printf 'hello\n' > "$d/file.txt"
  git -C "$d" add file.txt
  git -C "$d" commit -qm init
  printf '%s' "$d"
}

# Feeds a synthetic PreToolUse payload to the gate
run_gate() { # $1 = command string, $2 = cwd
  printf '{"tool_input":{"command":%s},"cwd":%s}' \
    "$(printf '%s' "$1" | jq -Rs .)" "$(printf '%s' "$2" | jq -Rs .)" \
    | bash "$GATE"
}

# --- gitleaks availability ---
assert_exit 0 "gitleaks is installed" command -v gitleaks

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 5: Run it to verify the harness works and gitleaks is present**

```bash
chmod +x ~/.claude/hooks/test-commit-gate.sh
bash ~/.claude/hooks/test-commit-gate.sh
```

Expected: `PASS  gitleaks is installed`, then `1 passed, 0 failed`.

- [ ] **Step 6: Create the script skeleton with `run_gitleaks()`**

Create `~/.claude/hooks/commit-gate.sh`:

```bash
#!/bin/bash
# commit-gate.sh — PreToolUse gate.
# No `git commit` proceeds without (a) a clean gitleaks scan and
# (b) a review token matching the exact diff being committed.
set -uo pipefail

LOG_FILE="$HOME/.claude/logs/commit-gate.log"

# Reads a unified diff on stdin. 0 = clean, 1 = leaks found, 3 = unavailable/errored.
run_gitleaks() {
  command -v gitleaks >/dev/null 2>&1 || return 3

  local tmp; tmp="$(mktemp -d)" || return 3
  # Scan added lines only: removed lines are already in history, and context
  # lines would re-flag secrets on every unrelated commit that touches the file.
  grep -E '^\+' | grep -vE '^\+\+\+' | sed 's/^+//' > "$tmp/added-content.txt"

  if [ ! -s "$tmp/added-content.txt" ]; then
    rm -rf "$tmp"; return 0
  fi

  local rc
  if gitleaks dir --help >/dev/null 2>&1; then
    gitleaks dir "$tmp" --no-banner --redact >/dev/null 2>&1; rc=$?
  else
    gitleaks detect --no-git --source "$tmp" --no-banner --redact >/dev/null 2>&1; rc=$?
  fi
  rm -rf "$tmp"

  case "$rc" in
    0) return 0 ;;
    1) return 1 ;;
    *) return 3 ;;
  esac
}
```

- [ ] **Step 7: Add gitleaks tests to the harness**

Insert before the summary lines in `test-commit-gate.sh`:

```bash
# --- run_gitleaks ---
source "$GATE"

clean_diff() { printf '+++ b/a.txt\n+just some ordinary text\n'; }
leak_diff()  { printf '+++ b/a.txt\n+aws_key = "AKIAIOSFODNN7EXAMPLE"\n'; }

clean_diff | run_gitleaks
assert_exit 0 "run_gitleaks: clean diff returns 0" test $? -eq 0

leak_diff | run_gitleaks
assert_exit 0 "run_gitleaks: AWS key returns 1" test $? -eq 1
```

- [ ] **Step 8: Run the tests**

```bash
bash ~/.claude/hooks/test-commit-gate.sh
```

Expected: 0 failed (the pass count grows as tasks are added). If the AWS-key case returns 0, the installed gitleaks ruleset did not match — try a different known-detectable secret (`-----BEGIN RSA PRIVATE KEY-----`) and use that in the test instead.

- [ ] **Step 9: Commit**

```bash
git -C ~/.claude add .gitignore hooks/commit-gate.sh hooks/test-commit-gate.sh
git -C ~/.claude commit -m "feat: commit gate scaffold with gitleaks scanning"
```

---

### Task 2: Detect `git commit` in a command string

**Files:**
- Modify: `~/.claude/hooks/commit-gate.sh`
- Modify: `~/.claude/hooks/test-commit-gate.sh`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: `parse_command <command-string>` — returns `0` if the string invokes `git commit`, `1` otherwise. On return `0` it sets global `GATE_COMMIT_ALL` to `1` when the commit uses `-a`/`--all`, else `0`.

- [ ] **Step 1: Write the failing tests**

Add to `test-commit-gate.sh` before the summary:

```bash
# --- parse_command ---
check_parse() { # $1 = label, $2 = command, $3 = expect match (0/1), $4 = expect ALL
  parse_command "$2"; local rc=$?
  if [ "$rc" -eq "$3" ] && { [ "$rc" -ne 0 ] || [ "$GATE_COMMIT_ALL" -eq "$4" ]; }; then
    printf 'PASS  %s\n' "$1"; PASS=$((PASS+1))
  else
    printf 'FAIL  %s (rc=%s all=%s)\n' "$1" "$rc" "${GATE_COMMIT_ALL:-unset}"; FAIL=$((FAIL+1))
  fi
}

check_parse "plain commit"          'git commit -m "hi"'                 0 0
check_parse "commit with -a"        'git commit -am "hi"'                0 1
check_parse "commit with --all"     'git commit --all -m "hi"'           0 1
check_parse "git -C path commit"    'git -C /tmp/x commit -m "hi"'       0 0
check_parse "chained add + commit"  'git add -A && git commit -m "hi"'   0 0
check_parse "not a commit"          'ls -la'                             1 0
check_parse "git log only"          'git log --oneline -5'               1 0
check_parse "commit inside message" 'git log --grep commit'              1 0
check_parse "message containing -a" 'git commit -m "fix -a flag bug"'    0 0
```

The last two are the ones that catch sloppy regex work: `git log --grep commit` must not match, and a `-a` inside a commit message must not widen the diff target.

- [ ] **Step 2: Run to verify they fail**

```bash
bash ~/.claude/hooks/test-commit-gate.sh
```

Expected: failures with `parse_command: command not found`.

- [ ] **Step 3: Implement `parse_command`**

Append to `commit-gate.sh`:

```bash
# Sets GATE_COMMIT_ALL. Returns 0 if the command invokes `git commit`.
parse_command() {
  local cmd="$1"
  GATE_COMMIT_ALL=0

  local seg
  while IFS= read -r seg; do
    [ -n "$seg" ] || continue
    set -f                      # no globbing when we word-split
    # shellcheck disable=SC2086
    set -- $seg
    set +f

    local saw_git=0 sub="" tok
    local seg_all=0
    while [ $# -gt 0 ]; do
      tok="$1"; shift

      if [ "$saw_git" -eq 0 ]; then
        case "$tok" in
          git|*/git) saw_git=1 ;;
        esac
        continue
      fi

      if [ -z "$sub" ]; then
        # git's own options, before the subcommand
        case "$tok" in
          -C|-c|--git-dir|--work-tree|--namespace|--exec-path) shift || true ;;
          -*) ;;
          *) sub="$tok" ;;
        esac
        continue
      fi

      # after the subcommand: find -a/--all, skipping options that take a value
      case "$tok" in
        -m|--message|-F|--file|--author|--date|-C|--reuse-message|\
        -c|--reedit-message|-S|--gpg-sign|-t|--template|--fixup|--squash)
          shift || true ;;
        --all) seg_all=1 ;;
        --*) ;;
        -*a*) seg_all=1 ;;
      esac
    done

    if [ "$sub" = "commit" ]; then
      GATE_COMMIT_ALL="$seg_all"
      return 0
    fi
  done < <(printf '%s\n' "$cmd" | sed -E 's/(\|\||&&|;|\|)/\n/g')

  return 1
}
```

Two details that matter. `set -f` prevents a token like `*.swift` from expanding against the hook's working directory. Skipping the argument after `-m` is what stops `git commit -m "fix -a flag bug"` from being read as an `-a` commit.

- [ ] **Step 4: Run tests to verify they pass**

```bash
bash ~/.claude/hooks/test-commit-gate.sh
```

Expected: 0 failed (the pass count grows as tasks are added).

- [ ] **Step 5: Commit**

```bash
git -C ~/.claude add hooks/
git -C ~/.claude commit -m "feat: parse git commit invocations from command strings"
```

---

### Task 3: Diff targeting, hashing, and the review token

**Files:**
- Modify: `~/.claude/hooks/commit-gate.sh`
- Modify: `~/.claude/hooks/test-commit-gate.sh`

**Interfaces:**
- Consumes: `GATE_COMMIT_ALL` from Task 2.
- Produces:
  - `target_diff` — writes the review target to stdout; uses `GATE_COMMIT_ALL` to decide between staged-only and staged+unstaged.
  - `write_token` — writes both hashes to the token file.
  - `read_token_field <staged|all>` — echoes that hash, returns `1` if the token file is absent.
  - `token_path` — echoes the absolute token path.

- [ ] **Step 1: Write the failing tests**

Add to `test-commit-gate.sh`:

```bash
# --- token round-trip ---
R="$(make_repo)"
cd "$R" || exit 1

printf 'change one\n' >> file.txt
git add file.txt

GATE_COMMIT_ALL=0
write_token
assert_exit 0 "token file created" test -f "$(token_path)"

t_staged="$(read_token_field staged)"
[ -n "$t_staged" ] && { printf 'PASS  token has staged hash\n'; PASS=$((PASS+1)); } \
                   || { printf 'FAIL  token has staged hash\n'; FAIL=$((FAIL+1)); }

h_now="$(target_diff | shasum -a 256 | cut -d' ' -f1)"
[ "$h_now" = "$t_staged" ] && { printf 'PASS  fresh token matches diff\n'; PASS=$((PASS+1)); } \
                           || { printf 'FAIL  fresh token matches diff\n'; FAIL=$((FAIL+1)); }

# staging more work must invalidate the token
printf 'change two\n' >> file.txt
git add file.txt
h_after="$(target_diff | shasum -a 256 | cut -d' ' -f1)"
[ "$h_after" != "$t_staged" ] && { printf 'PASS  stale token detected\n'; PASS=$((PASS+1)); } \
                              || { printf 'FAIL  stale token detected\n'; FAIL=$((FAIL+1)); }

cd / && rm -rf "$R"
```

- [ ] **Step 2: Run to verify they fail**

```bash
bash ~/.claude/hooks/test-commit-gate.sh
```

Expected: `write_token: command not found`.

- [ ] **Step 3: Implement diff targeting and token I/O**

Append to `commit-gate.sh`:

```bash
hash_stdin() { shasum -a 256 | cut -d' ' -f1; }

staged_diff() { git diff --cached; }
# `git commit -a` also sweeps unstaged changes to tracked files.
all_diff() { git diff --cached; git diff; }

target_diff() {
  if [ "${GATE_COMMIT_ALL:-0}" -eq 1 ]; then all_diff; else staged_diff; fi
}

token_path() { printf '%s/claude-review-ok' "$(git rev-parse --absolute-git-dir)"; }

# Both hashes are written because --approve runs before the commit and cannot
# know whether that commit will use -a.
write_token() {
  local p; p="$(token_path)" || return 1
  {
    printf 'staged=%s\n' "$(staged_diff | hash_stdin)"
    printf 'all=%s\n'    "$(all_diff | hash_stdin)"
  } > "$p"
}

read_token_field() { # $1 = staged | all
  local p; p="$(token_path)" || return 1
  [ -f "$p" ] || return 1
  sed -n "s/^$1=//p" "$p"
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bash ~/.claude/hooks/test-commit-gate.sh
```

Expected: 0 failed (the pass count grows as tasks are added).

- [ ] **Step 5: Commit**

```bash
git -C ~/.claude add hooks/
git -C ~/.claude commit -m "feat: diff targeting and review token round-trip"
```

---

### Task 4: Main flow — block, allow, bypass, log

**Files:**
- Modify: `~/.claude/hooks/commit-gate.sh`
- Modify: `~/.claude/hooks/test-commit-gate.sh`

**Interfaces:**
- Consumes: `parse_command`, `target_diff`, `write_token`, `read_token_field`, `run_gitleaks`.
- Produces: `main "$@"` — the hook entry point. Reads the PreToolUse JSON payload on stdin. Also handles `commit-gate.sh --approve`.

**Important:** the bypass is detected by **string match on the command text**, not by reading the environment. `CLAUDE_COMMIT_GATE=off git commit ...` sets that variable for the *git* process, not for the hook — the hook is a separate child of Claude Code and never sees it. The user-facing syntax is unchanged; only the mechanism differs from a naive reading of the spec.

- [ ] **Step 1: Write the failing end-to-end tests**

Add to `test-commit-gate.sh`:

```bash
# --- end-to-end ---
R2="$(make_repo)"
printf 'new work\n' >> "$R2/file.txt"
git -C "$R2" add file.txt

assert_exit 0 "non-git command passes"        run_gate 'ls -la' "$R2"
assert_exit 2 "commit without token blocked"  run_gate 'git commit -m "x"' "$R2"

( cd "$R2" && bash "$GATE" --approve >/dev/null 2>&1 )
assert_exit 0 "commit with fresh token allowed" run_gate 'git commit -m "x"' "$R2"

printf 'more work\n' >> "$R2/file.txt"
git -C "$R2" add file.txt
assert_exit 2 "stale token blocked"           run_gate 'git commit -m "x"' "$R2"

assert_exit 0 "bypass skips token check"      run_gate 'CLAUDE_COMMIT_GATE=off git commit -m "x"' "$R2"

# a secret beats both the token and the bypass
( cd "$R2" && bash "$GATE" --approve >/dev/null 2>&1 )
printf 'aws_key = "AKIAIOSFODNN7EXAMPLE"\n' >> "$R2/file.txt"
git -C "$R2" add file.txt
( cd "$R2" && bash "$GATE" --approve >/dev/null 2>&1 )
assert_exit 2 "secret blocked despite valid token" run_gate 'git commit -m "x"' "$R2"
assert_exit 2 "secret blocked despite bypass"      run_gate 'CLAUDE_COMMIT_GATE=off git commit -m "x"' "$R2"

cd / && rm -rf "$R2"
```

The last two are the point of the whole design: approving a diff that contains a secret must still fail, and the bypass must not reach the secret gate.

- [ ] **Step 2: Run to verify they fail**

```bash
bash ~/.claude/hooks/test-commit-gate.sh
```

Expected: the end-to-end assertions fail (the script has no `main` yet, so it exits 0 and every "blocked" case returns 0).

- [ ] **Step 3: Implement `main`**

Append to `commit-gate.sh`:

```bash
log_line() {
  mkdir -p "$(dirname "$LOG_FILE")"
  printf '%s  %s  %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(pwd)" "$1" >> "$LOG_FILE"
}

block() { printf '%s\n' "$1" >&2; exit 2; }

main() {
  if [ "${1:-}" = "--approve" ]; then
    git rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repo" >&2; exit 1; }
    write_token
    echo "Review token written for the current diff."
    exit 0
  fi

  local input cmd cwd
  input="$(cat)"
  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
  cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"

  [ -n "$cmd" ] || exit 0
  parse_command "$cmd" || exit 0

  [ -n "$cwd" ] && cd "$cwd" 2>/dev/null
  git rev-parse --git-dir >/dev/null 2>&1 || exit 0

  local diff; diff="$(target_diff)"
  [ -n "$diff" ] || exit 0   # nothing to commit; let git report it

  # --- gate 1: secrets. No override, fails closed. ---
  printf '%s\n' "$diff" | run_gitleaks
  case $? in
    1) log_line "BLOCKED-SECRET  $cmd"
       block "BLOCKED: gitleaks found a secret in this diff.
Run 'gitleaks dir <path> --redact' to see it. Remove the secret and re-stage.
This gate cannot be bypassed." ;;
    3) log_line "BLOCKED-NOGITLEAKS  $cmd"
       block "BLOCKED: gitleaks is unavailable, so the secret scan could not run.
Install it with 'brew install gitleaks'. The gate fails closed by design." ;;
  esac

  # --- gate 2: review token. Bypassable. ---
  if printf '%s' "$cmd" | grep -q 'CLAUDE_COMMIT_GATE=off'; then
    log_line "BYPASS  $cmd"
    exit 0
  fi

  local field expected actual
  if [ "${GATE_COMMIT_ALL:-0}" -eq 1 ]; then field="all"; else field="staged"; fi
  expected="$(read_token_field "$field" 2>/dev/null)"
  actual="$(printf '%s\n' "$diff" | hash_stdin)"

  if [ -z "$expected" ]; then
    block "BLOCKED: this diff has not been reviewed.
Review the staged changes, then run:
  bash ~/.claude/hooks/commit-gate.sh --approve
Do not approve if the review found correctness, security, or data-loss issues."
  fi

  if [ "$expected" != "$actual" ]; then
    block "BLOCKED: the review token is stale — the diff changed since it was approved.
Re-review the current diff, then run:
  bash ~/.claude/hooks/commit-gate.sh --approve"
  fi

  exit 0
}

main "$@"
```

Note `main "$@"` runs on `source` too, which the unit tests in Tasks 1–3 rely on not happening. Guard it in the next step.

- [ ] **Step 4: Guard against running `main` when sourced**

Replace the final `main "$@"` line with:

```bash
# Only run when executed, not when sourced by the test harness.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
```

- [ ] **Step 5: Run the full suite**

```bash
bash ~/.claude/hooks/test-commit-gate.sh
```

Expected: 0 failed (the pass count grows as tasks are added).

- [ ] **Step 6: Commit**

```bash
chmod 755 ~/.claude/hooks/commit-gate.sh
git -C ~/.claude add hooks/
git -C ~/.claude commit -m "feat: commit gate main flow with bypass and logging"
```

---

### Task 5: Register the hook and verify it live

**Files:**
- Modify: `~/.claude/settings.json`

**Interfaces:**
- Consumes: `~/.claude/hooks/commit-gate.sh` from Task 4.
- Produces: an active gate. Nothing depends on this task.

- [ ] **Step 1: Add the hook entry to `~/.claude/settings.json`**

The file currently has `model`, `enabledPlugins`, `effortLevel`, and `theme`. Add a sibling `hooks` key:

```json
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash $HOME/.claude/hooks/commit-gate.sh",
            "timeout": 30
          }
        ]
      }
    ]
  }
```

- [ ] **Step 2: Validate the JSON**

```bash
jq . ~/.claude/settings.json >/dev/null && echo "valid JSON"
```

Expected: `valid JSON`. A malformed settings file breaks hook loading at startup.

- [ ] **Step 3: Restart Claude Code**

Hooks load at session start; edits do not hot-swap. Exit and relaunch.

- [ ] **Step 4: Confirm the hook is registered**

Run `/hooks` in the new session. Expected: the `PreToolUse` / `Bash` entry appears, pointing at `commit-gate.sh`.

- [ ] **Step 5: Live end-to-end check in a throwaway repo**

```bash
D=$(mktemp -d) && git -C "$D" init -q && printf 'x\n' > "$D/a.txt" && git -C "$D" add a.txt
```

Then ask Claude to commit in `$D`. Expected: blocked, with the "has not been reviewed" message. Then approve and retry — expected: the commit succeeds.

Clean up: `rm -rf "$D"`.

- [ ] **Step 6: Verify the fast path did not slow ordinary commands**

```bash
time (echo '{"tool_input":{"command":"ls -la"},"cwd":"/tmp"}' | bash ~/.claude/hooks/commit-gate.sh)
```

Expected: exit 0, well under 100ms. Every Bash call pays this cost, so it has to stay cheap.

- [ ] **Step 7: Commit**

`settings.json` is excluded by `~/.claude/.gitignore` and stays local. Commit only if Task 1's allowlist edit is still uncommitted:

```bash
git -C ~/.claude status --short
```

If clean, nothing to do.

---

## Verification checklist

- [ ] `bash ~/.claude/hooks/test-commit-gate.sh` → all pass
- [ ] `/hooks` shows the PreToolUse Bash entry
- [ ] A commit with no token is blocked
- [ ] After `--approve`, the same commit succeeds
- [ ] Staging more work after approval blocks again
- [ ] A staged AWS-key-shaped string blocks even with a valid token
- [ ] `CLAUDE_COMMIT_GATE=off` bypasses the token check, and the bypass is logged to `~/.claude/logs/commit-gate.log`
- [ ] `CLAUDE_COMMIT_GATE=off` does **not** bypass gitleaks
- [ ] Non-git Bash commands are unaffected and fast

## Out of scope

Per spec: commits via `git revert`, `git merge`, `git rebase --continue`, or made outside Claude Code (terminal, Xcode). graudit scanning. Pushing the `~/.claude` repo to its public remote — that stays the user's call.
