# venom-skill

A [Claude Code skill](https://docs.anthropic.com/en/docs/claude-code/skills) that enforces consistent conventions when creating or editing [Venom](https://github.com/ovh/venom) test suites (`.venom.yml` files).

---

> 🤖 LLM/AI WARNING 🤖
>
> This project was largely written by [Claude](https://claude.ai/).
> It has been reviewed and tested, but use in production at your own discretion.
>
> 🤖 LLM/AI WARNING 🤖

---

## What it does

When loaded, the skill ensures every Venom test suite Claude generates follows a strict set of conventions:

- Files use `.venom.yml` suffix
- Every suite has `name:` and `vars:` at top level
- Every test case has `name:` and `steps:`
- Every exec step has `assertions:`
- Suite-level vars for paths — no hardcoded absolute paths
- User executors in `lib/` with proper `executor:`, `input:`, `steps:` structure
- Avoids known Venom limitations (range variable interpolation)
- Includes a complete executor and assertion reference

The skill includes a lint script (`lint.sh`) that validates all deterministic rules. The LLM runs it after generating files and fixes any failures before finishing.

## Prerequisites

- [Task](https://taskfile.dev) — task runner
- [Venom](https://github.com/ovh/venom) — required to run tests
- [Claude CLI](https://docs.anthropic.com/en/docs/claude-code) — required for LLM evals only

## Install

```bash
task install
```

This creates a symlink at `~/.claude/skills/venom` pointing to `.claude/skills/venom/` in this repo, making the skill available globally to Claude Code.

## Project structure

```
.claude/skills/venom/SKILL.md  # The skill prompt
.claude/skills/venom/lint.sh   # Structural lint
Taskfile.yml                    # Thin orchestrator
.taskfiles/dev.yml              # Dev module (test, lint)
.taskfiles/eval.yml             # Eval module (requires Claude CLI)
scripts/install.sh              # Skill installer
tests/ci.venom.yml              # CI test suite (Venom, self-dogfooding)
tests/fixtures/                 # Good and bad .venom.yml fixtures
evals/evals.venom.yml           # LLM eval suite (Venom)
evals/evals.json                # Eval cases
.github/workflows/ci.yml        # GitHub Actions CI pipeline
```

## Testing

```bash
task test    # Run CI-safe tests
task lint    # Run lint only
task check   # Run all quality gates (lint + test)
task clean   # Remove .test-output/ artifacts
```

Tests use [Venom](https://github.com/ovh/venom) as the test runner (self-dogfooding).

The CI test suite (`tests/ci.venom.yml`) validates:

- **Self-lint** — the project's own test files pass the lint script
- **Good fixtures** — known-correct `.venom.yml` files pass all lint checks
- **Bad fixtures** — failure scenarios (wrong suffix, missing name/vars, no assertions, range bug, hardcoded paths, broken executor) are correctly detected

## LLM evals

LLM evals require the Claude CLI and are not part of CI.

```bash
task eval:test       # Run all LLM evals
task eval:run -- 2   # Run a single eval by ID (one ID at a time)
task eval:list       # List eval cases
```

Eval results go to `.test-output/`.

## License

MIT
