import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'data/restaurant_catalog.dart';
import 'main_navigation_screen.dart';
import 'services/local_storage_service.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await LocalStorageService.create();
  runApp(DekkFoodApp(storage: storage));
}

class DekkFoodApp extends StatefulWidget {
  const DekkFoodApp({super.key, required this.storage});

  final LocalStorageService storage;

  @override
  State<DekkFoodApp> createState() => _DekkFoodAppState();
}

class _DekkFoodAppState extends State<DekkFoodApp> {
  late final AppState _appState;

  @override
  void initState() {
    super.initState();
    _appState = AppState(widget.storage);
  }

  @override
  void dispose() {
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DEKK FOOD - Sénégal',
      debugShowCheckedModeBanner: false,
      theme: buildDekkTheme(Brightness.light),
      darkTheme: buildDekkTheme(Brightness.dark),
      themeMode: ThemeMode.light,
      builder: (context, child) => AppScope(
        state: _appState,
        child: child ?? const SizedBox.shrink(),
      ),
      home: MainNavigationScreen(restaurants: RestaurantCatalog.all),
    );
  }
}
