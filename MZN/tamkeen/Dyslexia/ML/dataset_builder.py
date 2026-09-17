from pathlib import Path
import csv
import json

from ML.feature_extractor import extract_features


def build_training_row(
    analysis_result,
    target_skill,
    attempt_id=None,
    student_id=None,
    activity_id=None,
    label_source="teacher"
):
    """
    Convert one reading analysis into one labeled ML row.

    target_skill must be a trusted educational label,
    ideally provided by a teacher/specialist.

    Examples:
        READ.FLUENCY
        READ.WORD_RECOGNITION
        READ.DECODING.DIGRAPH
        NO_SUPPORT
    """

    if not target_skill:
        raise ValueError(
            "target_skill is required."
        )

    features = extract_features(
        analysis_result
    )

    row = {
        "attempt_id": attempt_id,
        "student_id": student_id,
        "activity_id": activity_id,
        **features,
        "target_skill": target_skill,
        "label_source": label_source
    }

    return row


def save_rows_to_csv(
    rows,
    output_path="data/training_dataset.csv"
):
    """
    Save multiple training rows into CSV.
    """

    if not rows:
        raise ValueError(
            "No rows were provided."
        )

    output_path = Path(
        output_path
    )

    output_path.parent.mkdir(
        parents=True,
        exist_ok=True
    )

    fieldnames = list(
        rows[0].keys()
    )

    with open(
        output_path,
        "w",
        newline="",
        encoding="utf-8"
    ) as csv_file:

        writer = csv.DictWriter(
            csv_file,
            fieldnames=fieldnames
        )

        writer.writeheader()

        writer.writerows(
            rows
        )

    return str(
        output_path
    )


def append_row_to_csv(
    row,
    output_path="data/training_dataset.csv"
):
    """
    Append one reading attempt to the dataset.

    Creates the file if it does not exist.
    """

    output_path = Path(
        output_path
    )

    output_path.parent.mkdir(
        parents=True,
        exist_ok=True
    )

    file_exists = (
        output_path.exists()
    )

    with open(
        output_path,
        "a",
        newline="",
        encoding="utf-8"
    ) as csv_file:

        writer = csv.DictWriter(
            csv_file,
            fieldnames=list(
                row.keys()
            )
        )

        if not file_exists:

            writer.writeheader()

        writer.writerow(
            row
        )

    return str(
        output_path
    )


def save_row_to_json(
    row,
    output_path
):
    """
    Optional helper for storing one attempt
    as JSON before later combining attempts.
    """

    output_path = Path(
        output_path
    )

    output_path.parent.mkdir(
        parents=True,
        exist_ok=True
    )

    with open(
        output_path,
        "w",
        encoding="utf-8"
    ) as json_file:

        json.dump(
            row,
            json_file,
            indent=4,
            ensure_ascii=False
        )

    return str(
        output_path
    )