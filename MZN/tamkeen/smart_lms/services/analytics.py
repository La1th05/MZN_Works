import json
import math
from datetime import datetime, timezone
from zoneinfo import ZoneInfo
import pandas as pd
import joblib
from pathlib import Path

TZ_JORDAN = ZoneInfo("Asia/Amman")

def compute_engagement_signals( ms_response:int,hint_count:int ,attempts:int, is_correct:bool):
    ms  = float(ms_response or 0)
    hc  = float(hint_count or 0)
    att = float(attempts or 1)
    
    attempt_signal = min((att - 1) / 4.0, 1.0) #number of attempts capped at 4s
    time_signal = min(ms / 60_000.0, 1.0) #response time over 10s contributes (capped at 60s)
    
    frustrated = round((attempt_signal * 0.7 + time_signal * 0.3), 4)
    
    if is_correct:
        confused=0
    else :
         # responded very fast (under 5s) → likely a guess
        fast_signal = max(0.0, 1.0 - ms / 5_000.0) if ms > 0 else 1.0
        # used no hints despite being wrong → didn't seek help
        no_hint_signal = 1.0 if hc == 0 else 0.0
        confused = round((fast_signal * 0.6 + no_hint_signal * 0.4), 4)
    
    return (frustrated,confused)

def _nowz() -> str:
    dt = datetime.now(timezone.utc).replace(microsecond=0)
    return dt.isoformat().replace("+00:00", "Z")

def _normalize_exact(s: str) -> str:
    return (s or "").strip().lower()

def _safe_float(s: str):
    try:
        return float(str(s).strip())
    except Exception:
        return None

# ==========================================
# 🧠 PyBKT Model Loading
# ==========================================
_MODEL_CANDIDATES = [
    Path(__file__).resolve().parent / "dyscalculia_master_model_best.pkl",
    Path(__file__).resolve().parent / "services" / "dyscalculia_master_model_best.pkl",
    Path("services") / "dyscalculia_master_model_best.pkl",
]

BKT_MODEL = None
for _p in _MODEL_CANDIDATES:
    try:
        if _p.exists():
            BKT_MODEL = joblib.load(str(_p))
            print(f"model loded from {_p}")
            break
    except Exception:
        print(f"model did not loaded from {_p}")
        BKT_MODEL = None



def update_student_mastery_pybkt(conn, student_id: int, topic_id: int, topic_name: str):
    """Calculates mastery P(L) using the pyBKT model.

    Observations are taken from grading_results (correct/incorrect) joined with
    the finalized behavioral metrics stored in answers (ms_first_response, hint_count, attempts).
    """
    nowz = _nowz()
    
    rows = conn.execute(
        """
        SELECT
            gr.id AS order_id,
            gr.is_correct AS correct,
            fa.ms_first_response,
            fa.hint_count,
            fa.attempts
        FROM grading_results gr
        JOIN assessment_instances ai ON ai.id=gr.instance_id
        JOIN questions q ON q.id=gr.question_id
        LEFT JOIN answers fa
               ON fa.instance_id=gr.instance_id AND fa.question_id=gr.question_id AND fa.is_final=1
        WHERE ai.student_id=? AND q.topic_id=?
        ORDER BY gr.graded_at ASC, gr.id ASC;
        """,
        (student_id, topic_id),
    ).fetchall()
    
    n_obs = len(rows)
    current_mastery = 0.3  # Default starting mastery
    
    if rows and BKT_MODEL:
        history_data = []
        for row in rows:
            ms = int(row["ms_first_response"] or 0)
            hc = int(row["hint_count"] or 0)
            att = int(row["attempts"] or 1)
            
            history_data.append({
                'order_id': row['order_id'],
                'user_id': student_id,
                'skill': topic_name,
                'correct': 1 if int(row['correct'] or 0) else 0,
                'time_and_hint': ms * hc,
                'many_attempts': 1 if att > 2 else 0
            })
            
        df = pd.DataFrame(history_data)
        
        try:
            predictions_df = BKT_MODEL.predict(data=df)
            current_mastery = float(predictions_df.iloc[-1]['state_predictions'])
        except Exception as e :
            import traceback 
            print(f"[BKT FALLBACK] student = {student_id} topic {topic_id} error {e}")
            
            print (traceback.format_exc())
            current_mastery=0.3
            
    # Update Database with new BKT state (p_knowledge)
    conn.execute('''
        INSERT INTO student_topic_mastery (student_id, topic_id, p_knowledge, n_obs, updated_at)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(student_id, topic_id) 
        DO UPDATE SET p_knowledge=excluded.p_knowledge, n_obs=excluded.n_obs, updated_at=excluded.updated_at
    ''', (student_id, topic_id, current_mastery, n_obs, nowz))
    
    return current_mastery, n_obs


def get_adaptive_difficulty(p_knowledge: float) -> str:
    """Productive struggle framework: adapts difficulty to keep student engaged."""
    if p_knowledge < 0.40:
        return 'Easy'
    elif p_knowledge > 0.75:
        return 'Hard'
    else:
        return 'Medium'

def grade_question(answer_text: str, correct_answer: str, answer_type: str, tolerance: float, points: float):
    ans = answer_text or ""
    corr = correct_answer or ""
    tol = float(tolerance or 0.0)
    pts = float(points or 1.0)

    is_correct = 0
    feedback = ""

    if answer_type == "numeric":
        a = _safe_float(ans)
        c = _safe_float(corr)
        if a is None or c is None:
            is_correct = 0
            feedback = "Numeric answer required."
        else:
            is_correct = 1 if abs(a - c) <= tol else 0
            feedback = "Correct." if is_correct else f"Incorrect. |a-c|={abs(a-c):.6g} > tol={tol:.6g}"
    else:
        is_correct = 1 if _normalize_exact(ans) == _normalize_exact(corr) else 0
        feedback = "Correct." if is_correct else "Incorrect."

    score = pts if is_correct else 0.0
    return is_correct, score, feedback


def _update_question_stats(conn, question_id: int, is_correct: int, time_spent_sec: float):
    nowz = _nowz()
    row = conn.execute(
        "SELECT n_attempts, n_correct, avg_time_sec FROM question_stats WHERE question_id=?;",
        (question_id,),
    ).fetchone()

    t = float(time_spent_sec or 0.0)
    if row:
        n_attempts = int(row["n_attempts"] or 0)
        n_correct = int(row["n_correct"] or 0)
        avg_time = float(row["avg_time_sec"] or 0.0)

        new_n_attempts = n_attempts + 1
        new_n_correct = n_correct + int(is_correct)
        new_avg_time = (avg_time * n_attempts + t) / new_n_attempts if new_n_attempts > 0 else t

        conn.execute(
            """
            UPDATE question_stats
            SET n_attempts=?, n_correct=?, avg_time_sec=?, updated_at=?
            WHERE question_id=?;
            """,
            (new_n_attempts, new_n_correct, float(new_avg_time), nowz, question_id),
        )
    else:
        conn.execute(
            """
            INSERT INTO question_stats(question_id, n_attempts, n_correct, avg_time_sec, updated_at)
            VALUES(?, 1, ?, ?, ?);
            """,
            (question_id, int(is_correct), float(t), nowz),
        )


def _topics_used(conn, assessment_id: int):
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

    if rows:
        return [{"id": int(r["topic_id"]), "name": r["name"]} for r in rows]

    # legacy fallback
    row = conn.execute("SELECT topic_id FROM assessments WHERE id=?;", (assessment_id,)).fetchone()
    if row and row["topic_id"]:
        t = conn.execute("SELECT id, name FROM topics WHERE id=?;", (row["topic_id"],)).fetchone()
        if t:
            return [{"id": int(t["id"]), "name": t["name"]}]
    return []


def _recommend_for_topic(topic_name: str, mastery: float, n_obs: int):
    # Confidence calculation based on number of observations
    c = 1.0 - math.exp(-n_obs / 5.0)
    
    if c < 0.35:
        return f"{topic_name}: Insufficient evidence to model knowledge; complete more exercises."
    if mastery >= 0.85:
        return f"{topic_name}: Student Mastered Topic — Ready for harder difficulty."
    if mastery <= 0.60:
        return f"{topic_name}: Low mastery detected — Student needs more practice and targeted support."
    return f"{topic_name}: Progressing — Keep practicing to solidify knowledge."


# ==========================================
# 🏆 Main Grading Pipeline
# ==========================================
def grade_instance(conn, instance_id: int):
    nowz = _nowz()

    inst = conn.execute(
        """
        SELECT ai.id, ai.student_id, ai.assessment_id
        FROM assessment_instances ai
        WHERE ai.id=?;
        """,
        (instance_id,),
    ).fetchone()
    
    if not inst:
        raise ValueError("Instance not found for grading")

    student_id = int(inst["student_id"])
    assessment_id = int(inst["assessment_id"])

    rows = conn.execute(
        """
        SELECT iq.order_index,
               q.id AS question_id, q.topic_id, q.answer_type, q.tolerance, q.points, q.correct_answer,
               fa.answer_text AS student_answer, fa.time_spent_sec
        FROM instance_questions iq
        JOIN questions q ON q.id=iq.question_id
        LEFT JOIN answers fa ON fa.instance_id=iq.instance_id AND fa.question_id=q.id AND fa.is_final=1
        WHERE iq.instance_id=?
        ORDER BY iq.order_index;
        """,
        (instance_id,),
    ).fetchall()

    if not rows:
        raise ValueError("No questions on instance")

    total_questions = len(rows)
    correct_count = 0
    total_score = 0.0

    per_topic = {}  
    topic_lookup = {t["id"]: t["name"] for t in _topics_used(conn, assessment_id)}
    
    missing_topic_ids = set(int(r["topic_id"]) for r in rows) - set(topic_lookup.keys())
    if missing_topic_ids:
        q = f"SELECT id, name FROM topics WHERE id IN ({','.join(['?']*len(missing_topic_ids))});"
        for tr in conn.execute(q, tuple(missing_topic_ids)).fetchall():
            topic_lookup[int(tr["id"])] = tr["name"]

    for r in rows:
        qid = int(r["question_id"])
        tid = int(r["topic_id"])
        ans = (r["student_answer"] or "")
        corr = (r["correct_answer"] or "")
        atype = (r["answer_type"] or "exact")
        tol = float(r["tolerance"] or 0.0)
        pts = float(r["points"] or 1.0)
        tsec = float(r["time_spent_sec"] or 0.0)

        is_correct, score, feedback = grade_question(ans, corr, atype, tol, pts)
        correct_count += int(is_correct)
        total_score += float(score)

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
            (instance_id, qid, int(is_correct), float(score), feedback, nowz),
        )

        _update_question_stats(conn, qid, int(is_correct), tsec)

        beh = conn.execute(
            """
            SELECT ms_first_response, hint_count, attempts
            FROM answers
            WHERE instance_id = ? AND question_id = ? AND is_final = 1;
            """,
            (instance_id, qid),
        ).fetchone()

        if beh:
            frustrated, confused = compute_engagement_signals(
                ms_response=beh["ms_first_response"],
                hint_count=beh["hint_count"],
                attempts=beh["attempts"],
                is_correct=int(is_correct),
            )
            conn.execute(
                """
                UPDATE answers
                SET frustrated_score = ?,
                    confused_score   = ?
                WHERE instance_id = ? AND question_id = ? AND is_final = 1;
                """,
                (frustrated, confused, instance_id, qid),
            )

        if tid not in per_topic:
            per_topic[tid] = {"earned": 0.0, "possible": 0.0, "name": topic_lookup.get(tid, f"Topic {tid}")}
        per_topic[tid]["earned"] += float(score)
        per_topic[tid]["possible"] += float(pts)
        
    accuracy = (correct_count / total_questions) if total_questions > 0 else 0.0

    # ==========================================
    # 🔥 BKT MASTERY INTEGRATION 
    # ==========================================
    topic_summaries = []
    updated_mastery = []
    
    for tid in sorted(per_topic.keys()):
        earned = per_topic[tid]["earned"]
        possible = per_topic[tid]["possible"]
        x = (earned / possible) if possible > 0 else 0.0 # Raw accuracy for summary 
        tname = per_topic[tid]["name"]

        # Run pyBKT calculation (replaces old EMA)
        bkt_mastery, n_obs = update_student_mastery_pybkt(conn, student_id, tid, tname)
        
        # Generate insight based on pyBKT state
        rec = _recommend_for_topic(tname, bkt_mastery, n_obs)
        
        topic_summaries.append({
            "topic_id": tid, 
            "topic_name": tname, 
            "earned": earned, 
            "possible": possible, 
            "x": x, 
            "mastery": bkt_mastery, 
            "n_obs": n_obs
        })
        updated_mastery.append((bkt_mastery, tname, tid, rec, n_obs))

    # Sort to find the weakest topic based on BKT
    updated_mastery.sort(key=lambda x: (x[0], x[1])) 
    weakest = updated_mastery[0]
    dominant_topic_id = int(weakest[2]) if updated_mastery else None

    if len(updated_mastery) == 1:
        model_rec = weakest[3]
    else:
        model_rec = "Weakest topic focus: " + weakest[3] + " | " + " | ".join([u[3] for u in updated_mastery])

    topics_json = json.dumps(topic_summaries, ensure_ascii=False)

    conn.execute(
        """
        INSERT INTO results_analytics(instance_id, student_id, total_score, accuracy, computed_at, topic_id, topics_json, model_recommendation)
        VALUES(?,?,?,?,?,?,?,?)
        ON CONFLICT(instance_id) DO UPDATE SET
            student_id=excluded.student_id,
            total_score=excluded.total_score,
            accuracy=excluded.accuracy,
            computed_at=excluded.computed_at,
            topic_id=excluded.topic_id,
            topics_json=excluded.topics_json,
            model_recommendation=excluded.model_recommendation;
        """,
        (instance_id, student_id, float(total_score), float(accuracy), nowz, dominant_topic_id, topics_json, model_rec),
    )