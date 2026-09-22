import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/state/app_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/tactile_button.dart';
import '../login_sizes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isSignUpMode = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _selectedRole = 'Student';
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  List<Map<String, dynamic>> _cloudProfiles = [];
  bool _isLoadingProfiles = true;

  @override
  void initState() {
    super.initState();
    _loadCloudProfiles();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadCloudProfiles() async {
    setState(() => _isLoadingProfiles = true);
    final profiles = await SupabaseService.fetchAllProfiles();
    if (mounted) {
      setState(() {
        _cloudProfiles = profiles;
        _isLoadingProfiles = false;
      });
    }
  }

  Future<void> _handleQuickLogin(AppState state, Map<String, dynamic> account) async {
    setState(() => _isLoading = true);
    await state.switchProfile(
      profileId: account['id'] ?? '',
      name: account['student_name'] ?? (state.isArabic ? 'المتعلم' : 'Learner'),
      stars: account['stars'] ?? 0,
      role: account['role'] ?? 'Student',
      level: account['level'] ?? 1,
      xp: account['xp'] ?? 0,
      streakDays: account['streak_days'] ?? 1,
    );
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handleEmailLogin(AppState state) async {
    final email = _emailController.text.trim();
    final pass = _passwordController.text.trim();
    if (email.isEmpty) {
      _showFeedback(state.isArabic ? 'يرجى إدخال البريد الإلكتروني' : 'Please enter your email');
      return;
    }
    if (pass.isEmpty) {
      _showFeedback(state.isArabic ? 'يرجى إدخال كلمة المرور' : 'Please enter your password');
      return;
    }

    setState(() => _isLoading = true);
    final error = await state.loginWithEmail(email: email, password: pass);
    if (mounted) {
      setState(() => _isLoading = false);
      if (error == 'user_not_found') {
        _showFeedback(
          state.isArabic
              ? 'البريد الإلكتروني غير مسجل، يرجى إنشاء حساب جديد'
              : 'Email not registered, please create an account',
        );
      } else if (error == 'wrong_password') {
        _showFeedback(
          state.isArabic
              ? 'كلمة المرور غير صحيحة، يرجى المحاولة مرة أخرى'
              : 'Incorrect password, please try again',
        );
      }
    }
  }

  Future<void> _handleSignUp(AppState state) async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final pass = _passwordController.text.trim();
    if (name.isEmpty) {
      _showFeedback(state.isArabic ? 'يرجى إدخال اسم الطالب / المستخدم' : 'Please enter student name');
      return;
    }
    if (email.isEmpty) {
      _showFeedback(state.isArabic ? 'يرجى إدخال البريد الإلكتروني' : 'Please enter email address');
      return;
    }
    if (pass.isEmpty) {
      _showFeedback(state.isArabic ? 'يرجى إدخال كلمة المرور' : 'Please enter password');
      return;
    }

    setState(() => _isLoading = true);
    await state.registerAndLogin(
      name: name,
      email: email,
      role: _selectedRole,
      password: pass,
    );
    if (mounted) setState(() => _isLoading = false);
  }

  void _showFeedback(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Directionality(
      textDirection: state.textDirection,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: LoginSizes.screenPaddingH, vertical: LoginSizes.screenPaddingV),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo
                Container(
                  width: LoginSizes.logoSize,
                  height: LoginSizes.logoSize,
                  padding: EdgeInsets.all(LoginSizes.spacingXs),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(LoginSizes.logoRadius),
                    color: Colors.white,
                    border: Border.all(color: AppColors.primaryContainer, width: LoginSizes.logoBorderWidth),
                    boxShadow: const [
                      BoxShadow(color: Color(0x14006A62), blurRadius: 16, offset: Offset(0, 6)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(LoginSizes.logoRadius > 4 ? LoginSizes.logoRadius - 4 : LoginSizes.logoRadius),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(Icons.school, size: LoginSizes.logoIconSize, color: AppColors.primary),
                    ),
                  ),
                ),
                SizedBox(height: LoginSizes.spacingMd),

                Text(
                  state.isArabic ? 'مرحباً بك في تمكين' : 'Welcome to Tamkeen',
                  style: AppTypography.getLexend(fontSize: LoginSizes.titleFontSize, fontWeight: FontWeight.w800, color: AppColors.primary),
                ),
                SizedBox(height: LoginSizes.spacingXs),
                Text(
                  state.isArabic
                      ? 'مغامرة التعلم الذكية لتمكين القراءة والرياضيات'
                      : 'Accessible Learning Adventure for Dyslexia & Math',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySm(color: AppColors.onSurfaceVariant),
                ),
                SizedBox(height: LoginSizes.spacingMd),

                // Language Toggle Pill
                GestureDetector(
                  onTap: () => state.toggleLanguage(),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: LoginSizes.langPillPaddingH, vertical: LoginSizes.langPillPaddingV),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(LoginSizes.langPillRadius),
                      border: Border.all(color: AppColors.outlineVariant),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.language_rounded, size: LoginSizes.langPillIconSize, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          state.isArabic ? 'اللغة: العربية' : 'Language: English',
                          style: AppTypography.labelSm(color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: LoginSizes.spacingLg),

                // Auth Mode Switcher (Login vs Sign Up)
                Container(
                  padding: EdgeInsets.all(LoginSizes.switcherPadding),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(LoginSizes.switcherRadius),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isSignUpMode = false),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: LoginSizes.switcherItemPaddingV),
                            decoration: BoxDecoration(
                              color: !_isSignUpMode ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(LoginSizes.switcherItemRadius),
                              boxShadow: !_isSignUpMode
                                   ? const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              state.isArabic ? 'تسجيل الدخول' : 'Sign In',
                              style: AppTypography.labelMd(
                                color: !_isSignUpMode ? AppColors.primary : AppColors.outline,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isSignUpMode = true),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: LoginSizes.switcherItemPaddingV),
                            decoration: BoxDecoration(
                              color: _isSignUpMode ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(LoginSizes.switcherItemRadius),
                              boxShadow: _isSignUpMode
                                  ? const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              state.isArabic ? 'حساب جديد' : 'New Account',
                              style: AppTypography.labelMd(
                                color: _isSignUpMode ? AppColors.primary : AppColors.outline,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: LoginSizes.spacingLg),

                if (!_isSignUpMode) ...[
                  // Dynamic Registered Cloud Profiles
                  Container(
                    padding: EdgeInsets.all(LoginSizes.cardPadding),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(LoginSizes.cardRadius),
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
                              child: Text(
                                state.isArabic ? 'الحسابات المسجلة في السحابة' : 'Registered Cloud Profiles',
                                style: AppTypography.headlineSm(),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.primary),
                              onPressed: _isLoadingProfiles ? null : _loadCloudProfiles,
                              tooltip: 'Refresh',
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        if (_isLoadingProfiles)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: CircularProgressIndicator(color: AppColors.primary),
                            ),
                          )
                        else if (_cloudProfiles.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Center(
                              child: Text(
                                state.isArabic
                                    ? 'لا توجد حسابات مسجلة بعد، أنشئ حسابك الجديد للبدء!'
                                    : 'No registered accounts yet. Create a new account to start!',
                                textAlign: TextAlign.center,
                                style: AppTypography.bodySm(color: AppColors.onSurfaceVariant),
                              ),
                            ),
                          )
                        else
                          ..._cloudProfiles.map((acc) {
                            final name = acc['student_name'] ?? 'User';
                            final role = acc['role'] ?? 'Student';
                            final stars = acc['stars'] ?? 0;
                            final level = acc['level'] ?? 1;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: InkWell(
                                onTap: _isLoading ? null : () => _handleQuickLogin(state, acc),
                                borderRadius: BorderRadius.circular(LoginSizes.profileItemRadius),
                                child: Container(
                                  padding: EdgeInsets.all(LoginSizes.profileItemPadding),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(LoginSizes.profileItemRadius),
                                    border: Border.all(color: AppColors.borderLight),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: LoginSizes.avatarRadius,
                                        backgroundColor: AppColors.primaryContainer,
                                        child: Icon(Icons.person, color: Colors.white, size: LoginSizes.avatarIconSize),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: AppTypography.labelMd(),
                                            ),
                                            Text(
                                              state.isArabic
                                                  ? '${role == 'Student' ? 'طالب' : (role == 'Guardian' || role == 'Parent' ? 'ولي أمر' : role)} • المستوى $level'
                                                  : '$role • Level $level',
                                              style: AppTypography.bodySm().copyWith(fontSize: LoginSizes.captionFontSize),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (stars > 0)
                                        Row(
                                          children: [
                                            Icon(Icons.star_rounded, color: AppColors.sunnyYellow, size: LoginSizes.starIconSize),
                                            Text('$stars', style: AppTypography.labelSm()),
                                          ],
                                        ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.outline),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                  SizedBox(height: LoginSizes.spacingMd),

                  // Standard Email Login Option
                  Container(
                    padding: EdgeInsets.all(LoginSizes.cardPadding),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(LoginSizes.cardRadius),
                      border: Border.all(color: AppColors.borderLight, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.isArabic ? 'أو تسجيل الدخول بالبريد' : 'Or Sign in with Email',
                          style: AppTypography.labelMd(),
                        ),
                        SizedBox(height: LoginSizes.spacingSm),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: state.isArabic ? 'البريد الإلكتروني' : 'Email Address',
                            prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primary),
                            filled: true,
                            fillColor: AppColors.surfaceContainerLow,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(LoginSizes.inputRadius),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        SizedBox(height: LoginSizes.spacingSm),
                        TextField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          decoration: InputDecoration(
                            hintText: state.isArabic ? 'كلمة المرور' : 'Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.primary),
                            suffixIcon: IconButton(
                              icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                            ),
                            filled: true,
                            fillColor: AppColors.surfaceContainerLow,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(LoginSizes.inputRadius),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        SizedBox(height: LoginSizes.spacingMd),
                        TactileButton(
                          label: _isLoading
                              ? (state.isArabic ? 'جارٍ التحقق...' : 'Authenticating...')
                              : (state.isArabic ? 'دخول لحسابي' : 'Login to My Account'),
                          variant: TactileButtonVariant.primary,
                          height: LoginSizes.buttonHeight,
                          onPressed: _isLoading ? null : () => _handleEmailLogin(state),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Create New Account Form
                  Container(
                    padding: EdgeInsets.all(LoginSizes.cardPadding),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(LoginSizes.cardRadius),
                      border: Border.all(color: AppColors.borderLight, width: 1.5),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.isArabic ? 'إنشاء حساب جديد من الصفر' : 'Create New Account from Scratch',
                          style: AppTypography.headlineSm(),
                        ),
                        SizedBox(height: LoginSizes.spacingXs),
                        Text(
                          state.isArabic
                              ? 'سجل حسابك لتبدأ المغامرة بـ 0 نجوم والمستوى 1'
                              : 'Register to start your adventure with 0 stars & Level 1',
                          style: AppTypography.bodySm(color: AppColors.onSurfaceVariant).copyWith(fontSize: LoginSizes.captionFontSize),
                        ),
                        SizedBox(height: LoginSizes.spacingMd),

                        // Name Field
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: state.isArabic ? 'اسم الطالب / المستخدم' : 'Student / User Name',
                            prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.primary),
                            filled: true,
                            fillColor: AppColors.surfaceContainerLow,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(LoginSizes.inputRadius),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        SizedBox(height: LoginSizes.spacingSm),

                        // Email Field
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: state.isArabic ? 'البريد الإلكتروني' : 'Email Address',
                            prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primary),
                            filled: true,
                            fillColor: AppColors.surfaceContainerLow,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(LoginSizes.inputRadius),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        SizedBox(height: LoginSizes.spacingSm),

                        // Password Field
                        TextField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          decoration: InputDecoration(
                            labelText: state.isArabic ? 'كلمة المرور' : 'Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.primary),
                            suffixIcon: IconButton(
                              icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                            ),
                            filled: true,
                            fillColor: AppColors.surfaceContainerLow,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(LoginSizes.inputRadius),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        SizedBox(height: LoginSizes.spacingSm),

                        // Role Selector
                        Text(
                          state.isArabic ? 'نوع الحساب:' : 'Account Role:',
                          style: AppTypography.labelSm(),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedRole = 'Student'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _selectedRole == 'Student'
                                        ? AppColors.primaryFixed
                                        : AppColors.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _selectedRole == 'Student'
                                          ? AppColors.primaryContainer
                                          : AppColors.outlineVariant,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    state.isArabic ? 'طالب' : 'Student',
                                    style: AppTypography.labelSm(
                                      color: _selectedRole == 'Student' ? AppColors.primary : AppColors.outline,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedRole = 'Guardian'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _selectedRole == 'Guardian'
                                        ? AppColors.primaryFixed
                                        : AppColors.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _selectedRole == 'Guardian'
                                          ? AppColors.primaryContainer
                                          : AppColors.outlineVariant,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    state.isArabic ? 'ولي أمر' : 'Guardian',
                                    style: AppTypography.labelSm(
                                      color: _selectedRole == 'Guardian' ? AppColors.primary : AppColors.outline,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: LoginSizes.spacingMd),

                        TactileButton(
                          label: _isLoading
                              ? (state.isArabic ? 'جارٍ إنشاء الحساب...' : 'Creating Account...')
                              : (state.isArabic ? 'إنشاء الحساب وبدء المغامرة' : 'Create Account & Start'),
                          variant: TactileButtonVariant.secondary,
                          height: LoginSizes.buttonHeight,
                          onPressed: _isLoading ? null : () => _handleSignUp(state),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}
