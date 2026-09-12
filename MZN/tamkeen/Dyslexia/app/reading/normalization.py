import re
import unicodedata


APOSTROPHES = {
    "’": "'",
    "‘": "'",
    "ʼ": "'",
    "`": "'"
}


# Arabic diacritics
ARABIC_DIACRITICS = re.compile(
    r"[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED]"
)


def normalize_language(language):

    if language is None:
        return "en"

    language = str(language).strip().lower()

    if language in ["english", "eng", "en"]:
        return "en"

    if language in ["arabic", "ara", "ar", "العربية", "عربي"]:
        return "ar"

    return language


def normalize_text(text, language="en"):

    if text is None:
        return ""

    # Unicode normalization
    text = unicodedata.normalize("NFKC", str(text))

    language = normalize_language(language)

    for old_apostrophe, new_apostrophe in APOSTROPHES.items():
        text = text.replace(old_apostrophe, new_apostrophe)

    if language == "en":

        text = text.lower()

        # Remove punctuation but keep apostrophe
        text = re.sub(
            r"[^\w\s']",
            " ",
            text,
            flags=re.UNICODE
        )

        text = text.replace("_", " ")

    elif language == "ar":

        # Remove Tatweel
        text = text.replace("ـ", "")

        # Remove Arabic diacritics
        text = ARABIC_DIACRITICS.sub("", text)

        # Remove punctuation
        text = re.sub(
            r"[^\w\s']",
            " ",
            text,
            flags=re.UNICODE
        )

        text = text.replace("_", " ")


    else:

        text = re.sub(
            r"[^\w\s']",
            " ",
            text,
            flags=re.UNICODE
        )

        text = text.replace("_", " ")

    # Remove extra spaces
    text = re.sub(
        r"\s+",
        " ",
        text
    ).strip()

    return text