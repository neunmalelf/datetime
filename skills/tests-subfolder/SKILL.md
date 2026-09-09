---
name: tests-subfolder
version: 1.0.20260813095115Z
description: >
  Guarantees that all new test scripts for this project live in the tests/
  subfolder. Use whenever you create, move, or update a test suite in
  1_my_scripts/.bashrc.d.
---

# Tests-subfolder skill

## Rule

All test scripts for this project MUST live in the `tests/` subfolder of the
project root (`B:/work/1_my_scripts/.bashrc.d/tests/`). Never place a test
script in the project root.

## When to apply

- When you write a new test suite.
- When you move or rename an existing test suite.
- When you update an existing test suite.

## Conventions for test scripts in tests/

1. Name the suite `_test_<subject>.sh` style, i.e. `tests/_test_<name>`
   (no `.sh` extension, matching the existing suites).
2. Give it a `__VERSION__` in the standard `Major.Minor.YYYYMMDDhhmmss`
   format, bumped on every change (see the shift-version skill).
3. Resolve the project root from the suite's own location so the suite works
   from any cwd:

   ```bash
   REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
   ```

   Reference scripts and sources as `"$REPO_DIR/_some_script"` and
   `"$REPO_DIR/___dd_colors"`.
4. Follow the pass/fail counting pattern of the existing suites
   (`check`/`assert_contains` helpers, exit 0 when all tests pass,
   exit 1 otherwise).
5. Run your suite from the project root like the others:
   `cd tests && ./_test_<name>`.

## Version validation

`_check_version` automatically validates `tests/_*` as well as `_*` and
`skills/*/SKILL.md`. After creating or editing a suite, run
`./_check_version` from the project root and make sure it reports the suite
as `[OK]` with 0 errors before committing.

## Commit convention

Commit each test-suite file separately with the version-commit convention:

```
[tests/_test_<name>] VERSION=<version> <short description>
```

## Verification checklist

- [ ] Suite lives in `tests/`.
- [ ] `__VERSION__` present and in `Major.Minor.YYYYMMDDhhmmss` format.
- [ ] `REPO_DIR` resolves via `dirname "${BASH_SOURCE[0]}")/..`.
- [ ] `./_check_version` reports the suite as `[OK]`, 0 errors.
- [ ] Suite runs green from the project root.
