# DysCalc AI UI Upgrade — Drop-in Installation

This package is designed to sit on top of the existing `smart_lms` backend supplied with the project.

## Copy these files into the project

```text
smart_lms/
├── app.py                         <- replace with this package's app.py
├── seed.py                        <- replace (secure demo password seeding)
├── requirements.txt               <- replace/merge
├── pages/
│   ├── 1_Teacher.py               <- add/replace
│   └── 2_Student.py               <- add/replace
└── services/
    ├── logic.py                    <- replace with patched version
    └── ui.py                       <- add
```

Keep the project's existing `services/auth.py`, `services/db.py`, `services/analytics.py`, and `services/qio.py`.

## Install

```powershell
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
python seed.py
streamlit run app.py
```

## Important

The PyBKT model is loaded with `joblib`, so the environment needs `pyBKT` installed and the model file must be in one of the locations expected by `services/analytics.py`.

The handwriting recognizer additionally expects `services/models/best_symbol_cnn2.pt`. The uploaded project set did not include that checkpoint, so the redesigned UI does not expose handwriting input as a production-ready path yet.

## Theme fix (v2)
This package now includes `.streamlit/config.toml`. Keep that folder in the project root (next to `app.py`). It forces Streamlit's native widgets to use the same light corporate theme as the custom UI, fixing faint/invisible inactive tabs and dark tables. Restart Streamlit after copying the files.
