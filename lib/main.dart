import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'state/quote_state.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'models/quote_model.dart';
import 'models/material_item.dart';
import 'models/trade_category.dart';
import 'models/catalog_item.dart';

final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  
  await Hive.initFlutter();
  Hive.registerAdapter(TradeCategoryAdapter());
  Hive.registerAdapter(MaterialItemAdapter());
  Hive.registerAdapter(QuoteStatusAdapter());
  Hive.registerAdapter(QuoteModelAdapter());
  Hive.registerAdapter(CatalogItemAdapter());
  
  await Hive.openBox<QuoteModel>('quotes');
  await Hive.openBox('settings');
  await Hive.openBox<CatalogItem>('custom_materials');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => QuoteState()),
      ],
      child: const QuickQuoteApp(),
    ),
  );
}

class QuickQuoteApp extends StatelessWidget {
  const QuickQuoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<QuoteState>(
      builder: (context, state, child) {
        return MaterialApp(
          title: 'Pocket Quote',
          navigatorKey: globalNavigatorKey,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: state.themeMode,
          debugShowCheckedModeBanner: false,
          home: const CustomSplashScreen(),
        );
      },
    );
  }
}
