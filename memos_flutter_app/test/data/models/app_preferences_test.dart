import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/models/app_preferences.dart';
import 'package:memos_flutter_app/features/memos/home_quick_actions.dart';

void main() {
  group('AppPreferences home quick actions', () {
    test('uses default quick actions when keys are missing', () {
      final prefs = AppPreferences.fromJson(<String, dynamic>{});

      expect(prefs.homeQuickActionPrimary, HomeQuickAction.monthlyStats);
      expect(prefs.homeQuickActionSecondary, HomeQuickAction.aiSummary);
      expect(prefs.homeQuickActionTertiary, HomeQuickAction.dailyReview);
    });

    test('falls back to defaults for invalid quick action values', () {
      final prefs = AppPreferences.fromJson(<String, dynamic>{
        'homeQuickActionPrimary': 'invalid',
        'homeQuickActionSecondary': 'bad',
        'homeQuickActionTertiary': 'oops',
      });

      expect(prefs.homeQuickActionPrimary, HomeQuickAction.monthlyStats);
      expect(prefs.homeQuickActionSecondary, HomeQuickAction.aiSummary);
      expect(prefs.homeQuickActionTertiary, HomeQuickAction.dailyReview);
    });

    test('serializes quick actions as enum names', () {
      final prefs = AppPreferences.defaults.copyWith(
        homeQuickActionPrimary: HomeQuickAction.explore,
        homeQuickActionSecondary: HomeQuickAction.notifications,
        homeQuickActionTertiary: HomeQuickAction.resources,
      );

      final json = prefs.toJson();

      expect(json['homeQuickActionPrimary'], 'explore');
      expect(json['homeQuickActionSecondary'], 'notifications');
      expect(json['homeQuickActionTertiary'], 'resources');
    });

    test('parses hidden quick action values', () {
      final prefs = AppPreferences.fromJson(<String, dynamic>{
        'homeQuickActionPrimary': 'none',
        'homeQuickActionSecondary': 'monthlyStats',
        'homeQuickActionTertiary': 'none',
      });

      expect(prefs.homeQuickActionPrimary, HomeQuickAction.none);
      expect(prefs.homeQuickActionSecondary, HomeQuickAction.monthlyStats);
      expect(prefs.homeQuickActionTertiary, HomeQuickAction.none);
    });

    test('copyWith overrides only requested quick action slots', () {
      final base = AppPreferences.defaults;
      final next = base.copyWith(
        homeQuickActionPrimary: HomeQuickAction.archived,
      );

      expect(next.homeQuickActionPrimary, HomeQuickAction.archived);
      expect(next.homeQuickActionSecondary, base.homeQuickActionSecondary);
      expect(next.homeQuickActionTertiary, base.homeQuickActionTertiary);
    });
  });

  group('resolveHomeQuickActions', () {
    test('keeps the default trio when already valid', () {
      final resolved = resolveHomeQuickActions(
        rawPrimary: HomeQuickAction.monthlyStats,
        rawSecondary: HomeQuickAction.aiSummary,
        rawTertiary: HomeQuickAction.dailyReview,
        hasAccount: false,
      );

      expect(resolved, const [
        HomeQuickAction.monthlyStats,
        HomeQuickAction.aiSummary,
        HomeQuickAction.dailyReview,
      ]);
    });

    test('deduplicates repeated actions and fills remaining slots', () {
      final resolved = resolveHomeQuickActions(
        rawPrimary: HomeQuickAction.aiSummary,
        rawSecondary: HomeQuickAction.aiSummary,
        rawTertiary: HomeQuickAction.aiSummary,
        hasAccount: true,
      );

      expect(resolved, const [
        HomeQuickAction.aiSummary,
        HomeQuickAction.monthlyStats,
        HomeQuickAction.dailyReview,
      ]);
    });

    test('replaces unavailable account-only actions in local mode', () {
      final resolved = resolveHomeQuickActions(
        rawPrimary: HomeQuickAction.explore,
        rawSecondary: HomeQuickAction.notifications,
        rawTertiary: HomeQuickAction.resources,
        hasAccount: false,
      );

      expect(resolved, const [
        HomeQuickAction.monthlyStats,
        HomeQuickAction.aiSummary,
        HomeQuickAction.resources,
      ]);
    });

    test('prefers slot default before global fill order', () {
      final resolved = resolveHomeQuickActions(
        rawPrimary: HomeQuickAction.monthlyStats,
        rawSecondary: HomeQuickAction.monthlyStats,
        rawTertiary: HomeQuickAction.monthlyStats,
        hasAccount: true,
      );

      expect(resolved, const [
        HomeQuickAction.monthlyStats,
        HomeQuickAction.aiSummary,
        HomeQuickAction.dailyReview,
      ]);
    });

    test(
      'restores account-only preferences when account becomes available',
      () {
        final resolved = resolveHomeQuickActions(
          rawPrimary: HomeQuickAction.explore,
          rawSecondary: HomeQuickAction.notifications,
          rawTertiary: HomeQuickAction.resources,
          hasAccount: true,
        );

        expect(resolved, const [
          HomeQuickAction.explore,
          HomeQuickAction.notifications,
          HomeQuickAction.resources,
        ]);
      },
    );

    test('always returns three unique actions', () {
      final resolved = resolveHomeQuickActions(
        rawPrimary: HomeQuickAction.explore,
        rawSecondary: HomeQuickAction.explore,
        rawTertiary: HomeQuickAction.explore,
        hasAccount: false,
      );

      expect(resolved, hasLength(3));
      expect(resolved.toSet(), hasLength(3));
    });

    test('preserves hidden slots instead of refilling them', () {
      final resolved = resolveHomeQuickActions(
        rawPrimary: HomeQuickAction.none,
        rawSecondary: HomeQuickAction.monthlyStats,
        rawTertiary: HomeQuickAction.none,
        hasAccount: true,
      );

      expect(resolved, const [
        HomeQuickAction.none,
        HomeQuickAction.monthlyStats,
        HomeQuickAction.none,
      ]);
    });
  });
}
