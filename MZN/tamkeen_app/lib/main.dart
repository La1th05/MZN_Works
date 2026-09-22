import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'core/services/supabase_service.dart';
import 'core/state/app_state.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase Cloud Database
  await SupabaseService.initialize();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: const TamkeenApp(),
    ),
  );
}

class TamkeenApp extends StatelessWidget {
  const TamkeenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, deviceType) {
        return MaterialApp(
          title: 'Tamkeen: Learning Adventure',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: Consumer<AppState>(
            builder: (context, state, _) {
              return state.isAuthenticated ? const MainShell() : const LoginScreen();
            },
          ),
        );
      },
    );
  }
}
