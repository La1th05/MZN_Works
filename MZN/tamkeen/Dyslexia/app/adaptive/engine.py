def clamp(value, minimum=0.0, maximum=1.0):
    return max(
        minimum,
        min(maximum, value)
    )


def estimate_mastery_from_evidence(
    skill_updates
):
    """
    Estimate current mastery from this reading sample.

    IMPORTANT:
    This is only an MVP approximation.

    evidence = stronger indication that support is needed
    mastery  = estimated current skill strength

    Example:
        evidence = 0.30
        mastery  = 0.70
    """

    mastery = {}

    for skill in skill_updates:

        skill_code = skill.get(
            "skill_code"
        )

        evidence = skill.get(
            "evidence",
            0.0
        )

        evidence = clamp(
            float(evidence)
        )

        mastery_score = (
            1.0 - evidence
        )

        mastery[skill_code] = round(
            mastery_score,
            3
        )

    return mastery


def choose_difficulty(
    mastery_score
):
    """
    MVP difficulty rules.

    mastery < 0.40:
        easy

    mastery < 0.70:
        medium

    otherwise:
        advanced
    """

    if mastery_score is None:
        return "easy"

    if mastery_score < 0.40:
        return "easy"

    elif mastery_score < 0.70:
        return "medium"

    else:
        return "advanced"


def get_adaptive_plan(
    skill_updates,
    recommendation,
    previous_mastery=None
):
    """
    Build an adaptive activity plan.

    Inputs:
        skill_updates:
            output from Skill Evidence engine

        recommendation:
            output from Recommendation Engine

        previous_mastery:
            optional dictionary such as:

            {
                "READ.FLUENCY": 0.55,
                "READ.WORD_RECOGNITION": 0.70
            }

    Returns:
        {
            target_skill,
            mastery,
            difficulty,
            activity_type,
            supports,
            reason
        }
    """

    if previous_mastery is None:
        previous_mastery = {}

    # ==========================================
    # NO RECOMMENDATION
    # ==========================================

    if recommendation is None:

        return {
            "target_skill":
                None,

            "mastery":
                None,

            "difficulty":
                "easy",

            "activity_type":
                "guided_reading",

            "supports": [
                "tts",
                "word_highlighting"
            ],

            "reason":
                "No recommendation was available."
        }

    # ==========================================
    # TARGET SKILL
    # ==========================================

    target_skill = recommendation.get(
        "target_skill"
    )

    activity_type = recommendation.get(
        "activity_type",
        "guided_reading"
    )

    supports = recommendation.get(
        "supports",
        []
    )

    # ==========================================
    # CURRENT SAMPLE MASTERY
    # ==========================================

    estimated_mastery = (
        estimate_mastery_from_evidence(
            skill_updates
        )
    )

    current_sample_mastery = (
        estimated_mastery.get(
            target_skill
        )
    )

    # ==========================================
    # PREVIOUS MASTERY
    # ==========================================

    old_mastery = previous_mastery.get(
        target_skill
    )

    # ==========================================
    # COMBINE HISTORY + CURRENT SAMPLE
    # ==========================================

    if (
        old_mastery is not None
        and current_sample_mastery is not None
    ):

        old_mastery = clamp(
            float(old_mastery)
        )

        # Give history more weight so
        # one bad reading does not completely
        # change the student's level.
        combined_mastery = (
            0.70 * old_mastery
            +
            0.30 * current_sample_mastery
        )

    elif current_sample_mastery is not None:

        combined_mastery = (
            current_sample_mastery
        )

    elif old_mastery is not None:

        combined_mastery = clamp(
            float(old_mastery)
        )

    else:

        # Neutral default when there is
        # not enough evidence.
        combined_mastery = 0.50

    combined_mastery = clamp(
        combined_mastery
    )

    # ==========================================
    # DIFFICULTY
    # ==========================================

    difficulty = choose_difficulty(
        combined_mastery
    )

    # ==========================================
    # REASON
    # ==========================================

    reason = (
        f"Estimated mastery for "
        f"{target_skill} is "
        f"{combined_mastery:.2f}, "
        f"so the next activity difficulty "
        f"is {difficulty}."
    )

    # ==========================================
    # FINAL RESULT
    # ==========================================

    return {
        "target_skill":
            target_skill,

        "mastery":
            round(
                combined_mastery,
                3
            ),

        "difficulty":
            difficulty,

        "activity_type":
            activity_type,

        "supports":
            supports,

        "reason":
            reason
    }