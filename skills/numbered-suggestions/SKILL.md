---
name: numbered-suggestions
description: Always number followup suggestions with a numeric prefix for easy reference
version: 1.0.20260602114105Z
load: always
---

# numbered-suggestions

When using `suggest_followups`, always prefix each suggestion label with a number like `1.`, `2.`, `3.` so the user can easily reference them by number.

## When to use

Always. This skill is active for all conversations.

## Instructions

1. When calling `suggest_followups`, number the suggestions sequentially starting from 1: `1.`, `2.`, `3.`, etc.
2. Put the number in the `label` field only — this is what the user sees on the clickable card (e.g., `"label": "1. Add tests"`). Do **not** include the number in the `prompt` field, since that text gets sent as a user message.
3. Use the format: `N. Short description` for each label.
4. Example:
   ```json
   {
     "label": "1. Add unit tests",
     "prompt": "Add unit tests for the new feature"
   }
   ```