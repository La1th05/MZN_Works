import sqlite3

conn = sqlite3.connect(r"c:\projects\MZN_Works\MZN\tamkeen\smart_lms\data\lms.db")
conn.row_factory = sqlite3.Row

rows = conn.execute("""
    SELECT 
        a.question_id,
        a.attempts,
        a.ms_first_response,
        a.hint_count,
        a.frustrated_score,
        a.confused_score,
        a.is_final
    FROM answers a
    WHERE a.is_final = 1
    LIMIT 10;
""").fetchall()

if not rows:
    print("No finalized answers yet — run a student session first.")
else:
    for r in rows:
        print(dict(r))

conn.close()