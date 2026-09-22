import 'package:flutter/material.dart';

/// Defines distinct stage content for reading and math challenges
class StageContent {
  final int stageId;
  final String realm; // 'words' or 'numbers'
  final String titleEn;
  final String titleAr;
  final String subtitleEn;
  final String subtitleAr;
  final IconData icon;

  // Reading specific
  final String textEn;
  final String textAr;
  final String discoveryWordEn;
  final String discoveryWordAr;
  final String discoveryMeaningEn;
  final String discoveryMeaningAr;
  final String soundBreakdownEn;
  final String soundBreakdownAr;

  // Math specific
  final int num1;
  final int num2;
  final String operation;
  final String expectedAnswer;
  final int tens1;
  final int ones1;
  final int tens2;
  final int ones2;
  final String tensRodsTextEn;
  final String tensRodsTextAr;
  final String onesCubesTextEn;
  final String onesCubesTextAr;
  final String nourHintEn;
  final String nourHintAr;
  final double minDrawingAccuracy;

  const StageContent({
    required this.stageId,
    required this.realm,
    required this.titleEn,
    required this.titleAr,
    required this.subtitleEn,
    required this.subtitleAr,
    required this.icon,
    this.textEn = '',
    this.textAr = '',
    this.discoveryWordEn = '',
    this.discoveryWordAr = '',
    this.discoveryMeaningEn = '',
    this.discoveryMeaningAr = '',
    this.soundBreakdownEn = '',
    this.soundBreakdownAr = '',
    this.num1 = 0,
    this.num2 = 0,
    this.operation = '+',
    this.expectedAnswer = '',
    this.tens1 = 0,
    this.ones1 = 0,
    this.tens2 = 0,
    this.ones2 = 0,
    this.tensRodsTextEn = '',
    this.tensRodsTextAr = '',
    this.onesCubesTextEn = '',
    this.onesCubesTextAr = '',
    this.nourHintEn = '',
    this.nourHintAr = '',
    this.minDrawingAccuracy = 0.50,
  });

  bool get isMath => realm == 'numbers';

  String title(bool isArabic) => isArabic ? titleAr : titleEn;
  String text(bool isArabic) => isArabic ? textAr : textEn;
  String subtitle(bool isArabic) => isArabic ? subtitleAr : subtitleEn;
  String discoveryWord(bool isArabic) => isArabic ? discoveryWordAr : discoveryWordEn;
  String discoveryMeaning(bool isArabic) => isArabic ? discoveryMeaningAr : discoveryMeaningEn;
  String soundBreakdown(bool isArabic) => isArabic ? soundBreakdownAr : soundBreakdownEn;
  String nourHint(bool isArabic) => isArabic ? nourHintAr : nourHintEn;
  String tensRodsText(bool isArabic) => isArabic ? tensRodsTextAr : tensRodsTextEn;
  String onesCubesText(bool isArabic) => isArabic ? onesCubesTextAr : onesCubesTextEn;
}

class StageRepository {
  static const Map<int, StageContent> stages = {
    // ----------------------------------------------------
    // Reading Track (12, 13, 14)
    // ----------------------------------------------------
    12: StageContent(
      stageId: 12,
      realm: 'words',
      titleEn: '12. Phonics Glade',
      titleAr: '12. واحة الأصوات',
      subtitleEn: 'Gentle phonics and letter melodies',
      subtitleAr: 'استمع لنغمات الحروف والأصوات الهادئة',
      icon: Icons.forest_rounded,
      textEn: 'The warm morning sun is rising. A little bird sings a joyful song upon the green branch.',
      textAr: 'شَمْسُ الصَّبَاحِ تُشْرِقُ بِدِفْءٍ. قَطْرَةُ النَّدَى تَلْمَعُ فَوْقَ وَرَقَةِ الشَّجَرِ الخَضْرَاءِ.',
      discoveryWordEn: 'Sunshine',
      discoveryWordAr: 'الشَّمْس',
      discoveryMeaningEn: 'Gentle light warming the world each dawn',
      discoveryMeaningAr: 'مصدر الدفء والضياء في بداية كل صباح',
      soundBreakdownEn: 's • u • n • s • h • i • n • e',
      soundBreakdownAr: 'ا • ل • شّ • مْ • س',
    ),
    13: StageContent(
      stageId: 13,
      realm: 'words',
      titleEn: '13. Syllable Springs',
      titleAr: '13. ينابيع المقاطع',
      subtitleEn: 'Blend syllables into flowing words',
      subtitleAr: 'اجمع المقاطع لتكوين كلمات سلسة وعذبة',
      icon: Icons.water_drop_rounded,
      textEn: 'Near the crystal spring, clear water flows over colorful stones. The river whispers tales of wonder.',
      textAr: 'قُرْبَ النَّبْعِ الصَّافِي، تَنْسَابُ المِيَاهُ العَذْبَةُ بَيْنَ الصُّخُورِ. وَتَشْدُو العَصَافِيرُ أَلْحَاناً جَمِيلَةً.',
      discoveryWordEn: 'Discovery',
      discoveryWordAr: 'الاسْتِكْشَاف',
      discoveryMeaningEn: 'Seeking to understand new and wonderful wonders',
      discoveryMeaningAr: 'الشغف بمعرفة أشياء جديدة وجميلة في الطبيعة',
      soundBreakdownEn: 'dis • cov • er • y',
      soundBreakdownAr: 'اِسْ • تِكْ • شَا • ف',
    ),
    14: StageContent(
      stageId: 14,
      realm: 'words',
      titleEn: '14. Echo Cavern',
      titleAr: '14. كهف الصدى',
      subtitleEn: 'Expressive rhythm and confident reading',
      subtitleAr: 'اقرأ بطلاقة ونبرة تعبيرية واثقة',
      icon: Icons.waves_rounded,
      textEn: 'The gentle ocean breeze whispered secrets to the ancient lighthouse standing proudly against the twilight sky.',
      textAr: 'هَمَسَ نَسِيمُ البَحْرِ الهَادِئُ بِأَسْرَارِهِ لِلْمَنَارَةِ العَتِيقَةِ الشَّامِخَةِ أَمَامَ سَمَاءِ الغُرُوبِ.',
      discoveryWordEn: 'Courage',
      discoveryWordAr: 'الشَّجَاعَة',
      discoveryMeaningEn: 'Inner strength to read and explore with pride',
      discoveryMeaningAr: 'القوة والثقة بالنفس عند خوض المغامرة والتحدي',
      soundBreakdownEn: 'cou • rage',
      soundBreakdownAr: 'شَ • جَـا • عَـ • ة',
    ),

    // ----------------------------------------------------
    // Math Track (15, 16, 17, 18) - Progressive Drawing Accuracy
    // ----------------------------------------------------
    15: StageContent(
      stageId: 15,
      realm: 'numbers',
      titleEn: '15. Equation Fortress',
      titleAr: '15. قلعة المعادلات',
      subtitleEn: 'Direct two-digit addition • Target: 50%',
      subtitleAr: 'جمع الآحاد والعشرات • دقة الرسم: 50%',
      icon: Icons.castle_rounded,
      num1: 14,
      num2: 15,
      operation: '+',
      expectedAnswer: '29',
      tens1: 1,
      ones1: 4,
      tens2: 1,
      ones2: 5,
      minDrawingAccuracy: 0.50,
      tensRodsTextEn: 'Tens Rods (1 + 1 = 2 tens = 20)',
      tensRodsTextAr: 'أعمدة العشرات (عشرة واحدة + عشرة واحدة = عشرتان = 20)',
      onesCubesTextEn: 'Ones Cubes (4 + 5 = 9 ones)',
      onesCubesTextAr: 'مكعبات الآحاد (4 آحاد + 5 آحاد = 9 آحاد)',
      nourHintEn: 'Step 1: Add tens first: 10 + 10 = 20. Then add ones: 4 + 5 = 9. Total is 29!',
      nourHintAr: 'الخطوة 1: اجمع العشرات أولاً: 10 + 10 = 20، ثم اجمع الآحاد: 4 + 5 = 9، الناتج هو 29!',
    ),
    16: StageContent(
      stageId: 16,
      realm: 'numbers',
      titleEn: '16. Regrouping Quest',
      titleAr: '16. مهمة إعادة التجميع',
      subtitleEn: 'Group ones into a new glowing ten • Target: 65%',
      subtitleAr: 'إعادة تجميع الآحاد • دقة الرسم: 65%',
      icon: Icons.extension_rounded,
      num1: 45,
      num2: 28,
      operation: '+',
      expectedAnswer: '73',
      tens1: 4,
      ones1: 5,
      tens2: 2,
      ones2: 8,
      minDrawingAccuracy: 0.65,
      tensRodsTextEn: 'Tens Rods (4 + 2 = 6 tens)',
      tensRodsTextAr: 'أعمدة العشرات (4 + 2 = 6 عشرات)',
      onesCubesTextEn: 'Ones Cubes (5 + 8 = 13 ones → 1 ten + 3 ones)',
      onesCubesTextAr: 'مكعبات الآحاد (5 + 8 = 13 آحاد → عشرة واحدة و 3 آحاد)',
      nourHintEn: '5 + 8 = 13. Put 3 in the ones place and carry 1 to the tens column (40 + 20 + 10 = 70). Total: 73!',
      nourHintAr: '5 + 8 = 13 آحاد. نضع 3 في خانة الآحاد ونرفع 1 مع العشرات (4 + 2 + 1 = 7 عشرات)، الناتج هو 73!',
    ),
    17: StageContent(
      stageId: 17,
      realm: 'numbers',
      titleEn: '17. Time Portal',
      titleAr: '17. بوابة الحساب المتقدمة',
      subtitleEn: 'Two-digit subtraction with borrowing • Target: 75%',
      subtitleAr: 'طرح العشرات والآحاد بالاستلاف • دقة الرسم: 75%',
      icon: Icons.timer_rounded,
      num1: 52,
      num2: 18,
      operation: '-',
      expectedAnswer: '34',
      tens1: 5,
      ones1: 2,
      tens2: 1,
      ones2: 8,
      minDrawingAccuracy: 0.75,
      tensRodsTextEn: 'Borrow 1 ten so 2 ones becomes 12 ones',
      tensRodsTextAr: 'نستلف عشرة واحدة لتصبح الآحاد 12 بدلاً من 2',
      onesCubesTextEn: '12 - 8 = 4 ones, and 4 tens - 1 ten = 3 tens',
      onesCubesTextAr: '12 - 8 = 4 آحاد، و 4 عشرات - عشرة واحدة = 3 عشرات',
      nourHintEn: 'Since 2 < 8, borrow 10: 12 - 8 = 4 ones, and 40 - 10 = 30 tens. Result is 34!',
      nourHintAr: 'بما أن 2 أصغر من 8، نستلف 10 من الخمسين: 12 - 8 = 4 آحاد، و 40 - 10 = 30، الناتج هو 34!',
    ),
    18: StageContent(
      stageId: 18,
      realm: 'numbers',
      titleEn: '18. Master Equation',
      titleAr: '18. عرش العباقرة',
      subtitleEn: 'Ultimate precision challenge • Target: 85%',
      subtitleAr: 'تحدي الدقة الفائقة • دقة الرسم: 85%',
      icon: Icons.military_tech_rounded,
      num1: 38,
      num2: 26,
      operation: '+',
      expectedAnswer: '64',
      tens1: 3,
      ones1: 8,
      tens2: 2,
      ones2: 6,
      minDrawingAccuracy: 0.85,
      tensRodsTextEn: 'Tens Rods (3 + 2 = 5 tens + 1 carried ten = 60)',
      tensRodsTextAr: 'أعمدة العشرات (3 + 2 = 5 عشرات + عشرة محمولة = 60)',
      onesCubesTextEn: 'Ones Cubes (8 + 6 = 14 ones → 4 ones + 1 ten)',
      onesCubesTextAr: 'مكعبات الآحاد (8 + 6 = 14 آحاد → 4 آحاد وعشرة واحدة)',
      nourHintEn: '8 + 6 = 14 (put 4, carry 1). 30 + 20 + 10 = 60. Final answer is 64! Draw 64 with high precision!',
      nourHintAr: '8 + 6 = 14 (نضع 4 ونرفع 1). 30 + 20 + 10 = 60. الناتج النهائي هو 64! ارسم 64 بدقة فائقة!',
    ),
  };

  static StageContent getStage(int stageId) {
    return stages[stageId] ?? stages[12]!;
  }
}
