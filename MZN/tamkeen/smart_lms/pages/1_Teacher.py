from __future__ import annotations

import json
from datetime import datetime

import pandas as pd
import streamlit as st

from services.auth import logout, require_login
from services.logic import (
    assessment_instances_view,
    assessment_targets_view,
    assessment_topics_view,
    class_roster,
    create_assessment,
    create_class,
    enroll_student,
    engagement_signals_for_student,
    list_active_students,
    list_topics,
    mastery_for_student,
    remove_student,
    results_for_student,
    search_questions,
    teacher_assessments,
    teacher_classes,
    teacher_students,
    upsert_question,
)
from services.qio import export_questions_csv, import_questions_csv
from services.ui import (
    apply_theme,
    empty_state,
    mastery_label,
    metric_card,
    page_hero,
    percent,
    section_heading,
    sidebar_brand,
    status_pill,
)

st.set_page_config(page_title="Teacher Workspace · DysCalc AI", page_icon="📘", layout="wide")
apply_theme()
sidebar_brand()
user = require_login(role="teacher")
teacher_id = int(user["id"])

st.sidebar.caption("Teacher account")
st.sidebar.write(f"**{user.get('display_name') or user.get('email')}**")
st.sidebar.caption(user.get("email", ""))
if st.sidebar.button("Sign out", use_container_width=True):
    logout()

page_hero(
    "Teacher Workspace",
    "Manage learning groups, design assessments, and turn performance data into clear instructional actions.",
    "Instruction & learner support",
)

classes = teacher_classes(teacher_id)
students = teacher_students(teacher_id)
assessments = teacher_assessments(teacher_id)

# Lightweight support overview.
learners_needing_support = 0
for s in students:
    mastery = mastery_for_student(int(s["id"]))
    if mastery and min(float(m.get("p_knowledge") or 0.3) for m in mastery) < 0.60:
        learners_needing_support += 1

m1, m2, m3, m4 = st.columns(4)
with m1:
    metric_card("Active classes", len(classes), "Learning groups you manage")
with m2:
    metric_card("Learners", len(students), "Active enrolled students")
with m3:
    metric_card("Assessments", len(assessments), "Created assessment plans")
with m4:
    metric_card("Support review", learners_needing_support, "Learners with a low-mastery topic")

st.write("")
overview_tab, classes_tab, questions_tab, assessments_tab, insights_tab = st.tabs(
    ["Overview", "Classes", "Question Bank", "Assessments", "Learner Insights"]
)

with overview_tab:
    l, r = st.columns([1.15, 0.85], gap="large")
    with l:
        section_heading("Recent assessments", "A quick view of your latest assessment plans.")
        if assessments:
            df = pd.DataFrame(assessments[:8])
            show_cols = [c for c in ["title", "difficulty", "num_questions", "duration_seconds", "created_at"] if c in df.columns]
            if "duration_seconds" in df.columns:
                df["duration_minutes"] = (pd.to_numeric(df["duration_seconds"], errors="coerce") / 60).round(0)
                show_cols = [c for c in ["title", "difficulty", "num_questions", "duration_minutes", "created_at"] if c in df.columns]
            st.dataframe(df[show_cols], use_container_width=True, hide_index=True)
        else:
            empty_state("No assessments yet", "Create your first assessment from the Assessments tab.")

    with r:
        section_heading("Instructional workflow")
        st.markdown(
            """
            1. **Organize learners** into classes.
            2. **Maintain the question bank** by topic and difficulty.
            3. **Assign assessments** to classes or individual learners.
            4. **Review mastery trends** and decide the next support action.
            """
        )
        st.markdown(
            '<div class="trust-note">Use mastery and behavioral metrics as decision support. A teacher should remain the final decision-maker for intervention, difficulty changes, and learner-facing feedback.</div>',
            unsafe_allow_html=True,
        )

with classes_tab:
    section_heading("Class management", "Create a class, enroll students, and maintain the roster.")
    c1, c2 = st.columns([0.42, 0.58], gap="large")

    with c1:
        st.subheader("Create class")
        with st.form("teacher_create_class"):
            class_name = st.text_input("Class name", placeholder="Math Foundations · Grade 7")
            year = st.text_input("Academic year", placeholder="2026–2027")
            create_clicked = st.form_submit_button("Create class", type="primary", use_container_width=True)
        if create_clicked:
            if not class_name.strip() or not year.strip():
                st.error("Class name and academic year are required.")
            else:
                create_class(teacher_id, class_name.strip(), year.strip())
                st.success("Class created.")
                st.rerun()

    with c2:
        st.subheader("Roster")
        if not classes:
            empty_state("Create a class first", "A class is required before learners can be enrolled.")
        else:
            class_map = {f"{c['name']} · {c.get('year') or ''}": c for c in classes}
            selected_label = st.selectbox("Class", list(class_map.keys()), key="roster_class_select")
            selected_class = class_map[selected_label]
            class_id = int(selected_class["id"])

            all_students = list_active_students()
            roster = class_roster(class_id)
            enrolled_ids = {int(r["student_id"]) for r in roster if r.get("status") == "active"}
            available = [s for s in all_students if int(s["id"]) not in enrolled_ids]

            if available:
                add_map = {f"{s.get('display_name') or s['email']} · {s['email']}": s for s in available}
                add_label = st.selectbox("Add learner", list(add_map.keys()), key="enroll_student_select")
                if st.button("Enroll learner", type="primary", key="enroll_student_btn"):
                    enroll_student(class_id, int(add_map[add_label]["id"]))
                    st.success("Learner enrolled.")
                    st.rerun()
            else:
                st.caption("All active students are already enrolled in this class.")

            active_roster = [r for r in roster if r.get("status") == "active"]
            if active_roster:
                for r in active_roster:
                    row1, row2 = st.columns([0.78, 0.22])
                    with row1:
                        st.write(f"**{r.get('display_name') or r.get('email')}**")
                        st.caption(r.get("email", ""))
                    with row2:
                        if st.button("Remove", key=f"remove_{class_id}_{r['student_id']}", use_container_width=True):
                            remove_student(class_id, int(r["student_id"]))
                            st.rerun()
            else:
                empty_state("No learners enrolled", "Use the selector above to add students to this class.")

with questions_tab:
    section_heading("Question bank", "Search, add, edit, import, and export curriculum items.")
    topics = list_topics(active_only=True)
    topic_by_name = {t["name"]: int(t["id"]) for t in topics}

    f1, f2, f3, f4 = st.columns([1.25, 0.8, 0.8, 1.4])
    with f1:
        topic_filter = st.selectbox("Topic", ["All"] + list(topic_by_name.keys()), key="q_topic_filter")
    with f2:
        difficulty_filter = st.selectbox("Difficulty", ["All", "Easy", "Medium", "Hard"], key="q_diff_filter")
    with f3:
        active_filter = st.selectbox("Status", ["Active", "Inactive", "All"], key="q_active_filter")
    with f4:
        search_term = st.text_input("Search", placeholder="Question text or answer", key="q_term_filter")

    active_value = {"Active": 1, "Inactive": 0, "All": None}[active_filter]
    question_rows = search_questions(
        topic_id=None if topic_filter == "All" else topic_by_name[topic_filter],
        difficulty=difficulty_filter,
        active=active_value,
        term=search_term,
    )

    with st.expander("Add or edit a question", expanded=not bool(question_rows)):
        if not topics:
            st.warning("Create at least one topic in the backend before adding questions.")
        else:
            qid_text = st.text_input("Question ID to edit (leave blank to create)", key="q_edit_id")
            e1, e2, e3 = st.columns(3)
            with e1:
                q_topic = st.selectbox("Topic", list(topic_by_name.keys()), key="q_form_topic")
            with e2:
                q_diff = st.selectbox("Difficulty", ["Easy", "Medium", "Hard"], key="q_form_diff")
            with e3:
                input_mode = st.selectbox("Input mode", ["text", "mcq", "draw"], key="q_form_mode")
            prompt = st.text_area("Prompt", height=100, key="q_form_prompt")
            hint = st.text_input("Hint (optional)", key="q_form_hint")
            correct = st.text_input("Correct answer", key="q_form_correct")
            choices = st.text_input("MCQ choices (comma-separated, optional)", key="q_form_choices")
            a1, a2, a3 = st.columns(3)
            with a1:
                answer_type = st.selectbox("Grading", ["exact", "numeric"], key="q_form_answer_type")
            with a2:
                tolerance = st.number_input("Numeric tolerance", min_value=0.0, value=0.0, step=0.1, key="q_form_tol")
            with a3:
                points = st.number_input("Points", min_value=0.1, value=1.0, step=0.5, key="q_form_points")
            if st.button("Save question", type="primary", key="save_question"):
                try:
                    qid = int(qid_text) if qid_text.strip() else None
                    choices_json = None
                    if choices.strip():
                        choices_json = json.dumps([x.strip() for x in choices.split(",") if x.strip()], ensure_ascii=False)
                    upsert_question(
                        qid=qid,
                        topic_id=topic_by_name[q_topic],
                        difficulty=q_diff,
                        prompt=prompt.strip(),
                        hint_text=hint.strip() or None,
                        correct_answer=correct.strip(),
                        choices_json=choices_json,
                        input_mode=input_mode,
                        answer_type=answer_type,
                        tolerance=float(tolerance),
                        points=float(points),
                        is_active=1,
                        created_by=teacher_id,
                    )
                    st.success("Question saved.")
                    st.rerun()
                except Exception as e:
                    st.error(f"Could not save question: {e}")

    if question_rows:
        qdf = pd.DataFrame(question_rows)
        qdf["accuracy"] = qdf.apply(
            lambda r: (float(r.get("n_correct", 0)) / float(r.get("n_attempts", 0))) if float(r.get("n_attempts", 0) or 0) > 0 else None,
            axis=1,
        )
        show = [c for c in ["id", "topic_name", "difficulty", "prompt", "input_mode", "n_attempts", "accuracy", "avg_time_sec"] if c in qdf.columns]
        st.dataframe(qdf[show], use_container_width=True, hide_index=True)
    else:
        empty_state("No matching questions", "Change the filters or add a new question.")

    st.divider()
    io1, io2 = st.columns(2, gap="large")
    with io1:
        st.subheader("Export")
        st.caption("Export the current filtered view as CSV.")
        if question_rows:
            st.download_button(
                "Download question bank CSV",
                data=export_questions_csv(question_rows),
                file_name="dyscalc_question_bank.csv",
                mime="text/csv",
                use_container_width=True,
            )
    with io2:
        st.subheader("Import")
        upload = st.file_uploader("CSV file", type=["csv"], key="question_csv_upload")
        if upload:
            size = getattr(upload, "size", 0) or 0
            if size > 2 * 1024 * 1024:
                st.error("For safety, this UI limits question imports to 2 MB. Split larger files into smaller batches.")
            elif st.button("Validate & import", type="primary", key="question_csv_import", use_container_width=True):
                try:
                    inserted, updated = import_questions_csv(upload.getvalue(), created_by=teacher_id)
                    st.success(f"Imported successfully: {inserted} added, {updated} updated.")
                    st.rerun()
                except Exception as e:
                    st.error(f"Import failed: {e}")

with assessments_tab:
    section_heading("Assessment builder", "Create focused assessments and assign them to classes or individual learners.")
    topics = list_topics(active_only=True)
    topic_map = {t["name"]: int(t["id"]) for t in topics}
    class_map = {f"{c['name']} · {c.get('year') or ''}": int(c["id"]) for c in classes}
    student_map = {f"{s.get('display_name') or s['email']} · {s['email']}": int(s["id"]) for s in students}

    with st.expander("Create assessment", expanded=not bool(assessments)):
        with st.form("create_assessment_form"):
            title = st.text_input("Assessment title", placeholder="Fractions readiness check")
            selected_topics = st.multiselect("Topics", list(topic_map.keys()))
            a1, a2, a3 = st.columns(3)
            with a1:
                difficulty = st.selectbox("Difficulty", ["Easy", "Medium", "Hard"])
            with a2:
                num_questions = st.number_input("Questions", min_value=1, max_value=100, value=10)
            with a3:
                duration_minutes = st.number_input("Duration (minutes)", min_value=1, max_value=180, value=15)

            target_classes = st.multiselect("Assign to classes", list(class_map.keys()))
            target_students = st.multiselect("Assign to individual learners", list(student_map.keys()))
            st.caption("Scheduling is optional. Leave both fields empty to make the assessment immediately available according to instance status.")
            start_text = st.text_input("Start (optional, Jordan local time)", placeholder="2026-09-07 09:00")
            end_text = st.text_input("End (optional, Jordan local time)", placeholder="2026-09-14 23:59")
            create_assessment_clicked = st.form_submit_button("Create & assign", type="primary", use_container_width=True)

        if create_assessment_clicked:
            if not title.strip():
                st.error("Assessment title is required.")
            elif not selected_topics:
                st.error("Select at least one topic.")
            elif not target_classes and not target_students:
                st.error("Select at least one class or learner.")
            else:
                try:
                    assessment_id = create_assessment(
                        teacher_id=teacher_id,
                        title=title.strip(),
                        topic_ids=[topic_map[x] for x in selected_topics],
                        difficulty=difficulty,
                        num_questions=int(num_questions),
                        duration_seconds=int(duration_minutes) * 60,
                        start_at_in=start_text.strip() or None,
                        end_at_in=end_text.strip() or None,
                        class_ids=[class_map[x] for x in target_classes],
                        student_ids=[student_map[x] for x in target_students],
                    )
                    st.success(f"Assessment #{assessment_id} created and assigned.")
                    st.rerun()
                except Exception as e:
                    st.error(f"Could not create assessment: {e}")

    assessments_now = teacher_assessments(teacher_id)
    if not assessments_now:
        empty_state("No assessments", "Create an assessment above to begin assigning work.")
    else:
        for a in assessments_now[:12]:
            with st.expander(f"{a['title']} · {a.get('difficulty') or 'Adaptive'}"):
                c1, c2, c3 = st.columns(3)
                with c1:
                    st.metric("Questions", a.get("num_questions", "—"))
                with c2:
                    st.metric("Duration", f"{int(a.get('duration_seconds') or 0) // 60} min")
                with c3:
                    st.metric("Created", str(a.get("created_at") or "")[:16])
                topic_names = [x["name"] for x in assessment_topics_view(int(a["id"]))]
                st.write("**Topics:**", ", ".join(topic_names) if topic_names else "—")
                targets = assessment_targets_view(int(a["id"]))
                instances = assessment_instances_view(int(a["id"]))
                tc1, tc2 = st.columns(2)
                with tc1:
                    st.caption("Targets")
                    if targets:
                        tdf = pd.DataFrame(targets)
                        cols = [c for c in ["class_name", "class_year", "student_name", "student_email"] if c in tdf.columns]
                        st.dataframe(tdf[cols], use_container_width=True, hide_index=True)
                with tc2:
                    st.caption("Learner instances")
                    if instances:
                        idf = pd.DataFrame(instances)
                        cols = [c for c in ["display_name", "email", "status", "started_at", "submitted_at"] if c in idf.columns]
                        st.dataframe(idf[cols], use_container_width=True, hide_index=True)

with insights_tab:
    section_heading("Learner insights", "Translate performance into next-step teaching decisions.")
    if not students:
        empty_state("No enrolled learners", "Enroll students in one of your classes to view insights.")
    else:
        student_select_map = {f"{s.get('display_name') or s['email']} · {s['email']}": s for s in students}
        learner_label = st.selectbox("Learner", list(student_select_map.keys()), key="analytics_student")
        learner = student_select_map[learner_label]
        learner_id = int(learner["id"])

        mastery = mastery_for_student(learner_id)
        results = results_for_student(learner_id)
        signals = engagement_signals_for_student(learner_id)

        if mastery:
            st.subheader("Topic mastery")
            for m in mastery:
                p = float(m.get("p_knowledge") or 0.0)
                label = mastery_label(p)
                c1, c2 = st.columns([0.78, 0.22])
                with c1:
                    st.write(f"**{m.get('topic_name')}** · {label}")
                    st.progress(max(0.0, min(1.0, p)))
                    st.caption(f"Evidence count: {int(m.get('n_obs') or 0)}")
                with c2:
                    st.metric("Mastery", percent(p))
        else:
            empty_state("No mastery history", "Mastery will appear after the learner completes graded work.")

        st.divider()
        r1, r2 = st.columns([1.1, 0.9], gap="large")
        with r1:
            st.subheader("Performance history")
            if results:
                rdf = pd.DataFrame(results).sort_values("computed_at")
                if "accuracy" in rdf.columns:
                    chart_df = rdf[["computed_at", "accuracy"]].copy()
                    chart_df["computed_at"] = pd.to_datetime(chart_df["computed_at"], errors="coerce")
                    chart_df = chart_df.dropna().set_index("computed_at")
                    st.line_chart(chart_df, use_container_width=True)
                show = [c for c in ["title", "difficulty", "accuracy", "total_score", "model_recommendation", "computed_at"] if c in rdf.columns]
                st.dataframe(rdf[show].sort_values("computed_at", ascending=False), use_container_width=True, hide_index=True)
            else:
                empty_state("No graded assessments", "The learner has not completed a graded assessment yet.")

        with r2:
            st.subheader("Learning support signals")
            st.caption("These are heuristic interaction indicators, not emotional or clinical diagnoses.")
            if signals:
                sdf = pd.DataFrame(signals).rename(
                    columns={
                        "avg_frustrated": "interaction_friction",
                        "avg_confused": "rapid_error_signal",
                        "n_answers": "evidence_count",
                    }
                )
                st.dataframe(sdf, use_container_width=True, hide_index=True)
            else:
                empty_state("No support-signal history", "Signals appear after finalized answers are graded.")
