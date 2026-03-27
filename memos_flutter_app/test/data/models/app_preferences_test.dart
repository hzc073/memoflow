import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/models/app_preferences.dart';

void main() {
  test('disables third-party share by default', () {
    expect(AppPreferences.defaults.thirdPartyShareEnabled, isFalse);
  });

  test('confirms exit on back by default', () {
    expect(AppPreferences.defaults.confirmExitOnBack, isTrue);
  });

  test('ignores legacy supporter crown field when reading preferences', () {
    final json = <String, dynamic>{
      ...AppPreferences.defaultsForLanguage(AppLanguage.en).toJson(),
      'supporterCrownEnabled': true,
    };

    final parsed = AppPreferences.fromJson(json);

    expect(parsed.language, AppLanguage.en);
    expect(parsed.toJson().containsKey('supporterCrownEnabled'), isFalse);
  });
}
