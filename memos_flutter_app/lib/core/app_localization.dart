import 'package:flutter/widgets.dart';

import '../state/preferences_provider.dart';

AppLanguage appLanguageFromLocale(Locale locale) {
  if (locale.languageCode.toLowerCase() == 'en') {
    return AppLanguage.en;
  }
  return AppLanguage.zhHans;
}

String trByLanguage({
  required AppLanguage language,
  required String zh,
  required String en,
}) {
  return language == AppLanguage.en ? en : zh;
}

String trByLocale({
  required Locale locale,
  required String zh,
  required String en,
}) {
  return locale.languageCode.toLowerCase() == 'en' ? en : zh;
}

extension AppLocalizationX on BuildContext {
  AppLanguage get appLanguage => appLanguageFromLocale(Localizations.localeOf(this));

  String tr({required String zh, required String en}) {
    return trByLocale(locale: Localizations.localeOf(this), zh: zh, en: en);
  }
}

extension NavigatorSafePopX on BuildContext {
  void safePop<T extends Object?>([T? result]) {
    final navigator = Navigator.maybeOf(this);
    if (navigator == null || !navigator.mounted || !navigator.canPop()) return;
    navigator.pop(result);
  }
}
