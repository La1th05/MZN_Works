import io
import json

import pandas as pd

from services.db import get_conn
from services.logic import utc_to_z, now_utc_dt


QUESTION_COLUMNS = [
    "id",
    "topic_id",
    "difficulty",
    "prompt",
    "hint_text",
    "correct_answer",
    "choices_json",
    "input_mode",
    "answer_type",
    "tolerance",
    "points",
    "is_active",
]


def export_questions_csv(rows: list[dict]) -> bytes:
    df = pd.DataFrame(rows)

    # keep only known columns if present + topic_name + stats if present
    cols: list[str] = []
    for c in QUESTION_COLUMNS + [
        "topic_name",
        "n_attempts",
        "n_correct",
        "avg_time_sec",
        "created_at",
        "updated_at",
    ]:
        if c in df.columns:
            cols.append(c)

    if cols:
        df = df[cols]

    buf = io.StringIO()
    df.to_csv(buf, index=False)
    return buf.getvalue().encode("utf-8")


def import_questions_csv(file_bytes: bytes, created_by: int) -> tuple[int, int]:
    df = pd.read_csv(io.BytesIO(file_bytes))
    df_cols = set(df.columns)

    required = {"topic_id", "difficulty", "prompt", "correct_answer"}
    if not required.issubset(df_cols):
        raise ValueError(f"CSV missing required columns: {sorted(list(required - df_cols))}")

    nowz = utc_to_z(now_utc_dt())
    inserted = 0
    updated = 0

    conn = get_conn()
    try:
        for _, row in df.iterrows():
            qid = int(row["id"]) if "id" in df_cols and pd.notna(row.get("id")) else None

            topic_id = int(row["topic_id"])
            difficulty = str(row["difficulty"])
            prompt = str(row["prompt"])

            hint_text = None
            if "hint_text" in df_cols and pd.notna(row.get("hint_text")):
                hint_text = str(row.get("hint_text"))

            correct_answer = str(row["correct_answer"])

            choices_json = None
            if "choices_json" in df_cols and pd.notna(row.get("choices_json")):
                cj = row.get("choices_json")
                if isinstance(cj, str) and cj.strip():
                    # validate it's JSON, store as-is
                    try:
                        json.loads(cj)
                        choices_json = cj
                    except Exception:
                        parts = [p.strip() for p in cj.split(",") if p.strip()]
                        choices_json = json.dumps(parts, ensure_ascii=False)

            input_mode = "text"
            if "input_mode" in df_cols and pd.notna(row.get("input_mode")):
                im = str(row.get("input_mode")).strip().lower()
                if im in ("text", "mcq", "draw"):
                    input_mode = im

            answer_type = "exact"
            if "answer_type" in df_cols and pd.notna(row.get("answer_type")):
                at = str(row.get("answer_type")).strip().lower()
                if at in ("exact", "numeric"):
                    answer_type = at

            tolerance = float(row.get("tolerance")) if "tolerance" in df_cols and pd.notna(row.get("tolerance")) else 0.0
            points = float(row.get("points")) if "points" in df_cols and pd.notna(row.get("points")) else 1.0
            is_active = int(row.get("is_active")) if "is_active" in df_cols and pd.notna(row.get("is_active")) else 1

            if qid is not None and conn.execute("SELECT 1 FROM questions WHERE id=?;", (qid,)).fetchone():
                conn.execute(
                    """
                    UPDATE questions SET
                        topic_id=?, difficulty=?, prompt=?, hint_text=?, correct_answer=?,
                        choices_json=?, input_mode=?, answer_type=?, tolerance=?, points=?, is_active=?,
                        updated_at=?
                    WHERE id=?;
                    """,
                    (
                        topic_id,
                        difficulty,
                        prompt,
                        hint_text,
                        correct_answer,
                        choices_json,
                        input_mode,
                        answer_type,
                        tolerance,
                        points,
                        is_active,
                        nowz,
                        qid,
                    ),
                )
                updated += 1
            else:
                conn.execute(
                    """
                    INSERT INTO questions(
                        topic_id, difficulty, prompt, hint_text, correct_answer, choices_json,
                        input_mode, answer_type, tolerance, points, is_active,
                        created_by, created_at, updated_at
                    ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?);
                    """,
                    (
                        topic_id,
                        difficulty,
                        prompt,
                        hint_text,
                        correct_answer,
                        choices_json,
                        input_mode,
                        answer_type,
                        tolerance,
                        points,
                        is_active,
                        created_by,
                        nowz,
                        nowz,
                    ),
                )
                inserted += 1

        conn.commit()
        return inserted, updated
    finally:
        conn.close()
