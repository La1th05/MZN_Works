from pathlib import Path
import tempfile
import traceback

import pandas as pd
from datasets import load_dataset, Audio

from App.reading.analyzer import analyze_reading
from ML.feature_extractor import extract_features


print("=== SPEECHOCEAN DATASET BUILDER STARTED ===")


# ============================================================
# PATHS
# ============================================================

BASE_DIR = Path(__file__).resolve().parents[1]

OUTPUT_DIR = BASE_DIR / "data"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

OUTPUT_PATH = OUTPUT_DIR / "speechocean_features_train.csv"


# ============================================================
# SETTINGS
# ============================================================

# Number of samples to consider from the beginning of train set.
#
# First test:
#     25
#
# Later:
#     100
#     500
#     2500
#
MAX_SAMPLES = 2500

# If True, only process children with age <= CHILD_MAX_AGE.
CHILDREN_ONLY = True

CHILD_MAX_AGE = 15


# ============================================================
# AUDIO PREPARATION
# ============================================================

def prepare_audio_file(audio_data):
    """
    Prepare a usable WAV file for Whisper.

    SpeechOcean762 may provide audio as:
        - an existing path
        - raw audio bytes

    Returns:
        (audio_path, temporary_path)

    temporary_path is None when an existing file was used.
    """

    audio_path = audio_data.get("path")
    audio_bytes = audio_data.get("bytes")

    # --------------------------------------------------------
    # Try existing audio path
    # --------------------------------------------------------

    if audio_path:

        path = Path(audio_path)

        if path.exists():
            return str(path), None

    # --------------------------------------------------------
    # Otherwise create temporary WAV from bytes
    # --------------------------------------------------------

    if audio_bytes:

        temp_file = tempfile.NamedTemporaryFile(
            suffix=".wav",
            delete=False
        )

        temp_file.write(audio_bytes)
        temp_file.close()

        return temp_file.name, temp_file.name

    raise ValueError(
        "No usable audio path or audio bytes were found."
    )


# ============================================================
# LOAD DATASET
# ============================================================

print("\nLoading SpeechOcean762...")

dataset = load_dataset(
    "mispeech/speechocean762"
)

print("Dataset loaded.")


print("\nDataset splits:")
print(dataset)


# ============================================================
# AUDIO COLUMN
# ============================================================

dataset = dataset.cast_column(
    "audio",
    Audio(decode=False)
)


# ============================================================
# TRAIN DATA
# ============================================================

train_dataset = dataset["train"]

print("\nOriginal train rows:")
print(len(train_dataset))


# ============================================================
# OPTIONAL CHILD FILTER
# ============================================================

if CHILDREN_ONLY:

    print(
        f"\nFiltering to children age <= {CHILD_MAX_AGE}..."
    )

    train_dataset = train_dataset.filter(
        lambda row: row["age"] <= CHILD_MAX_AGE
    )

    print("Rows after child filter:")
    print(len(train_dataset))


# ============================================================
# CHECK EXISTING OUTPUT
# ============================================================

processed_indices = set()


if OUTPUT_PATH.exists():

    try:

        existing_df = pd.read_csv(
            OUTPUT_PATH
        )

        print("\nExisting output file found:")
        print(OUTPUT_PATH)

        print("\nExisting rows:")
        print(len(existing_df))

        # ----------------------------------------------------
        # Check whether this is a resumable dataset
        # ----------------------------------------------------

        if "dataset_index" in existing_df.columns:

            processed_indices = set(
                existing_df["dataset_index"]
                .dropna()
                .astype(int)
            )

            print("\nAlready processed dataset indices:")
            print(len(processed_indices))

        else:

            print(
                "\nWARNING:"
            )

            print(
                "Existing CSV does not contain "
                "'dataset_index'."
            )

            print(
                "This file cannot safely be resumed."
            )

            print(
                "Delete the old CSV before starting."
            )

            raise RuntimeError(
                "Output CSV is from an older format. "
                "Delete data/speechocean_features_train.csv "
                "and run again."
            )

    except RuntimeError:
        raise

    except Exception as error:

        print(
            "\nWARNING: Could not read existing CSV."
        )

        print(
            "Error:",
            error
        )

        raise


else:

    print(
        "\nNo existing output CSV found."
    )

    print(
        "Starting a new dataset."
    )


# ============================================================
# SELECT NUMBER OF SAMPLES
# ============================================================

if MAX_SAMPLES is not None:

    number_to_process = min(
        MAX_SAMPLES,
        len(train_dataset)
    )

    train_dataset = train_dataset.select(
        range(number_to_process)
    )

else:

    number_to_process = len(train_dataset)


print("\nProcessing:")
print(
    number_to_process,
    "samples"
)


# ============================================================
# CURRENT RUN STATISTICS
# ============================================================

successful_this_run = 0
failed_this_run = 0
skipped_this_run = 0


# ============================================================
# PROCESS DATASET
# ============================================================

for index, sample in enumerate(train_dataset):

    # --------------------------------------------------------
    # Skip samples already processed
    # --------------------------------------------------------

    if index in processed_indices:

        print("\n" + "=" * 60)

        print(
            f"Skipping sample {index + 1}/{number_to_process}"
        )

        print(
            "Reason: already processed"
        )

        print("=" * 60)

        skipped_this_run += 1

        continue


    # --------------------------------------------------------
    # Sample header
    # --------------------------------------------------------

    print("\n" + "=" * 60)

    print(
        f"Sample {index + 1}/{number_to_process}"
    )

    print("=" * 60)


    temporary_path = None


    try:

        # ----------------------------------------------------
        # Basic information
        # ----------------------------------------------------

        print(
            "Dataset index:",
            index
        )

        print(
            "Speaker:",
            sample["speaker"]
        )

        print(
            "Age:",
            sample["age"]
        )

        print(
            "Gender:",
            sample["gender"]
        )

        print(
            "Expected text:",
            sample["text"]
        )


        # ----------------------------------------------------
        # Prepare audio
        # ----------------------------------------------------

        audio_path, temporary_path = prepare_audio_file(
            sample["audio"]
        )

        print(
            "Audio file ready:"
        )

        print(
            audio_path
        )


        # ----------------------------------------------------
        # Reading analysis
        # ----------------------------------------------------

        print(
            "\nRunning reading analysis..."
        )

        analysis = analyze_reading(
            expected_text=sample["text"],
            audio_path=audio_path,
            language="en"
        )


        # ----------------------------------------------------
        # Whisper transcript
        # ----------------------------------------------------

        print(
            "\nWhisper transcript:"
        )

        print(
            analysis["transcript"]
        )


        # ----------------------------------------------------
        # Feature extraction
        # ----------------------------------------------------

        print(
            "\nExtracting features..."
        )

        features = extract_features(
            analysis
        )

        print(
            "Features extracted."
        )


        print(
            "\nFeature names:"
        )

        print(
            list(features.keys())
        )


        # ====================================================
        # BUILD TRAINING ROW
        # ====================================================

        training_row = {

            # ------------------------------------------------
            # Dataset metadata
            # ------------------------------------------------

            "dataset_index": index,

            "speaker": sample["speaker"],

            "age": sample["age"],

            "gender": sample["gender"],

            "expected_text": sample["text"],


            # ------------------------------------------------
            # Features extracted by our system
            # ------------------------------------------------

            **features,


            # ------------------------------------------------
            # Expert labels from SpeechOcean762
            # ------------------------------------------------

            "expert_accuracy": sample["accuracy"],

            "expert_completeness": sample["completeness"],

            "expert_fluency": sample["fluency"],

            "expert_prosodic": sample["prosodic"],

            "expert_total": sample["total"],
        }


        # ====================================================
        # SAVE IMMEDIATELY
        # ====================================================

        row_df = pd.DataFrame(
            [training_row]
        )


        if OUTPUT_PATH.exists():

            row_df.to_csv(
                OUTPUT_PATH,
                mode="a",
                header=False,
                index=False,
                encoding="utf-8"
            )

        else:

            row_df.to_csv(
                OUTPUT_PATH,
                mode="w",
                header=True,
                index=False,
                encoding="utf-8"
            )


        # Add to processed set so this index is known
        # immediately during this run.

        processed_indices.add(
            index
        )


        successful_this_run += 1


        print(
            "\nSaved to CSV:"
        )

        print(
            OUTPUT_PATH
        )


        print(
            "\nSUCCESS"
        )


    except Exception as error:

        failed_this_run += 1

        print(
            "\nFAILED"
        )

        print(
            "Error type:",
            type(error).__name__
        )

        print(
            "Error:",
            error
        )

        print(
            "\nFULL TRACEBACK:"
        )

        traceback.print_exc()


    finally:

        # ----------------------------------------------------
        # Delete temporary audio file
        # ----------------------------------------------------

        if temporary_path:

            try:

                Path(
                    temporary_path
                ).unlink(
                    missing_ok=True
                )

            except Exception as cleanup_error:

                print(
                    "\nWARNING:"
                )

                print(
                    "Could not delete temporary audio:"
                )

                print(
                    cleanup_error
                )


# ============================================================
# FINAL DATASET REPORT
# ============================================================

print("\n" + "=" * 60)

print(
    "SPEECHOCEAN BUILD FINISHED"
)

print("=" * 60)


print(
    "\nSuccessful this run:",
    successful_this_run
)

print(
    "Failed this run:",
    failed_this_run
)

print(
    "Skipped this run:",
    skipped_this_run
)


# ============================================================
# READ FINAL CSV
# ============================================================

if OUTPUT_PATH.exists():

    try:

        final_df = pd.read_csv(
            OUTPUT_PATH
        )


        print(
            "\nFinal CSV information:"
        )

        print(
            "Rows:",
            len(final_df)
        )

        print(
            "Columns:",
            len(final_df.columns)
        )


        print(
            "\nColumns:"
        )

        print(
            list(final_df.columns)
        )


        print(
            "\nSaved to:"
        )

        print(
            OUTPUT_PATH
        )


    except Exception as error:

        print(
            "\nWARNING:"
        )

        print(
            "Could not read final CSV."
        )

        print(
            "Error:",
            error
        )

else:

    print(
        "\nNo output CSV was created."
    )

    if failed_this_run > 0:

        print(
            "All processed samples failed."
        )