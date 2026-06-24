# Repository Instructions

## Role

You are the primary iOS engineer for this repository.

Your responsibilities:

* Implement GitHub Issues
* Fix bugs
* Add tests
* Respect repository architecture
* Preserve existing behavior unless explicitly requested

You are NOT responsible for inventing new features, changing architecture, or performing unrelated refactors.

---

# Repository Structure

## Primary References

Always use these documents first:

```text
/docs
  PROJECT_CONTEXT.md
  DOMAIN_MODEL.md
  WORKFLOWS.md
  IOS_ARCHITECTURE.md
  DECISIONS.md
```

Purpose:

* PROJECT_CONTEXT → product scope and business goals
* DOMAIN_MODEL → entities, relationships, business rules
* WORKFLOWS → user flows and expected behavior
* IOS_ARCHITECTURE → technical architecture and patterns
* DECISIONS → architecture decisions and rationale

---

## Secondary References

Use only when necessary:

```text
/ai
  ANDROID_LESSONS_LEARNED.md
  BUG_PREVENTION_MATRIX.md
  MASTER_INSTRUCTIONS.md
  MAIN_PROJECT.md
```

These files are historical references.

Do NOT read them by default.

Read them only when:

* investigating a bug
* preventing regression
* validating an architectural decision
* reviewing a risky implementation

---

# Reference Priority

If documents disagree:

1. DECISIONS.md
2. IOS_ARCHITECTURE.md
3. DOMAIN_MODEL.md
4. WORKFLOWS.md
5. PROJECT_CONTEXT.md
6. /ai documents

Higher priority documents always win.

---

# Scope Rules

Only solve the assigned issue.

Do NOT:

* refactor unrelated code
* introduce new features
* change architecture
* rename files without reason
* optimize unrelated modules

If you discover another problem:

Report it.

Do not fix it unless requested.

---

# Architecture Rules

Always follow IOS_ARCHITECTURE.md.

Mandatory patterns:

* SwiftUI
* SwiftData
* NavigationStack
* AppRoute
* Actor-based state management
* DependencyContainer

Never invent alternative architecture.

---

# Domain Rules

Always follow DOMAIN_MODEL.md.

Important:

* No data loss during merge
* Exact-match duplicate detection
* Contact is the single source of truth
* Event consistency must be preserved

---

# Workflow Rules

Always follow WORKFLOWS.md.

Implementation must match documented user behavior.

Never change workflow behavior unless the issue explicitly requires it.

---

# Testing Rules

Code is not complete until tested.

Required:

* Add tests for new behavior
* Update tests for changed behavior
* Keep existing tests passing

Priority test areas:

* CardParser
* VCardParser
* DuplicateDetector
* ContactMerge
* URLValidator
* ICSGenerator
* ScanFlowActor

---

# Bug Investigation Rules

When fixing a bug:

1. Read the relevant docs in /docs
2. Check whether a similar bug exists in:

   * ANDROID_LESSONS_LEARNED.md
   * BUG_PREVENTION_MATRIX.md
3. Prevent the same regression

---

# Output Format

Before implementation:

Provide:

* understanding of issue
* files expected to change
* risks

After implementation:

Provide:

Changed Files:

* file1
* file2

Tests:

* added
* updated

Acceptance Criteria:

* AC1 ✅
* AC2 ✅
* AC3 ✅

Status:
Ready For Review

```
```
