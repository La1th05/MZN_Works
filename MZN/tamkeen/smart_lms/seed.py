import json
import random

from services.db import init_db, get_conn
from services.auth import hash_password
from services.logic import utc_to_z, now_utc_dt

def upsert_user(conn, email, role, display_name, password_plain):
    email_n = email.strip().lower()
    nowz = utc_to_z(now_utc_dt())
    ph = hash_password(password_plain)

    row = conn.execute("SELECT id FROM users WHERE lower(email)=?;", (email_n,)).fetchone()
    if row:
        conn.execute(
            """
            UPDATE users
            SET role=?, display_name=?, password_hash=?, password=?, is_active=1, deleted_at=NULL
            WHERE id=?;
            """,
            (role, display_name, ph, None, int(row["id"])),
        )
        return int(row["id"])
    else:
        cur = conn.execute(
            """
            INSERT INTO users(email, password_hash, password, role, display_name, created_at, is_active)
            VALUES(?,?,?,?,?,?,1);
            """,
            (email_n, ph, None, role, display_name, nowz),
        )
        return int(cur.lastrowid)

def upsert_topic(conn, name):
    conn.execute("INSERT INTO topics(name, is_active) VALUES(?,1) ON CONFLICT(name) DO NOTHING;", (name,))
    row = conn.execute("SELECT id FROM topics WHERE name=?;", (name,)).fetchone()
    return int(row["id"])

def ensure_questions(conn, teacher_id, topic_id, topic_name):
    nowz = utc_to_z(now_utc_dt())
    difficulties = ["Easy", "Medium", "Hard"]

    for diff in difficulties:
        existing = conn.execute(
            "SELECT COUNT(*) AS n FROM questions WHERE topic_id=? AND difficulty=?;",
            (topic_id, diff),
        ).fetchone()["n"]

        need = max(0, 10 - int(existing))
        if need == 0:
            continue

        for i in range(need):
            # Updated to match PyBKT string
            if topic_name.startswith("Addition"):
                if diff == "Easy":
                    a, b = random.randint(1, 9), random.randint(1, 9)
                elif diff == "Medium":
                    a, b = random.randint(10, 99), random.randint(10, 99)
                else:
                    a, b = random.randint(100, 999), random.randint(100, 999)
                prompt = f"Compute: {a} + {b}"
                correct = str(a + b)
                atype = "numeric" if (i % 3 == 0) else "exact"
                tol = 0.0

                choices_json = None
                if diff == "Easy" and i % 2 == 0:
                    distractors = sorted({a + b, a + b + 1, a + b - 1, a + b + 2})
                    choices_json = json.dumps([str(x) for x in distractors], ensure_ascii=False)

                pts = 1.0 if diff == "Easy" else (2.0 if diff == "Medium" else 3.0)

            else:
                if diff == "Easy":
                    a, b = random.randint(1, 9), random.randint(0, 9)
                elif diff == "Medium":
                    a, b = random.randint(10, 99), random.randint(0, 99)
                else:
                    a, b = random.randint(100, 999), random.randint(0, 999)
                if b > a:
                    a, b = b, a
                prompt = f"Compute: {a} - {b}"
                correct = str(a - b)

                atype = "numeric" if (i % 4 == 0) else "exact"
                tol = 0.0

                choices_json = None
                if diff == "Easy" and i % 2 == 1:
                    distractors = sorted({a - b, a - b + 1, a - b - 1, a - b + 2})
                    choices_json = json.dumps([str(x) for x in distractors], ensure_ascii=False)

                pts = 1.0 if diff == "Easy" else (2.0 if diff == "Medium" else 3.0)

            conn.execute(
                """
                INSERT INTO questions(
                    topic_id, difficulty, prompt, correct_answer, choices_json,
                    answer_type, tolerance, points, is_active, created_by, created_at, updated_at
                ) VALUES (?,?,?,?,?,?,?,?,1,?,?,?);
                """,
                (topic_id, diff, prompt, correct, choices_json, atype, tol, pts, teacher_id, nowz, nowz),
            )

def ensure_demo_class_and_enrollments(conn, teacher_id, student_ids):
    nowz = utc_to_z(now_utc_dt())
    row = conn.execute(
        "SELECT id FROM classes WHERE teacher_id=? AND name=? AND year=?;",
        (teacher_id, "Demo Class", "2026"),
    ).fetchone()
    
    if row:
        class_id = int(row["id"])
        conn.execute("UPDATE classes SET is_active=1, deleted_at=NULL WHERE id=?;", (class_id,))
    else:
        cur = conn.execute(
            "INSERT INTO classes(teacher_id, name, year, created_at, is_active) VALUES(?,?,?,?,1);",
            (teacher_id, "Demo Class", "2026", nowz),
        )
        class_id = int(cur.lastrowid)

    for sid in student_ids:
        conn.execute(
            """
            INSERT INTO enrollments(class_id, student_id, status, enrolled_at)
            VALUES(?,?, 'active', ?)
            ON CONFLICT(class_id, student_id) DO UPDATE SET status='active';
            """,
            (class_id, sid, nowz),
        )
    return class_id

def main():
    init_db()
    conn = get_conn()
    
    try:
        # 1. Map all exact PyBKT Skills
        bkt_skills = [
            "Addition and Subtraction Integers", "Order of Operations All",
            "Multiplication and Division Positive Decimals", "Multiplication Fractions",
            "Equation Solving More Than Two Steps", "Division Fractions", "Ordering Fractions",
            "Order of Operations +,-,/,* () positive reals", "Multiplication and Division Integers",
            "Pattern Finding", "Equation Solving Two or Fewer Steps", "Number Line",
            "Ordering Positive Decimals", "Ordering Integers", "Rounding",
            "Subtraction Whole Numbers", "Division Whole Numbers", "Addition Whole Numbers",
            "Expanded, Standard and Word Notation", "Estimation", "Multiplication Positive Decimals",
            "Division Mixed Fractions", "Division Proper Fractions", "Multiplication Mixed Fractions",
            "Multiplication Proper Fractions", "Ordering Real Numbers", "Quadratic Equation Solving",
            "Multiplication Whole Numbers", "Multiplication Division by Powers of 10",
            "Ordering Whole Numbers", "Graphing Inequalities on a number line", "Properties of Numbers"
        ]

        for skill in bkt_skills:
            upsert_topic(conn, skill)
        print("[OK] PyBKT topics seeded.")

        # 2. Seed Users
        teacher_id = upsert_user(conn, "teacher@demo.com", "teacher", "Teacher Demo", "teacher123")
        s0 = upsert_user(conn, "student@demo.com", "student", "Student Demo", "student123")
        s1 = upsert_user(conn, "student1@demo.com", "student", "Student One", "student123")
        print("[OK] Users seeded.")

        # 3. Retrieve specific topics for question generation
        # NOTE: Using the exact PyBKT names now!
        t_add = conn.execute("SELECT id FROM topics WHERE name='Addition Whole Numbers'").fetchone()["id"]
        t_sub = conn.execute("SELECT id FROM topics WHERE name='Subtraction Whole Numbers'").fetchone()["id"]

        # 4. Generate Questions
        ensure_questions(conn, teacher_id, t_add, "Addition Whole Numbers")
        ensure_questions(conn, teacher_id, t_sub, "Subtraction Whole Numbers")
        print("[OK] Questions seeded.")

        # 5. Enroll Students
        ensure_demo_class_and_enrollments(conn, teacher_id, [s0, s1])
        print("[OK] Classes and enrollments seeded.")

        conn.commit()
        print("[OK] Seed complete (idempotent).")
        
    except Exception as e:
        conn.rollback()
        print(f"[NO] Seed failed: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    main()