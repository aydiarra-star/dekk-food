import 'package:flutter/widgets.dart';

import 'state/app_state.dart';

/// Accès léger aux modèles de session, disponible dans toutes les routes.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.state,
    required super.child,
  });

  final AppState state;

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope est requis au-dessus de cette route.');
    return scope!.state;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => oldWidget.state != state;
}
