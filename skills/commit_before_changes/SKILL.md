---
name: commit_before_changes
description: >-
  Before implementing a new step from todo.md or before changing any part or
  module, git commit the current state with the current version. The version
  is a pure 14-digit YYYYMMDDhhmmss UTC timestamp (trailing Z).
version: 1.0.20260903181659Z
load: always
---

# commit_before_changes

Every change starts from a committed, versioned baseline. Before you implement
a new step (for example from `todo.md`) or before you change any part or
module of the project, snapshot the current state in git and label it with the
current version. This guarantees that every step and every change can be
reverted to its exact pre-change state.

## Version format

The version is a pure 14-digit timestamp:

```
YYYYMMDDhhmmss
```

- 4-digit year, 2-digit month, 2-digit day, then hour, minute, second.
- No `major.minor` prefix, no separators, no suffix.
- Computed in UTC, marked by a trailing `Z`:

```bash
timestamp
```

Example: `20260903181659Z`

## When to apply

Run this skill **before** any of the following:

1. Implementing a new step from `todo.md` (or, if no `todo.md` exists, a new
   step from `plan.md` or a task given by the user).
2. Changing a part or module of the project: source files, tests, scripts,
   documentation, configuration, or skills.
3. Refactoring, moving, or renaming files.

## Workflow

Before the first change of a step/module, do the following:

1. Determine the current version:

   ```bash
   VERSION=$(timestamp)
   ```

2. Inspect the working tree: `git status` and `git diff`.

3. If there are uncommitted changes, stage and commit them as the
   pre-change snapshot:

   ```bash
   git add -A
   git commit -m "[VERSION=$VERSION] Before <next step or change>"
   ```

   The description names what is about to be implemented or changed so the
   snapshot is easy to find later. Examples:

   ```
   [VERSION=20260903181659Z] Before step b) fix the version output
   [VERSION=20260903181700Z] Before refactoring the replace module
   ```

4. If the working tree is already clean, there is nothing to snapshot: skip
   the commit, take the current version as the baseline, and proceed. Never
   create an empty commit just to stamp a version.

5. Implement the step or make the change. Then continue with the normal
   after-change workflow (per the `version-commit` skill, the changed files
   get their own commits; the file-level versions follow the `shift-version`
   skill).

6. Repeat for every further step or module change: each one is preceded by
   its own snapshot commit with its own current version.

## Rules

1. Commit **before** changing, never after. The snapshot must contain exactly
   the pre-change state.
2. Every pre-change snapshot commit message carries its `VERSION=<YYYYMMDDhhmmss>`.
3. Never batch the pre-change snapshot together with the new changes: the
   snapshot comes first, the implementation is committed afterwards.
4. If the working tree is clean, do not create empty commits.
5. When a change is already in progress and a new part/module needs work, the
   in-progress work is part of the snapshot — commit it first, then continue.
6. If a step cannot be implemented, record the reason (e.g. in `plan.md`)
   before starting the next step.
