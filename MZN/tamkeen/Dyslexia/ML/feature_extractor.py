import math
import librosa
import numpy as np

def extract_acoustic_features(audio_path):
    """
    Extract lightweight acoustic features (Energy, Spectral Centroid, ZCR)
    to help predict prosody and fluency.
    """
    if not audio_path:
        return {}
        
    try:
        y, sr = librosa.load(audio_path, sr=None)
        if len(y) == 0:
            return {}
        
        rms = librosa.feature.rms(y=y)[0]
        cent = librosa.feature.spectral_centroid(y=y, sr=sr)[0]
        zcr = librosa.feature.zero_crossing_rate(y)[0]
        
        return {
            "rms_mean": float(np.mean(rms)),
            "rms_std": float(np.std(rms)),
            "spectral_centroid_mean": float(np.mean(cent)),
            "zero_crossing_rate_mean": float(np.mean(zcr))
        }
    except Exception:
        return {
            "rms_mean": 0.0,
            "rms_std": 0.0,
            "spectral_centroid_mean": 0.0,
            "zero_crossing_rate_mean": 0.0
        }

def safe_divide(numerator, denominator, default=0.0):
    if denominator in [None, 0]:
        return default
    return numerator / denominator

def safe_mean(values, default=0.0):
    clean_values = [value for value in values if value is not None]
    if not clean_values:
        return default
    return sum(clean_values) / len(clean_values)

def extract_word_timing_features(segments, long_pause_threshold=1.0):
    all_words = []
    for segment in segments or []:
        words = segment.get("words", [])
        for word in words:
            all_words.append({
                "start": word.get("start"),
                "end": word.get("end"),
                "probability": word.get("probability")
            })

    word_durations = []
    confidences = []

    for word in all_words:
        start = word["start"]
        end = word["end"]
        if start is not None and end is not None and end >= start:
            word_durations.append(end - start)
        if word["probability"] is not None:
            confidences.append(float(word["probability"]))

    pauses = []
    for index in range(1, len(all_words)):
        previous_end = all_words[index - 1]["end"]
        current_start = all_words[index]["start"]
        if previous_end is not None and current_start is not None:
            pause = current_start - previous_end
            if pause >= 0:
                pauses.append(pause)

    long_pause_count = sum(1 for pause in pauses if pause >= long_pause_threshold)
    low_confidence_count = sum(1 for confidence in confidences if confidence < 0.60)

    return {
        "average_word_duration": safe_mean(word_durations),
        "average_pause_duration": safe_mean(pauses),
        "max_pause_duration": max(pauses) if pauses else 0.0,
        "long_pause_count": long_pause_count,
        "mean_word_confidence": safe_mean(confidences),
        "low_confidence_word_rate": safe_divide(low_confidence_count, len(confidences))
    }

def extract_features(analysis_result):
    metrics = analysis_result.get("metrics", {})
    stt = analysis_result.get("stt", {})
    errors = analysis_result.get("errors", [])
    audio_path = analysis_result.get("audio_path")
    
    acoustic_features = extract_acoustic_features(audio_path)

    accuracy = metrics.get("accuracy", 0.0)
    wpm = metrics.get("wpm", 0.0)
    duration = metrics.get("duration", 0.0)
    words_expected = metrics.get("words_expected", 0)
    words_spoken = metrics.get("words_spoken", 0)
    words_correct = metrics.get("words_correct", 0)
    omissions = metrics.get("omissions", 0)
    substitutions = metrics.get("substitutions", 0)
    insertions = metrics.get("insertions", 0)
    repetitions = metrics.get("repetitions", 0)
    
    total_reading_errors = omissions + substitutions + insertions + repetitions

    timing_features = extract_word_timing_features(stt.get("segments", []))
    
    error_confidences = [float(error["confidence"]) for error in errors if error.get("confidence") is not None]

    features = {
        "accuracy": float(accuracy) if accuracy is not None else 0.0,
        "wpm": float(wpm) if wpm is not None else 0.0,
        "duration": float(duration) if duration is not None else 0.0,
        "words_expected": int(words_expected),
        "words_spoken": int(words_spoken),
        "words_correct": int(words_correct),
        "omissions": int(omissions),
        "substitutions": int(substitutions),
        "insertions": int(insertions),
        "repetitions": int(repetitions),
        "omission_rate": float(safe_divide(omissions, words_expected)),
        "substitution_rate": float(safe_divide(substitutions, words_expected)),
        "insertion_rate": float(safe_divide(insertions, words_expected)),
        "repetition_rate": float(safe_divide(repetitions, words_expected)),
        "total_error_rate": float(safe_divide(total_reading_errors, words_expected)),
        "word_count_difference": int(words_spoken - words_expected),
        "spoken_expected_ratio": float(safe_divide(words_spoken, words_expected)),
        "language_probability": float(stt.get("language_probability", 0.0) or 0.0),
        "mean_avg_logprob": float(stt.get("mean_avg_logprob", 0.0) or 0.0),
        "mean_error_confidence": float(safe_mean(error_confidences)),
        "average_word_duration": float(timing_features["average_word_duration"]),
        "average_pause_duration": float(timing_features["average_pause_duration"]),
        "max_pause_duration": float(timing_features["max_pause_duration"]),
        "long_pause_count": int(timing_features["long_pause_count"]),
        "mean_word_confidence": float(timing_features["mean_word_confidence"]),
        "low_confidence_word_rate": float(timing_features["low_confidence_word_rate"]),
        
        # Acoustic features
        "rms_mean": acoustic_features.get("rms_mean", 0.0),
        "rms_std": acoustic_features.get("rms_std", 0.0),
        "spectral_centroid_mean": acoustic_features.get("spectral_centroid_mean", 0.0),
        "zero_crossing_rate_mean": acoustic_features.get("zero_crossing_rate_mean", 0.0)
    }

    return features