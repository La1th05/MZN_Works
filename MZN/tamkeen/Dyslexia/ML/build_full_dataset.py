from pathlib import Path

import pandas as pd

from App.reading.analyzer import analyze_reading
from ML.feature_extractor import extract_features


METADATA_PATH = Path(
    r"raw_data/metadata.csv"
)

AUDIO_DIRECTORY = Path(
    r"raw_data/audio"
)

OUTPUT_PATH = Path(
    r'data\training_dataset.csv'
)

# ==========================================
# LOAD METADATA
# ==========================================

metadata = pd.read_csv(
    METADATA_PATH
)


print(
    f"Found {len(metadata)} reading attempts."
)


dataset_rows = []


# ==========================================
# PROCESS EVERY RECORDING
# ==========================================

for index, row in metadata.iterrows():

    attempt_id = row[
        "attempt_id"
    ]

    student_id = row[
        "student_id"
    ]

    audio_filename = row[
        "audio_file"
    ]

    expected_text = row[
        "expected_text"
    ]

    language = row.get(
        "language",
        "en"
    )

    target_skill = row[
        "target_skill"
    ]

    label_source = row.get(
        "label_source",
        "teacher"
    )

    audio_path = (
        AUDIO_DIRECTORY
        / audio_filename
    )


    print(
        f"\nProcessing "
        f"{index + 1}/{len(metadata)}"
    )

    print(
        f"Student: {student_id}"
    )

    print(
        f"Audio: {audio_path}"
    )


    # ======================================
    # CHECK FILE
    # ======================================

    if not audio_path.exists():

        print(
            f"SKIPPED: "
            f"{audio_path} not found."
        )

        continue


    try:

        # ==================================
        # READING ANALYSIS
        # ==================================

        analysis = analyze_reading(

            expected_text=
                expected_text,

            audio_path=
                str(audio_path),

            language=
                language
        )


        # ==================================
        # FEATURE EXTRACTION
        # ==================================

        features = extract_features(
            analysis
        )


        # ==================================
        # FINAL TRAINING ROW
        # ==================================

        training_row = {

            "attempt_id":
                attempt_id,

            "student_id":
                student_id,

            "audio_file":
                audio_filename,

            **features,

            "target_skill":
                target_skill,

            "label_source":
                label_source
        }


        dataset_rows.append(
            training_row
        )


        print(
            "SUCCESS"
        )


    except Exception as error:

        print(
            f"FAILED: {error}"
        )


# ==========================================
# CREATE DATAFRAME
# ==========================================

dataset = pd.DataFrame(
    dataset_rows
)


# ==========================================
# SAVE
# ==========================================

OUTPUT_PATH.parent.mkdir(
    parents=True,
    exist_ok=True
)


dataset.to_csv(

    OUTPUT_PATH,

    index=False,

    encoding="utf-8"
)


print(
    "\n================================"
)

print(
    "DATASET BUILD COMPLETE"
)

print(
    "================================"
)

print(
    f"Rows: {len(dataset)}"
)

print(
    f"Columns: {len(dataset.columns)}"
)

print(
    f"Saved to: "
    f"{OUTPUT_PATH.resolve()}"
)