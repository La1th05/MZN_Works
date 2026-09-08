# 🚀 Quick Start Guide

## Windows PowerShell Commands

```powershell
# Navigate to project
cd smart_lms

# Create virtual environment
python -m venv .venv

# Activate virtual environment
.\.venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Seed database with demo data
python seed.py

# Run the application
streamlit run app.py
```

## First Login

Open browser at `http://localhost:8501`

### Teacher Login
- Email: `teacher@demo.com`
- Password: `teacher123`

### Student Login
- Email: `student@demo.com`
- Password: `student123`

## Quick Test Flow

### As Teacher:
1. Go to **Teacher** page (sidebar)
2. Check **Classes** tab → See enrolled students
3. Check **Question Bank** → View/add questions
4. Check **Assessments** → See created assessments
5. Check **Student Analytics** → View student performance

### As Student:
1. Go to **Student** page (sidebar)
2. **Mission Control** → See available assessments
3. Click **Open Exam** → Start the exam
4. Answer questions → Auto-saves
5. Click **Submit Exam** → Get instant results
6. **My Reports** → View detailed feedback

## Features to Test

✅ Timed exams with countdown
✅ Auto-save answers
✅ Server-side time lock
✅ Auto-submit on timeout
✅ AI-powered recommendations
✅ CSV import/export
✅ Real-time analytics
✅ Topic mastery tracking

## Troubleshooting

**Can't find streamlit?**
```powershell
.\.venv\Scripts\activate
```

**Database issues?**
```powershell
Remove-Item data\lms.db
python seed.py
```

**Port already in use?**
```powershell
streamlit run app.py --server.port 8502
```
