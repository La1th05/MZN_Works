from alignment import align_words


def word_metrics(
    expected_text,
    recognized_text,
    time_taken,
    alignment=None
):

    expected_words = expected_text.strip().split()
    recognized_words = recognized_text.strip().split()

    words_expected = len(expected_words)
    words_spoken = len(recognized_words)


    if alignment is None:
        alignment, _ = align_words(
            expected_text,
            recognized_text
        )

    # Count results
    words_correct = sum(
        1
        for word in alignment
        if word["type"] == "correct"
    )

    omissions = sum(
        1
        for word in alignment
        if word["type"] == "omission"
    )

    substitutions = sum(
        1
        for word in alignment
        if word["type"] == "substitution"
    )

    insertions = sum(
        1
        for word in alignment
        if word["type"] == "insertion"
    )

    repetitions = sum(
        1
        for word in alignment
        if word["type"] == "repetition"
    )


    if words_expected > 0:

        accuracy = (
            words_correct
            / words_expected
        )

    else:

        accuracy = None


    if time_taken is None:

        duration_seconds = None

    else:

        try:
            duration_seconds = float(time_taken)

        except (TypeError, ValueError):
            duration_seconds = None

    if (
        duration_seconds is not None
        and duration_seconds > 0
    ):

        duration_minutes = (
            duration_seconds / 60
        )

        wpm = (
            words_spoken
            / duration_minutes
        )

    else:

        wpm = None


    metrics = {

        "accuracy": accuracy,

        "wpm": wpm,

        "duration": duration_seconds,

        "words_expected": words_expected,

        "words_spoken": words_spoken,

        "words_correct": words_correct,

        "omissions": omissions,

        "substitutions": substitutions,

        "insertions": insertions,

        "repetitions": repetitions,

        "hesitations": None
    }

    return metrics