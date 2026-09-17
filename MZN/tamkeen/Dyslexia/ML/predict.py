import sys
from pathlib import Path
import joblib
import pandas as pd
import json

from App.reading.analyzer import analyze_reading
from ML.feature_extractor import extract_features
from App.skills.evidence import infer_skill_evidence
from App.recommendations.engine import get_next_recommendation
from App.adaptive.engine import get_adaptive_plan

def load_reading_model():
    model_path = Path(__file__).resolve().parents[1] / "ML" / "models" / "baseline_rf.joblib"
    if not model_path.exists():
        raise FileNotFoundError(f"Model not found at {model_path}. Run train_model.py first.")
    return joblib.load(model_path)

def predict_expert_scores(audio_path, expected_text, model_data=None):
    if model_data is None:
        model_data = load_reading_model()
        
    model = model_data["model"]
    feature_names = model_data["feature_names"]
    target_names = model_data["target_names"]
    
    # 1. STT & Reading Analysis
    analysis = analyze_reading(expected_text=expected_text, audio_path=audio_path, language="en")
    
    # 2. Extract Numerical Features
    features = extract_features(analysis)
    feature_df = pd.DataFrame([features])
    for col in feature_names:
        if col not in feature_df.columns:
            feature_df[col] = 0.0
            
    X = feature_df[feature_names]
    
    # 3. Model Inference
    predictions = model.predict(X)[0]
    ml_results = dict(zip(target_names, predictions))
    
    # 4. Skill Evidence (Combining raw metrics + ML predictions)
    skill_updates = infer_skill_evidence(
        metrics=analysis["metrics"],
        errors=analysis["errors"],
        ml_predictions=ml_results
    )
    
    # 5. Recommendation Engine
    recommendation = get_next_recommendation(
        skill_updates=skill_updates,
        metrics=analysis["metrics"],
        errors=analysis["errors"]
    )
    
    # 6. Adaptive Learning Plan
    adaptive_plan = get_adaptive_plan(
        skill_updates=skill_updates,
        recommendation=recommendation
    )
    
    return {
        "transcript": analysis["transcript"],
        "predictions": ml_results,
        "skill_updates": skill_updates,
        "recommendation": recommendation,
        "adaptive_plan": adaptive_plan
    }

def main():
    BASE_DIR = Path(__file__).resolve().parents[1]
    
    if len(sys.argv) > 2:
        audio_file = sys.argv[1]
        text = sys.argv[2]
    else:
        # Default test case
        audio_file = BASE_DIR / "raw_data" / "audio" / "test_sample.wav" 
        text = "WE CALL IT BEAR"
        if not audio_file.exists():
            print(f"Usage: python -m ML.predict <path_to_audio_file> <expected_text>")
            return

    print("\nRunning the Complete Educational Inference Pipeline...")
    result = predict_expert_scores(str(audio_file), text)
    
    print("\n" + "="*50)
    print("1. MODEL PREDICTIONS")
    print("="*50)
    for target, score in result["predictions"].items():
        print(f"  {target}: {score:.2f}/10")
        
    print("\n" + "="*50)
    print("2. EDUCATIONAL SKILL EVIDENCE")
    print("="*50)
    print(json.dumps(result["skill_updates"], indent=2))
    
    print("\n" + "="*50)
    print("3. ADAPTIVE LEARNING PLAN")
    print("="*50)
    print(json.dumps(result["adaptive_plan"], indent=2))

if __name__ == "__main__":
    main()