import math
from functools import lru_cache

import ctranslate2
from faster_whisper import WhisperModel


def normalize_stt_language(language):

    if language is None:
        return None

    language = str(language).strip().lower()

    language_map = {
        "english": "en",
        "eng": "en",
        "en": "en",

        "arabic": "ar",
        "ara": "ar",
        "ar": "ar",

        "العربية": "ar",
        "عربي": "ar"
    }

    return language_map.get(
        language,
        language
    )


@lru_cache(maxsize=2)
def load_model(model_size="small"):

    cuda_available = (
        ctranslate2.get_cuda_device_count() > 0
    )

    if cuda_available:

        print("Loading Whisper on GPU...")

        return WhisperModel(
            model_size,
            device="cuda",
            compute_type="float16"
        )

    print("Loading Whisper on CPU...")

    return WhisperModel(
        model_size,
        device="cpu",
        compute_type="int8"
    )


def logprob_to_rough_confidence(
    avg_logprob
):

    if avg_logprob is None:
        return None

    confidence = math.exp(
        float(avg_logprob)
    )

    return max(
        0.0,
        min(1.0, confidence)
    )


def transcribe_audio(
    audio_path,
    language=None,
    model_size="small"
):

    model = load_model(
        model_size
    )

    whisper_language = (
        normalize_stt_language(
            language
        )
    )

    segments_generator, info = (
        model.transcribe(
            audio_path,
            beam_size=5,
            language=whisper_language,
            word_timestamps=True,
            vad_filter=True
        )
    )

    full_text_parts = []

    segments_data = []

    segment_logprobs = []

    for segment in segments_generator:

        segment_text = (
            segment.text.strip()
        )

        if segment_text:

            full_text_parts.append(
                segment_text
            )

        avg_logprob = getattr(
            segment,
            "avg_logprob",
            None
        )

        if avg_logprob is not None:

            segment_logprobs.append(
                float(avg_logprob)
            )

        # ==========================
        # WORD TIMESTAMPS
        # ==========================

        words_data = []

        segment_words = (
            getattr(
                segment,
                "words",
                None
            )
            or []
        )

        for word in segment_words:

            words_data.append({
                "word":
                    word.word.strip(),

                "start":
                    word.start,

                "end":
                    word.end,

                "probability":
                    getattr(
                        word,
                        "probability",
                        None
                    )
            })

        # ==========================
        # SEGMENT
        # ==========================

        segments_data.append({
            "start":
                segment.start,

            "end":
                segment.end,

            "text":
                segment_text,

            "avg_logprob":
                avg_logprob,

            "rough_confidence":
                logprob_to_rough_confidence(
                    avg_logprob
                ),

            "no_speech_prob":
                getattr(
                    segment,
                    "no_speech_prob",
                    None
                ),

            "words":
                words_data
        })

    # ==============================
    # FULL TRANSCRIPT
    # ==============================

    full_text = " ".join(
        full_text_parts
    ).strip()

    # ==============================
    # MEAN LOG PROBABILITY
    # ==============================

    if segment_logprobs:

        mean_avg_logprob = (
            sum(segment_logprobs)
            / len(segment_logprobs)
        )

    else:

        mean_avg_logprob = None

    rough_transcription_confidence = (
        logprob_to_rough_confidence(
            mean_avg_logprob
        )
    )

    # ==============================
    # DURATION
    # ==============================

    if segments_data:

        duration_seconds = max(
            segment["end"]
            for segment in segments_data
        )

    else:

        duration_seconds = 0.0

    # ==============================
    # RETURN
    # ==============================

    return {
        "text":
            full_text,

        "segments":
            segments_data,

        "language":
            info.language,

        "language_probability":
            getattr(
                info,
                "language_probability",
                None
            ),

        "mean_avg_logprob":
            mean_avg_logprob,

        "rough_transcription_confidence":
            rough_transcription_confidence,

        "duration_seconds":
            duration_seconds
    }