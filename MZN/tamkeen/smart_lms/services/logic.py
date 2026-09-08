import json
import random
from datetime import datetime, timezone, timedelta
from zoneinfo import ZoneInfo
from services.analytics import compute_engagement_signals

from services.db import get_conn
from services.analytics import (
    grade_instance,
    grade_question,
    update_student_mastery_pybkt,
    get_adaptive_difficulty,
)

TZ_JORDAN = ZoneInfo("Asia/Amman")


def now_utc_dt() -> datetime:
    return datetime.now(timezone.utc)


def utc_to_z(dt: datetime) -> str:
    dt2 = dt.astimezone(timezone.utc).replace(microsecond=0)
    return dt2.isoformat().replace("+00:00", "Z")


# =========================
# Adaptive practice (pyBKT driven)
# =========================

def _next_order_index(conn, instance_id: int) -> int:
    row = conn.execute(
        "SELECT COALESCE(MAX(order_index), 0) AS mx FROM instance_questions WHERE instance_id=?;",
        (instance_id,),
    ).fetchone()
    return int(row["mx"] or 0) + 1


def _instance_question_count(conn, instance_id: int) -> int:
    row = conn.execute(
        "SELECT COUNT(1) AS n FROM instance_questions WHERE instance_id=?;",
        (instance_id,),
    ).fetchone()
    return int(row["n"] or 0)


def get_next_adaptive_question(
    instance_id: int,
    student_id: int,
    topic_id: int | None = None,
) -> tuple[dict | None, str | None, float, int, int]:
    """Return the next adaptive question and current mastery.

    Returns:
        (question_dict_or_None, topic_name_or_None, p_knowledge, served_count, max_questions)
    """
    conn = get_conn()
    try:
        inst = conn.execute(
            """
            SELECT ai.id, ai.status, ai.student_id, a.id AS assessment_id, a.num_questions
            FROM assessment_instances ai
            JOIN assessments a ON a.id=ai.assessment_id
            WHERE ai.id=? AND ai.student_id=?;
            """,
            (instance_id, student_id),
        ).fetchone()
        if not inst:
            raise ValueError("Instance not found")
        if inst["status"] != "in_progress":
            raise ValueError("Instance not in progress")

        max_questions = int(inst["num_questions"] or 0)
        served = _instance_question_count(conn, instance_id)
        if max_questions > 0 and served >= max_questions:
            return None, None, 0.0, served, max_questions

        # Resolve topics on this adaptive assessment.
        trows = conn.execute(
            """
            SELECT at.topic_id, t.name
            FROM assessment_topics at
            JOIN topics t ON t.id=at.topic_id
            WHERE at.assessment_id=?
            ORDER BY t.name;
            """,
            (int(inst["assessment_id"]),),
        ).fetchall()
        topics = [(int(r["topic_id"]), r["name"]) for r in trows]
        if not topics:
            raise ValueError("Adaptive assessment has no topics")

        # Choose topic: explicit, else weakest by current stored mastery.
        if topic_id is None:
            mrows = conn.execute(
                """
                SELECT topic_id, p_knowledge, updated_at
                FROM student_topic_mastery
                WHERE student_id=? AND topic_id IN ({})
                """.format(",".join(["?"] * len(topics))),
                tuple([student_id] + [tid for tid, _ in topics]),
            ).fetchall()
            m_map = {int(r["topic_id"]): float(r["p_knowledge"] or 0.3) for r in mrows}
            topic_id = sorted([tid for tid, _ in topics], key=lambda tid: (m_map.get(tid, 0.3), tid))[0]

        topic_name = None
        for tid, tname in topics:
            if int(tid) == int(topic_id):
                topic_name = tname
                break
        if topic_name is None:
            raise ValueError("Topic not part of this assessment")

        p_knowledge, _n_obs = update_student_mastery_pybkt(conn, student_id, int(topic_id), topic_name)
        target_difficulty = get_adaptive_difficulty(float(p_knowledge))

        # Prefer questions not yet used in this instance.
        q = conn.execute(
            """
            SELECT q.*
            FROM questions q
            WHERE q.is_active=1
              AND q.topic_id=?
              AND q.difficulty=?
              AND q.id NOT IN (SELECT question_id FROM instance_questions WHERE instance_id=?)
            ORDER BY RANDOM()
            LIMIT 1;
            """,
            (int(topic_id), target_difficulty, instance_id),
        ).fetchone()

        # If none at target difficulty, broaden within the same topic.
        if not q:
            q = conn.execute(
                """
                SELECT q.*
                FROM questions q
                WHERE q.is_active=1
                  AND q.topic_id=?
                  AND q.id NOT IN (SELECT question_id FROM instance_questions WHERE instance_id=?)
                ORDER BY CASE q.difficulty WHEN 'Easy' THEN 1 WHEN 'Medium' THEN 2 WHEN 'Hard' THEN 3 ELSE 99 END,
                         RANDOM()
                LIMIT 1;
                """,
                (int(topic_id), instance_id),
            ).fetchone()

        if not q:
            return None, topic_name, float(p_knowledge), served, max_questions

        qid = int(q["id"])
        order_idx = _next_order_index(conn, instance_id)
        conn.execute(
            "INSERT OR IGNORE INTO instance_questions(instance_id, question_id, order_index) VALUES(?,?,?);",
            (instance_id, qid, order_idx),
        )
        conn.commit()

        served2 = served + 1
        safe_q = dict(q)
        safe_q.pop("correct_answer", None)
        return safe_q, topic_name, float(p_knowledge), served2, max_questions
    finally:
        conn.close()


def record_adaptive_answer(
    instance_id: int,
    student_id: int,
    question_id: int,
    answer_text: str,
    ms_first_response: int | None = None,
    hint_count: int | None = None,
    attempts: int | None = None,
    drawing_png_b64: str | None = None,
    pred_confidence: float | None = None,
    pred_topk_json: str | None = None,
) -> dict:
    """Persist a single adaptive answer, grade it immediately, and update mastery."""
    conn = get_conn()
    try:
        ok, reason, _ = can_save_instance(instance_id, student_id)
        if not ok:
            raise ValueError(reason)

        # Ensure question is present in this instance.
        if not conn.execute(
            "SELECT 1 FROM instance_questions WHERE instance_id=? AND question_id=?;",
            (instance_id, question_id),
        ).fetchone():
            order_idx = _next_order_index(conn, instance_id)
            conn.execute(
                "INSERT OR IGNORE INTO instance_questions(instance_id, question_id, order_index) VALUES(?,?,?);",
                (instance_id, question_id, order_idx),
            )

        # Save autosave row then finalize just this question.
        upsert_autosave(
            instance_id,
            student_id,
            question_id,
            answer_text=str(answer_text),
            add_time_sec=0.0,
            ms_first_response=ms_first_response,
            hint_count=hint_count,
            attempts=attempts,
            drawing_png_b64=drawing_png_b64,
            pred_confidence=pred_confidence,
            pred_topk_json=pred_topk_json,
        )
        finalize_answer(conn, instance_id, question_id)

        # Grade now.
        q = conn.execute(
            "SELECT id, topic_id, answer_type, tolerance, points, correct_answer FROM questions WHERE id=?;",
            (question_id,),
        ).fetchone()
        if not q:
            raise ValueError("Question not found")

        fa = conn.execute(
            "SELECT answer_text, time_spent_sec FROM answers WHERE instance_id=? AND question_id=? AND is_final=1;",
            (instance_id, question_id),
        ).fetchone()
        student_answer = (fa["answer_text"] if fa else "") or ""
        tsec = float(fa["time_spent_sec"] if fa else 0.0)

        is_correct, score, feedback = grade_question(
            student_answer,
            q["correct_answer"] or "",
            q["answer_type"] or "exact",
            float(q["tolerance"] or 0.0),
            float(q["points"] or 1.0),
        )

        nowz = utc_to_z(now_utc_dt())
        conn.execute(
            """
            INSERT INTO grading_results(instance_id, question_id, is_correct, score, feedback, graded_at)
            VALUES(?,?,?,?,?,?)
            ON CONFLICT(instance_id, question_id) DO UPDATE SET
                is_correct=excluded.is_correct,
                score=excluded.score,
                feedback=excluded.feedback,
                graded_at=excluded.graded_at;
            """,
            (instance_id, question_id, int(is_correct), float(score), feedback, nowz),
        )

        # Update mastery for this topic.
        t = conn.execute("SELECT name FROM topics WHERE id=?;", (int(q["topic_id"]),)).fetchone()
        topic_name = (t["name"] if t else f"Topic {int(q['topic_id'])}")
        p_knowledge, n_obs = update_student_mastery_pybkt(conn, student_id, int(q["topic_id"]), topic_name)
        frustrated, confused = compute_engagement_signals(
            ms_response=ms_first_response,
            hint_count=hint_count,
            attempts=attempts,
            is_correct=int(is_correct),
        )

        conn.execute(
            """
            UPDATE answers
            SET frustrated_score = ?,
                confused_score   = ?
            WHERE instance_id = ?
            AND question_id  = ?
            AND is_final     = 1;
            """,
            (frustrated, confused, instance_id, question_id),
        )
        conn.commit()
        return {
            "question_id": int(question_id),
            "is_correct": int(is_correct),
            "score": float(score),
            "feedback": feedback,
            "correct_answer": q["correct_answer"],
            "topic_id": int(q["topic_id"]),
            "topic_name": topic_name,
            "p_knowledge": float(p_knowledge),
            "n_obs": int(n_obs),
            "graded_at": nowz,
        }

        
    finally:
        conn.close()


def schedule_spaced_practice(
    student_id: int,
    teacher_id: int,
    max_topics: int = 3,
    mastery_threshold: float = 0.60,
    decay_days: int = 7,
    duration_seconds: int = 15 * 60,
    max_questions: int = 20,
) -> str:
    """Create an *adaptive* practice assessment for weak/decayed topics."""
    conn = get_conn()
    try:
        # Pick topics.
        mrows = conn.execute(
            """
            SELECT stm.topic_id, stm.p_knowledge, stm.updated_at, t.name
            FROM student_topic_mastery stm
            JOIN topics t ON t.id=stm.topic_id
            WHERE stm.student_id=? AND t.is_active=1
            ORDER BY stm.p_knowledge ASC, stm.updated_at ASC;
            """,
            (student_id,),
        ).fetchall()

        weak = []
        cutoff = now_utc_dt() - timedelta(days=int(decay_days))
        for r in mrows:
            pk = float(r["p_knowledge"] or 0.3)
            upd = utc_z_to_dt(r["updated_at"]) or datetime(1970, 1, 1, tzinfo=timezone.utc)
            if pk < mastery_threshold or upd < cutoff:
                weak.append((int(r["topic_id"]), r["name"], pk, upd))

        # If no mastery records yet, fall back to active topics.
        if not weak:
            trows = conn.execute(
                "SELECT id, name FROM topics WHERE is_active=1 ORDER BY name LIMIT ?;",
                (max_topics,),
            ).fetchall()
            weak = [(int(r["id"]), r["name"], 0.3, datetime(1970, 1, 1, tzinfo=timezone.utc)) for r in trows]

        weak = weak[: max_topics]
        if not weak:
            return "No topics available to schedule practice."

        topic_ids = [tid for tid, _, _, _ in weak]
        topic_names = [name for _, name, _, _ in weak]

        nowz = utc_to_z(now_utc_dt())
        title = f"Spaced Repetition Practice — {' / '.join(topic_names)}"

        cur = conn.execute(
            """
            INSERT INTO assessments(teacher_id, title, topic_id, difficulty, num_questions, duration_seconds, start_at, end_at, status, created_at)
            VALUES(?,?,?,?,?,?,?,?, 'scheduled', ?);
            """,
            (teacher_id, title, None, "Adaptive", int(max_questions), int(duration_seconds), None, None, nowz),
        )
        assessment_id = int(cur.lastrowid)

        for tid in topic_ids:
            conn.execute(
                "INSERT INTO assessment_topics(assessment_id, topic_id) VALUES(?,?) ON CONFLICT(assessment_id, topic_id) DO NOTHING;",
                (assessment_id, int(tid)),
            )

        conn.execute(
            "INSERT INTO assessment_targets(assessment_id, class_id, student_id) VALUES(?,NULL,?);",
            (assessment_id, student_id),
        )

        seed = random.randint(1, 2_147_483_647)
        cur2 = conn.execute(
            """
            INSERT INTO assessment_instances(assessment_id, student_id, assigned_at, status, seed)
            VALUES(?,?,?, 'assigned', ?);
            """,
            (assessment_id, student_id, nowz, seed),
        )
        instance_id = int(cur2.lastrowid)

        conn.commit()
        return f"Scheduled adaptive practice (instance #{instance_id}) for: {', '.join(topic_names)}"
    finally:
        conn.close()

def parse_dt_to_utc_z(s: str | None) -> str | None:
    s = (s or "").strip()
    if not s:
        return None

    s2 = s.replace(" ", "T")
    if s2.endswith("Z"):
        s2 = s2[:-1] + "+00:00"

    dt = datetime.fromisoformat(s2)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=TZ_JORDAN)

    return utc_to_z(dt.astimezone(timezone.utc))


def utc_z_to_dt(utc_z: str | None) -> datetime | None:
    if not utc_z:
        return None
    s = utc_z.strip()
    if s.endswith("Z"):
        s = s[:-1] + "+00:00"
    return datetime.fromisoformat(s).astimezone(timezone.utc)


def utc_z_to_jordan_str(utc_z: str | None) -> str:
    dt = utc_z_to_dt(utc_z)
    if not dt:
        return ""
    return dt.astimezone(TZ_JORDAN).strftime("%Y-%m-%d %H:%M")


def jordan_now_str() -> str:
    return now_utc_dt().astimezone(TZ_JORDAN).strftime("%Y-%m-%d %H:%M:%S")


# -------------------- Users / Classes --------------------
def upsert_user(email: str, role: str, display_name: str, password_hash: str | None, legacy_password: str | None):
    email_n = (email or "").strip().lower()
    if not email_n:
        raise ValueError("Email required")
    if role not in ("teacher", "student"):
        raise ValueError("Invalid role")

    conn = get_conn()
    try:
        row = conn.execute("SELECT id FROM users WHERE lower(email)=? LIMIT 1;", (email_n,)).fetchone()
        nowz = utc_to_z(now_utc_dt())
        if row:
            uid = row["id"]
            conn.execute(
                "UPDATE users SET role=?, display_name=?, password_hash=?, password=?, is_active=1, deleted_at=NULL "
                "WHERE id=?;",
                (role, display_name, password_hash, legacy_password, uid),
            )
        else:
            conn.execute(
                "INSERT INTO users(email, password_hash, password, role, display_name, created_at, is_active) "
                "VALUES(?,?,?,?,?,?,1);",
                (email_n, password_hash, legacy_password, role, display_name, nowz),
            )
        conn.commit()
    finally:
        conn.close()


def disable_user(user_id: int):
    conn = get_conn()
    try:
        nowz = utc_to_z(now_utc_dt())
        conn.execute("UPDATE users SET is_active=0, deleted_at=? WHERE id=?;", (nowz, user_id))
        conn.commit()
    finally:
        conn.close()


def reactivate_user(user_id: int):
    conn = get_conn()
    try:
        conn.execute("UPDATE users SET is_active=1, deleted_at=NULL WHERE id=?;", (user_id,))
        conn.commit()
    finally:
        conn.close()


def list_active_students():
    conn = get_conn()
    try:
        rows = conn.execute(
            "SELECT id, email, display_name FROM users "
            "WHERE role='student' AND is_active=1 ORDER BY email;"
        ).fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()


def list_users(include_inactive: bool = True):
    conn = get_conn()
    try:
        if include_inactive:
            rows = conn.execute(
                "SELECT id, email, role, display_name, is_active, deleted_at FROM users ORDER BY role, email;"
            ).fetchall()
        else:
            rows = conn.execute(
                "SELECT id, email, role, display_name, is_active, deleted_at FROM users WHERE is_active=1 ORDER BY role, email;"
            ).fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()


def create_class(teacher_id: int, name: str, year: str):
    conn = get_conn()
    try:
        nowz = utc_to_z(now_utc_dt())
        conn.execute(
            "INSERT INTO classes(teacher_id, name, year, created_at, is_active) VALUES(?,?,?,?,1);",
            (teacher_id, name, year, nowz),
        )
        conn.commit()
    finally:
        conn.close()


def teacher_classes(teacher_id: int, active_only: bool = True):
    conn = get_conn()
    try:
        if active_only:
            rows = conn.execute(
                "SELECT * FROM classes WHERE teacher_id=? AND is_active=1 ORDER BY created_at DESC;",
                (teacher_id,),
            ).fetchall()
        else:
            rows = conn.execute(
                "SELECT * FROM classes WHERE teacher_id=? ORDER BY created_at DESC;",
                (teacher_id,),
            ).fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()


def soft_delete_class(class_id: int, teacher_id: int):
    conn = get_conn()
    try:
        nowz = utc_to_z(now_utc_dt())
        conn.execute(
            "UPDATE classes SET is_active=0, deleted_at=? WHERE id=? AND teacher_id=?;",
            (nowz, class_id, teacher_id),
        )
        conn.commit()
    finally:
        conn.close()


def class_roster(class_id: int):
    conn = get_conn()
    try:
        rows = conn.execute(
            """
            SELECT e.id AS enrollment_id, e.status, e.enrolled_at,
                   u.id AS student_id, u.email, u.display_name, u.is_active
            FROM enrollments e
            JOIN users u ON u.id=e.student_id
            WHERE e.class_id=?
            ORDER BY u.email;
            """,
            (class_id,),
        ).fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()


def enroll_student(class_id: int, student_id: int):
    conn = get_conn()
    try:
        nowz = utc_to_z(now_utc_dt())
        conn.execute(
            """
            INSERT INTO enrollments(class_id, student_id, status, enrolled_at)
            VALUES(?,?, 'active', ?)
            ON CONFLICT(class_id, student_id) DO UPDATE SET status='active';
            """,
            (class_id, student_id, nowz),
        )
        conn.commit()
    finally:
        conn.close()


def remove_student(class_id: int, student_id: int):
    conn = get_conn()
    try:
        conn.execute(
            "UPDATE enrollments SET status='removed' WHERE class_id=? AND student_id=?;",
            (class_id, student_id),
        )
        conn.commit()
    finally:
        conn.close()


def teacher_students(teacher_id: int):
    conn = get_conn()
    try:
        rows = conn.execute(
            """
            SELECT DISTINCT u.id, u.email, u.display_name
            FROM classes c
            JOIN enrollments e ON e.class_id=c.id AND e.status='active'
            JOIN users u ON u.id=e.student_id AND u.is_active=1
            WHERE c.teacher_id=? AND c.is_active=1
            ORDER BY u.email;
            """,
            (teacher_id,),
        ).fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()


# -------------------- Topics --------------------

def add_topic(name: str):
    name = (name or "").strip()
    if not name:
        raise ValueError("Topic name required")
    conn = get_conn()
    try:
        conn.execute(
            "INSERT INTO topics(name, is_active) VALUES(?,1) ON CONFLICT(name) DO NOTHING;",
            (name,),
        )
        conn.commit()
    finally:
        conn.close()


def list_topics(active_only: bool = True):
    conn = get_conn()
    try:
        if active_only:
            rows = conn.execute("SELECT id, name, is_active, deleted_at FROM topics WHERE is_active=1 ORDER BY name;").fetchall()
        else:
            rows = conn.execute("SELECT id, name, is_active, deleted_at FROM topics ORDER BY name;").fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()


def soft_delete_topic(topic_id: int, deactivate_questions: bool = True):
    conn = get_conn()
    try:
        nowz = utc_to_z(now_utc_dt())
        conn.execute("UPDATE topics SET is_active=0, deleted_at=? WHERE id=?;", (nowz, topic_id))
        if deactivate_questions:
            conn.execute("UPDATE questions SET is_active=0, updated_at=? WHERE topic_id=?;", (nowz, topic_id))
        conn.commit()
    finally:
        conn.close()


def reactivate_topic(topic_id: int):
    conn = get_conn()
    try:
        conn.execute("UPDATE topics SET is_active=1, deleted_at=NULL WHERE id=?;", (topic_id,))
        conn.commit()
    finally:
        conn.close()


# -------------------- Questions --------------------

def get_question(qid: int):
    conn = get_conn()
    try:
        r = conn.execute("SELECT * FROM questions WHERE id=?;", (qid,)).fetchone()
        return dict(r) if r else None
    finally:
        conn.close()


def upsert_question(
    qid: int | None,
    topic_id: int,
    difficulty: str,
    prompt: str,
    hint_text: str | None,
    correct_answer: str,
    choices_json: str | None,
    input_mode: str = "text",
    answer_type: str = "exact",
    tolerance: float = 0.0,
    points: float = 1.0,
    is_active: int = 1,
    created_by: int | None = None,
):
    if difficulty not in ("Easy", "Medium", "Hard"):
        raise ValueError("Invalid difficulty")
    if answer_type not in ("exact", "numeric"):
        raise ValueError("Invalid answer type")

    im = (input_mode or "text").strip().lower()
    if im not in ("text", "mcq", "draw"):
        raise ValueError("Invalid input mode")
    # normalize stored value
    input_mode = im

    conn = get_conn()
    try:
        nowz = utc_to_z(now_utc_dt())
        if qid:
            conn.execute(
                """
                UPDATE questions SET
                    topic_id=?, difficulty=?, prompt=?, hint_text=?, correct_answer=?,
                    choices_json=?, input_mode=?, answer_type=?, tolerance=?, points=?,
                    is_active=?, updated_at=?
                WHERE id=?;
                """,
                (topic_id, difficulty, prompt, hint_text, correct_answer, choices_json, input_mode, answer_type, tolerance, points, is_active, nowz, qid),
            )
        else:
            conn.execute(
                """
                INSERT INTO questions(
                    topic_id, difficulty, prompt, hint_text, correct_answer, choices_json,
                    input_mode, answer_type, tolerance, points, is_active, created_by, created_at, updated_at
                ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?);
                """,
                (topic_id, difficulty, prompt, hint_text, correct_answer, choices_json, input_mode, answer_type, tolerance, points, is_active, created_by, nowz, nowz),
            )
        conn.commit()
    finally:
        conn.close()


def search_questions(topic_id=None, difficulty=None, active=None, term: str | None = None):
    term = (term or "").strip()
    params = []
    where = ["1=1"]
    if topic_id and int(topic_id) > 0:
        where.append("q.topic_id=?")
        params.append(int(topic_id))
    if difficulty and difficulty != "All":
        where.append("q.difficulty=?")
        params.append(difficulty)
    if active in (0, 1):
        where.append("q.is_active=?")
        params.append(int(active))
    if term:
        where.append("(q.prompt LIKE ? OR q.correct_answer LIKE ?)")
        params.extend([f"%{term}%", f"%{term}%"])

    sql = f"""
    SELECT q.*,
           t.name AS topic_name,
           COALESCE(s.n_attempts,0) AS n_attempts,
           COALESCE(s.n_correct,0) AS n_correct,
           COALESCE(s.avg_time_sec,0.0) AS avg_time_sec
    FROM questions q
    JOIN topics t ON t.id=q.topic_id
    LEFT JOIN question_stats s ON s.question_id=q.id
    WHERE {' AND '.join(where)}
    ORDER BY q.id DESC;
    """
    conn = get_conn()
    try:
        rows = conn.execute(sql, tuple(params)).fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()


# -------------------- Assessments / Instances --------------------

def _assessment_topics(conn, assessment_id: int):
    rows = conn.execute(
        """
        SELECT at.topic_id, t.name
        FROM assessment_topics at
        JOIN topics t ON t.id=at.topic_id
        WHERE at.assessment_id=?
        ORDER BY t.name;
        """,
        (assessment_id,),
    ).fetchall()
    return [dict(r) for r in rows]


def create_assessment(
    teacher_id: int,
    title: str,
    topic_ids: list[int],
    difficulty: str,
    num_questions: int,
    duration_seconds: int,
    start_at_in: str | None,
    end_at_in: str | None,
    class_ids: list[int],
    student_ids: list[int],
):
    if not topic_ids:
        raise ValueError("Select at least one topic")
    if difficulty not in ("Easy", "Medium", "Hard"):
        raise ValueError("Invalid difficulty")
    if num_questions <= 0:
        raise ValueError("num_questions must be > 0")
    if duration_seconds <= 0:
        raise ValueError("duration_seconds must be > 0")

    start_at = parse_dt_to_utc_z(start_at_in) if (start_at_in or "").strip() else None
    end_at = parse_dt_to_utc_z(end_at_in) if (end_at_in or "").strip() else None

    conn = get_conn()
    try:
        nowz = utc_to_z(now_utc_dt())

        qpool = conn.execute(
            f"""
            SELECT id FROM questions
            WHERE is_active=1 AND difficulty=?
              AND topic_id IN ({",".join(["?"] * len(topic_ids))})
            """,
            tuple([difficulty] + topic_ids),
        ).fetchall()
        if len(qpool) < num_questions:
            raise ValueError(f"Not enough questions in bank: have {len(qpool)}, need {num_questions}.")

        cur = conn.execute(
            """
            INSERT INTO assessments(teacher_id, title, topic_id, difficulty, num_questions, duration_seconds, start_at, end_at, status, created_at)
            VALUES(?,?,?,?,?,?,?,?, 'scheduled', ?);
            """,
            (teacher_id, title, None, difficulty, num_questions, duration_seconds, start_at, end_at, nowz),
        )
        assessment_id = int(cur.lastrowid)

        for tid in topic_ids:
            conn.execute(
                "INSERT INTO assessment_topics(assessment_id, topic_id) VALUES(?,?) ON CONFLICT(assessment_id, topic_id) DO NOTHING;",
                (assessment_id, tid),
            )

        for cid in class_ids:
            conn.execute(
                "INSERT INTO assessment_targets(assessment_id, class_id, student_id) VALUES(?,?,NULL);",
                (assessment_id, cid),
            )
        for sid in student_ids:
            conn.execute(
                "INSERT INTO assessment_targets(assessment_id, class_id, student_id) VALUES(?,NULL,?);",
                (assessment_id, sid),
            )

        resolved_students = set(int(s) for s in student_ids)
        if class_ids:
            rows = conn.execute(
                f"""
                SELECT DISTINCT e.student_id
                FROM enrollments e
                JOIN classes c ON c.id=e.class_id AND c.is_active=1
                JOIN users u ON u.id=e.student_id AND u.is_active=1
                WHERE e.status='active' AND e.class_id IN ({",".join(["?"] * len(class_ids))})
                """,
                tuple(class_ids),
            ).fetchall()
            for r in rows:
                resolved_students.add(int(r["student_id"]))

        all_qids = [int(r["id"]) for r in qpool]
        for sid in sorted(resolved_students):
            seed = random.randint(1, 2_147_483_647)
            cur2 = conn.execute(
                """
                INSERT INTO assessment_instances(assessment_id, student_id, assigned_at, status, seed)
                VALUES(?,?,?, 'assigned', ?);
                """,
                (assessment_id, sid, nowz, seed),
            )
            instance_id = int(cur2.lastrowid)

            rng = random.Random(seed)
            chosen = rng.sample(all_qids, k=num_questions)
            for idx, qid in enumerate(chosen, start=1):
                conn.execute(
                    "INSERT INTO instance_questions(instance_id, question_id, order_index) VALUES(?,?,?);",
                    (instance_id, qid, idx),
                )

        conn.commit()
        return assessment_id
    finally:
        conn.close()


def teacher_assessments(teacher_id: int):
    conn = get_conn()
    try:
        rows = conn.execute(
            """
            SELECT id, title, created_at, difficulty, num_questions, duration_seconds, start_at, end_at
            FROM assessments
            WHERE teacher_id=?
            ORDER BY created_at DESC;
            """,
            (teacher_id,),
        ).fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()


def assessment_topics_view(assessment_id: int):
    conn = get_conn()
    try:
        return _assessment_topics(conn, assessment_id)
    finally:
        conn.close()


def assessment_targets_view(assessment_id: int):
    conn = get_conn()
    try:
        rows = conn.execute(
            """
            SELECT at.id,
                   at.class_id, c.name AS class_name, c.year AS class_year,
                   at.student_id, u.email AS student_email, u.display_name AS student_name
            FROM assessment_targets at
            LEFT JOIN classes c ON c.id=at.class_id
            LEFT JOIN users u ON u.id=at.student_id
            WHERE at.assessment_id=?
            ORDER BY at.id;
            """,
            (assessment_id,),
        ).fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()


def assessment_instances_view(assessment_id: int):
    conn = get_conn()
    try:
        rows = conn.execute(
            """
            SELECT ai.id AS instance_id,
                   u.email, u.display_name,
                   ai.status, ai.assigned_at, ai.started_at, ai.ends_at, ai.submitted_at
            FROM assessment_instances ai
            JOIN users u ON u.id=ai.student_id
            WHERE ai.assessment_id=?
            ORDER BY u.email;
            """,
            (assessment_id,),
        ).fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()


def student_instances(student_id: int):
    conn = get_conn()
    try:
        rows = conn.execute(
            """
            SELECT ai.id AS instance_id, ai.status AS instance_status, ai.assigned_at, ai.started_at, ai.ends_at, ai.submitted_at,
                   a.id AS assessment_id, a.title, a.difficulty, a.num_questions, a.duration_seconds, a.start_at, a.end_at, a.created_at
            FROM assessment_instances ai
            JOIN assessments a ON a.id=ai.assessment_id
            WHERE ai.student_id=?
            ORDER BY a.created_at DESC, ai.id DESC;
            """,
            (student_id,),
        ).fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()


def get_instance(instance_id: int, student_id: int):
    conn = get_conn()
    try:
        row = conn.execute(
            """
            SELECT ai.*, a.title, a.difficulty, a.num_questions, a.duration_seconds, a.start_at AS assessment_start_at, a.end_at AS assessment_end_at, a.id AS assessment_id
            FROM assessment_instances ai
            JOIN assessments a ON a.id=ai.assessment_id
            WHERE ai.id=? AND ai.student_id=?;
            """,
            (instance_id, student_id),
        ).fetchone()
        return dict(row) if row else None
    finally:
        conn.close()


def instance_questions(instance_id: int):
    conn = get_conn()
    try:
        rows = conn.execute(
            """
            SELECT iq.order_index, q.*
            FROM instance_questions iq
            JOIN questions q ON q.id=iq.question_id
            WHERE iq.instance_id=?
            ORDER BY iq.order_index;
            """,
            (instance_id,),
        ).fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()


def instance_questions_brief(instance_id: int):
    conn = get_conn()
    try:
        rows = conn.execute(
            """
            SELECT iq.order_index, q.id AS question_id, q.prompt, q.difficulty, q.topic_id
            FROM instance_questions iq
            JOIN questions q ON q.id=iq.question_id
            WHERE iq.instance_id=?
            ORDER BY iq.order_index;
            """,
            (instance_id,),
        ).fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()


def latest_autosave_map(instance_id: int):
    conn = get_conn()
    try:
        rows = conn.execute(
            """
            SELECT question_id, answer_text, time_spent_sec, ms_first_response, hint_count, attempts, drawing_png_b64, pred_confidence, pred_topk_json, saved_at
            FROM answers
            WHERE instance_id=? AND is_final=0;
            """,
            (instance_id,),
        ).fetchall()
        return {int(r["question_id"]): dict(r) for r in rows}
    finally:
        conn.close()


def final_answers_map(instance_id: int):
    conn = get_conn()
    try:
        rows = conn.execute(
            """
            SELECT question_id, answer_text, time_spent_sec, ms_first_response, hint_count, attempts, drawing_png_b64, pred_confidence, pred_topk_json, saved_at
            FROM answers
            WHERE instance_id=? AND is_final=1;
            """,
            (instance_id,),
        ).fetchall()
        return {int(r["question_id"]): dict(r) for r in rows}
    finally:
        conn.close()


def can_start_instance(instance_row: dict) -> tuple[bool, str]:
    nowu = now_utc_dt()
    startu = utc_z_to_dt(instance_row.get("assessment_start_at"))
    endu = utc_z_to_dt(instance_row.get("assessment_end_at"))
    if instance_row.get("status") != "assigned":
        return False, "Not in assigned state"
    if startu and nowu < startu:
        return False, "Assessment not started yet"
    if endu and nowu >= endu:
        return False, "Assessment window ended"
    return True, ""


def start_instance(instance_id: int, student_id: int) -> dict:
    conn = get_conn()
    try:
        row = conn.execute(
            """
            SELECT ai.id, ai.status, ai.started_at, ai.ends_at, ai.student_id,
                   a.duration_seconds, a.start_at AS assessment_start_at, a.end_at AS assessment_end_at
            FROM assessment_instances ai
            JOIN assessments a ON a.id=ai.assessment_id
            WHERE ai.id=? AND ai.student_id=?;
            """,
            (instance_id, student_id),
        ).fetchone()
        if not row:
            raise ValueError("Instance not found")

        inst = dict(row)
        ok, reason = can_start_instance(inst)
        if not ok:
            raise ValueError(reason)

        nowu = now_utc_dt()
        nowz = utc_to_z(nowu)
        dur = int(inst["duration_seconds"])
        computed_end = nowu + timedelta(seconds=dur)

        assessment_end = utc_z_to_dt(inst.get("assessment_end_at"))
        if assessment_end:
            computed_end = min(computed_end, assessment_end)

        conn.execute(
            """
            UPDATE assessment_instances
            SET started_at=?, ends_at=?, status='in_progress'
            WHERE id=? AND student_id=? AND status='assigned';
            """,
            (nowz, utc_to_z(computed_end), instance_id, student_id),
        )
        conn.commit()
        return get_instance(instance_id, student_id) or {}
    finally:
        conn.close()


def can_save_instance(instance_id: int, student_id: int) -> tuple[bool, str, dict | None]:
    inst = get_instance(instance_id, student_id)
    if not inst:
        return False, "Instance not found", None
    if inst.get("status") != "in_progress":
        return False, "Not in progress", inst
    ends = utc_z_to_dt(inst.get("ends_at"))
    if not ends:
        return False, "No ends_at set", inst
    if now_utc_dt() >= ends:
        return False, "Time is up", inst
    return True, "", inst


def upsert_autosave(
    instance_id: int,
    student_id: int,
    question_id: int,
    answer_text: str | None,
    add_time_sec: float = 0.0,
    ms_first_response: int | None = None,
    hint_count: int | None = None,
    attempts: int | None = None,
    drawing_png_b64: str | None = None,
    pred_confidence: float | None = None,
    pred_topk_json: str | None = None,
) -> bool:
    ok, _, _ = can_save_instance(instance_id, student_id)
    if not ok:
        return False

    conn = get_conn()
    try:
        nowz = utc_to_z(now_utc_dt())
        if answer_text is None:
            conn.execute(
                """
                INSERT INTO answers(
                    instance_id, question_id, answer_text, is_final,
                    time_spent_sec, ms_first_response, hint_count, attempts,
                    drawing_png_b64, pred_confidence, pred_topk_json, saved_at
                )
                VALUES(?,?, '', 0, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(instance_id, question_id, is_final) DO UPDATE SET
                    time_spent_sec = COALESCE(answers.time_spent_sec,0.0) + excluded.time_spent_sec,
                    ms_first_response = COALESCE(excluded.ms_first_response, answers.ms_first_response),
                    hint_count = COALESCE(excluded.hint_count, answers.hint_count),
                    attempts = COALESCE(excluded.attempts, answers.attempts),
                    drawing_png_b64 = COALESCE(excluded.drawing_png_b64, answers.drawing_png_b64),
                    pred_confidence = COALESCE(excluded.pred_confidence, answers.pred_confidence),
                    pred_topk_json = COALESCE(excluded.pred_topk_json, answers.pred_topk_json),
                    saved_at = excluded.saved_at;
                """,
                (instance_id, question_id, float(add_time_sec), ms_first_response, hint_count, attempts, drawing_png_b64, pred_confidence, pred_topk_json, nowz),
            )
        else:
            conn.execute(
                """
                INSERT INTO answers(
                    instance_id, question_id, answer_text, is_final,
                    time_spent_sec, ms_first_response, hint_count, attempts,
                    drawing_png_b64, pred_confidence, pred_topk_json, saved_at
                )
                VALUES(?,?, ?, 0, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(instance_id, question_id, is_final) DO UPDATE SET
                    answer_text = excluded.answer_text,
                    time_spent_sec = COALESCE(answers.time_spent_sec,0.0) + excluded.time_spent_sec,
                    ms_first_response = COALESCE(excluded.ms_first_response, answers.ms_first_response),
                    hint_count = COALESCE(excluded.hint_count, answers.hint_count),
                    attempts = COALESCE(excluded.attempts, answers.attempts),
                    drawing_png_b64 = COALESCE(excluded.drawing_png_b64, answers.drawing_png_b64),
                    pred_confidence = COALESCE(excluded.pred_confidence, answers.pred_confidence),
                    pred_topk_json = COALESCE(excluded.pred_topk_json, answers.pred_topk_json),
                    saved_at = excluded.saved_at;
                """,
                (instance_id, question_id, answer_text, float(add_time_sec), ms_first_response, hint_count, attempts, drawing_png_b64, pred_confidence, pred_topk_json, nowz),
            )
        conn.commit()
        return True
    finally:
        conn.close()


def finalize_answers(conn, instance_id: int):
    nowz = utc_to_z(now_utc_dt())
    qrows = conn.execute(
        "SELECT question_id FROM instance_questions WHERE instance_id=? ORDER BY order_index;",
        (instance_id,),
    ).fetchall()
    for r in qrows:
        qid = int(r["question_id"])
        auto = conn.execute(
            "SELECT answer_text, time_spent_sec, ms_first_response, hint_count, attempts, drawing_png_b64, pred_confidence, pred_topk_json FROM answers WHERE instance_id=? AND question_id=? AND is_final=0;",
            (instance_id, qid),
        ).fetchone()
        ans_text = (auto["answer_text"] if auto else "") or ""
        tsec = float(auto["time_spent_sec"] if auto else 0.0)
        msfr = (auto["ms_first_response"] if auto else None)
        hc = int((auto["hint_count"] or 0) if auto else 0)
        att = int((auto["attempts"] or 1) if auto else 1)
        dp = (auto["drawing_png_b64"] if auto else None)
        pc = (auto["pred_confidence"] if auto else None)
        tk = (auto["pred_topk_json"] if auto else None)
        conn.execute(
            """
            INSERT INTO answers(
                instance_id, question_id, answer_text, is_final,
                time_spent_sec, ms_first_response, hint_count, attempts, drawing_png_b64, pred_confidence, pred_topk_json, saved_at
            )
            VALUES(?,?, ?, 1, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(instance_id, question_id, is_final) DO UPDATE SET
                answer_text=excluded.answer_text,
                time_spent_sec=excluded.time_spent_sec,
                ms_first_response=excluded.ms_first_response,
                hint_count=excluded.hint_count,
                attempts=excluded.attempts,
                drawing_png_b64=excluded.drawing_png_b64,
                pred_confidence=excluded.pred_confidence,
                pred_topk_json=excluded.pred_topk_json,
                saved_at=excluded.saved_at;
            """,
            (instance_id, qid, ans_text, tsec, msfr, hc, att, dp, pc, tk, nowz),
        )


def finalize_answer(conn, instance_id: int, question_id: int):
    """Finalize only one question (used in adaptive sessions)."""
    nowz = utc_to_z(now_utc_dt())
    auto = conn.execute(
        "SELECT answer_text, time_spent_sec, ms_first_response, hint_count, attempts, drawing_png_b64, pred_confidence, pred_topk_json FROM answers WHERE instance_id=? AND question_id=? AND is_final=0;",
        (instance_id, question_id),
    ).fetchone()
    ans_text = (auto["answer_text"] if auto else "") or ""
    tsec = float(auto["time_spent_sec"] if auto else 0.0)
    msfr = (auto["ms_first_response"] if auto else None)
    hc = int((auto["hint_count"] or 0) if auto else 0)
    att = int((auto["attempts"] or 1) if auto else 1)
    dp = (auto["drawing_png_b64"] if auto else None)
    pc = (auto["pred_confidence"] if auto else None)
    tk = (auto["pred_topk_json"] if auto else None)
    conn.execute(
        """
        INSERT INTO answers(
            instance_id, question_id, answer_text, is_final,
            time_spent_sec, ms_first_response, hint_count, attempts, drawing_png_b64, pred_confidence, pred_topk_json, saved_at
        )
        VALUES(?,?, ?, 1, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(instance_id, question_id, is_final) DO UPDATE SET
            answer_text=excluded.answer_text,
            time_spent_sec=excluded.time_spent_sec,
            ms_first_response=excluded.ms_first_response,
            hint_count=excluded.hint_count,
            attempts=excluded.attempts,
            drawing_png_b64=excluded.drawing_png_b64,
            pred_confidence=excluded.pred_confidence,
            pred_topk_json=excluded.pred_topk_json,
            saved_at=excluded.saved_at;
        """,
        (instance_id, question_id, ans_text, tsec, msfr, hc, att, dp, pc, tk, nowz),
    )


def submit_instance(instance_id: int, student_id: int, auto: bool = False):
    conn = get_conn()
    try:
        inst = conn.execute(
            "SELECT * FROM assessment_instances WHERE id=? AND student_id=?;",
            (instance_id, student_id),
        ).fetchone()
        if not inst:
            raise ValueError("Instance not found")
        if inst["status"] != "in_progress":
            raise ValueError("Instance not in progress")

        nowz = utc_to_z(now_utc_dt())
        new_status = "auto_submitted" if auto else "submitted"

        conn.execute(
            "UPDATE assessment_instances SET status=?, submitted_at=? WHERE id=? AND student_id=?;",
            (new_status, nowz, instance_id, student_id),
        )

        finalize_answers(conn, instance_id)
        grade_instance(conn, instance_id)

        conn.execute(
            "UPDATE assessment_instances SET status='graded' WHERE id=?;",
            (instance_id,),
        )

        conn.commit()
    finally:
        conn.close()


# -------------------- Teacher: remove/replace question from a test instance --------------------

def teacher_replace_or_remove_instance_question(teacher_id: int, instance_id: int, old_question_id: int, action: str) -> tuple[bool, str]:
    """
    action: 'remove' or 'replace'
    Allowed only if instance status is 'assigned' and belongs to teacher.
    """
    if action not in ("remove", "replace"):
        return False, "Invalid action"

    conn = get_conn()
    try:
        row = conn.execute(
            """
            SELECT ai.id AS instance_id, ai.status, ai.seed,
                   a.id AS assessment_id, a.difficulty,
                   a.teacher_id
            FROM assessment_instances ai
            JOIN assessments a ON a.id=ai.assessment_id
            WHERE ai.id=?;
            """,
            (instance_id,),
        ).fetchone()
        if not row:
            return False, "Instance not found"
        if int(row["teacher_id"]) != int(teacher_id):
            return False, "Access denied"
        if row["status"] != "assigned":
            return False, "Only editable while status='assigned' (before student starts)."

        # find order_index of old question
        old = conn.execute(
            "SELECT order_index FROM instance_questions WHERE instance_id=? AND question_id=?;",
            (instance_id, old_question_id),
        ).fetchone()
        if not old:
            return False, "Question not found in instance"
        old_order = int(old["order_index"])

        # current qids in instance
        current = conn.execute(
            "SELECT question_id FROM instance_questions WHERE instance_id=?;",
            (instance_id,),
        ).fetchall()
        current_qids = {int(r["question_id"]) for r in current}

        # remove old
        conn.execute("DELETE FROM instance_questions WHERE instance_id=? AND question_id=?;", (instance_id, old_question_id))
        conn.execute("DELETE FROM answers WHERE instance_id=? AND question_id=?;", (instance_id, old_question_id))
        conn.execute("DELETE FROM grading_results WHERE instance_id=? AND question_id=?;", (instance_id, old_question_id))

        if action == "replace":
            # topics for assessment
            tops = conn.execute(
                "SELECT topic_id FROM assessment_topics WHERE assessment_id=?;",
                (int(row["assessment_id"]),),
            ).fetchall()
            topic_ids = [int(r["topic_id"]) for r in tops]
            if not topic_ids:
                return False, "Assessment has no topics (assessment_topics missing)."

            placeholders = ",".join(["?"] * len(topic_ids))
            pool = conn.execute(
                f"""
                SELECT id FROM questions
                WHERE is_active=1 AND difficulty=?
                  AND topic_id IN ({placeholders})
                """,
                tuple([row["difficulty"]] + topic_ids),
            ).fetchall()
            pool_ids = [int(r["id"]) for r in pool if int(r["id"]) not in current_qids and int(r["id"]) != int(old_question_id)]
            if not pool_ids:
                # rollback by re-inserting old question to keep instance valid
                conn.execute(
                    "INSERT INTO instance_questions(instance_id, question_id, order_index) VALUES(?,?,?);",
                    (instance_id, old_question_id, old_order),
                )
                conn.commit()
                return False, "No replacement question available in pool (not already used)."

            rng = random.Random(int(row["seed"] or 1))
            new_qid = rng.choice(pool_ids)

            conn.execute(
                "INSERT INTO instance_questions(instance_id, question_id, order_index) VALUES(?,?,?);",
                (instance_id, new_qid, old_order),
            )

        # reindex order_index to be 1..n (keeps consistent navigation)
        rows = conn.execute(
            "SELECT id FROM instance_questions WHERE instance_id=? ORDER BY order_index;",
            (instance_id,),
        ).fetchall()
        for idx, r in enumerate(rows, start=1):
            conn.execute("UPDATE instance_questions SET order_index=? WHERE id=?;", (idx, int(r["id"])))

        conn.commit()
        return True, "Updated instance questions successfully."
    finally:
        conn.close()


# -------------------- Review helpers --------------------

def instance_review(instance_id: int, student_id: int):
    conn = get_conn()
    try:
        ok = conn.execute(
            "SELECT 1 FROM assessment_instances WHERE id=? AND student_id=?;",
            (instance_id, student_id),
        ).fetchone()
        if not ok:
            return []

        rows = conn.execute(
            """
            SELECT iq.order_index,
                   q.id AS question_id, q.prompt, q.correct_answer, q.answer_type, q.tolerance, q.points, q.choices_json,
                   fa.answer_text AS student_answer,
                   gr.is_correct, gr.score, gr.feedback
            FROM instance_questions iq
            JOIN questions q ON q.id=iq.question_id
            LEFT JOIN answers fa ON fa.instance_id=iq.instance_id AND fa.question_id=q.id AND fa.is_final=1
            LEFT JOIN grading_results gr ON gr.instance_id=iq.instance_id AND gr.question_id=q.id
            WHERE iq.instance_id=?
            ORDER BY iq.order_index;
            """,
            (instance_id,),
        ).fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()


def results_for_student(student_id: int):
    conn = get_conn()
    try:
        rows = conn.execute(
            """
            SELECT ra.*, a.title, a.difficulty
            FROM results_analytics ra
            JOIN assessment_instances ai ON ai.id=ra.instance_id
            JOIN assessments a ON a.id=ai.assessment_id
            WHERE ra.student_id=?
            ORDER BY ra.computed_at DESC;
            """,
            (student_id,),
        ).fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()


def mastery_for_student(student_id: int):
    conn = get_conn()
    try:
        rows = conn.execute(
            """
            SELECT stm.topic_id, t.name AS topic_name, stm.p_knowledge, stm.n_obs, stm.updated_at
            FROM student_topic_mastery stm
            JOIN topics t ON t.id=stm.topic_id
            WHERE stm.student_id=?
            ORDER BY t.name;
            """,
            (student_id,),
        ).fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()


def engagement_signals_for_student(student_id: int):
    conn = get_conn()
    try:
        rows = conn.execute(
            """
            SELECT
                t.name AS topic,
                ROUND(AVG(a.frustrated_score), 3) AS avg_frustrated,
                ROUND(AVG(a.confused_score),   3) AS avg_confused,
                COUNT(*) AS n_answers
            FROM answers a
            JOIN instance_questions iq ON iq.instance_id = a.instance_id
                                       AND iq.question_id = a.question_id
            JOIN questions q ON q.id = iq.question_id
            JOIN topics t ON t.id = q.topic_id
            JOIN assessment_instances ai ON ai.id = a.instance_id
            WHERE ai.student_id = ? AND a.is_final = 1
            GROUP BY t.name
            ORDER BY avg_frustrated DESC;
            """,
            (student_id,),
        ).fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()


# -------------------- Student-safe read projections --------------------
def student_instance_questions(instance_id: int, student_id: int):
    """Return only fields required to render a student's assessment.

    Deliberately excludes correct_answer and verifies instance ownership.
    """
    conn = get_conn()
    try:
        rows = conn.execute(
            """
            SELECT iq.order_index,
                   q.id AS question_id,
                   q.topic_id,
                   t.name AS topic_name,
                   q.difficulty,
                   q.prompt,
                   q.hint_text,
                   q.choices_json,
                   q.input_mode,
                   q.answer_type,
                   q.tolerance,
                   q.points
            FROM instance_questions iq
            JOIN assessment_instances ai ON ai.id=iq.instance_id
            JOIN questions q ON q.id=iq.question_id
            JOIN topics t ON t.id=q.topic_id
            WHERE iq.instance_id=? AND ai.student_id=?
            ORDER BY iq.order_index;
            """,
            (instance_id, student_id),
        ).fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()


def student_latest_autosave_map(instance_id: int, student_id: int):
    """Return autosaves only when the instance belongs to the requesting student."""
    conn = get_conn()
    try:
        rows = conn.execute(
            """
            SELECT a.question_id, a.answer_text, a.time_spent_sec, a.ms_first_response,
                   a.hint_count, a.attempts, a.saved_at
            FROM answers a
            JOIN assessment_instances ai ON ai.id=a.instance_id
            WHERE a.instance_id=? AND ai.student_id=? AND a.is_final=0;
            """,
            (instance_id, student_id),
        ).fetchall()
        return {int(r["question_id"]): dict(r) for r in rows}
    finally:
        conn.close()
