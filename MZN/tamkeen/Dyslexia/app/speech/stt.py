import os
import sys

# Force Windows to locate the cuBLAS and cuDNN DLLs dynamically inside the .venv
if os.name == "nt":
    # Locate the virtual environment's site-packages
    site_packages = os.path.join(os.path.dirname(os.path.dirname(sys.executable)), "Lib", "site-packages")
    
    cublas_bin = os.path.join(site_packages, "nvidia", "cublas", "bin")
    cudnn_bin = os.path.join(site_packages, "nvidia", "cudnn", "bin")
    
    # Register directories so CTranslate2 can load them
    if os.path.exists(cublas_bin):
        os.add_dll_directory(cublas_bin)
        os.environ["PATH"] = cublas_bin + os.pathsep + os.environ.get("PATH", "")
        
    if os.path.exists(cudnn_bin):
        os.add_dll_directory(cudnn_bin)
        os.environ["PATH"] = cudnn_bin + os.pathsep + os.environ.get("PATH", "")

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
    print("Loading Whisper on CUDA...")
    
    return WhisperModel(
        model_size,
        device="cuda", 
        compute_type="float16" # Use "int8_float16" if you need to save VRAM on smaller GPUs
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