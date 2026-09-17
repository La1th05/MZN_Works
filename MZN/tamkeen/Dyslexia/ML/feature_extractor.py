import math


def safe_divide(
    numerator,
    denominator,
    default=0.0
):
    """
    Safe division helper.

    Prevents division-by-zero errors.
    """

    if denominator in [None, 0]:
        return default

    return numerator / denominator


def safe_mean(
    values,
    default=0.0
):
    """
    Calculate mean safely.
    """

    clean_values = [
        value
        for value in values
        if value is not None
    ]

    if not clean_values:
        return default

    return (
        sum(clean_values)
        / len(clean_values)
    )


def extract_word_timing_features(
    segments,
    long_pause_threshold=1.0
):
    """
    Extract timing-related features
    from Faster-Whisper word timestamps.

    Returns:
        average_word_duration
        average_pause_duration
        max_pause_duration
        long_pause_count
        mean_word_confidence
        low_confidence_word_rate
    """

    all_words = []


    for segment in segments or []:

        words = segment.get(
            "words",
            []
        )

        for word in words:

            start = word.get(
                "start"
            )

            end = word.get(
                "end"
            )

            probability = word.get(
                "probability"
            )

            all_words.append({
                "start": start,
                "end": end,
                "probability": probability
            })

    word_durations = []

    confidences = []

    for word in all_words:

        start = word["start"]
        end = word["end"]

        if (
            start is not None
            and end is not None
            and end >= start
        ):

            word_durations.append(
                end - start
            )

        if word["probability"] is not None:

            confidences.append(
                float(
                    word["probability"]
                )
            )

    # ======================================
    # PAUSES
    # ======================================

    pauses = []

    for index in range(
        1,
        len(all_words)
    ):

        previous_word = (
            all_words[index - 1]
        )

        current_word = (
            all_words[index]
        )

        previous_end = (
            previous_word["end"]
        )

        current_start = (
            current_word["start"]
        )

        if (
            previous_end is not None
            and current_start is not None
        ):

            pause = (
                current_start
                - previous_end
            )

            # Negative pause can happen
            # because of timestamp overlap.
            if pause >= 0:

                pauses.append(
                    pause
                )

    long_pause_count = sum(
        1
        for pause in pauses
        if pause >= long_pause_threshold
    )

 

    low_confidence_count = sum(
        1
        for confidence in confidences
        if confidence < 0.60
    )

    low_confidence_word_rate = (
        safe_divide(
            low_confidence_count,
            len(confidences)
        )
    )


    return {
        "average_word_duration":
            safe_mean(
                word_durations
            ),

        "average_pause_duration":
            safe_mean(
                pauses
            ),

        "max_pause_duration":
            max(pauses)
            if pauses
            else 0.0,

        "long_pause_count":
            long_pause_count,

        "mean_word_confidence":
            safe_mean(
                confidences
            ),

        "low_confidence_word_rate":
            low_confidence_word_rate
    }


def extract_features(
    analysis_result
):
    """
    Convert one analyze_reading() result
    into a flat numeric ML feature dictionary.

    This function does NOT produce
    a dyslexia diagnosis.

    It only prepares educational
    reading-performance features
    for future ML models.
    """

  

    metrics = analysis_result.get(
        "metrics",
        {}
    )

    stt = analysis_result.get(
        "stt",
        {}
    )

    errors = analysis_result.get(
        "errors",
        []
    )

    accuracy = metrics.get(
        "accuracy"
    )

    wpm = metrics.get(
        "wpm"
    )

    duration = metrics.get(
        "duration"
    )

    words_expected = metrics.get(
        "words_expected",
        0
    )

    words_spoken = metrics.get(
        "words_spoken",
        0
    )

    words_correct = metrics.get(
        "words_correct",
        0
    )

    omissions = metrics.get(
        "omissions",
        0
    )

    substitutions = metrics.get(
        "substitutions",
        0
    )

    insertions = metrics.get(
        "insertions",
        0
    )

    repetitions = metrics.get(
        "repetitions",
        0
    )


    omission_rate = safe_divide(
        omissions,
        words_expected
    )

    substitution_rate = safe_divide(
        substitutions,
        words_expected
    )

    insertion_rate = safe_divide(
        insertions,
        words_expected
    )

    repetition_rate = safe_divide(
        repetitions,
        words_expected
    )

    total_reading_errors = (
        omissions
        + substitutions
        + insertions
        + repetitions
    )

    total_error_rate = safe_divide(
        total_reading_errors,
        words_expected
    )


    word_count_difference = (
        words_spoken
        - words_expected
    )

    spoken_expected_ratio = (
        safe_divide(
            words_spoken,
            words_expected
        )
    )


    language_probability = (
        stt.get(
            "language_probability"
        )
    )

    mean_avg_logprob = (
        stt.get(
            "mean_avg_logprob"
        )
    )


    timing_features = (
        extract_word_timing_features(
            stt.get(
                "segments",
                []
            )
        )
    )



    error_confidences = []

    for error in errors:

        confidence = error.get(
            "confidence"
        )

        if confidence is not None:

            error_confidences.append(
                float(confidence)
            )

    mean_error_confidence = (
        safe_mean(
            error_confidences
        )
    )

    # ======================================
    # CLEAN NULL VALUES
    # ======================================

    if accuracy is None:
        accuracy = 0.0

    if wpm is None:
        wpm = 0.0

    if duration is None:
        duration = 0.0

    if language_probability is None:
        language_probability = 0.0

    if mean_avg_logprob is None:
        mean_avg_logprob = 0.0

    # ======================================
    # FINAL ML FEATURES
    # ======================================

    features = {

        # General reading performance
        "accuracy":
            float(accuracy),

        "wpm":
            float(wpm),

        "duration":
            float(duration),

        # Word counts
        "words_expected":
            int(words_expected),

        "words_spoken":
            int(words_spoken),

        "words_correct":
            int(words_correct),

        # Raw errors
        "omissions":
            int(omissions),

        "substitutions":
            int(substitutions),

        "insertions":
            int(insertions),

        "repetitions":
            int(repetitions),

        # Normalized error features
        "omission_rate":
            float(omission_rate),

        "substitution_rate":
            float(substitution_rate),

        "insertion_rate":
            float(insertion_rate),

        "repetition_rate":
            float(repetition_rate),

        "total_error_rate":
            float(total_error_rate),

        # Reading length differences
        "word_count_difference":
            int(word_count_difference),

        "spoken_expected_ratio":
            float(spoken_expected_ratio),

        # Whisper signals
        "language_probability":
            float(language_probability),

        "mean_avg_logprob":
            float(mean_avg_logprob),

        "mean_error_confidence":
            float(mean_error_confidence),

        # Timing / hesitation-related signals
        "average_word_duration":
            float(
                timing_features[
                    "average_word_duration"
                ]
            ),

        "average_pause_duration":
            float(
                timing_features[
                    "average_pause_duration"
                ]
            ),

        "max_pause_duration":
            float(
                timing_features[
                    "max_pause_duration"
                ]
            ),

        "long_pause_count":
            int(
                timing_features[
                    "long_pause_count"
                ]
            ),

        "mean_word_confidence":
            float(
                timing_features[
                    "mean_word_confidence"
                ]
            ),

        "low_confidence_word_rate":
            float(
                timing_features[
                    "low_confidence_word_rate"
                ]
            )
    }

    return features