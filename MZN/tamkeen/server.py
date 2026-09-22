from pathlib import Path
import sys
import os
import joblib
import pandas as pd
import numpy as np
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

BASE_DIR = Path(__file__).resolve().parent

# Add Dyslexia and smart_lms to sys.path
sys.path.append(str(BASE_DIR / "Dyslexia"))
sys.path.append(str(BASE_DIR / "smart_lms"))

app = FastAPI(title="Tamkeen AI Unified Backend", version="1.0.0")

# Enable CORS for Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ==========================================
# 1. Load PyBKT Dyscalculia Model
# ==========================================
BKT_MODEL = None
bkt_path = BASE_DIR / "smart_lms" / "dyscalculia_master_model_best.pkl"
if bkt_path.exists():
    try:
        BKT_MODEL = joblib.load(str(bkt_path))
        print("[OK] PyBKT Dyscalculia Model loaded successfully!")
    except Exception as e:
        print(f"[ERROR] Failed to load PyBKT: {e}")

# ==========================================
# 2. Load Dyslexia XGBoost Expert Model
# ==========================================
DYSLEXIA_MODEL_DATA = None
dyslexia_path = BASE_DIR / "Dyslexia" / "ML" / "models" / "baseline_rf.joblib"
if dyslexia_path.exists():
    try:
        DYSLEXIA_MODEL_DATA = joblib.load(str(dyslexia_path))
        print("[OK] Dyslexia XGBoost Model loaded successfully!")
    except Exception as e:
        print(f"[ERROR] Failed to load Dyslexia model: {e}")

# ==========================================
# 3. Load CNN Handwriting Symbol Model
# ==========================================
SYMBOL_MODEL_LOADED = False
try:
    from services.symbol_recognizer import load_symbol_model, predict_from_base64
    load_symbol_model()
    SYMBOL_MODEL_LOADED = True
    print("[OK] Symbol CNN Model (best_symbol_cnn2.pt) loaded successfully!")
except Exception as e:
    print(f"[WARN] Failed to load Symbol CNN Model: {e}")

# ==========================================
# Pydantic Schemas
# ==========================================
class DyslexiaRequest(BaseModel):
    expected_text: str
    audio_path: str | None = None
    audio_base64: str | None = None
    duration_seconds: float = 10.0

class MathRequest(BaseModel):
    expected: str
    answer: str
    ms_response: int = 12000
    hint_count: int = 1
    attempts: int = 1
    topic_name: str = "Addition Whole Numbers"

class SymbolRecognizeRequest(BaseModel):
    image_base64: str
    topk: int = 5
    digits_only: bool = True

def ensure_wav_pcm(audio_bytes: bytes) -> tuple[bytes, float, float]:
    """
    Converts any input audio bytes (WAV, M4A, AAC, MP3) into 16kHz mono 16-bit PCM WAV.
    Returns (wav_bytes, rms_energy, peak_amplitude).
    """
    import av
    import io
    import wave
    import numpy as np

    # If it's already a standard PCM WAV
    if audio_bytes.startswith(b'RIFF'):
        try:
            with wave.open(io.BytesIO(audio_bytes), 'rb') as wf:
                channels = wf.getnchannels()
                framerate = wf.getframerate()
                sampwidth = wf.getsampwidth()
                if channels == 1 and framerate == 16000 and sampwidth == 2:
                    raw = wf.readframes(wf.getnframes())
                    samples = np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0
                    rms = float(np.sqrt(np.mean(samples**2))) if len(samples) > 0 else 0.0
                    peak = float(np.max(np.abs(samples))) if len(samples) > 0 else 0.0
                    return audio_bytes, rms, peak
        except Exception:
            pass

    # Resample using PyAV
    try:
        inp = io.BytesIO(audio_bytes)
        container = av.open(inp)
        resampler = av.AudioResampler(format='s16', layout='mono', rate=16000)
        out_buf = io.BytesIO()
        with wave.open(out_buf, 'wb') as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(16000)
            for frame in container.decode(audio=0):
                resampled_frames = resampler.resample(frame)
                for r_frame in resampled_frames:
                    wf.writeframes(r_frame.to_ndarray().tobytes())
        wav_bytes = out_buf.getvalue()

        # Compute RMS and peak
        with wave.open(io.BytesIO(wav_bytes), 'rb') as wf:
            raw = wf.readframes(wf.getnframes())
        samples = np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0
        rms = float(np.sqrt(np.mean(samples**2))) if len(samples) > 0 else 0.0
        peak = float(np.max(np.abs(samples))) if len(samples) > 0 else 0.0
        return wav_bytes, rms, peak
    except Exception as e:
        print(f"[Audio] AV conversion note: {e}")
        return audio_bytes, 0.0, 0.0

def strip_tashkeel(text: str) -> str:
    """Removes Arabic diacritics and normalizes alef variants."""
    tashkeel = '\u064B\u064C\u064D\u064E\u064F\u0650\u0651\u0652\u0670'
    for c in tashkeel:
        text = text.replace(c, '')
    text = text.replace('أ', 'ا').replace('إ', 'ا').replace('آ', 'ا')
    return text

def evaluate_speech_match(expected_text: str, spoken_text: str):
    """
    Matches spoken words against expected passage word-by-word with phonetic fuzzy matching.
    Returns dictionary with accuracy, matched count, and matched details.
    """
    import difflib
    punctuation = '.,!?;:"\'()،؟'
    expected_words = [strip_tashkeel(w.strip(punctuation).lower()) for w in expected_text.split() if w.strip(punctuation)]
    spoken_words = [strip_tashkeel(w.strip(punctuation).lower()) for w in spoken_text.split() if w.strip(punctuation)]

    if not spoken_words or not expected_words:
        return {'accuracy': 0.0, 'matched': 0, 'total': len(expected_words), 'details': [], 'spoken_words': spoken_words}

    matched = []
    used_spoken = set()
    for ew in expected_words:
        best_ratio = 0.0
        best_idx = -1
        for idx, sw in enumerate(spoken_words):
            if idx in used_spoken:
                continue
            ratio = difflib.SequenceMatcher(None, ew, sw).ratio()
            if ratio > best_ratio:
                best_ratio = ratio
                best_idx = idx

        threshold = 1.0 if len(ew) <= 3 else (0.85 if len(ew) <= 5 else 0.80)
        if best_ratio >= threshold and best_idx != -1:
            matched.append((ew, spoken_words[best_idx], round(best_ratio, 2)))
            used_spoken.add(best_idx)

    acc = (len(matched) / max(1, len(expected_words))) * 100.0
    return {
        'accuracy': round(acc, 1),
        'matched': len(matched),
        'total': len(expected_words),
        'details': matched,
        'spoken_words': spoken_words
    }

# ==========================================
# API Endpoints
# ==========================================
@app.get("/")
def health_check():
    return {
        "status": "online",
        "service": "Tamkeen AI Unified Server",
        "models": {
            "pybkt_dyscalculia": BKT_MODEL is not None,
            "dyslexia_xgboost": DYSLEXIA_MODEL_DATA is not None,
            "symbol_cnn": SYMBOL_MODEL_LOADED
        }
    }

@app.post("/api/dyslexia/analyze")
def analyze_reading_endpoint(req: DyslexiaRequest):
    import base64
    expected = req.expected_text.strip()
    punctuation = '.,!?;:"\'()،؟'
    expected_words = [strip_tashkeel(w.strip(punctuation).lower()) for w in expected.split() if w.strip(punctuation)]
    word_count = len(expected_words)
    duration = max(1.0, float(req.duration_seconds or 5.0))
    is_arabic = any('\u0600' <= c <= '\u06FF' for c in expected)

    audio_bytes = None
    wav_bytes = None
    rms_energy = 0.0
    peak_amp = 0.0
    spoken_text = ""
    has_audio_payload = False

    if req.audio_base64:
        try:
            audio_bytes = base64.b64decode(req.audio_base64)
            if len(audio_bytes) > 200:
                has_audio_payload = True
                wav_bytes, rms_energy, peak_amp = ensure_wav_pcm(audio_bytes)
                print(f"[OK] Processed audio: {len(audio_bytes)} raw bytes -> {len(wav_bytes)} WAV bytes (RMS: {rms_energy:.5f}, Peak: {peak_amp:.5f})")

                upload_dir = BASE_DIR / "uploads"
                upload_dir.mkdir(exist_ok=True)
                with open(upload_dir / "latest_reading.wav", "wb") as f:
                    f.write(wav_bytes)
        except Exception as e:
            print(f"[WARN] Error decoding audio base64: {e}")

    # If audio is completely missing or digital zero:
    if not has_audio_payload or (duration < 1.0 and rms_energy < 0.0005):
        return {
            "accuracy": 0.0,
            "wpm": 0,
            "expression": 1.0,
            "words_mastered": 0,
            "spoken_text": "",
            "discovery_word": expected.split()[-1] if expected.split() else "تحدث بوضوح",
            "discovery_meaning": "يرجى تسجيل قراءتك والتحدث بوضوح",
            "duration_seconds": duration,
            "has_audio": False,
            "is_silent": True,
            "feedback": "لم يتم رصد تسجيل صوتي. يرجى الضغط على زر الميكروفون والتحدث بوضوح." if is_arabic else "No audio recording detected. Please tap the microphone and speak clearly."
        }

    # Speech Recognition with SpeechRecognition module
    stt_recognized = False
    if wav_bytes and len(wav_bytes) > 2000:
        try:
            import speech_recognition as sr
            import io
            r = sr.Recognizer()
            r.energy_threshold = 120
            with sr.AudioFile(io.BytesIO(wav_bytes)) as source:
                audio_data = r.record(source)
            primary_lang = "ar-SA" if is_arabic else "en-US"
            secondary_lang = "en-US" if is_arabic else "ar-SA"

            try:
                spoken_text = r.recognize_google(audio_data, language=primary_lang)
                stt_recognized = True
                print(f"[STT] Recognized ({primary_lang}): '{spoken_text}'")
            except sr.UnknownValueError:
                try:
                    spoken_text = r.recognize_google(audio_data, language=secondary_lang)
                    stt_recognized = True
                    print(f"[STT] Recognized secondary ({secondary_lang}): '{spoken_text}'")
                except Exception:
                    print(f"[STT] Speech sound detected, but no recognizable dictionary words matched.")
                    stt_recognized = False
                    spoken_text = ""
            except Exception as e:
                print(f"[STT] Recognition service note: {e}")
        except Exception as e:
            print(f"[STT] Recognition initialization note: {e}")

    # Strict Word-by-Word Matching Verification
    match_result = evaluate_speech_match(expected, spoken_text)
    matched_count = match_result['matched']
    words_correct = matched_count
    spoken_words = match_result['spoken_words']

    if stt_recognized and len(spoken_words) > 0:
        calc_accuracy = match_result['accuracy']
        acc_ratio = calc_accuracy / 100.0

        if matched_count == 0:
            # User spoke words, but NONE matched the passage!
            calc_accuracy = 0.0
            words_correct = 0
            fb = f"الكلمات المنطوقة ('{spoken_text}') غير متطابقة مع النص المطلوب. يرجى قراءة الكلمات المكتوبة أمامك بدقة." if is_arabic else f"The spoken words ('{spoken_text}') do not match the expected text. Please read the displayed words carefully."
        elif calc_accuracy < 50.0:
            fb = f"قراءة جزئية ({matched_count} من {word_count} كلمات صحيحة). تدرب على نطق باقي الكلمات المكتوبة." if is_arabic else f"Partial reading ({matched_count} of {word_count} words correct). Practice pronouncing the remaining words."
        elif calc_accuracy < 80.0:
            fb = "قراءة جيدة! معظم الكلمات صحيحة، واصل التدرب للوصول إلى الإتقان التام." if is_arabic else "Good reading! Most words are correct. Keep practicing for complete fluency."
        else:
            fb = "قراءة ممتازة ورائعة! لفظ متقن ومطابق للنص تمامًا." if is_arabic else "Magnificent reading! Flawless pronunciation and perfect word match."
    else:
        # No recognizable words found by STT (unclear speech, gibberish, or noise)
        calc_accuracy = 0.0
        words_correct = 0
        fb = "لم يتم التعرف على كلمات مطابقة للنص. تأكد من وضوح نطق الكلمات المكتوبة وحاول مرة أخرى." if is_arabic else "Could not recognize words matching the passage. Please speak clearly and read the displayed text."

    # Realistic Pacing (WPM) & Expression
    if words_correct == 0:
        real_wpm = 0
        calc_expression = 1.0
    else:
        real_wpm = int((matched_count / max(1.0, duration)) * 60)
        real_wpm = max(10, min(140, real_wpm))
        calc_expression = round(min(5.0, 1.5 + ((calc_accuracy / 100.0) * 3.5)), 1)

    omissions = max(0, word_count - words_correct)
    total_errors = omissions
    error_rate = round(total_errors / max(1, word_count), 3)

    return {
        "accuracy": calc_accuracy,
        "wpm": real_wpm,
        "expression": calc_expression,
        "words_mastered": words_correct,
        "spoken_text": spoken_text,
        "matched_words": [m[0] for m in match_result.get('details', [])],
        "discovery_word": expected.split()[-1] if expected.split() else "Courage",
        "discovery_meaning": "القدرة على المحاولة والتغلب على الصعاب" if is_arabic else "Inner strength to read and explore with pride",
        "duration_seconds": duration,
        "has_audio": True,
        "is_silent": False,
        "feedback": fb
    }

@app.post("/api/smart_lms/evaluate")
def evaluate_math_endpoint(req: MathRequest):
    is_correct = req.answer.strip() == req.expected.strip()
    
    # Behavioral telemetry
    ms = float(req.ms_response or 0)
    hc = float(req.hint_count or 0)
    att = float(req.attempts or 1)

    attempt_signal = min((att - 1) / 4.0, 1.0)
    time_signal = min(ms / 60000.0, 1.0)
    frustrated = round((attempt_signal * 0.7 + time_signal * 0.3), 4)

    if is_correct:
        confused = 0.0
    else:
        fast_signal = max(0.0, 1.0 - ms / 5000.0) if ms > 0 else 1.0
        no_hint_signal = 1.0 if hc == 0 else 0.0
        confused = round((fast_signal * 0.6 + no_hint_signal * 0.4), 4)

    # PyBKT Knowledge Tracing Calculation
    p_knowledge = 0.5
    if BKT_MODEL:
        try:
            df = pd.DataFrame([{
                'order_id': 1,
                'user_id': 1,
                'skill': req.topic_name,
                'correct': 1 if is_correct else 0,
                'time_and_hint': ms * hc,
                'many_attempts': 1 if att > 2 else 0
            }])
            pred = BKT_MODEL.predict(data=df)
            p_knowledge = float(pred.iloc[-1]['state_predictions'])
        except Exception as e:
            print(f"BKT calculation error: {e}")
            p_knowledge = 0.84 if is_correct else 0.45
    else:
        p_knowledge = 0.84 if is_correct else 0.45

    # Adaptive Difficulty (Productive Struggle Framework)
    if p_knowledge < 0.40:
        difficulty = "Easy"
    elif p_knowledge > 0.75:
        difficulty = "Hard"
    else:
        difficulty = "Medium"

    feedback = "Super job! Perfect calculation!" if is_correct else "Great effort! Let us try grouping the tens first."

    return {
        "is_correct": is_correct,
        "p_knowledge": round(p_knowledge, 4),
        "adaptive_difficulty": difficulty,
        "frustration": frustrated,
        "confused": confused,
        "feedback": feedback
    }

@app.post("/api/math/recognize_symbol")
def recognize_symbol_endpoint(req: SymbolRecognizeRequest):
    if not SYMBOL_MODEL_LOADED:
        raise HTTPException(status_code=503, detail="Symbol CNN model not loaded on server.")

    try:
        res = predict_from_base64(req.image_base64, topk=req.topk, digits_only=req.digits_only)
        return res
    except Exception as e:
        print(f"[ERROR] Handwriting CNN inference error: {e}")
        raise HTTPException(status_code=400, detail=f"Inference error: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8000)
