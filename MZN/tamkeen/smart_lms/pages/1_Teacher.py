from __future__ import annotations

import json

import pandas as pd
import streamlit as st

from services.auth import logout, require_login
from services.i18n import (
    apply_language_direction,
    difficulty_label,
    get_lang,
    language_switcher,
    mastery_label as translated_mastery_label,
    status_label,
    topic_label,
)
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
    metric_card,
    page_hero,
    percent,
    section_heading,
    sidebar_brand,
)


# ============================================================
# LOCAL TRANSLATION HELPER
# ============================================================
# We keep this file fully bilingual without changing any
# database values. English remains the canonical/internal value.
# Only what the user sees is translated.


def tr(en: str, ar: str) -> str:
    return ar if get_lang() == "ar" else en


def input_mode_label(value: str) -> str:
    labels = {
        "text": tr("Text", "نصي"),
        "mcq": tr("Multiple choice", "اختيار من متعدد"),
        "draw": tr("Draw", "رسم"),
    }
    return labels.get(value, value)


def grading_label(value: str) -> str:
    labels = {
        "exact": tr("Exact", "مطابقة تامة"),
        "numeric": tr("Numeric", "رقمي"),
    }
    return labels.get(value, value)


def activity_status_label(value: str) -> str:
    labels = {
        "Active": tr("Active", "نشط"),
        "Inactive": tr("Inactive", "غير نشط"),
        "All": tr("All", "الكل"),
    }
    return labels.get(value, value)


def all_label(value: str) -> str:
    return tr("All", "الكل") if value == "All" else value


def translate_topic_option(value: str) -> str:
    if value == "All":
        return tr("All", "الكل")
    return topic_label(value)


def translate_difficulty_option(value: str) -> str:
    if value == "All":
        return tr("All", "الكل")
    return difficulty_label(value)


def translate_question_table(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy()

    if "topic_name" in out.columns:
        out["topic_name"] = out["topic_name"].apply(topic_label)

    if "difficulty" in out.columns:
        out["difficulty"] = out["difficulty"].apply(difficulty_label)

    if "input_mode" in out.columns:
        out["input_mode"] = out["input_mode"].apply(input_mode_label)

    return out.rename(
        columns={
            "id": tr("ID", "الرقم"),
            "topic_name": tr("Topic", "الموضوع"),
            "difficulty": tr("Difficulty", "الصعوبة"),
            "prompt": tr("Prompt", "نص السؤال"),
            "input_mode": tr("Input mode", "طريقة الإجابة"),
            "n_attempts": tr("Attempts", "المحاولات"),
            "accuracy": tr("Accuracy", "الدقة"),
            "avg_time_sec": tr("Average time (sec)", "متوسط الوقت (ثانية)"),
        }
    )


# ============================================================
# PAGE SETUP
# ============================================================

st.set_page_config(
    page_title="Teacher Workspace · DysCalc AI",
    page_icon="📘",
    layout="wide",
)

apply_theme()

# Language selector must exist on every standalone Streamlit page.
language_switcher(
    location="sidebar",
    key="teacher_language_selector",
)

# Arabic = RTL, English = LTR.
apply_language_direction()

sidebar_brand()

user = require_login(role="teacher")
teacher_id = int(user["id"])


# ============================================================
# SIDEBAR ACCOUNT
# ============================================================

st.sidebar.caption(tr("Teacher account", "حساب المعلم"))
st.sidebar.write(f"**{user.get('display_name') or user.get('email')}**")
st.sidebar.caption(user.get("email", ""))

if st.sidebar.button(
    tr("Sign out", "تسجيل الخروج"),
    use_container_width=True,
):
    logout()


# ============================================================
# PAGE HERO
# ============================================================

page_hero(
    tr("Teacher Workspace", "مساحة عمل المعلم"),
    tr(
        "Manage learning groups, design assessments, and turn performance data into clear instructional actions.",
        "أدر المجموعات التعليمية، وأنشئ الاختبارات، وحوّل بيانات الأداء إلى إجراءات تعليمية واضحة.",
    ),
    tr(
        "Instruction & learner support",
        "التعليم ودعم المتعلم",
    ),
)


# ============================================================
# LOAD TEACHER DATA
# ============================================================

classes = teacher_classes(teacher_id)
students = teacher_students(teacher_id)
assessments = teacher_assessments(teacher_id)


# ============================================================
# SUPPORT OVERVIEW
# ============================================================

learners_needing_support = 0

for s in students:
    mastery = mastery_for_student(int(s["id"]))

    if mastery and min(
        float(m.get("p_knowledge") or 0.3)
        for m in mastery
    ) < 0.60:
        learners_needing_support += 1


m1, m2, m3, m4 = st.columns(4)

with m1:
    metric_card(
        tr("Active classes", "الصفوف النشطة"),
        len(classes),
        tr(
            "Learning groups you manage",
            "المجموعات التعليمية التي تديرها",
        ),
    )

with m2:
    metric_card(
        tr("Learners", "الطلاب"),
        len(students),
        tr(
            "Active enrolled students",
            "الطلاب المسجلون حالياً",
        ),
    )

with m3:
    metric_card(
        tr("Assessments", "الاختبارات"),
        len(assessments),
        tr(
            "Created assessment plans",
            "خطط التقييم التي تم إنشاؤها",
        ),
    )

with m4:
    metric_card(
        tr("Support review", "بحاجة إلى مراجعة"),
        learners_needing_support,
        tr(
            "Learners with a low-mastery topic",
            "طلاب لديهم موضوع بمستوى إتقان منخفض",
        ),
    )


# ============================================================
# MAIN TABS
# ============================================================

st.write("")

overview_tab, classes_tab, questions_tab, assessments_tab, insights_tab = st.tabs(
    [
        tr("Overview", "نظرة عامة"),
        tr("Classes", "الصفوف"),
        tr("Question Bank", "بنك الأسئلة"),
        tr("Assessments", "الاختبارات"),
        tr("Learner Insights", "تحليل الطلاب"),
    ]
)


# ============================================================
# OVERVIEW TAB
# ============================================================

with overview_tab:
    l, r = st.columns(
        [1.15, 0.85],
        gap="large",
    )

    with l:
        section_heading(
            tr(
                "Recent assessments",
                "الاختبارات الأخيرة",
            ),
            tr(
                "A quick view of your latest assessment plans.",
                "نظرة سريعة على أحدث خطط التقييم.",
            ),
        )

        if assessments:
            df = pd.DataFrame(assessments[:8])

            show_cols = [
                c
                for c in [
                    "title",
                    "difficulty",
                    "num_questions",
                    "duration_seconds",
                    "created_at",
                ]
                if c in df.columns
            ]

            if "duration_seconds" in df.columns:
                df["duration_minutes"] = (
                    pd.to_numeric(
                        df["duration_seconds"],
                        errors="coerce",
                    )
                    / 60
                ).round(0)

                show_cols = [
                    c
                    for c in [
                        "title",
                        "difficulty",
                        "num_questions",
                        "duration_minutes",
                        "created_at",
                    ]
                    if c in df.columns
                ]

            display_df = df[show_cols].copy()

            if "difficulty" in display_df.columns:
                display_df["difficulty"] = display_df[
                    "difficulty"
                ].apply(difficulty_label)

            display_df = display_df.rename(
                columns={
                    "title": tr("Title", "العنوان"),
                    "difficulty": tr("Difficulty", "الصعوبة"),
                    "num_questions": tr(
                        "Questions",
                        "عدد الأسئلة",
                    ),
                    "duration_minutes": tr(
                        "Duration (min)",
                        "المدة (دقيقة)",
                    ),
                    "created_at": tr(
                        "Created",
                        "تاريخ الإنشاء",
                    ),
                }
            )

            st.dataframe(
                display_df,
                use_container_width=True,
                hide_index=True,
            )

        else:
            empty_state(
                tr(
                    "No assessments yet",
                    "لا توجد اختبارات حتى الآن",
                ),
                tr(
                    "Create your first assessment from the Assessments tab.",
                    "أنشئ أول اختبار من تبويب الاختبارات.",
                ),
            )

    with r:
        section_heading(
            tr(
                "Instructional workflow",
                "سير العملية التعليمية",
            )
        )

        st.markdown(
            tr(
                """
1. **Organize learners** into classes.
2. **Maintain the question bank** by topic and difficulty.
3. **Assign assessments** to classes or individual learners.
4. **Review mastery trends** and decide the next support action.
                """,
                """
1. **نظّم الطلاب** ضمن الصفوف.
2. **أدر بنك الأسئلة** حسب الموضوع ومستوى الصعوبة.
3. **عيّن الاختبارات** للصفوف أو لطلاب محددين.
4. **راجع اتجاهات الإتقان** وحدد إجراء الدعم التالي.
                """,
            )
        )

        st.markdown(
            (
                '<div class="trust-note">'
                + tr(
                    "Use mastery and behavioral metrics as decision support. "
                    "A teacher should remain the final decision-maker for "
                    "intervention, difficulty changes, and learner-facing feedback.",
                    "استخدم مؤشرات الإتقان والسلوك كأدوات لدعم القرار. "
                    "يجب أن يبقى المعلم صاحب القرار النهائي فيما يتعلق "
                    "بالتدخل وتغيير مستوى الصعوبة والتغذية الراجعة للطالب.",
                )
                + "</div>"
            ),
            unsafe_allow_html=True,
        )


# ============================================================
# CLASSES TAB
# ============================================================

with classes_tab:
    section_heading(
        tr(
            "Class management",
            "إدارة الصفوف",
        ),
        tr(
            "Create a class, enroll students, and maintain the roster.",
            "أنشئ صفاً، وسجّل الطلاب، وأدر قائمة الصف.",
        ),
    )

    c1, c2 = st.columns(
        [0.42, 0.58],
        gap="large",
    )

    # --------------------------------------------------------
    # CREATE CLASS
    # --------------------------------------------------------

    with c1:
        st.subheader(
            tr(
                "Create class",
                "إنشاء صف",
            )
        )

        with st.form("teacher_create_class"):
            class_name = st.text_input(
                tr(
                    "Class name",
                    "اسم الصف",
                ),
                placeholder=tr(
                    "Math Foundations · Grade 7",
                    "أساسيات الرياضيات · الصف السابع",
                ),
            )

            year = st.text_input(
                tr(
                    "Academic year",
                    "السنة الأكاديمية",
                ),
                placeholder="2026–2027",
            )

            create_clicked = st.form_submit_button(
                tr(
                    "Create class",
                    "إنشاء الصف",
                ),
                type="primary",
                use_container_width=True,
            )

        if create_clicked:
            if not class_name.strip() or not year.strip():
                st.error(
                    tr(
                        "Class name and academic year are required.",
                        "اسم الصف والسنة الأكاديمية مطلوبان.",
                    )
                )

            else:
                create_class(
                    teacher_id,
                    class_name.strip(),
                    year.strip(),
                )

                st.success(
                    tr(
                        "Class created.",
                        "تم إنشاء الصف.",
                    )
                )

                st.rerun()

    # --------------------------------------------------------
    # ROSTER
    # --------------------------------------------------------

    with c2:
        st.subheader(
            tr(
                "Roster",
                "قائمة الطلاب",
            )
        )

        if not classes:
            empty_state(
                tr(
                    "Create a class first",
                    "أنشئ صفاً أولاً",
                ),
                tr(
                    "A class is required before learners can be enrolled.",
                    "يجب إنشاء صف قبل تسجيل الطلاب.",
                ),
            )

        else:
            class_map = {
                f"{c['name']} · {c.get('year') or ''}": c
                for c in classes
            }

            selected_label = st.selectbox(
                tr(
                    "Class",
                    "الصف",
                ),
                list(class_map.keys()),
                key="roster_class_select",
            )

            selected_class = class_map[selected_label]
            class_id = int(selected_class["id"])

            all_students = list_active_students()
            roster = class_roster(class_id)

            enrolled_ids = {
                int(r["student_id"])
                for r in roster
                if r.get("status") == "active"
            }

            available = [
                s
                for s in all_students
                if int(s["id"]) not in enrolled_ids
            ]

            if available:
                add_map = {
                    f"{s.get('display_name') or s['email']} · {s['email']}": s
                    for s in available
                }

                add_label = st.selectbox(
                    tr(
                        "Add learner",
                        "إضافة طالب",
                    ),
                    list(add_map.keys()),
                    key="enroll_student_select",
                )

                if st.button(
                    tr(
                        "Enroll learner",
                        "تسجيل الطالب",
                    ),
                    type="primary",
                    key="enroll_student_btn",
                ):
                    enroll_student(
                        class_id,
                        int(add_map[add_label]["id"]),
                    )

                    st.success(
                        tr(
                            "Learner enrolled.",
                            "تم تسجيل الطالب.",
                        )
                    )

                    st.rerun()

            else:
                st.caption(
                    tr(
                        "All active students are already enrolled in this class.",
                        "جميع الطلاب النشطين مسجلون بالفعل في هذا الصف.",
                    )
                )

            active_roster = [
                r
                for r in roster
                if r.get("status") == "active"
            ]

            if active_roster:
                for r in active_roster:
                    row1, row2 = st.columns(
                        [0.78, 0.22]
                    )

                    with row1:
                        st.write(
                            f"**{r.get('display_name') or r.get('email')}**"
                        )
                        st.caption(
                            r.get(
                                "email",
                                "",
                            )
                        )

                    with row2:
                        if st.button(
                            tr(
                                "Remove",
                                "إزالة",
                            ),
                            key=(
                                f"remove_{class_id}_"
                                f"{r['student_id']}"
                            ),
                            use_container_width=True,
                        ):
                            remove_student(
                                class_id,
                                int(r["student_id"]),
                            )

                            st.rerun()

            else:
                empty_state(
                    tr(
                        "No learners enrolled",
                        "لا يوجد طلاب مسجلون",
                    ),
                    tr(
                        "Use the selector above to add students to this class.",
                        "استخدم القائمة أعلاه لإضافة طلاب إلى هذا الصف.",
                    ),
                )


# ============================================================
# QUESTION BANK TAB
# ============================================================

with questions_tab:
    section_heading(
        tr(
            "Question bank",
            "بنك الأسئلة",
        ),
        tr(
            "Search, add, edit, import, and export curriculum items.",
            "ابحث عن الأسئلة وأضفها وعدّلها واستوردها وصدّرها.",
        ),
    )

    topics = list_topics(
        active_only=True
    )

    topic_by_name = {
        t["name"]: int(t["id"])
        for t in topics
    }

    f1, f2, f3, f4 = st.columns(
        [1.25, 0.8, 0.8, 1.4]
    )

    with f1:
        topic_filter = st.selectbox(
            tr(
                "Topic",
                "الموضوع",
            ),
            ["All"] + list(topic_by_name.keys()),
            key="q_topic_filter",
            format_func=translate_topic_option,
        )

    with f2:
        difficulty_filter = st.selectbox(
            tr(
                "Difficulty",
                "الصعوبة",
            ),
            [
                "All",
                "Easy",
                "Medium",
                "Hard",
            ],
            key="q_diff_filter",
            format_func=translate_difficulty_option,
        )

    with f3:
        active_filter = st.selectbox(
            tr(
                "Status",
                "الحالة",
            ),
            [
                "Active",
                "Inactive",
                "All",
            ],
            key="q_active_filter",
            format_func=activity_status_label,
        )

    with f4:
        search_term = st.text_input(
            tr(
                "Search",
                "بحث",
            ),
            placeholder=tr(
                "Question text or answer",
                "نص السؤال أو الإجابة",
            ),
            key="q_term_filter",
        )

    active_value = {
        "Active": 1,
        "Inactive": 0,
        "All": None,
    }[active_filter]

    question_rows = search_questions(
        topic_id=(
            None
            if topic_filter == "All"
            else topic_by_name[topic_filter]
        ),
        difficulty=difficulty_filter,
        active=active_value,
        term=search_term,
    )

    # --------------------------------------------------------
    # ADD / EDIT QUESTION
    # --------------------------------------------------------

    with st.expander(
        tr(
            "Add or edit a question",
            "إضافة سؤال أو تعديله",
        ),
        expanded=not bool(question_rows),
    ):

        if not topics:
            st.warning(
                tr(
                    "Create at least one topic in the backend before adding questions.",
                    "أنشئ موضوعاً واحداً على الأقل في النظام قبل إضافة الأسئلة.",
                )
            )

        else:
            qid_text = st.text_input(
                tr(
                    "Question ID to edit (leave blank to create)",
                    "رقم السؤال للتعديل (اتركه فارغاً لإنشاء سؤال جديد)",
                ),
                key="q_edit_id",
            )

            e1, e2, e3 = st.columns(3)

            with e1:
                q_topic = st.selectbox(
                    tr(
                        "Topic",
                        "الموضوع",
                    ),
                    list(topic_by_name.keys()),
                    key="q_form_topic",
                    format_func=topic_label,
                )

            with e2:
                q_diff = st.selectbox(
                    tr(
                        "Difficulty",
                        "الصعوبة",
                    ),
                    [
                        "Easy",
                        "Medium",
                        "Hard",
                    ],
                    key="q_form_diff",
                    format_func=difficulty_label,
                )

            with e3:
                input_mode = st.selectbox(
                    tr(
                        "Input mode",
                        "طريقة الإجابة",
                    ),
                    [
                        "text",
                        "mcq",
                        "draw",
                    ],
                    key="q_form_mode",
                    format_func=input_mode_label,
                )

            prompt = st.text_area(
                tr(
                    "Prompt",
                    "نص السؤال",
                ),
                height=100,
                key="q_form_prompt",
            )

            hint = st.text_input(
                tr(
                    "Hint (optional)",
                    "تلميح (اختياري)",
                ),
                key="q_form_hint",
            )

            correct = st.text_input(
                tr(
                    "Correct answer",
                    "الإجابة الصحيحة",
                ),
                key="q_form_correct",
            )

            choices = st.text_input(
                tr(
                    "MCQ choices (comma-separated, optional)",
                    "خيارات الاختيار من متعدد (مفصولة بفواصل، اختياري)",
                ),
                key="q_form_choices",
            )

            a1, a2, a3 = st.columns(3)

            with a1:
                answer_type = st.selectbox(
                    tr(
                        "Grading",
                        "طريقة التصحيح",
                    ),
                    [
                        "exact",
                        "numeric",
                    ],
                    key="q_form_answer_type",
                    format_func=grading_label,
                )

            with a2:
                tolerance = st.number_input(
                    tr(
                        "Numeric tolerance",
                        "هامش الخطأ الرقمي",
                    ),
                    min_value=0.0,
                    value=0.0,
                    step=0.1,
                    key="q_form_tol",
                )

            with a3:
                points = st.number_input(
                    tr(
                        "Points",
                        "العلامة",
                    ),
                    min_value=0.1,
                    value=1.0,
                    step=0.5,
                    key="q_form_points",
                )

            if st.button(
                tr(
                    "Save question",
                    "حفظ السؤال",
                ),
                type="primary",
                key="save_question",
            ):
                try:
                    qid = (
                        int(qid_text)
                        if qid_text.strip()
                        else None
                    )

                    choices_json = None

                    if choices.strip():
                        choices_json = json.dumps(
                            [
                                x.strip()
                                for x in choices.split(",")
                                if x.strip()
                            ],
                            ensure_ascii=False,
                        )

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

                    st.success(
                        tr(
                            "Question saved.",
                            "تم حفظ السؤال.",
                        )
                    )

                    st.rerun()

                except Exception as e:
                    st.error(
                        tr(
                            f"Could not save question: {e}",
                            f"تعذر حفظ السؤال: {e}",
                        )
                    )

    # --------------------------------------------------------
    # QUESTION TABLE
    # --------------------------------------------------------

    if question_rows:
        qdf = pd.DataFrame(
            question_rows
        )

        qdf["accuracy"] = qdf.apply(
            lambda r: (
                float(
                    r.get(
                        "n_correct",
                        0,
                    )
                )
                / float(
                    r.get(
                        "n_attempts",
                        0,
                    )
                )
            )
            if float(
                r.get(
                    "n_attempts",
                    0,
                )
                or 0
            )
            > 0
            else None,
            axis=1,
        )

        show = [
            c
            for c in [
                "id",
                "topic_name",
                "difficulty",
                "prompt",
                "input_mode",
                "n_attempts",
                "accuracy",
                "avg_time_sec",
            ]
            if c in qdf.columns
        ]

        display_qdf = translate_question_table(
            qdf[show]
        )

        st.dataframe(
            display_qdf,
            use_container_width=True,
            hide_index=True,
        )

    else:
        empty_state(
            tr(
                "No matching questions",
                "لا توجد أسئلة مطابقة",
            ),
            tr(
                "Change the filters or add a new question.",
                "غيّر خيارات البحث أو أضف سؤالاً جديداً.",
            ),
        )

    # --------------------------------------------------------
    # IMPORT / EXPORT
    # --------------------------------------------------------

    st.divider()

    io1, io2 = st.columns(
        2,
        gap="large",
    )

    with io1:
        st.subheader(
            tr(
                "Export",
                "تصدير",
            )
        )

        st.caption(
            tr(
                "Export the current filtered view as CSV.",
                "صدّر العرض الحالي بعد تطبيق عوامل التصفية بصيغة CSV.",
            )
        )

        if question_rows:
            st.download_button(
                tr(
                    "Download question bank CSV",
                    "تحميل بنك الأسئلة CSV",
                ),
                data=export_questions_csv(
                    question_rows
                ),
                file_name="dyscalc_question_bank.csv",
                mime="text/csv",
                use_container_width=True,
            )

    with io2:
        st.subheader(
            tr(
                "Import",
                "استيراد",
            )
        )

        upload = st.file_uploader(
            tr(
                "CSV file",
                "ملف CSV",
            ),
            type=["csv"],
            key="question_csv_upload",
        )

        if upload:
            size = getattr(
                upload,
                "size",
                0,
            ) or 0

            if size > 2 * 1024 * 1024:
                st.error(
                    tr(
                        "For safety, this UI limits question imports to 2 MB. "
                        "Split larger files into smaller batches.",
                        "لأسباب تتعلق بالأمان، يقتصر استيراد الأسئلة من هذه الواجهة "
                        "على ملفات بحجم 2 ميجابايت. قسّم الملفات الأكبر إلى ملفات أصغر.",
                    )
                )

            elif st.button(
                tr(
                    "Validate & import",
                    "تحقق واستورد",
                ),
                type="primary",
                key="question_csv_import",
                use_container_width=True,
            ):
                try:
                    inserted, updated = import_questions_csv(
                        upload.getvalue(),
                        created_by=teacher_id,
                    )

                    st.success(
                        tr(
                            f"Imported successfully: {inserted} added, {updated} updated.",
                            f"تم الاستيراد بنجاح: تمت إضافة {inserted} وتحديث {updated}.",
                        )
                    )

                    st.rerun()

                except Exception as e:
                    st.error(
                        tr(
                            f"Import failed: {e}",
                            f"فشل الاستيراد: {e}",
                        )
                    )


# ============================================================
# ASSESSMENTS TAB
# ============================================================

with assessments_tab:
    section_heading(
        tr(
            "Assessment builder",
            "إنشاء الاختبارات",
        ),
        tr(
            "Create focused assessments and assign them to classes or individual learners.",
            "أنشئ اختبارات مركزة وعيّنها للصفوف أو لطلاب محددين.",
        ),
    )

    topics = list_topics(
        active_only=True
    )

    topic_map = {
        t["name"]: int(t["id"])
        for t in topics
    }

    class_map = {
        f"{c['name']} · {c.get('year') or ''}": int(c["id"])
        for c in classes
    }

    student_map = {
        f"{s.get('display_name') or s['email']} · {s['email']}": int(s["id"])
        for s in students
    }

    # --------------------------------------------------------
    # CREATE ASSESSMENT
    # --------------------------------------------------------

    with st.expander(
        tr(
            "Create assessment",
            "إنشاء اختبار",
        ),
        expanded=not bool(assessments),
    ):

        with st.form(
            "create_assessment_form"
        ):
            title = st.text_input(
                tr(
                    "Assessment title",
                    "عنوان الاختبار",
                ),
                placeholder=tr(
                    "Fractions readiness check",
                    "اختبار جاهزية الكسور",
                ),
            )

            selected_topics = st.multiselect(
                tr(
                    "Topics",
                    "المواضيع",
                ),
                list(topic_map.keys()),
                format_func=topic_label,
            )

            a1, a2, a3 = st.columns(3)

            with a1:
                difficulty = st.selectbox(
                    tr(
                        "Difficulty",
                        "الصعوبة",
                    ),
                    [
                        "Easy",
                        "Medium",
                        "Hard",
                    ],
                    format_func=difficulty_label,
                )

            with a2:
                num_questions = st.number_input(
                    tr(
                        "Questions",
                        "عدد الأسئلة",
                    ),
                    min_value=1,
                    max_value=100,
                    value=10,
                )

            with a3:
                duration_minutes = st.number_input(
                    tr(
                        "Duration (minutes)",
                        "المدة (بالدقائق)",
                    ),
                    min_value=1,
                    max_value=180,
                    value=15,
                )

            target_classes = st.multiselect(
                tr(
                    "Assign to classes",
                    "تعيين للصفوف",
                ),
                list(class_map.keys()),
            )

            target_students = st.multiselect(
                tr(
                    "Assign to individual learners",
                    "تعيين لطلاب محددين",
                ),
                list(student_map.keys()),
            )

            st.caption(
                tr(
                    "Scheduling is optional. Leave both fields empty to make "
                    "the assessment immediately available according to instance status.",
                    "الجدولة اختيارية. اترك حقلي البداية والنهاية فارغين "
                    "ليصبح الاختبار متاحاً مباشرة حسب حالة التعيين.",
                )
            )

            start_text = st.text_input(
                tr(
                    "Start (optional, Jordan local time)",
                    "وقت البدء (اختياري، بتوقيت الأردن)",
                ),
                placeholder="2026-09-07 09:00",
            )

            end_text = st.text_input(
                tr(
                    "End (optional, Jordan local time)",
                    "وقت الانتهاء (اختياري، بتوقيت الأردن)",
                ),
                placeholder="2026-09-14 23:59",
            )

            create_assessment_clicked = st.form_submit_button(
                tr(
                    "Create & assign",
                    "إنشاء وتعيين",
                ),
                type="primary",
                use_container_width=True,
            )

        if create_assessment_clicked:
            if not title.strip():
                st.error(
                    tr(
                        "Assessment title is required.",
                        "عنوان الاختبار مطلوب.",
                    )
                )

            elif not selected_topics:
                st.error(
                    tr(
                        "Select at least one topic.",
                        "اختر موضوعاً واحداً على الأقل.",
                    )
                )

            elif not target_classes and not target_students:
                st.error(
                    tr(
                        "Select at least one class or learner.",
                        "اختر صفاً واحداً أو طالباً واحداً على الأقل.",
                    )
                )

            else:
                try:
                    assessment_id = create_assessment(
                        teacher_id=teacher_id,
                        title=title.strip(),
                        topic_ids=[
                            topic_map[x]
                            for x in selected_topics
                        ],
                        difficulty=difficulty,
                        num_questions=int(
                            num_questions
                        ),
                        duration_seconds=(
                            int(
                                duration_minutes
                            )
                            * 60
                        ),
                        start_at_in=(
                            start_text.strip()
                            or None
                        ),
                        end_at_in=(
                            end_text.strip()
                            or None
                        ),
                        class_ids=[
                            class_map[x]
                            for x in target_classes
                        ],
                        student_ids=[
                            student_map[x]
                            for x in target_students
                        ],
                    )

                    st.success(
                        tr(
                            f"Assessment #{assessment_id} created and assigned.",
                            f"تم إنشاء الاختبار رقم {assessment_id} وتعيينه.",
                        )
                    )

                    st.rerun()

                except Exception as e:
                    st.error(
                        tr(
                            f"Could not create assessment: {e}",
                            f"تعذر إنشاء الاختبار: {e}",
                        )
                    )

    # --------------------------------------------------------
    # ASSESSMENT LIST
    # --------------------------------------------------------

    assessments_now = teacher_assessments(
        teacher_id
    )

    if not assessments_now:
        empty_state(
            tr(
                "No assessments",
                "لا توجد اختبارات",
            ),
            tr(
                "Create an assessment above to begin assigning work.",
                "أنشئ اختباراً أعلاه للبدء في تعيين المهام.",
            ),
        )

    else:
        for a in assessments_now[:12]:
            displayed_difficulty = difficulty_label(
                a.get(
                    "difficulty"
                )
                or "Adaptive"
            )

            with st.expander(
                f"{a['title']} · {displayed_difficulty}"
            ):
                c1, c2, c3 = st.columns(3)

                with c1:
                    st.metric(
                        tr(
                            "Questions",
                            "عدد الأسئلة",
                        ),
                        a.get(
                            "num_questions",
                            "—",
                        ),
                    )

                with c2:
                    st.metric(
                        tr(
                            "Duration",
                            "المدة",
                        ),
                        tr(
                            f"{int(a.get('duration_seconds') or 0) // 60} min",
                            f"{int(a.get('duration_seconds') or 0) // 60} دقيقة",
                        ),
                    )

                with c3:
                    st.metric(
                        tr(
                            "Created",
                            "تاريخ الإنشاء",
                        ),
                        str(
                            a.get(
                                "created_at"
                            )
                            or ""
                        )[:16],
                    )

                topic_names = [
                    topic_label(x["name"])
                    for x in assessment_topics_view(
                        int(a["id"])
                    )
                ]

                st.write(
                    f"**{tr('Topics', 'المواضيع')}:**",
                    (
                        ", ".join(
                            topic_names
                        )
                        if topic_names
                        else "—"
                    ),
                )

                targets = assessment_targets_view(
                    int(a["id"])
                )

                instances = assessment_instances_view(
                    int(a["id"])
                )

                tc1, tc2 = st.columns(2)

                with tc1:
                    st.caption(
                        tr(
                            "Targets",
                            "المستهدفون",
                        )
                    )

                    if targets:
                        tdf = pd.DataFrame(
                            targets
                        )

                        cols = [
                            c
                            for c in [
                                "class_name",
                                "class_year",
                                "student_name",
                                "student_email",
                            ]
                            if c in tdf.columns
                        ]

                        display_tdf = tdf[
                            cols
                        ].copy()

                        display_tdf = display_tdf.rename(
                            columns={
                                "class_name": tr(
                                    "Class",
                                    "الصف",
                                ),
                                "class_year": tr(
                                    "Academic year",
                                    "السنة الأكاديمية",
                                ),
                                "student_name": tr(
                                    "Student",
                                    "الطالب",
                                ),
                                "student_email": tr(
                                    "Email",
                                    "البريد الإلكتروني",
                                ),
                            }
                        )

                        st.dataframe(
                            display_tdf,
                            use_container_width=True,
                            hide_index=True,
                        )

                with tc2:
                    st.caption(
                        tr(
                            "Learner instances",
                            "حالات الطلاب",
                        )
                    )

                    if instances:
                        idf = pd.DataFrame(
                            instances
                        )

                        cols = [
                            c
                            for c in [
                                "display_name",
                                "email",
                                "status",
                                "started_at",
                                "submitted_at",
                            ]
                            if c in idf.columns
                        ]

                        display_idf = idf[
                            cols
                        ].copy()

                        if "status" in display_idf.columns:
                            display_idf[
                                "status"
                            ] = display_idf[
                                "status"
                            ].apply(
                                status_label
                            )

                        display_idf = display_idf.rename(
                            columns={
                                "display_name": tr(
                                    "Learner",
                                    "الطالب",
                                ),
                                "email": tr(
                                    "Email",
                                    "البريد الإلكتروني",
                                ),
                                "status": tr(
                                    "Status",
                                    "الحالة",
                                ),
                                "started_at": tr(
                                    "Started",
                                    "وقت البدء",
                                ),
                                "submitted_at": tr(
                                    "Submitted",
                                    "وقت التسليم",
                                ),
                            }
                        )

                        st.dataframe(
                            display_idf,
                            use_container_width=True,
                            hide_index=True,
                        )


# ============================================================
# LEARNER INSIGHTS TAB
# ============================================================

with insights_tab:
    section_heading(
        tr(
            "Learner insights",
            "تحليل الطلاب",
        ),
        tr(
            "Translate performance into next-step teaching decisions.",
            "حوّل الأداء إلى قرارات تعليمية واضحة للخطوة التالية.",
        ),
    )

    if not students:
        empty_state(
            tr(
                "No enrolled learners",
                "لا يوجد طلاب مسجلون",
            ),
            tr(
                "Enroll students in one of your classes to view insights.",
                "سجّل الطلاب في أحد صفوفك لعرض التحليلات.",
            ),
        )

    else:
        student_select_map = {
            f"{s.get('display_name') or s['email']} · {s['email']}": s
            for s in students
        }

        learner_label = st.selectbox(
            tr(
                "Learner",
                "الطالب",
            ),
            list(
                student_select_map.keys()
            ),
            key="analytics_student",
        )

        learner = student_select_map[
            learner_label
        ]

        learner_id = int(
            learner["id"]
        )

        mastery = mastery_for_student(
            learner_id
        )

        results = results_for_student(
            learner_id
        )

        signals = engagement_signals_for_student(
            learner_id
        )

        # ----------------------------------------------------
        # MASTERY
        # ----------------------------------------------------

        if mastery:
            st.subheader(
                tr(
                    "Topic mastery",
                    "إتقان المواضيع",
                )
            )

            for m in mastery:
                p = float(
                    m.get(
                        "p_knowledge"
                    )
                    or 0.0
                )

                label = translated_mastery_label(
                    p
                )

                c1, c2 = st.columns(
                    [0.78, 0.22]
                )

                with c1:
                    st.write(
                        f"**{topic_label(m.get('topic_name'))}** · {label}"
                    )

                    st.progress(
                        max(
                            0.0,
                            min(
                                1.0,
                                p,
                            ),
                        )
                    )

                    st.caption(
                        tr(
                            f"Evidence count: {int(m.get('n_obs') or 0)}",
                            f"عدد الأدلة: {int(m.get('n_obs') or 0)}",
                        )
                    )

                with c2:
                    st.metric(
                        tr(
                            "Mastery",
                            "الإتقان",
                        ),
                        percent(
                            p
                        ),
                    )

        else:
            empty_state(
                tr(
                    "No mastery history",
                    "لا يوجد سجل إتقان",
                ),
                tr(
                    "Mastery will appear after the learner completes graded work.",
                    "سيظهر مستوى الإتقان بعد إكمال الطالب لأعمال تم تقييمها.",
                ),
            )

        st.divider()

        r1, r2 = st.columns(
            [1.1, 0.9],
            gap="large",
        )

        # ----------------------------------------------------
        # PERFORMANCE HISTORY
        # ----------------------------------------------------

        with r1:
            st.subheader(
                tr(
                    "Performance history",
                    "سجل الأداء",
                )
            )

            if results:
                rdf = pd.DataFrame(
                    results
                ).sort_values(
                    "computed_at"
                )

                if "accuracy" in rdf.columns:
                    chart_df = rdf[
                        [
                            "computed_at",
                            "accuracy",
                        ]
                    ].copy()

                    chart_df[
                        "computed_at"
                    ] = pd.to_datetime(
                        chart_df[
                            "computed_at"
                        ],
                        errors="coerce",
                    )

                    chart_df = (
                        chart_df
                        .dropna()
                        .set_index(
                            "computed_at"
                        )
                    )

                    st.line_chart(
                        chart_df,
                        use_container_width=True,
                    )

                show = [
                    c
                    for c in [
                        "title",
                        "difficulty",
                        "accuracy",
                        "total_score",
                        "model_recommendation",
                        "computed_at",
                    ]
                    if c in rdf.columns
                ]

                display_rdf = rdf[
                    show
                ].sort_values(
                    "computed_at",
                    ascending=False,
                ).copy()

                if "difficulty" in display_rdf.columns:
                    display_rdf[
                        "difficulty"
                    ] = display_rdf[
                        "difficulty"
                    ].apply(
                        difficulty_label
                    )

                display_rdf = display_rdf.rename(
                    columns={
                        "title": tr(
                            "Assessment",
                            "الاختبار",
                        ),
                        "difficulty": tr(
                            "Difficulty",
                            "الصعوبة",
                        ),
                        "accuracy": tr(
                            "Accuracy",
                            "الدقة",
                        ),
                        "total_score": tr(
                            "Score",
                            "العلامة",
                        ),
                        "model_recommendation": tr(
                            "Recommendation",
                            "التوصية",
                        ),
                        "computed_at": tr(
                            "Computed at",
                            "وقت التحليل",
                        ),
                    }
                )

                st.dataframe(
                    display_rdf,
                    use_container_width=True,
                    hide_index=True,
                )

            else:
                empty_state(
                    tr(
                        "No graded assessments",
                        "لا توجد اختبارات تم تقييمها",
                    ),
                    tr(
                        "The learner has not completed a graded assessment yet.",
                        "لم يكمل الطالب اختباراً تم تقييمه حتى الآن.",
                    ),
                )

        # ----------------------------------------------------
        # SUPPORT SIGNALS
        # ----------------------------------------------------

        with r2:
            st.subheader(
                tr(
                    "Learning support signals",
                    "مؤشرات دعم التعلم",
                )
            )

            st.caption(
                tr(
                    "These are heuristic interaction indicators, not emotional or clinical diagnoses.",
                    "هذه مؤشرات تقديرية للتفاعل وليست تشخيصات عاطفية أو طبية.",
                )
            )

            if signals:
                sdf = pd.DataFrame(
                    signals
                ).rename(
                    columns={
                        "avg_frustrated": tr(
                            "Interaction friction",
                            "صعوبة التفاعل",
                        ),
                        "avg_confused": tr(
                            "Rapid error signal",
                            "مؤشر الأخطاء السريعة",
                        ),
                        "n_answers": tr(
                            "Evidence count",
                            "عدد الأدلة",
                        ),
                    }
                )

                st.dataframe(
                    sdf,
                    use_container_width=True,
                    hide_index=True,
                )

            else:
                empty_state(
                    tr(
                        "No support-signal history",
                        "لا يوجد سجل لمؤشرات الدعم",
                    ),
                    tr(
                        "Signals appear after finalized answers are graded.",
                        "تظهر المؤشرات بعد تصحيح الإجابات النهائية.",
                    ),
                )
