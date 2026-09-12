from pathlib import Path
import uuid

import edge_tts


# ==========================================
# DEFAULT VOICES
# ==========================================

DEFAULT_VOICES = {
    "en": "en-US-AriaNeural",
    "ar": "ar-JO-SanaNeural"
}


def normalize_tts_language(language):
    """
    Convert language names into short codes.
    """

    if language is None:
        return "en"

    language = str(language).strip().lower()

    if language in [
        "english",
        "eng",
        "en"
    ]:
        return "en"

    if language in [
        "arabic",
        "ara",
        "ar",
        "العربية",
        "عربي"
    ]:
        return "ar"

    return language


def speed_to_rate(speed):
    """
    Convert:
        speed = 1.0
    into:
        +0%

    Examples:
        0.8 -> -20%
        1.0 -> +0%
        1.2 -> +20%
    """

    try:
        speed = float(speed)

    except (TypeError, ValueError):
        speed = 1.0

    # Keep speed in a reasonable range
    speed = max(
        0.5,
        min(2.0, speed)
    )

    percentage = round(
        (speed - 1.0) * 100
    )

    if percentage >= 0:
        return f"+{percentage}%"

    return f"{percentage}%"


def synthesize_speech(
    text,
    language="en",
    speed=1.0,
    output_path=None,
    voice=None
):
    """
    Convert text to speech and save it as MP3.

    Returns metadata that the frontend can use.

    IMPORTANT:
    This function does NOT use Streamlit,
    HTML, or frontend-specific code.
    """

    # ======================================
    # VALIDATION
    # ======================================

    if text is None:
        raise ValueError(
            "Text cannot be None."
        )

    text = str(text).strip()

    if not text:
        raise ValueError(
            "Text cannot be empty."
        )

    # ======================================
    # LANGUAGE
    # ======================================

    language = normalize_tts_language(
        language
    )

    # ======================================
    # VOICE
    # ======================================

    if voice is None:

        voice = DEFAULT_VOICES.get(
            language
        )

    if voice is None:

        raise ValueError(
            f"No default TTS voice configured "
            f"for language: {language}"
        )

    # ======================================
    # SPEED
    # ======================================

    rate = speed_to_rate(
        speed
    )

    # ======================================
    # OUTPUT FILE
    # ======================================

    if output_path is None:

        output_directory = Path(
            "generated_audio"
        )

        output_directory.mkdir(
            parents=True,
            exist_ok=True
        )

        filename = (
            f"tts_{uuid.uuid4().hex}.mp3"
        )

        output_path = (
            output_directory
            / filename
        )

    else:

        output_path = Path(
            output_path
        )

        output_path.parent.mkdir(
            parents=True,
            exist_ok=True
        )

    # ======================================
    # TTS
    # ======================================

    communicate = edge_tts.Communicate(
        text=text,
        voice=voice,
        rate=rate
    )

    # stream_sync avoids forcing the caller
    # to manage asyncio for simple backend use.
    with open(
        output_path,
        "wb"
    ) as audio_file:

        for chunk in communicate.stream_sync():

            if chunk["type"] == "audio":

                audio_file.write(
                    chunk["data"]
                )

    # ======================================
    # RESULT
    # ======================================

    return {
        "audio_path":
            str(output_path),

        "language":
            language,

        "voice":
            voice,

        "speed":
            speed,

        "rate":
            rate,

        "mime_type":
            "audio/mpeg"
    }