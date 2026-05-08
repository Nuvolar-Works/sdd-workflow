<!--
==============================================================================
SYNC IMPACT REPORT
==============================================================================
Version change: 0.0.0 → 1.0.0 (initial ratification)

Modified principles: N/A
Added sections: Core Principles (I–X), Technology Stack, Folder Structure,
                 Specification & Planning Standards, Development Workflow,
                 Quality Gates, Governance
Removed sections: N/A

Follow-up TODOs: None
==============================================================================
-->

# HR Tool Constitution

## Core Principles

### I. Functional Components Only (NON-NEGOTIABLE)

All React components MUST be functional components. No class components.

- Props MUST be typed with a named `{ComponentName}Props` interface, exported from the component file.
- Components exceeding ~150 lines MUST be broken into sub-components or extracted hooks.
- Component-specific types MUST be co-located in the component file.
- Named exports preferred over default exports (except Next.js `page.tsx` / `layout.tsx` files).

**Rationale**: Functional components with hooks are the standard React pattern. Consistent prop naming and size limits keep components readable and maintainable across a 2-person team.

### II. TypeScript Strictness (NON-NEGOTIABLE)

All code MUST adhere to TypeScript strict mode with zero tolerance for `any` types:

- All API responses MUST be typed with explicit interfaces.
- All component props MUST use `{ComponentName}Props` interfaces.
- All function parameters and return types MUST be explicitly typed.
- Use `interface` for object shapes; `type` for unions and computed types.
- No magic strings — use enums or constant objects (e.g., `UserRole`, `LeaveType`).

**Rationale**: Type safety prevents runtime errors and serves as living documentation. In an HR system handling sensitive employee data, type safety is critical for data integrity.

### III. Server-First Architecture (NON-NEGOTIABLE)

React Server Components MUST be the default; client components only when necessary:

- Default to Server Components for all new components.
- Add `"use client"` directive ONLY when requiring: state, effects, browser APIs, or event handlers.
- All data fetching MUST use Server Components for initial loads.
- Client-side mutations MUST use TanStack Query (React Query) for cache management.
- API routes in `app/api/` for auth callbacks and backend proxies only.

**Rationale**: Server Components reduce bundle size, improve performance, and keep sensitive logic server-side. Essential for mobile time-tracking users on slower connections.

### IV. Role-Based Access Control (NON-NEGOTIABLE)

Three-tier permission model MUST be enforced at every layer:

- **User (Employee/Freelancer)**: Base permissions for self-service operations.
- **Manager**: User permissions + team management (scoped to assigned employees).
- **Admin**: Full system access (global operations).

Enforcement MUST occur at:

- Route level via Next.js middleware.
- Component level via conditional rendering.
- API level via session validation.
- Database query level (backend responsibility, verified in contracts).

Permission checks MUST never be bypassed. UI MUST hide unauthorized actions (not just disable).

**Rationale**: HR data is highly sensitive. Multi-layer enforcement prevents unauthorized access even if one layer fails. Progressive disclosure based on role improves UX.

### V. User Story Independence (NON-NEGOTIABLE)

Every user story MUST be:

- Prioritized (P1, P2, P3, etc.) based on business value.
- Independently testable without requiring other stories.
- Capable of being deployed as a standalone MVP increment.
- Documented with explicit acceptance scenarios.
- Mapped to specific user roles and permissions.

Tasks MUST be organized by user story to enable parallel development and incremental delivery.

**Rationale**: Independent user stories enable iterative delivery, reduce integration risk, and allow teams to pivot priorities without cascading dependencies.

### VI. Mobile-First Responsiveness (NON-NEGOTIABLE)

Time tracking features MUST be fully functional on mobile devices:

- Check-in/check-out interface MUST be touch-optimized.
- Project selector MUST work with mobile viewports.
- Break controls MUST be easily tappable (minimum 44x44px touch targets).
- Forms MUST use appropriate mobile input types (date pickers, numeric keyboards).
- Navigation MUST adapt to small screens (collapsible sidebar, bottom nav, or hamburger menu).
- All Tailwind classes MUST follow mobile-first approach (base = mobile, then `md:`, `lg:`).

**Rationale**: Employees clock time from various locations and devices. Mobile is the primary use case for time tracking. Poor mobile UX directly impacts adoption and compliance.

### VII. Spanish Labor Law Compliance (NON-NEGOTIABLE)

Leave types and business rules MUST support Spanish employment regulations:

- All 18 leave types from Bizneo MUST be supported (including Spanish-specific types like "Permiso de lactancia").
- Leave duration MUST support half-day increments (morning/afternoon splits).
- Freedom Policy (Fridom) MUST correctly handle PTO overlap rules.
- Seniority-based vacation accrual MUST follow Spanish tenure conventions.
- Regional holiday groups MUST support Spanish autonomous communities (Madrid, Barcelona, etc.).
- All business rules MUST be validated before implementation against Spanish labor law.

**Rationale**: The system replaces Bizneo for freelancers due to legal compliance requirements. Non-compliance risks legal liability.

### VIII. Constitution Compliance (NON-NEGOTIABLE)

All implementation plans MUST include a Constitution Check section that:

- Validates adherence to all core principles.
- Documents any principle violations with explicit justification.
- Explains why simpler alternatives were rejected.
- Verifies technical stack alignment.
- Confirms role-based access control implementation.
- Receives approval before implementation begins.

Plans failing constitution checks MUST be revised before proceeding.

**Rationale**: Constitution checks prevent architectural drift, maintain consistency across features, and ensure complexity is justified rather than accidental.

### IX. Tailwind-Only Styling (NON-NEGOTIABLE)

- Tailwind CSS for all styling — NO custom CSS files unless truly unavoidable.
- shadcn/ui for all UI primitives.
- `cn()` helper from shadcn for conditional class merging.
- Lucide React for icons — NO other icon libraries.
- CVA (Class Variance Authority) for component variants.

**Rationale**: A single styling approach eliminates inconsistency and keeps the design system unified. shadcn/ui provides accessible, unstyled primitives that pair naturally with Tailwind.

### X. Accessibility (RECOMMENDED)

- Use semantic HTML elements (`<button>`, `<nav>`, `<main>`, etc.).
- ARIA labels for interactive elements where needed.
- Full keyboard navigation support.
- WCAG AA minimum contrast (4.5:1 for normal text).
- Visible focus indicators on all interactive elements.

**Rationale**: An HR tool is used daily by all employees. Accessibility ensures no one is excluded and aligns with EU accessibility regulations.

## Technology Stack

- **Framework**: Next.js 14+ (App Router) — NO Pages Router
- **Language**: TypeScript 5.0+ in strict mode
- **Node Version**: 18.17+ or 20.0+
- **Package Manager**: npm, yarn, or pnpm (lock file determines choice)
- **UI Primitives**: shadcn/ui (built on Radix UI)
- **Icons**: Lucide React
- **Styling**: Tailwind CSS (mobile-first breakpoints)
- **Component Variants**: CVA (Class Variance Authority)
- **State Management**: Zustand (global state only), React hooks for local state
- **Data Fetching**: Server Components (initial loads), TanStack Query (client mutations)
- **Forms**: React Hook Form + Zod
- **Auth**: NextAuth.js (Auth.js v5) with Google SSO (OAuth 2.0), JWT sessions
- **Routing**: Next.js App Router (file-based)
- **Internationalization**: Custom i18n system (`src/lib/i18n/`)
- **Date/Time**: date-fns — NO moment.js or day.js
- **Calendar**: react-day-picker (via shadcn calendar component)
- **Timezone**: Store UTC, display Europe/Madrid
- **Date Format**: ISO 8601 for APIs, localized for display
- **Testing**: Vitest + React Testing Library
- **Linting/Formatting**: ESLint + Prettier
- **Build Tool**: Next.js built-in (Turbopack/Webpack)

## Folder Structure

```
src/
├── app/              — Next.js App Router (routes, layouts, pages, error boundaries)
│   ├── api/          — API routes (auth callbacks, backend proxies only)
│   ├── (auth)/       — Auth-related routes (login, etc.)
│   └── (dashboard)/  — Protected dashboard routes
├── components/       — Reusable UI components
│   └── ui/           — shadcn/ui primitives
├── hooks/            — Custom React hooks (useCamelCase)
├── lib/              — Shared utilities and configuration
│   ├── i18n/         — Internationalization system
│   ├── validations/  — Zod schemas for form validation
│   └── utils.ts      — cn() helper and general utilities
├── stores/           — Zustand stores (global state only)
├── types/            — Shared TypeScript interfaces and types
└── constants/        — Application constants (SCREAMING_SNAKE_CASE)
```

## Naming Conventions

| Element           | Convention              | Example                                    |
|-------------------|-------------------------|--------------------------------------------|
| Files (components)| `kebab-case.tsx`        | `leave-request-form.tsx`                   |
| Files (utilities) | `kebab-case.ts`         | `date-helpers.ts`                          |
| Components        | `PascalCase`            | `LeaveRequestForm`                         |
| Hooks             | `useCamelCase`          | `useTimeTracker`                           |
| Constants         | `SCREAMING_SNAKE_CASE`  | `LEAVE_TYPES`, `USER_ROLES`                |
| Types/Interfaces  | `PascalCase`            | `LeaveRequest`, `TimesheetEntry`           |
| Props Interfaces  | `{Component}Props`      | `LeaveRequestFormProps`                    |
| API Functions     | `verbNoun`              | `fetchTimesheets`, `createLeaveRequest`    |

## Error Handling

- **API Calls**: All wrapped in try/catch with typed error responses.
- **User Feedback**: shadcn `sonner` toast for notifications.
- **Form Errors**: Inline validation errors below fields.
- **Loading States**: Skeleton loaders preferred over spinners.
- **Error Boundaries**: Implement at route segment level (`error.tsx`) for graceful failures.

## Specification & Planning Standards

### Specification Requirements

Specifications MUST include:

- User scenarios ordered by priority (P1, P2, P3).
- Acceptance criteria in Given-When-Then format.
- Functional requirements with FR-XXX identifiers.
- Role-based capability matrix (User/Manager/Admin).
- Measurable success criteria with SC-XXX identifiers.
- Edge cases and error scenarios.

### Plan Requirements

Implementation plans MUST include:

- Technical context with explicit Next.js + TypeScript stack.
- Constitution check with any violations justified.
- Project structure showing exact file paths per conventions.
- Component breakdown with Server/Client designation.
- API contract definitions with TypeScript interfaces.
- Mobile responsiveness approach.
- Role-based access control enforcement points.

### Task Requirements

Task lists MUST:

- Group tasks by user story for independent delivery.
- Mark parallelizable tasks with `[P]` prefix.
- Include exact file paths following architecture constraints.
- Specify Server Component vs Client Component for each component task.
- Define TypeScript interfaces before implementation tasks.
- Include role-based access control validation steps.
- Separate foundational tasks from user story tasks.

## Development Workflow

- **Branching**: See CLAUDE.md for git conventions (`<type>/<issue-number>-<short-description>`).
- **Commits**: Conventional commits as defined in CLAUDE.md.
- **Constitution compliance**: Every PR and code review MUST verify principles are followed.

## Quality Gates (NON-NEGOTIABLE)

All of the following MUST pass before work is considered complete:

1. `npm run lint` passes with zero errors.
2. `npm run build` compiles without errors.
3. TypeScript strict mode passes — zero `any` types.
4. All tests pass (`npm test`).
5. Minimum 70% coverage for business logic (forms, utilities, API clients).
6. Constitution check section included in implementation plans.
7. Role-based access control verified at all enforcement layers.

## Governance

This constitution supersedes all other project conventions (except CLAUDE.md git/branch conventions, which it complements). Where conflicts arise between this document and other guidance, this constitution takes precedence.

**Amendment procedure**:
1. Propose the change as a PR that updates this file.
2. The PR MUST include an updated Sync Impact Report (HTML comment at the top).
3. At least one other contributor MUST approve the PR before merge.

**Version**: 1.0.0 | **Ratified**: 2026-03-12 | **Last Amended**: 2026-03-12
