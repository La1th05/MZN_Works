from alignment import align_words
from metrics import word_metrics
from normalization import normalize_text
from speech.stt import transcribe_audio
from skills.evidence import infer_skill_evidence
from recommendations.engine import get_next_recommendation
from adaptive.engine import get_adaptive_plan
def analyze_reading(
    expected_text,
    audio_path,
    language="en",
    time_taken=None,
    review_threshold=0.55,
    previous_mastery=None
):


    stt_result = transcribe_audio(
        audio_path=audio_path,
        language=language
    )

    raw_transcript = (
        stt_result["text"]
    )

    normalized_expected = normalize_text(
        expected_text,
        language
    )

    normalized_recognized = normalize_text(
        raw_transcript,
        language
    )



    alignment, correct_count = align_words(
        normalized_expected,
        normalized_recognized
    )



    if time_taken is not None:

        duration_seconds = time_taken

    else:

        duration_seconds = (
            stt_result.get(
                "duration_seconds"
            )
        )


    metrics = word_metrics(

        expected_text=
            normalized_expected,

        recognized_text=
            normalized_recognized,

        time_taken=
            duration_seconds,

        alignment=
            alignment
    )
    
    



    errors = []

    analysis_confidence = (
        stt_result.get(
            "rough_transcription_confidence"
        )
    )

    for item in alignment:

        # Correct words are not errors
        if item["type"] == "correct":
            continue

        errors.append({

            "type":
                item["type"],

            "expected":
                item["expected"],

            "spoken":
                item["spoken"],

            "position":
                item["position"],

            "confidence":
                analysis_confidence
        })

    skill_updates = infer_skill_evidence(
    metrics=metrics,
    errors=errors,
    target_wpm=60.0
)
    recommendation = get_next_recommendation(
        skill_updates=skill_updates,
        metrics=metrics,
        errors=errors
    )
    adaptive_plan = get_adaptive_plan(
    skill_updates=skill_updates,
    recommendation=recommendation,
    previous_mastery=previous_mastery
)

    transcript_available = bool(
        normalized_recognized
    )

    if not transcript_available:

        teacher_review_recommended = True

    elif analysis_confidence is None:

        teacher_review_recommended = True

    elif analysis_confidence < review_threshold:

        teacher_review_recommended = True

    else:

        teacher_review_recommended = False

    if transcript_available:

        audio_quality = "acceptable"

    else:

        audio_quality = "unusable"


    result = {

        "transcript":
            raw_transcript,

        "normalized_transcript":
            normalized_recognized,

        "normalized_expected_text":
            normalized_expected,

        "alignment":
            alignment,

        "metrics":
            metrics,

        "errors":
            errors,

        # We implement these next.
        "skill_updates":skill_updates,

        "recommendation": recommendation,
        "adaptive_plan":adaptive_plan,

        "quality": {

            "audio_quality":
                audio_quality,

            "analysis_confidence":
                analysis_confidence,

            "teacher_review_recommended":
                teacher_review_recommended
        },

        "stt": {

            "language":
                stt_result.get(
                    "language"
                ),

            "language_probability":
                stt_result.get(
                    "language_probability"
                ),

            "mean_avg_logprob":
                stt_result.get(
                    "mean_avg_logprob"
                ),

            "segments":
                stt_result.get(
                    "segments",
                    []
                )
        }
    }

    return result