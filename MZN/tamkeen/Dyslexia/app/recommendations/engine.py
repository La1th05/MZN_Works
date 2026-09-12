def get_next_recommendation(
    skill_updates,
    metrics,
    errors
):
    """
    Generate an explainable educational recommendation.

    This is NOT a medical diagnosis.

    Priority:
    1. Word recognition problems
    2. Fluency problems
    3. General reading practice
    """

    # ==========================================
    # NO SKILL EVIDENCE
    # ==========================================

    if not skill_updates:

        return {
            "recommendation_code":
                "GENERAL_READING_PRACTICE",

            "target_skill":
                "READ.WORD_RECOGNITION",

            "activity_type":
                "guided_reading",

            "difficulty":
                "medium",

            "supports": [
                "tts",
                "word_highlighting"
            ],

            "reason":
                "No strong reading-skill weakness was detected "
                "from the current sample."
        }

    # ==========================================
    # FIND STRONGEST SKILL EVIDENCE
    # ==========================================

    strongest_skill = max(
        skill_updates,
        key=lambda item: item.get(
            "evidence",
            0
        )
    )

    skill_code = strongest_skill.get(
        "skill_code"
    )

    evidence = strongest_skill.get(
        "evidence",
        0
    )

    # ==========================================
    # WORD RECOGNITION
    # ==========================================

    if skill_code == "READ.WORD_RECOGNITION":

        substitutions = metrics.get(
            "substitutions",
            0
        )

        omissions = metrics.get(
            "omissions",
            0
        )

        accuracy = metrics.get(
            "accuracy"
        )

        # -------------------------------
        # Difficulty
        # -------------------------------

        if accuracy is None:

            difficulty = "easy"

        elif accuracy < 0.60:

            difficulty = "easy"

        elif accuracy < 0.80:

            difficulty = "medium"

        else:

            difficulty = "medium"

        # -------------------------------
        # Recommendation
        # -------------------------------

        return {
            "recommendation_code":
                "WORD_RECOGNITION_SUPPORT",

            "target_skill":
                "READ.WORD_RECOGNITION",

            "activity_type":
                "word_recognition_practice",

            "difficulty":
                difficulty,

            "supports": [
                "tts",
                "word_highlighting",
                "word_repetition"
            ],

            "reason":
                (
                    f"Word-recognition support is recommended. "
                    f"Detected {substitutions} substitution(s) "
                    f"and {omissions} omission(s). "
                    f"Evidence score: {evidence:.2f}."
                )
        }

    # ==========================================
    # FLUENCY
    # ==========================================

    if skill_code == "READ.FLUENCY":

        wpm = metrics.get(
            "wpm"
        )

        accuracy = metrics.get(
            "accuracy"
        )

        repetitions = metrics.get(
            "repetitions",
            0
        )

        # -------------------------------
        # Difficulty
        # -------------------------------

        if wpm is None:

            difficulty = "easy"

        elif wpm < 30:

            difficulty = "easy"

        elif wpm < 50:

            difficulty = "medium"

        else:

            difficulty = "medium"

        # -------------------------------
        # Recommendation
        # -------------------------------

        return {
            "recommendation_code":
                "LOW_FLUENCY",

            "target_skill":
                "READ.FLUENCY",

            "activity_type":
                "repeated_reading",

            "difficulty":
                difficulty,

            "supports": [
                "tts",
                "word_highlighting",
                "paced_reading"
            ],

            "reason":
                (
                    f"Reading accuracy is "
                    f"{accuracy:.2f} "
                    if accuracy is not None
                    else ""
                )
                +
                (
                    f"with a reading speed of "
                    f"{wpm:.1f} WPM. "
                    if wpm is not None
                    else ""
                )
                +
                (
                    f"{repetitions} repetition(s) "
                    f"were detected. "
                    if repetitions > 0
                    else ""
                )
                +
                (
                    "Repeated reading of a short familiar "
                    "passage is recommended."
                )
        }

    # ==========================================
    # FALLBACK
    # ==========================================

    return {
        "recommendation_code":
            "GENERAL_READING_PRACTICE",

        "target_skill":
            skill_code,

        "activity_type":
            "guided_reading",

        "difficulty":
            "medium",

        "supports": [
            "tts",
            "word_highlighting"
        ],

        "reason":
            (
                "Continue guided reading practice based "
                "on the strongest detected skill evidence."
            )
    }