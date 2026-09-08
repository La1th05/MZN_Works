import random
import sqlite3
import time
from datetime import datetime, timezone, timedelta
from pathlib import Path
import sys
sys.stdout.reconfigure(encoding='utf-8')
DB_PATH = r"c:\projects\MZN_Works\MZN\tamkeen\smart_lms\data\lms.db"

def nowz(offset_days=0):
    dt = datetime.now(timezone.utc) - timedelta(days=offset_days)
    return dt.isoformat().replace("+00:00", "Z")

def seed_demo_sessions():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON;")

    # Get students and topics
    students = conn.execute(
        "SELECT id, display_name FROM users WHERE role='student';"
    ).fetchall()
    topics = conn.execute(
        "SELECT id, name FROM topics WHERE is_active=1 LIMIT 4;"
    ).fetchall()
    teacher = conn.execute(
        "SELECT id FROM users WHERE role='teacher' LIMIT 1;"
    ).fetchone()

    if not students or not topics or not teacher:
        print("[ERROR] Run seed.py first.")
        return

    # Student learning profiles: how they improve over sessions
    profiles = {
        0: {"name": "Struggling to improving", "start_acc": 0.2, "growth": 0.12},
        1: {"name": "Already good",            "start_acc": 0.7, "growth": 0.05},
        2: {"name": "Inconsistent",            "start_acc": 0.4, "growth": 0.07},
    }

    for s_idx, student in enumerate(students[:3]):
        sid = int(student["id"])
        profile = profiles[s_idx]
        print(f"\n[INFO] Seeding sessions for: {student['display_name']} ({profile['name']})")

        for session_num in range(6):  # 6 sessions per student
            # Accuracy improves each session
            accuracy = min(
                profile["start_acc"] + profile["growth"] * session_num + random.uniform(-0.05, 0.05),
                0.95
            )
            topic = topics[session_num % len(topics)]
            tid = int(topic["id"])
            days_ago = 12 - (session_num * 2)  # Sessions spread over 12 days

            # Get questions for this topic
            questions = conn.execute(
                "SELECT id, correct_answer, answer_type, tolerance, points FROM questions "
                "WHERE topic_id=? AND is_active=1 LIMIT 5;",
                (tid,)
            ).fetchall()

            if not questions:
                continue

            # Create assessment
            cur = conn.execute(
                """INSERT INTO assessments(teacher_id, title, topic_id, difficulty, 
                   num_questions, duration_seconds, status, created_at)
                   VALUES(?,?,?,?,?,?,?,?)""",
                (int(teacher["id"]), f"Session {session_num+1} - {topic['name']}",
                 tid, "Easy", len(questions), 600, "active", nowz(days_ago))
            )
            assessment_id = cur.lastrowid

            conn.execute(
                "INSERT INTO assessment_topics(assessment_id, topic_id) VALUES(?,?)",
                (assessment_id, tid)
            )

            # Create instance
            started = nowz(days_ago)
            ended = nowz(days_ago)
            cur2 = conn.execute(
                """INSERT INTO assessment_instances(assessment_id, student_id, assigned_at,
                   started_at, ends_at, submitted_at, status, seed)
                   VALUES(?,?,?,?,?,?,'graded',?)""",
                (assessment_id, sid, started, started, ended, ended, session_num * 42)
            )
            instance_id = cur2.lastrowid

            # Assign and answer questions
            for order, q in enumerate(questions):
                qid = int(q["id"])
                conn.execute(
                    "INSERT OR IGNORE INTO instance_questions(instance_id, question_id, order_index) VALUES(?,?,?)",
                    (instance_id, qid, order)
                )

                is_correct = 1 if random.random() < accuracy else 0
                answer_text = q["correct_answer"] if is_correct else "99999"

                # Behavioral signals: struggling students are slower and retry more
                if is_correct:
                    ms_first = random.randint(3000, 15000)
                    attempts = 1
                else:
                    ms_first = random.randint(500, 8000)
                    attempts = random.randint(1, 4)

                hint_count = random.randint(0, 2) if not is_correct else 0

                conn.execute(
                    """INSERT OR IGNORE INTO answers(instance_id, question_id, answer_text,
                       is_final, time_spent_sec, ms_first_response, hint_count, attempts)
                       VALUES(?,?,?,1,?,?,?,?)""",
                    (instance_id, qid, answer_text,
                     random.uniform(5, 45), ms_first, hint_count, attempts)
                )

                score = float(q["points"]) if is_correct else 0.0
                conn.execute(
                    """INSERT OR IGNORE INTO grading_results(instance_id, question_id,
                       is_correct, score, feedback, graded_at)
                       VALUES(?,?,?,?,?,?)""",
                    (instance_id, qid, is_correct, score,
                     "Correct." if is_correct else "Incorrect.", nowz(days_ago))
                )

            # Compute engagement signals and mastery
            from services.analytics import compute_engagement_signals, update_student_mastery_pybkt, _recommend_for_topic
            import json

            answers = conn.execute(
                "SELECT question_id, ms_first_response, hint_count, attempts FROM answers "
                "WHERE instance_id=? AND is_final=1", (instance_id,)
            ).fetchall()

            grades = conn.execute(
                "SELECT question_id, is_correct FROM grading_results WHERE instance_id=?",
                (instance_id,)
            ).fetchall()
            grade_map = {int(g["question_id"]): int(g["is_correct"]) for g in grades}

            total_score = 0.0
            total_q = len(questions)
            correct_count = 0

            for a in answers:
                qid2 = int(a["question_id"])
                ic = grade_map.get(qid2, 0)
                correct_count += ic
                frustrated, confused = compute_engagement_signals(
                    ms_response=a["ms_first_response"],
                    hint_count=a["hint_count"],
                    attempts=a["attempts"],
                    is_correct=ic,
                )
                conn.execute(
                    "UPDATE answers SET frustrated_score=?, confused_score=? "
                    "WHERE instance_id=? AND question_id=? AND is_final=1",
                    (frustrated, confused, instance_id, qid2)
                )
                q_row = conn.execute("SELECT points FROM questions WHERE id=?", (qid2,)).fetchone()
                if q_row and ic:
                    total_score += float(q_row["points"])

            acc = correct_count / total_q if total_q else 0.0
            bkt_mastery, n_obs = update_student_mastery_pybkt(conn, sid, tid, topic["name"])
            rec = _recommend_for_topic(topic["name"], bkt_mastery, n_obs)

            topic_summary = [{
                "topic_id": tid, "topic_name": topic["name"],
                "earned": total_score, "possible": float(sum(q["points"] for q in questions)),
                "x": acc, "mastery": bkt_mastery, "n_obs": n_obs
            }]

            conn.execute(
                """INSERT OR REPLACE INTO results_analytics(instance_id, student_id, total_score,
                   accuracy, computed_at, topic_id, topics_json, model_recommendation)
                   VALUES(?,?,?,?,?,?,?,?)""",
                (instance_id, sid, total_score, acc, nowz(days_ago),
                 tid, json.dumps(topic_summary), rec)
            )

            print(f"  Session {session_num+1}: acc={acc:.2f} | BKT P(L)={bkt_mastery:.3f} | rec={rec[:50]}")

    conn.commit()
    conn.close()
    print("\n[DONE] Demo data seeded.")

if __name__ == "__main__":
    seed_demo_sessions()