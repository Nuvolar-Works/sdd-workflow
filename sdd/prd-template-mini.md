# Mini PRD

For follow-on increments (v2, v2-1) and change requests. Use this when the work builds on an existing feature and most of the product context is already captured in a prior PRD version or in `openspec/specs/`.

**Feature:** <feature name> — <increment slug, e.g. v2-overtime-rules>
**Builds on:** <link to prior PRD version or OpenSpec change>
**Product Owner:** <Name>
**Created:** <YYYY-MM-DD>
**Status:** Draft

---

## Problem Statement

<!-- One paragraph. What changed since the last version? What new pain are we solving? -->

## Goals

<!-- ≤5 bullets. Specific to this increment, not the overall product. -->

- Goal 1
- Goal 2

## User Stories

<!-- Often just one story for an increment. Same shape as the full template. -->

### Story: <short title>

**As a** <role>
**I want** <capability>
**So that** <benefit>

**Acceptance Criteria:**
- [ ] <criterion>
- [ ] <criterion>

## Dependencies

<!-- What v1 specs / OpenSpec changes / running systems does this build on? -->

- <dependency>

## API Contract (optional)

<!-- Usually a delta from the existing contract — list the new or changed endpoints only. -->

**Changed/new endpoints:**
- `POST /api/v2/...` — <one-line description>
