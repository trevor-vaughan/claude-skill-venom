---
name: venom
description: Conventions, patterns, and reference for creating, editing, or extending Venom test suites (.venom.yml files) and user-defined executors (https://github.com/ovh/venom). ALWAYS use this skill when the user mentions Venom, venom test, .venom.yml, integration tests with Venom, or asks to write tests using Venom. Also trigger when converting other test formats to Venom, adding test cases or executors to existing suites, or when the user says "venom" in the context of testing. This includes casual requests like "write venom tests", "add a test case", "create a user executor", or "test this API with venom". If the request involves Venom in any way, use this skill.
---

# Venom Skill

## COMMON MISTAKES — do NOT do these

These are patterns the model often generates incorrectly. Check your output against this list.

| WRONG | RIGHT |
|-------|-------|
| `test.yml` or `test_venom.yml` | `test.venom.yml` — always use `.venom.yml` suffix |
| `range` with `{{.value}}` in `script:` blocks | User-defined executors for parameterized tests (range vars don't interpolate in scripts in v1.3) |
| Exec step without `assertions:` | Every step asserts on at least `result.code ShouldEqual 0` |
| `script: some-cmd; true` or `script: some-cmd \|\| true` | Removes all signal from the exit code — assertions on `result.code` become meaningless. Fix the root cause or restructure the test instead |
| Stub/placeholder test with only `result.code ShouldEqual 0` | A test that passes without checking anything meaningful is worse than no test — it creates false confidence. Write a real assertion, or make the stub fail explicitly with `exit 1` so it stays visible |
| Hardcoded paths in scripts (`/home/user/...`) | Suite-level `vars:` with overridable defaults, reference as `{{.root}}` |
| `grep` in script to check output | `result.systemout ShouldContainSubstring "expected"` |
| Inline multiline test logic (>5 lines in script) | Extract to user executor in `lib/` |
| Test suite without `name:` | Every suite starts with `name:` |
| Test suite without `vars:` | Every suite has a `vars:` block (even if just `root: "."`) |
| `result.body` for exec stdout | `result.systemout` for exec, `result.body` for http |
| `ShouldMatch` for substring check | `ShouldContainSubstring` for substrings, `ShouldMatchRegex` for regex |
| `{{ .var }}` with spaces in braces | `{{.var}}` — no whitespace inside braces (Go template) |
| `venom run suite.yml` without `--lib-dir` when using user executors | `venom run suite.yml --lib-dir path/to/lib` — Venom resolves `lib/` from the **working directory**, not the suite file's directory |
| Passing `--var` derived from other vars (e.g. `evals_json: "{{.root}}/evals/evals.json"`) and expecting CLI `--var root=` to be used | Venom evaluates `vars:` block template expressions using the **default** value of referenced vars, not CLI-overridden values. Pass all path vars as fully-resolved absolute values directly from the Taskfile (e.g. `--var evals_json="{{.EVALS_DIR}}/evals.json"`) |
| Relative paths used after a `cd` in an exec script | Exec steps start with CWD = the `venom run` invocation dir, but any `cd` mid-script changes CWD for everything after it — including command substitutions like `$(cat relative/path)`. Always use **absolute paths** for files accessed after a `cd`, or capture them into variables before the `cd` |
| `skip:` with literal strings like `"yes ShouldEqual yes"` or `"{{.var}} ShouldEqual val"` | The first operand in `skip:` assertions is a **variable name** (key lookup), NOT a literal or template expression. Use bare var names: `"my_var ShouldEqual expected_value"`. The skip defines a precondition — if the assertion fails (var doesn't match), the test is SKIPPED |

## MANDATORY RULES — apply to EVERY file you create or edit

1. Test suite files MUST use `.venom.yml` suffix.
2. Every suite MUST have `name:` as the first field.
3. Every suite MUST have a `vars:` block. At minimum include `root: "."` for path references.
4. Every test case MUST have `name:` and `steps:`.
5. Every exec step MUST have `assertions:`. At minimum: `result.code ShouldEqual 0`.
6. Use suite-level vars for all paths and configuration. Never hardcode absolute paths.
7. User-defined executors go in `lib/` directory and MUST have `executor:`, `input:`, and `steps:` fields.
8. Do NOT use `range` with `{{.value}}` in `script:` blocks — values don't interpolate in Venom v1.3. Use user executors or explicit test cases instead.
9. Pass project root as `--var root=<path>` when running suites. Reference as `{{.root}}` in scripts.
10. For multi-step scripts (>5 lines), extract to a user-defined executor in `lib/`.
11. **Never write a test that passes without checking something meaningful.** A test asserting only `result.code ShouldEqual 0` on a trivial command is a false green. If you cannot implement a proper test yet, write an explicit stub that fails:
    ```yaml
    - name: "TODO: verify output format"
      steps:
        - type: exec
          script: |
            echo "TODO: not yet implemented"
            exit 1
          assertions:
            - result.code ShouldEqual 0  # fails until implemented
    ```
    This keeps stubs visible as failures in CI rather than silent passes.

## COMMON PATTERNS — templates for frequent test types

### Basic exec test

```yaml
name: CLI integration tests
vars:
  root: "."
  binary: "{{.root}}/bin/myapp"

testcases:
  - name: Version flag prints version
    steps:
      - type: exec
        script: "{{.binary}} --version"
        assertions:
          - result.code ShouldEqual 0
          - result.systemout ShouldContainSubstring "v1."
```

### HTTP endpoint test

```yaml
name: API integration tests
vars:
  root: "."
  api_url: "http://localhost:8080"

testcases:
  - name: Health check returns 200
    steps:
      - type: http
        url: "{{.api_url}}/health"
        method: GET
        assertions:
          - result.statuscode ShouldEqual 200
          - result.bodyjson.status ShouldEqual "ok"

  - name: Create resource returns 201
    steps:
      - type: http
        url: "{{.api_url}}/items"
        method: POST
        headers:
          Content-Type: application/json
        body: '{"name": "test-item"}'
        assertions:
          - result.statuscode ShouldEqual 201
          - result.bodyjson.name ShouldEqual "test-item"
        vars:
          item_id:
            from: result.bodyjson.id
      - type: http
        url: "{{.api_url}}/items/{{.item_id}}"
        method: GET
        assertions:
          - result.statuscode ShouldEqual 200
```

### File content validation

```yaml
  - name: Config file has required fields
    steps:
      - type: readfile
        path: "{{.root}}/config.yml"
        assertions:
          - result.content ShouldContainSubstring "database:"
          - result.content ShouldContainSubstring "port:"
```

### User-defined executor

Executor file at `lib/check-service.yml`:

```yaml
executor: check-service
input:
  url: ""
  expected_status: "200"

steps:
  - type: http
    url: "{{.input.url}}/health"
    assertions:
      - result.statuscode ShouldEqual {{.input.expected_status}}
    vars:
      status:
        from: result.statuscode

output:
  status: "{{.status}}"
```

Called from a test suite:

```yaml
  - name: Service is healthy
    steps:
      - type: check-service
        url: "http://localhost:8080"
        expected_status: "200"
        assertions:
          - result.status ShouldEqual "200"
```

### Variable passing between steps

```yaml
  - name: Create then verify resource
    steps:
      - type: exec
        script: echo '{"id": 42, "name": "test"}'
        assertions:
          - result.code ShouldEqual 0
        vars:
          resource_id:
            from: result.systemoutjson.id
      - type: exec
        script: echo "Got resource {{.resource_id}}"
        assertions:
          - result.code ShouldEqual 0
          - result.systemout ShouldContainSubstring "42"
```

### Negative test (expected failure)

```yaml
  - name: Invalid input returns error
    steps:
      - type: exec
        script: "{{.binary}} --invalid-flag"
        assertions:
          - result.code ShouldNotEqual 0
          - result.systemerr ShouldContainSubstring "unknown flag"
```

### Conditional skip (environment-dependent test)

The `skip:` field uses assertions where the **first operand is a variable name** (key lookup, NOT a literal or template expression). The assertion defines a precondition — if it fails, the test is skipped.

```yaml
name: My test suite
vars:
  root: "."
  in_container: "no"  # override with --var in_container=yes

testcases:
  - name: "Feature only available in container [container-only]"
    skip:
      - "in_container ShouldEqual yes"
    steps:
      - type: exec
        script: "{{.root}}/bin/container-feature --check"
        assertions:
          - result.code ShouldEqual 0
```

**Key points:**
- First operand is a bare var name: `"my_var ShouldEqual value"` — NOT `"{{.my_var}} ShouldEqual value"`
- Skip triggers when the assertion FAILS (precondition not met)
- `"in_container ShouldEqual yes"` means "requires in_container=yes; skip otherwise"

## EXECUTOR REFERENCE

### exec (default)

Runs shell commands. Standard result fields: `result.code`, `result.systemout`, `result.systemerr`.

Non-obvious: `result.systemoutjson` / `result.systemerrjson` — stdout/stderr auto-parsed as JSON when output is valid JSON.

### http

Makes HTTP requests. Required input: `url`. Standard inputs: `method`, `headers`, `body`, `bodyFile`, `basic_auth_user`/`basic_auth_password`, `ignore_verify_ssl`, `timeout`.

Result fields: `result.statuscode`, `result.body`, `result.bodyjson`, `result.headers`.

**JSON access gotchas:**
- Keys are auto-lowercased: `result.bodyjson.mykey`
- Array elements use indexed naming: `result.bodyjson.items.items0.name` (first), `result.bodyjson.items.items1.name` (second)

### readfile

Input: `path` (supports glob). Result fields: `result.content`, `result.contentjson`.

Non-obvious: `result.size.<filename>` and `result.md5sum.<filename>` — `<filename>` is the base filename of the matched file, not a literal.

### User-defined executors

Place in `lib/` directory alongside the test suite. Venom resolves `lib/` relative to the **working directory where `venom run` is invoked**, not the suite file's location. Always pass `--lib-dir <suite-dir>/lib` in run commands (Taskfiles, CI scripts, etc.) to ensure executors are found regardless of the caller's working directory.

```yaml
executor: my-executor
input:
  param1: ""
  param2: "default-value"

steps:
  - type: exec
    script: echo "{{.input.param1}}"
    assertions:
      - result.code ShouldEqual 0
    vars:
      captured:
        from: result.systemout

output:
  result: "{{.captured}}"
```

- Reference inputs as `{{.input.paramName}}`
- Vars captured in steps are available in later steps and in `output:`
- Output vars are accessible by the calling test case in `result.<key>`

### Other built-in executor types

`sql`, `dbfixtures`, `redis`, `kafka`, `rabbitmq`, `amqp`, `mqtt`, `smtp`, `imap`, `ssh`, `grpc`, `web`, `ovhapi` — refer to Venom docs for input fields.

## ASSERTION REFERENCE

### Less-obvious assertion keywords

Standard comparisons (`ShouldEqual`, `ShouldNotEqual`, numeric comparisons, `ShouldBeNil`, etc.) work as expected. Less obvious ones:

| Assertion | Description |
|-----------|-------------|
| `ShouldAlmostEqual` | Approximate numeric equality |
| `ShouldContainKey` | Map contains key |
| `ShouldContainSubstring` / `ShouldNotContainSubstring` | String substring check |
| `ShouldStartWith` / `ShouldEndWith` | String prefix/suffix |
| `ShouldMatchRegex` | Regex match |
| `ShouldHaveLength` | Collection/string length |
| `ShouldEqualTrimSpace` | Equal after trimming whitespace |
| `ShouldJSONEqual` | JSON structural equality |
| `ShouldJSONContain` | JSON contains subset |
| `ShouldJSONContainWithKey` | JSON has key with value |
| `ShouldNotExist` | Value does not exist |

### Must variants

Every assertion has a `Must` prefix variant (e.g., `MustShouldEqual`). If a `Must` assertion fails, remaining steps in the test case are skipped. Use `Must` for precondition checks where continuing is pointless.

### Logical operators

```yaml
assertions:
  - or:
    - result.statuscode ShouldEqual 200
    - result.statuscode ShouldEqual 201
  - and:
    - result.bodyjson.status ShouldEqual "ok"
    - result.bodyjson.data ShouldNotBeNil
```

## VARIABLE SYSTEM

### Declaration scopes

- **Suite-level:** `vars:` block at top of file — available to all test cases
- **Step-level extraction:** `vars:` block inside a step — captured from results
- **CLI override:** `--var key=value` (highest priority)
- **File override:** `--var-from-file vars.yaml`
- **Environment:** `VENOM_VAR_key=value` (lowest priority)

### Variable extraction with regex

```yaml
vars:
  token:
    from: result.systemout
    regex: "token=([a-zA-Z0-9]+)"
    default: "none"
```

### Built-in variables

- `{{.venom.testsuite}}` — suite name
- `{{.venom.testcase}}` — current test case name
- `{{.venom.timestamp}}` — Unix timestamp
- `{{.venom.datetime}}` — formatted datetime

## Automated lint — run AFTER every file you create or edit

A lint script validates all deterministic structural rules. Run it after creating or editing any `.venom.yml` or `lib/*.yml` file, and fix every failure before finishing:

```bash
bash .claude/skills/venom/lint.sh <directory>
```

The script checks: `.venom.yml` suffix, `name:` field, `vars:` block, `name:` on test cases, `steps:` on test cases, `assertions:` on exec steps, no `range`/`{{.value}}` in scripts, no hardcoded paths, and user executor required fields. Any `FAIL` output is a bug — fix it and re-run until all checks pass.

If the lint script is not available at `.claude/skills/venom/lint.sh`, check `~/.claude/skills/venom/lint.sh`.

## Manual checklist — judgment calls the linter cannot make

After the lint passes, verify these by inspection:

- [ ] Test cases cover both positive and negative scenarios
- [ ] Assertions check meaningful values, not just exit codes — a test that only asserts `result.code ShouldEqual 0` on a trivial command is a false green
- [ ] No stub tests that silently pass — any unimplemented test must fail explicitly (via `exit 1`) until it is properly written
- [ ] Variables used for all configurable values (URLs, paths, credentials)
- [ ] User executors used for repeated multi-step patterns
- [ ] Step results captured in vars when needed by subsequent steps
- [ ] Timeouts set appropriately for long-running steps
- [ ] Secrets declared in `secrets:` block if sensitive vars are used
