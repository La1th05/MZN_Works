# 🎓 AI-Driven Smart LMS

A complete Learning Management System built with Streamlit and SQLite featuring AI-powered analytics, adaptive assessments, and real-time exam monitoring.

## 📁 Project Structure

```
smart_lms/
├── app.py                      # Main application entry point
├── seed.py                     # Database seeding script
├── requirements.txt            # Python dependencies
├── README.md                   # This file
├── data/                       # SQLite database (created at runtime)
│   └── lms.db
├── services/                   # Backend services
│   ├── __init__.py
│   ├── db.py                   # Database initialization and connection
│   ├── auth.py                 # Authentication and session management
│   ├── logic.py                # Business logic (assessments, instances)
│   ├── analytics.py            # Grading and AI recommendations
│   └── qio.py                  # Question import/export (CSV)
└── pages/                      # Streamlit multipage app
    ├── 1_Teacher.py            # Teacher portal
    └── 2_Student.py            # Student portal
```

## ✨ Features

### Teacher Features
- **Class Management**: Create classes and enroll students
- **Question Bank**: CRUD operations with CSV import/export
- **Assessment Creation**: Configure topic, difficulty, duration, and targeting
- **Student Analytics**: View performance trends, mastery levels, and AI recommendations

### Student Features
- **Mission Control**: View active, upcoming, and past assessments
- **Exam Interface**: Timed exams with auto-save and server-side lock
- **Reports**: Detailed results with question-level feedback

### AI-Powered Analytics
- **Mastery Tracking**: EMA-based topic mastery calculation
- **Adaptive Recommendations**: Personalized suggestions based on performance
- **Question Statistics**: Track attempts, success rate, and average time

### Security Features
- **Server-Enforced Exam Lock**: No saving after time expires
- **Dual Password Support**: SHA256 hashing with legacy plain password fallback
- **Session Management**: Secure authentication with role-based access

## 🚀 Installation & Setup (Windows PowerShell)

### Step 1: Navigate to Project Directory
```powershell
cd smart_lms
```

### Step 2: Create Virtual Environment
```powershell
python -m venv .venv
```

### Step 3: Activate Virtual Environment
```powershell
.\.venv\Scripts\activate
```

### Step 4: Install Dependencies
```powershell
pip install -r requirements.txt
```

### Step 5: Seed Database
```powershell
python seed.py
```

Expected output:
```
🌱 Seeding database...
✓ Created user: teacher@demo.com
✓ Created user: student@demo.com
...
✅ Database seeded successfully!
```

### Step 6: Run Application
```powershell
streamlit run app.py
```

The application will open in your browser at `http://localhost:8501`

## 👥 Demo Credentials

### Teacher Account
- **Email**: teacher@demo.com
- **Password**: teacher123

### Student Accounts
- **Email**: student@demo.com / **Password**: student123
- **Email**: student1@demo.com / **Password**: student123
- **Email**: student2@demo.com / **Password**: student123

## 🧪 Testing Guide

### Test 1: Teacher Workflow
1. Log in as teacher@demo.com
2. Navigate to **Teacher** page
3. **Classes Tab**: View "Math 101 - 2024" class with enrolled students
4. **Question Bank Tab**: 
   - View existing questions filtered by topic/difficulty
   - Add a new question
   - Export questions to CSV
5. **Assessments Tab**: View existing "Addition Quiz - Easy"
6. **Student Analytics Tab**: Select a student and view their performance

### Test 2: Student Exam Flow
1. Log in as student@demo.com
2. Navigate to **Student** page
3. **Mission Control Tab**: See "Addition Quiz - Easy" in active assessments
4. Click **Open Exam**
5. **Exam Tab**: 
   - Click **Start Exam** (timer begins)
   - Answer questions (auto-saves on each change)
   - Navigate between questions using sidebar
   - Click **Submit Exam**
6. **My Reports Tab**: View graded results with AI recommendation

### Test 3: Server-Side Exam Lock
1. Start an exam as a student
2. Wait for timer to expire (or manually set a short duration)
3. Verify that:
   - Answers cannot be saved after expiration
   - Exam auto-submits when time reaches zero
   - Status changes to "auto_submitted" then "graded"

### Test 4: CSV Import/Export
1. Log in as teacher
2. Go to Question Bank
3. Export questions to CSV
4. Modify CSV (add new question or update existing)
5. Import CSV back
6. Verify changes are reflected

### Test 5: AI Recommendations
1. Complete multiple assessments as a student
2. View reports to see different recommendations:
   - High mastery (≥85%): "Student Mastered Topic..."
   - Low mastery (≤60%): "Needs Retake..."
   - Medium mastery: "Progressing..."
   - Few attempts: "Insufficient evidence..."

## 🗄️ Database Schema

### Key Tables
- **users**: Authentication and user profiles
- **topics**: Subject areas (Addition, Algebra, etc.)
- **questions**: Question bank with difficulty levels
- **classes**: Teacher-managed student groups
- **assessments**: Exam configurations
- **assessment_instances**: Per-student exam instances
- **answers**: Student responses (auto-save + final)
- **grading_results**: Question-level scores
- **results_analytics**: Overall performance metrics
- **student_topic_mastery**: EMA-based mastery tracking

## 🔧 Configuration

### Database Location
SQLite database is created at `data/lms.db`

### Session State Keys
- `user`: Current logged-in user
- `active_instance_id`: Currently opened exam
- `current_question_index`: Current question in exam
- `answer_{instance_id}_{question_id}`: Cached answers

## 📊 Analytics Algorithm

### Mastery Calculation (EMA)
```
alpha = 0.25
mastery_new = alpha * current_accuracy + (1 - alpha) * mastery_previous
confidence = 1 - exp(-n_observations / 5)
```

### Recommendation Logic
- **Confidence < 0.35**: "Insufficient evidence"
- **Mastery ≥ 0.85**: "Mastered - Ready for harder"
- **Mastery ≤ 0.60**: "Needs Retake"
- **Otherwise**: "Progressing - Keep practicing"

## 🛠️ Troubleshooting

### Issue: "streamlit: command not found"
**Solution**: Ensure virtual environment is activated
```powershell
.\.venv\Scripts\activate
```

### Issue: Database locked error
**Solution**: Close all connections and restart
```powershell
# Delete database and reseed
Remove-Item data\lms.db
python seed.py
```

### Issue: Duplicate key errors
**Solution**: All widgets have unique keys. If you see this error, clear browser cache or use incognito mode.

### Issue: Timer not updating
**Solution**: The timer uses `st.rerun()` with 1-second sleep. Ensure you're on the Exam tab with an in-progress assessment.

## 📝 Notes

- **No deprecated APIs**: Uses `st.rerun()` instead of `st.experimental_rerun`
- **Idempotent seeding**: Safe to run `seed.py` multiple times
- **Server-side validation**: All exam locks enforced in backend
- **Dual password support**: Accepts both SHA256 hash and legacy plain passwords
- **Auto-save**: Answers saved on every input change (when exam is active)

## 🎯 Key Implementation Details

1. **Multipage Structure**: Uses `pages/` folder (not `page/`)
2. **Unique Widget Keys**: Every Streamlit widget has a unique key
3. **Import Compatibility**: All imports work from project root
4. **Safe Migrations**: Database init uses CREATE IF NOT EXISTS
5. **UTC Timestamps**: All datetime operations use UTC
6. **Row Factory**: SQLite connections use `sqlite3.Row` for dict-like access

## 📄 License

This is a demo project for educational purposes.
