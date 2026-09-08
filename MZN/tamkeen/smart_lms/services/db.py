import sqlite3
from pathlib import Path

# Resolve path relative to this file: ../data/lms.db
DB_REL_PATH = Path(__file__).resolve().parents[1] / "data" / "lms.db"


def db_path() -> str:
    Path(DB_REL_PATH).parent.mkdir(parents=True, exist_ok=True)
    return str(DB_REL_PATH)


def get_conn() -> sqlite3.Connection:
    conn = sqlite3.connect(db_path(), check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON;")
    return conn


# Backward-compatible alias so old imports don't break
get_db_connection = get_conn


def _table_columns(conn: sqlite3.Connection, table: str) -> set[str]:
    try:
        rows = conn.execute(f"PRAGMA table_info({table});").fetchall()
        return {r["name"] for r in rows}
    except sqlite3.OperationalError:
        return set()


def _ensure_columns(conn: sqlite3.Connection, table: str, col_defs: dict[str, str]) -> None:
    existing = _table_columns(conn, table)
    for col, ddl in col_defs.items():
        if col not in existing:
            conn.execute(f"ALTER TABLE {table} ADD COLUMN {col} {ddl};")


def init_db() -> None:
    conn = get_conn()
    try:
        conn.executescript(
            """
            PRAGMA foreign_keys = ON;

            -- 1. USERS & ROLES
            CREATE TABLE IF NOT EXISTS users(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                email TEXT UNIQUE,
                password_hash TEXT NULL,
                password TEXT NULL,
                role TEXT CHECK(role IN ('teacher','student')),
                display_name TEXT,
                dys_level INTEGER DEFAULT 0, -- 0-3 scale for accessibility/dyslexia
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                is_active INTEGER DEFAULT 1,
                deleted_at TEXT NULL
            );

            -- 2. TOPICS & QUESTIONS
            CREATE TABLE IF NOT EXISTS topics(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT UNIQUE,
                is_active INTEGER DEFAULT 1,
                deleted_at TEXT NULL
            );

            CREATE TABLE IF NOT EXISTS questions(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                topic_id INTEGER,
                difficulty TEXT CHECK(difficulty IN ('Easy','Medium','Hard')),
                prompt TEXT,
                hint_text TEXT NULL,
                correct_answer TEXT,
                choices_json TEXT NULL,
                input_mode TEXT DEFAULT 'text', -- 'text' | 'mcq' | 'draw'
                answer_type TEXT CHECK(answer_type IN ('exact','numeric')) DEFAULT 'exact',
                tolerance REAL DEFAULT 0.0,
                points REAL DEFAULT 1.0,
                is_active INTEGER DEFAULT 1,
                created_by INTEGER,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY(topic_id) REFERENCES topics(id),
                FOREIGN KEY(created_by) REFERENCES users(id)
            );

            CREATE TABLE IF NOT EXISTS question_stats(
                question_id INTEGER PRIMARY KEY,
                n_attempts INTEGER DEFAULT 0,
                n_correct INTEGER DEFAULT 0,
                avg_time_sec REAL DEFAULT 0.0,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY(question_id) REFERENCES questions(id)
            );

            -- 3. CLASSES & ENROLLMENTS
            CREATE TABLE IF NOT EXISTS classes(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                teacher_id INTEGER,
                name TEXT,
                year TEXT,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                is_active INTEGER DEFAULT 1,
                deleted_at TEXT NULL,
                FOREIGN KEY(teacher_id) REFERENCES users(id)
            );

            CREATE TABLE IF NOT EXISTS enrollments(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                class_id INTEGER,
                student_id INTEGER,
                status TEXT DEFAULT 'active',
                enrolled_at TEXT DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(class_id, student_id),
                FOREIGN KEY(class_id) REFERENCES classes(id),
                FOREIGN KEY(student_id) REFERENCES users(id)
            );

            -- 4. ASSESSMENTS & TARGETS
            CREATE TABLE IF NOT EXISTS assessments(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                teacher_id INTEGER,
                title TEXT,
                topic_id INTEGER NULL,
                difficulty TEXT,
                num_questions INTEGER,
                duration_seconds INTEGER,
                start_at TEXT NULL,
                end_at TEXT NULL,
                status TEXT DEFAULT 'scheduled',
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY(teacher_id) REFERENCES users(id),
                FOREIGN KEY(topic_id) REFERENCES topics(id)
            );

            CREATE TABLE IF NOT EXISTS assessment_topics(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                assessment_id INTEGER,
                topic_id INTEGER,
                UNIQUE(assessment_id, topic_id),
                FOREIGN KEY(assessment_id) REFERENCES assessments(id),
                FOREIGN KEY(topic_id) REFERENCES topics(id)
            );

            CREATE TABLE IF NOT EXISTS assessment_targets(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                assessment_id INTEGER,
                class_id INTEGER NULL,
                student_id INTEGER NULL,
                FOREIGN KEY(assessment_id) REFERENCES assessments(id),
                FOREIGN KEY(class_id) REFERENCES classes(id),
                FOREIGN KEY(student_id) REFERENCES users(id)
            );

            -- 5. INSTANCES & ANSWERS (WITH BEHAVIORAL METRICS)
            CREATE TABLE IF NOT EXISTS assessment_instances(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                assessment_id INTEGER,
                student_id INTEGER,
                assigned_at TEXT DEFAULT CURRENT_TIMESTAMP,
                started_at TEXT NULL,
                ends_at TEXT NULL,
                submitted_at TEXT NULL,
                status TEXT CHECK(status IN ('assigned','in_progress','submitted','auto_submitted','graded')) DEFAULT 'assigned',
                seed INTEGER,
                FOREIGN KEY(assessment_id) REFERENCES assessments(id),
                FOREIGN KEY(student_id) REFERENCES users(id)
            );

            CREATE TABLE IF NOT EXISTS instance_questions(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                instance_id INTEGER,
                question_id INTEGER,
                order_index INTEGER,
                UNIQUE(instance_id, question_id),
                FOREIGN KEY(instance_id) REFERENCES assessment_instances(id),
                FOREIGN KEY(question_id) REFERENCES questions(id)
            );

            CREATE TABLE IF NOT EXISTS answers(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                instance_id INTEGER,
                question_id INTEGER,
                answer_text TEXT,
                is_final INTEGER DEFAULT 0,
                time_spent_sec REAL DEFAULT 0.0,
                ms_first_response INTEGER NULL,     -- Behavioral metric
                hint_count INTEGER DEFAULT 0,       -- Behavioral metric
                attempts INTEGER DEFAULT 1,         -- Behavioral metric
                frustrated_score REAL DEFAULT 0.0,  -- Affective metric
                confused_score REAL DEFAULT 0.0,    -- Affective metric

                -- Drawing / model inference metadata (optional)
                drawing_png_b64 TEXT NULL,
                pred_confidence REAL NULL,
                pred_topk_json TEXT NULL,

                saved_at TEXT DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(instance_id, question_id, is_final),
                FOREIGN KEY(instance_id) REFERENCES assessment_instances(id),
                FOREIGN KEY(question_id) REFERENCES questions(id)
            );

            -- 6. GRADING, ANALYTICS & MASTERY (BKT)
            CREATE TABLE IF NOT EXISTS grading_results(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                instance_id INTEGER,
                question_id INTEGER,
                is_correct INTEGER,
                score REAL,
                feedback TEXT,
                graded_at TEXT DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(instance_id, question_id),
                FOREIGN KEY(instance_id) REFERENCES assessment_instances(id),
                FOREIGN KEY(question_id) REFERENCES questions(id)
            );

            CREATE TABLE IF NOT EXISTS results_analytics(
                instance_id INTEGER PRIMARY KEY,
                student_id INTEGER,
                total_score REAL,
                accuracy REAL,
                computed_at TEXT DEFAULT CURRENT_TIMESTAMP,
                topic_id INTEGER NULL,
                topics_json TEXT NULL,
                model_recommendation TEXT,
                FOREIGN KEY(instance_id) REFERENCES assessment_instances(id),
                FOREIGN KEY(student_id) REFERENCES users(id),
                FOREIGN KEY(topic_id) REFERENCES topics(id)
            );

            CREATE TABLE IF NOT EXISTS student_topic_mastery(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                student_id INTEGER,
                topic_id INTEGER,
                p_knowledge REAL DEFAULT 0.3, -- BKT state P(L)
                n_obs INTEGER DEFAULT 0,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(student_id, topic_id),
                FOREIGN KEY(student_id) REFERENCES users(id),
                FOREIGN KEY(topic_id) REFERENCES topics(id)
            );
            """
        )

        # -------------------------
        # Safe migrations (existing DBs)
        # -------------------------
        _ensure_columns(conn, "users", {
            "is_active": "INTEGER DEFAULT 1",
            "deleted_at": "TEXT NULL",
            "dys_level": "INTEGER DEFAULT 0",
        })
        _ensure_columns(conn, "topics", {"is_active": "INTEGER DEFAULT 1", "deleted_at": "TEXT NULL"})
        _ensure_columns(conn, "questions", {
            "hint_text": "TEXT NULL",
            "choices_json": "TEXT NULL",
            "input_mode": "TEXT DEFAULT 'text'",
            "answer_type": "TEXT DEFAULT 'exact'",
            "tolerance": "REAL DEFAULT 0.0",
            "points": "REAL DEFAULT 1.0",
            "is_active": "INTEGER DEFAULT 1",
        })
        _ensure_columns(conn, "classes", {"is_active": "INTEGER DEFAULT 1", "deleted_at": "TEXT NULL"})
        _ensure_columns(conn, "enrollments", {"status": "TEXT DEFAULT 'active'"})
        _ensure_columns(conn, "assessments", {
            "start_at": "TEXT NULL",
            "end_at": "TEXT NULL",
            "status": "TEXT DEFAULT 'scheduled'",
        })
        _ensure_columns(conn, "assessment_instances", {"ends_at": "TEXT NULL", "submitted_at": "TEXT NULL"})

        _ensure_columns(conn, "answers", {
            "time_spent_sec": "REAL DEFAULT 0.0",
            "is_final": "INTEGER DEFAULT 0",
            "ms_first_response": "INTEGER NULL",
            "hint_count": "INTEGER DEFAULT 0",
            "attempts": "INTEGER DEFAULT 1",
            "frustrated_score": "REAL DEFAULT 0.0",
            "confused_score": "REAL DEFAULT 0.0",
            "drawing_png_b64": "TEXT NULL",
            "pred_confidence": "REAL NULL",
            "pred_topk_json": "TEXT NULL",
        })

        _ensure_columns(conn, "student_topic_mastery", {
            "p_knowledge": "REAL DEFAULT 0.3",
            "n_obs": "INTEGER DEFAULT 0",
        })

        # -------------------------
        # Indexes (performance)
        # -------------------------
        conn.executescript(
            """
            CREATE INDEX IF NOT EXISTS idx_topics_active ON topics(is_active);
            CREATE INDEX IF NOT EXISTS idx_questions_topic_diff_active ON questions(topic_id, difficulty, is_active);
            CREATE INDEX IF NOT EXISTS idx_enrollments_class_status ON enrollments(class_id, status);
            CREATE INDEX IF NOT EXISTS idx_enrollments_student_status ON enrollments(student_id, status);
            CREATE INDEX IF NOT EXISTS idx_assessments_teacher_created ON assessments(teacher_id, created_at);
            CREATE INDEX IF NOT EXISTS idx_instances_student_status ON assessment_instances(student_id, status);
            CREATE INDEX IF NOT EXISTS idx_instances_assessment ON assessment_instances(assessment_id);
            CREATE INDEX IF NOT EXISTS idx_iq_instance_order ON instance_questions(instance_id, order_index);
            CREATE INDEX IF NOT EXISTS idx_answers_instance_final ON answers(instance_id, is_final);
            CREATE INDEX IF NOT EXISTS idx_grading_instance ON grading_results(instance_id);
            CREATE INDEX IF NOT EXISTS idx_mastery_student ON student_topic_mastery(student_id);
            """
        )

        conn.commit()
    finally:
        conn.close()


if __name__ == "__main__":
    init_db()
    print(f"Database successfully initialized at {db_path()}")
