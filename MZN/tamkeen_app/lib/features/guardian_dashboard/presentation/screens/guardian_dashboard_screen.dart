import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/ai_bridge_service.dart';
import '../../../../core/services/intro_tour_service.dart';
import '../../../../core/services/pdf_report_service.dart';
import '../../../../core/state/app_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../guardian_dashboard_sizes.dart';

class GuardianDashboardScreen extends StatefulWidget {
  const GuardianDashboardScreen({super.key});

  @override
  State<GuardianDashboardScreen> createState() => _GuardianDashboardScreenState();
}

class _GuardianDashboardScreenState extends State<GuardianDashboardScreen> {
  String _getDateFilterLabel(AppState state) {
    final now = DateTime.now();
    switch (state.selectedDateFilterIndex) {
      case 1:
        return state.isArabic ? 'آخر 30 يوماً' : 'Last 30 Days';
      case 2:
        return state.isArabic ? 'كامل السجل (جميع الجلسات)' : 'All Time (All Sessions)';
      case 0:
      default:
        final startOfWeek = now.subtract(Duration(days: now.weekday % 7));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        final f = DateFormat('d MMM');
        return state.isArabic
            ? 'هذا الأسبوع (${f.format(startOfWeek)} - ${f.format(endOfWeek)})'
            : 'This Week (${f.format(startOfWeek)} - ${f.format(endOfWeek)})';
    }
  }

  void _showDateFilterDialog(BuildContext context, AppState state) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday % 7));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    final f = DateFormat('d MMM');
    final weekLabel = state.isArabic
        ? 'هذا الأسبوع (${f.format(startOfWeek)} - ${f.format(endOfWeek)})'
        : 'This Week (${f.format(startOfWeek)} - ${f.format(endOfWeek)})';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.isArabic ? 'تحديد النطاق الزمني للتحليلات' : 'Select Analytics Time Window',
              style: AppTypography.headlineSm(),
            ),
            const SizedBox(height: 14),
            ListTile(
              title: Text(weekLabel),
              subtitle: Text(state.isArabic ? 'يعرض فقط الجلسات التي تمت خلال الأسبوع الحالي' : 'Shows only sessions completed this current week'),
              trailing: state.selectedDateFilterIndex == 0 ? const Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () {
                state.setDateFilter(0);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: Text(state.isArabic ? 'آخر 30 يوماً' : 'Last 30 Days'),
              subtitle: Text(state.isArabic ? 'يعرض جميع الجلسات المنجزة في آخر شهر' : 'Shows all sessions completed in the last 30 days'),
              trailing: state.selectedDateFilterIndex == 1 ? const Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () {
                state.setDateFilter(1);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: Text(state.isArabic ? 'كامل السجل (جميع الجلسات)' : 'All Time (All Sessions)'),
              subtitle: Text(state.isArabic ? 'يعرض السجل التاريخي الكامل منذ إنشاء الحساب' : 'Shows complete historical records since registration'),
              trailing: state.selectedDateFilterIndex == 2 ? const Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () {
                state.setDateFilter(2);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPinSecurityDialog(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.security_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              state.isArabic ? 'حماية لوحة ولي الأمر' : 'Guardian PIN Security',
              style: AppTypography.labelMd(),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.isArabic
                  ? 'رمز المرور السري مفعّل حالياً لحماية تقارير الطالب التشخيصية ومنع التعديل غير المصرح به.'
                  : 'PIN protection is active to secure clinical analytics and prevent unauthorized setting alterations.',
              style: AppTypography.bodySm(),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_clock_rounded, color: Color(0xFF2563EB), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    state.isArabic ? 'حالة الحساب: محمي برمز المرور (الرمز: 1234)' : 'Security Status: Locked (PIN: 1234)',
                    style: AppTypography.labelSm(color: const Color(0xFF1E40AF)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(state.isArabic ? 'إغلاق' : 'Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return RefreshIndicator(
      onRefresh: () => state.refreshAnalytics(),
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: EdgeInsets.symmetric(
          horizontal: GuardianDashboardSizes.screenPaddingH,
          vertical: GuardianDashboardSizes.screenPaddingV,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Guardian Header Card (Student Info + Dynamic Date Filter + Export PDF)
            _buildGuardianHeaderCard(context, state),
            SizedBox(height: GuardianDashboardSizes.spacingSm),

            // 2. Fresh Account Guidance Banner (Shown if 0 sessions completed)
            if (state.totalSessionsCount == 0) ...[
              _buildNewLearnerGuidanceCard(context, state),
              SizedBox(height: GuardianDashboardSizes.spacingMd),
            ],

            // 3. Cognitive & Emotional State Card (Real-Time from DB)
            _buildCognitiveStateCard(context, state),
            SizedBox(height: GuardianDashboardSizes.spacingMd),

            // 4. Dyslexia & Reading Fluency Card (Real WPM Growth & Acoustic Profiling)
            _buildReadingFluencyCard(context, state),
            SizedBox(height: GuardianDashboardSizes.spacingMd),

            // 5. Dyscalculia & PyBKT Skill Tracing Card (Real Bayesian Mastery)
            _buildDyscalculiaCard(context, state),
            SizedBox(height: GuardianDashboardSizes.spacingMd),

            // 6. Parent Diagnostic Guide Card (Explains WPM, PyBKT, Frustration)
            _buildParentDiagnosticGuideCard(context, state),
            SizedBox(height: GuardianDashboardSizes.spacingMd),

            // 7. Recent Activity Feed (Chronological Live Sessions from DB)
            _buildRecentActivityFeedCard(context, state),
            SizedBox(height: GuardianDashboardSizes.spacingMd),

            // 8. Caregiver Actionable Insights Card
            _buildCaregiverInsightsCard(context, state),
            SizedBox(height: GuardianDashboardSizes.spacingMd),

            // 9. Accessibility Accommodations Toggles
            _buildAccessibilityAccommodations(context, state),
            SizedBox(height: GuardianDashboardSizes.spacingMd),

            // 10. Account & Session Management (Logout)
            _buildLogoutSection(context, state),
            SizedBox(height: GuardianDashboardSizes.spacingLg),
          ],
        ),
      ),
    );
  }

  Widget _buildGuardianHeaderCard(BuildContext context, AppState state) {
    return Container(
      padding: EdgeInsets.all(GuardianDashboardSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(GuardianDashboardSizes.cardRadius),
        border: Border.all(color: AppColors.borderLight, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: GuardianDashboardSizes.headerIconBoxSize,
                height: GuardianDashboardSizes.headerIconBoxSize,
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.verified_user_rounded,
                  color: AppColors.primary,
                  size: GuardianDashboardSizes.headerIconSize,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          state.studentName.isNotEmpty ? state.studentName : (state.isArabic ? 'المتعلم' : 'Learner'),
                          style: AppTypography.headlineSm(),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryFixed.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            state.tr('guardian_pin_active'),
                            style: AppTypography.labelSm(color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      state.isArabic
                          ? 'المستوى ${state.level} • الصف الثالث (دعم القراءة والحساب)'
                          : 'Level ${state.level} • Grade 3 (Dyslexia & Math Support)',
                      style: AppTypography.bodySm(color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _showPinSecurityDialog(context, state),
                child: Container(
                  width: GuardianDashboardSizes.lockBoxSize,
                  height: GuardianDashboardSizes.lockBoxSize,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.lock_rounded, color: Color(0xFF2563EB), size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Date Filter & PDF Export
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showDateFilterDialog(context, state),
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 15, color: AppColors.outline),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _getDateFilterLabel(state),
                            style: AppTypography.labelSm(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppColors.outline),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => PdfReportService.generateAndExportReport(context, state),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: AppColors.primaryShadow, offset: Offset(0, 2), blurRadius: 0),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(state.tr('btn_export_pdf'), style: AppTypography.labelSm(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNewLearnerGuidanceCard(BuildContext context, AppState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.explore_rounded, color: Color(0xFF16A34A), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.isArabic ? 'حساب جديد جاهز للتعلم' : 'New Learner Account Ready',
                      style: AppTypography.labelMd().copyWith(color: const Color(0xFF14532D)),
                    ),
                    Text(
                      state.isArabic ? 'لم تُسجل أي جلسات بعد - التحليلات تبدأ فورياً مع أول تمرين' : 'No sessions recorded yet - Analytics start with the first session',
                      style: AppTypography.bodySm(color: const Color(0xFF15803D)).copyWith(
                        fontSize: GuardianDashboardSizes.badgeFontSize,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            state.isArabic
                ? 'أهلاً بك في منصة تمكين! كافة مؤشرات سرعة القراءة ونموذج تتبع الحساب الذكي يتم احتسابها مباشرة من قاعدة البيانات بناءً على تفاعل طفلك الفعلي.'
                : 'Welcome to Tamkeen! All reading fluency (WPM) and math knowledge tracing (PyBKT) metrics are calculated dynamically from actual session attempts.',
            style: AppTypography.bodySm(color: const Color(0xFF166534)).copyWith(
              fontSize: GuardianDashboardSizes.bodyFontSize,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        state.isArabic ? '1. ابدأ بقراءة قصة المرحلة 12 لتفعيل رسم سرعة القراءة بالكلمة/دقيقة.' : '1. Start reading Stage 12 passage to activate WPM curve.',
                        style: AppTypography.labelSm(color: const Color(0xFF14532D)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        state.isArabic ? '2. حل أول معادلة في مختبر الحساب (المرحلة 15) لبدء تتبع استيعاب الرياضيات.' : '2. Solve the first equation in Math Lab to start PyBKT tracing.',
                        style: AppTypography.labelSm(color: const Color(0xFF14532D)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => state.setTabIndex(0),
              icon: const Icon(Icons.map_rounded, size: 18),
              label: Text(state.isArabic ? 'الذهاب إلى خريطة المغامرة والبدء' : 'Go to Adventure Map & Start'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCognitiveStateCard(BuildContext context, AppState state) {
    final hasData = state.totalSessionsCount > 0;
    final frustrationVal = state.frustrationPercent;
    final focusVal = state.focusPercent;
    final totalSessions = state.totalSessionsCount;
    final readingCount = state.readingSessionsCount;
    final mathCount = state.mathSessionsCount;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderLight, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.psychology_rounded, color: AppColors.primary, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.tr('cognitive_state'),
                            style: AppTypography.labelMd(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            state.tr('realtime_telemetry'),
                            style: AppTypography.labelSm(color: AppColors.outline),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(state.tr('calm_pacing'), style: AppTypography.labelSm(color: AppColors.onPrimaryFixed)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Frustration Index
          _buildTelemetryMetric(
            title: state.tr('frustration_index'),
            value: hasData
                ? '$frustrationVal% ${frustrationVal <= 30 ? (state.isArabic ? 'منخفض' : 'Low') : (state.isArabic ? 'متوسط' : 'Moderate')}'
                : (state.isArabic ? '0% هدوء تام' : '0% Calm & Resting'),
            sub: hasData
                ? (state.isArabic ? 'معدل الإحباط والتردد المحسوب من زمن وتكرار المحاولات' : 'Calculated from response times and retry patterns')
                : (state.isArabic ? 'لا توجد بيانات إحباط مسجلة (حساب جديد)' : 'No cognitive frustration recorded yet'),
            icon: Icons.sentiment_satisfied_alt_rounded,
            iconColor: AppColors.primary,
            bgColor: const Color(0xFFEFF6FF),
          ),
          const SizedBox(height: 10),

          // Focus & Joy State
          _buildTelemetryMetric(
            title: state.tr('focus_joy'),
            value: hasData
                ? (state.isArabic ? '$focusVal% تركيز مثالي' : '$focusVal% Flow')
                : (state.isArabic ? '100% جاهز للتعلم' : '100% Ready to Learn'),
            sub: hasData
                ? (state.isArabic ? 'معدل التركيز والانغماس المعرفي أثناء الحل' : 'High engagement and cognitive flow')
                : (state.isArabic ? 'حالة تركيز واستعداد ذهني مثالي لبدء التمرين' : 'Optimal baseline cognitive readiness'),
            icon: Icons.mood_rounded,
            iconColor: AppColors.tertiary,
            bgColor: const Color(0xFFFEF3C7),
          ),
          const SizedBox(height: 10),

          // Total Real Sessions Completed
          _buildTelemetryMetric(
            title: state.isArabic ? 'إجمالي الجلسات المنجزة' : 'Completed Sessions',
            value: hasData
                ? '$totalSessions ${state.isArabic ? 'جلسات فعلية' : 'Real Sessions'}'
                : (state.isArabic ? '0 جلسات فعلية' : '0 Real Sessions'),
            sub: hasData
                ? (state.isArabic ? '$readingCount قراءة بالذكاء الاصطناعي • $mathCount حساب' : '$readingCount Reading AI • $mathCount Math')
                : (state.isArabic ? 'بانتظار إنجاز أول تمرين في خريطة المغامرة' : 'Awaiting first exercise in Adventure Map'),
            icon: Icons.check_circle_outline_rounded,
            iconColor: AppColors.periwinkle,
            bgColor: const Color(0xFFF5F3FF),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryMetric({
    required String title,
    required String value,
    required String sub,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: EdgeInsets.all(GuardianDashboardSizes.metricPadding),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(GuardianDashboardSizes.metricRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.labelSm(color: AppColors.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, color: iconColor, size: 18),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.getLexend(
              fontSize: GuardianDashboardSizes.headerTitleFontSize,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: AppTypography.bodySm(color: AppColors.onSurfaceVariant).copyWith(
              fontSize: GuardianDashboardSizes.badgeFontSize,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingFluencyCard(BuildContext context, AppState state) {
    final points = state.wpmPoints;
    final hasReading = state.readingSessionsCount > 0 && points.isNotEmpty;

    return Container(
      padding: EdgeInsets.all(GuardianDashboardSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(GuardianDashboardSizes.cardRadius),
        border: Border.all(color: AppColors.borderLight, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.auto_stories_rounded, color: AppColors.secondary, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.tr('dyslexia_reading_fluency'),
                            style: AppTypography.labelMd(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            state.isArabic ? 'تحليل النطق الصوتي والطلاقة عبر الذكاء الاصطناعي' : 'Acoustic speech parsing & phonetics',
                            style: AppTypography.labelSm(color: AppColors.outline),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  hasReading ? (state.isArabic ? '${state.avgWpm} ك/د (المعدل)' : '${state.avgWpm} WPM Avg') : (state.isArabic ? '0 ك/د' : '0 WPM'),
                  style: AppTypography.labelSm(color: const Color(0xFF1D4ED8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // WPM Growth Line Visualization
          Text(state.tr('wpm_chart_title'), style: AppTypography.labelSm()),
          const SizedBox(height: 10),

          if (!hasReading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_stories_outlined, color: AppColors.outline, size: 30),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.isArabic ? 'لا توجد جلسات قراءة مسجلة بعد' : 'No Reading Sessions Recorded Yet',
                          style: AppTypography.labelSm(color: AppColors.onSurface),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          state.isArabic
                              ? 'سيبدأ رسم منحنى سرعة القراءة ومعدلات الدقة فور إكمال أول جلسة قراءة صوتية في المرحلة 12.'
                              : 'WPM growth progression will be plotted here dynamically once the student completes an AI reading session.',
                          style: AppTypography.bodySm(color: AppColors.outline).copyWith(
                            fontSize: GuardianDashboardSizes.badgeFontSize,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              height: 112,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: points.map((pt) {
                  final isLast = pt == points.last;
                  return _buildWpmBar(pt['label'] ?? '', (pt['wpm'] as num?)?.toInt() ?? 0, 180, isLatest: isLast);
                }).toList(),
              ),
            ),
          const SizedBox(height: 14),

          // Acoustic Error Profiling (Substitutions, Hesitations, Omissions)
          Text(state.tr('acoustic_error_profiling'), style: AppTypography.labelSm()),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildErrorChip(
                  state.tr('substitutions'),
                  hasReading ? '${state.substitutionsPct.toStringAsFixed(1)}%' : '0%',
                  hasReading ? (state.isArabic ? 'محسوب فعلياً' : 'Calibrated') : (state.isArabic ? 'بانتظار البدء' : 'Pending'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildErrorChip(
                  state.tr('hesitations'),
                  hasReading ? '${state.hesitationsPct.toStringAsFixed(1)}%' : '0%',
                  hasReading ? (state.isArabic ? 'محسوب فعلياً' : 'Calibrated') : (state.isArabic ? 'بانتظار البدء' : 'Pending'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildErrorChip(
                  state.tr('omissions'),
                  hasReading ? '${state.omissionsPct.toStringAsFixed(1)}%' : '0%',
                  hasReading ? (state.isArabic ? 'محسوب فعلياً' : 'Calibrated') : (state.isArabic ? 'بانتظار البدء' : 'Pending'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Phonetic Focus Note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hasReading ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: hasReading ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.spellcheck_rounded,
                  color: hasReading ? Colors.red : AppColors.outline,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasReading
                        ? (state.phoneticNotes.isNotEmpty
                            ? state.phoneticNotes
                            : (state.isArabic
                                ? 'تركيز صوتي: الحروف المتقاربة لفظاً والمدود الصوتية'
                                : 'Phonetic focus: Consonant blends and elongated vowels'))
                        : (state.isArabic
                            ? 'جاهز للمعايرة الصوتية: سيقوم الذكاء الاصطناعي برصد الحروف التي تتطلب تدريباً إضافياً فور تسجيل أول قراءة.'
                            : 'Awaiting first reading session to identify specific phonetic areas requiring practice.'),
                    style: AppTypography.bodySm(color: hasReading ? const Color(0xFF991B1B) : AppColors.onSurfaceVariant).copyWith(
                      fontSize: GuardianDashboardSizes.badgeFontSize,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWpmBar(String label, int value, int maxVal, {bool isLatest = false}) {
    final heightRatio = (value / maxVal).clamp(0.2, 1.0);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          style: AppTypography.getLexend(
            fontSize: GuardianDashboardSizes.captionFontSize,
            fontWeight: FontWeight.bold,
            color: isLatest ? AppColors.primary : AppColors.outline,
          ),
        ),
        const SizedBox(height: 3),
        Container(
          width: 14,
          height: 38 * heightRatio,
          decoration: BoxDecoration(
            color: isLatest ? AppColors.primaryContainer : AppColors.outlineVariant,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: AppTypography.labelSm(color: AppColors.onSurfaceVariant).copyWith(
            fontSize: GuardianDashboardSizes.microFontSize,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorChip(String title, String percent, String trend) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: AppTypography.getLexend(
              fontSize: GuardianDashboardSizes.captionFontSize,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E40AF),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            percent,
            style: AppTypography.getLexend(
              fontSize: GuardianDashboardSizes.metricValueFontSize,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1D4ED8),
            ),
          ),
          Text(
            trend,
            style: AppTypography.getLexend(
              fontSize: GuardianDashboardSizes.microFontSize,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF3B82F6),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDyscalculiaCard(BuildContext context, AppState state) {
    final breakdown = state.mathSkillsBreakdown;

    final s1 = breakdown['single_addition'];
    final s1Val = (s1?['mastery'] as num?)?.toDouble() ?? 0.0;
    final s1Count = (s1?['sessions'] as num?)?.toInt() ?? 0;

    final s2 = breakdown['tens_regrouping'];
    final s2Val = (s2?['mastery'] as num?)?.toDouble() ?? 0.0;
    final s2Count = (s2?['sessions'] as num?)?.toInt() ?? 0;

    final s3 = breakdown['number_line'];
    final s3Val = (s3?['mastery'] as num?)?.toDouble() ?? 0.0;
    final s3Count = (s3?['sessions'] as num?)?.toInt() ?? 0;

    final s4 = breakdown['multi_step'];
    final s4Val = (s4?['mastery'] as num?)?.toDouble() ?? 0.0;
    final s4Count = (s4?['sessions'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderLight, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.calculate_rounded, color: AppColors.tertiary, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(state.tr('dyscalculia_skill_tracing'), style: AppTypography.labelMd()),
                          Text(
                            state.tr('pybkt_sub'),
                            style: AppTypography.labelSm(color: AppColors.outline),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  state.tr('pybkt_badge'),
                  style: AppTypography.labelSm(color: const Color(0xFF0369A1)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Skill 1: Single-digit Addition
          _buildPyBktProgressBar(
            state.tr('skill_addition'),
            s1Val,
            s1Count > 0
                ? (state.isArabic
                    ? '${(s1Val * 100).toInt()}% تمكّن (الاحتمالية: ${s1Val.toStringAsFixed(2)})'
                    : '${(s1Val * 100).toInt()}% PyBKT (P_L = ${s1Val.toStringAsFixed(2)})')
                : (state.isArabic ? '0% (لم تبدأ بعد)' : '0% (Not Started)'),
            AppColors.primary,
            isZero: s1Count == 0,
          ),
          const SizedBox(height: 12),

          // Skill 2: Tens Regrouping
          _buildPyBktProgressBar(
            state.tr('skill_regrouping'),
            s2Val,
            s2Count > 0
                ? (state.isArabic
                    ? '${(s2Val * 100).toInt()}% تمكّن (الاحتمالية: ${s2Val.toStringAsFixed(2)})'
                    : '${(s2Val * 100).toInt()}% PyBKT (P_L = ${s2Val.toStringAsFixed(2)})')
                : (state.isArabic ? '0% (لم تبدأ بعد)' : '0% (Not Started)'),
            AppColors.primaryContainer,
            isZero: s2Count == 0,
          ),
          const SizedBox(height: 12),

          // Skill 3: Number Line
          _buildPyBktProgressBar(
            state.isArabic ? 'التقدير المكاني على خط الأعداد' : 'Number Line Spatial Estimation',
            s3Val,
            s3Count > 0
                ? (state.isArabic
                    ? '${(s3Val * 100).toInt()}% تمكّن (الاحتمالية: ${s3Val.toStringAsFixed(2)})'
                    : '${(s3Val * 100).toInt()}% PyBKT (P_L = ${s3Val.toStringAsFixed(2)})')
                : (state.isArabic ? '0% (لم تبدأ بعد)' : '0% (Not Started)'),
            AppColors.secondaryContainer,
            isZero: s3Count == 0,
          ),
          const SizedBox(height: 12),

          // Skill 4: Multi-step Equations
          _buildPyBktProgressBar(
            state.isArabic ? 'المعادلات الحسابية متعددة الخطوات' : 'Multi-step Story Equations',
            s4Val,
            s4Count > 0
                ? (state.isArabic
                    ? '${(s4Val * 100).toInt()}% تمكّن (الاحتمالية: ${s4Val.toStringAsFixed(2)})'
                    : '${(s4Val * 100).toInt()}% PyBKT (P_L = ${s4Val.toStringAsFixed(2)})')
                : (state.isArabic ? '0% (لم تبدأ بعد)' : '0% (Not Started)'),
            AppColors.tertiary,
            isZero: s4Count == 0,
          ),
        ],
      ),
    );
  }

  Widget _buildPyBktProgressBar(String title, double progress, String label, Color color, {bool isZero = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(title, style: AppTypography.labelSm(), maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.labelSm(color: isZero ? AppColors.outline : color).copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: AppColors.surfaceContainerHigh,
            valueColor: AlwaysStoppedAnimation<Color>(isZero ? AppColors.outlineVariant : color),
          ),
        ),
      ],
    );
  }

  Widget _buildParentDiagnosticGuideCard(BuildContext context, AppState state) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderLight, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.isArabic ? 'دليل ولي الأمر لفهم المؤشرات التشخيصية' : 'Guardian Diagnostic Metrics Guide',
                  style: AppTypography.labelMd(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            state.isArabic
                ? 'لمساعدتك في متابعة طفلك بدقة، إليك معاني المؤشرات الرئيسية وكيف يحللها النظام:'
                : 'To help you interpret clinical telemetry accurately, here is how each metric is calibrated:',
            style: AppTypography.bodySm(color: AppColors.onSurfaceVariant).copyWith(
              fontSize: GuardianDashboardSizes.bodyFontSize,
            ),
          ),
          const SizedBox(height: 12),

          _buildGuideItem(
            icon: Icons.speed_rounded,
            color: const Color(0xFF2563EB),
            title: state.isArabic ? 'مؤشر سرعة القراءة (كلمة/دقيقة)' : 'Words Per Minute (WPM)',
            desc: state.isArabic
                ? 'يقيس عدد الكلمات المقروءة في الدقيقة بدقة. المعدل الطبيعي لطلاب الصف الثالث هو 60-90 كلمة/دقيقة، ويفيد في قياس الطلاقة والاسترسال.'
                : 'Measures reading speed accurately. Grade 3 benchmark is 60-90 WPM, reflecting fluency and smooth decoding.',
          ),
          const SizedBox(height: 10),

          _buildGuideItem(
            icon: Icons.auto_awesome_rounded,
            color: const Color(0xFF0D9488),
            title: state.isArabic ? 'نموذج تتبع المعرفة البايزي المتطور' : 'Bayesian Knowledge Tracing (PyBKT)',
            desc: state.isArabic
                ? 'نموذج ذكاء اصطناعي يقدر احتمالية الإتقان الذهني الحقيقي للمفهوم الحسابي (بين 0.0 إلى 1.0) اعتماداً على زمن التفكير ونمط المحاولات.'
                : 'AI algorithm calculating latent mathematical concept mastery (0.0 to 1.0) based on response latency and retry sequences.',
          ),
          const SizedBox(height: 10),

          _buildGuideItem(
            icon: Icons.sentiment_satisfied_rounded,
            color: const Color(0xFFD97706),
            title: state.isArabic ? 'مؤشر الإحباط والتوتر السلوكي' : 'Behavioral Frustration Index',
            desc: state.isArabic
                ? 'يرصد مؤشرات التردد أو التوتر أثناء الحل، وعند ارتفاعه يقوم النظام تلقائياً بتفعيل التلميحات اللطيفة ووضع الهدوء التام.'
                : 'Monitors hesitation and cognitive stress signals to automatically engage gentle audio cues and Zen Timer.',
          ),
        ],
      ),
    );
  }

  Widget _buildGuideItem({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.labelSm(color: color).copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: AppTypography.bodySm(color: AppColors.onSurface).copyWith(
                    fontSize: GuardianDashboardSizes.badgeFontSize,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityFeedCard(BuildContext context, AppState state) {
    final logs = state.activityLogs;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderLight, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.history_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    state.isArabic ? 'سجل النشاطات والجلسات المباشرة' : 'Live Activity & Session History',
                    style: AppTypography.labelMd(),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${logs.length}',
                  style: AppTypography.labelSm(color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (logs.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(Icons.history_toggle_off_rounded, color: AppColors.outline, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    state.isArabic ? 'لا توجد جلسات مسجلة بعد في قاعدة البيانات' : 'No sessions recorded yet in Supabase',
                    style: AppTypography.labelSm(color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.isArabic
                        ? 'ستظهر كل جلسة قراءة أو حساب هنا تلقائياً بتوقيتها وتفاصيل نتائجها فور إنجازها.'
                        : 'Every reading or math session will appear here with timestamp and score upon completion.',
                    style: AppTypography.bodySm(color: AppColors.outline).copyWith(
                      fontSize: GuardianDashboardSizes.badgeFontSize,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: logs.length > 5 ? 5 : logs.length,
              separatorBuilder: (context, index) => const Divider(height: 16, color: AppColors.borderLight),
              itemBuilder: (context, index) {
                final item = logs[index];
                final isMath = item['type'] == 'math';
                final title = state.isArabic ? (item['title_ar'] ?? item['title']) : (item['title'] ?? '');
                final sub = state.isArabic ? (item['subtitle_ar'] ?? item['subtitle']) : (item['subtitle'] ?? '');
                String dateStr = '';
                if (item['created_at'] != null) {
                  try {
                    final dt = DateTime.parse(item['created_at'].toString()).toLocal();
                    dateStr = DateFormat('d MMM - hh:mm a').format(dt);
                    if (state.isArabic) {
                      dateStr = dateStr.replaceAll('AM', 'ص').replaceAll('PM', 'م');
                    }
                  } catch (_) {
                    dateStr = item['created_at'].toString();
                  }
                }

                return Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isMath ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isMath ? Icons.calculate_rounded : Icons.auto_stories_rounded,
                        color: isMath ? AppColors.tertiary : AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title.toString(),
                            style: AppTypography.labelSm(color: AppColors.onSurface),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            sub.toString(),
                            style: AppTypography.bodySm(color: AppColors.onSurfaceVariant).copyWith(
                              fontSize: GuardianDashboardSizes.badgeFontSize,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Builder(builder: (_) {
                            final rawScore = item['score']?.toString() ?? (state.isArabic ? 'مكتمل' : 'Done');
                            final scoreText = state.isArabic
                                ? (rawScore == 'Mastered'
                                    ? 'متقن'
                                    : (rawScore == 'Completed' || rawScore == 'Done'
                                        ? 'مكتمل'
                                        : rawScore.replaceAll('WPM', 'ك/د')))
                                : rawScore;
                            return Text(
                              scoreText,
                              style: AppTypography.labelSm(color: const Color(0xFF16A34A)).copyWith(
                                fontSize: GuardianDashboardSizes.captionFontSize,
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateStr,
                          style: AppTypography.bodySm(color: AppColors.outline).copyWith(
                            fontSize: GuardianDashboardSizes.microFontSize,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCaregiverInsightsCard(BuildContext context, AppState state) {
    final hasData = state.totalSessionsCount > 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderLight, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_rounded, color: AppColors.sunnyYellow, size: 22),
              const SizedBox(width: 8),
              Text(state.tr('caregiver_insights'), style: AppTypography.labelMd()),
            ],
          ),
          const SizedBox(height: 14),

          // Sensory Tip of Week
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.cookie_outlined, color: Color(0xFF2563EB), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(state.tr('sensory_tip_title'), style: AppTypography.labelSm(color: const Color(0xFF1E40AF))),
                      const SizedBox(height: 2),
                      Text(
                        hasData
                            ? state.tr('sensory_tip_body')
                            : (state.isArabic
                                ? 'شجع طفلك على القراءة بصوت واضح ومريح، واجعل وقت التعلم ممتعاً وقصيراً (10-15 دقيقة يومياً).'
                                : 'Encourage short, comfortable daily learning sessions (10-15 minutes) with gentle vocalization.'),
                        style: AppTypography.bodySm(color: const Color(0xFF1E3A8A)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Tamkeen Owl Bot
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.smart_toy_outlined, color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(state.tr('tamkeen_bot_title'), style: AppTypography.labelSm(color: AppColors.primary)),
                      const SizedBox(height: 2),
                      Text(
                        hasData
                            ? state.tr('tamkeen_bot_body')
                            : (state.isArabic
                                ? 'يقوم المساعد الذكي بتكييف التمارين تلقائياً لتعزيز ثقة الطفل بنفسه وتقديم تلميحات مرئية عند الحاجة.'
                                : 'Tamkeen AI assistant adapts challenges smoothly to build confidence and offer gentle visual scaffolds.'),
                        style: AppTypography.bodySm(color: const Color(0xFF14532D)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessibilityAccommodations(BuildContext context, AppState state) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderLight, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Text(state.tr('accessibility_accommodations'), style: AppTypography.labelMd()),
            ],
          ),
          const SizedBox(height: 14),

          // OpenDyslexic Heavy Font switch
          SwitchListTile(
            value: state.isDyslexicFont,
            onChanged: (_) => state.toggleDyslexicFont(),
            title: Text(state.tr('acc_opendyslexic'), style: AppTypography.labelSm()),
            subtitle: Text(state.tr('acc_opendyslexic_sub'), style: AppTypography.bodySm(color: AppColors.outline)),
            activeThumbColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(color: AppColors.borderLight),

          // Zen Mode switch
          SwitchListTile(
            value: state.isZenMode,
            onChanged: (_) => state.toggleZenMode(),
            title: Text(state.tr('acc_zen'), style: AppTypography.labelSm()),
            subtitle: Text(state.tr('acc_zen_sub'), style: AppTypography.bodySm(color: AppColors.outline)),
            activeThumbColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(color: AppColors.borderLight),

          // Audio-First Guidance switch
          SwitchListTile(
            value: true,
            onChanged: null,
            title: Text(state.tr('acc_audio_guidance'), style: AppTypography.labelSm()),
            subtitle: Text(state.tr('acc_audio_guidance_sub'), style: AppTypography.bodySm(color: AppColors.outline)),
            activeThumbColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(color: AppColors.borderLight),

          // Dynamic Font Scaling Controller
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.tr('font_size'),
                        style: AppTypography.labelSm().copyWith(
                          fontSize: GuardianDashboardSizes.cardTitleFontSize,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        state.fontSizeDelta == 0
                            ? state.tr('font_size_standard')
                            : (state.fontSizeDelta > 0
                                ? '${state.tr('font_size_large')} (+${state.fontSizeDelta.toInt()})'
                                : '${state.tr('font_size_small')} (${state.fontSizeDelta.toInt()})'),
                        style: AppTypography.bodySm(color: AppColors.outline).copyWith(
                          fontSize: GuardianDashboardSizes.captionFontSize,
                        ),
                      ),
                    ],
                  ),
                ),
                // A- Button
                IconButton.filledTonal(
                  onPressed: state.fontSizeDelta > -4.0 ? () => state.decreaseFontSize() : null,
                  icon: Text(state.isArabic ? 'أ-' : 'A-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  tooltip: state.tr('font_size_decrease'),
                ),
                const SizedBox(width: 6),
                // Reset Button if delta != 0
                if (state.fontSizeDelta != 0) ...[
                  IconButton.outlined(
                    onPressed: () => state.resetFontSize(),
                    icon: const Icon(Icons.restart_alt_rounded, size: 18),
                    tooltip: state.tr('font_size_reset'),
                  ),
                  const SizedBox(width: 6),
                ],
                // A+ Button
                IconButton.filled(
                  onPressed: state.fontSizeDelta < 8.0 ? () => state.increaseFontSize() : null,
                  icon: Text(state.isArabic ? 'أ+' : 'A+', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                  tooltip: state.tr('font_size_increase'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutSection(BuildContext context, AppState state) {
    return Container(
      padding: EdgeInsets.all(GuardianDashboardSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(GuardianDashboardSizes.cardRadius),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25), width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.logout_rounded, color: AppColors.error, size: GuardianDashboardSizes.logoutIconSize),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.tr('guardian_logout_title'),
                      style: AppTypography.labelMd().copyWith(
                        fontSize: GuardianDashboardSizes.cardTitleFontSize,
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      state.tr('guardian_logout_sub'),
                      style: AppTypography.bodySm(color: AppColors.outline).copyWith(
                        fontSize: GuardianDashboardSizes.captionFontSize,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: GuardianDashboardSizes.spacingSm),
          _buildAiServerCard(context, state),
          SizedBox(height: GuardianDashboardSizes.spacingSm),
          SizedBox(
            width: double.infinity,
            height: GuardianDashboardSizes.logoutButtonHeight,
            child: OutlinedButton.icon(
              onPressed: () => IntroTourService.startTour(context),
              icon: const Icon(Icons.help_outline_rounded, color: AppColors.primary),
              label: Text(
                state.tr('tour_guide_tooltip'),
                style: AppTypography.labelMd().copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.6), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(GuardianDashboardSizes.metricRadius),
                ),
                backgroundColor: AppColors.primary.withValues(alpha: 0.08),
              ),
            ),
          ),
          SizedBox(height: GuardianDashboardSizes.spacingSm),
          SizedBox(
            width: double.infinity,
            height: GuardianDashboardSizes.logoutButtonHeight,
            child: OutlinedButton.icon(
              onPressed: () => _confirmLogout(context, state),
              icon: const Icon(Icons.exit_to_app_rounded, color: AppColors.error),
              label: Text(
                state.tr('guardian_logout_btn'),
                style: AppTypography.labelMd().copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.error.withValues(alpha: 0.6), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(GuardianDashboardSizes.metricRadius),
                ),
                backgroundColor: AppColors.errorContainer.withValues(alpha: 0.15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiServerCard(BuildContext context, AppState state) {
    return FutureBuilder<String>(
      future: AIBridgeService.getBackendUrl(),
      builder: (ctx, snapshot) {
        final currentUrl = snapshot.data ?? AIBridgeService.defaultNgrokUrl;

        return Container(
          padding: EdgeInsets.all(GuardianDashboardSizes.metricPadding),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(GuardianDashboardSizes.metricRadius),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.25), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.cloud_sync_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.tr('guardian_server_title'),
                          style: AppTypography.labelMd().copyWith(
                            fontSize: GuardianDashboardSizes.cardTitleFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          state.tr('guardian_server_sub'),
                          style: AppTypography.bodySm(color: AppColors.onSurfaceVariant).copyWith(
                            fontSize: GuardianDashboardSizes.captionFontSize,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // URL display banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link_rounded, size: 16, color: Color(0xFF475569)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        currentUrl,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 16, color: AppColors.primary),
                      tooltip: state.tr('guardian_server_edit'),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _showEditServerDialog(context, state, currentUrl),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Action button: Test Connection
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => _testServerConnection(context, state, currentUrl),
                  icon: const Icon(Icons.wifi_tethering_rounded, size: 18),
                  label: Text(
                    state.tr('guardian_server_test_btn'),
                    style: AppTypography.labelSm().copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _testServerConnection(BuildContext context, AppState state, String url) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            const SizedBox(width: 12),
            Text(state.isArabic ? 'جارٍ فحص الاتصال بسيرفر ngrok...' : 'Testing connection to ngrok server...'),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    final res = await AIBridgeService.testConnection(url);
    if (!context.mounted) return;

    if (res['success'] == true) {
      final latency = res['latencyMs'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF16A34A),
          content: Text(
            state.isArabic
                ? '✅ متصل بنجاح بالسيرفر عبر ngrok! زمن الاستجابة: ${latency}ms'
                : '✅ Connected successfully via ngrok! Latency: ${latency}ms',
          ),
        ),
      );
    } else if (res['isNgrokWaiting'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFD97706),
          content: Text(
            state.isArabic
                ? '⚠️ نفق ngrok نشط، لكن سيرفر بايثون (localhost:8000) لم يتم تشغيله بعد. يرجى تشغيل run_server.bat'
                : '⚠️ ngrok tunnel is online, but python server (localhost:8000) is not started yet. Please run run_server.bat',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(
            state.isArabic
                ? '❌ تعذر الاتصال: ${res['message'] ?? 'تحقق من تشغيل ngrok'}'
                : '❌ Connection failed: ${res['message'] ?? 'Check ngrok status'}',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showEditServerDialog(BuildContext context, AppState state, String currentUrl) {
    final controller = TextEditingController(text: currentUrl);
    showDialog(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: state.textDirection,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(state.tr('guardian_server_edit'), style: AppTypography.headlineSm()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.isArabic
                    ? 'أدخل رابط ngrok الجديد كاملاً (مثال: https://xxxx.ngrok-free.dev):'
                    : 'Enter the new ngrok URL (e.g. https://xxxx.ngrok-free.dev):',
                style: AppTypography.bodySm(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.link_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  hintText: 'https://....ngrok-free.dev',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await AIBridgeService.setCustomBackendUrl(null);
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                setState(() {});
              },
              child: Text(state.tr('guardian_server_reset'), style: const TextStyle(color: AppColors.outline)),
            ),
            FilledButton(
              onPressed: () async {
                final newUrl = controller.text.trim();
                if (newUrl.isNotEmpty) {
                  await AIBridgeService.setCustomBackendUrl(newUrl);
                }
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                setState(() {});
              },
              child: Text(state.tr('guardian_server_save')),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: state.textDirection,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
              const SizedBox(width: 8),
              Text(state.tr('guardian_logout_dialog_title'), style: AppTypography.headlineSm()),
            ],
          ),
          content: Text(
            state.tr('guardian_logout_dialog_desc'),
            style: AppTypography.bodyMd(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(
                state.tr('guardian_logout_cancel'),
                style: AppTypography.labelMd(color: AppColors.outline),
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                state.logout();
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                state.tr('guardian_logout_confirm'),
                style: AppTypography.labelMd(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
