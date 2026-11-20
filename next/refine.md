# Refine…: talking a note's text over with a writer

## Status

**Built, not yet tried by the author.** Refine… stands in the window a text is written in - the Body card's editor (beside
Done) and the Direction card's box - and opens a chat window beside it (`TextRefine`, `src/ui/text_refine.gd`), the way the
3D view's Refine… opens on a prop. The writer row (agent, model, effort: `AgentPick`) is in that window, not on the card; the
Direction card lost its row and its "Prompt" heading, so the two cards read alike.

- **A conversation, kept** (`WriterChat`, `src/agents/writer_chat.gd`): turn after turn, scrolled back through, kept in the note's
  folder (`<note folder>/refine/body/chat.json`, `.../direction/`; each turn's run in `turns/<id>/`), so it moves with the note and
  is there when the note opens again. New conversation (pressed twice) starts over.
- **The CLI's own session carries it**: Claude (`--session-id`, then `--resume`), Codex (`exec resume <thread>`) and Grok (`-s`,
  then `--resume`) each keep their session across turns (`TextGen` jobs' `session` and `cwd`), so earlier turns are read from the
  provider's prompt cache and only the new turn is sent. Each turn shows what it cost and how much came from the cache. A turn
  that cannot resume (another agent picked mid-way, Bedrock, a session the CLI no longer finds) starts a new session told the
  conversation so far.
- **The writer edits with tools** (`TextTools`, served by `AgentTools`): `read`, `edit` (a part copied exactly, refused when absent
  or ambiguous), `write`, and for the Direction `read_note`. Each change lands at once in the editor as one step Ctrl+Z takes
  back, and shows in the chat as the lines taken out (struck) and put in. What the writer says between calls shows as it comes.
  Bedrock, with no tools, answers with the text between `<text>` tags.
- **It knows what it works on** (rules/agents/refine.yaml): what the text is for (a script read aloud, a show's brief, or a
  Direction), the note's title, what the note is made of (each component's blurb) and every mark the Body's palette offers in
  that mode, with its sample and what it does (`ScriptMarks`). A hand's edit between turns is told as the lines that changed.
- **It survives the panel**: a note opened again (a card attached, a format picked) hands the live conversation to the new card,
  turn under way and all; leaving the note stops a turn a moment later.
- **Gates**: `tests/agents/writer_chat_check.gd` (tools, prompts, landing, the session flags), `tests/ui/text_refine_check.gd`
  (the window, a change landing, the Body's editor), `tests/ui/direction_card_check.gd` (the card).

**Open - for the author to judge:**

- How much progress to show. Now: the writer's words between calls, each change as a diff, the status line (thinking, calling
  edit, tokens, time) and the cost. Thinking itself is not shown, nor tool calls other than changes (a `read` is silent).
- Whether the chat should be docked inside the editor instead of a window beside it.
- Whether an old conversation should be summarized and trimmed when it grows long, rather than New conversation by hand.
- The Body's frontmatter fields (Title, Episode) are not the writer's to change.

## Why

Editing a script is a back and forth. A writer run with no session sends the whole conversation and the text again every turn,
uncached; a session resumed is read from the prompt cache. Resuming by id was chosen over one process kept open per
conversation: the cache is the provider's either way (keyed by the prompt's prefix, not by the process), a resumed session
survives closing the app, and it needs no pipe held open to a CLI.
