# DysCalc AI — Security, Reliability, and UX Review

## Executive priority

The project has a solid educational workflow and useful server-side exam timing, but it should not be deployed to a real school or institution yet without security and data-governance hardening.

## Critical / high priority

### 1. Legacy/demo passwords are written in plaintext
`seed.py` writes both a SHA256 hash and the raw password into the `users.password` column. Even though successful legacy logins can upgrade hashes later, dormant demo or imported accounts can retain plaintext credentials.

**Upgrade included:** this package changes demo seeding to PBKDF2 via `hash_password()` and stores `password=NULL`.

### 2. Adaptive-answer path contains a runtime bug
`record_adaptive_answer()` calls `compute_engagement_signals(ms_first_response=...)`, but the function accepts `ms_response`. That raises a `TypeError` during adaptive answer processing.

**Upgrade included:** patched keyword argument.

### 3. Student question-read helpers can expose answer keys
The original `instance_questions()` returns `q.*`, which includes `correct_answer`, and does not itself verify student ownership. In a server-rendered Streamlit page this may stay on the server if handled carefully, but it is an unsafe service boundary and is easy to leak accidentally or through a future API.

**Upgrade included:** `student_instance_questions(instance_id, student_id)` verifies ownership and excludes `correct_answer`. The adaptive question return is also stripped of `correct_answer` before reaching the student UI.

### 4. Service-layer authorization is inconsistent
Some functions correctly scope by teacher/student ID, while others accept raw IDs without ownership checks (`class_roster`, `enroll_student`, `remove_student`, topic/question mutation helpers, assessment detail readers). The UI can constrain IDs, but authorization should be enforced in the service layer because UI checks are not a security boundary.

**Recommendation:** every mutating/read operation should receive the authenticated actor ID and enforce ownership/role in SQL.

### 5. No login rate limiting, lockout, or session expiry
Authentication has no failed-attempt throttle and sessions live in Streamlit session state with no explicit absolute/idle expiry.

**Recommendation:** for institutional deployment use SSO/OIDC (Microsoft Entra ID, Google Workspace, etc.), or add server-side session expiry and rate limiting at the reverse proxy/application layer.

### 6. Pickle/joblib model loading is a code-execution trust boundary
`joblib.load()` can execute code from a malicious pickle. Only load models built and signed/hashed by your deployment pipeline; never accept a user-uploaded `.pkl` as a model artifact.

**Recommendation:** maintain a SHA-256 checksum allowlist for model artifacts and store models read-only. Prefer safer model formats when practical.

## Reliability / functional issues

### 7. Dependency list is incomplete
The uploaded `requirements.txt` only lists Streamlit, pandas, and tzdata, while analytics uses joblib/PyBKT and the symbol recognizer uses numpy, Pillow, torch, and torchvision.

**Upgrade included:** expanded requirements list.

### 8. Handwriting recognition checkpoint is missing from the uploaded project set
`symbol_recognizer.py` expects `services/models/best_symbol_cnn2.pt`. Without that checkpoint, drawing inference fails at load time.

**Recommendation:** package the model as a versioned deployment artifact and validate its checksum at startup.

### 9. PyBKT skill naming may not align with LMS topic names
The uploaded model metadata contains skills such as `Addition Whole Numbers` and `Subtraction Whole Numbers`, while demo topics use broad names such as `Addition` and `Subtraction`. Passing the LMS topic name directly as the BKT `skill` can fail or produce fallback behavior if the model does not contain that exact skill.

**Recommendation:** add an explicit `topic_model_skill_map` table/config or retrain the model using the exact LMS topic identifiers.

### 10. CSV import needs backend limits and ownership rules
The import reads the whole file into pandas, has no backend byte/row cap, and can update existing question IDs. In a multi-teacher environment, that can become a cross-tenant editing problem.

**UI mitigation included:** 2 MB upload cap. Still add backend row/byte caps and ownership checks.

### 11. CSV export can create spreadsheet-formula injection risk
If exported teacher-authored fields begin with `=`, `+`, `-`, or `@`, spreadsheet software may interpret them as formulas.

**Recommendation:** escape formula-leading cells on CSV export when the file will be opened in Excel-like tools.

### 12. SQLite is not an institutional multi-user database
SQLite is convenient for demos but will become a locking, backup, and concurrency bottleneck with simultaneous classes/exams.

**Recommendation:** move production to PostgreSQL, use migrations (Alembic), connection pooling, backups, and monitored restore tests.

## Privacy / responsible-learning issues

### 13. `frustrated_score` and `confused_score` are heuristic labels
The signals are derived from response time, attempts, hints, and correctness. They are not validated emotional states and can be misleading or stigmatizing.

**UX change included:** the teacher UI renames these to neutral support indicators and explains that they are heuristic, not clinical/emotional diagnoses.

### 14. Student data governance is not defined
The schema stores performance, timing, hints, attempts, drawing images (base64), and model outputs. For minors or school deployments, define retention, access, consent/notice, deletion, export, and audit policies before production.

**Recommendation:** collect only what is required, define retention windows, encrypt backups, add audit trails, and document teacher/admin access.

## UI/UX upgrades included

- Branded education-corporate visual system with calm navy/blue/teal palette.
- Main-page sign-in instead of forcing first-time users to hunt in the sidebar.
- Separate Teacher and Student workspaces with clear information architecture.
- Teacher KPIs, class roster flow, question bank filters, assessment builder, and learner insights.
- Student one-question-at-a-time assessment flow, explicit progress, persistent timer, saved-state cue, and confirmation before submission.
- Mastery presented as an estimate with evidence counts, not a fixed student label.
- Responsive spacing and larger controls for reduced cognitive load.
- Avoids relying only on red/green to communicate meaning.
- Neutral language for support/behavioral indicators.

## Recommended next additions

1. SSO/OIDC + admin role + audit log.
2. PostgreSQL + Alembic migrations + automated backup/restore.
3. Accessibility preferences per learner (font size, reduced motion, reading spacing, optional timer concealment where accommodations allow).
4. Teacher intervention notes and a human-reviewed recommendation workflow.
5. Parent/guardian reporting only if privacy rules and permissions are defined.
6. Model versioning, model-card page, feature provenance, and prediction confidence/coverage monitoring.
7. Automated tests for exam ownership, timing, submission idempotency, CSV isolation, and adaptive practice.
8. Observability: structured logs, error tracking, uptime, DB health, and model-load status.
9. Internationalization (Arabic/English) with proper RTL support.
10. Accessibility testing against WCAG 2.2 AA and keyboard-only navigation.
