# Agent Homebase roadmap

## Phase 1: Personal operating layer

Status: Complete

- Live skill wiring and global guidance
- Durable memory and reusable commands
- Bounded in-thread and headless loops
- Health checks, dry-runs, and safety contracts

## Phase 2: Validation and portability boundary

Status: In progress

- Add repository structure validation and focused regression tests
- Document requirements, boundaries, and acceptance criteria
- Keep installation behavior explicit and recoverable
- Evaluate `.agents/skills` compatibility without disrupting the current setup

Exit criteria:

- Validation passes from a clean checkout
- Skill and vendor inventories are checked automatically
- No runtime or credential files are accepted into the repository

## Phase 3: Distribution

Status: Planned

- Add a portable installer for supported platforms
- Add CI for structural validation and PowerShell tests
- Publish only after runtime boundaries and permissions are documented
