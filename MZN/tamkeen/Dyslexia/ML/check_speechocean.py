from pathlib import Path
import pandas as pd

def main():
    BASE_DIR = Path(__file__).resolve().parents[1]
    CSV_PATH = BASE_DIR / "data" / "speechocean_features_train.csv"

    if not CSV_PATH.exists():
        print(f"File not found: {CSV_PATH}")
        return

    df = pd.read_csv(CSV_PATH)

    print("==================================================")
    print("1. DATASET SHAPE")
    print("==================================================")
    print(f"Rows: {len(df)}")
    print(f"Columns: {len(df.columns)}")

    print("\n==================================================")
    print("2. MISSING VALUES")
    print("==================================================")
    missing = df.isna().sum()
    missing = missing[missing > 0]
    if len(missing) > 0:
        print(missing.to_string())
    else:
        print("No missing values detected.")

    print("\n==================================================")
    print("3. UNIQUE IDENTIFIERS & DUPLICATES")
    print("==================================================")
    print(f"Duplicate dataset_index entries: {df['dataset_index'].duplicated().sum()}")
    print(f"Unique speakers: {df['speaker'].nunique()}")
    
    speaker_counts = df['speaker'].value_counts()
    print(f"Min samples per speaker: {speaker_counts.min()}")
    print(f"Max samples per speaker: {speaker_counts.max()}")

    print("\n==================================================")
    print("4. TARGET DISTRIBUTIONS (EXPERT SCORES)")
    print("==================================================")
    targets = ['expert_accuracy', 'expert_completeness', 'expert_fluency', 'expert_prosodic', 'expert_total']
    # Check if targets exist in the dataframe before describing
    available_targets = [t for t in targets if t in df.columns]
    if available_targets:
        print(df[available_targets].describe().T.to_string())
    else:
        print("Target columns not found!")

    print("\n==================================================")
    print("5. PREDICTIVE FEATURE SNEAK PEEK (FIRST 5 ROWS)")
    print("==================================================")
    # Exclude targets and metadata for a cleaner view
    exclude_cols = available_targets + ['dataset_index', 'speaker', 'gender', 'expected_text']
    features = [c for c in df.columns if c not in exclude_cols]
    
    if features:
        print(df[['age'] + features[:6]].head().to_string())
    else:
        print("No numerical features found.")

if __name__ == "__main__":
    main()