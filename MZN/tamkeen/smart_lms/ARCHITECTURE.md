# 🏗️ Architecture Overview

## Project Structure

```
smart_lms/
├── app.py                      # Main entry point, login UI
├── seed.py                     # Idempotent database seeding
├── requirements.txt            # Dependencies (streamlit, pandas)
├── README.md                   # Full documentation
├── QUICKSTART.md              # Quick start commands
├── ARCHITECTURE.md            # This file
├── data/                      # Created at runtime
│   └── lms.db                 # SQLite database
├── services/                  # Backend logic
│   ├── __init__.py
│   ├── db.py                  # Database init & connection
│   ├── auth.py                # Authentication & sessions
│   ├── logic.py               # Business logic
│   ├── analytics.py           # Grading & AI recommendations
│   └── qio.py                 # CSV import/export
└── pages/                     # Streamlit multipage
    ├── 1_Teacher.py           # Teacher portal (4 tabs)
    └── 2_Student.py           # Student portal (3 tabs)
```

## Data Flow

### Teacher Creates Assessment
1. Teacher selects topic, difficulty, duration
2. Teacher targets classes/students
3. System validates question availability
4. System creates assessment record
5. System generates randomized instances per student
6. Each instance gets unique question set (seeded random)

### Student Takes Exam
1. Student opens exam from Mission Control
2. Student clicks Start → timer begins
3. System sets `started_at` and `ends_at`
4. Student answers questions → auto-saves to `answers` table
5. Timer expires OR student submits
6. System finalizes answers (`is_final=1`)
7. System grades each question
8. System updates statistics
9. System calculates mastery (EMA)
10. System generates AI recommendation

### Analytics Pipeline
```
Answer → Grade → Update Question Stats → Update Mastery → Generate Recommendation
```

## Database Schema (14 Tables)

### Core Tables
- **users**: Authentication (dual password support)
- **topics**: Subject areas
- **questions**: Question bank with metadata
- **question_stats**: Aggregated performance metrics

### Class Management
- **classes**: Teacher-owned groups
- **enrollments**: Student-class relationships

### Assessment System
- **assessments**: Exam templates
- **assessment_targets**: Class/student targeting
- **assessment_instances**: Per-student exam copies
- **instance_questions**: Question assignments

### Exam & Grading
- **answers**: Student responses (auto-save + final)
- **grading_results**: Question-level scores
- **results_analytics**: Overall performance
- **student_topic_mastery**: EMA-based tracking

## Key Algorithms

### EMA Mastery Calculation
```python
alpha = 0.25
mastery_new = alpha * accuracy + (1 - alpha) * mastery_old
confidence = 1 - exp(-n_observations / 5)
```

### Recommendation Engine
```python
if confidence < 0.35:
    return "Insufficient evidence"
elif mastery >= 0.85:
    return "Mastered - Ready for harder"
elif mastery <= 0.60:
    return "Needs Retake"
else:
    return "Progressing"
```

### Question Stats (Incremental Mean)
```python
new_avg = old_avg + (new_value - old_avg) / n_attempts
```

## Security Features

### Server-Side Exam Lock
```python
# Check before saving answer
if status not in ('assigned', 'in_progress'):
    return False, "Exam closed"

if datetime.utcnow() >= ends_at:
    return False, "Time expired"
```

### Dual Password Support
```python
# Try SHA256 first
if password_hash and sha256(input) == password_hash:
    return user

# Fallback to plain password
if password and input == password:
    return user
```

## Session Management

### Session State Keys
- `user`: {id, email, role, display_name}
- `active_instance_id`: Current exam ID
- `current_question_index`: Current question position
- `answer_{instance_id}_{question_id}`: Cached answers

## API Patterns

### Authentication
```python
user = require_login(role="teacher")  # Enforces role
```

### Database Access
```python
conn = get_connection()  # Returns sqlite3.Row factory
cursor = conn.cursor()
cursor.execute("SELECT * FROM users WHERE id = ?", (user_id,))
row = cursor.fetchone()
user_dict = dict(row)  # Convert Row to dict
```

### Instance Creation
```python
success, msg = create_assessment_instances(assessment_id, student_ids)
```

### Grading
```python
success, msg = grade_instance(instance_id)
```

## UI Components

### Teacher Portal Tabs
1. **Classes**: Create, enroll, view roster
2. **Question Bank**: CRUD, CSV, filters, stats
3. **Assessments**: Create, configure, target
4. **Student Analytics**: Trends, results, mastery

### Student Portal Tabs
1. **Mission Control**: Active/upcoming/past exams
2. **Exam**: Timed interface with auto-save
3. **My Reports**: Results with AI feedback

## Performance Considerations

- **Auto-save**: Debounced via session state comparison
- **Timer refresh**: 1-second sleep + rerun (only during exam)
- **Database**: Indexed foreign keys, UNIQUE constraints
- **CSV**: Streaming with io.StringIO
- **Queries**: LEFT JOIN for optional relationships

## Error Handling

- **Validation**: Check question availability before creating assessment
- **Idempotency**: Seed script uses INSERT OR IGNORE
- **Transactions**: Commit after multi-step operations
- **Graceful degradation**: Show info messages for empty states

## Extension Points

### Add New Question Types
1. Add to `answer_type` CHECK constraint
2. Implement grading logic in `analytics.py`
3. Update UI in `2_Student.py`

### Add New Analytics
1. Create new table for metrics
2. Update `analytics.py` grading function
3. Add visualization in `1_Teacher.py`

### Add New Roles
1. Add to `role` CHECK constraint
2. Create new page file `3_Admin.py`
3. Update `require_login()` checks

## Testing Checklist

- [ ] Teacher can create class
- [ ] Teacher can enroll students
- [ ] Teacher can add questions
- [ ] Teacher can export/import CSV
- [ ] Teacher can create assessment
- [ ] Student sees assigned exam
- [ ] Student can start exam
- [ ] Timer counts down correctly
- [ ] Answers auto-save
- [ ] Exam locks after time expires
- [ ] Exam auto-submits on timeout
- [ ] Grading calculates correctly
- [ ] Mastery updates with EMA
- [ ] Recommendations are accurate
- [ ] Analytics show trends
- [ ] Reports display correctly

## Deployment Notes

### Production Considerations
- Replace SQLite with PostgreSQL for multi-user
- Add Redis for session management
- Implement proper authentication (OAuth, JWT)
- Add rate limiting for API calls
- Enable HTTPS
- Add logging and monitoring
- Implement backup strategy
- Add email notifications
- Implement file upload limits
- Add CSRF protection

### Environment Variables
```python
DB_PATH = os.getenv("DB_PATH", "data/lms.db")
SECRET_KEY = os.getenv("SECRET_KEY", "change-me")
```

### Docker Deployment
```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["streamlit", "run", "app.py"]
```
