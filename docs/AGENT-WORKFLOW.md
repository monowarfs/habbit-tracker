# Agent Implementation Workflow

This document defines the strict operational procedure for AI agents implementing tasks from the `IMPLEMENTATION-ORDER.md` list.

## 1. Task Selection
- Read `docs/IMPLEMENTATION-ORDER.md`.
- Identify the first task (lowest serial number) that is not yet fully implemented and merged into the `dev` branch.
- Locate the corresponding instruction file in `docs/superpowers/specs/`.

## 2. Environment Setup
- Checkout the `dev` branch: `git checkout dev`.
- Ensure it is up-to-date: `git pull origin dev`.
- Create a new feature branch for the task: `git checkout -b feature/<task-name>`.
- **Constraint**: DO NOT delete local or remote feature branches unless explicitly instructed by the user.

## 3. Implementation Loop
- Implement the task in small, logical increments.
- Follow the instructions in the task's `IMPLEMENTATION-PLAN.md` strictly.
- **Commit frequently**: Create a git commit for every sub-task or major code change with descriptive messages.
- Use `Co-Authored-By: Claude <noreply@anthropic.com>` (or equivalent) if applicable to denote AI assistance.

## 4. Testing
- Run unit and integration tests **only** for the current task.
- **Timeout Rule**: If a test takes longer than 10 seconds, kill it immediately.
- Fix the underlying issue and retry.

## 5. Pull Request & Review Loop
- Push the feature branch to remote: `git push origin feature/<task-name>`.
- Create a Pull Request (PR) to the `dev` branch via the platform (simulated by pushing).
- **Self-Review Pass 1**:
    - Critically analyze the implemented code for bugs, edge cases, and architectural alignment.
    - Identify and document findings.
    - Fix the issues and commit/push updates to the feature branch.
- **Self-Review Pass 2**:
    - Perform a second pass to ensure the fixes are robust and no new issues were introduced.
    - Document any new findings.
    - Finalize the code.

## 6. Documentation & Merging
- Add all review findings and a summary of work as a comment (simulated in `walkthrough.artifact.md` and `pr_review.artifact.md`).
- Merge the feature branch into `dev`: `git checkout dev && git merge feature/<task-name>`.
- Push the updated `dev` branch to remote: `git push origin dev`.
- Update `docs/IMPLEMENTATION-ORDER.md` to mark the task as complete.
- Proceed to the next task in the serial list.
