# Contributors

## Humans

| | Role |
|---|---|
| **[@pistolinkr](https://github.com/pistolinkr)** (Pistol™) | Owner. Sets direction, reviews and merges every pull request. No agent may merge to `main`. |

## AI agents

From v3.0.0 onward, biolabs is developed by an AI engineering organization that runs
unattended on the owner's machine. Agents open pull requests; a human merges them.

Agent-authored commits carry a `Co-authored-by` trailer naming the model that did the work.
These trailers do **not** appear in GitHub's Contributors sidebar, because the addresses are
not bound to GitHub accounts. That is intentional — we do not commit under accounts we do not
own. The trailers exist so `git log` tells the truth about who wrote what.

| Agent | Job title | Branches | Trailer | Work |
|---|---|---|---|---|
| Claude (Anthropic) | Alpha | `claude/v3.0.X` | `Co-authored-by: Claude <noreply@anthropic.com>` | Daily bug scan, code review, security review and forward-looking research; writes the work order Cursor executes |
| Cursor Agent | — | `cursor/v3.0.X` | `Co-authored-by: Cursor <cursoragent@cursor.com>` | Implements the work orders Alpha hands off |

Branch numbering is a single sequence shared by both agents: `scripts/next-branch.sh` counts
`claude/*` and `cursor/*` together and returns max + 1, so no two agents ever claim the same
number. The owner's own branches (`obserser/v3.0.X`) are outside that sequence and no agent
writes to them.

Alpha runs on a fixed daily cycle (`.github/workflows/alpha-daily.yml`): it scans at 08:00 KST,
commits a work order to a `claude/v3.0.X` branch, re-checks it at 14:00 KST and posts it to the
owner's Slack `#request` channel, where Cursor picks it up. Alpha does not implement what it
files, except for P0 security issues and one-line typos — separating who finds a problem from
who fixes it is the point.

### How the organization works

```
Engineering Lead (orchestrator session)
├── technical-investigator   root cause analysis, resolution planning
├── security-reviewer        conditional; can BLOCK a change outright
├── product-engineer         implements approved plans only
├── evaluation-engineer      independent verification (the implementer cannot pass its own work)
└── recovery-engineer        recovers stalled workflows
```

Definitions live in `.claude/agents/`, workflows in `.claude/skills/`, and configuration
(investigation depth, role routing, timeouts, retry policy, model routing) in
`company/config/engineering-org.yaml`, which is kept outside the repository.

### Boundaries agents operate under

Enforced by `CLAUDE.md` and by a deterministic `PreToolUse` hook, not by prompt alone:

- No direct commits or pushes to `main`
- No force push, no history rewrite, no branch or tag deletion
- No secrets in commits, logs, pull requests or reports
- No dependency major upgrades, no lockfile regeneration
- No database migrations, no production deploys
- Maximum 2 pull requests per role per day — output that cannot be reviewed is not produced

An agent that needs any of the above stops and requests owner approval instead.

### Attribution honesty

An agent's self-report is not evidence. Every claim an agent makes about its own work
(tests passing, scope respected, plan followed) is re-verified by a separate agent that
has no write access, and the day's output is checked against `git log` and the pull
request list before it is reported to the owner.
