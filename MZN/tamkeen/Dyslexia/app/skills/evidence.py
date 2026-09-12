def clamp(value, minimum=0.0, maximum=1.0):
    """
    Keep a numeric value between minimum and maximum.
    """
    return max(minimum, min(maximum, value))


def infer_skill_evidence(
    metrics,
    errors,
    target_wpm=60.0,
    good_accuracy_threshold=0.90,
    word_recognition_threshold=0.85
):
    """
    Convert reading metrics/errors into educational skill evidence.

    IMPORTANT:
    evidence is NOT:
        - probability of dyslexia
        - medical diagnosis probability

    evidence means:
        how strongly this reading sample suggests that
        this educational skill may need additional support.

    Returns:
        list of dictionaries
    """

    skill_updates = []

    # =========================================
    # READ BASIC METRICS
    # =========================================

    accuracy = metrics.get("accuracy")

    wpm = metrics.get("wpm")

    words_expected = metrics.get(
        "words_expected",
        0
    )

    substitutions = metrics.get(
        "substitutions",
        0
    )

    omissions = metrics.get(
        "omissions",
        0
    )

    repetitions = metrics.get(
        "repetitions",
        0
    )

    # =========================================
    # 1. WORD RECOGNITION
    # =========================================

    if words_expected > 0 and accuracy is not None:

        recognition_errors = (
            substitutions
            + omissions
        )

        recognition_error_rate = (
            recognition_errors
            / words_expected
        )

        # Evidence can come from:
        #
        # 1. Low reading accuracy
        # 2. High substitution/omission rate

        accuracy_signal = 1.0 - accuracy

        error_signal = recognition_error_rate

        word_recognition_evidence = max(
            accuracy_signal,
            error_signal
        )

        word_recognition_evidence = clamp(
            word_recognition_evidence
        )

        # Only create evidence if there is
        # something meaningful to report.
        if (
            accuracy < word_recognition_threshold
            or recognition_error_rate >= 0.15
        ):

            reasons = []

            if accuracy < word_recognition_threshold:
                reasons.append(
                    f"Reading accuracy is {accuracy:.2f}"
                )

            if substitutions > 0:
                reasons.append(
                    f"{substitutions} substitution(s)"
                )

            if omissions > 0:
                reasons.append(
                    f"{omissions} omission(s)"
                )

            skill_updates.append({
                "skill_code":
                    "READ.WORD_RECOGNITION",

                "evidence":
                    round(
                        word_recognition_evidence,
                        3
                    ),

                "status":
                    "needs_support",

                "reason":
                    "; ".join(reasons)
            })

    # =========================================
    # 2. FLUENCY
    # =========================================

    # Fluency should not be inferred only
    # because accuracy is poor.
    #
    # We use this rule when:
    #
    # accuracy is reasonably good
    # BUT reading speed is below target.

    if (
        accuracy is not None
        and wpm is not None
        and target_wpm is not None
        and target_wpm > 0
    ):

        if (
            accuracy >= good_accuracy_threshold
            and wpm < target_wpm
        ):

            speed_ratio = (
                wpm / target_wpm
            )

            fluency_evidence = (
                1.0 - speed_ratio
            )

            fluency_evidence = clamp(
                fluency_evidence
            )

            reasons = [
                f"Accuracy is good ({accuracy:.2f})",
                f"WPM is {wpm:.1f}",
                f"Target WPM is {target_wpm:.1f}"
            ]

            if repetitions > 0:
                reasons.append(
                    f"{repetitions} repetition(s)"
                )

                # Slightly strengthen the signal
                fluency_evidence += min(
                    0.20,
                    repetitions * 0.05
                )

                fluency_evidence = clamp(
                    fluency_evidence
                )

            skill_updates.append({
                "skill_code":
                    "READ.FLUENCY",

                "evidence":
                    round(
                        fluency_evidence,
                        3
                    ),

                "status":
                    "needs_support",

                "reason":
                    "; ".join(reasons)
            })

    return skill_updates