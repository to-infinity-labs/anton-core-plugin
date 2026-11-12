---
name: relate
description: Links two saved memories by id — supersedes, resolves, part of, relates to — or suppresses a wrong link. Use for 'record that one note supersedes another', 'link these two notes', 'this resolves that' or 'that link is wrong'.
allowed-tools: Bash
---

## What it does

`item relate` writes one operator edge between existing memory items; `item unrelate` suppresses one. An operator edge outranks any the pipeline infers for the same pair, and a suppression stops the pipeline inferring that pair again.

## When to use

- "record that <id> supersedes <id>", "this replaces that"
- "link these two", "this resolves that error", "this is part of that project"
- "that link is wrong", "unlink these"

## How

Run the command that fits with Bash, then answer from what it prints. Never answer before it has run: what the store holds is unknown until it does.

```
anton item relate   --from <id> --to <id>[,<id>…] --type <type>
anton item unrelate --from <id> --to <id>[,<id>…] --type <type>
```

`--type` is one of these, read from `--from` to `--to`:

| Type | Meaning |
|---|---|
| `relates_to` | a loose association |
| `supersedes` | `--from` replaces or corrects `--to` (newer → older) |
| `part_of` | `--from` is a component of `--to` |
| `resolves` | `--from` answers or closes `--to` |

`updates` is read as `supersedes`; case and separators are ignored. Any other type, including the pipeline's own and the code graph's (`CALLS` …), is refused. Assert one direction only: traversal reads an edge both ways. A later `relate` of a suppressed pair restores it.

## Output

`rel_type` is the canonical type written; `noop` lists the targets already in that state, which wrote nothing. A missing id, a self-edge or a repeated target rejects the whole call and writes nothing. Suppressed edges are hidden from recall and `explore`, and shown, marked, by `item get --include-relationships`.

Contract: `item-relate`, `item-unrelate` in the anton-core CLI contract.
