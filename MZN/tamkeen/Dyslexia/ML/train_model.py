from pathlib import Path
import pandas as pd
import numpy as np
from sklearn.model_selection import GroupShuffleSplit
from sklearn.ensemble import RandomForestRegressor
from sklearn.multioutput import MultiOutputRegressor
from xgboost import XGBRegressor
from lightgbm import LGBMRegressor
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
import joblib

def main():
    BASE_DIR = Path(__file__).resolve().parents[1]
    CSV_PATH = BASE_DIR / "data" / "speechocean_features_train.csv"
    MODEL_DIR = BASE_DIR / "ML" / "models"
    
    if not CSV_PATH.exists():
        print(f"Error: Dataset not found at {CSV_PATH}")
        return

    print("Loading dataset...")
    df = pd.read_csv(CSV_PATH)

    # 1. Define feature and target spaces
    TARGETS = [
        "expert_accuracy", 
        "expert_completeness", 
        "expert_fluency", 
        "expert_prosodic", 
        "expert_total"
    ]
    
    METADATA = ["dataset_index", "speaker", "gender", "expected_text"]
    
    # Features are everything not in TARGETS or METADATA
    feature_cols = [c for c in df.columns if c not in TARGETS + METADATA]
    
    X = df[feature_cols]
    y = df[TARGETS]
    groups = df["speaker"]

    print(f"Using {len(feature_cols)} numerical input features.")

    # 2. Speaker-Aware Data Splitting (80% Train, 20% Val)
    print("Performing speaker-aware GroupShuffleSplit...")
    gss = GroupShuffleSplit(n_splits=1, train_size=0.8, random_state=42)
    train_idx, val_idx = next(gss.split(X, y, groups))

    X_train, X_val = X.iloc[train_idx], X.iloc[val_idx]
    y_train, y_val = y.iloc[train_idx], y.iloc[val_idx]

    train_speakers = df.iloc[train_idx]["speaker"].nunique()
    val_speakers = df.iloc[val_idx]["speaker"].nunique()

    print(f"Train split: {len(X_train)} rows, {train_speakers} unique speakers.")
    print(f"Val split: {len(X_val)} rows, {val_speakers} unique speakers.")

    # 3. Model Training
    base_xgb = XGBRegressor(
        n_estimators=200,
        learning_rate=0.05,
        max_depth=4,
        subsample=0.8,
        colsample_bytree=0.8,
        random_state=42,
        n_jobs=-1
    )
    model = MultiOutputRegressor(base_xgb)
    
    model.fit(X_train, y_train)

    # 4. Evaluation
    print("\nEvaluating model on validation set...")
    y_pred = model.predict(X_val)

    print("\n" + "="*50)
    print("BASELINE METRICS (VALIDATION SET)")
    print("="*50)
    
    for i, target in enumerate(TARGETS):
        y_true_target = y_val.iloc[:, i]
        y_pred_target = y_pred[:, i]
        
        mae = mean_absolute_error(y_true_target, y_pred_target)
        rmse = np.sqrt(mean_squared_error(y_true_target, y_pred_target))
        r2 = r2_score(y_true_target, y_pred_target)
        
        print(f"Target: {target}")
        print(f"  MAE:  {mae:.4f}")
        print(f"  RMSE: {rmse:.4f}")
        print(f"  R2:   {r2:.4f}")
        print("-" * 30)

    # 5. Save the baseline model
    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    model_path = MODEL_DIR / "baseline_rf.joblib"
    
    model_data = {
        "model": model,
        "feature_names": feature_cols,
        "target_names": TARGETS
    }
    
    joblib.dump(model_data, model_path)
    print(f"\nModel and metadata saved to: {model_path}")

if __name__ == "__main__":
    main()