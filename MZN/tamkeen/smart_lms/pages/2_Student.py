from __future__ import annotations

import json
import time
from html import escape
from datetime import datetime, timezone

import pandas as pd
import streamlit as st

from services.auth import logout, require_login
from services.logic import (
    can_start_instance,
    get_instance,
    get_next_adaptive_question,
    instance_review,
    mastery_for_student,
    record_adaptive_answer,
    results_for_student,
    start_instance,
    student_instances,
    student_latest_autosave_map,
    student_instance_questions,
    submit_instance,
    upsert_autosave,
    utc_z_to_dt,
    utc_z_to_jordan_str,
)
from services.ui import (
    apply_theme,
    empty_state,
    mastery_label,
    metric_card,
    page_hero,
    percent,
    section_heading,
    sidebar_brand,
    status_label,
    status_pill,
)

st.set_page_config(page_title="Student Workspace · DysCalc AI", page_icon="🧠", layout="wide")
apply_theme()
sidebar_brand()
user = require_login(role="student")
student_id = int(user["id"])

st.sidebar.caption("Student account")
st.sidebar.write(f"**{user.get('display_name') or user.get('email')}**")
st.sidebar.caption(user.get("email", ""))
if st.sidebar.button("Sign out", use_container_width=True):
    logout()

page_hero(
    "Student Workspace",
    "One task at a time, clear progress, and learning feedback that helps you know what to do next.",
    "Focused adaptive learning",
)

instances = student_instances(student_id)
results = results_for_student(student_id)
mastery = mastery_for_student(student_id)

active_count = sum(1 for x in instances if x.get("instance_status") in ("assigned", "in_progress"))
completed_count = sum(1 for x in instances if x.get("instance_status") == "graded")
avg_accuracy = None
if results:
    vals = [float(r.get("accuracy") or 0.0) for r in results]
    avg_accuracy = sum(vals) / len(vals) if vals else None
strong_topics = sum(1 for m in mastery if float(m.get("p_knowledge") or 0.0) >= 0.85)

m1, m2, m3, m4 = st.columns(4)
with m1:
    metric_card("Available work", active_count, "Assigned or in-progress")
with m2:
    metric_card("Completed", completed_count, "Graded learning sessions")
with m3:
    metric_card("Average accuracy", percent(avg_accuracy) if avg_accuracy is not None else "—", "Across graded work")
with m4:
    metric_card("Strong topics", strong_topics, "Topics at 85%+ mastery")

st.write("")
learn_tab, progress_tab, reports_tab = st.tabs(["My Learning", "Progress", "Reports"])


def _remaining_seconds(inst: dict) -> int | None:
    ends = utc_z_to_dt(inst.get("ends_at"))
    if not ends:
        return None
    return max(0, int((ends - datetime.now(timezone.utc)).total_seconds()))


def _format_time(seconds: int | None) -> str:
    if seconds is None:
        return "—"
    m, s = divmod(max(0, seconds), 60)
    h, m = divmod(m, 60)
    if h:
        return f"{h:02d}:{m:02d}:{s:02d}"
    return f"{m:02d}:{s:02d}"


def _autosave_standard(instance_id: int, question_id: int, widget_key: str) -> None:
    answer = st.session_state.get(widget_key, "")
    attempts_key = f"attempts_{instance_id}_{question_id}"
    st.session_state[attempts_key] = int(st.session_state.get(attempts_key, 0)) + 1
    hint_key = f"hints_{instance_id}_{question_id}"
    first_key = f"first_seen_{instance_id}_{question_id}"
    first_seen = float(st.session_state.get(first_key, time.time()))
    ms_first = max(1, int((time.time() - first_seen) * 1000))
    ok = upsert_autosave(
        instance_id=instance_id,
        student_id=student_id,
        question_id=question_id,
        answer_text=str(answer),
        ms_first_response=ms_first,
        hint_count=int(st.session_state.get(hint_key, 0)),
        attempts=int(st.session_state[attempts_key]),
    )
    st.session_state[f"saved_{instance_id}_{question_id}"] = bool(ok)


def _timer_body(instance_id: int) -> None:
    inst = get_instance(instance_id, student_id)
    if not inst or inst.get("status") != "in_progress":
        return
    remaining = _remaining_seconds(inst)
    st.metric("Time remaining", _format_time(remaining))
    if remaining is not None and remaining <= 0:
        try:
            submit_instance(instance_id, student_id, auto=True)
            st.success("Time ended. Your saved answers were submitted automatically.")
            st.session_state.pop("active_instance_id", None)
            st.rerun()
        except Exception:
            pass


if hasattr(st, "fragment"):
    timer_fragment = st.fragment(run_every="1s")(_timer_body)
else:
    timer_fragment = _timer_body


def _render_standard_exam(inst: dict) -> None:
    instance_id = int(inst["id"])
    questions = student_instance_questions(instance_id, student_id)
    if not questions:
        empty_state("No questions available", "Ask your teacher to review this assessment.")
        return

    idx_key = f"question_index_{instance_id}"
    if idx_key not in st.session_state:
        st.session_state[idx_key] = 0
    idx = max(0, min(int(st.session_state[idx_key]), len(questions) - 1))
    st.session_state[idx_key] = idx

    autosaved = student_latest_autosave_map(instance_id, student_id)
    q = questions[idx]
    qid = int(q["question_id"])
    answer_key = f"answer_{instance_id}_{qid}"
    first_key = f"first_seen_{instance_id}_{qid}"
    hint_key = f"hints_{instance_id}_{qid}"

    if first_key not in st.session_state:
        st.session_state[first_key] = time.time()
    if hint_key not in st.session_state:
        st.session_state[hint_key] = int((autosaved.get(qid) or {}).get("hint_count") or 0)
    if answer_key not in st.session_state:
        st.session_state[answer_key] = str((autosaved.get(qid) or {}).get("answer_text") or "")

    top1, top2 = st.columns([0.72, 0.28])
    with top1:
        st.progress((idx + 1) / len(questions), text=f"Question {idx + 1} of {len(questions)}")
    with top2:
        timer_fragment(instance_id)

    st.markdown(
        f"""
        <div class="question-shell">
          <div class="question-number">Question {idx + 1} · {escape(str(q.get('difficulty') or '').title())}</div>
          <div class="question-prompt">{escape(str(q.get('prompt') or ''))}</div>
        </div>
        """,
        unsafe_allow_html=True,
    )

    choices = []
    if q.get("choices_json"):
        try:
            choices = [str(x) for x in json.loads(q["choices_json"])]
        except Exception:
            choices = []

    if choices or q.get("input_mode") == "mcq":
        options = [""] + choices if choices else [""]
        current = str(st.session_state.get(answer_key, ""))
        index = options.index(current) if current in options else 0
        st.radio(
            "Choose an answer",
            options,
            index=index,
            key=answer_key,
            format_func=lambda x: "Select an option" if x == "" else x,
            on_change=_autosave_standard,
            args=(instance_id, qid, answer_key),
        )
    else:
        st.text_input(
            "Your answer",
            key=answer_key,
            placeholder="Type your answer",
            on_change=_autosave_standard,
            args=(instance_id, qid, answer_key),
        )

    hc1, hc2 = st.columns([0.72, 0.28])
    with hc1:
        if q.get("hint_text"):
            if st.button("Show hint", key=f"hint_btn_{instance_id}_{qid}"):
                st.session_state[hint_key] = int(st.session_state.get(hint_key, 0)) + 1
                upsert_autosave(
                    instance_id=instance_id,
                    student_id=student_id,
                    question_id=qid,
                    answer_text=None,
                    hint_count=int(st.session_state[hint_key]),
                )
                st.session_state[f"hint_visible_{instance_id}_{qid}"] = True
            if st.session_state.get(f"hint_visible_{instance_id}_{qid}"):
                st.info(q.get("hint_text"))
    with hc2:
        if st.session_state.get(f"saved_{instance_id}_{qid}") or qid in autosaved:
            st.caption("✓ Answer saved")
        else:
            st.caption("Your answer saves when it changes")

    nav1, nav2, nav3 = st.columns([1, 1, 1.25])
    with nav1:
        if st.button("← Previous", disabled=idx == 0, use_container_width=True, key=f"prev_{instance_id}_{idx}"):
            _autosave_standard(instance_id, qid, answer_key)
            st.session_state[idx_key] = idx - 1
            st.rerun()
    with nav2:
        if st.button("Next →", disabled=idx == len(questions) - 1, use_container_width=True, key=f"next_{instance_id}_{idx}"):
            _autosave_standard(instance_id, qid, answer_key)
            st.session_state[idx_key] = idx + 1
            st.rerun()
    with nav3:
        confirm = st.checkbox("I am ready to submit", key=f"confirm_submit_{instance_id}")
        if st.button("Submit assessment", type="primary", disabled=not confirm, use_container_width=True, key=f"submit_{instance_id}"):
            _autosave_standard(instance_id, qid, answer_key)
            try:
                submit_instance(instance_id, student_id, auto=False)
                st.success("Assessment submitted successfully.")
                st.session_state.pop("active_instance_id", None)
                st.rerun()
            except Exception as e:
                st.error(f"Could not submit: {e}")


def _render_adaptive_exam(inst: dict) -> None:
    instance_id = int(inst["id"])
    timer_fragment(instance_id)

    q_state_key = f"adaptive_question_{instance_id}"
    if q_state_key not in st.session_state:
        q, topic_name, mastery_value, served, max_questions = get_next_adaptive_question(instance_id, student_id)
        st.session_state[q_state_key] = {
            "q": q,
            "topic": topic_name,
            "mastery": mastery_value,
            "served": served,
            "max_questions": max_questions,
        }
        st.rerun()

    state = st.session_state.get(q_state_key) or {}
    q = state.get("q")
    if not q:
        st.success("Adaptive practice is complete.")
        if st.button("Finish session", type="primary", key=f"finish_adaptive_{instance_id}"):
            try:
                submit_instance(instance_id, student_id, auto=False)
            except Exception:
                pass
            st.session_state.pop(q_state_key, None)
            st.session_state.pop("active_instance_id", None)
            st.rerun()
        return

    served = int(state.get("served") or 1)
    max_questions = int(state.get("max_questions") or 0)
    if max_questions > 0:
        st.progress(min(1.0, served / max_questions), text=f"Adaptive question {served} of up to {max_questions}")

    st.caption(f"Focus topic: {state.get('topic') or 'Current topic'} · Estimated mastery before this question: {percent(state.get('mastery') or 0.0)}")
    st.markdown(
        f"""
        <div class="question-shell">
          <div class="question-number">Adaptive practice · {escape(str(q.get('difficulty') or '').title())}</div>
          <div class="question-prompt">{escape(str(q.get('prompt') or ''))}</div>
        </div>
        """,
        unsafe_allow_html=True,
    )

    qid = int(q["id"])
    ans_key = f"adaptive_answer_{instance_id}_{qid}"
    if ans_key not in st.session_state:
        st.session_state[ans_key] = ""
    choices = []
    if q.get("choices_json"):
        try:
            choices = [str(x) for x in json.loads(q["choices_json"])]
        except Exception:
            choices = []
    if choices:
        st.radio("Choose an answer", [""] + choices, key=ans_key, format_func=lambda x: "Select an option" if x == "" else x)
    else:
        st.text_input("Your answer", key=ans_key, placeholder="Type your answer")

    if q.get("hint_text"):
        with st.expander("Need a hint?"):
            st.write(q["hint_text"])

    if st.button("Check answer & continue", type="primary", use_container_width=True, key=f"adaptive_submit_{instance_id}_{qid}"):
        answer = str(st.session_state.get(ans_key, "")).strip()
        if not answer:
            st.warning("Enter an answer before continuing.")
        else:
            try:
                feedback = record_adaptive_answer(
                    instance_id=instance_id,
                    student_id=student_id,
                    question_id=qid,
                    answer_text=answer,
                    attempts=1,
                    hint_count=0,
                )
                if int(feedback.get("is_correct") or 0):
                    st.success("Correct. Nice work.")
                else:
                    st.warning(f"Not quite. Correct answer: {feedback.get('correct_answer')}")
                q2, topic2, mastery2, served2, max2 = get_next_adaptive_question(instance_id, student_id)
                st.session_state[q_state_key] = {
                    "q": q2,
                    "topic": topic2,
                    "mastery": mastery2,
                    "served": served2,
                    "max_questions": max2,
                }
                time.sleep(0.35)
                st.rerun()
            except Exception as e:
                st.error(f"Adaptive practice could not continue: {e}")


with learn_tab:
    section_heading("My learning", "Continue assigned work or begin a new assessment when you are ready.")
    active = [x for x in instances if x.get("instance_status") in ("assigned", "in_progress")]
    upcoming_or_past = [x for x in instances if x.get("instance_status") not in ("assigned", "in_progress")]

    active_instance_id = st.session_state.get("active_instance_id")
    if active_instance_id:
        inst = get_instance(int(active_instance_id), student_id)
        if not inst:
            st.session_state.pop("active_instance_id", None)
            st.rerun()
        else:
            back_col, title_col = st.columns([0.18, 0.82])
            with back_col:
                if st.button("← Learning list", use_container_width=True):
                    st.session_state.pop("active_instance_id", None)
                    st.rerun()
            with title_col:
                st.subheader(inst.get("title") or "Assessment")
                status_pill(inst.get("status"))

            if inst.get("status") == "assigned":
                ok, reason = can_start_instance(inst)
                st.write("This assessment will begin its timer only after you press **Start**.")
                if st.button("Start assessment", type="primary", disabled=not ok, use_container_width=True, key=f"start_{active_instance_id}"):
                    try:
                        start_instance(int(active_instance_id), student_id)
                        st.rerun()
                    except Exception as e:
                        st.error(str(e))
                if not ok:
                    st.info(reason)
            elif inst.get("status") == "in_progress":
                if str(inst.get("difficulty") or "").lower() == "adaptive":
                    _render_adaptive_exam(inst)
                else:
                    _render_standard_exam(inst)
            elif inst.get("status") == "graded":
                st.success("This assessment is complete. Open Reports to review your feedback.")
            else:
                st.info(f"Assessment status: {status_label(inst.get('status'))}")
    else:
        if not active:
            empty_state("You are all caught up", "There are no assigned or in-progress assessments right now.")
        else:
            for item in active:
                with st.container(border=True):
                    c1, c2, c3 = st.columns([0.62, 0.18, 0.20])
                    with c1:
                        st.subheader(item.get("title") or "Assessment")
                        st.caption(f"{item.get('difficulty') or 'Adaptive'} · {item.get('num_questions') or '—'} questions · {int(item.get('duration_seconds') or 0)//60} min")
                        status_pill(item.get("instance_status"))
                    with c2:
                        if item.get("start_at"):
                            st.caption("Available")
                            st.write(utc_z_to_jordan_str(item.get("start_at")))
                    with c3:
                        label = "Continue" if item.get("instance_status") == "in_progress" else "Open"
                        if st.button(label, type="primary", key=f"open_instance_{item['instance_id']}", use_container_width=True):
                            st.session_state["active_instance_id"] = int(item["instance_id"])
                            st.rerun()

with progress_tab:
    section_heading("My progress", "Mastery estimates summarize evidence from your completed learning sessions.")
    if mastery:
        for m in mastery:
            p = float(m.get("p_knowledge") or 0.0)
            c1, c2 = st.columns([0.78, 0.22])
            with c1:
                st.write(f"**{m.get('topic_name')}** · {mastery_label(p)}")
                st.progress(max(0.0, min(1.0, p)))
                st.caption(f"Based on {int(m.get('n_obs') or 0)} observations")
            with c2:
                st.metric("Mastery", percent(p))
    else:
        empty_state("No mastery estimate yet", "Complete graded work to begin building your topic mastery profile.")

    st.markdown(
        '<div class="trust-note"><strong>What this means:</strong> mastery is an estimate from your learning evidence. It is not a diagnosis, intelligence score, or permanent label.</div>',
        unsafe_allow_html=True,
    )

with reports_tab:
    section_heading("Reports", "Review completed assessments and see what to practice next.")
    if not results:
        empty_state("No reports yet", "Completed and graded assessments will appear here.")
    else:
        report_map = {
            f"{r.get('title') or 'Assessment'} · {str(r.get('computed_at') or '')[:16]}": r
            for r in results
        }
        report_label = st.selectbox("Completed assessment", list(report_map.keys()), key="student_report_select")
        report = report_map[report_label]
        r1, r2, r3 = st.columns(3)
        with r1:
            st.metric("Accuracy", percent(report.get("accuracy")))
        with r2:
            st.metric("Score", f"{float(report.get('total_score') or 0.0):.1f}")
        with r3:
            st.metric("Difficulty", str(report.get("difficulty") or "—"))

        st.subheader("Recommended next step")
        st.info(report.get("model_recommendation") or "Keep practicing and review feedback with your teacher.")

        topics_json = report.get("topics_json")
        if topics_json:
            try:
                topic_rows = json.loads(topics_json)
                if topic_rows:
                    tdf = pd.DataFrame(topic_rows)
                    keep = [c for c in ["topic_name", "mastery", "n_obs", "x"] if c in tdf.columns]
                    st.dataframe(tdf[keep], use_container_width=True, hide_index=True)
            except Exception:
                pass

        review = instance_review(int(report["instance_id"]), student_id)
        if review:
            st.subheader("Question feedback")
            for row in review:
                correct = int(row.get("is_correct") or 0) == 1
                with st.expander(f"Question {row.get('order_index')} · {'Correct' if correct else 'Review'}"):
                    st.write(row.get("prompt") or "")
                    st.write(f"**Your answer:** {row.get('student_answer') or 'No answer'}")
                    st.write(f"**Correct answer:** {row.get('correct_answer') or '—'}")
                    if row.get("feedback"):
                        st.caption(row["feedback"])
