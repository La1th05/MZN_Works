from speech.sst import transcribe_audio
from alignment import align_words
from metrics import word_metrics
from normalization import normalize_text
def analyze_reading(audio_path,language,expected_text,time_taken):
    recognized_text,segment,lang,conf=transcribe_audio(audio_path,language)
    
    recognized_text=normalize_text(recognized_text,language)
    
    errors=align_words(expected_text,recognized_text)
    
    metrics=word_metrics(expected_text,recognized_text,time_taken)
    
    