# Collaboration

## Ticket comments

`/sdd-work` reads work-item and parent-story comments on entry, then during implementation prompts opt-in (`yes` / `edit` / `skip`) to post one of five named shapes:

| Shape | When |
|-------|------|
| Decision | Implementation diverges from `design.md` or the ticket body. |
| Blocker | External dependency surfaced (API not ready, missing infra). |
| Follow-up | Known future work left as a placeholder. |
| Clarification | Outstanding question got answered. |
| Closing summary | End-of-implementation overview before `/sdd-verify`. |

Blockers and Follow-ups also offer to create a tracked follow-up ticket via `CreateRelatedTicket` (`is_blocked_by` in Jira, emulated `Blocked by #N` body footer in GitHub).

Detail: [`templates/ticket-comment-shapes.md`](../templates/ticket-comment-shapes.md), [`templates/work-discovery-comments.md`](../templates/work-discovery-comments.md), [`templates/story-comment-triage.md`](../templates/story-comment-triage.md).

## Parallel developers on one change

`tasks.md` is a derived view, not a control surface — ticket status is the single source of truth. `/sdd-work` does not write checkbox state during implementation (granular per-edit writes caused conflicts). Instead, `/sdd-verify` checks off **only the current ticket's own section** just before opening the PR, so the flip ships inside the feature PR rather than as a separate post-merge commit. Because each work item touches only its own section, parallel work on the same change stays conflict-free. `/sdd-status`'s Completion Sweep (Class C) then reconciles any residual drift from ticket statuses (idempotent — usually a no-op).

| Team size | Behaviour |
|-----------|-----------|
| 1 dev | Run `/sdd-work` and `/sdd-verify`; `/sdd-status` periodically. |
| 2-N devs, different work items | Parallel work, no shared writes during implementation. |
| 2 devs, same work item | Code-level git conflicts still on you. SDD assumes one dev per ticket per branch. |

## Re-running planning skills

The four ticket-creating skills detect existing state in Phase 0.5 and prompt **Continue** (default — skip what exists, fill gaps) / **Regenerate** (per-file diff before overwrite) / **Abort**. Re-running after editing a PRD or story is safe; you have to explicitly opt into Regenerate to overwrite anything.
