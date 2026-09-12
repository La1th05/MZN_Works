import functools
from faster_whisper import WhisperModel
@functools.lru_cache(maxsize=1)
def load_model():
    return WhisperModel("small",device="cuda",compute_type="float16")

def transcribe_audio(audio_path,language=None):
    model=load_model()
    segments_generator,info=model.transcribe(
        audio_path,
        beam_size=5,
        language=language
    )
    full_text=""
    segments_data=[]
    
    for segment in segments_generator:
        full_text += segment.text + " "
        segments_data.append({
            "start": segment.start,
            "end": segment.end,
            "text": segment.text.strip(),
            "confidence": segment.avg_logprob 
        })
        
    return {
        "text": full_text.strip(),
        "segments": segments_data,
        "language": info.language,
        "confidence": info.language_probability # نسبة الثقة في تحديد اللغة
    }
    