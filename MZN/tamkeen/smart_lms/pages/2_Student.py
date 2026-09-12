from __future__ import annotations

import base64
import hashlib
import io
import json
import re
import time
from html import escape
from datetime import datetime, timezone

import pandas as pd
import streamlit as st
from PIL import Image

try:
    from streamlit_drawable_canvas import st_canvas
except ImportError:
    st_canvas = None

from services.auth import logout, require_login
from services.symbol_recognizer import predict_from_canvas
from services.i18n import (
    apply_language_direction,
    difficulty_label,
    get_lang,
    language_switcher,
    mastery_label as translated_mastery_label,
    status_label as translated_status_label,
    topic_label,
)
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
    metric_card,
    page_hero,
    percent,
    section_heading,
    sidebar_brand,
)


# ============================================================
# PAGE CONFIG
# ============================================================

st.set_page_config(
    page_title="Student Workspace · DysCalc AI",
    page_icon="🧠",
    layout="wide",
)

apply_theme()

# Language selector:
# English <-> العربية
language_switcher(
    location="sidebar",
    key="student_language_selector",
)

# RTL for Arabic, LTR for English
apply_language_direction()

sidebar_brand()


# ============================================================
# LOCAL BILINGUAL HELPER
# ============================================================

def tr(en: str, ar: str) -> str:
    """
    Return English or Arabic text according to the user's language choice.
    """
    return ar if get_lang() == "ar" else en


def display_topic(value: str | None) -> str:
    return topic_label(value)


def display_difficulty(value: str | None) -> str:
    return difficulty_label(value or "Adaptive")


def display_status(value: str | None) -> str:
    return translated_status_label(value)


def _status_badge(status: str | None) -> None:
    """
    Local translated status badge so the status text also changes language.
    """
    label = display_status(status)
    st.markdown(
        f"""
        <div style="
            display:inline-block;
            padding:0.22rem 0.65rem;
            border-radius:999px;
            border:1px solid rgba(120,120,120,.25);
            font-size:.84rem;
            font-weight:600;
            margin:.15rem 0 .35rem 0;
        ">
            {escape(label)}
        </div>
        """,
        unsafe_allow_html=True,
    )


def _translate_recommendation(text: str | None) -> str:
    """
    Translate a few known recommendation phrases when Arabic is selected.
    Unknown model-generated text is shown as-is so we never change meaning.
    """
    if not text:
        return tr(
            "Keep practicing and review feedback with your teacher.",
            "استمر في التدريب وراجع التغذية الراجعة مع معلمك.",
        )

    if get_lang() != "ar":
        return str(text)

    replacements = {
        "High slip/guess ratio detected": "تم رصد نسبة مرتفعة من الأخطاء أو التخمين",
        "Needs fundamental review": "يحتاج إلى مراجعة المهارات الأساسية",
        "Low mastery detected": "تم رصد مستوى إتقان منخفض",
        "Student needs more practice": "يحتاج الطالب إلى مزيد من التدريب",
        "Ready for harder difficulty": "جاهز لمستوى صعوبة أعلى",
        "Keep practicing": "استمر في التدريب",
        "review feedback with your teacher": "راجع التغذية الراجعة مع معلمك",
    }

    out = str(text)
    for en, ar in replacements.items():
        out = out.replace(en, ar)
    return out


# ============================================================
# AUTHENTICATION
# ============================================================

user = require_login(role="student")
student_id = int(user["id"])


# ============================================================
# SIDEBAR
# ============================================================

st.sidebar.caption(
    tr("Student account", "حساب الطالب")
)

st.sidebar.write(
    f"**{user.get('display_name') or user.get('email')}**"
)

st.sidebar.caption(
    user.get("email", "")
)

if st.sidebar.button(
    tr("Sign out", "تسجيل الخروج"),
    use_container_width=True,
):
    logout()


# ============================================================
# HERO
# ============================================================

page_hero(
    tr(
        "Student Workspace",
        "مساحة عمل الطالب",
    ),
    tr(
        "One task at a time, clear progress, and learning feedback that helps you know what to do next.",
        "مهمة واحدة في كل مرة، وتقدم واضح، وتغذية راجعة تساعدك على معرفة ما الذي يجب أن تفعله بعد ذلك.",
    ),
    tr(
        "Focused adaptive learning",
        "تعلم تكيفي مركز",
    ),
)


# ============================================================
# STUDENT DATA
# ============================================================

instances = student_instances(student_id)
results = results_for_student(student_id)
mastery = mastery_for_student(student_id)

active_count = sum(
    1
    for x in instances
    if x.get("instance_status") in ("assigned", "in_progress")
)

completed_count = sum(
    1
    for x in instances
    if x.get("instance_status") == "graded"
)

avg_accuracy = None

if results:
    vals = [
        float(r.get("accuracy") or 0.0)
        for r in results
    ]

    avg_accuracy = (
        sum(vals) / len(vals)
        if vals
        else None
    )

strong_topics = sum(
    1
    for m in mastery
    if float(m.get("p_knowledge") or 0.0) >= 0.85
)


# ============================================================
# TOP METRICS
# ============================================================

m1, m2, m3, m4 = st.columns(4)

with m1:
    metric_card(
        tr("Available work", "المهام المتاحة"),
        active_count,
        tr(
            "Assigned or in-progress",
            "مهام معينة أو قيد التنفيذ",
        ),
    )

with m2:
    metric_card(
        tr("Completed", "المكتملة"),
        completed_count,
        tr(
            "Graded learning sessions",
            "جلسات تعلم تم تقييمها",
        ),
    )

with m3:
    metric_card(
        tr("Average accuracy", "متوسط الدقة"),
        (
            percent(avg_accuracy)
            if avg_accuracy is not None
            else "—"
        ),
        tr(
            "Across graded work",
            "عبر الأعمال التي تم تقييمها",
        ),
    )

with m4:
    metric_card(
        tr("Strong topics", "المهارات القوية"),
        strong_topics,
        tr(
            "Topics at 85%+ mastery",
            "المهارات التي وصلت إلى إتقان 85% أو أكثر",
        ),
    )


# ============================================================
# TABS
# ============================================================

st.write("")

learn_tab, progress_tab, reports_tab = st.tabs(
    [
        tr("My Learning", "تعلمي"),
        tr("Progress", "التقدم"),
        tr("Reports", "التقارير"),
    ]
)


# ============================================================
# HELPERS
# ============================================================

def _remaining_seconds(inst: dict) -> int | None:
    ends = utc_z_to_dt(inst.get("ends_at"))

    if not ends:
        return None

    return max(
        0,
        int(
            (
                ends
                - datetime.now(timezone.utc)
            ).total_seconds()
        ),
    )


def _format_time(seconds: int | None) -> str:
    if seconds is None:
        return "—"

    m, s = divmod(
        max(0, seconds),
        60,
    )

    h, m = divmod(
        m,
        60,
    )

    if h:
        return f"{h:02d}:{m:02d}:{s:02d}"

    return f"{m:02d}:{s:02d}"


def _save_standard_answer(
    instance_id: int,
    question_id: int,
    answer: str,
    *,
    drawing_png_b64: str | None = None,
    pred_confidence: float | None = None,
    pred_topk_json: str | None = None,
    count_attempt: bool = True,
) -> None:
    """Save one canonical answer value for a standard assessment question."""
    attempts_key = f"attempts_{instance_id}_{question_id}"

    if count_attempt:
        st.session_state[attempts_key] = int(
            st.session_state.get(attempts_key, 0)
        ) + 1
    elif attempts_key not in st.session_state:
        st.session_state[attempts_key] = 0

    hint_key = f"hints_{instance_id}_{question_id}"
    first_key = f"first_seen_{instance_id}_{question_id}"
    first_seen = float(st.session_state.get(first_key, time.time()))
    ms_first = max(1, int((time.time() - first_seen) * 1000))

    ok = upsert_autosave(
        instance_id=instance_id,
        student_id=student_id,
        question_id=question_id,
        answer_text=str(answer or ""),
        ms_first_response=ms_first,
        hint_count=int(st.session_state.get(hint_key, 0)),
        attempts=max(1, int(st.session_state.get(attempts_key, 0))),
        drawing_png_b64=drawing_png_b64,
        pred_confidence=pred_confidence,
        pred_topk_json=pred_topk_json,
    )

    st.session_state[f"saved_{instance_id}_{question_id}"] = bool(ok)


def _autosave_standard(
    instance_id: int,
    question_id: int,
    widget_key: str,
) -> None:
    """Existing callback for MCQ/normal inputs."""
    answer = str(st.session_state.get(widget_key, "") or "")
    _save_standard_answer(
        instance_id,
        question_id,
        answer,
        count_attempt=True,
    )


def _sync_keyboard_standard(
    instance_id: int,
    question_id: int,
    typed_key: str,
    answer_key: str,
) -> None:
    """Copy the keyboard value to the canonical answer and autosave it."""
    answer = str(st.session_state.get(typed_key, "") or "").strip()
    st.session_state[answer_key] = answer
    _save_standard_answer(
        instance_id,
        question_id,
        answer,
        count_attempt=True,
    )


def _switch_standard_answer_method(
    instance_id: int,
    question_id: int,
    method_key: str,
    typed_key: str,
    answer_key: str,
) -> None:
    """
    Keep only the answer belonging to the student's currently selected method.
    This prevents an old typed answer being submitted after switching to handwriting.
    """
    method = st.session_state.get(method_key, "keyboard")

    if method == "keyboard":
        answer = str(st.session_state.get(typed_key, "") or "").strip()
    else:
        answer = ""

    st.session_state[answer_key] = answer
    _save_standard_answer(
        instance_id,
        question_id,
        answer,
        count_attempt=False,
    )


def _switch_adaptive_answer_method(
    method_key: str,
    typed_key: str,
    answer_key: str,
) -> None:
    """Switch the adaptive question between keyboard and handwriting safely."""
    method = st.session_state.get(method_key, "keyboard")
    if method == "keyboard":
        st.session_state[answer_key] = str(
            st.session_state.get(typed_key, "") or ""
        ).strip()
    else:
        st.session_state[answer_key] = ""


def _sync_keyboard_adaptive(
    typed_key: str,
    answer_key: str,
) -> None:
    st.session_state[answer_key] = str(
        st.session_state.get(typed_key, "") or ""
    ).strip()

def _timer_body(
    instance_id: int,
) -> None:

    inst = get_instance(
        instance_id,
        student_id,
    )

    if (
        not inst
        or inst.get("status")
        != "in_progress"
    ):
        return

    remaining = _remaining_seconds(
        inst
    )

    st.metric(
        tr(
            "Time remaining",
            "الوقت المتبقي",
        ),
        _format_time(remaining),
    )

    if (
        remaining is not None
        and remaining <= 0
    ):

        try:

            submit_instance(
                instance_id,
                student_id,
                auto=True,
            )

            st.success(
                tr(
                    "Time ended. Your saved answers were submitted automatically.",
                    "انتهى الوقت. تم تسليم إجاباتك المحفوظة تلقائياً.",
                )
            )

            st.session_state.pop(
                "active_instance_id",
                None,
            )

            st.rerun()

        except Exception:
            pass


if hasattr(
    st,
    "fragment",
):

    timer_fragment = st.fragment(
        run_every="1s"
    )(
        _timer_body
    )

else:

    timer_fragment = (
        _timer_body
    )



# ============================================================
# INTERACTIVE HANDWRITING ANSWER BOARD
# ============================================================

_ARITHMETIC_RE = re.compile(
    r"(-?\d+)\s*([+\-xX×*/÷])\s*(-?\d+)"
)


def _solve_integer_arithmetic_prompt(prompt: str | None) -> int | None:
    """
    Read simple integer arithmetic from the visible prompt only.

    Used only to decide how many handwriting digit boxes to show.
    It does NOT read the stored answer key.
    """
    match = _ARITHMETIC_RE.search(str(prompt or ""))
    if not match:
        return None

    a = int(match.group(1))
    op = match.group(2)
    b = int(match.group(3))

    if op == "+":
        return a + b
    if op == "-":
        return a - b
    if op in ("x", "X", "×", "*"):
        return a * b
    if op in ("/", "÷"):
        if b == 0 or a % b != 0:
            return None
        return a // b

    return None


def _handwriting_supported(q: dict) -> bool:
    """
    The current CNN recognizes one symbol at a time.
    For the student answer board we deliberately use only digit outputs 0-9.
    """
    result = _solve_integer_arithmetic_prompt(q.get("prompt"))
    return result is not None and result >= 0


def _answer_box_count(q: dict) -> int:
    result = _solve_integer_arithmetic_prompt(q.get("prompt"))
    if result is None or result < 0:
        return 1

    # Current arithmetic can reach 4 answer digits (e.g. 999 + 999 = 1998).
    # Keep a small safety ceiling for future question-bank extensions.
    return max(1, min(6, len(str(int(result)))))


def _canvas_signature(images: list) -> str:
    digest = hashlib.sha1()
    for image_data in images:
        if image_data is None:
            digest.update(b"<blank>")
        else:
            digest.update(image_data.astype("uint8").tobytes())
    return digest.hexdigest()


def _combine_canvas_images_b64(images: list) -> str | None:
    """Combine all digit canvases into one PNG for the existing answer audit field."""
    pil_images = []

    for image_data in images:
        if image_data is None:
            continue
        pil_images.append(
            Image.fromarray(image_data.astype("uint8"), mode="RGBA")
        )

    if not pil_images:
        return None

    gap = 10
    total_width = sum(img.width for img in pil_images) + gap * (len(pil_images) - 1)
    max_height = max(img.height for img in pil_images)
    combined = Image.new("RGBA", (total_width, max_height), (255, 255, 255, 255))

    x = 0
    for img in pil_images:
        combined.paste(img, (x, 0))
        x += img.width + gap

    buf = io.BytesIO()
    combined.save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode("utf-8")


def _best_digit_prediction(image_data):
    """
    Run the CNN for one box.
    If its top class is an operator, choose the highest-probability digit from top-k.
    """
    pred, confidence, topk, _png_b64 = predict_from_canvas(
        image_data,
        topk=15,
    )

    pred = str(pred)
    if pred in set("0123456789"):
        return pred, float(confidence), topk

    for token, prob in topk:
        token = str(token)
        if token in set("0123456789"):
            return token, float(prob), topk

    return "", 0.0, topk


def _render_handwriting_board(
    *,
    q: dict,
    instance_id: int,
    question_id: int,
    answer_key: str,
    prefix: str,
    standard_autosave: bool,
) -> str:
    """
    Show one interactive drawing canvas per answer digit.

    Example: 5 + 5 -> two canvases -> CNN predicts 1 and 0 -> answer_text='10'.
    Numeric box order is always left-to-right, including when the page language is Arabic.
    """
    if st_canvas is None:
        st.error(
            tr(
                "Handwriting board is unavailable because streamlit-drawable-canvas is not installed.",
                "لوح الكتابة غير متاح لأن مكتبة streamlit-drawable-canvas غير مثبتة.",
            )
        )
        st.code("pip install streamlit-drawable-canvas")
        return ""

    box_count = _answer_box_count(q)
    reset_key = f"{prefix}_canvas_reset_{instance_id}_{question_id}"
    recognition_key = f"{prefix}_recognition_{instance_id}_{question_id}"

    if reset_key not in st.session_state:
        st.session_state[reset_key] = 0

    reset_token = int(st.session_state[reset_key])
    container_key = f"hwboxes_{prefix}_{instance_id}_{question_id}"

    st.markdown(
        """
        <style>
        div[class*="st-key-hwboxes_"] [data-testid="stHorizontalBlock"] {
            direction: ltr !important;
        }
        div[class*="st-key-hwboxes_"] canvas {
            border-radius: 12px !important;
        }
        </style>
        """,
        unsafe_allow_html=True,
    )

    st.info(
        tr(
            "Write ONE digit in each box, then press Recognize handwriting.",
            "اكتب رقماً واحداً فقط في كل مربع، ثم اضغط على التعرّف على الكتابة.",
        )
    )

    image_datas = []

    with st.container(key=container_key):
        columns = st.columns(box_count)

        for i, col in enumerate(columns):
            with col:
                st.caption(
                    tr(
                        f"Digit {i + 1}",
                        f"الخانة {i + 1}",
                    )
                )

                result = st_canvas(
                    fill_color="rgba(0, 0, 0, 0)",
                    stroke_width=10,
                    stroke_color="#111111",
                    background_color="#FFFFFF",
                    update_streamlit=True,
                    height=150,
                    width=130,
                    drawing_mode="freedraw",
                    display_toolbar=True,
                    key=(
                        f"{prefix}_canvas_{instance_id}_{question_id}_"
                        f"{i}_{reset_token}"
                    ),
                )

                image_datas.append(
                    result.image_data if result is not None else None
                )

    signature = _canvas_signature(image_datas)
    previous_recognition = st.session_state.get(recognition_key)

    # If the student edits a canvas after recognition, invalidate the old CNN result.
    if (
        previous_recognition
        and previous_recognition.get("signature") != signature
    ):
        st.session_state.pop(recognition_key, None)
        st.session_state[answer_key] = ""
        previous_recognition = None

    c1, c2 = st.columns([1, 1])

    with c1:
        recognize_clicked = st.button(
            tr("🔎 Recognize handwriting", "🔎 التعرّف على الكتابة"),
            type="primary",
            use_container_width=True,
            key=f"{prefix}_recognize_{instance_id}_{question_id}",
        )

    with c2:
        clear_clicked = st.button(
            tr("🧹 Clear all boxes", "🧹 مسح جميع المربعات"),
            use_container_width=True,
            key=f"{prefix}_clear_{instance_id}_{question_id}",
        )

    if clear_clicked:
        st.session_state[reset_key] = reset_token + 1
        st.session_state.pop(recognition_key, None)
        st.session_state[answer_key] = ""

        if standard_autosave:
            _save_standard_answer(
                instance_id,
                question_id,
                "",
                count_attempt=False,
            )

        st.rerun()

    if recognize_clicked:
        if any(image is None for image in image_datas):
            st.warning(
                tr(
                    "Draw a digit in every box before recognition.",
                    "ارسم رقماً في كل مربع قبل تشغيل التعرّف.",
                )
            )
        else:
            try:
                digits = []
                details = []

                for i, image_data in enumerate(image_datas):
                    digit, confidence, topk = _best_digit_prediction(image_data)

                    if not digit:
                        raise ValueError(
                            tr(
                                f"Box {i + 1} could not be recognized as a digit.",
                                f"تعذر التعرّف على الخانة {i + 1} كرقم.",
                            )
                        )

                    digits.append(digit)
                    details.append(
                        {
                            "box": i + 1,
                            "digit": digit,
                            "confidence": round(float(confidence), 6),
                            "topk": [
                                [str(token), round(float(prob), 6)]
                                for token, prob in topk
                            ],
                        }
                    )

                answer = "".join(digits)
                confidences = [d["confidence"] for d in details]
                overall_confidence = min(confidences) if confidences else 0.0
                drawing_png_b64 = _combine_canvas_images_b64(image_datas)
                pred_topk_json = json.dumps(details, ensure_ascii=False)

                recognition = {
                    "signature": signature,
                    "answer": answer,
                    "details": details,
                    "confidence": overall_confidence,
                    "drawing_png_b64": drawing_png_b64,
                    "pred_topk_json": pred_topk_json,
                }

                st.session_state[recognition_key] = recognition
                st.session_state[answer_key] = answer
                previous_recognition = recognition

                if standard_autosave:
                    _save_standard_answer(
                        instance_id,
                        question_id,
                        answer,
                        drawing_png_b64=drawing_png_b64,
                        pred_confidence=overall_confidence,
                        pred_topk_json=pred_topk_json,
                        count_attempt=True,
                    )

            except FileNotFoundError:
                st.error(
                    tr(
                        "CNN model file was not found. Put best_symbol_cnn2.pt in services/models/.",
                        "ملف نموذج CNN غير موجود. ضع best_symbol_cnn2.pt داخل services/models/.",
                    )
                )
            except Exception as exc:
                st.error(
                    tr(
                        f"Handwriting recognition failed: {exc}",
                        f"فشل التعرّف على الكتابة: {exc}",
                    )
                )

    if previous_recognition:
        answer = str(previous_recognition.get("answer") or "")
        details = previous_recognition.get("details") or []

        st.success(
            tr(
                f"Recognized answer: {answer}",
                f"الإجابة التي تم التعرّف عليها: {answer}",
            )
        )

        labels = []
        for item in details:
            labels.append(
                tr(
                    f"Box {item['box']}: {item['digit']} ({item['confidence']:.0%})",
                    f"الخانة {item['box']}: {item['digit']} ({item['confidence']:.0%})",
                )
            )

        if labels:
            st.caption(" · ".join(labels))

        if any(float(item.get("confidence") or 0.0) < 0.55 for item in details):
            st.warning(
                tr(
                    "One or more digits have low recognition confidence. Redraw them if the recognized answer is wrong.",
                    "الثقة منخفضة في قراءة رقم واحد أو أكثر. أعد رسم الخانة إذا كانت الإجابة المقروءة غير صحيحة.",
                )
            )

        return answer

    st.caption(
        tr(
            "The answer is not saved until handwriting is recognized.",
            "لن تُحفظ إجابة اللوح حتى يتم التعرّف على الكتابة.",
        )
    )
    return ""


def _render_student_answer_method_standard(
    *,
    q: dict,
    instance_id: int,
    qid: int,
    answer_key: str,
) -> None:
    """Student chooses keyboard OR handwriting for a standard arithmetic question."""
    method_key = f"answer_method_{instance_id}_{qid}"
    typed_key = f"typed_answer_{instance_id}_{qid}"

    if typed_key not in st.session_state:
        st.session_state[typed_key] = str(
            st.session_state.get(answer_key, "") or ""
        )

    options = ["keyboard", "handwriting"] if st_canvas is not None else ["keyboard"]

    if method_key not in st.session_state:
        st.session_state[method_key] = "keyboard"

    if st.session_state[method_key] not in options:
        st.session_state[method_key] = "keyboard"

    st.radio(
        tr("How do you want to answer?", "كيف تريد إدخال إجابتك؟"),
        options,
        key=method_key,
        horizontal=True,
        format_func=lambda value: (
            tr("⌨️ Type the number", "⌨️ كتابة الرقم")
            if value == "keyboard"
            else tr("✍️ Handwrite on the board", "✍️ الكتابة على اللوح التفاعلي")
        ),
        on_change=_switch_standard_answer_method,
        args=(instance_id, qid, method_key, typed_key, answer_key),
    )

    method = st.session_state.get(method_key, "keyboard")

    if method == "keyboard":
        st.session_state[answer_key] = str(
            st.session_state.get(typed_key, "") or ""
        ).strip()

        st.text_input(
            tr("Your answer", "إجابتك"),
            key=typed_key,
            placeholder=tr("Type your answer", "اكتب إجابتك"),
            on_change=_sync_keyboard_standard,
            args=(instance_id, qid, typed_key, answer_key),
        )
    else:
        _render_handwriting_board(
            q=q,
            instance_id=instance_id,
            question_id=qid,
            answer_key=answer_key,
            prefix="standard",
            standard_autosave=True,
        )


def _render_student_answer_method_adaptive(
    *,
    q: dict,
    instance_id: int,
    qid: int,
    answer_key: str,
) -> None:
    """Student chooses keyboard OR handwriting for an adaptive arithmetic question."""
    method_key = f"adaptive_answer_method_{instance_id}_{qid}"
    typed_key = f"adaptive_typed_answer_{instance_id}_{qid}"

    if typed_key not in st.session_state:
        st.session_state[typed_key] = str(
            st.session_state.get(answer_key, "") or ""
        )

    options = ["keyboard", "handwriting"] if st_canvas is not None else ["keyboard"]

    if method_key not in st.session_state:
        st.session_state[method_key] = "keyboard"

    if st.session_state[method_key] not in options:
        st.session_state[method_key] = "keyboard"

    st.radio(
        tr("How do you want to answer?", "كيف تريد إدخال إجابتك؟"),
        options,
        key=method_key,
        horizontal=True,
        format_func=lambda value: (
            tr("⌨️ Type the number", "⌨️ كتابة الرقم")
            if value == "keyboard"
            else tr("✍️ Handwrite on the board", "✍️ الكتابة على اللوح التفاعلي")
        ),
        on_change=_switch_adaptive_answer_method,
        args=(method_key, typed_key, answer_key),
    )

    method = st.session_state.get(method_key, "keyboard")

    if method == "keyboard":
        st.session_state[answer_key] = str(
            st.session_state.get(typed_key, "") or ""
        ).strip()

        st.text_input(
            tr("Your answer", "إجابتك"),
            key=typed_key,
            placeholder=tr("Type your answer", "اكتب إجابتك"),
            on_change=_sync_keyboard_adaptive,
            args=(typed_key, answer_key),
        )
    else:
        _render_handwriting_board(
            q=q,
            instance_id=instance_id,
            question_id=qid,
            answer_key=answer_key,
            prefix="adaptive",
            standard_autosave=False,
        )

# ============================================================
# STANDARD EXAM
# ============================================================

def _render_standard_exam(inst: dict) -> None:
    instance_id = int(inst["id"])
    questions = student_instance_questions(instance_id, student_id)

    if not questions:
        empty_state(
            tr("No questions available", "لا توجد أسئلة متاحة"),
            tr(
                "Ask your teacher to review this assessment.",
                "اطلب من معلمك مراجعة هذا الاختبار.",
            ),
        )
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
        st.session_state[hint_key] = int(
            (autosaved.get(qid) or {}).get("hint_count") or 0
        )

    if answer_key not in st.session_state:
        st.session_state[answer_key] = str(
            (autosaved.get(qid) or {}).get("answer_text") or ""
        )

    top1, top2 = st.columns([0.72, 0.28])

    with top1:
        st.progress(
            (idx + 1) / len(questions),
            text=tr(
                f"Question {idx + 1} of {len(questions)}",
                f"السؤال {idx + 1} من {len(questions)}",
            ),
        )

    with top2:
        timer_fragment(instance_id)

    difficulty_text = display_difficulty(q.get("difficulty"))
    question_number = tr(
        f"Question {idx + 1} · {difficulty_text}",
        f"السؤال {idx + 1} · {difficulty_text}",
    )

    st.markdown(
        f"""
        <div class="question-shell">
          <div class="question-number">{escape(question_number)}</div>
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

    # MCQ keeps its normal choice UI.
    if choices or q.get("input_mode") == "mcq":
        options = [""] + choices if choices else [""]
        current = str(st.session_state.get(answer_key, ""))
        index = options.index(current) if current in options else 0

        st.radio(
            tr("Choose an answer", "اختر إجابة"),
            options,
            index=index,
            key=answer_key,
            format_func=lambda x: (
                tr("Select an option", "اختر خياراً") if x == "" else x
            ),
            on_change=_autosave_standard,
            args=(instance_id, qid, answer_key),
        )

    # Arithmetic questions: student chooses keyboard OR handwriting board.
    elif _handwriting_supported(q):
        _render_student_answer_method_standard(
            q=q,
            instance_id=instance_id,
            qid=qid,
            answer_key=answer_key,
        )

    # Non-arithmetic free-text questions stay keyboard-only.
    else:
        st.text_input(
            tr("Your answer", "إجابتك"),
            key=answer_key,
            placeholder=tr("Type your answer", "اكتب إجابتك"),
            on_change=_autosave_standard,
            args=(instance_id, qid, answer_key),
        )

    hc1, hc2 = st.columns([0.72, 0.28])

    with hc1:
        if q.get("hint_text"):
            if st.button(
                tr("Show hint", "إظهار التلميح"),
                key=f"hint_btn_{instance_id}_{qid}",
            ):
                st.session_state[hint_key] = int(
                    st.session_state.get(hint_key, 0)
                ) + 1

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
            st.caption(tr("✓ Answer saved", "✓ تم حفظ الإجابة"))
        else:
            st.caption(
                tr(
                    "Your answer saves when it changes",
                    "يتم حفظ إجابتك عند تغييرها",
                )
            )

    nav1, nav2, nav3 = st.columns([1, 1, 1.25])

    with nav1:
        if st.button(
            tr("← Previous", "السابق →"),
            disabled=idx == 0,
            use_container_width=True,
            key=f"prev_{instance_id}_{idx}",
        ):
            _save_standard_answer(
                instance_id,
                qid,
                str(st.session_state.get(answer_key, "") or ""),
                count_attempt=False,
            )
            st.session_state[idx_key] = idx - 1
            st.rerun()

    with nav2:
        if st.button(
            tr("Next →", "← التالي"),
            disabled=idx == len(questions) - 1,
            use_container_width=True,
            key=f"next_{instance_id}_{idx}",
        ):
            _save_standard_answer(
                instance_id,
                qid,
                str(st.session_state.get(answer_key, "") or ""),
                count_attempt=False,
            )
            st.session_state[idx_key] = idx + 1
            st.rerun()

    with nav3:
        confirm = st.checkbox(
            tr("I am ready to submit", "أنا جاهز لتسليم الاختبار"),
            key=f"confirm_submit_{instance_id}",
        )

        if st.button(
            tr("Submit assessment", "تسليم الاختبار"),
            type="primary",
            disabled=not confirm,
            use_container_width=True,
            key=f"submit_{instance_id}",
        ):
            _save_standard_answer(
                instance_id,
                qid,
                str(st.session_state.get(answer_key, "") or ""),
                count_attempt=False,
            )

            try:
                submit_instance(instance_id, student_id, auto=False)
                st.success(
                    tr(
                        "Assessment submitted successfully.",
                        "تم تسليم الاختبار بنجاح.",
                    )
                )
                st.session_state.pop("active_instance_id", None)
                st.rerun()
            except Exception as e:
                st.error(
                    tr(
                        f"Could not submit: {e}",
                        f"تعذر تسليم الاختبار: {e}",
                    )
                )


# ============================================================
# ADAPTIVE EXAM
# ============================================================

def _render_adaptive_exam(inst: dict) -> None:
    instance_id = int(inst["id"])
    timer_fragment(instance_id)

    q_state_key = f"adaptive_question_{instance_id}"

    if q_state_key not in st.session_state:
        q, topic_name, mastery_value, served, max_questions = get_next_adaptive_question(
            instance_id,
            student_id,
        )
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
        st.success(
            tr(
                "Adaptive practice is complete.",
                "اكتمل التدريب التكيفي.",
            )
        )

        if st.button(
            tr("Finish session", "إنهاء الجلسة"),
            type="primary",
            key=f"finish_adaptive_{instance_id}",
        ):
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
        st.progress(
            min(1.0, served / max_questions),
            text=tr(
                f"Adaptive question {served} of up to {max_questions}",
                f"السؤال التكيفي {served} من أصل {max_questions} كحد أقصى",
            ),
        )

    focus_topic = display_topic(state.get("topic") or "Current topic")
    mastery_before = percent(state.get("mastery") or 0.0)

    st.caption(
        tr(
            f"Focus topic: {focus_topic} · Estimated mastery before this question: {mastery_before}",
            f"الموضوع المستهدف: {focus_topic} · الإتقان المقدر قبل هذا السؤال: {mastery_before}",
        )
    )

    adaptive_label = tr("Adaptive practice", "تدريب تكيفي")
    q_difficulty = display_difficulty(q.get("difficulty"))

    st.markdown(
        f"""
        <div class="question-shell">
          <div class="question-number">{escape(adaptive_label)} · {escape(q_difficulty)}</div>
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
        st.radio(
            tr("Choose an answer", "اختر إجابة"),
            [""] + choices,
            key=ans_key,
            format_func=lambda x: (
                tr("Select an option", "اختر خياراً") if x == "" else x
            ),
        )

    elif _handwriting_supported(q):
        _render_student_answer_method_adaptive(
            q=q,
            instance_id=instance_id,
            qid=qid,
            answer_key=ans_key,
        )

    else:
        st.text_input(
            tr("Your answer", "إجابتك"),
            key=ans_key,
            placeholder=tr("Type your answer", "اكتب إجابتك"),
        )

    if q.get("hint_text"):
        with st.expander(tr("Need a hint?", "تحتاج إلى تلميح؟")):
            st.write(q["hint_text"])

    if st.button(
        tr("Check answer & continue", "تحقق من الإجابة وتابع"),
        type="primary",
        use_container_width=True,
        key=f"adaptive_submit_{instance_id}_{qid}",
    ):
        answer = str(st.session_state.get(ans_key, "") or "").strip()

        if not answer:
            st.warning(
                tr(
                    "Enter or recognize an answer before continuing.",
                    "أدخل الإجابة أو شغّل التعرّف على الكتابة قبل المتابعة.",
                )
            )
            return

        try:
            # If handwriting was selected, include its evidence in the adaptive answer row.
            recognition_key = f"adaptive_recognition_{instance_id}_{qid}"
            recognition = st.session_state.get(recognition_key) or {}
            method = st.session_state.get(
                f"adaptive_answer_method_{instance_id}_{qid}",
                "keyboard",
            )

            extra = {}
            if method == "handwriting" and recognition:
                extra = {
                    "drawing_png_b64": recognition.get("drawing_png_b64"),
                    "pred_confidence": recognition.get("confidence"),
                    "pred_topk_json": recognition.get("pred_topk_json"),
                }

            feedback = record_adaptive_answer(
                instance_id=instance_id,
                student_id=student_id,
                question_id=qid,
                answer_text=answer,
                attempts=1,
                hint_count=0,
                **extra,
            )

            if int(feedback.get("is_correct") or 0):
                st.success(tr("Correct. Nice work.", "إجابة صحيحة، أحسنت."))
            else:
                correct_answer = feedback.get("correct_answer")
                st.warning(
                    tr(
                        f"Not quite. Correct answer: {correct_answer}",
                        f"ليست صحيحة. الإجابة الصحيحة: {correct_answer}",
                    )
                )

            q2, topic2, mastery2, served2, max2 = get_next_adaptive_question(
                instance_id,
                student_id,
            )

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
            st.error(
                tr(
                    f"Adaptive practice could not continue: {e}",
                    f"تعذر متابعة التدريب التكيفي: {e}",
                )
            )


# ============================================================
# MY LEARNING TAB
# ============================================================

with learn_tab:

    section_heading(
        tr(
            "My learning",
            "تعلمي",
        ),
        tr(
            "Continue assigned work or begin a new assessment when you are ready.",
            "تابع المهام المعينة أو ابدأ اختباراً جديداً عندما تكون جاهزاً.",
        ),
    )

    active = [
        x
        for x in instances
        if x.get(
            "instance_status"
        )
        in (
            "assigned",
            "in_progress",
        )
    ]

    active_instance_id = (
        st.session_state.get(
            "active_instance_id"
        )
    )

    if active_instance_id:

        inst = get_instance(
            int(
                active_instance_id
            ),
            student_id,
        )

        if not inst:

            st.session_state.pop(
                "active_instance_id",
                None,
            )

            st.rerun()

        else:

            back_col, title_col = (
                st.columns(
                    [0.18, 0.82]
                )
            )

            with back_col:

                if st.button(
                    tr(
                        "← Learning list",
                        "قائمة التعلم →",
                    ),
                    use_container_width=True,
                ):

                    st.session_state.pop(
                        "active_instance_id",
                        None,
                    )

                    st.rerun()

            with title_col:

                st.subheader(
                    inst.get(
                        "title"
                    )
                    or tr(
                        "Assessment",
                        "اختبار",
                    )
                )

                _status_badge(
                    inst.get(
                        "status"
                    )
                )

            if (
                inst.get(
                    "status"
                )
                == "assigned"
            ):

                ok, reason = (
                    can_start_instance(
                        inst
                    )
                )

                st.write(
                    tr(
                        "This assessment will begin its timer only after you press **Start**.",
                        "لن يبدأ مؤقت الاختبار إلا بعد الضغط على **بدء الاختبار**.",
                    )
                )

                if st.button(
                    tr(
                        "Start assessment",
                        "بدء الاختبار",
                    ),
                    type="primary",
                    disabled=not ok,
                    use_container_width=True,
                    key=(
                        f"start_"
                        f"{active_instance_id}"
                    ),
                ):

                    try:

                        start_instance(
                            int(
                                active_instance_id
                            ),
                            student_id,
                        )

                        st.rerun()

                    except Exception as e:

                        st.error(
                            str(e)
                        )

                if not ok:

                    st.info(
                        reason
                    )

            elif (
                inst.get(
                    "status"
                )
                == "in_progress"
            ):

                if (
                    str(
                        inst.get(
                            "difficulty"
                        )
                        or ""
                    ).lower()
                    == "adaptive"
                ):

                    _render_adaptive_exam(
                        inst
                    )

                else:

                    _render_standard_exam(
                        inst
                    )

            elif (
                inst.get(
                    "status"
                )
                == "graded"
            ):

                st.success(
                    tr(
                        "This assessment is complete. Open Reports to review your feedback.",
                        "هذا الاختبار مكتمل. افتح التقارير لمراجعة التغذية الراجعة.",
                    )
                )

            else:

                st.info(
                    tr(
                        f"Assessment status: {display_status(inst.get('status'))}",
                        f"حالة الاختبار: {display_status(inst.get('status'))}",
                    )
                )

    else:

        if not active:

            empty_state(
                tr(
                    "You are all caught up",
                    "لقد أنجزت جميع مهامك",
                ),
                tr(
                    "There are no assigned or in-progress assessments right now.",
                    "لا توجد اختبارات معينة أو قيد التنفيذ حالياً.",
                ),
            )

        else:

            for item in active:

                with st.container(
                    border=True
                ):

                    c1, c2, c3 = (
                        st.columns(
                            [
                                0.62,
                                0.18,
                                0.20,
                            ]
                        )
                    )

                    with c1:

                        st.subheader(
                            item.get(
                                "title"
                            )
                            or tr(
                                "Assessment",
                                "اختبار",
                            )
                        )

                        diff_text = (
                            display_difficulty(
                                item.get(
                                    "difficulty"
                                )
                                or "Adaptive"
                            )
                        )

                        question_count = (
                            item.get(
                                "num_questions"
                            )
                            or "—"
                        )

                        duration_min = (
                            int(
                                item.get(
                                    "duration_seconds"
                                )
                                or 0
                            )
                            // 60
                        )

                        st.caption(
                            tr(
                                f"{diff_text} · {question_count} questions · {duration_min} min",
                                f"{diff_text} · {question_count} أسئلة · {duration_min} دقيقة",
                            )
                        )

                        _status_badge(
                            item.get(
                                "instance_status"
                            )
                        )

                    with c2:

                        if item.get(
                            "start_at"
                        ):

                            st.caption(
                                tr(
                                    "Available",
                                    "متاح من",
                                )
                            )

                            st.write(
                                utc_z_to_jordan_str(
                                    item.get(
                                        "start_at"
                                    )
                                )
                            )

                    with c3:

                        label = (
                            tr(
                                "Continue",
                                "متابعة",
                            )
                            if item.get(
                                "instance_status"
                            )
                            == "in_progress"
                            else tr(
                                "Open",
                                "فتح",
                            )
                        )

                        if st.button(
                            label,
                            type="primary",
                            key=(
                                f"open_instance_"
                                f"{item['instance_id']}"
                            ),
                            use_container_width=True,
                        ):

                            st.session_state[
                                "active_instance_id"
                            ] = int(
                                item[
                                    "instance_id"
                                ]
                            )

                            st.rerun()


# ============================================================
# PROGRESS TAB
# ============================================================

with progress_tab:

    section_heading(
        tr(
            "My progress",
            "تقدمي",
        ),
        tr(
            "Mastery estimates summarize evidence from your completed learning sessions.",
            "تلخص تقديرات الإتقان الأدلة الناتجة عن جلسات التعلم المكتملة.",
        ),
    )

    if mastery:

        for m in mastery:

            p = float(
                m.get(
                    "p_knowledge"
                )
                or 0.0
            )

            c1, c2 = (
                st.columns(
                    [0.78, 0.22]
                )
            )

            with c1:

                topic_name = (
                    display_topic(
                        m.get(
                            "topic_name"
                        )
                    )
                )

                mastery_text = (
                    translated_mastery_label(
                        p
                    )
                )

                st.write(
                    f"**{topic_name}** · "
                    f"{mastery_text}"
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

                observations = int(
                    m.get(
                        "n_obs"
                    )
                    or 0
                )

                st.caption(
                    tr(
                        f"Based on {observations} observations",
                        f"بناءً على {observations} ملاحظات",
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
                "No mastery estimate yet",
                "لا يوجد تقدير للإتقان حتى الآن",
            ),
            tr(
                "Complete graded work to begin building your topic mastery profile.",
                "أكمل أعمالاً تم تقييمها لبدء بناء ملف إتقانك للمهارات.",
            ),
        )

    trust_note = tr(
        """
        <div class="trust-note">
            <strong>What this means:</strong>
            mastery is an estimate from your learning evidence.
            It is not a diagnosis, intelligence score, or permanent label.
        </div>
        """,
        """
        <div class="trust-note">
            <strong>ماذا يعني ذلك؟</strong>
            الإتقان هو تقدير يعتمد على أدلة تعلمك.
            وهو ليس تشخيصاً أو مقياساً للذكاء أو تصنيفاً دائماً لك.
        </div>
        """,
    )

    st.markdown(
        trust_note,
        unsafe_allow_html=True,
    )


# ============================================================
# REPORTS TAB
# ============================================================

with reports_tab:

    section_heading(
        tr(
            "Reports",
            "التقارير",
        ),
        tr(
            "Review completed assessments and see what to practice next.",
            "راجع الاختبارات المكتملة واعرف ما الذي تحتاج إلى التدرب عليه تالياً.",
        ),
    )

    if not results:

        empty_state(
            tr(
                "No reports yet",
                "لا توجد تقارير حتى الآن",
            ),
            tr(
                "Completed and graded assessments will appear here.",
                "ستظهر هنا الاختبارات المكتملة التي تم تقييمها.",
            ),
        )

    else:

        report_map = {
            (
                f"{r.get('title') or tr('Assessment', 'اختبار')} "
                f"· {str(r.get('computed_at') or '')[:16]}"
            ): r
            for r in results
        }

        report_label = (
            st.selectbox(
                tr(
                    "Completed assessment",
                    "الاختبار المكتمل",
                ),
                list(
                    report_map.keys()
                ),
                key=(
                    "student_report_select"
                ),
            )
        )

        report = (
            report_map[
                report_label
            ]
        )

        r1, r2, r3 = (
            st.columns(
                3
            )
        )

        with r1:

            st.metric(
                tr(
                    "Accuracy",
                    "الدقة",
                ),
                percent(
                    report.get(
                        "accuracy"
                    )
                ),
            )

        with r2:

            st.metric(
                tr(
                    "Score",
                    "العلامة",
                ),
                f"{float(report.get('total_score') or 0.0):.1f}",
            )

        with r3:

            st.metric(
                tr(
                    "Difficulty",
                    "الصعوبة",
                ),
                display_difficulty(
                    report.get(
                        "difficulty"
                    )
                )
                if report.get(
                    "difficulty"
                )
                else "—",
            )

        st.subheader(
            tr(
                "Recommended next step",
                "الخطوة التالية المقترحة",
            )
        )

        st.info(
            _translate_recommendation(
                report.get(
                    "model_recommendation"
                )
            )
        )

        topics_json = (
            report.get(
                "topics_json"
            )
        )

        if topics_json:

            try:

                topic_rows = (
                    json.loads(
                        topics_json
                    )
                )

                if topic_rows:

                    tdf = (
                        pd.DataFrame(
                            topic_rows
                        )
                    )

                    if (
                        "topic_name"
                        in tdf.columns
                    ):
                        tdf[
                            "topic_name"
                        ] = tdf[
                            "topic_name"
                        ].apply(
                            display_topic
                        )

                    rename_map = {
                        "topic_name": tr(
                            "Topic",
                            "الموضوع",
                        ),
                        "mastery": tr(
                            "Mastery",
                            "الإتقان",
                        ),
                        "n_obs": tr(
                            "Observations",
                            "عدد الملاحظات",
                        ),
                        "x": tr(
                            "Observed accuracy",
                            "الدقة المرصودة",
                        ),
                    }

                    keep = [
                        c
                        for c
                        in [
                            "topic_name",
                            "mastery",
                            "n_obs",
                            "x",
                        ]
                        if c
                        in tdf.columns
                    ]

                    display_df = (
                        tdf[
                            keep
                        ].rename(
                            columns=rename_map
                        )
                    )

                    st.dataframe(
                        display_df,
                        use_container_width=True,
                        hide_index=True,
                    )

            except Exception:
                pass

        review = (
            instance_review(
                int(
                    report[
                        "instance_id"
                    ]
                ),
                student_id,
            )
        )

        if review:

            st.subheader(
                tr(
                    "Question feedback",
                    "ملاحظات الأسئلة",
                )
            )

            for row in review:

                correct = (
                    int(
                        row.get(
                            "is_correct"
                        )
                        or 0
                    )
                    == 1
                )

                status_word = (
                    tr(
                        "Correct",
                        "صحيح",
                    )
                    if correct
                    else tr(
                        "Review",
                        "مراجعة",
                    )
                )

                with st.expander(
                    tr(
                        f"Question {row.get('order_index')} · {status_word}",
                        f"السؤال {row.get('order_index')} · {status_word}",
                    )
                ):

                    st.write(
                        row.get(
                            "prompt"
                        )
                        or ""
                    )

                    st.write(
                        tr(
                            f"**Your answer:** {row.get('student_answer') or 'No answer'}",
                            f"**إجابتك:** {row.get('student_answer') or 'لا توجد إجابة'}",
                        )
                    )

                    st.write(
                        tr(
                            f"**Correct answer:** {row.get('correct_answer') or '—'}",
                            f"**الإجابة الصحيحة:** {row.get('correct_answer') or '—'}",
                        )
                    )

                    if row.get(
                        "feedback"
                    ):

                        st.caption(
                            row[
                                "feedback"
                            ]
                        )
