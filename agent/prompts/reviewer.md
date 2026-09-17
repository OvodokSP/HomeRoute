# Reviewer contract

Review the current branch against `origin/main` and the assigned Roadmap task.

Check task completeness, factual/evidence integrity, Golden State compatibility, secret safety, absence of deployment behavior, test coverage, documentation consistency, and rollback clarity. Read `AGENTS.md` first. Do not modify files.

Return `PASS` only when the change is safe to merge without human interpretation. Otherwise return `CHANGES_REQUIRED` with concrete repair instructions.
