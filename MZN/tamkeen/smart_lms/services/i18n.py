from __future__ import annotations

import streamlit as st


# ============================================================
# MZN / DysCalc AI - Internationalization (i18n)
# Supported languages:
#   en -> English
#   ar -> Arabic
# ============================================================


SUPPORTED_LANGUAGES = {
    "en": "English",
    "ar": "العربية",
}


TRANSLATIONS = {
    # ========================================================
    # ENGLISH
    # ========================================================
    "en": {
        # ---------------- COMMON ----------------
        "common.language": "Language / اللغة",
        "common.sign_out": "Sign out",
        "common.email": "Email",
        "common.password": "Password",
        "common.continue": "Continue",
        "common.cancel": "Cancel",
        "common.save": "Save",
        "common.remove": "Remove",
        "common.open": "Open",
        "common.start": "Start",
        "common.submit": "Submit",
        "common.next": "Next",
        "common.previous": "Previous",
        "common.yes": "Yes",
        "common.no": "No",
        "common.loading": "Loading...",
        "common.error": "Something went wrong.",
        "common.success": "Completed successfully.",
        "common.minutes": "minutes",
        "common.questions": "questions",

        # ---------------- BRAND ----------------
        "brand.name": "DysCalc AI",
        "brand.subtitle": "Adaptive learning workspace",

        # ---------------- NAVIGATION ----------------
        "nav.home": "Home",
        "nav.teacher": "Teacher",
        "nav.student": "Student",

        # ---------------- HOME / LOGIN ----------------
        "app.page_title": "DysCalc AI",

        "app.signed_in": "Signed in",

        "app.hero_title":
            "Adaptive math support, designed for learning clarity.",

        "app.hero_text":
            "A focused learning workspace for teachers and students "
            "using assessment data, mastery tracking, and adaptive "
            "support without adding unnecessary cognitive load.",

        "app.hero_kicker":
            "DysCalc AI · Education intelligence",

        "app.built_for_learning":
            "Built for learning, not dashboard clutter",

        "app.feature_student":
            "Student-first assessment flow with one question "
            "in focus at a time.",

        "app.feature_teacher":
            "Teacher visibility into classes, assignments, mastery, "
            "and learning support signals.",

        "app.feature_adaptive":
            "Adaptive recommendations that translate model output "
            "into understandable next steps.",

        "app.feature_accessible":
            "Accessible structure with high contrast, larger controls, "
            "consistent spacing, and calm status cues.",

        "app.privacy_title":
            "Privacy-first UX principle:",

        "app.privacy_text":
            "behavioral signals should be treated as support indicators, "
            "not diagnoses or labels about a learner.",

        "app.sign_in": "Sign in",

        "app.email_placeholder":
            "you@school.edu",

        "app.password_placeholder":
            "Enter your password",

        "app.invalid_login":
            "The email or password is incorrect, "
            "or the account is inactive.",

        "app.welcome":
            "Welcome, {name}",

        "app.choose_workspace":
            "Choose your workspace to continue.",

        "app.open_teacher":
            "Open Teacher Workspace",

        "app.teacher_info":
            "Manage classes, build assessments, "
            "and review learner progress.",

        "app.open_student":
            "Open Student Workspace",

        "app.student_info":
            "Continue assessments, practice skills, "
            "and review your progress.",

        "app.unsupported_role":
            "This account has an unsupported role. "
            "Ask an administrator to review it.",

        # ====================================================
        # TEACHER
        # ====================================================
        "teacher.page_title":
            "Teacher Workspace · DysCalc AI",

        "teacher.account":
            "Teacher account",

        "teacher.hero_title":
            "Teacher Workspace",

        "teacher.hero_subtitle":
            "Manage learning groups, design assessments, "
            "and turn performance data into clear instructional actions.",

        "teacher.hero_kicker":
            "INSTRUCTION & LEARNER SUPPORT",

        # Teacher metrics
        "teacher.metrics.active_classes":
            "Active classes",

        "teacher.metrics.active_classes_help":
            "Learning groups you manage",

        "teacher.metrics.learners":
            "Learners",

        "teacher.metrics.learners_help":
            "Active enrolled students",

        "teacher.metrics.assessments":
            "Assessments",

        "teacher.metrics.assessments_help":
            "Created assessment plans",

        "teacher.metrics.support_review":
            "Support review",

        "teacher.metrics.support_review_help":
            "Learners with a low-mastery topic",

        # Teacher tabs
        "teacher.tabs.overview":
            "Overview",

        "teacher.tabs.classes":
            "Classes",

        "teacher.tabs.question_bank":
            "Question Bank",

        "teacher.tabs.assessments":
            "Assessments",

        "teacher.tabs.insights":
            "Learner Insights",

        # Overview
        "teacher.recent_assessments":
            "Recent assessments",

        "teacher.recent_assessments_help":
            "A quick view of your latest assessment plans.",

        "teacher.instructional_workflow":
            "Instructional workflow",

        "teacher.workflow.1":
            "Organize learners into classes.",

        "teacher.workflow.2":
            "Maintain the question bank by topic and difficulty.",

        "teacher.workflow.3":
            "Assign assessments to classes or individual learners.",

        "teacher.workflow.4":
            "Review mastery trends and decide the next support action.",

        "teacher.decision_support":
            "Use mastery and behavioral metrics as decision support. "
            "A teacher should remain the final decision-maker for "
            "intervention, difficulty changes, and learner-facing feedback.",

        # Classes
        "teacher.create_class":
            "Create class",

        "teacher.class_name":
            "Class name",

        "teacher.year":
            "Year",

        "teacher.class_created":
            "Class created.",

        "teacher.roster":
            "Roster",

        "teacher.class":
            "Class",

        "teacher.add_learner":
            "Add learner",

        "teacher.enroll_learner":
            "Enroll learner",

        "teacher.learner_enrolled":
            "Learner enrolled.",

        "teacher.no_classes":
            "No classes are available yet.",

        "teacher.no_students":
            "No learners are available yet.",

        # Question bank
        "teacher.question_bank":
            "Question Bank",

        "teacher.create_question":
            "Create question",

        "teacher.question":
            "Question",

        "teacher.topic":
            "Topic",

        "teacher.difficulty":
            "Difficulty",

        "teacher.answer":
            "Correct answer",

        "teacher.hint":
            "Hint",

        "teacher.question_created":
            "Question created.",

        # Assessments
        "teacher.assessment_builder":
            "Assessment builder",

        "teacher.create_assessment":
            "Create assessment",

        "teacher.assessment_title":
            "Assessment title",

        "teacher.topics":
            "Topics",

        "teacher.number_questions":
            "Number of questions",

        "teacher.duration":
            "Duration (minutes)",

        "teacher.assign_classes":
            "Assign to classes",

        "teacher.assign_students":
            "Assign to individual learners",

        "teacher.start_optional":
            "Start (optional)",

        "teacher.end_optional":
            "End (optional)",

        "teacher.create_assign":
            "Create & assign",

        "teacher.assessment_created":
            "Assessment created and assigned.",

        # Insights
        "teacher.learner_insights":
            "Learner Insights",

        "teacher.select_learner":
            "Select learner",

        "teacher.mastery":
            "Mastery",

        "teacher.accuracy":
            "Accuracy",

        "teacher.attempts":
            "Attempts",

        "teacher.recommendation":
            "Recommendation",

        # ====================================================
        # STUDENT
        # ====================================================
        "student.page_title":
            "Student Workspace · DysCalc AI",

        "student.account":
            "Student account",

        "student.hero_title":
            "Student Workspace",

        "student.hero_subtitle":
            "One task at a time, clear progress, and learning feedback "
            "that helps you know what to do next.",

        "student.hero_kicker":
            "FOCUSED ADAPTIVE LEARNING",

        # Student metrics
        "student.metrics.available_work":
            "Available work",

        "student.metrics.available_help":
            "Assigned or in-progress",

        "student.metrics.completed":
            "Completed",

        "student.metrics.completed_help":
            "Graded learning sessions",

        "student.metrics.average_accuracy":
            "Average accuracy",

        "student.metrics.accuracy_help":
            "Across graded work",

        "student.metrics.strong_topics":
            "Strong topics",

        "student.metrics.strong_help":
            "Topics at 85%+ mastery",

        # Student tabs
        "student.tabs.learning":
            "My Learning",

        "student.tabs.progress":
            "Progress",

        "student.tabs.reports":
            "Reports",

        # My Learning
        "student.my_learning":
            "My Learning",

        "student.my_learning_help":
            "Continue assigned work or begin a new assessment "
            "when you are ready.",

        "student.no_available_work":
            "You do not have any available work right now.",

        "student.assigned":
            "Assigned",

        "student.in_progress":
            "In progress",

        "student.open":
            "Open",

        "student.start_assessment":
            "Start assessment",

        "student.continue_assessment":
            "Continue assessment",

        "student.submit_assessment":
            "Submit assessment",

        "student.question":
            "Question",

        "student.of":
            "of",

        "student.choose_answer":
            "Choose an answer",

        "student.select_option":
            "Select an option",

        "student.your_answer":
            "Your answer",

        "student.type_answer":
            "Type your answer",

        "student.need_hint":
            "Need a hint?",

        "student.check_continue":
            "Check answer & continue",

        "student.correct":
            "Correct. Nice work.",

        "student.incorrect":
            "Not quite. Keep trying.",

        "student.enter_answer":
            "Enter an answer before continuing.",

        "student.time_remaining":
            "Time remaining",

        # Progress
        "student.progress_title":
            "My progress",

        "student.progress_help":
            "See how your skills and mastery are developing.",

        "student.topic":
            "Topic",

        "student.mastery":
            "Mastery",

        "student.attempts":
            "Attempts",

        "student.accuracy":
            "Accuracy",

        # Reports
        "student.reports_title":
            "Reports",

        "student.reports_help":
            "Review completed assessments and see what to practice next.",

        "student.completed_assessment":
            "Completed assessment",

        "student.score":
            "Score",

        "student.difficulty":
            "Difficulty",

        "student.recommended_next_step":
            "Recommended next step",

        "student.question_feedback":
            "Question feedback",

        # ====================================================
        # MASTERY
        # ====================================================
        "mastery.strong":
            "Strong mastery",

        "mastery.developing":
            "Developing",

        "mastery.support":
            "Needs support",

        # ====================================================
        # STATUS
        # ====================================================
        "status.assigned":
            "Assigned",

        "status.in_progress":
            "In progress",

        "status.submitted":
            "Submitted",

        "status.auto_submitted":
            "Auto submitted",

        "status.graded":
            "Graded",

        # ====================================================
        # DIFFICULTY
        # ====================================================
        "difficulty.Easy":
            "Easy",

        "difficulty.Medium":
            "Medium",

        "difficulty.Hard":
            "Hard",

        "difficulty.Adaptive":
            "Adaptive",

        # ====================================================
        # TOPICS
        # ====================================================
        "topics.Addition (+)":
            "Addition (+)",

        "topics.Subtraction (-)":
            "Subtraction (-)",

        "topics.Multiplication (×)":
            "Multiplication (×)",

        "topics.Division (÷)":
            "Division (÷)",

        # ====================================================
        # TABLES
        # ====================================================
        "table.title":
            "Title",

        "table.difficulty":
            "Difficulty",

        "table.questions":
            "Questions",

        "table.duration":
            "Duration",

        "table.created":
            "Created",

        "table.topic":
            "Topic",

        "table.mastery":
            "Mastery",

        "table.attempts":
            "Attempts",

        "table.accuracy":
            "Accuracy",
    },

    # ========================================================
    # ARABIC
    # ========================================================
    "ar": {
        # ---------------- COMMON ----------------
        "common.language": "Language / اللغة",
        "common.sign_out": "تسجيل الخروج",
        "common.email": "البريد الإلكتروني",
        "common.password": "كلمة المرور",
        "common.continue": "متابعة",
        "common.cancel": "إلغاء",
        "common.save": "حفظ",
        "common.remove": "إزالة",
        "common.open": "فتح",
        "common.start": "بدء",
        "common.submit": "تسليم",
        "common.next": "التالي",
        "common.previous": "السابق",
        "common.yes": "نعم",
        "common.no": "لا",
        "common.loading": "جاري التحميل...",
        "common.error": "حدث خطأ.",
        "common.success": "تمت العملية بنجاح.",
        "common.minutes": "دقائق",
        "common.questions": "أسئلة",

        # ---------------- BRAND ----------------
        "brand.name": "DysCalc AI",
        "brand.subtitle": "مساحة تعلم تكيفية",

        # ---------------- NAVIGATION ----------------
        "nav.home": "الرئيسية",
        "nav.teacher": "المعلم",
        "nav.student": "الطالب",

        # ---------------- HOME / LOGIN ----------------
        "app.page_title": "DysCalc AI",

        "app.signed_in": "تم تسجيل الدخول",

        "app.hero_title":
            "دعم تكيفي للرياضيات مصمم لتسهيل عملية التعلم.",

        "app.hero_text":
            "مساحة تعلم مركزة للمعلمين والطلاب تعتمد على بيانات "
            "التقييم وتتبع الإتقان والدعم التكيفي دون إضافة "
            "عبء معرفي غير ضروري.",

        "app.hero_kicker":
            "DysCalc AI · ذكاء تعليمي",

        "app.built_for_learning":
            "مصمم للتعلم، وليس لازدحام لوحات المعلومات",

        "app.feature_student":
            "تجربة تقييم تركز على الطالب من خلال عرض سؤال واحد في كل مرة.",

        "app.feature_teacher":
            "إتاحة رؤية واضحة للمعلم حول الصفوف والاختبارات "
            "والإتقان ومؤشرات دعم التعلم.",

        "app.feature_adaptive":
            "توصيات تكيفية تحول نتائج النماذج إلى خطوات تالية "
            "واضحة وسهلة الفهم.",

        "app.feature_accessible":
            "تصميم سهل الوصول بتباين واضح وأزرار أكبر "
            "ومسافات متناسقة ومؤشرات هادئة.",

        "app.privacy_title":
            "مبدأ الخصوصية أولاً:",

        "app.privacy_text":
            "يجب التعامل مع المؤشرات السلوكية كوسيلة للمساعدة "
            "والدعم، وليس كتشخيص أو تصنيف للطالب.",

        "app.sign_in":
            "تسجيل الدخول",

        "app.email_placeholder":
            "you@school.edu",

        "app.password_placeholder":
            "أدخل كلمة المرور",

        "app.invalid_login":
            "البريد الإلكتروني أو كلمة المرور غير صحيحة، "
            "أو أن الحساب غير فعال.",

        "app.welcome":
            "مرحباً، {name}",

        "app.choose_workspace":
            "اختر مساحة العمل للمتابعة.",

        "app.open_teacher":
            "فتح مساحة عمل المعلم",

        "app.teacher_info":
            "إدارة الصفوف وإنشاء الاختبارات ومراجعة تقدم الطلاب.",

        "app.open_student":
            "فتح مساحة عمل الطالب",

        "app.student_info":
            "متابعة الاختبارات والتدرب على المهارات "
            "ومراجعة مستوى التقدم.",

        "app.unsupported_role":
            "هذا الحساب يمتلك دوراً غير مدعوم. "
            "يرجى مراجعة مسؤول النظام.",

        # ====================================================
        # TEACHER
        # ====================================================
        "teacher.page_title":
            "مساحة عمل المعلم · DysCalc AI",

        "teacher.account":
            "حساب المعلم",

        "teacher.hero_title":
            "مساحة عمل المعلم",

        "teacher.hero_subtitle":
            "إدارة المجموعات التعليمية وإنشاء الاختبارات "
            "وتحويل بيانات الأداء إلى إجراءات تعليمية واضحة.",

        "teacher.hero_kicker":
            "التعليم ودعم المتعلم",

        # Teacher metrics
        "teacher.metrics.active_classes":
            "الصفوف النشطة",

        "teacher.metrics.active_classes_help":
            "المجموعات التعليمية التي تديرها",

        "teacher.metrics.learners":
            "الطلاب",

        "teacher.metrics.learners_help":
            "الطلاب المسجلون حالياً",

        "teacher.metrics.assessments":
            "الاختبارات",

        "teacher.metrics.assessments_help":
            "خطط التقييم التي تم إنشاؤها",

        "teacher.metrics.support_review":
            "بحاجة إلى مراجعة",

        "teacher.metrics.support_review_help":
            "طلاب لديهم مهارة بمستوى إتقان منخفض",

        # Teacher tabs
        "teacher.tabs.overview":
            "نظرة عامة",

        "teacher.tabs.classes":
            "الصفوف",

        "teacher.tabs.question_bank":
            "بنك الأسئلة",

        "teacher.tabs.assessments":
            "الاختبارات",

        "teacher.tabs.insights":
            "تحليل الطلاب",

        # Overview
        "teacher.recent_assessments":
            "الاختبارات الأخيرة",

        "teacher.recent_assessments_help":
            "نظرة سريعة على أحدث خطط التقييم.",

        "teacher.instructional_workflow":
            "سير العملية التعليمية",

        "teacher.workflow.1":
            "تنظيم الطلاب ضمن الصفوف.",

        "teacher.workflow.2":
            "إدارة بنك الأسئلة حسب الموضوع ومستوى الصعوبة.",

        "teacher.workflow.3":
            "تعيين الاختبارات للصفوف أو لطلاب محددين.",

        "teacher.workflow.4":
            "مراجعة اتجاهات الإتقان وتحديد إجراء الدعم التالي.",

        "teacher.decision_support":
            "استخدم مؤشرات الإتقان والسلوك كأدوات لدعم القرار. "
            "يجب أن يبقى المعلم صاحب القرار النهائي فيما يتعلق "
            "بالتدخل وتغيير مستوى الصعوبة والتغذية الراجعة للطالب.",

        # Classes
        "teacher.create_class":
            "إنشاء صف",

        "teacher.class_name":
            "اسم الصف",

        "teacher.year":
            "السنة",

        "teacher.class_created":
            "تم إنشاء الصف.",

        "teacher.roster":
            "قائمة الطلاب",

        "teacher.class":
            "الصف",

        "teacher.add_learner":
            "إضافة طالب",

        "teacher.enroll_learner":
            "تسجيل الطالب",

        "teacher.learner_enrolled":
            "تم تسجيل الطالب.",

        "teacher.no_classes":
            "لا توجد صفوف حالياً.",

        "teacher.no_students":
            "لا يوجد طلاب متاحون حالياً.",

        # Question bank
        "teacher.question_bank":
            "بنك الأسئلة",

        "teacher.create_question":
            "إنشاء سؤال",

        "teacher.question":
            "السؤال",

        "teacher.topic":
            "الموضوع",

        "teacher.difficulty":
            "الصعوبة",

        "teacher.answer":
            "الإجابة الصحيحة",

        "teacher.hint":
            "التلميح",

        "teacher.question_created":
            "تم إنشاء السؤال.",

        # Assessments
        "teacher.assessment_builder":
            "إنشاء اختبار",

        "teacher.create_assessment":
            "إنشاء اختبار",

        "teacher.assessment_title":
            "عنوان الاختبار",

        "teacher.topics":
            "المواضيع",

        "teacher.number_questions":
            "عدد الأسئلة",

        "teacher.duration":
            "المدة بالدقائق",

        "teacher.assign_classes":
            "تعيين للصفوف",

        "teacher.assign_students":
            "تعيين لطلاب محددين",

        "teacher.start_optional":
            "وقت البدء (اختياري)",

        "teacher.end_optional":
            "وقت الانتهاء (اختياري)",

        "teacher.create_assign":
            "إنشاء وتعيين",

        "teacher.assessment_created":
            "تم إنشاء الاختبار وتعيينه.",

        # Insights
        "teacher.learner_insights":
            "تحليل الطلاب",

        "teacher.select_learner":
            "اختر الطالب",

        "teacher.mastery":
            "الإتقان",

        "teacher.accuracy":
            "الدقة",

        "teacher.attempts":
            "المحاولات",

        "teacher.recommendation":
            "التوصية",

        # ====================================================
        # STUDENT
        # ====================================================
        "student.page_title":
            "مساحة عمل الطالب · DysCalc AI",

        "student.account":
            "حساب الطالب",

        "student.hero_title":
            "مساحة عمل الطالب",

        "student.hero_subtitle":
            "مهمة واحدة في كل مرة، وتقدم واضح، وتغذية راجعة "
            "تساعدك على معرفة الخطوة التالية.",

        "student.hero_kicker":
            "تعلم تكيفي مركز",

        # Student metrics
        "student.metrics.available_work":
            "المهام المتاحة",

        "student.metrics.available_help":
            "مهام معينة أو قيد التنفيذ",

        "student.metrics.completed":
            "المكتملة",

        "student.metrics.completed_help":
            "جلسات تعلم تم تقييمها",

        "student.metrics.average_accuracy":
            "متوسط الدقة",

        "student.metrics.accuracy_help":
            "عبر الأعمال التي تم تقييمها",

        "student.metrics.strong_topics":
            "المهارات القوية",

        "student.metrics.strong_help":
            "المهارات التي وصلت إلى إتقان 85% أو أكثر",

        # Student tabs
        "student.tabs.learning":
            "تعلمي",

        "student.tabs.progress":
            "التقدم",

        "student.tabs.reports":
            "التقارير",

        # My Learning
        "student.my_learning":
            "تعلمي",

        "student.my_learning_help":
            "تابع المهام المعينة أو ابدأ اختباراً جديداً عندما تكون جاهزاً.",

        "student.no_available_work":
            "لا يوجد لديك أي عمل متاح حالياً.",

        "student.assigned":
            "تم التعيين",

        "student.in_progress":
            "قيد التنفيذ",

        "student.open":
            "فتح",

        "student.start_assessment":
            "بدء الاختبار",

        "student.continue_assessment":
            "متابعة الاختبار",

        "student.submit_assessment":
            "تسليم الاختبار",

        "student.question":
            "السؤال",

        "student.of":
            "من",

        "student.choose_answer":
            "اختر إجابة",

        "student.select_option":
            "اختر خياراً",

        "student.your_answer":
            "إجابتك",

        "student.type_answer":
            "اكتب إجابتك",

        "student.need_hint":
            "تحتاج إلى تلميح؟",

        "student.check_continue":
            "تحقق من الإجابة وتابع",

        "student.correct":
            "إجابة صحيحة، أحسنت.",

        "student.incorrect":
            "ليست صحيحة، حاول مرة أخرى.",

        "student.enter_answer":
            "أدخل إجابة قبل المتابعة.",

        "student.time_remaining":
            "الوقت المتبقي",

        # Progress
        "student.progress_title":
            "تقدمي",

        "student.progress_help":
            "شاهد كيف تتطور مهاراتك ومستوى إتقانك.",

        "student.topic":
            "الموضوع",

        "student.mastery":
            "الإتقان",

        "student.attempts":
            "المحاولات",

        "student.accuracy":
            "الدقة",

        # Reports
        "student.reports_title":
            "التقارير",

        "student.reports_help":
            "راجع الاختبارات المكتملة واعرف ما الذي تحتاج إلى التدرب عليه تالياً.",

        "student.completed_assessment":
            "الاختبار المكتمل",

        "student.score":
            "العلامة",

        "student.difficulty":
            "الصعوبة",

        "student.recommended_next_step":
            "الخطوة التالية المقترحة",

        "student.question_feedback":
            "ملاحظات الأسئلة",

        # ====================================================
        # MASTERY
        # ====================================================
        "mastery.strong":
            "إتقان قوي",

        "mastery.developing":
            "قيد التطور",

        "mastery.support":
            "يحتاج إلى دعم",

        # ====================================================
        # STATUS
        # ====================================================
        "status.assigned":
            "تم التعيين",

        "status.in_progress":
            "قيد التنفيذ",

        "status.submitted":
            "تم التسليم",

        "status.auto_submitted":
            "تم التسليم تلقائياً",

        "status.graded":
            "تم التقييم",

        # ====================================================
        # DIFFICULTY
        # ====================================================
        "difficulty.Easy":
            "سهل",

        "difficulty.Medium":
            "متوسط",

        "difficulty.Hard":
            "صعب",

        "difficulty.Adaptive":
            "تكيفي",

        # ====================================================
        # TOPICS
        # ====================================================
        "topics.Addition (+)":
            "الجمع (+)",

        "topics.Subtraction (-)":
            "الطرح (-)",

        "topics.Multiplication (×)":
            "الضرب (×)",

        "topics.Division (÷)":
            "القسمة (÷)",

        # ====================================================
        # TABLES
        # ====================================================
        "table.title":
            "العنوان",

        "table.difficulty":
            "الصعوبة",

        "table.questions":
            "عدد الأسئلة",

        "table.duration":
            "المدة",

        "table.created":
            "تاريخ الإنشاء",

        "table.topic":
            "الموضوع",

        "table.mastery":
            "الإتقان",

        "table.attempts":
            "المحاولات",

        "table.accuracy":
            "الدقة",
    },
}


# ============================================================
# LANGUAGE STATE
# ============================================================

def get_lang() -> str:
    """
    Return the active language.

    Default:
        en
    """

    lang = st.session_state.get("lang", "en")

    if lang not in SUPPORTED_LANGUAGES:
        lang = "en"
        st.session_state["lang"] = "en"

    return lang


def set_lang(lang: str) -> None:
    """
    Set the current UI language.
    """

    if lang not in SUPPORTED_LANGUAGES:
        lang = "en"

    st.session_state["lang"] = lang


# ============================================================
# TRANSLATION
# ============================================================

def t(key: str, **kwargs) -> str:
    """
    Translate a UI key.

    Example:

        t("common.sign_out")

        t(
            "app.welcome",
            name="Ahmad"
        )

    If an Arabic translation does not exist,
    English is used as a fallback.

    If the key does not exist in English either,
    the key itself is returned.
    """

    lang = get_lang()

    text = TRANSLATIONS.get(
        lang,
        TRANSLATIONS["en"],
    ).get(key)

    # English fallback
    if text is None:
        text = TRANSLATIONS["en"].get(key)

    # Final fallback
    if text is None:
        return key

    try:
        return text.format(**kwargs)
    except (KeyError, ValueError):
        return text


# ============================================================
# RTL / LTR
# ============================================================

def is_rtl() -> bool:
    """
    Arabic uses RTL layout.
    """

    return get_lang() == "ar"


def apply_language_direction() -> None:
    """
    Apply RTL styling when Arabic is selected.
    Apply LTR styling when English is selected.

    Important:
    numbers, code, email addresses and some inputs
    stay LTR for readability.
    """

    if is_rtl():

        st.markdown(
            """
            <style>

            /* ==========================================
               MAIN APPLICATION
               ========================================== */

            .stApp {
                direction: rtl;
            }

            .main .block-container {
                direction: rtl;
                text-align: right;
            }


            /* ==========================================
               TEXT
               ========================================== */

            .stMarkdown,
            .stCaption,
            .stAlert,
            .stText,
            p,
            h1,
            h2,
            h3,
            h4,
            h5,
            h6 {
                text-align: right;
            }


            /* ==========================================
               SIDEBAR
               ========================================== */

            [data-testid="stSidebar"] {
                direction: rtl;
            }

            [data-testid="stSidebar"] .stMarkdown,
            [data-testid="stSidebar"] p,
            [data-testid="stSidebar"] label {
                text-align: right;
            }


            /* ==========================================
               FORMS
               ========================================== */

            label {
                text-align: right;
            }

            [data-testid="stTextInput"] {
                direction: rtl;
            }

            [data-testid="stTextArea"] {
                direction: rtl;
            }


            /* ==========================================
               SELECTBOX / MULTISELECT
               ========================================== */

            [data-baseweb="select"] {
                direction: rtl;
                text-align: right;
            }


            /* ==========================================
               TABS
               ========================================== */

            [data-baseweb="tab-list"] {
                direction: rtl;
            }


            /* ==========================================
               METRICS
               ========================================== */

            [data-testid="stMetric"] {
                direction: rtl;
                text-align: right;
            }


            /* ==========================================
               EXPANDERS
               ========================================== */

            [data-testid="stExpander"] {
                direction: rtl;
                text-align: right;
            }


            /* ==========================================
               DATAFRAMES
               ========================================== */

            [data-testid="stDataFrame"] {
                direction: rtl;
            }


            /* ==========================================
               KEEP TECHNICAL VALUES LTR
               ========================================== */

            code,
            pre,
            kbd {
                direction: ltr !important;
                text-align: left !important;
            }

            input[type="email"],
            input[type="number"],
            input[type="password"] {
                direction: ltr;
                text-align: left;
            }

            </style>
            """,
            unsafe_allow_html=True,
        )

    else:

        st.markdown(
            """
            <style>

            .stApp {
                direction: ltr;
            }

            .main .block-container {
                direction: ltr;
            }

            </style>
            """,
            unsafe_allow_html=True,
        )


# ============================================================
# LANGUAGE SELECTOR
# ============================================================

def language_switcher(
    *,
    location: str = "sidebar",
    key: str = "global_language_selector",
) -> str:
    """
    Display the English / Arabic language selector.

    Example:

        language_switcher()

    or:

        language_switcher(
            location="main"
        )
    """

    current = get_lang()

    options = list(SUPPORTED_LANGUAGES.keys())

    try:
        current_index = options.index(current)
    except ValueError:
        current_index = 0

    container = (
        st.sidebar
        if location == "sidebar"
        else st
    )

    selected = container.selectbox(
        "Language / اللغة",
        options=options,
        index=current_index,
        format_func=lambda lang: SUPPORTED_LANGUAGES[lang],
        key=key,
    )

    if selected != current:
        set_lang(selected)
        st.rerun()

    return selected


# ============================================================
# DISPLAY HELPERS
# ============================================================

def difficulty_label(value: str | None) -> str:
    """
    Translate difficulty for DISPLAY ONLY.

    Database values must remain:

        Easy
        Medium
        Hard
        Adaptive
    """

    if not value:
        return ""

    key = f"difficulty.{value}"

    translated = t(key)

    if translated == key:
        return str(value)

    return translated


def status_label(value: str | None) -> str:
    """
    Translate assessment status for DISPLAY ONLY.

    Database values remain unchanged.
    """

    if not value:
        return ""

    mapping = {
        "assigned": "status.assigned",
        "in_progress": "status.in_progress",
        "submitted": "status.submitted",
        "auto_submitted": "status.auto_submitted",
        "graded": "status.graded",
    }

    key = mapping.get(str(value))

    if not key:
        return str(value)

    return t(key)


def topic_label(value: str | None) -> str:
    """
    Translate topic name for DISPLAY ONLY.

    IMPORTANT:
    The real topic stored in the database remains English,
    so the BKT / analytics code is not affected.
    """

    if not value:
        return ""

    key = f"topics.{value}"

    translated = t(key)

    if translated == key:
        return str(value)

    return translated


def mastery_label(value: float | int | None) -> str:
    """
    Convert mastery score to translated educational label.
    """

    try:
        mastery = float(value or 0.0)
    except (TypeError, ValueError):
        mastery = 0.0

    if mastery >= 0.85:
        return t("mastery.strong")

    if mastery >= 0.60:
        return t("mastery.developing")

    return t("mastery.support")