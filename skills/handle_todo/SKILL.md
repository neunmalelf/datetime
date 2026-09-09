---
name: handle_todo
description: Reads todo.md in the project directory, analyzes the tasks, writes a plan.md, then implements and tests each task one by one, removing completed items from todo.md until it is empty
version: 1.0.20260813094627Z
load: always
---

# handle_todo

Processes the task list in `todo.md`. The agent reads the tasks, writes an implementation plan to `plan.md`, then works through the tasks one at a time. A task is removed from `todo.md` only after it is implemented and tested successfully. The process ends when `todo.md` is empty.

## Files

- `todo.md` — the task list in the project directory. It is the source of truth.
- `plan.md` — the implementation plan. Created at the start and updated as tasks are completed.

## Workflow

1. Read `todo.md` from the project directory (the current working directory).
   - If `todo.md` does not exist, report that there are no tasks and stop.
   - If `todo.md` is empty, report that all tasks are done and stop.

2. Parse the task list. Items can use any list format: `a)`, `b)`, `-`, `*`, or `1.`.

3. Create `plan.md`. Analyze each task and write:
   - the goal of the task
   - the steps needed to implement it
   - the tests needed to verify it
   - the order in which the tasks will be handled

4. Process the tasks one at a time, in list order:
   - Take the first unfinished task.
   - Implement it.
   - Test it.
   - If the tests pass, remove that item from `todo.md` and mark the task as done in `plan.md`.
   - If the tests fail, do not remove the item. Fix the problem and test again. If the task cannot be completed, leave it in `todo.md`, add a note with the reason to `plan.md`, and continue with the next task.

5. Repeat step 4 until `todo.md` contains no unfinished items.

6. Report the result when all tasks are done.

## Rules

1. Remove a task from `todo.md` only after it is implemented AND tested successfully.
2. Never remove a task that is not complete.
3. Preserve the remaining items in `todo.md` when you remove a completed one.
4. Keep `plan.md` up to date. Mark each task as done when you finish it.
5. If a task is blocked or cannot be done, record the reason in `plan.md` and continue with the next task.
6. If a task is ambiguous, ask the user before you implement it.
7. Follow the other active project conventions (version tracking, per-file commits, test suites) while you implement a task.

## Example

`todo.md`:

```
a) add a --json flag to _count_files
b) fix the version output
```

`plan.md`:

```
# Plan

## Task a) add a --json flag to _count_files
- Steps: parse the flag, build the JSON output, update the usage text.
- Test: run with and without the flag, check the output.
- Status: done

## Task b) fix the version output
- Steps: find the version line, correct the format.
- Test: run -v and check the output.
- Status: pending
```

After task a) is implemented and tested, `todo.md` contains only item b).

## Instructions

1. Run this skill whenever the user asks to process `todo.md` or when a task list needs to be worked through.
2. Look for `todo.md` in the project directory first.
3. Do not modify `todo.md` or `plan.md` unless this skill says so.
