/// Generated file. Do not edit.
///
/// Original: lib/i18n
/// To regenerate, run: `dart run slang`
///
/// Locales: 5
/// Strings: 5015 (1003 per locale)
///
/// Built on 2026-02-17 at 11:32 UTC

// coverage:ignore-file
// ignore_for_file: type=lint

import 'package:flutter/widgets.dart';
import 'package:slang/builder/model/node.dart';
import 'package:slang_flutter/slang_flutter.dart';
export 'package:slang_flutter/slang_flutter.dart';

const AppLocale _baseLocale = AppLocale.en;

/// Supported locales, see extension methods below.
///
/// Usage:
/// - LocaleSettings.setLocale(AppLocale.en) // set locale
/// - Locale locale = AppLocale.en.flutterLocale // get flutter locale from enum
/// - if (LocaleSettings.currentLocale == AppLocale.en) // locale check
enum AppLocale with BaseAppLocale<AppLocale, Translations> {
	en(languageCode: 'en', build: Translations.build),
	de(languageCode: 'de', build: _StringsDe.build),
	ja(languageCode: 'ja', build: _StringsJa.build),
	zhHans(languageCode: 'zh', scriptCode: 'Hans', build: _StringsZhHans.build),
	zhHantTw(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW', build: _StringsZhHantTw.build);

	const AppLocale({required this.languageCode, this.scriptCode, this.countryCode, required this.build}); // ignore: unused_element

	@override final String languageCode;
	@override final String? scriptCode;
	@override final String? countryCode;
	@override final TranslationBuilder<AppLocale, Translations> build;

	/// Gets current instance managed by [LocaleSettings].
	Translations get translations => LocaleSettings.instance.translationMap[this]!;
}

/// Method A: Simple
///
/// No rebuild after locale change.
/// Translation happens during initialization of the widget (call of t).
/// Configurable via 'translate_var'.
///
/// Usage:
/// String a = t.someKey.anotherKey;
/// String b = t['someKey.anotherKey']; // Only for edge cases!
Translations get t => LocaleSettings.instance.currentTranslations;

/// Method B: Advanced
///
/// All widgets using this method will trigger a rebuild when locale changes.
/// Use this if you have e.g. a settings page where the user can select the locale during runtime.
///
/// Step 1:
/// wrap your App with
/// TranslationProvider(
/// 	child: MyApp()
/// );
///
/// Step 2:
/// final t = Translations.of(context); // Get t variable.
/// String a = t.someKey.anotherKey; // Use t variable.
/// String b = t['someKey.anotherKey']; // Only for edge cases!
class TranslationProvider extends BaseTranslationProvider<AppLocale, Translations> {
	TranslationProvider({required super.child}) : super(settings: LocaleSettings.instance);

	static InheritedLocaleData<AppLocale, Translations> of(BuildContext context) => InheritedLocaleData.of<AppLocale, Translations>(context);
}

/// Method B shorthand via [BuildContext] extension method.
/// Configurable via 'translate_var'.
///
/// Usage (e.g. in a widget's build method):
/// context.t.someKey.anotherKey
extension BuildContextTranslationsExtension on BuildContext {
	Translations get t => TranslationProvider.of(this).translations;
}

/// Manages all translation instances and the current locale
class LocaleSettings extends BaseFlutterLocaleSettings<AppLocale, Translations> {
	LocaleSettings._() : super(utils: AppLocaleUtils.instance);

	static final instance = LocaleSettings._();

	// static aliases (checkout base methods for documentation)
	static AppLocale get currentLocale => instance.currentLocale;
	static Stream<AppLocale> getLocaleStream() => instance.getLocaleStream();
	static AppLocale setLocale(AppLocale locale, {bool? listenToDeviceLocale = false}) => instance.setLocale(locale, listenToDeviceLocale: listenToDeviceLocale);
	static AppLocale setLocaleRaw(String rawLocale, {bool? listenToDeviceLocale = false}) => instance.setLocaleRaw(rawLocale, listenToDeviceLocale: listenToDeviceLocale);
	static AppLocale useDeviceLocale() => instance.useDeviceLocale();
	@Deprecated('Use [AppLocaleUtils.supportedLocales]') static List<Locale> get supportedLocales => instance.supportedLocales;
	@Deprecated('Use [AppLocaleUtils.supportedLocalesRaw]') static List<String> get supportedLocalesRaw => instance.supportedLocalesRaw;
	static void setPluralResolver({String? language, AppLocale? locale, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver}) => instance.setPluralResolver(
		language: language,
		locale: locale,
		cardinalResolver: cardinalResolver,
		ordinalResolver: ordinalResolver,
	);
}

/// Provides utility functions without any side effects.
class AppLocaleUtils extends BaseAppLocaleUtils<AppLocale, Translations> {
	AppLocaleUtils._() : super(baseLocale: _baseLocale, locales: AppLocale.values);

	static final instance = AppLocaleUtils._();

	// static aliases (checkout base methods for documentation)
	static AppLocale parse(String rawLocale) => instance.parse(rawLocale);
	static AppLocale parseLocaleParts({required String languageCode, String? scriptCode, String? countryCode}) => instance.parseLocaleParts(languageCode: languageCode, scriptCode: scriptCode, countryCode: countryCode);
	static AppLocale findDeviceLocale() => instance.findDeviceLocale();
	static List<Locale> get supportedLocales => instance.supportedLocales;
	static List<String> get supportedLocalesRaw => instance.supportedLocalesRaw;
}

// translations

// Path: <root>
class Translations implements BaseTranslations<AppLocale, Translations> {
	/// Returns the current translations of the given [context].
	///
	/// Usage:
	/// final t = Translations.of(context);
	static Translations of(BuildContext context) => InheritedLocaleData.of<AppLocale, Translations>(context).translations;

	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	Translations.build({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = TranslationMetadata(
		    locale: AppLocale.en,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <en>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	dynamic operator[](String key) => $meta.getTranslation(key);

	late final Translations _root = this; // ignore: unused_field

	// Translations
	late final _StringsStringsEn strings = _StringsStringsEn._(_root);
}

// Path: strings
class _StringsStringsEn {
	_StringsStringsEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	late final _StringsStringsCommonEn common = _StringsStringsCommonEn._(_root);
	late final _StringsStringsLanguagesEn languages = _StringsStringsLanguagesEn._(_root);
	late final _StringsStringsLanguagesNativeEn languagesNative = _StringsStringsLanguagesNativeEn._(_root);
	late final _StringsStringsOnboardingEn onboarding = _StringsStringsOnboardingEn._(_root);
	late final _StringsStringsLoginEn login = _StringsStringsLoginEn._(_root);
	late final _StringsStringsSettingsEn settings = _StringsStringsSettingsEn._(_root);
	late final _StringsStringsLegacyEn legacy = _StringsStringsLegacyEn._(_root);
}

// Path: strings.common
class _StringsStringsCommonEn {
	_StringsStringsCommonEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get back => 'Back';
	String get cancel => 'Cancel';
	String get confirm => 'Confirm';
	String get save => 'Save';
	String get saveSettings => 'Save Settings';
	String get auto => 'Auto';
	String get manual => 'Manual';
	String get copiedToClipboard => 'Copied to clipboard';
	String get serverVersion => 'Server Version';
	String get selectValidServerVersion => 'Please select a valid server version';
	String serverVersionValue({required Object version}) => 'Server version: ${version}';
	String get selectServerVersionRange021To026 => 'Please manually select a server version between 0.21 and 0.26';
}

// Path: strings.languages
class _StringsStringsLanguagesEn {
	_StringsStringsLanguagesEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get system => 'Follow System';
	String get zhHans => 'Chinese (Simplified)';
	String get zhHantTw => 'Chinese (Traditional, China Taiwan)';
	String get en => 'English';
	String get ja => 'Japanese';
	String get de => 'German';
}

// Path: strings.languagesNative
class _StringsStringsLanguagesNativeEn {
	_StringsStringsLanguagesNativeEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get system => 'System';
	String get zhHans => '简体中文';
	String get zhHantTw => '繁體中文（中國台灣）';
	String get en => 'English';
	String get ja => '日本語';
	String get de => 'Deutsch';
}

// Path: strings.onboarding
class _StringsStringsOnboardingEn {
	_StringsStringsOnboardingEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get tagline => 'Minimal, powerful note stream';
	String get selectLanguage => 'Select language';
	String get selectMode => 'Choose a mode';
	String get modeHint => 'You can change this later in Settings.';
	String get modeLocalTitle => 'Local mode';
	String get modeLocalLabel => 'LOCAL MODE';
	String get modeLocalDesc => 'Data stays on device. No server setup required, ideal for privacy and offline use.';
	String get modeServerTitle => 'Server mode';
	String get modeServerLabel => 'SERVER MODE';
	String get modeServerDesc => 'Connect to your Memos backend for real-time multi-device sync.';
	String get localLibraryNameTitle => 'Local library name';
	String get localLibraryNameHint => 'Enter a name';
	String get localLibraryDefaultName => 'Local library';
	String get getStarted => 'Get started';
}

// Path: strings.login
class _StringsStringsLoginEn {
	_StringsStringsLoginEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get title => 'Connect to Memos';
	late final _StringsStringsLoginModeEn mode = _StringsStringsLoginModeEn._(_root);
	late final _StringsStringsLoginFieldEn field = _StringsStringsLoginFieldEn._(_root);
	late final _StringsStringsLoginValidationEn validation = _StringsStringsLoginValidationEn._(_root);
	late final _StringsStringsLoginCompatibilityEn compatibility = _StringsStringsLoginCompatibilityEn._(_root);
	late final _StringsStringsLoginConnectEn connect = _StringsStringsLoginConnectEn._(_root);
	late final _StringsStringsLoginErrorsEn errors = _StringsStringsLoginErrorsEn._(_root);
}

// Path: strings.settings
class _StringsStringsSettingsEn {
	_StringsStringsSettingsEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	late final _StringsStringsSettingsPreferencesEn preferences = _StringsStringsSettingsPreferencesEn._(_root);
}

// Path: strings.legacy
class _StringsStringsLegacyEn {
	_StringsStringsLegacyEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get msg_memos_backend_docs => 'Memos Backend Docs';
	String get msg_remember_moment_feel_warmth_life_take => 'Remember the moment, feel the warmth of life.\\nTake a quick review every day.';
	String get msg_sure_want_delete_shortcut => 'Are you sure you want to delete this shortcut?';
	String get msg_scan_completed => 'Scan completed';
	String get msg_confirm => 'Confirm';
	String get msg_unable_open_browser_install_browser_app => 'Unable to open browser. Please install a browser app.';
	String get msg_contributors => 'Contributors';
	String get msg_enter_keywords_search_box_query_local => 'Enter keywords in the search box to query local content and tags. Works offline; for first use, wait until local indexing finishes.';
	String get msg_memo_not_found_locally => 'Memo not found locally';
	String get msg_token => 'Token';
	String get msg_last_7_days => 'Last 7 days';
	String get msg_search_memo_content => 'Search memo content';
	String get msg_retry_started => 'Retry started';
	String msg_last_year_memos({required Object lastYearMemos}) => 'Last year: ${lastYearMemos} memos';
	String get msg_no_content_yet => 'No content yet';
	String get msg_no_summary_yet => 'No summary yet';
	String get msg_sooner => ' sooner!';
	String get msg_token_copied => 'Token copied';
	String get msg_share => 'Share';
	String get msg_gallery_permission_required => 'Gallery permission required';
	String get msg_basic_settings => 'Basic settings';
	String get msg_bad_ssl_certificate => 'Bad SSL certificate.';
	String get msg_no_notifications => 'No notifications';
	String get msg_import_markdown => 'Import from Markdown';
	String get msg_upload_zip_package_md_files => 'Upload a .zip package with .md files';
	String get msg_request_send_timeout_try => 'Request send timeout. Try again.';
	String get msg_select_date_range => 'Select date range';
	String get msg_delete_shortcut => 'Delete Shortcut';
	String get msg_auto_lock_time => 'Auto-lock time';
	String get msg_replacing_delete_original_attachment_continue => 'Replacing will delete the original attachment. Continue?';
	String get msg_add_least_one_condition => 'Please add at least one condition.';
	String get msg_upload_images_image_bed_append_links => 'Upload images to the image bed and append links to the memo.';
	String get msg_request_cancelled => 'Request cancelled.';
	String get msg_generating => 'Generating?';
	String get msg_permissions_denied_reminders_disabled => 'Permissions denied. Reminders disabled.';
	String get msg_memoflow_local_reminders => 'MemoFlow local reminders';
	String get msg_use_legacy_endpoints_older_memos_servers => 'Use legacy endpoints (for older Memos servers).';
	String get msg_no_comments_yet => 'No comments yet';
	String get msg_open => 'Open';
	String get msg_microphone_permission_required => 'Microphone permission required';
	String msg_failed_react({required Object e}) => 'Failed to react: ${e}';
	String get msg_restore_backup => 'Restore backup?';
	String get msg_qr_saved_gallery => 'QR saved to gallery';
	String get msg_no_attachments => 'No attachments';
	String get msg_enable_reminder_permissions => 'Enable reminder permissions';
	String get msg_created_time => 'Created time ↑';
	String get msg_prompt_saved_quick_prompts => 'Your prompt will be saved in Quick prompts';
	String get msg_remember_password => 'Remember password';
	String get msg_enter_valid_url => 'Please enter a valid URL';
	String get msg_may_take_few_seconds => 'This may take a few seconds';
	String msg_local_sync_failed({required Object type, required Object memoError}) => 'Local sync failed (${type}): ${memoError}';
	String get msg_webdav_sync => 'WebDAV Sync';
	String get msg_clear => 'Clear';
	String get msg_clear_recycle_bin_confirm => 'Clear recycle bin? All items will be permanently deleted.';
	String get msg_save_failed => 'Save failed';
	String get msg_endpoint_not_found_version_mismatch => 'Endpoint not found (version mismatch?)';
	String get msg_enable_webdav_sync => 'Enable WebDAV sync';
	String get msg_local_libraries => 'Local libraries';
	String get msg_apply => 'Apply';
	String get msg_restore_only_available_local_libraries => 'Restore is only available for local libraries.';
	String get msg_sign => 'Sign out?';
	String get msg_reminders_disabled => 'Reminders are disabled';
	String get msg_downloading => 'Downloading...';
	String get msg_path => 'Path';
	String get msg_match_any => 'Match any';
	String get msg_local_db_pending_queue => 'Local DB + pending queue';
	String msg_scan_failed({required Object e}) => 'Scan failed: ${e}';
	String get msg_user => 'User';
	String get msg_pick_future_time => 'Pick a future time';
	String get msg_include_pending_queue => 'Include pending queue';
	String get msg_enter_days => 'Enter days';
	String get msg_times => 'Times';
	String get msg_token_returned_only_once_cannot_fetched => 'Token is returned only once and cannot be fetched again';
	String msg_quoted_lines({required Object quoteLines}) => 'Quoted ${quoteLines} lines';
	String get msg_use_remote => 'Use remote';
	String get msg_enable_memo_location => 'Enable memo location';
	String get msg_failed_get_location => 'Failed to get location';
	String get msg_after_import_memos_sync_list_automatically => 'After import, your memos sync to the list automatically. For ZIP imports, ensure the file structure is intact.';
	String get msg_legacy_mode => 'Legacy Mode';
	String get msg_signed => 'Signed in';
	String get msg_shortcut_includes_advanced_conditions_saving_overwrite => 'This shortcut includes advanced conditions. Saving will overwrite them.';
	String get msg_no_results_found => 'No results found';
	String msg_reply({required Object replyName}) => 'Reply ${replyName}...';
	String get msg_copy => 'Copy';
	String get msg_enable_reminders_memos => 'Enable reminders for your memos.';
	String get msg_comment => 'Comment';
	String get msg_added_voice_attachment => 'Added voice attachment.';
	String get msg_customize_sidebar => 'Customize Sidebar';
	String get msg_coffee_add_drumstick => '☕ Coffee it is / add a drumstick';
	String get msg_pin => 'Pin';
	String get msg_enter_password_continue => 'Enter password to continue';
	String get msg_remove_local_library => 'Remove local library?';
	String get msg_comment_2 => 'New comment';
	String get msg_sync_all => 'Sync all';
	String get msg_backup_schedule => 'Backup schedule';
	String get msg_server_error => 'Server error';
	String get msg_analyzing_memos => 'Analyzing your memos...';
	String get msg_notification => 'Notification';
	String get msg_policy => 'Policy';
	String msg_failed_load({required Object error}) => 'Failed to load: ${error}';
	String get msg_default_visibility => 'Default visibility';
	String get msg_filter => 'Filter';
	String get msg_imported_memos => 'Imported memos';
	String get msg_token_created => 'Token created';
	String get msg_server_response_timeout_try => 'Server response timeout. Try again.';
	String get msg_expiring => 'Expiring';
	String get msg_delete_task => 'Delete task';
	String get msg_body_must_json => 'Body must be JSON';
	String get msg_enable => 'Enable';
	String get msg_referenced => 'Referenced by';
	String get msg_replace_image => 'Replace image?';
	String get msg_debug_logs => 'Debug Logs';
	String get msg_active_tasks => 'Active tasks';
	String get msg_attachments => 'Attachments';
	String get msg_range => 'Range';
	String get msg_no_backups_found => 'No backups found';
	String get msg_create_memo => 'Create memo';
	String get msg_street => 'Street';
	String get msg_display_name => 'Display name';
	String get msg_full_text_search => 'Full-Text Search';
	String get msg_create_edit_delete_actions_offline_stored => 'Create/edit/delete actions offline are stored locally and queued for sync. They are sent in order when online. To avoid mistakes, unsubmitted edits can be kept as drafts.';
	String get msg_sign_2 => 'Sign Out';
	String get msg_end_time => 'End time';
	String get msg_sync_recent_content => 'Sync recent content';
	String get msg_resetting_local_data => 'Resetting local data...';
	String get msg_incorrect_password => 'Incorrect password';
	String get msg_content_cannot_empty => 'Content cannot be empty';
	String get msg_preparing => 'Preparing';
	String msg_ai_summary_failed({required Object formatSummaryError_e}) => 'AI summary failed: ${formatSummaryError_e}';
	String get msg_manage => 'Manage';
	String get msg_keep_data_consistent_across_devices => 'Keep data consistent across devices.';
	String msg_playback_failed({required Object e}) => 'Playback failed: ${e}';
	String get msg_path_copied => 'Path copied';
	String get msg_auth_settings => 'Auth settings';
	String get msg_randomly_draw_memo_cards => 'Randomly draw your memo cards';
	String get msg_copy_log_text => 'Copy log text';
	String get msg_yes => 'Yes';
	String get msg_save_open_alipay_scan => 'Save and open Alipay to scan';
	String get msg_signed_but_no_token_returned => 'Signed in, but no token returned';
	String msg_create_failed({required Object formatError_e_context}) => 'Create failed: ${formatError_e_context}';
	String get msg_expand => 'Expand';
	String get msg_local_library_only => 'Local library only';
	String get msg_reminder_channel => 'Reminder channel';
	String get msg_grant => 'Grant';
	String get msg_import_canceled => 'Import canceled.';
	String get msg_never => 'Never';
	String get msg_release_notes => 'Release Notes';
	String get msg_failed_load_references => 'Failed to load references';
	String get msg_select_tags => 'Select tags';
	String get msg_failed_load_try => 'Failed to load. Please try again.';
	String get msg_logs_copied => 'Logs copied';
	String get msg_shortcuts_not_supported_server => 'Shortcuts are not supported on this server.';
	String msg_reply_2({required Object name}) => 'Reply ${name}...';
	String get msg_anonymous => 'Anonymous';
	String get msg_username => 'Username';
	String get msg_update_memo => 'Update memo';
	String msg_saved({required Object targetPath}) => 'Saved to: ${targetPath}';
	String get msg_chinese_simplified => 'Chinese (Simplified)';
	String get msg_memo_copied => 'Memo copied';
	String get msg_collapse => 'Collapse';
	String get msg_retry_count_controls_how_many_extra => 'Retry count controls how many extra attempts are made on failure. Higher values may improve success but take longer.';
	String get msg_recording_info_missing => 'Recording info missing';
	String get msg_sync_task => 'Sync task';
	String get msg_clear_all_debug_logs => 'Clear all debug logs?';
	String get msg_export_finished => 'Export finished';
	String msg_failed_stop_recording({required Object e}) => 'Failed to stop recording: ${e}';
	String get msg_my_profile => 'My Profile';
	String get msg_image_bed => 'Image Bed';
	String msg_failed_open_notification({required Object e}) => 'Failed to open notification: ${e}';
	String get msg_manual => 'Manual';
	String get msg_no_html_file_found_zip => 'No HTML file found in ZIP.';
	String get msg_also_clear_local_cache_account_offline => 'This will also clear local cache for this account (offline data/drafts/pending sync queue). This action cannot be undone.';
	String get msg_restore => 'Restore';
	String get msg_auto_backup => 'Auto backup';
	String get msg_generate_summary => 'Generate summary';
	String msg_days({required Object stats_activeDays}) => '${stats_activeDays} days';
	String get msg_count => '- Count';
	String get msg_weekly => 'Weekly';
	String get msg_notifications => 'Notifications';
	String get msg_backup_failed => 'Backup failed';
	String get msg_private => 'Private';
	String get msg_filter_tags => 'Filter by tags';
	String get msg_clear_logs => 'Clear logs';
	String get msg_unable_open_browser => 'Unable to open browser';
	String get msg_attachment_too_large => 'Attachment too large';
	String get msg_query => 'Query';
	String get msg_match_all => 'Match all';
	String get msg_record_request_response_logs => 'Record request/response logs';
	String get msg_import_file => 'Import File';
	String get msg_content_tags => 'Content + tags';
	String get msg_feature_not_available_local_library_mode => 'This feature is not available in local library mode.';
	String msg_import_failed({required Object e}) => 'Import failed: ${e}';
	String get msg_save_memo => 'Save as memo';
	String get msg_scan_disk_directory_merge_local_database => 'Scan disk directory and merge into local database? Missing files will be treated as deletions.';
	String get msg_passwords_not_match => 'Passwords do not match';
	String msg_signed_2({required Object lastLoginUser}) => 'Signed in as: ${lastLoginUser}';
	String get msg_made_love_note_taking => 'Made with love for note-taking';
	String get msg_password_updated_local => 'Password updated (local)';
	String get msg_retry => 'Retry';
	String get msg_memo_stats => 'Memo stats';
	String get msg_shown_only_once_copy_keep_safe => 'Shown only once, please copy and keep it safe.';
	String get msg_describe_issue_time_repro_steps_etc => 'Describe the issue, time, repro steps, etc.';
	String get msg_how_many_days_back => 'How many days back';
	String get msg_local_cache_cleared => 'Local cache cleared';
	String get msg_none => 'None';
	String get msg_body_json => 'Body (JSON)';
	String msg_download_failed({required Object e}) => 'Download failed: ${e}';
	String get msg_recycle_bin => 'Recycle Bin';
	String get msg_unpin => 'Unpin';
	String get msg_advanced_security => 'Advanced & security';
	String get msg_run_issues_memoflow_e_g_sync => 'If you run into issues in MemoFlow (e.g. sync failures, crashes), please follow the steps below to help us diagnose and fix the problem faster.\\n\\n';
	String get msg_remove_all_reminder_times_memo => 'Remove all reminder times for this memo.';
	String get msg_no_summary_save => 'No summary to save';
	String get msg_reset_language_selection => 'Reset language selection';
	String get msg_v_30_days => '30 days';
	String get msg_e_g_mood_check => 'e.g. Mood check';
	String get msg_note_some_tokens_returned_only_once => 'Note: Some tokens are returned only once and cannot be retrieved later. Please keep them safe.';
	String get msg_syncing => 'Syncing...';
	String get msg_retention => 'Retention';
	String get msg_open_login_screen => 'Open login screen';
	String get msg_apply_all => 'Apply to all';
	String get msg_write_something_supports_tag_tasks_x => 'Write something... Supports #tag and tasks [ ] / [x]';
	String msg_http({required Object base, required Object status, required Object msg}) => '${base} (HTTP ${status}): ${msg}';
	String get msg_single => 'Single';
	String get msg_delete_memo => 'Delete memo?';
	String get msg_ai_provider => 'AI Provider';
	String msg_release_notes_v({required Object version}) => 'Release Notes v${version}';
	String get msg_info_only_used_background_ai_summaries => 'This info is only used as background for AI summaries/reports and is not synced to the backend.';
	String get msg_not_disturb => 'Do not disturb';
	String msg_local_library_import_failed({required Object e}) => 'Local library import failed: ${e}';
	String get msg_key_insights => 'Key insights';
	String get msg_additional_notes_optional => 'Additional notes (optional)';
	String get msg_server_response_error => 'Server response error.';
	String get msg_sort => 'Sort';
	String get msg_api_call => 'API Call';
	String get msg_webhooks => 'Webhooks';
	String get msg_local_library => 'Local library';
	String get msg_log_copied => 'Log copied';
	String get msg_last_success => 'Last success';
	String get msg_restore_cloud => 'Restore from cloud';
	String get msg_search_public_memos => 'Search public memos';
	String get msg_cancel => 'Cancel';
	String msg_processing({required Object processed, required Object total}) => 'Processing ${processed} / ${total}';
	String get msg_failed_items => 'Failed items';
	String get msg_recording_file_not_found => 'Recording file not found';
	String get msg_local_db_outbox_queue => 'Local DB + outbox queue';
	String get msg_remove => 'Remove';
	String get msg_export_format => 'Export Format';
	String get msg_idle => 'Idle';
	String msg_ago({required Object months}) => '${months} ago';
	String get msg_no_tags_yet => 'No tags yet';
	String msg_version_v({required Object version}) => 'Version v${version}';
	String get msg_sync => 'Sync';
	String get msg_done => 'Done';
	String get msg_gallery_permission_required_2 => 'Gallery permission required';
	String get msg_insufficient_permissions => 'Insufficient permissions';
	String get msg_no_download_url_available => 'No download URL available';
	String get msg_record_create_memos => 'Record to create memos';
	String get msg_signing => 'Signing in...';
	String get msg_memoflow_uses_system_location_permission_get => 'MemoFlow uses system location permission to get coordinates, then reverse geocodes via Amap Web API. You can choose the display precision above.';
	String get msg_continue => 'Continue';
	String get msg_notification_content_unavailable => 'Notification content unavailable';
	String get msg_unable_read_file_path => 'Unable to read file path.';
	String get msg_all_memos => 'All Memos';
	String get msg_keywords => 'Keywords';
	String get msg_import_result => 'Import Result';
	String get msg_offline_sync => 'Offline Sync';
	String get msg_imported_memos_local_library => 'Imported memos from local library';
	String get msg_request_failed => 'Request failed';
	String get msg_log_file => 'Log file';
	String get msg_after_confirming_support_unlock_limited_gold => 'After confirming support, you will unlock a limited gold badge or a forever ad-free promise (though there were never ads).';
	String get msg_failed_open_system_settings => 'Failed to open system settings';
	String get msg_no_mood_trend => 'No mood trend';
	String get msg_memoflow_export => '# MemoFlow Export';
	String get msg_sync_queue => 'Sync queue';
	String get msg_only_delete_sync_task_memo_kept => 'Only delete the sync task; the memo will be kept.';
	String get msg_add_home_screen => 'Add to Home Screen';
	String get msg_past_days => 'Past days';
	String get msg_poster_generation_failed => 'Poster generation failed';
	String msg_failed_load_stats({required Object e}) => 'Failed to load stats: ${e}';
	String get msg_customize_notification => 'Customize Notification';
	String get msg_updated_time => 'Updated time ↓';
	String get msg_network_connection_failed_check_network => 'Network connection failed. Please check your network.';
	String get msg_special_thanks => 'Special thanks:';
	String msg_failed_comment({required Object e}) => 'Failed to comment: ${e}';
	String get msg_security_key_sig => 'Security Key (sig)';
	String get msg_save_gallery => 'Save to gallery';
	String get msg_request_sent_confirm_system_prompt => 'Request sent. Confirm in the system prompt';
	String get msg_server_url => 'Server URL';
	String get msg_period_review => 'Period Review';
	String get msg_settings_updated => 'Settings updated';
	String get msg_backend_0_21_not_supported_import => 'Backend 0.21 is not supported for import. Please upgrade and try again.';
	String msg_failed_load_tags({required Object e}) => 'Failed to load tags: ${e}';
	String get msg_enter_email => 'Enter email';
	String get msg_add_webhook => 'Add Webhook';
	String get msg_read => 'Read';
	String get msg_widgets => 'Widgets';
	String get msg_default => 'Default';
	String get msg_memo_reminders => 'Memo Reminders';
	String get msg_import_flomo => 'Import from Flomo';
	String get msg_format_fixed_markdown_zip => 'Format is fixed to Markdown + ZIP';
	String get msg_enter_username_password => 'Enter username and password';
	String get msg_loading => 'Loading...';
	String msg_test_scheduled({required Object timeLabel, required Object suffix, required Object pendingLabel}) => 'Test scheduled at ${timeLabel}${suffix}${pendingLabel}';
	String get msg_edit_memo => 'Edit Memo';
	String get msg_save => 'Save';
	String get msg_laboratory => 'Laboratory';
	String get msg_use_local => 'Use local';
	String get msg_retry_sync => 'Retry sync';
	String get msg_e_g_my_role_topics_interest => 'e.g., my role / topics of interest / writing style preferences?';
	String get msg_confirm_password => 'Confirm Password';
	String get msg_not_set => 'Not set';
	String get msg_no_memos_day => 'No memos on this day';
	String get msg_shortcut_name => 'Shortcut name';
	String get msg_edit_shortcut => 'Edit Shortcut';
	String get msg_days_memos => 'Days with memos';
	String get msg_delete => 'Delete';
	String get msg_test_reminder => 'Test reminder';
	String get msg_enable_reminders => 'Enable reminders';
	String get msg_links => 'Links';
	String get msg_location => 'Location';
	String get msg_import_file_2 => 'Import from file';
	String msg_reply_3({required Object creatorDisplayName_commentCreator_commentMemo_creator}) => 'Reply ${creatorDisplayName_commentCreator_commentMemo_creator}...';
	String msg_created({required Object widget_createdAtLabel}) => 'Created ${widget_createdAtLabel}';
	String get msg_notifications_coming_soon => 'Notifications: coming soon';
	String get msg_view_full_contributors => 'View full contributors';
	String get msg_no_times_set => 'No times set';
	String get msg_ignore_tls_errors => 'Ignore TLS errors';
	String get msg_no_content => 'No content';
	String get msg_about_15_seconds_left => 'About 15 seconds left';
	String get msg_view_imported_memos => 'View imported memos';
	String get msg_load_failed => 'Load failed';
	String get msg_disk_content_conflicts_local_pending_changes => 'Disk content conflicts with local pending changes. Use disk to overwrite local content.';
	String get msg_all_history_so_far_memoflow_since => 'That is all the history so far\\nMEMOFLOW SINCE 2023';
	String get msg_cancelling => 'Cancelling';
	String get msg_reading_file => 'Reading file...';
	String get msg_switch_workspace => 'Switch workspace';
	String get msg_optional_leave_empty_default => 'Optional. Leave empty for default.';
	String get msg_memo_reminders_2 => 'Memo reminders';
	String msg_save_failed_2({required Object e}) => 'Save failed: ${e}';
	String get msg_record_create_memos_sync_later => 'Record and create memos (sync later)';
	String get msg_use_https_avoid_ignoring_tls_errors => 'Use HTTPS and avoid ignoring TLS errors to protect credentials.';
	String get msg_failed_load_announcement_config => 'Failed to load announcement config';
	String get msg_shortcuts => 'Shortcuts';
	String get msg_memo => 'Memo';
	String get msg_maybe_later => 'Maybe later';
	String get msg_server_connection => 'Server connection';
	String get msg_days_2 => 'Days';
	String get msg_include_archived => 'Include Archived';
	String get msg_during_quiet_hours_reminders_silenced => 'During quiet hours, reminders will be silenced.';
	String get msg_preview_not_supported_type => 'Preview not supported for this type';
	String get msg_failed_load_2 => 'Failed to load';
	String get msg_create_token => 'Create New Token';
	String get msg_enter_name => 'Please enter a name.';
	String get msg_api_url_incorrect => 'API URL is incorrect.';
	String get msg_user_general_settings => 'User General Settings';
	String get msg_saved_memo => 'Saved as memo';
	String msg_restore_failed({required Object e}) => 'Restore failed: ${e}';
	String msg_token_tail({required Object tail}) => 'Token tail ${tail}';
	String get msg_manual_token => 'Manual Token';
	String msg_ago_2({required Object years}) => '${years} ago';
	String get msg_recent_searches => 'Recent searches';
	String get msg_restored => 'Restored';
	String get msg_no_contributors_yet => 'No contributors yet';
	String get msg_no_record_yet => 'No record yet';
	String get msg_reminder => 'Reminder';
	String get msg_enter_api_key_ai_settings => 'Please enter API Key in AI settings';
	String get msg_reminder_settings => 'Reminder Settings';
	String msg_http_2({required Object base, required Object status}) => '${base} (HTTP ${status})';
	String get msg_edit_webhook => 'Edit Webhook';
	String get msg_generate_share_poster => 'Generate share poster';
	String msg_archive_failed({required Object e}) => 'Archive failed: ${e}';
	String msg_comments({required Object widget_commentCount}) => '${widget_commentCount} comments';
	String get msg_remove_account => 'Remove account?';
	String get msg_chinese_traditional => 'Chinese (Traditional)';
	String get msg_private_2 => 'Private';
	String get msg_current_streak => 'Current streak';
	String get msg_generated_ai_memoflow => 'Generated by AI · MemoFlow';
	String get msg_edit_completed => 'Edit completed';
	String get msg_local => 'Local';
	String get msg_edit => 'Edit';
	String msg_text({required Object shortUserName_item_sender}) => 'From ${shortUserName_item_sender}';
	String get msg_got => 'Got it';
	String get msg_web_api_key => 'Web API Key';
	String get msg_preview => 'Preview';
	String get msg_enter_password => 'Please enter password';
	String get msg_api => 'API';
	String get msg_ok => 'OK';
	String get msg_failed_load_shortcuts => 'Failed to load shortcuts.';
	String get msg_after_recording_audio_added_current_draft => 'After recording, the audio is added to the current draft as an attachment so you can edit before sending. Max length is 60 minutes; transcription can be added via third-party services later.';
	String get msg_pull_refresh => 'Pull to Refresh';
	String get msg_unable_open_photo => 'Unable to open photo';
	String get msg_existing_tokens => 'Existing Tokens';
	String get msg_ai_settings => 'AI Settings';
	String get msg_app_lock => 'App Lock';
	String get msg_total_notes => 'Total notes';
	String get msg_stats_loading => 'Stats are loading';
	String get msg_enter_token_description => 'Enter a token description';
	String get msg_enter_token => 'Enter a token';
	String get msg_api_plugins => 'API & Plugins';
	String get msg_parsing_file => 'Parsing file...';
	String get msg_english => 'English';
	String get msg_activity_heatmap => 'Activity Heatmap';
	String get msg_mark_read => 'Mark as read';
	String get msg_request => 'Request';
	String msg_sync_failed({required Object type, required Object memoError}) => 'Sync failed (${type}): ${memoError}';
	String get msg_error_copied => 'Error copied';
	String get msg_only_local_index_removed_disk_files => 'Only local index will be removed; disk files are kept. This cannot be undone.';
	String get msg_switch_account => 'Switch account';
	String get msg_invalid_download_link => 'Invalid download link';
	String get msg_about => 'About';
	String get msg_icon => 'Icon';
	String get msg_reset_done_syncing => 'Reset done. Syncing...';
	String get msg_enter_amap_web_api_key => 'Enter your Amap Web API Key';
	String get msg_recycle_bin_coming_soon => 'Recycle bin: coming soon';
	String get msg_empty_content => '(Empty content)';
	String get msg_note_most_features_offline_stats_ai => 'Note: Most features (offline/stats/AI reports/export) work without backend changes, but tokens are returned only once?please keep them safe.';
	String get msg_fixed => 'Fixed: ';
	String get msg_allow_sharing_links_images_other_apps => 'Allow sharing links or images from other apps into MemoFlow.';
	String get msg_invalid_request_parameters => 'Invalid request parameters';
	String get msg_enter_api_url => 'Please enter API URL';
	String msg_pending({required Object result_pendingCount}) => ' (pending ${result_pendingCount})';
	String msg_days_3({required Object currentStreak}) => '${currentStreak} days';
	String get msg_poster_not_ready_yet => 'Poster is not ready yet';
	String get msg_generated_memoflow => 'Generated by MemoFlow';
	String get msg_enter_name_2 => 'Enter a name';
	String get msg_version => 'Version';
	String get msg_memo_missing_disk_but_has_local => 'The memo is missing on disk but has local pending changes. Use disk to delete locally.';
	String get msg_legacy_api_compatibility => 'Legacy API Compatibility';
	String get msg_sync_parameters => 'Sync parameters';
	String get msg_quick_prompts => 'Quick prompts';
	String msg_share_failed({required Object e}) => 'Share failed: ${e}';
	String get msg_no_memos_summarize_range => 'No memos to summarize in this range';
	String get msg_characters => 'Characters';
	String get msg_capture_every_moment_record => 'Capture every moment you record';
	String get msg_vibration => 'Vibration';
	String get msg_days_4 => 'days';
	String get msg_prompt_title => 'Prompt title';
	String get msg_show_all => 'Show all';
	String get msg_no_memos_available => 'No memos available';
	String get msg_comment_unavailable => 'Comment unavailable';
	String get msg_refresh => 'Refresh';
	String get msg_syncing_2 => 'Syncing';
	String get msg_body => 'Body';
	String get msg_clear_2 => 'Clear';
	String get msg_third_party_share => 'Third-party Share';
	String get msg_charging_station => 'Charging Station';
	String get msg_attachments_2 => 'Attachments';
	String get msg_when_enabled_must_verify_each_app => 'When enabled, you must verify on each app launch. Auto-lock time controls how soon verification is required after the app goes to background.';
	String get msg_add_prompt => 'Add prompt';
	String get msg_include => 'Include';
	String get msg_created_time_2 => 'Created time ↓';
	String get msg_choose_data_source_start_importing_memos => 'Choose a data source to start importing your memos';
	String get msg_describe_how_want_summary => 'Describe how you want the summary…';
	String get msg_keep_token_safe_not_share_api => 'Keep your token safe and do not share it.\\nAPI rate limit is 60 requests per minute.';
	String get msg_open_2 => 'Open';
	String get msg_e_g_claude_3_5_sonnet => 'e.g. claude-3-5-sonnet-20241022';
	String get msg_failed_request_whitelist => 'Failed to request whitelist';
	String get msg_notification_deleted => 'Notification deleted';
	String get msg_accounts => 'Accounts';
	String get msg_add_local_library => 'Add local library';
	String get msg_sign_first => 'Please sign in first';
	String get msg_failed_parse_query => 'Failed to parse query';
	String get msg_note_logs_sanitized_automatically_sensitive_data => 'Note: logs are sanitized automatically. If sensitive data remains, redact before submitting.';
	String get msg_add => 'Add';
	String msg_failed_load_3({required Object memosError}) => 'Failed to load: ${memosError}';
	String get msg_max_chars_day => 'Max chars/day';
	String get msg_choose_what_edited_image => 'Choose what to do with the edited image.';
	String get msg_select => 'Select';
	String get msg_unnamed_token => '(Unnamed Token)';
	String get msg_name => 'Name';
	String get msg_sure_want_delete_webhook => 'Are you sure you want to delete this webhook?';
	String get msg_back => 'Back';
	String get msg_no => 'No';
	String get msg_untitled => 'Untitled';
	String get msg_open_language_onboarding => 'Open language onboarding';
	String get msg_voice_memos => 'Voice Memos';
	String get msg_unable_open_browser_try => 'Unable to open browser. Please try again.';
	String get msg_date_range => 'Date Range';
	String get msg_not_authenticated => 'Not authenticated';
	String get msg_back_2 => 'Back';
	String get msg_local_library_removed => 'Local library removed';
	String get msg_exact_alarm_permission_required => 'Exact alarm permission required';
	String get msg_visibility => 'Visibility';
	String msg_failed_start_recording({required Object e}) => 'Failed to start recording: ${e}';
	String get msg_mood_trend => 'Mood trend';
	String get msg_local_library_name => 'Local library name';
	String get msg_no_tokens_yet => 'No tokens yet';
	String get msg_loading_2 => 'Loading?';
	String get msg_location_permission_denied_permanently => 'Location permission denied permanently';
	String get msg_download => 'Download';
	String get msg_export_time => '- Export time';
	String get msg_enter_password_2 => 'Enter password';
	String get msg_no_image_available => 'No image available';
	String get msg_daily => 'Daily';
	String get msg_no_likes_yet => 'No likes yet';
	String get msg_basics => 'Basics';
	String get msg_shortcut => 'New shortcut';
	String get msg_debug_tools => 'Debug Tools';
	String get msg_save_settings => 'Save Settings';
	String get msg_date_range_2 => 'Date range';
	String get msg_feedback => 'Feedback';
	String get msg_image_bed_2 => 'Image Bed';
	String get msg_restoring => 'Restoring…';
	String get msg_export => 'Export';
	String get msg_enter_token_name => 'Please enter token name';
	String get msg_start_time => 'Start time';
	String get msg_preparing_file_structure => 'Preparing file structure';
	String get msg_sign_3 => 'Sign in';
	String get msg_scan_local_library => 'Scan local library';
	String get msg_lsky_pro => 'Lsky Pro';
	String get msg_exact_alarm_permission_off_reminders_may => 'Exact alarm permission is off. Reminders may not fire on time. Open settings now?';
	String get msg_last_30_days => 'Last 30 days';
	String get msg_match => 'Match';
	String get msg_auth_mode => 'Auth mode';
	String get msg_unsupported_file_type => 'Unsupported file type.';
	String get msg_only_delete_sync_task => 'Only delete the sync task.';
	String get msg_change_password => 'Change Password';
	String get msg_saved_2 => 'Saved';
	String get msg_import_export => 'Import / Export';
	String get msg_created_2 => 'Created';
	String get msg_ai_summary => 'AI Summary';
	String get msg_progress => 'Progress';
	String get msg_replace_memo_image => 'Replace memo image';
	String get msg_app_settings => 'App settings';
	String get msg_copy_path => 'Copy path';
	String get msg_components => 'Components';
	String get msg_no_shortcuts => 'No shortcuts';
	String get msg_location_timed_try => 'Location timed out. Please try again.';
	String get msg_attach_location_info_memos_show_subtle => 'Attach location info to memos and show subtle place names.';
	String msg_send_failed({required Object e}) => 'Send failed: ${e}';
	String get msg_repeat => 'Repeat';
	String get msg_not_signed => 'Not signed in';
	String get msg_no_webhooks_configured => 'No webhooks configured';
	String get msg_apply_token => 'Apply token';
	String get msg_enable_reminder_permissions_2 => 'Enable reminder permissions';
	String get msg_enter_backup_password => 'Enter backup password';
	String get msg_start_backup => 'Start backup';
	String get msg_last_sync => 'Last sync';
	String get msg_note_export_includes_content_already_synced => 'Note: Export includes content already synced to the local database (offline data included).';
	String get msg_enter_username => 'Enter username';
	String get msg_settings_saved => 'Settings saved';
	String get msg_no_keywords => 'No keywords';
	String get msg_these_settings_apply_newly_created_memos => 'These settings apply to newly created memos.';
	String get msg_back_home => 'Back to Home';
	String get msg_quiet_hours => 'Quiet hours';
	String get msg_add_account => 'Add Account';
	String get msg_reset_complete => 'Reset complete';
	String get msg_no_shortcuts_configured => 'No shortcuts configured';
	String get msg_password => 'Password';
	String get msg_importing => 'Importing';
	String msg_visibility_2({required Object visibilityLabel}) => 'Visibility: ${visibilityLabel}';
	String get msg_no_logs_yet => 'No logs yet';
	String get msg_v_9_times_allowed => 'Up to 9 times allowed';
	String get msg_last_14_days => 'Last 14 days';
	String get msg_location_disabled_enable_settings_first => 'Location is disabled. Enable it in settings first.';
	String get msg_add_2 => 'Add';
	String get msg_logs => 'Logs';
	String get msg_references => 'References';
	String get msg_importing_memos => 'Importing memos...';
	String get msg_account_security => 'Account & Security';
	String get msg_reminder_2 => 'Reminder';
	String get msg_enable_scheduled_reminder_notifications => 'Enable scheduled reminder notifications.';
	String get msg_no_links => 'No links';
	String get msg_delete_memo_2 => 'Delete memo';
	String get msg_one_tap_add_not_supported_add => 'One-tap add not supported. Add it from the widget picker';
	String get msg_password_2 => 'New Password';
	String get msg_processing_content => 'Processing content...';
	String get msg_status => 'Status';
	String get msg_local_library_added => 'Local library added';
	String get msg_failed_open_try => 'Failed to open. Please try again.';
	String get msg_removed_locally_now_deleted_server_when => 'It will be removed locally now and deleted on the server when online.';
	String get msg_server_url_unavailable => 'Server URL unavailable';
	String get msg_no_release_notes_yet => 'No release notes yet';
	String get msg_cancelling_2 => 'Cancelling...';
	String get msg_summaries_selected_range => 'Summaries over selected range';
	String get msg_expand_2 => 'Expand';
	String get msg_close => 'Close';
	String msg_more_comments({required Object remainingComments}) => '${remainingComments} more comments';
	String get msg_backing => 'Backing up…';
	String get msg_view_debug_logs => 'View debug logs';
	String get msg_location_permission_denied => 'Location permission denied';
	String get msg_self_repair_reset_heatmap => 'Self repair: reset heatmap';
	String get msg_these_settings_changed_locally_remotely_choose => 'These settings changed locally and remotely. Choose which version to keep.';
	String get msg_not_authenticated_2 => 'Not authenticated.';
	String msg_action_failed({required Object e}) => 'Action failed: ${e}';
	String get msg_shortcut_2 => 'New Shortcut';
	String get msg_url => 'URL';
	String get msg_no_memos_found_html => 'No memos found in HTML.';
	String get msg_enter_what_want_summarize => 'Enter what you want to summarize...';
	String get msg_unable_load_audio_source => 'Unable to load audio source.';
	String get msg_strategy_id => 'Strategy ID';
	String msg_copy_failed({required Object e}) => 'Copy failed: ${e}';
	String get msg_enable_image_bed => 'Enable image bed';
	String get msg_active => 'Active';
	String get msg_account => 'Account';
	String get msg_invalid_webdav_server_url => 'Invalid WebDAV server URL';
	String get msg_keep_local => 'Keep local';
	String get msg_within_range => 'Within range';
	String get msg_generate_log_file => 'Generate log file';
	String get msg_ai_reports => 'AI Reports';
	String get msg_battery_optimization => 'Battery optimization';
	String get msg_sync_overview => 'Sync overview';
	String get msg_legacy_servers_not_support_search_filters => 'Legacy servers do not support search filters; results may be incomplete.';
	String get msg_conflicts_detected_run_manual_sync => 'Conflicts detected. Run manual sync.';
	String get msg_authentication_failed_check_token => 'Authentication failed. Check token.';
	String get msg_date_range_3 => 'Date range';
	String get msg_help_ai_understand_better => 'Help AI understand you better';
	String get msg_no_search_history => 'No search history';
	String get msg_enter_api_path => 'Enter API path';
	String get msg_stats => 'Stats';
	String get msg_text_2 => 'New: ';
	String get msg_removing_signing_clear_local_cache_account => 'Removing/signing out will clear local cache for this account (offline data/drafts/pending sync queue).';
	String get msg_updated_time_2 => 'Updated time ↑';
	String get msg_province => 'Province';
	String get msg_submitting_sync_queue => 'Submitting sync queue';
	String get msg_failed => 'Failed';
	String get msg_set_time => 'Set time';
	String get msg_enable_local_library_backup => 'Enable local library backup';
	String get msg_cancel_2 => 'Cancel';
	String get msg_week => 'This Week';
	String get msg_like => 'Like';
	String get msg_location_services_disabled => 'Location services are disabled';
	String get msg_clears_local_cache_offline_memos_pending => 'This clears local cache (offline memos/pending queue) and triggers a full resync. Unsynced content will be lost and it may take a while. Continue?';
	String get msg_load_more => 'Load more';
	String get msg_pull_memo_list_refresh_sync_sync => 'Pull down in the memo list to refresh and sync. Sync fetches the most recent items first; run a full sync periodically to keep stats/heatmap complete.';
	String msg_server_returned_error({required Object code}) => 'Server returned error (${code}).';
	String get msg_sound_feedback => 'Sound & feedback';
	String msg_memos_skipped_attachments_skipped({required Object exportedMemoCount, required Object skippedMemoCount, required Object exportedAttachmentCount, required Object skippedAttachmentCount}) => '${exportedMemoCount} memos (skipped ${skippedMemoCount}), ${exportedAttachmentCount} attachments (skipped ${skippedAttachmentCount}).';
	String get msg_import_complete => 'Import complete';
	String get msg_text_3 => 'New';
	String get msg_max_per_day => 'Max per day';
	String get msg_permissions_denied => 'Permissions denied';
	String get msg_memo_2 => 'New Memo';
	String get msg_delete_reminder => 'Delete reminder';
	String get msg_select_month => 'Select month';
	String get msg_select_backup => 'Select backup';
	String get msg_no_keywords_2 => '#No keywords';
	String get msg_preparing_memo_content => 'Preparing memo content';
	String get msg_prompt_content => 'Prompt content';
	String get msg_default_prompt_ai_summaries_reports => 'Default prompt for AI summaries/reports';
	String get msg_intro => 'Intro';
	String get msg_monthly_stats => 'Monthly stats';
	String get msg_times_2 => 'times';
	String get msg_file_has_already_been_imported_skipped => 'This file has already been imported. Skipped.';
	String get msg_token_tail_unknown => 'Token tail unknown';
	String get msg_press_back_exit => 'Press back again to exit';
	String get msg_enter_password_3 => 'Enter password';
	String get msg_sync_conflicts => 'Sync conflicts';
	String get msg_locale => 'Locale';
	String get msg_any => 'Any';
	String get msg_provider => 'Provider';
	String get msg_preview_2 => 'Preview';
	String get msg_automatically_upload_images_append_links_memo => 'Automatically upload images and append links to the memo.';
	String get msg_import_file_not_found => 'Import file not found.';
	String get msg_today => 'Today';
	String get msg_link_card => 'Link Card';
	String get msg_expiration => 'Expiration';
	String get msg_summary_prompt_optional => 'Summary prompt (optional)';
	String get msg_memos => 'Memos';
	String get msg_recording_file_not_found_2 => 'Recording file not found.';
	String get msg_backup_settings => 'Backup settings';
	String get msg_mode => 'Mode';
	String get msg_no_markdown_memos_found_zip => 'No Markdown memos found in ZIP.';
	String get msg_archived => 'Archived';
	String msg_update_failed({required Object e}) => 'Update failed: ${e}';
	String get msg_enable_app_lock => 'Enable App Lock';
	String get msg_html_zip => 'HTML / ZIP';
	String get msg_all => 'All';
	String get msg_model => 'Model';
	String get msg_title => 'Title';
	String get msg_amap_web_api => 'Amap Web API';
	String get msg_saved_gallery => 'Saved to gallery';
	String get msg_unread => 'Unread';
	String get msg_exporting => 'Exporting...';
	String get msg_network_timeout_try => 'Network timeout. Please try again.';
	String get msg_unlock => 'Unlock';
	String msg_ago_3({required Object diff_inDays}) => '${diff_inDays} ago';
	String get msg_deserve_coffee_i_m_pulling_all => 'To deserve this coffee, I\'m pulling an all-nighter to write 100 lines of code!';
	String get msg_token_name => 'Token Name';
	String get msg_restore_completed => 'Restore completed';
	String get msg_copied_clipboard => 'Copied to clipboard';
	String msg_failed_2({required Object attempts}) => 'Failed ${attempts}';
	String get msg_too_many_requests_try_later => 'Too many requests. Try again later.';
	String get msg_more => 'More';
	String get msg_already_whitelisted => 'Already whitelisted';
	String get msg_local_library_backup => 'Local library backup';
	String get msg_awesome => 'Awesome! ❤️';
	String get msg_now => 'Now';
	String get msg_select_reminder_time => 'Select reminder time';
	String get msg_protected => 'Protected';
	String msg_failed_load_4({required Object e}) => 'Failed to load: ${e}';
	String msg_operation_failed({required Object e}) => 'Operation failed: ${e}';
	String get msg_no_tags => 'No tags';
	String get msg_server => 'Server';
	String get msg_improved => 'Improved';
	String get msg_request_2 => 'Request';
	String msg_export_failed({required Object e}) => 'Export failed: ${e}';
	String get msg_notification_settings => 'Notification settings';
	String get msg_related_memo_was_deleted => 'The related memo was deleted';
	String get msg_email => 'Email';
	String get msg_enter_password_4 => 'Please enter a password';
	String get msg_retry_count => 'Retry Count';
	String get msg_import_exported_html_zip_package => 'Import exported HTML or ZIP package';
	String get msg_archive => 'Archive';
	String get msg_reset_heatmap => 'Reset heatmap?';
	String get msg_token_applied => 'Token applied';
	String get msg_log_file_created => 'Log file created';
	String get msg_delete_sync_task => 'Delete sync task';
	String get msg_include_archived_2 => '- Include archived';
	String get msg_memoflow_side_project_i_build_my => 'MemoFlow is a side project I build in my spare time. I have been up late fixing bugs and could really use an iced Americano. Your support refuels my battery and helps new features ship ';
	String msg_failed_generate({required Object e}) => 'Failed to generate: ${e}';
	String get msg_search_logs => 'Search logs';
	String get msg_active_days => 'Active days';
	String get msg_back_top => 'Back to top';
	String get msg_month => 'This Month';
	String get msg_loading_references => 'Loading references';
	String get msg_silent => 'Silent';
	String get msg_settings => 'Settings';
	String get msg_locating => 'Locating...';
	String get msg_scan => 'Scan';
	String get msg_recording_path_missing => 'Recording path missing.';
	String get msg_date_range_4 => '- Date range';
	String get msg_suggested_tags => 'Suggested tags';
	String get msg_energy_restored => '⚡ ENERGY RESTORED';
	String get msg_username_2 => 'Username';
	String get msg_ai_summary_report => 'AI Summary Report';
	String get msg_all_tags => 'All Tags';
	String get msg_preferences => 'Preferences';
	String get msg_image_bed_3 => 'Image Bed';
	String get msg_quick_input => 'Quick Input';
	String get msg_tags => 'Tags';
	String get msg_energy_critically_low => 'Energy critically low!';
	String msg_delete_failed({required Object e}) => 'Delete failed: ${e}';
	String get msg_server_login => 'Server Login';
	String get msg_like_2 => 'Like';
	String get msg_save_2 => 'Save';
	String get msg_unknown => 'Unknown';
	String get msg_release_notes_2 => 'Release Notes';
	String get msg_include_error_details => 'Include error details';
	String get msg_write_comment => 'Write a comment...';
	String get msg_write_thoughts => 'Write down your thoughts...';
	String get msg_local_2 => 'Local';
	String get msg_expired => 'Expired';
	String get msg_fixed_2 => 'Fixed';
	String get msg_upload_attachment => 'Upload attachment';
	String get msg_battery_whitelist => 'Battery whitelist';
	String get msg_district => 'District';
	String get msg_voice_memo => '🎙️ Voice memo\\n';
	String get msg_system_default => 'System default';
	String get msg_all_memos_2 => 'All memos';
	String get msg_network_request_failed => 'Network request failed';
	String get msg_memo_not_found => 'Memo not found';
	String msg_playback_failed_2({required Object e}) => 'Playback failed: ${e}';
	String get msg_sync_settings_webdav_across_devices => 'Sync settings to WebDAV across devices.';
	String get msg_offline_first_client_memos_backend => 'An offline-first client for the Memos backend.';
	String get msg_user_guide => 'User Guide';
	String get msg_notice => 'Notice';
	String get msg_exact_alarms => 'Exact alarms';
	String get msg_restoring_overwrite_local_library_files_rebuild => 'Restoring will overwrite local library files and rebuild the database. This cannot be undone.';
	String get msg_enter_api_url_ai_settings => 'Please enter API URL in AI settings';
	String msg_create_failed_2({required Object e}) => 'Create failed: ${e}';
	String get msg_close_search => 'Close search';
	String get msg_imported_memos_2 => 'Imported memos';
	String get msg_explore => 'Explore';
	String get msg_network_connection_failed => 'Network connection failed.';
	String msg_save_failed_3({required Object e}) => 'Save failed: ${e}';
	String get msg_no_summary_share => 'No summary to share';
	String get msg_custom_model => 'Custom Model';
	String msg_sign_failed({required Object message}) => 'Sign-in failed: ${message}';
	String get msg_notification_exact_alarm_permissions_required_send => 'Notification and exact alarm permissions are required to send reminders on time.';
	String get msg_random_review => 'Random Review';
	String get msg_public => 'Public';
	String get msg_all_2 => 'All';
	String get msg_add_custom_model => 'Add custom model';
	String get msg_backup_password => 'Backup password';
	String get msg_optional_used_sign_requests => 'Optional. Used to sign requests.';
	String get msg_search => 'Search';
	String get msg_set_password => 'Set Password';
	String get msg_submit_logs => 'Submit Logs';
	String get msg_activity_heatmap_2 => 'ACTIVITY HEATMAP';
	String get msg_invalid_api_key_insufficient_permissions => 'Invalid API key or insufficient permissions.';
	String get msg_data_has_been_migrated_app_successfully => 'Your data has been migrated to this app successfully.';
	String get msg_get_version => 'Get the new version';
	String get msg_token_source => 'Token Source';
	String get msg_send => 'Send';
	String get msg_no_pending_sync_tasks => 'No pending sync tasks';
	String get msg_locating_memo_content => 'Locating memo content';
	String get msg_offline_ready => 'Offline Ready';
	String get msg_use_relative_path => 'Use a relative path';
	String get msg_total => 'Total';
	String get msg_location_2 => 'Location';
	String get msg_show_location_metadata_memos_not_configured => 'Show location metadata on memos. If not configured, coordinates will be shown instead.';
	String get msg_api_url => 'API URL';
	String get msg_parsing_progress => 'Parsing progress';
	String get msg_parsing => 'Parsing';
	String get msg_custom => 'Custom';
	String get msg_tags_created => 'New tags created';
	String get msg_third_party_share_disabled => 'Third-party share is disabled';
	String get msg_loading_links => 'Loading links...';
	String get msg_how_report => 'How to report?';
	String get msg_confirm_password_2 => 'Confirm password';
	String get msg_search_title_content_tags => 'Search by title, content, or tags';
	String msg_reset_failed({required Object e}) => 'Reset failed: ${e}';
	String get msg_debug_preview_update_dialog => 'Debug: Preview update dialog';
	String get msg_what_s => 'What\'s new?';
	String get msg_ringtone => 'Ringtone';
	String get msg_unable_detect_backend_version_check_server => 'Unable to detect backend version. Check the server URL or network.';
	String get msg_pending_2 => 'Pending';
	String get msg_parsing_html => 'Parsing HTML...';
	String get msg_actions => 'Actions';
	String get msg_import_complete_2 => 'Import Complete';
	String get msg_use_disk => 'Use disk';
	String get msg_root_path => 'Root path';
	String get msg_disabled => 'Disabled';
	String get msg_improved_2 => 'Improved: ';
	String get msg_city => 'City';
	String get msg_decoding_zip => 'Decoding ZIP...';
	String get msg_notification_content => 'Notification content';
	String get msg_resolve_conflict => 'Resolve conflict';
	String get msg_webhooks_not_supported_server => 'Webhooks are not supported on this server.';
	String get msg_may_delayed => ' (may be delayed)';
	String get msg_permissions_system_settings => 'Permissions & system settings';
	String get msg_waiting_tasks_stop => 'Waiting for tasks to stop';
	String get msg_done_2 => 'Done';
	String get msg_parsing_memoflow_export => 'Parsing MemoFlow export...';
	String msg_location_updated({required Object next_displayText_fractionDigits_6}) => 'Location updated: ${next_displayText_fractionDigits_6}';
	String get msg_checking_server_version => 'Checking server version...';
	String get msg_next_time_back_fixing_bugs => '👀 Next time, back to fixing bugs';
	String msg_ago_4({required Object weeks}) => '${weeks} ago';
	String get msg_import => 'Import';
	String get msg_ios_long_press_home_screen_add => 'On iOS, long-press the home screen to add MemoFlow widgets';
	String get msg_create_token_2 => 'Create Token';
	String get msg_marked_read => 'Marked as read';
	String get msg_pinned => 'Pinned';
	String get msg_version_update => 'Version update';
	String get msg_allow_private_memos => 'Allow private memos';
	String get msg_token_copied_clipboard => 'Token copied to clipboard';
	String get msg_keeping_more_versions_uses_more_storage => 'Keeping more versions uses more storage. Consider cleaning old versions.';
	String get msg_delete_webhook => 'Delete Webhook';
	String get msg_prompt => 'Prompt';
	String get msg_location_precision => 'Location precision';
	String get msg_password_required => 'Password required';
	String get msg_exit_app => 'Exit app';
	String get msg_thanks_energy_fully_restored => 'Thanks! Energy fully restored ⚡';
	String get msg_connection_timeout_check_network_api_url => 'Connection timeout. Check network or API URL.';
	late final _StringsStringsLegacyAppLanguageEn app_language = _StringsStringsLegacyAppLanguageEn._(_root);
	late final _StringsStringsLegacyAppThemeEn app_theme = _StringsStringsLegacyAppThemeEn._(_root);
	late final _StringsStringsLegacyAppFontSizeEn app_font_size = _StringsStringsLegacyAppFontSizeEn._(_root);
	late final _StringsStringsLegacyAppLineHeightEn app_line_height = _StringsStringsLegacyAppLineHeightEn._(_root);
	late final _StringsStringsLegacyLaunchActionEn launch_action = _StringsStringsLegacyLaunchActionEn._(_root);
	late final _StringsStringsLegacyAutoLockTimeEn auto_lock_time = _StringsStringsLegacyAutoLockTimeEn._(_root);
	late final _StringsStringsLegacyReminderEn reminder = _StringsStringsLegacyReminderEn._(_root);
	late final _StringsStringsLegacyLocationEn location = _StringsStringsLegacyLocationEn._(_root);
	late final _StringsStringsLegacyWebdavEn webdav = _StringsStringsLegacyWebdavEn._(_root);
	String import_count_memos({required Object count}) => '${count}';
	String import_count_attachments({required Object count}) => '${count}';
	late final _StringsStringsLegacyAppDrawerEn app_drawer = _StringsStringsLegacyAppDrawerEn._(_root);
	late final _StringsStringsLegacyAiSummaryEn ai_summary = _StringsStringsLegacyAiSummaryEn._(_root);
}

// Path: strings.login.mode
class _StringsStringsLoginModeEn {
	_StringsStringsLoginModeEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get password => 'Username & Password';
	String get token => 'Token';
	String get descPassword => 'Sign in with username and password';
	String get descToken => 'Sign in with Personal Access Token';
	String get signInMethod => 'Sign-in method';
}

// Path: strings.login.field
class _StringsStringsLoginFieldEn {
	_StringsStringsLoginFieldEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get serverUrlLabel => 'Server URL';
	String get serverUrlHint => 'http://localhost:5230';
	String get usernameLabel => 'Username';
	String get usernameHint => 'Enter username';
	String get passwordLabel => 'Password';
	String get passwordHint => 'Enter password';
	String get tokenLabel => 'Token (PAT)';
	String get tokenHint => 'Token (PAT)';
}

// Path: strings.login.validation
class _StringsStringsLoginValidationEn {
	_StringsStringsLoginValidationEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get serverUrlRequired => 'Please enter server URL';
	String get serverUrlInvalid => 'Enter full URL (including http/https and port)';
	String get usernameRequired => 'Please enter username';
	String get passwordRequired => 'Please enter password';
	String get tokenRequired => 'Please enter token';
}

// Path: strings.login.compatibility
class _StringsStringsLoginCompatibilityEn {
	_StringsStringsLoginCompatibilityEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get title => 'Compatibility Mode';
	String get description => 'Use legacy endpoints (for older Memos servers)';
}

// Path: strings.login.connect
class _StringsStringsLoginConnectEn {
	_StringsStringsLoginConnectEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get connecting => 'Connecting…';
	String get action => 'Connect';
}

// Path: strings.login.errors
class _StringsStringsLoginErrorsEn {
	_StringsStringsLoginErrorsEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get authFailedToken => 'Authentication failed. Check that the token is valid and not expired.';
	String get authFailedPat => 'Authentication failed. For new Memos use a PAT starting with memos_pat_ (do not paste the Bearer prefix).';
	String connectionFailedWithMessage({required Object message}) => 'Connection failed: ${message}';
	String connectionFailed({required Object error}) => 'Connection failed: ${error}';
	String get signInFailed => 'Sign-in failed. Check username and password.';
	String signInFailedWithMessage({required Object message}) => 'Sign-in failed: ${message}';
	String get invalidServerUrl => 'Invalid server URL';
	String get serverUrlNormalized => 'Server URL normalized (removed extra path segments)';
}

// Path: strings.settings.preferences
class _StringsStringsSettingsPreferencesEn {
	_StringsStringsSettingsPreferencesEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get title => 'Preferences';
	String get language => 'Language';
	String get fontSize => 'Font Size';
	String get lineHeight => 'Line Height';
	String get font => 'Font';
	String get systemDefault => 'System Default';
	String get noSystemFonts => 'No system fonts found';
	String loadFontsFailed({required Object error}) => 'Failed to load fonts: ${error}';
	String get collapseLongContent => 'Collapse Long Content';
	String get collapseReferences => 'Collapse References';
	String get showEngagementInAllMemoDetails => 'Show likes and comments in all memo details';
	String get launchAction => 'Launch Action';
	String get quickInputKeyboard => 'Auto-open keyboard for Quick Input';
	String get appearance => 'Appearance';
	String get themeColor => 'Theme Color';
	String get haptics => 'Haptics';
	String get customTheme => 'Custom Theme';
	String get history => 'History';
	String get lightMode => 'Light Mode';
	String get darkMode => 'Dark Mode';
	String get surfaces => 'Surfaces';
	String get background => 'Background';
	String get backgroundColor => 'Background Color';
	String get card => 'Card';
	String get cardColor => 'Card Color';
	String get border => 'Border';
	String get borderColor => 'Border Color';
}

// Path: strings.legacy.app_language
class _StringsStringsLegacyAppLanguageEn {
	_StringsStringsLegacyAppLanguageEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get system => 'Follow System';
	String get zh_hans => 'Chinese (Simplified)';
	String get zh_hant_tw => 'Chinese (Traditional, China Taiwan)';
	String get en => 'English';
	String get ja => 'Japanese';
	String get de => 'German';
}

// Path: strings.legacy.app_theme
class _StringsStringsLegacyAppThemeEn {
	_StringsStringsLegacyAppThemeEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get system => 'System';
	String get light => 'Light';
	String get dark => 'Dark';
}

// Path: strings.legacy.app_font_size
class _StringsStringsLegacyAppFontSizeEn {
	_StringsStringsLegacyAppFontSizeEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get standard => 'Standard';
	String get large => 'Large';
	String get small => 'Small';
}

// Path: strings.legacy.app_line_height
class _StringsStringsLegacyAppLineHeightEn {
	_StringsStringsLegacyAppLineHeightEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get classic => 'Classic';
	String get compact => 'Compact';
	String get relaxed => 'Relaxed';
}

// Path: strings.legacy.launch_action
class _StringsStringsLegacyLaunchActionEn {
	_StringsStringsLegacyLaunchActionEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get none => 'None';
	String get sync => 'Sync';
	String get quick_input => 'Quick Input';
	String get daily_review => 'Random Review';
}

// Path: strings.legacy.auto_lock_time
class _StringsStringsLegacyAutoLockTimeEn {
	_StringsStringsLegacyAutoLockTimeEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get immediately => 'Immediately';
	String get after_1_min => '1 minute';
	String get after_5_min => '5 minutes';
	String get after_15_min => '15 minutes';
}

// Path: strings.legacy.reminder
class _StringsStringsLegacyReminderEn {
	_StringsStringsLegacyReminderEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get default_title => 'Hey, remember this idea?';
	String get default_body => 'Tap to view details';
}

// Path: strings.legacy.location
class _StringsStringsLegacyLocationEn {
	_StringsStringsLegacyLocationEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get current => 'Current location';
}

// Path: strings.legacy.webdav
class _StringsStringsLegacyWebdavEn {
	_StringsStringsLegacyWebdavEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get not_configured => 'WebDAV is not configured';
	String get backup_disabled => 'Backup is disabled';
	String get backup_account_missing => 'Account missing for backup';
	String get backup_local_only => 'Backup is available only for local libraries';
	String get backup_password_missing => 'Backup password missing';
	String get backup_no_memo_files => 'No memo files found in local library; backup cancelled';
	String get restore_account_missing => 'Account missing for restore';
	String get restore_local_only => 'Restore is only available for local libraries';
	String get backup_empty => 'Backup is empty';
	String get backup_no_memos => 'No memos found in backup';
	String get snapshot_missing => 'Backup snapshot missing';
	String get snapshot_corrupted => 'Backup snapshot corrupted';
	String get object_missing => 'Backup object missing';
	String get config_corrupted => 'Backup config corrupted';
	String get config_invalid => 'Invalid backup config';
	String get password_invalid => 'Invalid backup password';
	String get data_corrupted => 'Backup data corrupted';
	String get server_url_invalid => 'Invalid WebDAV server URL';
}

// Path: strings.legacy.app_drawer
class _StringsStringsLegacyAppDrawerEn {
	_StringsStringsLegacyAppDrawerEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String tooltip_single({required Object date, required Object weekday, required Object count}) => '${date} (${weekday}) · ${count} memo';
	String tooltip_multi({required Object date, required Object weekday, required Object count}) => '${date} (${weekday}) · ${count} memos';
}

// Path: strings.legacy.ai_summary
class _StringsStringsLegacyAiSummaryEn {
	_StringsStringsLegacyAiSummaryEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get error_api_key_empty => 'API key is empty';
	late final _StringsStringsLegacyAiSummarySystemEn system = _StringsStringsLegacyAiSummarySystemEn._(_root);
	late final _StringsStringsLegacyAiSummaryUserEn user = _StringsStringsLegacyAiSummaryUserEn._(_root);
	String get error_invalid_response => 'AI response has an invalid format';
	String get error_empty_response => 'AI response is empty';
	String get error_missing_content => 'AI response content is missing';
	String get default_prompt => 'You are a minimalist note assistant. Extract key points and present them in a clean format. Keep the tone professional, warm, and concise. Prefer lists and short paragraphs.';
}

// Path: strings.legacy.ai_summary.system
class _StringsStringsLegacyAiSummarySystemEn {
	_StringsStringsLegacyAiSummarySystemEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String get require_json => 'Please output JSON strictly. Do not use code blocks or extra text.';
	String get json_format => 'JSON format: {"insights":["..."],"moodTrend":"...","keywords":["#..."]}';
	String get insights_rule => 'insights should be 2-5 items; keywords should be 4-8 items with #.';
}

// Path: strings.legacy.ai_summary.user
class _StringsStringsLegacyAiSummaryUserEn {
	_StringsStringsLegacyAiSummaryUserEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	String range({required Object rangeLabel}) => 'Time range: ${rangeLabel}';
	String counts({required Object memoCount, required Object includedCount}) => 'Memos: ${memoCount} (included for summary: ${includedCount})';
	String profile({required Object profile}) => 'User profile: ${profile}';
	String custom_prompt({required Object customPrompt}) => 'Additional instructions: ${customPrompt}';
	String get memo_content => 'Memo content:';
}

// Path: <root>
class _StringsDe extends Translations {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	_StringsDe.build({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = TranslationMetadata(
		    locale: AppLocale.de,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super.build(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		super.$meta.setFlatMapFunction($meta.getTranslation); // copy base translations to super.$meta
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <de>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key) ?? super.$meta.getTranslation(key);

	@override late final _StringsDe _root = this; // ignore: unused_field

	// Translations
	@override late final _StringsStringsDe strings = _StringsStringsDe._(_root);
}

// Path: strings
class _StringsStringsDe extends _StringsStringsEn {
	_StringsStringsDe._(_StringsDe root) : this._root = root, super._(root);

	@override final _StringsDe _root; // ignore: unused_field

	// Translations
	@override late final _StringsStringsCommonDe common = _StringsStringsCommonDe._(_root);
	@override late final _StringsStringsLanguagesDe languages = _StringsStringsLanguagesDe._(_root);
	@override late final _StringsStringsLanguagesNativeDe languagesNative = _StringsStringsLanguagesNativeDe._(_root);
	@override late final _StringsStringsOnboardingDe onboarding = _StringsStringsOnboardingDe._(_root);
	@override late final _StringsStringsLoginDe login = _StringsStringsLoginDe._(_root);
	@override late final _StringsStringsSettingsDe settings = _StringsStringsSettingsDe._(_root);
	@override late final _StringsStringsLegacyDe legacy = _StringsStringsLegacyDe._(_root);
}

// Path: strings.common
class _StringsStringsCommonDe extends _StringsStringsCommonEn {
	_StringsStringsCommonDe._(_StringsDe root) : this._root = root, super._(root);

	@override final _StringsDe _root; // ignore: unused_field

	// Translations
	@override String get back => 'Zurück';
	@override String get cancel => 'Abbrechen';
	@override String get confirm => 'Bestätigen';
	@override String get save => 'Speichern';
	@override String get saveSettings => 'Einstellungen speichern';
	@override String get auto => 'Automatisch';
	@override String get manual => 'Manuell';
	@override String get copiedToClipboard => 'In die Zwischenablage kopiert';
	@override String get serverVersion => 'Serverversion';
	@override String get selectValidServerVersion => 'Bitte eine gültige Serverversion auswählen';
	@override String serverVersionValue({required Object version}) => 'Serverversion: ${version}';
	@override String get selectServerVersionRange021To026 => 'Bitte wählen Sie manuell eine Serverversion zwischen 0.21 und 0.26';
}

// Path: strings.languages
class _StringsStringsLanguagesDe extends _StringsStringsLanguagesEn {
	_StringsStringsLanguagesDe._(_StringsDe root) : this._root = root, super._(root);

	@override final _StringsDe _root; // ignore: unused_field

	// Translations
	@override String get system => 'System folgen';
	@override String get zhHans => 'Chinesisch (Vereinfacht)';
	@override String get zhHantTw => 'Chinesisch (Traditionell, China Taiwan)';
	@override String get en => 'Englisch';
	@override String get ja => 'Japanisch';
	@override String get de => 'Deutsch';
}

// Path: strings.languagesNative
class _StringsStringsLanguagesNativeDe extends _StringsStringsLanguagesNativeEn {
	_StringsStringsLanguagesNativeDe._(_StringsDe root) : this._root = root, super._(root);

	@override final _StringsDe _root; // ignore: unused_field

	// Translations
	@override String get system => 'System';
	@override String get zhHans => '简体中文';
	@override String get zhHantTw => '繁體中文（中國台灣）';
	@override String get en => 'English';
	@override String get ja => '日本語';
	@override String get de => 'Deutsch';
}

// Path: strings.onboarding
class _StringsStringsOnboardingDe extends _StringsStringsOnboardingEn {
	_StringsStringsOnboardingDe._(_StringsDe root) : this._root = root, super._(root);

	@override final _StringsDe _root; // ignore: unused_field

	// Translations
	@override String get tagline => 'Minimaler, leistungsstarker Notiz-Stream';
	@override String get selectLanguage => 'Sprache auswählen';
	@override String get selectMode => 'Modus wählen';
	@override String get modeHint => 'Sie können dies später in den Einstellungen ändern.';
	@override String get modeLocalTitle => 'Lokaler Modus';
	@override String get modeLocalLabel => 'LOKALER MODUS';
	@override String get modeLocalDesc => 'Daten bleiben auf dem Gerät. Keine Server-Einrichtung erforderlich – ideal für Datenschutz und Offline-Nutzung.';
	@override String get modeServerTitle => 'Servermodus';
	@override String get modeServerLabel => 'SERVERMODUS';
	@override String get modeServerDesc => 'Verbinden Sie Ihr Memos-Backend für die Echtzeit-Synchronisierung auf mehreren Geräten.';
	@override String get localLibraryNameTitle => 'Name der lokalen Bibliothek';
	@override String get localLibraryNameHint => 'Name eingeben';
	@override String get localLibraryDefaultName => 'Lokale Bibliothek';
	@override String get getStarted => 'Loslegen';
}

// Path: strings.login
class _StringsStringsLoginDe extends _StringsStringsLoginEn {
	_StringsStringsLoginDe._(_StringsDe root) : this._root = root, super._(root);

	@override final _StringsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mit Memos verbinden';
	@override late final _StringsStringsLoginModeDe mode = _StringsStringsLoginModeDe._(_root);
	@override late final _StringsStringsLoginFieldDe field = _StringsStringsLoginFieldDe._(_root);
	@override late final _StringsStringsLoginValidationDe validation = _StringsStringsLoginValidationDe._(_root);
	@override late final _StringsStringsLoginCompatibilityDe compatibility = _StringsStringsLoginCompatibilityDe._(_root);
	@override late final _StringsStringsLoginConnectDe connect = _StringsStringsLoginConnectDe._(_root);
	@override late final _StringsStringsLoginErrorsDe errors = _StringsStringsLoginErrorsDe._(_root);
}

// Path: strings.settings
class _StringsStringsSettingsDe extends _StringsStringsSettingsEn {
	_StringsStringsSettingsDe._(_StringsDe root) : this._root = root, super._(root);

	@override final _StringsDe _root; // ignore: unused_field

	// Translations
	@override late final _StringsStringsSettingsPreferencesDe preferences = _StringsStringsSettingsPreferencesDe._(_root);
}

// Path: strings.legacy
class _StringsStringsLegacyDe extends _StringsStringsLegacyEn {
	_StringsStringsLegacyDe._(_StringsDe root) : this._root = root, super._(root);

	@override final _StringsDe _root; // ignore: unused_field

	// Translations
	@override String get msg_memos_backend_docs => 'MemoFlow-Backend-Dokumentation';
	@override String get msg_remember_moment_feel_warmth_life_take => 'Erinnere dich an den Moment und spüre die Wärme des Lebens.\\nMach jeden Tag eine kurze Rückschau.';
	@override String get msg_sure_want_delete_shortcut => 'Möchten Sie diese Verknüpfung wirklich löschen?';
	@override String get msg_scan_completed => 'Scan abgeschlossen';
	@override String get msg_confirm => 'Bestätigen';
	@override String get msg_unable_open_browser_install_browser_app => 'Browser kann nicht geöffnet werden. Bitte installieren Sie eine Browser-App.';
	@override String get msg_contributors => 'Mitwirkende';
	@override String get msg_enter_keywords_search_box_query_local => 'Geben Sie Schlüsselwörter in das Suchfeld ein, um lokale Inhalte und Tags zu durchsuchen. Funktioniert offline; warten Sie bei der ersten Nutzung, bis die lokale Indizierung abgeschlossen ist.';
	@override String get msg_memo_not_found_locally => 'Memo lokal nicht gefunden';
	@override String get msg_token => 'Token';
	@override String get msg_last_7_days => 'Letzte 7 Tage';
	@override String get msg_search_memo_content => 'Memo-Inhalt durchsuchen';
	@override String get msg_retry_started => 'Erneuter Versuch gestartet';
	@override String msg_last_year_memos({required Object lastYearMemos}) => 'Letztes Jahr: ${lastYearMemos} Memos';
	@override String get msg_no_content_yet => 'Noch kein Inhalt';
	@override String get msg_no_summary_yet => 'Noch keine Zusammenfassung';
	@override String get msg_sooner => ' früher!';
	@override String get msg_token_copied => 'Token kopiert';
	@override String get msg_share => 'Teilen';
	@override String get msg_gallery_permission_required => 'Galerieberechtigung erforderlich';
	@override String get msg_basic_settings => 'Grundeinstellungen';
	@override String get msg_bad_ssl_certificate => 'Ungültiges SSL-Zertifikat.';
	@override String get msg_no_notifications => 'Keine Benachrichtigungen';
	@override String get msg_import_markdown => 'Aus Markdown importieren';
	@override String get msg_upload_zip_package_md_files => 'Laden Sie ein .zip-Paket mit .md-Dateien hoch';
	@override String get msg_request_send_timeout_try => 'Zeitüberschreitung beim Senden der Anfrage. Versuchen Sie es erneut.';
	@override String get msg_select_date_range => 'Datumsbereich auswählen';
	@override String get msg_delete_shortcut => 'Verknüpfung löschen';
	@override String get msg_auto_lock_time => 'Zeit bis zur automatischen Sperre';
	@override String get msg_replacing_delete_original_attachment_continue => 'Beim Ersetzen wird der ursprüngliche Anhang gelöscht. Fortfahren?';
	@override String get msg_add_least_one_condition => 'Bitte fügen Sie mindestens eine Bedingung hinzu.';
	@override String get msg_upload_images_image_bed_append_links => 'Laden Sie Bilder in den Bildspeicher hoch und fügen Sie Links zum Memo hinzu.';
	@override String get msg_request_cancelled => 'Anfrage abgebrochen.';
	@override String get msg_generating => 'Wird generiert?';
	@override String get msg_permissions_denied_reminders_disabled => 'Berechtigungen verweigert. Erinnerungen deaktiviert.';
	@override String get msg_memoflow_local_reminders => 'MemoFlow lokale Erinnerungen';
	@override String get msg_use_legacy_endpoints_older_memos_servers => 'Verwenden Sie Legacy-Endpunkte (für ältere Memos-Server).';
	@override String get msg_no_comments_yet => 'Noch keine Kommentare';
	@override String get msg_open => 'Öffnen';
	@override String get msg_microphone_permission_required => 'Mikrofonberechtigung erforderlich';
	@override String msg_failed_react({required Object e}) => 'Reaktion fehlgeschlagen: ${e}';
	@override String get msg_restore_backup => 'Backup wiederherstellen?';
	@override String get msg_qr_saved_gallery => 'QR in Galerie gespeichert';
	@override String get msg_no_attachments => 'Keine Anhänge';
	@override String get msg_enable_reminder_permissions => 'Erinnerungsberechtigungen aktivieren';
	@override String get msg_created_time => 'Erstellungszeit ↑';
	@override String get msg_prompt_saved_quick_prompts => 'Ihr Prompt wird in den Schnell-Prompts gespeichert';
	@override String get msg_remember_password => 'Passwort merken';
	@override String get msg_enter_valid_url => 'Bitte geben Sie eine gültige URL ein';
	@override String get msg_may_take_few_seconds => 'Dies kann einige Sekunden dauern';
	@override String msg_local_sync_failed({required Object type, required Object memoError}) => 'Lokale Synchronisierung fehlgeschlagen (${type}): ${memoError}';
	@override String get msg_webdav_sync => 'WebDAV-Synchronisierung';
	@override String get msg_clear => 'Löschen';
	@override String get msg_clear_recycle_bin_confirm => 'Papierkorb leeren? Alle Einträge werden dauerhaft gelöscht.';
	@override String get msg_save_failed => 'Speichern fehlgeschlagen';
	@override String get msg_endpoint_not_found_version_mismatch => 'Endpunkt nicht gefunden (Versionskonflikt?)';
	@override String get msg_enable_webdav_sync => 'WebDAV-Synchronisierung aktivieren';
	@override String get msg_local_libraries => 'Lokale Bibliotheken';
	@override String get msg_apply => 'Anwenden';
	@override String get msg_restore_only_available_local_libraries => 'Wiederherstellung ist nur für lokale Bibliotheken verfügbar.';
	@override String get msg_sign => 'Abmelden?';
	@override String get msg_reminders_disabled => 'Erinnerungen sind deaktiviert';
	@override String get msg_downloading => 'Wird heruntergeladen...';
	@override String get msg_path => 'Pfad';
	@override String get msg_match_any => 'Beliebige Übereinstimmung';
	@override String get msg_local_db_pending_queue => 'Lokale DB + ausstehende Warteschlange';
	@override String msg_scan_failed({required Object e}) => 'Scan fehlgeschlagen: ${e}';
	@override String get msg_user => 'Benutzer';
	@override String get msg_pick_future_time => 'Wählen Sie einen zukünftigen Zeitpunkt';
	@override String get msg_include_pending_queue => 'Ausstehende Warteschlange einschließen';
	@override String get msg_enter_days => 'Tage eingeben';
	@override String get msg_times => 'Zeiten';
	@override String get msg_token_returned_only_once_cannot_fetched => 'Das Token wird nur einmal zurückgegeben und kann nicht erneut abgerufen werden';
	@override String msg_quoted_lines({required Object quoteLines}) => 'Zitierte ${quoteLines} Zeilen';
	@override String get msg_use_remote => 'Remote verwenden';
	@override String get msg_enable_memo_location => 'Memo-Standort aktivieren';
	@override String get msg_failed_get_location => 'Standort konnte nicht abgerufen werden';
	@override String get msg_after_import_memos_sync_list_automatically => 'Nach dem Import werden Ihre Memos automatisch mit der Liste synchronisiert. Stellen Sie bei ZIP-Importen sicher, dass die Dateistruktur intakt ist.';
	@override String get msg_legacy_mode => 'Legacy-Modus';
	@override String get msg_signed => 'Angemeldet';
	@override String get msg_shortcut_includes_advanced_conditions_saving_overwrite => 'Diese Verknüpfung enthält erweiterte Bedingungen. Beim Speichern werden sie überschrieben.';
	@override String get msg_no_results_found => 'Keine Ergebnisse gefunden';
	@override String msg_reply({required Object replyName}) => 'Antworten ${replyName}...';
	@override String get msg_copy => 'Kopieren';
	@override String get msg_enable_reminders_memos => 'Erinnerungen für deine Memos aktivieren.';
	@override String get msg_comment => 'Kommentar';
	@override String get msg_added_voice_attachment => 'Sprachanhang hinzugefügt.';
	@override String get msg_customize_sidebar => 'Seitenleiste anpassen';
	@override String get msg_coffee_add_drumstick => '☕ Dann eben Kaffee / füge einen Drumstick hinzu';
	@override String get msg_pin => 'Anheften';
	@override String get msg_enter_password_continue => 'Passwort eingeben, um fortzufahren';
	@override String get msg_remove_local_library => 'Lokale Bibliothek entfernen?';
	@override String get msg_comment_2 => 'Neuer Kommentar';
	@override String get msg_sync_all => 'Alle synchronisieren';
	@override String get msg_backup_schedule => 'Sicherungszeitplan';
	@override String get msg_server_error => 'Serverfehler';
	@override String get msg_analyzing_memos => 'Deine Memos werden analysiert...';
	@override String get msg_notification => 'Benachrichtigung';
	@override String get msg_policy => 'Richtlinie';
	@override String msg_failed_load({required Object error}) => 'Laden fehlgeschlagen: ${error}';
	@override String get msg_default_visibility => 'Standard-Sichtbarkeit';
	@override String get msg_filter => 'Filter';
	@override String get msg_imported_memos => 'Memos importiert';
	@override String get msg_token_created => 'Token erstellt';
	@override String get msg_server_response_timeout_try => 'Zeitüberschreitung bei Serverantwort. Versuche es erneut.';
	@override String get msg_expiring => 'Läuft ab';
	@override String get msg_delete_task => 'Aufgabe löschen';
	@override String get msg_body_must_json => 'Body muss JSON sein';
	@override String get msg_enable => 'Aktivieren';
	@override String get msg_referenced => 'Referenziert von';
	@override String get msg_replace_image => 'Bild ersetzen?';
	@override String get msg_debug_logs => 'Debug-Protokolle';
	@override String get msg_active_tasks => 'Aktive Aufgaben';
	@override String get msg_attachments => 'Anhänge';
	@override String get msg_range => 'Bereich';
	@override String get msg_no_backups_found => 'Keine Sicherungen gefunden';
	@override String get msg_create_memo => 'Memo erstellen';
	@override String get msg_street => 'Straße';
	@override String get msg_display_name => 'Anzeigename';
	@override String get msg_full_text_search => 'Volltextsuche';
	@override String get msg_create_edit_delete_actions_offline_stored => 'Erstellen-/Bearbeiten-/Löschen-Aktionen im Offline-Modus werden lokal gespeichert und zur Synchronisierung in eine Warteschlange gestellt. Sie werden online der Reihenfolge nach gesendet. Um Fehler zu vermeiden, können nicht übermittelte Bearbeitungen als Entwürfe behalten werden.';
	@override String get msg_sign_2 => 'Abmelden';
	@override String get msg_end_time => 'Endzeit';
	@override String get msg_sync_recent_content => 'Aktuelle Inhalte synchronisieren';
	@override String get msg_resetting_local_data => 'Lokale Daten werden zurückgesetzt...';
	@override String get msg_incorrect_password => 'Falsches Passwort';
	@override String get msg_content_cannot_empty => 'Inhalt darf nicht leer sein';
	@override String get msg_preparing => 'Wird vorbereitet';
	@override String msg_ai_summary_failed({required Object formatSummaryError_e}) => 'KI-Zusammenfassung fehlgeschlagen: ${formatSummaryError_e}';
	@override String get msg_manage => 'Verwalten';
	@override String get msg_keep_data_consistent_across_devices => 'Daten auf allen Geräten konsistent halten.';
	@override String msg_playback_failed({required Object e}) => 'Wiedergabe fehlgeschlagen: ${e}';
	@override String get msg_path_copied => 'Pfad kopiert';
	@override String get msg_auth_settings => 'Authentifizierungseinstellungen';
	@override String get msg_randomly_draw_memo_cards => 'Ziehe zufällig deine Memo-Karten';
	@override String get msg_copy_log_text => 'Protokolltext kopieren';
	@override String get msg_yes => 'Ja';
	@override String get msg_save_open_alipay_scan => 'Speichern und Alipay zum Scannen öffnen';
	@override String get msg_signed_but_no_token_returned => 'Angemeldet, aber kein Token zurückgegeben';
	@override String msg_create_failed({required Object formatError_e_context}) => 'Erstellen fehlgeschlagen: ${formatError_e_context}';
	@override String get msg_expand => 'Erweitern';
	@override String get msg_local_library_only => 'Nur lokale Bibliothek';
	@override String get msg_reminder_channel => 'Erinnerungskanal';
	@override String get msg_grant => 'Gewähren';
	@override String get msg_import_canceled => 'Import abgebrochen.';
	@override String get msg_never => 'Nie';
	@override String get msg_release_notes => 'Versionshinweise';
	@override String get msg_failed_load_references => 'Referenzen konnten nicht geladen werden';
	@override String get msg_select_tags => 'Tags auswählen';
	@override String get msg_failed_load_try => 'Laden fehlgeschlagen. Bitte versuche es erneut.';
	@override String get msg_logs_copied => 'Protokolle kopiert';
	@override String get msg_shortcuts_not_supported_server => 'Kurzbefehle werden auf diesem Server nicht unterstützt.';
	@override String msg_reply_2({required Object name}) => 'Antworten ${name}...';
	@override String get msg_anonymous => 'Anonym';
	@override String get msg_username => 'Benutzername';
	@override String get msg_update_memo => 'Memo aktualisieren';
	@override String msg_saved({required Object targetPath}) => 'Gespeichert unter: ${targetPath}';
	@override String get msg_chinese_simplified => 'Chinesisch (Vereinfacht)';
	@override String get msg_memo_copied => 'Memo kopiert';
	@override String get msg_collapse => 'Einklappen';
	@override String get msg_retry_count_controls_how_many_extra => 'Die Anzahl der Wiederholungsversuche legt fest, wie viele zusätzliche Versuche bei einem Fehlschlag unternommen werden. Höhere Werte können die Erfolgsquote verbessern, dauern aber länger.';
	@override String get msg_recording_info_missing => 'Aufzeichnungsinformationen fehlen';
	@override String get msg_sync_task => 'Synchronisierungsaufgabe';
	@override String get msg_clear_all_debug_logs => 'Alle Debug-Protokolle löschen?';
	@override String get msg_export_finished => 'Export abgeschlossen';
	@override String msg_failed_stop_recording({required Object e}) => 'Aufzeichnung konnte nicht gestoppt werden: ${e}';
	@override String get msg_my_profile => 'Mein Profil';
	@override String get msg_image_bed => 'Bildspeicher';
	@override String msg_failed_open_notification({required Object e}) => 'Benachrichtigung konnte nicht geöffnet werden: ${e}';
	@override String get msg_manual => 'Handbuch';
	@override String get msg_no_html_file_found_zip => 'Keine HTML-Datei in der ZIP gefunden.';
	@override String get msg_also_clear_local_cache_account_offline => 'Dadurch wird auch der lokale Cache für dieses Konto gelöscht (Offline-Daten/Entwürfe/wartende Synchronisierungswarteschlange). Diese Aktion kann nicht rückgängig gemacht werden.';
	@override String get msg_restore => 'Wiederherstellen';
	@override String get msg_auto_backup => 'Automatische Sicherung';
	@override String get msg_generate_summary => 'Zusammenfassung erstellen';
	@override String msg_days({required Object stats_activeDays}) => '${stats_activeDays} Tage';
	@override String get msg_count => '- Anzahl';
	@override String get msg_weekly => 'Wöchentlich';
	@override String get msg_notifications => 'Benachrichtigungen';
	@override String get msg_backup_failed => 'Sicherung fehlgeschlagen';
	@override String get msg_private => 'Privat';
	@override String get msg_filter_tags => 'Nach Tags filtern';
	@override String get msg_clear_logs => 'Protokolle löschen';
	@override String get msg_unable_open_browser => 'Browser kann nicht geöffnet werden';
	@override String get msg_attachment_too_large => 'Anhang zu groß';
	@override String get msg_query => 'Abfrage';
	@override String get msg_match_all => 'Alle erfüllen';
	@override String get msg_record_request_response_logs => 'Anfrage-/Antwortprotokolle aufzeichnen';
	@override String get msg_import_file => 'Datei importieren';
	@override String get msg_content_tags => 'Inhalt + Tags';
	@override String get msg_feature_not_available_local_library_mode => 'Diese Funktion ist im Modus der lokalen Bibliothek nicht verfügbar.';
	@override String msg_import_failed({required Object e}) => 'Import fehlgeschlagen: ${e}';
	@override String get msg_save_memo => 'Als Memo speichern';
	@override String get msg_scan_disk_directory_merge_local_database => 'Datenträgerverzeichnis scannen und mit lokaler Datenbank zusammenführen? Fehlende Dateien werden als Löschungen behandelt.';
	@override String get msg_passwords_not_match => 'Passwörter stimmen nicht überein';
	@override String msg_signed_2({required Object lastLoginUser}) => 'Angemeldet als: ${lastLoginUser}';
	@override String get msg_made_love_note_taking => 'Mit Liebe fürs Notieren gemacht';
	@override String get msg_password_updated_local => 'Passwort aktualisiert (lokal)';
	@override String get msg_retry => 'Erneut versuchen';
	@override String get msg_memo_stats => 'Memo-Statistiken';
	@override String get msg_shown_only_once_copy_keep_safe => 'Wird nur einmal angezeigt, bitte kopieren und sicher aufbewahren.';
	@override String get msg_describe_issue_time_repro_steps_etc => 'Beschreibe das Problem, den Zeitpunkt, die Reproduktionsschritte usw.';
	@override String get msg_how_many_days_back => 'Wie viele Tage zurück';
	@override String get msg_local_cache_cleared => 'Lokaler Cache gelöscht';
	@override String get msg_none => 'Keine';
	@override String get msg_body_json => 'Textkörper (JSON)';
	@override String msg_download_failed({required Object e}) => 'Download fehlgeschlagen: ${e}';
	@override String get msg_recycle_bin => 'Papierkorb';
	@override String get msg_unpin => 'Lösen';
	@override String get msg_advanced_security => 'Erweitert & Sicherheit';
	@override String get msg_run_issues_memoflow_e_g_sync => 'Wenn du in MemoFlow auf Probleme stößt (z. B. Synchronisierungsfehler, Abstürze), befolge bitte die folgenden Schritte, damit wir das Problem schneller diagnostizieren und beheben können.\\n\\n';
	@override String get msg_remove_all_reminder_times_memo => 'Alle Erinnerungszeiten für dieses Memo entfernen.';
	@override String get msg_no_summary_save => 'Keine Zusammenfassung zum Speichern';
	@override String get msg_reset_language_selection => 'Sprachauswahl zurücksetzen';
	@override String get msg_v_30_days => '30 Tage';
	@override String get msg_e_g_mood_check => 'z. B. Stimmungscheck';
	@override String get msg_note_some_tokens_returned_only_once => 'Hinweis: Einige Token werden nur einmal zurückgegeben und können später nicht wieder abgerufen werden. Bitte bewahre sie sicher auf.';
	@override String get msg_syncing => 'Synchronisierung läuft...';
	@override String get msg_retention => 'Aufbewahrung';
	@override String get msg_open_login_screen => 'Anmeldebildschirm öffnen';
	@override String get msg_apply_all => 'Auf alle anwenden';
	@override String get msg_write_something_supports_tag_tasks_x => 'Schreibe etwas... Unterstützt #tag und Aufgaben [ ] / [x]';
	@override String msg_http({required Object base, required Object status, required Object msg}) => '${base} (HTTP ${status}): ${msg}';
	@override String get msg_single => 'Einzeln';
	@override String get msg_delete_memo => 'Memo löschen?';
	@override String get msg_ai_provider => 'AI-Anbieter';
	@override String msg_release_notes_v({required Object version}) => 'Versionshinweise v${version}';
	@override String get msg_info_only_used_background_ai_summaries => 'Diese Information wird nur als Hintergrund für KI-Zusammenfassungen/-Berichte verwendet und nicht mit dem Backend synchronisiert.';
	@override String get msg_not_disturb => 'Nicht stören';
	@override String msg_local_library_import_failed({required Object e}) => 'Import der lokalen Bibliothek fehlgeschlagen: ${e}';
	@override String get msg_key_insights => 'Wichtige Erkenntnisse';
	@override String get msg_additional_notes_optional => 'Zusätzliche Notizen (optional)';
	@override String get msg_server_response_error => 'Fehler in der Serverantwort.';
	@override String get msg_sort => 'Sortieren';
	@override String get msg_api_call => 'API-Aufruf';
	@override String get msg_webhooks => 'Webhooks';
	@override String get msg_local_library => 'Lokale Bibliothek';
	@override String get msg_log_copied => 'Protokoll kopiert';
	@override String get msg_last_success => 'Letzter Erfolg';
	@override String get msg_restore_cloud => 'Aus der Cloud wiederherstellen';
	@override String get msg_search_public_memos => 'Öffentliche Memos durchsuchen';
	@override String get msg_cancel => 'Abbrechen';
	@override String msg_processing({required Object processed, required Object total}) => 'Verarbeite ${processed} / ${total}';
	@override String get msg_failed_items => 'Fehlgeschlagene Elemente';
	@override String get msg_recording_file_not_found => 'Aufnahmedatei nicht gefunden';
	@override String get msg_local_db_outbox_queue => 'Lokale DB + Outbox-Warteschlange';
	@override String get msg_remove => 'Entfernen';
	@override String get msg_export_format => 'Exportformat';
	@override String get msg_idle => 'Leerlauf';
	@override String msg_ago({required Object months}) => 'vor ${months}';
	@override String get msg_no_tags_yet => 'Noch keine Tags';
	@override String msg_version_v({required Object version}) => 'Version v${version}';
	@override String get msg_sync => 'Synchronisieren';
	@override String get msg_done => 'Fertig';
	@override String get msg_gallery_permission_required_2 => 'Galerieberechtigung erforderlich';
	@override String get msg_insufficient_permissions => 'Unzureichende Berechtigungen';
	@override String get msg_no_download_url_available => 'Keine Download-URL verfügbar';
	@override String get msg_record_create_memos => 'Aufnehmen, um Memos zu erstellen';
	@override String get msg_signing => 'Anmeldung...';
	@override String get msg_memoflow_uses_system_location_permission_get => 'MemoFlow verwendet die Standortberechtigung des Systems, um Koordinaten zu erhalten, und führt dann eine Reverse-Geokodierung über die Amap Web API durch. Oben können Sie die Anzeigegenauigkeit auswählen.';
	@override String get msg_continue => 'Weiter';
	@override String get msg_notification_content_unavailable => 'Benachrichtigungsinhalt nicht verfügbar';
	@override String get msg_unable_read_file_path => 'Dateipfad kann nicht gelesen werden.';
	@override String get msg_all_memos => 'Alle Memos';
	@override String get msg_keywords => 'Schlüsselwörter';
	@override String get msg_import_result => 'Importergebnis';
	@override String get msg_offline_sync => 'Offline-Synchronisierung';
	@override String get msg_imported_memos_local_library => 'Memos aus der lokalen Bibliothek importiert';
	@override String get msg_request_failed => 'Anfrage fehlgeschlagen';
	@override String get msg_log_file => 'Protokolldatei';
	@override String get msg_after_confirming_support_unlock_limited_gold => 'Nach bestätigter Unterstützung schalten Sie entweder ein zeitlich begrenztes Gold-Abzeichen oder ein dauerhaft werbefreies Versprechen frei (obwohl es nie Werbung gab).';
	@override String get msg_failed_open_system_settings => 'Systemeinstellungen konnten nicht geöffnet werden';
	@override String get msg_no_mood_trend => 'Kein Stimmungstrend';
	@override String get msg_memoflow_export => '# MemoFlow-Export';
	@override String get msg_sync_queue => 'Synchronisierungswarteschlange';
	@override String get msg_only_delete_sync_task_memo_kept => 'Nur die Synchronisierungsaufgabe löschen; das Memo bleibt erhalten.';
	@override String get msg_add_home_screen => 'Zum Startbildschirm hinzufügen';
	@override String get msg_past_days => 'Vergangene Tage';
	@override String get msg_poster_generation_failed => 'Postergenerierung fehlgeschlagen';
	@override String msg_failed_load_stats({required Object e}) => 'Statistiken konnten nicht geladen werden: ${e}';
	@override String get msg_customize_notification => 'Benachrichtigung anpassen';
	@override String get msg_updated_time => 'Aktualisierte Zeit ↓';
	@override String get msg_network_connection_failed_check_network => 'Netzwerkverbindung fehlgeschlagen. Bitte überprüfen Sie Ihre Netzwerkverbindung.';
	@override String get msg_special_thanks => 'Besonderer Dank:';
	@override String msg_failed_comment({required Object e}) => 'Kommentieren fehlgeschlagen: ${e}';
	@override String get msg_security_key_sig => 'Sicherheitsschlüssel (sig)';
	@override String get msg_save_gallery => 'In Galerie speichern';
	@override String get msg_request_sent_confirm_system_prompt => 'Anfrage gesendet. Im Systemhinweis bestätigen';
	@override String get msg_server_url => 'Server-URL';
	@override String get msg_period_review => 'Zeitraumrückblick';
	@override String get msg_settings_updated => 'Einstellungen aktualisiert';
	@override String get msg_backend_0_21_not_supported_import => 'Backend 0.21 wird für den Import nicht unterstützt. Bitte aktualisieren Sie und versuchen Sie es erneut.';
	@override String msg_failed_load_tags({required Object e}) => 'Tags konnten nicht geladen werden: ${e}';
	@override String get msg_enter_email => 'E-Mail eingeben';
	@override String get msg_add_webhook => 'Webhook hinzufügen';
	@override String get msg_read => 'Gelesen';
	@override String get msg_widgets => 'Widgets';
	@override String get msg_default => 'Standard';
	@override String get msg_memo_reminders => 'Memo-Erinnerungen';
	@override String get msg_import_flomo => 'Aus Flomo importieren';
	@override String get msg_format_fixed_markdown_zip => 'Format ist auf Markdown + ZIP festgelegt';
	@override String get msg_enter_username_password => 'Benutzername und Passwort eingeben';
	@override String get msg_loading => 'Lädt...';
	@override String msg_test_scheduled({required Object timeLabel, required Object suffix, required Object pendingLabel}) => 'Test geplant um ${timeLabel}${suffix}${pendingLabel}';
	@override String get msg_edit_memo => 'Memo bearbeiten';
	@override String get msg_save => 'Speichern';
	@override String get msg_laboratory => 'Labor';
	@override String get msg_use_local => 'Lokal verwenden';
	@override String get msg_retry_sync => 'Synchronisierung erneut versuchen';
	@override String get msg_e_g_my_role_topics_interest => 'z. B. meine Rolle / interessante Themen / Präferenzen beim Schreibstil?';
	@override String get msg_confirm_password => 'Passwort bestätigen';
	@override String get msg_not_set => 'Nicht festgelegt';
	@override String get msg_no_memos_day => 'Keine Memos an diesem Tag';
	@override String get msg_shortcut_name => 'Name der Verknüpfung';
	@override String get msg_edit_shortcut => 'Verknüpfung bearbeiten';
	@override String get msg_days_memos => 'Tage mit Memos';
	@override String get msg_delete => 'Löschen';
	@override String get msg_test_reminder => 'Erinnerung testen';
	@override String get msg_enable_reminders => 'Erinnerungen aktivieren';
	@override String get msg_links => 'Links';
	@override String get msg_location => 'Standort';
	@override String get msg_import_file_2 => 'Aus Datei importieren';
	@override String msg_reply_3({required Object creatorDisplayName_commentCreator_commentMemo_creator}) => 'Antworten ${creatorDisplayName_commentCreator_commentMemo_creator}...';
	@override String msg_created({required Object widget_createdAtLabel}) => 'Erstellt ${widget_createdAtLabel}';
	@override String get msg_notifications_coming_soon => 'Benachrichtigungen: demnächst verfügbar';
	@override String get msg_view_full_contributors => 'Alle Mitwirkenden anzeigen';
	@override String get msg_no_times_set => 'Keine Zeiten festgelegt';
	@override String get msg_ignore_tls_errors => 'TLS-Fehler ignorieren';
	@override String get msg_no_content => 'Kein Inhalt';
	@override String get msg_about_15_seconds_left => 'Noch etwa 15 Sekunden';
	@override String get msg_view_imported_memos => 'Importierte Memos anzeigen';
	@override String get msg_load_failed => 'Laden fehlgeschlagen';
	@override String get msg_disk_content_conflicts_local_pending_changes => 'Der Festplatteninhalt steht in Konflikt mit lokalen ausstehenden Änderungen. Verwende die Festplatte, um den lokalen Inhalt zu überschreiben.';
	@override String get msg_all_history_so_far_memoflow_since => 'Das ist bisher die gesamte Chronik\\nMEMOFLOW SEIT 2023';
	@override String get msg_cancelling => 'Wird abgebrochen';
	@override String get msg_reading_file => 'Datei wird gelesen...';
	@override String get msg_switch_workspace => 'Arbeitsbereich wechseln';
	@override String get msg_optional_leave_empty_default => 'Optional. Für den Standard leer lassen.';
	@override String get msg_memo_reminders_2 => 'Memo-Erinnerungen';
	@override String msg_save_failed_2({required Object e}) => 'Speichern fehlgeschlagen: ${e}';
	@override String get msg_record_create_memos_sync_later => 'Aufnehmen und Memos erstellen (später synchronisieren)';
	@override String get msg_use_https_avoid_ignoring_tls_errors => 'Verwende HTTPS und vermeide das Ignorieren von TLS-Fehlern, um Anmeldedaten zu schützen.';
	@override String get msg_failed_load_announcement_config => 'Ankündigungskonfiguration konnte nicht geladen werden';
	@override String get msg_shortcuts => 'Tastenkürzel';
	@override String get msg_memo => 'Memo';
	@override String get msg_maybe_later => 'Vielleicht später';
	@override String get msg_server_connection => 'Serververbindung';
	@override String get msg_days_2 => 'Tage';
	@override String get msg_include_archived => 'Archivierte einschließen';
	@override String get msg_during_quiet_hours_reminders_silenced => 'Während der Ruhezeiten werden Erinnerungen stummgeschaltet.';
	@override String get msg_preview_not_supported_type => 'Vorschau für diesen Typ nicht unterstützt';
	@override String get msg_failed_load_2 => 'Laden fehlgeschlagen';
	@override String get msg_create_token => 'Neues Token erstellen';
	@override String get msg_enter_name => 'Bitte gib einen Namen ein.';
	@override String get msg_api_url_incorrect => 'API-URL ist falsch.';
	@override String get msg_user_general_settings => 'Allgemeine Benutzereinstellungen';
	@override String get msg_saved_memo => 'Als Memo gespeichert';
	@override String msg_restore_failed({required Object e}) => 'Wiederherstellen fehlgeschlagen: ${e}';
	@override String msg_token_tail({required Object tail}) => 'Token-Ende ${tail}';
	@override String get msg_manual_token => 'Manuelles Token';
	@override String msg_ago_2({required Object years}) => 'vor ${years}';
	@override String get msg_recent_searches => 'Letzte Suchen';
	@override String get msg_restored => 'Wiederhergestellt';
	@override String get msg_no_contributors_yet => 'Noch keine Mitwirkenden';
	@override String get msg_no_record_yet => 'Noch kein Eintrag';
	@override String get msg_reminder => 'Erinnerung';
	@override String get msg_enter_api_key_ai_settings => 'Bitte gib den API-Schlüssel in den KI-Einstellungen ein';
	@override String get msg_reminder_settings => 'Erinnerungseinstellungen';
	@override String msg_http_2({required Object base, required Object status}) => '${base} (HTTP ${status})';
	@override String get msg_edit_webhook => 'Webhook bearbeiten';
	@override String get msg_generate_share_poster => 'Share-Poster generieren';
	@override String msg_archive_failed({required Object e}) => 'Archivieren fehlgeschlagen: ${e}';
	@override String msg_comments({required Object widget_commentCount}) => '${widget_commentCount} Kommentare';
	@override String get msg_remove_account => 'Konto entfernen?';
	@override String get msg_chinese_traditional => 'Chinesisch (Traditionell)';
	@override String get msg_private_2 => 'Privat';
	@override String get msg_current_streak => 'Aktuelle Serie';
	@override String get msg_generated_ai_memoflow => 'Erstellt von KI · MemoFlow';
	@override String get msg_edit_completed => 'Bearbeitung abgeschlossen';
	@override String get msg_local => 'Lokal';
	@override String get msg_edit => 'Bearbeiten';
	@override String msg_text({required Object shortUserName_item_sender}) => 'Von ${shortUserName_item_sender}';
	@override String get msg_got => 'Verstanden';
	@override String get msg_web_api_key => 'Web-API-Schlüssel';
	@override String get msg_preview => 'Vorschau';
	@override String get msg_enter_password => 'Bitte Passwort eingeben';
	@override String get msg_api => 'API';
	@override String get msg_ok => 'OK';
	@override String get msg_failed_load_shortcuts => 'Tastenkürzel konnten nicht geladen werden.';
	@override String get msg_after_recording_audio_added_current_draft => 'Nach der Aufnahme wird die Audiodatei als Anhang zum aktuellen Entwurf hinzugefügt, sodass du sie vor dem Senden bearbeiten kannst. Die maximale Länge beträgt 60 Minuten; eine Transkription kann später über Drittanbieterdienste hinzugefügt werden.';
	@override String get msg_pull_refresh => 'Zum Aktualisieren ziehen';
	@override String get msg_unable_open_photo => 'Foto kann nicht geöffnet werden';
	@override String get msg_existing_tokens => 'Vorhandene Tokens';
	@override String get msg_ai_settings => 'KI-Einstellungen';
	@override String get msg_app_lock => 'App-Sperre';
	@override String get msg_total_notes => 'Gesamtnotizen';
	@override String get msg_stats_loading => 'Statistiken werden geladen';
	@override String get msg_enter_token_description => 'Gib eine Token-Beschreibung ein';
	@override String get msg_enter_token => 'Gib ein Token ein';
	@override String get msg_api_plugins => 'API & Plugins';
	@override String get msg_parsing_file => 'Datei wird analysiert...';
	@override String get msg_english => 'Englisch';
	@override String get msg_activity_heatmap => 'Aktivitäts-Heatmap';
	@override String get msg_mark_read => 'Als gelesen markieren';
	@override String get msg_request => 'Anfrage';
	@override String msg_sync_failed({required Object type, required Object memoError}) => 'Synchronisierung fehlgeschlagen (${type}): ${memoError}';
	@override String get msg_error_copied => 'Fehler kopiert';
	@override String get msg_only_local_index_removed_disk_files => 'Nur der lokale Index wird entfernt; die Dateien auf der Festplatte bleiben erhalten. Dies kann nicht rückgängig gemacht werden.';
	@override String get msg_switch_account => 'Konto wechseln';
	@override String get msg_invalid_download_link => 'Ungültiger Download-Link';
	@override String get msg_about => 'Info';
	@override String get msg_icon => 'Symbol';
	@override String get msg_reset_done_syncing => 'Zurücksetzen abgeschlossen. Synchronisierung läuft...';
	@override String get msg_enter_amap_web_api_key => 'Geben Sie Ihren Amap Web-API-Schlüssel ein';
	@override String get msg_recycle_bin_coming_soon => 'Papierkorb: kommt bald';
	@override String get msg_empty_content => '(Leerer Inhalt)';
	@override String get msg_note_most_features_offline_stats_ai => 'Hinweis: Die meisten Funktionen (offline/Statistiken/KI-Berichte/Export) funktionieren ohne Backend-Änderungen, aber Token werden nur einmal zurückgegeben?bitte bewahren Sie sie sicher auf.';
	@override String get msg_fixed => 'Behoben: ';
	@override String get msg_allow_sharing_links_images_other_apps => 'Erlauben Sie das Teilen von Links oder Bildern aus anderen Apps in MemoFlow.';
	@override String get msg_invalid_request_parameters => 'Ungültige Anfrageparameter';
	@override String get msg_enter_api_url => 'Bitte API-URL eingeben';
	@override String msg_pending({required Object result_pendingCount}) => ' (ausstehend ${result_pendingCount})';
	@override String msg_days_3({required Object currentStreak}) => '${currentStreak} Tage';
	@override String get msg_poster_not_ready_yet => 'Poster ist noch nicht bereit';
	@override String get msg_generated_memoflow => 'Erstellt von MemoFlow';
	@override String get msg_enter_name_2 => 'Geben Sie einen Namen ein';
	@override String get msg_version => 'Version';
	@override String get msg_memo_missing_disk_but_has_local => 'Das Memo fehlt auf der Festplatte, hat aber lokale ausstehende Änderungen. Verwenden Sie die Festplatte, um lokal zu löschen.';
	@override String get msg_legacy_api_compatibility => 'Legacy-API-Kompatibilität';
	@override String get msg_sync_parameters => 'Synchronisierungsparameter';
	@override String get msg_quick_prompts => 'Schnell-Prompts';
	@override String msg_share_failed({required Object e}) => 'Teilen fehlgeschlagen: ${e}';
	@override String get msg_no_memos_summarize_range => 'Keine Memos zum Zusammenfassen in diesem Bereich';
	@override String get msg_characters => 'Zeichen';
	@override String get msg_capture_every_moment_record => 'Halte jeden Moment fest, den du aufnimmst';
	@override String get msg_vibration => 'Vibration';
	@override String get msg_days_4 => 'Tage';
	@override String get msg_prompt_title => 'Prompt-Titel';
	@override String get msg_show_all => 'Alle anzeigen';
	@override String get msg_no_memos_available => 'Keine Memos verfügbar';
	@override String get msg_comment_unavailable => 'Kommentar nicht verfügbar';
	@override String get msg_refresh => 'Aktualisieren';
	@override String get msg_syncing_2 => 'Synchronisierung läuft';
	@override String get msg_body => 'Text';
	@override String get msg_clear_2 => 'Löschen';
	@override String get msg_third_party_share => 'Teilen über Drittanbieter';
	@override String get msg_charging_station => 'Ladestation';
	@override String get msg_attachments_2 => 'Anhänge';
	@override String get msg_when_enabled_must_verify_each_app => 'Wenn aktiviert, müssen Sie bei jedem App-Start eine Verifizierung durchführen. Die automatische Sperrzeit legt fest, wie schnell nach dem Wechsel der App in den Hintergrund eine Verifizierung erforderlich ist.';
	@override String get msg_add_prompt => 'Prompt hinzufügen';
	@override String get msg_include => 'Einschließen';
	@override String get msg_created_time_2 => 'Erstellungszeit ↓';
	@override String get msg_choose_data_source_start_importing_memos => 'Wählen Sie eine Datenquelle, um mit dem Import Ihrer Memos zu beginnen';
	@override String get msg_describe_how_want_summary => 'Beschreiben Sie, wie Sie die Zusammenfassung möchten…';
	@override String get msg_keep_token_safe_not_share_api => 'Bewahren Sie Ihr Token sicher auf und teilen Sie es nicht.\\nDas API-Rate-Limit beträgt 60 Anfragen pro Minute.';
	@override String get msg_open_2 => 'Öffnen';
	@override String get msg_e_g_claude_3_5_sonnet => 'z. B. claude-3-5-sonnet-20241022';
	@override String get msg_failed_request_whitelist => 'Whitelist konnte nicht angefordert werden';
	@override String get msg_notification_deleted => 'Benachrichtigung gelöscht';
	@override String get msg_accounts => 'Konten';
	@override String get msg_add_local_library => 'Lokale Bibliothek hinzufügen';
	@override String get msg_sign_first => 'Bitte zuerst anmelden';
	@override String get msg_failed_parse_query => 'Abfrage konnte nicht geparst werden';
	@override String get msg_note_logs_sanitized_automatically_sensitive_data => 'Hinweis: Protokolle werden automatisch bereinigt. Wenn sensible Daten verbleiben, schwärzen Sie sie vor dem Absenden.';
	@override String get msg_add => 'Hinzufügen';
	@override String msg_failed_load_3({required Object memosError}) => 'Laden fehlgeschlagen: ${memosError}';
	@override String get msg_max_chars_day => 'Max. Zeichen/Tag';
	@override String get msg_choose_what_edited_image => 'Wählen Sie aus, was mit dem bearbeiteten Bild geschehen soll.';
	@override String get msg_select => 'Auswählen';
	@override String get msg_unnamed_token => '(Unbenanntes Token)';
	@override String get msg_name => 'Name';
	@override String get msg_sure_want_delete_webhook => 'Möchten Sie diesen Webhook wirklich löschen?';
	@override String get msg_back => 'Zurück';
	@override String get msg_no => 'Nein';
	@override String get msg_untitled => 'Ohne Titel';
	@override String get msg_open_language_onboarding => 'Sprach-Einführung öffnen';
	@override String get msg_voice_memos => 'Sprachmemos';
	@override String get msg_unable_open_browser_try => 'Browser kann nicht geöffnet werden. Bitte versuchen Sie es erneut.';
	@override String get msg_date_range => 'Datumsbereich';
	@override String get msg_not_authenticated => 'Nicht authentifiziert';
	@override String get msg_back_2 => 'Zurück';
	@override String get msg_local_library_removed => 'Lokale Bibliothek entfernt';
	@override String get msg_exact_alarm_permission_required => 'Exakte Alarmberechtigung erforderlich';
	@override String get msg_visibility => 'Sichtbarkeit';
	@override String msg_failed_start_recording({required Object e}) => 'Aufnahme konnte nicht gestartet werden: ${e}';
	@override String get msg_mood_trend => 'Stimmungstrend';
	@override String get msg_local_library_name => 'Name der lokalen Bibliothek';
	@override String get msg_no_tokens_yet => 'Noch keine Tokens';
	@override String get msg_loading_2 => 'Lädt?';
	@override String get msg_location_permission_denied_permanently => 'Standortberechtigung dauerhaft verweigert';
	@override String get msg_download => 'Herunterladen';
	@override String get msg_export_time => '- Exportzeit';
	@override String get msg_enter_password_2 => 'Passwort eingeben';
	@override String get msg_no_image_available => 'Kein Bild verfügbar';
	@override String get msg_daily => 'Täglich';
	@override String get msg_no_likes_yet => 'Noch keine Likes';
	@override String get msg_basics => 'Grundlagen';
	@override String get msg_shortcut => 'Neue Verknüpfung';
	@override String get msg_debug_tools => 'Debug-Tools';
	@override String get msg_save_settings => 'Einstellungen speichern';
	@override String get msg_date_range_2 => 'Datumsbereich';
	@override String get msg_feedback => 'Feedback';
	@override String get msg_image_bed_2 => 'Bildspeicher';
	@override String get msg_restoring => 'Wird wiederhergestellt…';
	@override String get msg_export => 'Exportieren';
	@override String get msg_enter_token_name => 'Bitte Token-Namen eingeben';
	@override String get msg_start_time => 'Startzeit';
	@override String get msg_preparing_file_structure => 'Dateistruktur wird vorbereitet';
	@override String get msg_sign_3 => 'Anmelden';
	@override String get msg_scan_local_library => 'Lokale Bibliothek scannen';
	@override String get msg_lsky_pro => 'Lsky Pro';
	@override String get msg_exact_alarm_permission_off_reminders_may => 'Die Berechtigung für genaue Alarme ist deaktiviert. Erinnerungen werden möglicherweise nicht rechtzeitig ausgelöst. Einstellungen jetzt öffnen?';
	@override String get msg_last_30_days => 'Letzte 30 Tage';
	@override String get msg_match => 'Übereinstimmung';
	@override String get msg_auth_mode => 'Authentifizierungsmodus';
	@override String get msg_unsupported_file_type => 'Nicht unterstützter Dateityp.';
	@override String get msg_only_delete_sync_task => 'Nur die Synchronisierungsaufgabe löschen.';
	@override String get msg_change_password => 'Passwort ändern';
	@override String get msg_saved_2 => 'Gespeichert';
	@override String get msg_import_export => 'Import / Export';
	@override String get msg_created_2 => 'Erstellt';
	@override String get msg_ai_summary => 'KI-Zusammenfassung';
	@override String get msg_progress => 'Fortschritt';
	@override String get msg_replace_memo_image => 'Memo-Bild ersetzen';
	@override String get msg_app_settings => 'App-Einstellungen';
	@override String get msg_copy_path => 'Pfad kopieren';
	@override String get msg_components => 'Komponenten';
	@override String get msg_no_shortcuts => 'Keine Verknüpfungen';
	@override String get msg_location_timed_try => 'Zeitüberschreitung beim Standort. Bitte erneut versuchen.';
	@override String get msg_attach_location_info_memos_show_subtle => 'Standortinformationen an Memos anhängen und dezente Ortsnamen anzeigen.';
	@override String msg_send_failed({required Object e}) => 'Senden fehlgeschlagen: ${e}';
	@override String get msg_repeat => 'Wiederholen';
	@override String get msg_not_signed => 'Nicht angemeldet';
	@override String get msg_no_webhooks_configured => 'Keine Webhooks konfiguriert';
	@override String get msg_apply_token => 'Token anwenden';
	@override String get msg_enable_reminder_permissions_2 => 'Erinnerungsberechtigungen aktivieren';
	@override String get msg_enter_backup_password => 'Backup-Passwort eingeben';
	@override String get msg_start_backup => 'Backup starten';
	@override String get msg_last_sync => 'Letzte Synchronisierung';
	@override String get msg_note_export_includes_content_already_synced => 'Hinweis: Der Export enthält Inhalte, die bereits mit der lokalen Datenbank synchronisiert wurden (einschließlich Offlinedaten).';
	@override String get msg_enter_username => 'Benutzernamen eingeben';
	@override String get msg_settings_saved => 'Einstellungen gespeichert';
	@override String get msg_no_keywords => 'Keine Schlüsselwörter';
	@override String get msg_these_settings_apply_newly_created_memos => 'Diese Einstellungen gelten für neu erstellte Memos.';
	@override String get msg_back_home => 'Zurück zur Startseite';
	@override String get msg_quiet_hours => 'Ruhezeiten';
	@override String get msg_add_account => 'Konto hinzufügen';
	@override String get msg_reset_complete => 'Zurücksetzen abgeschlossen';
	@override String get msg_no_shortcuts_configured => 'Keine Verknüpfungen konfiguriert';
	@override String get msg_password => 'Passwort';
	@override String get msg_importing => 'Importieren';
	@override String msg_visibility_2({required Object visibilityLabel}) => 'Sichtbarkeit: ${visibilityLabel}';
	@override String get msg_no_logs_yet => 'Noch keine Protokolle';
	@override String get msg_v_9_times_allowed => 'Bis zu 9 Mal erlaubt';
	@override String get msg_last_14_days => 'Letzte 14 Tage';
	@override String get msg_location_disabled_enable_settings_first => 'Standort ist deaktiviert. Aktivieren Sie ihn zuerst in den Einstellungen.';
	@override String get msg_add_2 => 'Hinzufügen';
	@override String get msg_logs => 'Protokolle';
	@override String get msg_references => 'Referenzen';
	@override String get msg_importing_memos => 'Memos werden importiert...';
	@override String get msg_account_security => 'Konto & Sicherheit';
	@override String get msg_reminder_2 => 'Erinnerung';
	@override String get msg_enable_scheduled_reminder_notifications => 'Geplante Erinnerungsbenachrichtigungen aktivieren.';
	@override String get msg_no_links => 'Keine Links';
	@override String get msg_delete_memo_2 => 'Memo löschen';
	@override String get msg_one_tap_add_not_supported_add => 'Hinzufügen mit einem Tippen wird nicht unterstützt. Fügen Sie es über die Widget-Auswahl hinzu';
	@override String get msg_password_2 => 'Neues Passwort';
	@override String get msg_processing_content => 'Inhalt wird verarbeitet...';
	@override String get msg_status => 'Status';
	@override String get msg_local_library_added => 'Lokale Bibliothek hinzugefügt';
	@override String get msg_failed_open_try => 'Konnte nicht geöffnet werden. Bitte erneut versuchen.';
	@override String get msg_removed_locally_now_deleted_server_when => 'Es wird jetzt lokal entfernt und auf dem Server gelöscht, sobald eine Verbindung besteht.';
	@override String get msg_server_url_unavailable => 'Server-URL nicht verfügbar';
	@override String get msg_no_release_notes_yet => 'Noch keine Versionshinweise';
	@override String get msg_cancelling_2 => 'Abbrechen...';
	@override String get msg_summaries_selected_range => 'Zusammenfassungen über den ausgewählten Bereich';
	@override String get msg_expand_2 => 'Erweitern';
	@override String get msg_close => 'Schließen';
	@override String msg_more_comments({required Object remainingComments}) => '${remainingComments} weitere Kommentare';
	@override String get msg_backing => 'Sicherung wird erstellt…';
	@override String get msg_view_debug_logs => 'Debug-Protokolle anzeigen';
	@override String get msg_location_permission_denied => 'Standortberechtigung verweigert';
	@override String get msg_self_repair_reset_heatmap => 'Selbstreparatur: Heatmap zurücksetzen';
	@override String get msg_these_settings_changed_locally_remotely_choose => 'Diese Einstellungen wurden lokal und remote geändert. Wählen Sie, welche Version beibehalten werden soll.';
	@override String get msg_not_authenticated_2 => 'Nicht authentifiziert.';
	@override String msg_action_failed({required Object e}) => 'Aktion fehlgeschlagen: ${e}';
	@override String get msg_shortcut_2 => 'Neue Verknüpfung';
	@override String get msg_url => 'URL';
	@override String get msg_no_memos_found_html => 'Keine Memos in HTML gefunden.';
	@override String get msg_enter_what_want_summarize => 'Geben Sie ein, was Sie zusammenfassen möchten...';
	@override String get msg_unable_load_audio_source => 'Audioquelle konnte nicht geladen werden.';
	@override String get msg_strategy_id => 'Strategie-ID';
	@override String msg_copy_failed({required Object e}) => 'Kopieren fehlgeschlagen: ${e}';
	@override String get msg_enable_image_bed => 'Bildbett aktivieren';
	@override String get msg_active => 'Aktiv';
	@override String get msg_account => 'Konto';
	@override String get msg_invalid_webdav_server_url => 'Ungültige WebDAV-Server-URL';
	@override String get msg_keep_local => 'Lokal beibehalten';
	@override String get msg_within_range => 'Innerhalb des Bereichs';
	@override String get msg_generate_log_file => 'Protokolldatei erstellen';
	@override String get msg_ai_reports => 'KI-Berichte';
	@override String get msg_battery_optimization => 'Akkuoptimierung';
	@override String get msg_sync_overview => 'Synchronisierungsübersicht';
	@override String get msg_legacy_servers_not_support_search_filters => 'Legacy-Server unterstützen keine Suchfilter; Ergebnisse können unvollständig sein.';
	@override String get msg_conflicts_detected_run_manual_sync => 'Konflikte erkannt. Führen Sie eine manuelle Synchronisierung aus.';
	@override String get msg_authentication_failed_check_token => 'Authentifizierung fehlgeschlagen. Prüfen Sie das Token.';
	@override String get msg_date_range_3 => 'Datumsbereich';
	@override String get msg_help_ai_understand_better => 'Hilf der KI, dich besser zu verstehen';
	@override String get msg_no_search_history => 'Kein Suchverlauf';
	@override String get msg_enter_api_path => 'API-Pfad eingeben';
	@override String get msg_stats => 'Statistiken';
	@override String get msg_text_2 => 'Neu: ';
	@override String get msg_removing_signing_clear_local_cache_account => 'Entfernen/Abmelden löscht den lokalen Cache für dieses Konto (Offline-Daten/Entwürfe/ausstehende Synchronisierungswarteschlange).';
	@override String get msg_updated_time_2 => 'Aktualisierte Zeit ↑';
	@override String get msg_province => 'Bundesland';
	@override String get msg_submitting_sync_queue => 'Synchronisierungswarteschlange wird übermittelt';
	@override String get msg_failed => 'Fehlgeschlagen';
	@override String get msg_set_time => 'Zeit festlegen';
	@override String get msg_enable_local_library_backup => 'Lokale Bibliothekssicherung aktivieren';
	@override String get msg_cancel_2 => 'Abbrechen';
	@override String get msg_week => 'Diese Woche';
	@override String get msg_like => 'Gefällt mir';
	@override String get msg_location_services_disabled => 'Standortdienste sind deaktiviert';
	@override String get msg_clears_local_cache_offline_memos_pending => 'Dadurch wird der lokale Cache (Offline-Memos/ausstehende Warteschlange) gelöscht und eine vollständige Neusynchronisierung ausgelöst. Nicht synchronisierte Inhalte gehen verloren, und es kann eine Weile dauern. Fortfahren?';
	@override String get msg_load_more => 'Mehr laden';
	@override String get msg_pull_memo_list_refresh_sync_sync => 'Zum Aktualisieren und Synchronisieren in der Memoliste nach unten ziehen. Die Synchronisierung ruft zuerst die neuesten Elemente ab; führen Sie regelmäßig eine vollständige Synchronisierung durch, damit Statistiken/Heatmap vollständig bleiben.';
	@override String msg_server_returned_error({required Object code}) => 'Server hat einen Fehler zurückgegeben (${code}).';
	@override String get msg_sound_feedback => 'Ton & Feedback';
	@override String msg_memos_skipped_attachments_skipped({required Object exportedMemoCount, required Object skippedMemoCount, required Object exportedAttachmentCount, required Object skippedAttachmentCount}) => '${exportedMemoCount} Memos (übersprungen: ${skippedMemoCount}), ${exportedAttachmentCount} Anhänge (übersprungen: ${skippedAttachmentCount}).';
	@override String get msg_import_complete => 'Import abgeschlossen';
	@override String get msg_text_3 => 'Neu';
	@override String get msg_max_per_day => 'Max. pro Tag';
	@override String get msg_permissions_denied => 'Berechtigungen verweigert';
	@override String get msg_memo_2 => 'Neues Memo';
	@override String get msg_delete_reminder => 'Erinnerung löschen';
	@override String get msg_select_month => 'Monat auswählen';
	@override String get msg_select_backup => 'Sicherung auswählen';
	@override String get msg_no_keywords_2 => '#Keine Schlüsselwörter';
	@override String get msg_preparing_memo_content => 'Memo-Inhalt wird vorbereitet';
	@override String get msg_prompt_content => 'Prompt-Inhalt';
	@override String get msg_default_prompt_ai_summaries_reports => 'Standard-Prompt für KI-Zusammenfassungen/-Berichte';
	@override String get msg_intro => 'Einführung';
	@override String get msg_monthly_stats => 'Monatliche Statistiken';
	@override String get msg_times_2 => 'Mal';
	@override String get msg_file_has_already_been_imported_skipped => 'Diese Datei wurde bereits importiert. Übersprungen.';
	@override String get msg_token_tail_unknown => 'Token-Ende unbekannt';
	@override String get msg_press_back_exit => 'Zum Beenden erneut Zurück drücken';
	@override String get msg_enter_password_3 => 'Passwort eingeben';
	@override String get msg_sync_conflicts => 'Synchronisierungskonflikte';
	@override String get msg_locale => 'Gebietsschema';
	@override String get msg_any => 'Beliebig';
	@override String get msg_provider => 'Anbieter';
	@override String get msg_preview_2 => 'Vorschau';
	@override String get msg_automatically_upload_images_append_links_memo => 'Bilder automatisch hochladen und Links an das Memo anhängen.';
	@override String get msg_import_file_not_found => 'Importdatei nicht gefunden.';
	@override String get msg_today => 'Heute';
	@override String get msg_link_card => 'Karte verknüpfen';
	@override String get msg_expiration => 'Ablaufdatum';
	@override String get msg_summary_prompt_optional => 'Zusammenfassungs-Prompt (optional)';
	@override String get msg_memos => 'Notizen';
	@override String get msg_recording_file_not_found_2 => 'Aufnahmedatei nicht gefunden.';
	@override String get msg_backup_settings => 'Sicherungseinstellungen';
	@override String get msg_mode => 'Modus';
	@override String get msg_no_markdown_memos_found_zip => 'Keine Markdown-Notizen in der ZIP gefunden.';
	@override String get msg_archived => 'Archiviert';
	@override String msg_update_failed({required Object e}) => 'Aktualisierung fehlgeschlagen: ${e}';
	@override String get msg_enable_app_lock => 'App-Sperre aktivieren';
	@override String get msg_html_zip => 'HTML / ZIP';
	@override String get msg_all => 'Alle';
	@override String get msg_model => 'Modell';
	@override String get msg_title => 'Titel';
	@override String get msg_amap_web_api => 'Amap Web API';
	@override String get msg_saved_gallery => 'In Galerie gespeichert';
	@override String get msg_unread => 'Ungelesen';
	@override String get msg_exporting => 'Exportiere...';
	@override String get msg_network_timeout_try => 'Netzwerk-Timeout. Bitte versuche es erneut.';
	@override String get msg_unlock => 'Entsperren';
	@override String msg_ago_3({required Object diff_inDays}) => 'vor ${diff_inDays}';
	@override String get msg_deserve_coffee_i_m_pulling_all => 'Um diesen Kaffee zu verdienen, mache ich eine Nachtschicht, um 100 Zeilen Code zu schreiben!';
	@override String get msg_token_name => 'Token-Name';
	@override String get msg_restore_completed => 'Wiederherstellung abgeschlossen';
	@override String get msg_copied_clipboard => 'In die Zwischenablage kopiert';
	@override String msg_failed_2({required Object attempts}) => 'Fehlgeschlagen ${attempts}';
	@override String get msg_too_many_requests_try_later => 'Zu viele Anfragen. Versuche es später erneut.';
	@override String get msg_more => 'Mehr';
	@override String get msg_already_whitelisted => 'Bereits auf der Whitelist';
	@override String get msg_local_library_backup => 'Lokale Bibliothekssicherung';
	@override String get msg_awesome => 'Großartig! ❤️';
	@override String get msg_now => 'Jetzt';
	@override String get msg_select_reminder_time => 'Erinnerungszeit auswählen';
	@override String get msg_protected => 'Geschützt';
	@override String msg_failed_load_4({required Object e}) => 'Laden fehlgeschlagen: ${e}';
	@override String msg_operation_failed({required Object e}) => 'Vorgang fehlgeschlagen: ${e}';
	@override String get msg_no_tags => 'Keine Tags';
	@override String get msg_server => 'Server';
	@override String get msg_improved => 'Verbessert';
	@override String get msg_request_2 => 'Anfrage';
	@override String msg_export_failed({required Object e}) => 'Export fehlgeschlagen: ${e}';
	@override String get msg_notification_settings => 'Benachrichtigungseinstellungen';
	@override String get msg_related_memo_was_deleted => 'Die zugehörige Notiz wurde gelöscht';
	@override String get msg_email => 'E-Mail';
	@override String get msg_enter_password_4 => 'Bitte ein Passwort eingeben';
	@override String get msg_retry_count => 'Anzahl der Wiederholungen';
	@override String get msg_import_exported_html_zip_package => 'Exportiertes HTML- oder ZIP-Paket importieren';
	@override String get msg_archive => 'Archiv';
	@override String get msg_reset_heatmap => 'Heatmap zurücksetzen?';
	@override String get msg_token_applied => 'Token angewendet';
	@override String get msg_log_file_created => 'Protokolldatei erstellt';
	@override String get msg_delete_sync_task => 'Synchronisierungsaufgabe löschen';
	@override String get msg_include_archived_2 => '- Archivierte einschließen';
	@override String get msg_memoflow_side_project_i_build_my => 'MemoFlow ist ein Nebenprojekt, das ich in meiner Freizeit entwickle. Ich habe bis spät in die Nacht Bugs behoben und könnte wirklich einen Iced Americano gebrauchen. Deine Unterstützung lädt meine Batterie wieder auf und hilft dabei, neue Funktionen zu veröffentlichen ';
	@override String msg_failed_generate({required Object e}) => 'Generierung fehlgeschlagen: ${e}';
	@override String get msg_search_logs => 'Protokolle durchsuchen';
	@override String get msg_active_days => 'Aktive Tage';
	@override String get msg_back_top => 'Zurück nach oben';
	@override String get msg_month => 'Dieser Monat';
	@override String get msg_loading_references => 'Referenzen werden geladen';
	@override String get msg_silent => 'Lautlos';
	@override String get msg_settings => 'Einstellungen';
	@override String get msg_locating => 'Wird lokalisiert...';
	@override String get msg_scan => 'Scannen';
	@override String get msg_recording_path_missing => 'Aufnahmepfad fehlt.';
	@override String get msg_date_range_4 => '- Datumsbereich';
	@override String get msg_suggested_tags => 'Vorgeschlagene Tags';
	@override String get msg_energy_restored => '⚡ ENERGIE WIEDERHERGESTELLT';
	@override String get msg_username_2 => 'Benutzername';
	@override String get msg_ai_summary_report => 'KI-Zusammenfassungsbericht';
	@override String get msg_all_tags => 'Alle Tags';
	@override String get msg_preferences => 'Präferenzen';
	@override String get msg_image_bed_3 => 'Bildspeicher';
	@override String get msg_quick_input => 'Schnelleingabe';
	@override String get msg_tags => 'Tags';
	@override String get msg_energy_critically_low => 'Energie kritisch niedrig!';
	@override String msg_delete_failed({required Object e}) => 'Löschen fehlgeschlagen: ${e}';
	@override String get msg_server_login => 'Server-Anmeldung';
	@override String get msg_like_2 => 'Gefällt mir';
	@override String get msg_save_2 => 'Speichern';
	@override String get msg_unknown => 'Unbekannt';
	@override String get msg_release_notes_2 => 'Versionshinweise';
	@override String get msg_include_error_details => 'Fehlerdetails einschließen';
	@override String get msg_write_comment => 'Einen Kommentar schreiben...';
	@override String get msg_write_thoughts => 'Schreibe deine Gedanken auf...';
	@override String get msg_local_2 => 'Lokal';
	@override String get msg_expired => 'Abgelaufen';
	@override String get msg_fixed_2 => 'Behoben';
	@override String get msg_upload_attachment => 'Anhang hochladen';
	@override String get msg_battery_whitelist => 'Batterie-Whitelist';
	@override String get msg_district => 'Bezirk';
	@override String get msg_voice_memo => '🎙️ Sprachnotiz\\n';
	@override String get msg_system_default => 'Systemstandard';
	@override String get msg_all_memos_2 => 'Alle Notizen';
	@override String get msg_network_request_failed => 'Netzwerkanfrage fehlgeschlagen';
	@override String get msg_memo_not_found => 'Notiz nicht gefunden';
	@override String msg_playback_failed_2({required Object e}) => 'Wiedergabe fehlgeschlagen: ${e}';
	@override String get msg_sync_settings_webdav_across_devices => 'Synchronisiere Einstellungen über Geräte hinweg mit WebDAV.';
	@override String get msg_offline_first_client_memos_backend => 'Ein Offline-First-Client für das Memos-Backend.';
	@override String get msg_user_guide => 'Benutzerhandbuch';
	@override String get msg_notice => 'Hinweis';
	@override String get msg_exact_alarms => 'Exakte Alarme';
	@override String get msg_restoring_overwrite_local_library_files_rebuild => 'Beim Wiederherstellen werden lokale Bibliotheksdateien überschrieben und die Datenbank neu aufgebaut. Dies kann nicht rückgängig gemacht werden.';
	@override String get msg_enter_api_url_ai_settings => 'Bitte geben Sie die API-URL in den KI-Einstellungen ein';
	@override String msg_create_failed_2({required Object e}) => 'Erstellen fehlgeschlagen: ${e}';
	@override String get msg_close_search => 'Suche schließen';
	@override String get msg_imported_memos_2 => 'Memos importiert';
	@override String get msg_explore => 'Entdecken';
	@override String get msg_network_connection_failed => 'Netzwerkverbindung fehlgeschlagen.';
	@override String msg_save_failed_3({required Object e}) => 'Speichern fehlgeschlagen: ${e}';
	@override String get msg_no_summary_share => 'Keine Zusammenfassung zum Teilen';
	@override String get msg_custom_model => 'Benutzerdefiniertes Modell';
	@override String msg_sign_failed({required Object message}) => 'Anmeldung fehlgeschlagen: ${message}';
	@override String get msg_notification_exact_alarm_permissions_required_send => 'Benachrichtigungs- und Berechtigungen für exakte Alarme sind erforderlich, um Erinnerungen pünktlich zu senden.';
	@override String get msg_random_review => 'Zufällige Überprüfung';
	@override String get msg_public => 'Öffentlich';
	@override String get msg_all_2 => 'Alle';
	@override String get msg_add_custom_model => 'Benutzerdefiniertes Modell hinzufügen';
	@override String get msg_backup_password => 'Backup-Passwort';
	@override String get msg_optional_used_sign_requests => 'Optional. Wird zum Signieren von Anfragen verwendet.';
	@override String get msg_search => 'Suchen';
	@override String get msg_set_password => 'Passwort festlegen';
	@override String get msg_submit_logs => 'Protokolle senden';
	@override String get msg_activity_heatmap_2 => 'AKTIVITÄTS-HEATMAP';
	@override String get msg_invalid_api_key_insufficient_permissions => 'Ungültiger API-Schlüssel oder unzureichende Berechtigungen.';
	@override String get msg_data_has_been_migrated_app_successfully => 'Ihre Daten wurden erfolgreich in diese App migriert.';
	@override String get msg_get_version => 'Neue Version herunterladen';
	@override String get msg_token_source => 'Token-Quelle';
	@override String get msg_send => 'Senden';
	@override String get msg_no_pending_sync_tasks => 'Keine ausstehenden Synchronisierungsaufgaben';
	@override String get msg_locating_memo_content => 'Notizinhalt wird lokalisiert';
	@override String get msg_offline_ready => 'Offline bereit';
	@override String get msg_use_relative_path => 'Einen relativen Pfad verwenden';
	@override String get msg_total => 'Gesamt';
	@override String get msg_location_2 => 'Standort';
	@override String get msg_show_location_metadata_memos_not_configured => 'Standortmetadaten in Notizen anzeigen. Wenn nicht konfiguriert, werden stattdessen Koordinaten angezeigt.';
	@override String get msg_api_url => 'API-URL';
	@override String get msg_parsing_progress => 'Analysefortschritt';
	@override String get msg_parsing => 'Analysieren';
	@override String get msg_custom => 'Benutzerdefiniert';
	@override String get msg_tags_created => 'Neue Tags erstellt';
	@override String get msg_third_party_share_disabled => 'Teilen über Drittanbieter ist deaktiviert';
	@override String get msg_loading_links => 'Links werden geladen...';
	@override String get msg_how_report => 'Wie melden?';
	@override String get msg_confirm_password_2 => 'Passwort bestätigen';
	@override String get msg_search_title_content_tags => 'Nach Titel, Inhalt oder Tags suchen';
	@override String msg_reset_failed({required Object e}) => 'Zurücksetzen fehlgeschlagen: ${e}';
	@override String get msg_debug_preview_update_dialog => 'Debug: Vorschau des Update-Dialogs';
	@override String get msg_what_s => 'Was ist neu?';
	@override String get msg_ringtone => 'Klingelton';
	@override String get msg_unable_detect_backend_version_check_server => 'Backend-Version kann nicht erkannt werden. Überprüfen Sie die Server-URL oder das Netzwerk.';
	@override String get msg_pending_2 => 'Ausstehend';
	@override String get msg_parsing_html => 'HTML wird analysiert...';
	@override String get msg_actions => 'Aktionen';
	@override String get msg_import_complete_2 => 'Import abgeschlossen';
	@override String get msg_use_disk => 'Datenträger verwenden';
	@override String get msg_root_path => 'Root-Pfad';
	@override String get msg_disabled => 'Deaktiviert';
	@override String get msg_improved_2 => 'Verbessert: ';
	@override String get msg_city => 'Stadt';
	@override String get msg_decoding_zip => 'ZIP wird decodiert...';
	@override String get msg_notification_content => 'Benachrichtigungsinhalt';
	@override String get msg_resolve_conflict => 'Konflikt lösen';
	@override String get msg_webhooks_not_supported_server => 'Webhooks werden auf diesem Server nicht unterstützt.';
	@override String get msg_may_delayed => ' (kann verzögert sein)';
	@override String get msg_permissions_system_settings => 'Berechtigungen & Systemeinstellungen';
	@override String get msg_waiting_tasks_stop => 'Warten, bis Aufgaben beendet sind';
	@override String get msg_done_2 => 'Fertig';
	@override String get msg_parsing_memoflow_export => 'MemoFlow-Export wird analysiert...';
	@override String msg_location_updated({required Object next_displayText_fractionDigits_6}) => 'Standort aktualisiert: ${next_displayText_fractionDigits_6}';
	@override String get msg_checking_server_version => 'Serverversion wird überprüft...';
	@override String get msg_next_time_back_fixing_bugs => '👀 Nächstes Mal zurück zum Beheben von Fehlern';
	@override String msg_ago_4({required Object weeks}) => 'vor ${weeks}';
	@override String get msg_import => 'Importieren';
	@override String get msg_ios_long_press_home_screen_add => 'Unter iOS: Halte den Home-Bildschirm gedrückt, um MemoFlow-Widgets hinzuzufügen';
	@override String get msg_create_token_2 => 'Token erstellen';
	@override String get msg_marked_read => 'Als gelesen markiert';
	@override String get msg_pinned => 'Angepinnt';
	@override String get msg_version_update => 'Versionsaktualisierung';
	@override String get msg_allow_private_memos => 'Private Memos zulassen';
	@override String get msg_token_copied_clipboard => 'Token in die Zwischenablage kopiert';
	@override String get msg_keeping_more_versions_uses_more_storage => 'Das Beibehalten mehrerer Versionen benötigt mehr Speicherplatz. Erwäge, alte Versionen zu bereinigen.';
	@override String get msg_delete_webhook => 'Webhook löschen';
	@override String get msg_prompt => 'Eingabeaufforderung';
	@override String get msg_location_precision => 'Standortgenauigkeit';
	@override String get msg_password_required => 'Passwort erforderlich';
	@override String get msg_exit_app => 'App beenden';
	@override String get msg_thanks_energy_fully_restored => 'Danke! Energie vollständig wiederhergestellt ⚡';
	@override String get msg_connection_timeout_check_network_api_url => 'Zeitüberschreitung bei der Verbindung. Überprüfe das Netzwerk oder die API-URL.';
	@override late final _StringsStringsLegacyAppLanguageDe app_language = _StringsStringsLegacyAppLanguageDe._(_root);
	@override late final _StringsStringsLegacyAppThemeDe app_theme = _StringsStringsLegacyAppThemeDe._(_root);
	@override late final _StringsStringsLegacyAppFontSizeDe app_font_size = _StringsStringsLegacyAppFontSizeDe._(_root);
	@override late final _StringsStringsLegacyAppLineHeightDe app_line_height = _StringsStringsLegacyAppLineHeightDe._(_root);
	@override late final _StringsStringsLegacyLaunchActionDe launch_action = _StringsStringsLegacyLaunchActionDe._(_root);
	@override late final _StringsStringsLegacyAutoLockTimeDe auto_lock_time = _StringsStringsLegacyAutoLockTimeDe._(_root);
	@override late final _StringsStringsLegacyReminderDe reminder = _StringsStringsLegacyReminderDe._(_root);
	@override late final _StringsStringsLegacyLocationDe location = _StringsStringsLegacyLocationDe._(_root);
	@override late final _StringsStringsLegacyWebdavDe webdav = _StringsStringsLegacyWebdavDe._(_root);
	@override String import_count_memos({required Object count}) => '${count}';
	@override String import_count_attachments({required Object count}) => '${count}';
	@override late final _StringsStringsLegacyAppDrawerDe app_drawer = _StringsStringsLegacyAppDrawerDe._(_root);
	@override late final _StringsStringsLegacyAiSummaryDe ai_summary = _StringsStringsLegacyAiSummaryDe._(_root);
}

// Path: strings.login.mode
class _StringsStringsLoginModeDe extends _StringsStringsLoginModeEn {
	_StringsStringsLoginModeDe._(_StringsDe root) : this._root = root, super._(root);

	@override final _StringsDe _root; // ignore: unused_field

	// Translations
	@override String get password => 'Benutzername & Passwort';
	@override String get token => 'Token';
	@override String get descPassword => 'Mit Benutzername und Passwort anmelden';
	@override String get descToken => 'Mit Personal Access Token anmelden';
	@override String get signInMethod => 'Anmeldeart';
}

// Path: strings.login.field
class _StringsStringsLoginFieldDe extends _StringsStringsLoginFieldEn {
	_StringsStringsLoginFieldDe._(_StringsDe root) : this._root = root, super._(root);

	@override final _StringsDe _root; // ignore: unused_field

	// Translations
	@override String get serverUrlLabel => 'Server-URL';
	@override String get serverUrlHint => 'http://localhost:5230';
	@override String get usernameLabel => 'Benutzername';
	@override String get usernameHint => 'Benutzernamen eingeben';
	@override String get passwordLabel => 'Passwort';
	@override String get passwordHint => 'Passwort eingeben';
	@override String get tokenLabel => 'Token (PAT)';
	@override String get tokenHint => 'Token (PAT)';
}

// Path: strings.login.validation
class _StringsStringsLoginValidationDe extends _StringsStringsLoginValidationEn {
	_StringsStringsLoginValidationDe._(_StringsDe root) : this._root = root, super._(root);

	@override final _StringsDe _root; // ignore: unused_field

	// Translations
	@override String get serverUrlRequired => 'Bitte Server-URL eingeben';
	@override String get serverUrlInvalid => 'Bitte vollständige URL eingeben (inkl. http/https und Port)';
	@override String get usernameRequired => 'Bitte Benutzernamen eingeben';
	@override String get passwordRequired => 'Bitte Passwort eingeben';
	@override String get tokenRequired => 'Bitte Token eingeben';
}

// Path: strings.login.compatibility
class _StringsStringsLoginCompatibilityDe extends _StringsStringsLoginCompatibilityEn {
	_StringsStringsLoginCompatibilityDe._(_StringsDe root) : this._root = root, super._(root);

	@override final _StringsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Kompatibilitätsmodus';
	@override String get description => 'Legacy-Endpunkte verwenden (für ältere Memos-Server)';
}

// Path: strings.login.connect
class _StringsStringsLoginConnectDe extends _StringsStringsLoginConnectEn {
	_StringsStringsLoginConnectDe._(_StringsDe root) : this._root = root, super._(root);

	@override final _StringsDe _root; // ignore: unused_field

	// Translations
	@override String get connecting => 'Verbindung wird hergestellt…';
	@override String get action => 'Verbinden';
}

// Path: strings.login.errors
class _StringsStringsLoginErrorsDe extends _StringsStringsLoginErrorsEn {
	_StringsStringsLoginErrorsDe._(_StringsDe root) : this._root = root, super._(root);

	@override final _StringsDe _root; // ignore: unused_field

	// Translations
	@override String get authFailedToken => 'Authentifizierung fehlgeschlagen. Prüfen Sie, ob das Token gültig und nicht abgelaufen ist.';
	@override String get authFailedPat => 'Authentifizierung fehlgeschlagen. Für neue Memos ein PAT verwenden, das mit memos_pat_ beginnt (den Bearer-Präfix nicht einfügen).';
	@override String connectionFailedWithMessage({required Object message}) => 'Verbindung fehlgeschlagen: ${message}';
	@override String connectionFailed({required Object error}) => 'Verbindung fehlgeschlagen: ${error}';
	@override String get signInFailed => 'Anmeldung fehlgeschlagen. Benutzername und Passwort prüfen.';
	@override String signInFailedWithMessage({required Object message}) => 'Anmeldung fehlgeschlagen: ${message}';
	@override String get invalidServerUrl => 'Ungültige Server-URL';
	@override String get serverUrlNormalized => 'Server-URL normalisiert (zusätzliche Pfadsegmente entfernt)';
}

// Path: strings.settings.preferences
class _StringsStringsSettingsPreferencesDe extends _StringsStringsSettingsPreferencesEn {
	_StringsStringsSettingsPreferencesDe._(_StringsDe root) : this._root = root, super._(root);

	@override final _StringsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Einstellungen';
	@override String get language => 'Sprache';
	@override String get fontSize => 'Schriftgröße';
	@override String get lineHeight => 'Zeilenhöhe';
	@override String get font => 'Schriftart';
	@override String get systemDefault => 'Systemstandard';
	@override String get noSystemFonts => 'Keine Systemschriftarten gefunden';
	@override String loadFontsFailed({required Object error}) => 'Schriftarten konnten nicht geladen werden: ${error}';
	@override String get collapseLongContent => 'Lange Inhalte einklappen';
	@override String get collapseReferences => 'Referenzen einklappen';
	@override String get showEngagementInAllMemoDetails => 'Likes und Kommentare in allen Memo-Details anzeigen';
	@override String get launchAction => 'Aktion beim Start';
	@override String get quickInputKeyboard => 'Tastatur bei Schnellnotiz automatisch öffnen';
	@override String get appearance => 'Darstellung';
	@override String get themeColor => 'Themenfarbe';
	@override String get haptics => 'Haptik';
	@override String get customTheme => 'Benutzerdefiniertes Thema';
	@override String get history => 'Verlauf';
	@override String get lightMode => 'Heller Modus';
	@override String get darkMode => 'Dunkler Modus';
	@override String get surfaces => 'Oberflächen';
	@override String get background => 'Hintergrund';
	@override String get backgroundColor => 'Hintergrundfarbe';
	@override String get card => 'Karte';
	@override String get cardColor => 'Kartenfarbe';
	@override String get border => 'Rahmen';
	@override String get borderColor => 'Rahmenfarbe';
}

// Path: strings.legacy.app_language
class _StringsStringsLegacyAppLanguageDe extends _StringsStringsLegacyAppLanguageEn {
	_StringsStringsLegacyAppLanguageDe._(_StringsDe root) : this._root = root, super._(root);

	@override final _StringsDe _root; // ignore: unused_field

	// Translations
	@override String get system => 'System';
	@override String get zh_hans => 'Chinesisch (Vereinfacht)';
	@override String get zh_hant_tw => 'Chinesisch (Traditionell, China Taiwan)';
	@override String get en => 'Englisch';
	@override String get ja => 'Japanisch';
	@override String get de => 'Deutsch';
}

// Path: strings.legacy.app_theme
class _StringsStringsLegacyAppThemeDe extends _StringsStringsLegacyAppThemeEn {
	_StringsStringsLegacyAppThemeDe._(_StringsDe root) : this._root = root, super._(root);

	@override final _StringsDe _root; // ignore: unused_field

	// Translations
	@override String get system => 'System';
	@override String get light => 'Hell';
	@override String get dark => 'Dunkel';
}

// Path: strings.legacy.app_font_size
class _StringsStringsLegacyAppFontSizeDe extends _StringsStringsLegacyAppFontSizeEn {
	_StringsStringsLegacyAppFontSizeDe._(_StringsDe root) : this._root = root, super._(root);

	@override final _StringsDe _root; // ignore: unused_field

	// Translations
	@override String get standard => 'Standard';
	@override String get large => 'Groß';
	@override String get small => 'Klein';
}

// Path: strings.legacy.app_line_height
class _StringsStringsLegacyAppLineHeightDe extends _StringsStringsLegacyAppLineHeightEn {
	_StringsStringsLegacyAppLineHeightDe._(_StringsDe root) : this._root = root, super._(root);

	@override final _StringsDe _root; // ignore: unused_field

	// Translations
	@override String get classic => 'Klassisch';
	@override String get compact => 'Kompakt';
	@override String get relaxed => 'Entspannt';
}

// Path: strings.legacy.launch_action
class _StringsStringsLegacyLaunchActionDe extends _StringsStringsLegacyLaunchActionEn {
	_StringsStringsLegacyLaunchActionDe._(_StringsDe root) : this._root = root, super._(root);

	@override final _StringsDe _root; // ignore: unused_field

	// Translations
	@override String get none => 'Keine';
	@override String get sync => 'Synchronisieren';
	@override String get quick_input => 'Schnelleingabe';
	@override String get daily_review => 'Zufällige Rückschau';
}

// Path: strings.legacy.auto_lock_time
class _StringsStringsLegacyAutoLockTimeDe extends _StringsStringsLegacyAutoLockTimeEn {
	_StringsStringsLegacyAutoLockTimeDe._(_StringsDe root) : this._root = root, super._(root);

	@override final _StringsDe _root; // ignore: unused_field

	// Translations
	@override String get immediately => 'Sofort';
	@override String get after_1_min => '1 Minute';
	@override String get after_5_min => '5 Minuten';
	@override String get after_15_min => '15 Minuten';
}

// Path: strings.legacy.reminder
class _StringsStringsLegacyReminderDe extends _StringsStringsLegacyReminderEn {
	_StringsStringsLegacyReminderDe._(_StringsDe root) : this._root = root, super._(root);

	@override final _StringsDe _root; // ignore: unused_field

	// Translations
	@override String get default_title => 'Hey, erinnerst du dich an diese Idee?';
	@override String get default_body => 'Tippen, um Details anzusehen';
}

// Path: strings.legacy.location
class _StringsStringsLegacyLocationDe extends _StringsStringsLegacyLocationEn {
	_StringsStringsLegacyLocationDe._(_StringsDe root) : this._root = root, super._(root);

	@override final _StringsDe _root; // ignore: unused_field

	// Translations
	@override String get current => 'Aktueller Standort';
}

// Path: strings.legacy.webdav
class _StringsStringsLegacyWebdavDe extends _StringsStringsLegacyWebdavEn {
	_StringsStringsLegacyWebdavDe._(_StringsDe root) : this._root = root, super._(root);

	@override final _StringsDe _root; // ignore: unused_field

	// Translations
	@override String get not_configured => 'WebDAV ist nicht konfiguriert';
	@override String get backup_disabled => 'Backup ist deaktiviert';
	@override String get backup_account_missing => 'Konto für das Backup fehlt';
	@override String get backup_local_only => 'Backup ist nur für lokale Bibliotheken verfügbar';
	@override String get backup_password_missing => 'Backup-Passwort fehlt';
	@override String get backup_no_memo_files => 'Keine Memo-Dateien in der lokalen Bibliothek gefunden; Backup abgebrochen';
	@override String get restore_account_missing => 'Konto für die Wiederherstellung fehlt';
	@override String get restore_local_only => 'Wiederherstellung ist nur für lokale Bibliotheken verfügbar';
	@override String get backup_empty => 'Backup ist leer';
	@override String get backup_no_memos => 'Keine Memos im Backup gefunden';
	@override String get snapshot_missing => 'Backup-Snapshot fehlt';
	@override String get snapshot_corrupted => 'Backup-Snapshot ist beschädigt';
	@override String get object_missing => 'Backup-Objekt fehlt';
	@override String get config_corrupted => 'Backup-Konfiguration ist beschädigt';
	@override String get config_invalid => 'Ungültige Backup-Konfiguration';
	@override String get password_invalid => 'Ungültiges Backup-Passwort';
	@override String get data_corrupted => 'Backup-Daten sind beschädigt';
	@override String get server_url_invalid => 'Ungültige WebDAV-Server-URL';
}

// Path: strings.legacy.app_drawer
class _StringsStringsLegacyAppDrawerDe extends _StringsStringsLegacyAppDrawerEn {
	_StringsStringsLegacyAppDrawerDe._(_StringsDe root) : this._root = root, super._(root);

	@override final _StringsDe _root; // ignore: unused_field

	// Translations
	@override String tooltip_single({required Object date, required Object weekday, required Object count}) => '${date} (${weekday}) · ${count} Notiz';
	@override String tooltip_multi({required Object date, required Object weekday, required Object count}) => '${date} (${weekday}) · ${count} Notizen';
}

// Path: strings.legacy.ai_summary
class _StringsStringsLegacyAiSummaryDe extends _StringsStringsLegacyAiSummaryEn {
	_StringsStringsLegacyAiSummaryDe._(_StringsDe root) : this._root = root, super._(root);

	@override final _StringsDe _root; // ignore: unused_field

	// Translations
	@override String get error_api_key_empty => 'API-Schlüssel ist leer';
	@override late final _StringsStringsLegacyAiSummarySystemDe system = _StringsStringsLegacyAiSummarySystemDe._(_root);
	@override late final _StringsStringsLegacyAiSummaryUserDe user = _StringsStringsLegacyAiSummaryUserDe._(_root);
	@override String get error_invalid_response => 'Ungültiges AI-Antwortformat';
	@override String get error_empty_response => 'AI-Antwort ist leer';
	@override String get error_missing_content => 'Inhalt der AI-Antwort fehlt';
	@override String get default_prompt => 'Du bist ein minimalistischer Notizassistent. Extrahiere die Kernaussagen und formatiere sie elegant. Antworte professionell, freundlich und prägnant. Verwende nach Möglichkeit Listen und kurze Absätze.';
}

// Path: strings.legacy.ai_summary.system
class _StringsStringsLegacyAiSummarySystemDe extends _StringsStringsLegacyAiSummarySystemEn {
	_StringsStringsLegacyAiSummarySystemDe._(_StringsDe root) : this._root = root, super._(root);

	@override final _StringsDe _root; // ignore: unused_field

	// Translations
	@override String get require_json => 'Bitte ausschließlich JSON ausgeben. Keine Codeblöcke und keine zusätzlichen Erläuterungen.';
	@override String get json_format => 'JSON-Format: {"insights":["..."],"moodTrend":"...","keywords":["#..."]}';
	@override String get insights_rule => 'insights 2-5 Einträge, keywords 4-8 Begriffe mit #.';
}

// Path: strings.legacy.ai_summary.user
class _StringsStringsLegacyAiSummaryUserDe extends _StringsStringsLegacyAiSummaryUserEn {
	_StringsStringsLegacyAiSummaryUserDe._(_StringsDe root) : this._root = root, super._(root);

	@override final _StringsDe _root; // ignore: unused_field

	// Translations
	@override String range({required Object rangeLabel}) => 'Zeitraum: ${rangeLabel}';
	@override String counts({required Object memoCount, required Object includedCount}) => 'Memos: ${memoCount} (für die Zusammenfassung: ${includedCount})';
	@override String profile({required Object profile}) => 'Nutzerprofil: ${profile}';
	@override String custom_prompt({required Object customPrompt}) => 'Zusätzliche Anweisungen: ${customPrompt}';
	@override String get memo_content => 'Memo-Inhalt:';
}

// Path: <root>
class _StringsJa extends Translations {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	_StringsJa.build({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = TranslationMetadata(
		    locale: AppLocale.ja,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super.build(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		super.$meta.setFlatMapFunction($meta.getTranslation); // copy base translations to super.$meta
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <ja>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key) ?? super.$meta.getTranslation(key);

	@override late final _StringsJa _root = this; // ignore: unused_field

	// Translations
	@override late final _StringsStringsJa strings = _StringsStringsJa._(_root);
}

// Path: strings
class _StringsStringsJa extends _StringsStringsEn {
	_StringsStringsJa._(_StringsJa root) : this._root = root, super._(root);

	@override final _StringsJa _root; // ignore: unused_field

	// Translations
	@override late final _StringsStringsCommonJa common = _StringsStringsCommonJa._(_root);
	@override late final _StringsStringsLanguagesJa languages = _StringsStringsLanguagesJa._(_root);
	@override late final _StringsStringsLanguagesNativeJa languagesNative = _StringsStringsLanguagesNativeJa._(_root);
	@override late final _StringsStringsOnboardingJa onboarding = _StringsStringsOnboardingJa._(_root);
	@override late final _StringsStringsLoginJa login = _StringsStringsLoginJa._(_root);
	@override late final _StringsStringsSettingsJa settings = _StringsStringsSettingsJa._(_root);
	@override late final _StringsStringsLegacyJa legacy = _StringsStringsLegacyJa._(_root);
}

// Path: strings.common
class _StringsStringsCommonJa extends _StringsStringsCommonEn {
	_StringsStringsCommonJa._(_StringsJa root) : this._root = root, super._(root);

	@override final _StringsJa _root; // ignore: unused_field

	// Translations
	@override String get back => '戻る';
	@override String get cancel => 'キャンセル';
	@override String get confirm => '確認';
	@override String get save => '保存';
	@override String get saveSettings => '設定を保存';
	@override String get auto => '自動';
	@override String get manual => '手動';
	@override String get copiedToClipboard => 'クリップボードにコピーしました';
	@override String get serverVersion => 'サーバーバージョン';
	@override String get selectValidServerVersion => '有効なサーバーバージョンを選択してください';
	@override String serverVersionValue({required Object version}) => 'サーバーバージョン: ${version}';
	@override String get selectServerVersionRange021To026 => '0.21〜0.26 のサーバーバージョンを手動で選択してください';
}

// Path: strings.languages
class _StringsStringsLanguagesJa extends _StringsStringsLanguagesEn {
	_StringsStringsLanguagesJa._(_StringsJa root) : this._root = root, super._(root);

	@override final _StringsJa _root; // ignore: unused_field

	// Translations
	@override String get system => 'システムに従う';
	@override String get zhHans => '中国語（簡体字）';
	@override String get zhHantTw => '中国語（繁体字・中国台湾）';
	@override String get en => '英語';
	@override String get ja => '日本語';
	@override String get de => 'ドイツ語';
}

// Path: strings.languagesNative
class _StringsStringsLanguagesNativeJa extends _StringsStringsLanguagesNativeEn {
	_StringsStringsLanguagesNativeJa._(_StringsJa root) : this._root = root, super._(root);

	@override final _StringsJa _root; // ignore: unused_field

	// Translations
	@override String get system => 'システム';
	@override String get zhHans => '简体中文';
	@override String get zhHantTw => '繁體中文（中國台灣）';
	@override String get en => 'English';
	@override String get ja => '日本語';
	@override String get de => 'Deutsch';
}

// Path: strings.onboarding
class _StringsStringsOnboardingJa extends _StringsStringsOnboardingEn {
	_StringsStringsOnboardingJa._(_StringsJa root) : this._root = root, super._(root);

	@override final _StringsJa _root; // ignore: unused_field

	// Translations
	@override String get tagline => 'ミニマルで強力なノートストリーム';
	@override String get selectLanguage => '言語を選択';
	@override String get selectMode => 'モードを選択';
	@override String get modeHint => '後で設定で変更できます。';
	@override String get modeLocalTitle => 'ローカルモード';
	@override String get modeLocalLabel => 'ローカルモード';
	@override String get modeLocalDesc => 'データは端末内に保存されます。サーバー設定は不要で、プライバシー重視やオフライン利用に最適です。';
	@override String get modeServerTitle => 'サーバーモード';
	@override String get modeServerLabel => 'サーバーモード';
	@override String get modeServerDesc => 'Memos バックエンドに接続して、複数端末でリアルタイム同期します。';
	@override String get localLibraryNameTitle => 'ローカルライブラリ名';
	@override String get localLibraryNameHint => '名前を入力';
	@override String get localLibraryDefaultName => 'ローカルライブラリ';
	@override String get getStarted => 'はじめる';
}

// Path: strings.login
class _StringsStringsLoginJa extends _StringsStringsLoginEn {
	_StringsStringsLoginJa._(_StringsJa root) : this._root = root, super._(root);

	@override final _StringsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Memos に接続';
	@override late final _StringsStringsLoginModeJa mode = _StringsStringsLoginModeJa._(_root);
	@override late final _StringsStringsLoginFieldJa field = _StringsStringsLoginFieldJa._(_root);
	@override late final _StringsStringsLoginValidationJa validation = _StringsStringsLoginValidationJa._(_root);
	@override late final _StringsStringsLoginCompatibilityJa compatibility = _StringsStringsLoginCompatibilityJa._(_root);
	@override late final _StringsStringsLoginConnectJa connect = _StringsStringsLoginConnectJa._(_root);
	@override late final _StringsStringsLoginErrorsJa errors = _StringsStringsLoginErrorsJa._(_root);
}

// Path: strings.settings
class _StringsStringsSettingsJa extends _StringsStringsSettingsEn {
	_StringsStringsSettingsJa._(_StringsJa root) : this._root = root, super._(root);

	@override final _StringsJa _root; // ignore: unused_field

	// Translations
	@override late final _StringsStringsSettingsPreferencesJa preferences = _StringsStringsSettingsPreferencesJa._(_root);
}

// Path: strings.legacy
class _StringsStringsLegacyJa extends _StringsStringsLegacyEn {
	_StringsStringsLegacyJa._(_StringsJa root) : this._root = root, super._(root);

	@override final _StringsJa _root; // ignore: unused_field

	// Translations
	@override String get msg_memos_backend_docs => 'Memos バックエンドドキュメント';
	@override String get msg_remember_moment_feel_warmth_life_take => 'その瞬間を記録し、暮らしのぬくもりを感じましょう。\\n毎日さっと振り返りましょう。';
	@override String get msg_sure_want_delete_shortcut => 'このショートカットを削除してもよろしいですか？';
	@override String get msg_scan_completed => 'スキャン完了';
	@override String get msg_confirm => '確認';
	@override String get msg_unable_open_browser_install_browser_app => 'ブラウザを開けません。ブラウザアプリをインストールしてください。';
	@override String get msg_contributors => '貢献者';
	@override String get msg_enter_keywords_search_box_query_local => '検索ボックスにキーワードを入力して、ローカルの内容とタグを検索します。オフラインで利用可能です。初回利用時はローカルインデックスの作成完了までお待ちください。';
	@override String get msg_memo_not_found_locally => 'メモがローカルに見つかりません';
	@override String get msg_token => 'トークン';
	@override String get msg_last_7_days => '過去7日間';
	@override String get msg_search_memo_content => 'メモ内容を検索';
	@override String get msg_retry_started => '再試行を開始しました';
	@override String msg_last_year_memos({required Object lastYearMemos}) => '昨年: ${lastYearMemos} 件のメモ';
	@override String get msg_no_content_yet => 'まだ内容がありません';
	@override String get msg_no_summary_yet => 'まだ要約がありません';
	@override String get msg_sooner => ' 今すぐ！';
	@override String get msg_token_copied => 'トークンをコピーしました';
	@override String get msg_share => '共有';
	@override String get msg_gallery_permission_required => 'ギャラリーへのアクセス権が必要です';
	@override String get msg_basic_settings => '基本設定';
	@override String get msg_bad_ssl_certificate => 'SSL証明書が不正です。';
	@override String get msg_no_notifications => '通知はありません';
	@override String get msg_import_markdown => 'Markdown からインポート';
	@override String get msg_upload_zip_package_md_files => '.md ファイルを含む .zip パッケージをアップロードしてください';
	@override String get msg_request_send_timeout_try => 'リクエストの送信がタイムアウトしました。再試行してください。';
	@override String get msg_select_date_range => '日付範囲を選択';
	@override String get msg_delete_shortcut => 'ショートカットを削除';
	@override String get msg_auto_lock_time => '自動ロック時間';
	@override String get msg_replacing_delete_original_attachment_continue => '置き換えると元の添付ファイルは削除されます。続行しますか？';
	@override String get msg_add_least_one_condition => '条件を少なくとも1つ追加してください。';
	@override String get msg_upload_images_image_bed_append_links => '画像を画像ホスティングにアップロードし、リンクをメモに追記します。';
	@override String get msg_request_cancelled => 'リクエストがキャンセルされました。';
	@override String get msg_generating => '生成しますか？';
	@override String get msg_permissions_denied_reminders_disabled => '権限が拒否されました。リマインダーは無効です。';
	@override String get msg_memoflow_local_reminders => 'MemoFlow ローカルリマインダー';
	@override String get msg_use_legacy_endpoints_older_memos_servers => 'レガシーエンドポイントを使用（旧Memosサーバー向け）。';
	@override String get msg_no_comments_yet => 'まだコメントがありません';
	@override String get msg_open => '開く';
	@override String get msg_microphone_permission_required => 'マイクへのアクセス権が必要です';
	@override String msg_failed_react({required Object e}) => 'リアクションに失敗しました: ${e}';
	@override String get msg_restore_backup => 'バックアップを復元しますか？';
	@override String get msg_qr_saved_gallery => 'QRをギャラリーに保存しました';
	@override String get msg_no_attachments => '添付ファイルはありません';
	@override String get msg_enable_reminder_permissions => 'リマインダー権限を有効にする';
	@override String get msg_created_time => '作成日時 ↑';
	@override String get msg_prompt_saved_quick_prompts => 'あなたのプロンプトはクイックプロンプトに保存されます';
	@override String get msg_remember_password => 'パスワードを記憶';
	@override String get msg_enter_valid_url => '有効なURLを入力してください';
	@override String get msg_may_take_few_seconds => 'これには数秒かかる場合があります';
	@override String msg_local_sync_failed({required Object type, required Object memoError}) => 'ローカル同期に失敗しました（${type}）: ${memoError}';
	@override String get msg_webdav_sync => 'WebDAV 同期';
	@override String get msg_clear => 'クリア';
	@override String get msg_clear_recycle_bin_confirm => 'ごみ箱を空にしますか？中の項目はすべて完全に削除されます。';
	@override String get msg_save_failed => '保存に失敗しました';
	@override String get msg_endpoint_not_found_version_mismatch => 'エンドポイントが見つかりません（バージョン不一致？）';
	@override String get msg_enable_webdav_sync => 'WebDAV 同期を有効にする';
	@override String get msg_local_libraries => 'ローカルライブラリ';
	@override String get msg_apply => '適用';
	@override String get msg_restore_only_available_local_libraries => '復元はローカルライブラリでのみ利用できます。';
	@override String get msg_sign => 'サインアウトしますか？';
	@override String get msg_reminders_disabled => 'リマインダーは無効です';
	@override String get msg_downloading => 'ダウンロード中...';
	@override String get msg_path => 'パス';
	@override String get msg_match_any => 'いずれかに一致';
	@override String get msg_local_db_pending_queue => 'ローカルDB + 保留キュー';
	@override String msg_scan_failed({required Object e}) => 'スキャンに失敗しました: ${e}';
	@override String get msg_user => 'ユーザー';
	@override String get msg_pick_future_time => '未来の時刻を選択してください';
	@override String get msg_include_pending_queue => '保留キューを含める';
	@override String get msg_enter_days => '日数を入力';
	@override String get msg_times => '回数';
	@override String get msg_token_returned_only_once_cannot_fetched => 'トークンは一度だけ返され、再取得できません';
	@override String msg_quoted_lines({required Object quoteLines}) => '${quoteLines} 行を引用';
	@override String get msg_use_remote => 'リモートを使用';
	@override String get msg_enable_memo_location => 'メモの位置情報を有効にする';
	@override String get msg_failed_get_location => '位置情報の取得に失敗しました';
	@override String get msg_after_import_memos_sync_list_automatically => 'インポート後、メモは自動的に一覧へ同期されます。ZIPインポートの場合は、ファイル構造が正しいことを確認してください。';
	@override String get msg_legacy_mode => 'レガシーモード';
	@override String get msg_signed => 'サインイン済み';
	@override String get msg_shortcut_includes_advanced_conditions_saving_overwrite => 'このショートカットには高度な条件が含まれています。保存するとそれらは上書きされます。';
	@override String get msg_no_results_found => '結果が見つかりません';
	@override String msg_reply({required Object replyName}) => '${replyName} に返信...';
	@override String get msg_copy => 'コピー';
	@override String get msg_enable_reminders_memos => 'メモのリマインダーを有効にします。';
	@override String get msg_comment => 'コメント';
	@override String get msg_added_voice_attachment => '音声添付を追加しました。';
	@override String get msg_customize_sidebar => 'サイドバーをカスタマイズ';
	@override String get msg_coffee_add_drumstick => '☕ コーヒーで / ドラムスティックを追加';
	@override String get msg_pin => 'ピン留め';
	@override String get msg_enter_password_continue => '続行するにはパスワードを入力してください';
	@override String get msg_remove_local_library => 'ローカルライブラリを削除しますか？';
	@override String get msg_comment_2 => '新しいコメント';
	@override String get msg_sync_all => 'すべて同期';
	@override String get msg_backup_schedule => 'バックアップスケジュール';
	@override String get msg_server_error => 'サーバーエラー';
	@override String get msg_analyzing_memos => 'メモを解析中...';
	@override String get msg_notification => '通知';
	@override String get msg_policy => 'ポリシー';
	@override String msg_failed_load({required Object error}) => '読み込みに失敗しました: ${error}';
	@override String get msg_default_visibility => 'デフォルトの公開範囲';
	@override String get msg_filter => 'フィルター';
	@override String get msg_imported_memos => 'メモをインポートしました';
	@override String get msg_token_created => 'トークンを作成しました';
	@override String get msg_server_response_timeout_try => 'サーバーの応答がタイムアウトしました。もう一度お試しください。';
	@override String get msg_expiring => '期限切れ予定';
	@override String get msg_delete_task => 'タスクを削除';
	@override String get msg_body_must_json => '本文はJSONである必要があります';
	@override String get msg_enable => '有効にする';
	@override String get msg_referenced => '参照元';
	@override String get msg_replace_image => '画像を置き換えますか？';
	@override String get msg_debug_logs => 'デバッグログ';
	@override String get msg_active_tasks => 'アクティブなタスク';
	@override String get msg_attachments => '添付ファイル';
	@override String get msg_range => '範囲';
	@override String get msg_no_backups_found => 'バックアップが見つかりません';
	@override String get msg_create_memo => 'メモを作成';
	@override String get msg_street => '番地';
	@override String get msg_display_name => '表示名';
	@override String get msg_full_text_search => '全文検索';
	@override String get msg_create_edit_delete_actions_offline_stored => 'オフラインでの作成・編集・削除操作はローカルに保存され、同期キューに追加されます。オンライン時に順番に送信されます。ミスを防ぐため、未送信の編集は下書きとして保持できます。';
	@override String get msg_sign_2 => 'サインアウト';
	@override String get msg_end_time => '終了時刻';
	@override String get msg_sync_recent_content => '最近のコンテンツを同期';
	@override String get msg_resetting_local_data => 'ローカルデータをリセット中...';
	@override String get msg_incorrect_password => 'パスワードが正しくありません';
	@override String get msg_content_cannot_empty => '内容を空にすることはできません';
	@override String get msg_preparing => '準備中';
	@override String msg_ai_summary_failed({required Object formatSummaryError_e}) => 'AI要約に失敗しました: ${formatSummaryError_e}';
	@override String get msg_manage => '管理';
	@override String get msg_keep_data_consistent_across_devices => 'デバイス間でデータの整合性を保ちます。';
	@override String msg_playback_failed({required Object e}) => '再生に失敗しました: ${e}';
	@override String get msg_path_copied => 'パスをコピーしました';
	@override String get msg_auth_settings => '認証設定';
	@override String get msg_randomly_draw_memo_cards => 'メモカードをランダムに引く';
	@override String get msg_copy_log_text => 'ログテキストをコピー';
	@override String get msg_yes => 'はい';
	@override String get msg_save_open_alipay_scan => '保存してAlipayを開き、スキャンしてください';
	@override String get msg_signed_but_no_token_returned => 'サインインしましたが、トークンが返されませんでした';
	@override String msg_create_failed({required Object formatError_e_context}) => '作成に失敗しました: ${formatError_e_context}';
	@override String get msg_expand => '展開';
	@override String get msg_local_library_only => 'ローカルライブラリのみ';
	@override String get msg_reminder_channel => 'リマインダーチャンネル';
	@override String get msg_grant => '許可';
	@override String get msg_import_canceled => 'インポートをキャンセルしました。';
	@override String get msg_never => 'しない';
	@override String get msg_release_notes => 'リリースノート';
	@override String get msg_failed_load_references => '参照の読み込みに失敗しました';
	@override String get msg_select_tags => 'タグを選択';
	@override String get msg_failed_load_try => '読み込みに失敗しました。もう一度お試しください。';
	@override String get msg_logs_copied => 'ログをコピーしました';
	@override String get msg_shortcuts_not_supported_server => 'このサーバーではショートカットはサポートされていません。';
	@override String msg_reply_2({required Object name}) => '${name} に返信...';
	@override String get msg_anonymous => '匿名';
	@override String get msg_username => 'ユーザー名';
	@override String get msg_update_memo => 'メモを更新';
	@override String msg_saved({required Object targetPath}) => '保存先: ${targetPath}';
	@override String get msg_chinese_simplified => '中国語（簡体字）';
	@override String get msg_memo_copied => 'メモをコピーしました';
	@override String get msg_collapse => '折りたたむ';
	@override String get msg_retry_count_controls_how_many_extra => '再試行回数は、失敗時に行う追加試行の回数を制御します。値を大きくすると成功率が上がる可能性がありますが、時間がかかります。';
	@override String get msg_recording_info_missing => '記録情報がありません';
	@override String get msg_sync_task => '同期タスク';
	@override String get msg_clear_all_debug_logs => 'すべてのデバッグログを消去しますか？';
	@override String get msg_export_finished => 'エクスポートが完了しました';
	@override String msg_failed_stop_recording({required Object e}) => '記録の停止に失敗しました: ${e}';
	@override String get msg_my_profile => 'マイプロフィール';
	@override String get msg_image_bed => '画像ベッド';
	@override String msg_failed_open_notification({required Object e}) => '通知を開けませんでした: ${e}';
	@override String get msg_manual => 'マニュアル';
	@override String get msg_no_html_file_found_zip => 'ZIP内にHTMLファイルが見つかりませんでした。';
	@override String get msg_also_clear_local_cache_account_offline => 'この操作により、このアカウントのローカルキャッシュ（オフラインデータ／下書き／保留中の同期キュー）も削除されます。この操作は元に戻せません。';
	@override String get msg_restore => '復元';
	@override String get msg_auto_backup => '自動バックアップ';
	@override String get msg_generate_summary => '要約を生成';
	@override String msg_days({required Object stats_activeDays}) => '${stats_activeDays}日';
	@override String get msg_count => '- 件数';
	@override String get msg_weekly => '毎週';
	@override String get msg_notifications => '通知';
	@override String get msg_backup_failed => 'バックアップに失敗しました';
	@override String get msg_private => '非公開';
	@override String get msg_filter_tags => 'タグで絞り込む';
	@override String get msg_clear_logs => 'ログを消去';
	@override String get msg_unable_open_browser => 'ブラウザを開けません';
	@override String get msg_attachment_too_large => '添付ファイルが大きすぎます';
	@override String get msg_query => 'クエリ';
	@override String get msg_match_all => 'すべて一致';
	@override String get msg_record_request_response_logs => 'リクエスト／レスポンスログを記録';
	@override String get msg_import_file => 'ファイルをインポート';
	@override String get msg_content_tags => '本文＋タグ';
	@override String get msg_feature_not_available_local_library_mode => 'この機能はローカルライブラリモードでは利用できません。';
	@override String msg_import_failed({required Object e}) => 'インポートに失敗しました: ${e}';
	@override String get msg_save_memo => 'メモとして保存';
	@override String get msg_scan_disk_directory_merge_local_database => 'ディスクディレクトリをスキャンしてローカルデータベースに統合しますか？ 見つからないファイルは削除として扱われます。';
	@override String get msg_passwords_not_match => 'パスワードが一致しません';
	@override String msg_signed_2({required Object lastLoginUser}) => 'サインイン中: ${lastLoginUser}';
	@override String get msg_made_love_note_taking => 'メモ作成を愛するあなたへ、心を込めて';
	@override String get msg_password_updated_local => 'パスワードを更新しました（ローカル）';
	@override String get msg_retry => '再試行';
	@override String get msg_memo_stats => 'メモ統計';
	@override String get msg_shown_only_once_copy_keep_safe => '一度だけ表示されます。コピーして安全に保管してください。';
	@override String get msg_describe_issue_time_repro_steps_etc => '問題の内容、発生時刻、再現手順などを記載してください。';
	@override String get msg_how_many_days_back => '何日前まで';
	@override String get msg_local_cache_cleared => 'ローカルキャッシュを消去しました';
	@override String get msg_none => 'なし';
	@override String get msg_body_json => '本文（JSON）';
	@override String msg_download_failed({required Object e}) => 'ダウンロードに失敗しました: ${e}';
	@override String get msg_recycle_bin => 'ごみ箱';
	@override String get msg_unpin => 'ピン留めを解除';
	@override String get msg_advanced_security => '詳細とセキュリティ';
	@override String get msg_run_issues_memoflow_e_g_sync => 'MemoFlowで問題（例: 同期失敗、クラッシュ）が発生した場合は、以下の手順に従ってください。問題の診断と修正をより迅速に行うために役立ちます。\\n\\n';
	@override String get msg_remove_all_reminder_times_memo => 'このメモのすべてのリマインダー時刻を削除します。';
	@override String get msg_no_summary_save => '保存する要約がありません';
	@override String get msg_reset_language_selection => '言語選択をリセット';
	@override String get msg_v_30_days => '30日';
	@override String get msg_e_g_mood_check => '例: 気分チェック';
	@override String get msg_note_some_tokens_returned_only_once => '注意: 一部のトークンは一度しか返されず、後から取得できません。安全に保管してください。';
	@override String get msg_syncing => '同期中...';
	@override String get msg_retention => '保持期間';
	@override String get msg_open_login_screen => 'ログイン画面を開く';
	@override String get msg_apply_all => 'すべてに適用';
	@override String get msg_write_something_supports_tag_tasks_x => '何か書いてみましょう... #タグ とタスク [ ] / [x] をサポート';
	@override String msg_http({required Object base, required Object status, required Object msg}) => '${base}（HTTP ${status}）: ${msg}';
	@override String get msg_single => '単一';
	@override String get msg_delete_memo => 'メモを削除しますか？';
	@override String get msg_ai_provider => 'AIプロバイダー';
	@override String msg_release_notes_v({required Object version}) => 'リリースノート v${version}';
	@override String get msg_info_only_used_background_ai_summaries => 'この情報はAI要約／レポートの背景情報としてのみ使用され、バックエンドには同期されません。';
	@override String get msg_not_disturb => 'おやすみモード';
	@override String msg_local_library_import_failed({required Object e}) => 'ローカルライブラリのインポートに失敗しました: ${e}';
	@override String get msg_key_insights => '主なインサイト';
	@override String get msg_additional_notes_optional => '追加メモ（任意）';
	@override String get msg_server_response_error => 'サーバー応答エラー。';
	@override String get msg_sort => '並び替え';
	@override String get msg_api_call => 'API呼び出し';
	@override String get msg_webhooks => 'Webhook';
	@override String get msg_local_library => 'ローカルライブラリ';
	@override String get msg_log_copied => 'ログをコピーしました';
	@override String get msg_last_success => '最終成功';
	@override String get msg_restore_cloud => 'クラウドから復元';
	@override String get msg_search_public_memos => '公開メモを検索';
	@override String get msg_cancel => 'キャンセル';
	@override String msg_processing({required Object processed, required Object total}) => '${processed} / ${total} を処理中';
	@override String get msg_failed_items => '失敗した項目';
	@override String get msg_recording_file_not_found => '録音ファイルが見つかりません';
	@override String get msg_local_db_outbox_queue => 'ローカルDB＋outboxキュー';
	@override String get msg_remove => '削除';
	@override String get msg_export_format => 'エクスポート形式';
	@override String get msg_idle => '待機中';
	@override String msg_ago({required Object months}) => '${months}前';
	@override String get msg_no_tags_yet => 'タグはまだありません';
	@override String msg_version_v({required Object version}) => 'バージョン v${version}';
	@override String get msg_sync => '同期';
	@override String get msg_done => '完了';
	@override String get msg_gallery_permission_required_2 => 'ギャラリーへのアクセス権が必要です';
	@override String get msg_insufficient_permissions => '権限が不足しています';
	@override String get msg_no_download_url_available => 'ダウンロードURLが利用できません';
	@override String get msg_record_create_memos => 'メモを作成するために記録する';
	@override String get msg_signing => 'サインイン中...';
	@override String get msg_memoflow_uses_system_location_permission_get => 'MemoFlowは座標を取得するためにシステムの位置情報権限を使用し、その後Amap Web APIで逆ジオコーディングを行います。表示精度は上で選択できます。';
	@override String get msg_continue => '続行';
	@override String get msg_notification_content_unavailable => '通知内容を利用できません';
	@override String get msg_unable_read_file_path => 'ファイルパスを読み取れません。';
	@override String get msg_all_memos => 'すべてのメモ';
	@override String get msg_keywords => 'キーワード';
	@override String get msg_import_result => 'インポート結果';
	@override String get msg_offline_sync => 'オフライン同期';
	@override String get msg_imported_memos_local_library => 'ローカルライブラリからメモをインポートしました';
	@override String get msg_request_failed => 'リクエストに失敗しました';
	@override String get msg_log_file => 'ログファイル';
	@override String get msg_after_confirming_support_unlock_limited_gold => 'サポートを確認すると、期間限定のゴールドバッジまたは永久広告なしの約束（そもそも広告はありませんでした）が解除されます。';
	@override String get msg_failed_open_system_settings => 'システム設定を開けませんでした';
	@override String get msg_no_mood_trend => '気分の推移はありません';
	@override String get msg_memoflow_export => '# MemoFlow エクスポート';
	@override String get msg_sync_queue => '同期キュー';
	@override String get msg_only_delete_sync_task_memo_kept => '同期タスクのみを削除します。メモは保持されます。';
	@override String get msg_add_home_screen => 'ホーム画面に追加';
	@override String get msg_past_days => '過去の日数';
	@override String get msg_poster_generation_failed => 'ポスターの生成に失敗しました';
	@override String msg_failed_load_stats({required Object e}) => '統計の読み込みに失敗しました: ${e}';
	@override String get msg_customize_notification => '通知をカスタマイズ';
	@override String get msg_updated_time => '更新時刻 ↓';
	@override String get msg_network_connection_failed_check_network => 'ネットワーク接続に失敗しました。ネットワークをご確認ください。';
	@override String get msg_special_thanks => '特別な感謝:';
	@override String msg_failed_comment({required Object e}) => 'コメントに失敗しました: ${e}';
	@override String get msg_security_key_sig => 'セキュリティキー（sig）';
	@override String get msg_save_gallery => 'ギャラリーに保存';
	@override String get msg_request_sent_confirm_system_prompt => 'リクエストを送信しました。システムのプロンプトで確認してください';
	@override String get msg_server_url => 'サーバーURL';
	@override String get msg_period_review => '期間レビュー';
	@override String get msg_settings_updated => '設定を更新しました';
	@override String get msg_backend_0_21_not_supported_import => 'バックエンド 0.21 はインポートに対応していません。アップグレードして再試行してください。';
	@override String msg_failed_load_tags({required Object e}) => 'タグの読み込みに失敗しました: ${e}';
	@override String get msg_enter_email => 'メールアドレスを入力';
	@override String get msg_add_webhook => 'Webhookを追加';
	@override String get msg_read => '既読';
	@override String get msg_widgets => 'ウィジェット';
	@override String get msg_default => 'デフォルト';
	@override String get msg_memo_reminders => 'メモのリマインダー';
	@override String get msg_import_flomo => 'Flomoからインポート';
	@override String get msg_format_fixed_markdown_zip => '形式はMarkdown + ZIPに固定されています';
	@override String get msg_enter_username_password => 'ユーザー名とパスワードを入力';
	@override String get msg_loading => '読み込み中...';
	@override String msg_test_scheduled({required Object timeLabel, required Object suffix, required Object pendingLabel}) => 'テストは ${timeLabel}${suffix}${pendingLabel} に予定されています';
	@override String get msg_edit_memo => 'メモを編集';
	@override String get msg_save => '保存';
	@override String get msg_laboratory => 'ラボ';
	@override String get msg_use_local => 'ローカルを使用';
	@override String get msg_retry_sync => '同期を再試行';
	@override String get msg_e_g_my_role_topics_interest => '例：自分の役割／関心のあるトピック／文体の好み など';
	@override String get msg_confirm_password => 'パスワードを確認';
	@override String get msg_not_set => '未設定';
	@override String get msg_no_memos_day => 'この日のメモはありません';
	@override String get msg_shortcut_name => 'ショートカット名';
	@override String get msg_edit_shortcut => 'ショートカットを編集';
	@override String get msg_days_memos => 'メモのある日数';
	@override String get msg_delete => '削除';
	@override String get msg_test_reminder => 'テスト通知';
	@override String get msg_enable_reminders => 'リマインダーを有効にする';
	@override String get msg_links => 'リンク';
	@override String get msg_location => '位置情報';
	@override String get msg_import_file_2 => 'ファイルからインポート';
	@override String msg_reply_3({required Object creatorDisplayName_commentCreator_commentMemo_creator}) => '${creatorDisplayName_commentCreator_commentMemo_creator} に返信…';
	@override String msg_created({required Object widget_createdAtLabel}) => '${widget_createdAtLabel} を作成';
	@override String get msg_notifications_coming_soon => '通知：近日公開';
	@override String get msg_view_full_contributors => 'すべてのコントリビューターを見る';
	@override String get msg_no_times_set => '時間が設定されていません';
	@override String get msg_ignore_tls_errors => 'TLS エラーを無視';
	@override String get msg_no_content => '内容がありません';
	@override String get msg_about_15_seconds_left => '約15秒残っています';
	@override String get msg_view_imported_memos => 'インポートしたメモを見る';
	@override String get msg_load_failed => '読み込みに失敗しました';
	@override String get msg_disk_content_conflicts_local_pending_changes => 'ディスク上の内容がローカルの保留中の変更と競合しています。ディスク上の内容でローカルの内容を上書きしてください。';
	@override String get msg_all_history_so_far_memoflow_since => 'これまでの履歴は以上です\\nMEMOFLOW SINCE 2023';
	@override String get msg_cancelling => 'キャンセル中';
	@override String get msg_reading_file => 'ファイルを読み込み中…';
	@override String get msg_switch_workspace => 'ワークスペースを切り替え';
	@override String get msg_optional_leave_empty_default => '任意。デフォルトを使用する場合は空欄のままにしてください。';
	@override String get msg_memo_reminders_2 => 'メモのリマインダー';
	@override String msg_save_failed_2({required Object e}) => '保存に失敗しました: ${e}';
	@override String get msg_record_create_memos_sync_later => '録音してメモを作成（後で同期）';
	@override String get msg_use_https_avoid_ignoring_tls_errors => '認証情報を保護するため、HTTPS を使用し、TLS エラーの無視は避けてください。';
	@override String get msg_failed_load_announcement_config => 'お知らせ設定の読み込みに失敗しました';
	@override String get msg_shortcuts => 'ショートカット';
	@override String get msg_memo => 'メモ';
	@override String get msg_maybe_later => '後で';
	@override String get msg_server_connection => 'サーバー接続';
	@override String get msg_days_2 => '日';
	@override String get msg_include_archived => 'アーカイブを含む';
	@override String get msg_during_quiet_hours_reminders_silenced => '静かな時間帯は、リマインダーは通知されません。';
	@override String get msg_preview_not_supported_type => 'この種類ではプレビューはサポートされていません';
	@override String get msg_failed_load_2 => '読み込みに失敗しました';
	@override String get msg_create_token => '新しいトークンを作成';
	@override String get msg_enter_name => '名前を入力してください。';
	@override String get msg_api_url_incorrect => 'API URL が正しくありません。';
	@override String get msg_user_general_settings => 'ユーザー一般設定';
	@override String get msg_saved_memo => 'メモとして保存しました';
	@override String msg_restore_failed({required Object e}) => '復元に失敗しました: ${e}';
	@override String msg_token_tail({required Object tail}) => 'トークン末尾 ${tail}';
	@override String get msg_manual_token => '手動トークン';
	@override String msg_ago_2({required Object years}) => '${years} 前';
	@override String get msg_recent_searches => '最近の検索';
	@override String get msg_restored => '復元しました';
	@override String get msg_no_contributors_yet => 'コントリビューターはまだいません';
	@override String get msg_no_record_yet => '記録はまだありません';
	@override String get msg_reminder => 'リマインダー';
	@override String get msg_enter_api_key_ai_settings => 'AI 設定で API キーを入力してください';
	@override String get msg_reminder_settings => 'リマインダー設定';
	@override String msg_http_2({required Object base, required Object status}) => '${base}（HTTP ${status}）';
	@override String get msg_edit_webhook => 'Webhook を編集';
	@override String get msg_generate_share_poster => '共有ポスターを生成';
	@override String msg_archive_failed({required Object e}) => 'アーカイブに失敗しました: ${e}';
	@override String msg_comments({required Object widget_commentCount}) => '${widget_commentCount} 件のコメント';
	@override String get msg_remove_account => 'アカウントを削除しますか？';
	@override String get msg_chinese_traditional => '中国語（繁体字）';
	@override String get msg_private_2 => '非公開';
	@override String get msg_current_streak => '現在の連続記録';
	@override String get msg_generated_ai_memoflow => 'AI により生成 · MemoFlow';
	@override String get msg_edit_completed => '編集が完了しました';
	@override String get msg_local => 'ローカル';
	@override String get msg_edit => '編集';
	@override String msg_text({required Object shortUserName_item_sender}) => '${shortUserName_item_sender} から';
	@override String get msg_got => '了解';
	@override String get msg_web_api_key => 'Web API キー';
	@override String get msg_preview => 'プレビュー';
	@override String get msg_enter_password => 'パスワードを入力してください';
	@override String get msg_api => 'API';
	@override String get msg_ok => 'OK';
	@override String get msg_failed_load_shortcuts => 'ショートカットの読み込みに失敗しました。';
	@override String get msg_after_recording_audio_added_current_draft => '録音後、音声は添付ファイルとして現在の下書きに追加されるため、送信前に編集できます。最大長は60分です。文字起こしは後でサードパーティサービスを使って追加できます。';
	@override String get msg_pull_refresh => '引っ張って更新';
	@override String get msg_unable_open_photo => '写真を開けません';
	@override String get msg_existing_tokens => '既存のトークン';
	@override String get msg_ai_settings => 'AI 設定';
	@override String get msg_app_lock => 'アプリロック';
	@override String get msg_total_notes => 'メモ総数';
	@override String get msg_stats_loading => '統計を読み込み中';
	@override String get msg_enter_token_description => 'トークンの説明を入力';
	@override String get msg_enter_token => 'トークンを入力';
	@override String get msg_api_plugins => 'API とプラグイン';
	@override String get msg_parsing_file => 'ファイルを解析中…';
	@override String get msg_english => '英語';
	@override String get msg_activity_heatmap => 'アクティビティヒートマップ';
	@override String get msg_mark_read => '既読にする';
	@override String get msg_request => 'リクエスト';
	@override String msg_sync_failed({required Object type, required Object memoError}) => '同期に失敗しました（${type}）: ${memoError}';
	@override String get msg_error_copied => 'エラーをコピーしました';
	@override String get msg_only_local_index_removed_disk_files => 'ローカルインデックスのみが削除され、ディスク上のファイルは保持されます。これは元に戻せません。';
	@override String get msg_switch_account => 'アカウントを切り替え';
	@override String get msg_invalid_download_link => '無効なダウンロードリンク';
	@override String get msg_about => '情報';
	@override String get msg_icon => 'アイコン';
	@override String get msg_reset_done_syncing => 'リセット完了。同期中...';
	@override String get msg_enter_amap_web_api_key => 'Amap Web APIキーを入力してください';
	@override String get msg_recycle_bin_coming_soon => 'ごみ箱：近日対応';
	@override String get msg_empty_content => '（内容が空です）';
	@override String get msg_note_most_features_offline_stats_ai => '注: ほとんどの機能（オフライン/統計/AIレポート/エクスポート）はバックエンド変更なしで動作しますが、トークンは一度しか返されません？安全に保管してください。';
	@override String get msg_fixed => '修正済み: ';
	@override String get msg_allow_sharing_links_images_other_apps => '他のアプリからのリンクや画像をMemoFlowに共有できるようにします。';
	@override String get msg_invalid_request_parameters => 'リクエストパラメータが無効です';
	@override String get msg_enter_api_url => 'API URLを入力してください';
	@override String msg_pending({required Object result_pendingCount}) => '（保留中 ${result_pendingCount}）';
	@override String msg_days_3({required Object currentStreak}) => '${currentStreak}日';
	@override String get msg_poster_not_ready_yet => 'ポスターはまだ準備できていません';
	@override String get msg_generated_memoflow => 'MemoFlow により生成';
	@override String get msg_enter_name_2 => '名前を入力してください';
	@override String get msg_version => 'バージョン';
	@override String get msg_memo_missing_disk_but_has_local => 'メモがディスク上に見つかりませんが、ローカルに保留中の変更があります。ローカルで削除するにはディスクを使用してください。';
	@override String get msg_legacy_api_compatibility => 'レガシーAPI互換性';
	@override String get msg_sync_parameters => '同期パラメータ';
	@override String get msg_quick_prompts => 'クイックプロンプト';
	@override String msg_share_failed({required Object e}) => '共有に失敗しました: ${e}';
	@override String get msg_no_memos_summarize_range => 'この範囲に要約できるメモはありません';
	@override String get msg_characters => '文字数';
	@override String get msg_capture_every_moment_record => '記録するすべての瞬間を残そう';
	@override String get msg_vibration => 'バイブレーション';
	@override String get msg_days_4 => '日';
	@override String get msg_prompt_title => 'プロンプトタイトル';
	@override String get msg_show_all => 'すべて表示';
	@override String get msg_no_memos_available => '利用可能なメモがありません';
	@override String get msg_comment_unavailable => 'コメントは利用できません';
	@override String get msg_refresh => '更新';
	@override String get msg_syncing_2 => '同期中';
	@override String get msg_body => '本文';
	@override String get msg_clear_2 => 'クリア';
	@override String get msg_third_party_share => 'サードパーティ共有';
	@override String get msg_charging_station => '充電ステーション';
	@override String get msg_attachments_2 => '添付ファイル';
	@override String get msg_when_enabled_must_verify_each_app => '有効にすると、アプリ起動のたびに認証が必要になります。自動ロック時間は、アプリがバックグラウンドに移行した後、どれくらいで認証を要求するかを制御します。';
	@override String get msg_add_prompt => 'プロンプトを追加';
	@override String get msg_include => '含める';
	@override String get msg_created_time_2 => '作成日時 ↓';
	@override String get msg_choose_data_source_start_importing_memos => 'メモのインポートを開始するデータソースを選択してください';
	@override String get msg_describe_how_want_summary => '要約の希望内容を説明してください…';
	@override String get msg_keep_token_safe_not_share_api => 'トークンは安全に保管し、共有しないでください。\\nAPIのレート制限は1分あたり60リクエストです。';
	@override String get msg_open_2 => '開く';
	@override String get msg_e_g_claude_3_5_sonnet => '例: claude-3-5-sonnet-20241022';
	@override String get msg_failed_request_whitelist => 'ホワイトリストのリクエストに失敗しました';
	@override String get msg_notification_deleted => '通知を削除しました';
	@override String get msg_accounts => 'アカウント';
	@override String get msg_add_local_library => 'ローカルライブラリを追加';
	@override String get msg_sign_first => '先にサインインしてください';
	@override String get msg_failed_parse_query => 'クエリの解析に失敗しました';
	@override String get msg_note_logs_sanitized_automatically_sensitive_data => '注: ログは自動的にサニタイズされます。機密データが残っている場合は、送信前にマスキングしてください。';
	@override String get msg_add => '追加';
	@override String msg_failed_load_3({required Object memosError}) => '読み込みに失敗しました: ${memosError}';
	@override String get msg_max_chars_day => '1日あたりの最大文字数';
	@override String get msg_choose_what_edited_image => '編集した画像をどうするか選択してください。';
	@override String get msg_select => '選択';
	@override String get msg_unnamed_token => '（名前のないトークン）';
	@override String get msg_name => '名前';
	@override String get msg_sure_want_delete_webhook => 'このWebhookを削除してもよろしいですか？';
	@override String get msg_back => '戻る';
	@override String get msg_no => 'いいえ';
	@override String get msg_untitled => '無題';
	@override String get msg_open_language_onboarding => '言語オンボーディングを開く';
	@override String get msg_voice_memos => 'ボイスメモ';
	@override String get msg_unable_open_browser_try => 'ブラウザを開けませんでした。もう一度お試しください。';
	@override String get msg_date_range => '日付範囲';
	@override String get msg_not_authenticated => '認証されていません';
	@override String get msg_back_2 => '戻る';
	@override String get msg_local_library_removed => 'ローカルライブラリを削除しました';
	@override String get msg_exact_alarm_permission_required => '正確なアラーム権限が必要です';
	@override String get msg_visibility => '公開範囲';
	@override String msg_failed_start_recording({required Object e}) => '録音の開始に失敗しました: ${e}';
	@override String get msg_mood_trend => '気分の傾向';
	@override String get msg_local_library_name => 'ローカルライブラリ名';
	@override String get msg_no_tokens_yet => 'トークンはまだありません';
	@override String get msg_loading_2 => '読み込み中？';
	@override String get msg_location_permission_denied_permanently => '位置情報の権限が永久に拒否されています';
	@override String get msg_download => 'ダウンロード';
	@override String get msg_export_time => '- エクスポート時刻';
	@override String get msg_enter_password_2 => 'パスワードを入力してください';
	@override String get msg_no_image_available => '利用可能な画像がありません';
	@override String get msg_daily => '毎日';
	@override String get msg_no_likes_yet => 'いいねはまだありません';
	@override String get msg_basics => '基本';
	@override String get msg_shortcut => '新しいショートカット';
	@override String get msg_debug_tools => 'デバッグツール';
	@override String get msg_save_settings => '設定を保存';
	@override String get msg_date_range_2 => '日付範囲';
	@override String get msg_feedback => 'フィードバック';
	@override String get msg_image_bed_2 => '画像ベッド';
	@override String get msg_restoring => '復元中…';
	@override String get msg_export => 'エクスポート';
	@override String get msg_enter_token_name => 'トークン名を入力してください';
	@override String get msg_start_time => '開始時刻';
	@override String get msg_preparing_file_structure => 'ファイル構造を準備中';
	@override String get msg_sign_3 => 'サインイン';
	@override String get msg_scan_local_library => 'ローカルライブラリをスキャン';
	@override String get msg_lsky_pro => 'Lsky Pro';
	@override String get msg_exact_alarm_permission_off_reminders_may => '正確なアラーム権限がオフです。リマインダーが時間どおりに通知されない可能性があります。今すぐ設定を開きますか？';
	@override String get msg_last_30_days => '過去30日間';
	@override String get msg_match => '一致';
	@override String get msg_auth_mode => '認証モード';
	@override String get msg_unsupported_file_type => 'サポートされていないファイル形式です。';
	@override String get msg_only_delete_sync_task => '同期タスクのみを削除します。';
	@override String get msg_change_password => 'パスワードを変更';
	@override String get msg_saved_2 => '保存済み';
	@override String get msg_import_export => 'インポート / エクスポート';
	@override String get msg_created_2 => '作成日';
	@override String get msg_ai_summary => 'AI要約';
	@override String get msg_progress => '進行状況';
	@override String get msg_replace_memo_image => 'メモ画像を置き換える';
	@override String get msg_app_settings => 'アプリ設定';
	@override String get msg_copy_path => 'パスをコピー';
	@override String get msg_components => 'コンポーネント';
	@override String get msg_no_shortcuts => 'ショートカットはありません';
	@override String get msg_location_timed_try => '位置情報の取得がタイムアウトしました。もう一度お試しください。';
	@override String get msg_attach_location_info_memos_show_subtle => '位置情報をメモに添付し、控えめな地名を表示します。';
	@override String msg_send_failed({required Object e}) => '送信に失敗しました: ${e}';
	@override String get msg_repeat => '繰り返し';
	@override String get msg_not_signed => 'サインインしていません';
	@override String get msg_no_webhooks_configured => 'Webhook が設定されていません';
	@override String get msg_apply_token => 'トークンを適用';
	@override String get msg_enable_reminder_permissions_2 => 'リマインダー権限を有効にする';
	@override String get msg_enter_backup_password => 'バックアップパスワードを入力してください';
	@override String get msg_start_backup => 'バックアップを開始';
	@override String get msg_last_sync => '最終同期';
	@override String get msg_note_export_includes_content_already_synced => '注: エクスポートには、すでにローカルデータベースに同期済みの内容（オフラインデータを含む）が含まれます。';
	@override String get msg_enter_username => 'ユーザー名を入力してください';
	@override String get msg_settings_saved => '設定を保存しました';
	@override String get msg_no_keywords => 'キーワードはありません';
	@override String get msg_these_settings_apply_newly_created_memos => 'これらの設定は新しく作成されるメモに適用されます。';
	@override String get msg_back_home => 'ホームに戻る';
	@override String get msg_quiet_hours => 'おやすみ時間';
	@override String get msg_add_account => 'アカウントを追加';
	@override String get msg_reset_complete => 'リセット完了';
	@override String get msg_no_shortcuts_configured => 'ショートカットが設定されていません';
	@override String get msg_password => 'パスワード';
	@override String get msg_importing => 'インポート中';
	@override String msg_visibility_2({required Object visibilityLabel}) => '公開範囲: ${visibilityLabel}';
	@override String get msg_no_logs_yet => 'ログはまだありません';
	@override String get msg_v_9_times_allowed => '最大9回まで可能';
	@override String get msg_last_14_days => '過去14日間';
	@override String get msg_location_disabled_enable_settings_first => '位置情報が無効です。先に設定で有効にしてください。';
	@override String get msg_add_2 => '追加';
	@override String get msg_logs => 'ログ';
	@override String get msg_references => '参照';
	@override String get msg_importing_memos => 'メモをインポート中...';
	@override String get msg_account_security => 'アカウントとセキュリティ';
	@override String get msg_reminder_2 => 'リマインダー';
	@override String get msg_enable_scheduled_reminder_notifications => 'スケジュールされたリマインダー通知を有効にします。';
	@override String get msg_no_links => 'リンクはありません';
	@override String get msg_delete_memo_2 => 'メモを削除';
	@override String get msg_one_tap_add_not_supported_add => 'ワンタップ追加はサポートされていません。ウィジェットピッカーから追加してください';
	@override String get msg_password_2 => '新しいパスワード';
	@override String get msg_processing_content => 'コンテンツを処理中...';
	@override String get msg_status => 'ステータス';
	@override String get msg_local_library_added => 'ローカルライブラリを追加しました';
	@override String get msg_failed_open_try => '開けませんでした。もう一度お試しください。';
	@override String get msg_removed_locally_now_deleted_server_when => '今ローカルで削除され、オンライン時にサーバーからも削除されます。';
	@override String get msg_server_url_unavailable => 'サーバーURLを利用できません';
	@override String get msg_no_release_notes_yet => 'リリースノートはまだありません';
	@override String get msg_cancelling_2 => 'キャンセルしています...';
	@override String get msg_summaries_selected_range => '選択範囲の要約';
	@override String get msg_expand_2 => '展開';
	@override String get msg_close => '閉じる';
	@override String msg_more_comments({required Object remainingComments}) => 'コメントがあと${remainingComments}件';
	@override String get msg_backing => 'バックアップ中…';
	@override String get msg_view_debug_logs => 'デバッグログを表示';
	@override String get msg_location_permission_denied => '位置情報の権限が拒否されました';
	@override String get msg_self_repair_reset_heatmap => '自己修復: ヒートマップをリセット';
	@override String get msg_these_settings_changed_locally_remotely_choose => 'これらの設定はローカルとリモートの両方で変更されました。どちらのバージョンを保持するか選択してください。';
	@override String get msg_not_authenticated_2 => '認証されていません。';
	@override String msg_action_failed({required Object e}) => '操作に失敗しました: ${e}';
	@override String get msg_shortcut_2 => '新しいショートカット';
	@override String get msg_url => 'URL';
	@override String get msg_no_memos_found_html => 'HTML内にメモが見つかりません。';
	@override String get msg_enter_what_want_summarize => '要約したい内容を入力してください...';
	@override String get msg_unable_load_audio_source => '音声ソースを読み込めません。';
	@override String get msg_strategy_id => 'ストラテジーID';
	@override String msg_copy_failed({required Object e}) => 'コピーに失敗しました: ${e}';
	@override String get msg_enable_image_bed => '画像ベッドを有効化';
	@override String get msg_active => '有効';
	@override String get msg_account => 'アカウント';
	@override String get msg_invalid_webdav_server_url => '無効なWebDAVサーバーURL';
	@override String get msg_keep_local => 'ローカルを保持';
	@override String get msg_within_range => '範囲内';
	@override String get msg_generate_log_file => 'ログファイルを生成';
	@override String get msg_ai_reports => 'AIレポート';
	@override String get msg_battery_optimization => 'バッテリー最適化';
	@override String get msg_sync_overview => '同期の概要';
	@override String get msg_legacy_servers_not_support_search_filters => '旧式サーバーは検索フィルターをサポートしていないため、結果が不完全な場合があります。';
	@override String get msg_conflicts_detected_run_manual_sync => '競合が検出されました。手動同期を実行してください。';
	@override String get msg_authentication_failed_check_token => '認証に失敗しました。トークンを確認してください。';
	@override String get msg_date_range_3 => '日付範囲';
	@override String get msg_help_ai_understand_better => 'AIがあなたをよりよく理解できるようにする';
	@override String get msg_no_search_history => '検索履歴がありません';
	@override String get msg_enter_api_path => 'APIパスを入力';
	@override String get msg_stats => '統計';
	@override String get msg_text_2 => '新規: ';
	@override String get msg_removing_signing_clear_local_cache_account => '削除/サインアウトすると、このアカウントのローカルキャッシュ（オフラインデータ/下書き/保留中の同期キュー）が消去されます。';
	@override String get msg_updated_time_2 => '更新時刻 ↑';
	@override String get msg_province => '都道府県';
	@override String get msg_submitting_sync_queue => '同期キューを送信中';
	@override String get msg_failed => '失敗';
	@override String get msg_set_time => '時刻を設定';
	@override String get msg_enable_local_library_backup => 'ローカルライブラリのバックアップを有効化';
	@override String get msg_cancel_2 => 'キャンセル';
	@override String get msg_week => '今週';
	@override String get msg_like => 'いいね';
	@override String get msg_location_services_disabled => '位置情報サービスが無効です';
	@override String get msg_clears_local_cache_offline_memos_pending => 'これによりローカルキャッシュ（オフラインメモ/保留キュー）が消去され、完全な再同期が実行されます。未同期のコンテンツは失われ、時間がかかる場合があります。続行しますか？';
	@override String get msg_load_more => 'さらに読み込む';
	@override String get msg_pull_memo_list_refresh_sync_sync => 'メモ一覧で下に引っ張って更新・同期してください。同期では最新の項目から取得します。統計/ヒートマップを完全に保つため、定期的に完全同期を実行してください。';
	@override String msg_server_returned_error({required Object code}) => 'サーバーがエラーを返しました（${code}）。';
	@override String get msg_sound_feedback => 'サウンドとフィードバック';
	@override String msg_memos_skipped_attachments_skipped({required Object exportedMemoCount, required Object skippedMemoCount, required Object exportedAttachmentCount, required Object skippedAttachmentCount}) => 'メモ${exportedMemoCount}件（スキップ${skippedMemoCount}件）、添付ファイル${exportedAttachmentCount}件（スキップ${skippedAttachmentCount}件）。';
	@override String get msg_import_complete => 'インポート完了';
	@override String get msg_text_3 => '新規';
	@override String get msg_max_per_day => '1日あたりの最大数';
	@override String get msg_permissions_denied => '権限が拒否されました';
	@override String get msg_memo_2 => '新しいメモ';
	@override String get msg_delete_reminder => 'リマインダーを削除';
	@override String get msg_select_month => '月を選択';
	@override String get msg_select_backup => 'バックアップを選択';
	@override String get msg_no_keywords_2 => '#キーワードなし';
	@override String get msg_preparing_memo_content => 'メモ内容を準備中';
	@override String get msg_prompt_content => 'プロンプト内容';
	@override String get msg_default_prompt_ai_summaries_reports => 'AI要約/レポートのデフォルトプロンプト';
	@override String get msg_intro => '紹介';
	@override String get msg_monthly_stats => '月間統計';
	@override String get msg_times_2 => '回';
	@override String get msg_file_has_already_been_imported_skipped => 'このファイルはすでにインポートされています。スキップしました。';
	@override String get msg_token_tail_unknown => 'トークン末尾が不明です';
	@override String get msg_press_back_exit => '終了するにはもう一度戻るを押してください';
	@override String get msg_enter_password_3 => 'パスワードを入力してください';
	@override String get msg_sync_conflicts => '同期の競合';
	@override String get msg_locale => 'ロケール';
	@override String get msg_any => '任意';
	@override String get msg_provider => 'プロバイダー';
	@override String get msg_preview_2 => 'プレビュー';
	@override String get msg_automatically_upload_images_append_links_memo => '画像を自動アップロードし、メモにリンクを追記します。';
	@override String get msg_import_file_not_found => 'インポートファイルが見つかりません。';
	@override String get msg_today => '今日';
	@override String get msg_link_card => 'リンクカード';
	@override String get msg_expiration => '有効期限';
	@override String get msg_summary_prompt_optional => '要約プロンプト（任意）';
	@override String get msg_memos => 'メモ';
	@override String get msg_recording_file_not_found_2 => '録音ファイルが見つかりません。';
	@override String get msg_backup_settings => 'バックアップ設定';
	@override String get msg_mode => 'モード';
	@override String get msg_no_markdown_memos_found_zip => 'ZIP内にMarkdownメモが見つかりません。';
	@override String get msg_archived => 'アーカイブ済み';
	@override String msg_update_failed({required Object e}) => '更新に失敗しました: ${e}';
	@override String get msg_enable_app_lock => 'アプリロックを有効にする';
	@override String get msg_html_zip => 'HTML / ZIP';
	@override String get msg_all => 'すべて';
	@override String get msg_model => 'モデル';
	@override String get msg_title => 'タイトル';
	@override String get msg_amap_web_api => 'Amap Web API';
	@override String get msg_saved_gallery => 'ギャラリーに保存しました';
	@override String get msg_unread => '未読';
	@override String get msg_exporting => 'エクスポート中...';
	@override String get msg_network_timeout_try => 'ネットワークがタイムアウトしました。もう一度お試しください。';
	@override String get msg_unlock => 'ロック解除';
	@override String msg_ago_3({required Object diff_inDays}) => '${diff_inDays}前';
	@override String get msg_deserve_coffee_i_m_pulling_all => 'このコーヒーに見合うように、100行のコードを書くために徹夜しています！';
	@override String get msg_token_name => 'トークン名';
	@override String get msg_restore_completed => '復元が完了しました';
	@override String get msg_copied_clipboard => 'クリップボードにコピーしました';
	@override String msg_failed_2({required Object attempts}) => '失敗 ${attempts}';
	@override String get msg_too_many_requests_try_later => 'リクエストが多すぎます。後でもう一度お試しください。';
	@override String get msg_more => 'もっと見る';
	@override String get msg_already_whitelisted => 'すでにホワイトリストに登録されています';
	@override String get msg_local_library_backup => 'ローカルライブラリのバックアップ';
	@override String get msg_awesome => '最高！ ❤️';
	@override String get msg_now => '今';
	@override String get msg_select_reminder_time => 'リマインダー時刻を選択';
	@override String get msg_protected => '保護済み';
	@override String msg_failed_load_4({required Object e}) => '読み込みに失敗しました: ${e}';
	@override String msg_operation_failed({required Object e}) => '操作に失敗しました: ${e}';
	@override String get msg_no_tags => 'タグなし';
	@override String get msg_server => 'サーバー';
	@override String get msg_improved => '改善済み';
	@override String get msg_request_2 => 'リクエスト';
	@override String msg_export_failed({required Object e}) => 'エクスポートに失敗しました: ${e}';
	@override String get msg_notification_settings => '通知設定';
	@override String get msg_related_memo_was_deleted => '関連するメモは削除されました';
	@override String get msg_email => 'メール';
	@override String get msg_enter_password_4 => 'パスワードを入力してください';
	@override String get msg_retry_count => '再試行回数';
	@override String get msg_import_exported_html_zip_package => 'エクスポートしたHTMLまたはZIPパッケージをインポート';
	@override String get msg_archive => 'アーカイブ';
	@override String get msg_reset_heatmap => 'ヒートマップをリセットしますか？';
	@override String get msg_token_applied => 'トークンを適用しました';
	@override String get msg_log_file_created => 'ログファイルを作成しました';
	@override String get msg_delete_sync_task => '同期タスクを削除';
	@override String get msg_include_archived_2 => '- アーカイブを含める';
	@override String get msg_memoflow_side_project_i_build_my => 'MemoFlowは、空き時間に開発しているサイドプロジェクトです。バグ修正で夜更かしが続いていて、アイスアメリカーノが本当に欲しいです。あなたのサポートがエネルギー補給になり、新機能のリリースを後押ししてくれます ';
	@override String msg_failed_generate({required Object e}) => '生成に失敗しました: ${e}';
	@override String get msg_search_logs => 'ログを検索';
	@override String get msg_active_days => 'アクティブ日数';
	@override String get msg_back_top => 'トップに戻る';
	@override String get msg_month => '今月';
	@override String get msg_loading_references => '参照を読み込み中';
	@override String get msg_silent => 'サイレント';
	@override String get msg_settings => '設定';
	@override String get msg_locating => '位置情報を取得中...';
	@override String get msg_scan => 'スキャン';
	@override String get msg_recording_path_missing => '録音パスが見つかりません。';
	@override String get msg_date_range_4 => '- 日付範囲';
	@override String get msg_suggested_tags => 'おすすめタグ';
	@override String get msg_energy_restored => '⚡ エネルギー回復';
	@override String get msg_username_2 => 'ユーザー名';
	@override String get msg_ai_summary_report => 'AI要約レポート';
	@override String get msg_all_tags => 'すべてのタグ';
	@override String get msg_preferences => '環境設定';
	@override String get msg_image_bed_3 => '画像ベッド';
	@override String get msg_quick_input => 'クイック入力';
	@override String get msg_tags => 'タグ';
	@override String get msg_energy_critically_low => 'エネルギーが危険水準です！';
	@override String msg_delete_failed({required Object e}) => '削除に失敗しました: ${e}';
	@override String get msg_server_login => 'サーバーログイン';
	@override String get msg_like_2 => 'いいね';
	@override String get msg_save_2 => '保存';
	@override String get msg_unknown => '不明';
	@override String get msg_release_notes_2 => 'リリースノート';
	@override String get msg_include_error_details => 'エラー詳細を含める';
	@override String get msg_write_comment => 'コメントを書く...';
	@override String get msg_write_thoughts => '考えを書き留めてください...';
	@override String get msg_local_2 => 'ローカル';
	@override String get msg_expired => '期限切れ';
	@override String get msg_fixed_2 => '修正済み';
	@override String get msg_upload_attachment => '添付ファイルをアップロード';
	@override String get msg_battery_whitelist => 'バッテリーのホワイトリスト';
	@override String get msg_district => '地区';
	@override String get msg_voice_memo => '🎙️ ボイスメモ\\n';
	@override String get msg_system_default => 'システムのデフォルト';
	@override String get msg_all_memos_2 => 'すべてのメモ';
	@override String get msg_network_request_failed => 'ネットワークリクエストに失敗しました';
	@override String get msg_memo_not_found => 'メモが見つかりません';
	@override String msg_playback_failed_2({required Object e}) => '再生に失敗しました: ${e}';
	@override String get msg_sync_settings_webdav_across_devices => 'デバイス間で同期するために、WebDAVへ設定を保存します。';
	@override String get msg_offline_first_client_memos_backend => 'Memosバックエンド向けのオフラインファーストクライアント。';
	@override String get msg_user_guide => 'ユーザーガイド';
	@override String get msg_notice => 'お知らせ';
	@override String get msg_exact_alarms => '正確なアラーム';
	@override String get msg_restoring_overwrite_local_library_files_rebuild => '復元するとローカルライブラリのファイルが上書きされ、データベースが再構築されます。これは元に戻せません。';
	@override String get msg_enter_api_url_ai_settings => 'AI設定でAPI URLを入力してください';
	@override String msg_create_failed_2({required Object e}) => '作成に失敗しました: ${e}';
	@override String get msg_close_search => '検索を閉じる';
	@override String get msg_imported_memos_2 => 'メモをインポートしました';
	@override String get msg_explore => '探索';
	@override String get msg_network_connection_failed => 'ネットワーク接続に失敗しました。';
	@override String msg_save_failed_3({required Object e}) => '保存に失敗しました: ${e}';
	@override String get msg_no_summary_share => '共有できる要約がありません';
	@override String get msg_custom_model => 'カスタムモデル';
	@override String msg_sign_failed({required Object message}) => 'サインインに失敗しました: ${message}';
	@override String get msg_notification_exact_alarm_permissions_required_send => '通知と正確なアラームの権限は、リマインダーを時間どおりに送信するために必要です。';
	@override String get msg_random_review => 'ランダムレビュー';
	@override String get msg_public => '公開';
	@override String get msg_all_2 => 'すべて';
	@override String get msg_add_custom_model => 'カスタムモデルを追加';
	@override String get msg_backup_password => 'バックアップパスワード';
	@override String get msg_optional_used_sign_requests => '任意。リクエストの署名に使用されます。';
	@override String get msg_search => '検索';
	@override String get msg_set_password => 'パスワードを設定';
	@override String get msg_submit_logs => 'ログを送信';
	@override String get msg_activity_heatmap_2 => 'アクティビティヒートマップ';
	@override String get msg_invalid_api_key_insufficient_permissions => 'APIキーが無効か、権限が不足しています。';
	@override String get msg_data_has_been_migrated_app_successfully => 'データはこのアプリに正常に移行されました。';
	@override String get msg_get_version => '新しいバージョンを入手';
	@override String get msg_token_source => 'トークンソース';
	@override String get msg_send => '送信';
	@override String get msg_no_pending_sync_tasks => '保留中の同期タスクはありません';
	@override String get msg_locating_memo_content => 'メモ内容を特定中';
	@override String get msg_offline_ready => 'オフライン対応';
	@override String get msg_use_relative_path => '相対パスを使用';
	@override String get msg_total => '合計';
	@override String get msg_location_2 => '位置情報';
	@override String get msg_show_location_metadata_memos_not_configured => 'メモに位置情報メタデータを表示します。設定されていない場合は、代わりに座標が表示されます。';
	@override String get msg_api_url => 'API URL';
	@override String get msg_parsing_progress => '解析の進捗';
	@override String get msg_parsing => '解析中';
	@override String get msg_custom => 'カスタム';
	@override String get msg_tags_created => '新しいタグが作成されました';
	@override String get msg_third_party_share_disabled => 'サードパーティ共有は無効です';
	@override String get msg_loading_links => 'リンクを読み込み中...';
	@override String get msg_how_report => '報告方法は？';
	@override String get msg_confirm_password_2 => 'パスワードを確認';
	@override String get msg_search_title_content_tags => 'タイトル、内容、またはタグで検索';
	@override String msg_reset_failed({required Object e}) => 'リセットに失敗しました: ${e}';
	@override String get msg_debug_preview_update_dialog => 'デバッグ: 更新ダイアログをプレビュー';
	@override String get msg_what_s => '新機能';
	@override String get msg_ringtone => '着信音';
	@override String get msg_unable_detect_backend_version_check_server => 'バックエンドのバージョンを検出できません。サーバーURLまたはネットワークを確認してください。';
	@override String get msg_pending_2 => '保留中';
	@override String get msg_parsing_html => 'HTMLを解析中...';
	@override String get msg_actions => '操作';
	@override String get msg_import_complete_2 => 'インポート完了';
	@override String get msg_use_disk => 'ディスクを使用';
	@override String get msg_root_path => 'ルートパス';
	@override String get msg_disabled => '無効';
	@override String get msg_improved_2 => '改善: ';
	@override String get msg_city => '市';
	@override String get msg_decoding_zip => 'ZIPをデコード中...';
	@override String get msg_notification_content => '通知内容';
	@override String get msg_resolve_conflict => '競合を解決';
	@override String get msg_webhooks_not_supported_server => 'このサーバーではWebhookはサポートされていません。';
	@override String get msg_may_delayed => ' （遅延する可能性があります）';
	@override String get msg_permissions_system_settings => '権限とシステム設定';
	@override String get msg_waiting_tasks_stop => 'タスクの停止を待機中';
	@override String get msg_done_2 => '完了';
	@override String get msg_parsing_memoflow_export => 'MemoFlowエクスポートを解析中...';
	@override String msg_location_updated({required Object next_displayText_fractionDigits_6}) => '位置情報が更新されました: ${next_displayText_fractionDigits_6}';
	@override String get msg_checking_server_version => 'サーバーバージョンを確認中...';
	@override String get msg_next_time_back_fixing_bugs => '👀 次回は、バグ修正に戻る';
	@override String msg_ago_4({required Object weeks}) => '${weeks}前';
	@override String get msg_import => 'インポート';
	@override String get msg_ios_long_press_home_screen_add => 'iOSでは、ホーム画面を長押ししてMemoFlowウィジェットを追加します';
	@override String get msg_create_token_2 => 'トークンを作成';
	@override String get msg_marked_read => '既読にしました';
	@override String get msg_pinned => 'ピン留め済み';
	@override String get msg_version_update => 'バージョン更新';
	@override String get msg_allow_private_memos => 'プライベートメモを許可';
	@override String get msg_token_copied_clipboard => 'トークンをクリップボードにコピーしました';
	@override String get msg_keeping_more_versions_uses_more_storage => 'より多くのバージョンを保持すると、より多くのストレージを使用します。古いバージョンの整理を検討してください。';
	@override String get msg_delete_webhook => 'Webhookを削除';
	@override String get msg_prompt => 'プロンプト';
	@override String get msg_location_precision => '位置情報の精度';
	@override String get msg_password_required => 'パスワードが必要です';
	@override String get msg_exit_app => 'アプリを終了';
	@override String get msg_thanks_energy_fully_restored => 'ありがとうございます！エネルギーが完全に回復しました⚡';
	@override String get msg_connection_timeout_check_network_api_url => '接続がタイムアウトしました。ネットワークまたはAPI URLを確認してください。';
	@override late final _StringsStringsLegacyAppLanguageJa app_language = _StringsStringsLegacyAppLanguageJa._(_root);
	@override late final _StringsStringsLegacyAppThemeJa app_theme = _StringsStringsLegacyAppThemeJa._(_root);
	@override late final _StringsStringsLegacyAppFontSizeJa app_font_size = _StringsStringsLegacyAppFontSizeJa._(_root);
	@override late final _StringsStringsLegacyAppLineHeightJa app_line_height = _StringsStringsLegacyAppLineHeightJa._(_root);
	@override late final _StringsStringsLegacyLaunchActionJa launch_action = _StringsStringsLegacyLaunchActionJa._(_root);
	@override late final _StringsStringsLegacyAutoLockTimeJa auto_lock_time = _StringsStringsLegacyAutoLockTimeJa._(_root);
	@override late final _StringsStringsLegacyReminderJa reminder = _StringsStringsLegacyReminderJa._(_root);
	@override late final _StringsStringsLegacyLocationJa location = _StringsStringsLegacyLocationJa._(_root);
	@override late final _StringsStringsLegacyWebdavJa webdav = _StringsStringsLegacyWebdavJa._(_root);
	@override String import_count_memos({required Object count}) => '${count}';
	@override String import_count_attachments({required Object count}) => '${count}';
	@override late final _StringsStringsLegacyAppDrawerJa app_drawer = _StringsStringsLegacyAppDrawerJa._(_root);
	@override late final _StringsStringsLegacyAiSummaryJa ai_summary = _StringsStringsLegacyAiSummaryJa._(_root);
}

// Path: strings.login.mode
class _StringsStringsLoginModeJa extends _StringsStringsLoginModeEn {
	_StringsStringsLoginModeJa._(_StringsJa root) : this._root = root, super._(root);

	@override final _StringsJa _root; // ignore: unused_field

	// Translations
	@override String get password => 'ユーザー名とパスワード';
	@override String get token => 'トークン';
	@override String get descPassword => 'ユーザー名とパスワードでサインイン';
	@override String get descToken => 'パーソナルアクセストークンでサインイン';
	@override String get signInMethod => 'サインイン方法';
}

// Path: strings.login.field
class _StringsStringsLoginFieldJa extends _StringsStringsLoginFieldEn {
	_StringsStringsLoginFieldJa._(_StringsJa root) : this._root = root, super._(root);

	@override final _StringsJa _root; // ignore: unused_field

	// Translations
	@override String get serverUrlLabel => 'サーバーURL';
	@override String get serverUrlHint => 'http://localhost:5230';
	@override String get usernameLabel => 'ユーザー名';
	@override String get usernameHint => 'ユーザー名を入力';
	@override String get passwordLabel => 'パスワード';
	@override String get passwordHint => 'パスワードを入力';
	@override String get tokenLabel => 'トークン (PAT)';
	@override String get tokenHint => 'トークン (PAT)';
}

// Path: strings.login.validation
class _StringsStringsLoginValidationJa extends _StringsStringsLoginValidationEn {
	_StringsStringsLoginValidationJa._(_StringsJa root) : this._root = root, super._(root);

	@override final _StringsJa _root; // ignore: unused_field

	// Translations
	@override String get serverUrlRequired => 'サーバーURLを入力してください';
	@override String get serverUrlInvalid => 'http/https とポートを含む完全なURLを入力してください';
	@override String get usernameRequired => 'ユーザー名を入力してください';
	@override String get passwordRequired => 'パスワードを入力してください';
	@override String get tokenRequired => 'トークンを入力してください';
}

// Path: strings.login.compatibility
class _StringsStringsLoginCompatibilityJa extends _StringsStringsLoginCompatibilityEn {
	_StringsStringsLoginCompatibilityJa._(_StringsJa root) : this._root = root, super._(root);

	@override final _StringsJa _root; // ignore: unused_field

	// Translations
	@override String get title => '互換モード';
	@override String get description => '旧版 Memos 用のレガシーエンドポイントを使用します';
}

// Path: strings.login.connect
class _StringsStringsLoginConnectJa extends _StringsStringsLoginConnectEn {
	_StringsStringsLoginConnectJa._(_StringsJa root) : this._root = root, super._(root);

	@override final _StringsJa _root; // ignore: unused_field

	// Translations
	@override String get connecting => '接続中…';
	@override String get action => '接続';
}

// Path: strings.login.errors
class _StringsStringsLoginErrorsJa extends _StringsStringsLoginErrorsEn {
	_StringsStringsLoginErrorsJa._(_StringsJa root) : this._root = root, super._(root);

	@override final _StringsJa _root; // ignore: unused_field

	// Translations
	@override String get authFailedToken => '認証に失敗しました。トークンが有効で期限切れでないか確認してください。';
	@override String get authFailedPat => '認証に失敗しました。新しい Memos では memos_pat_ で始まる PAT を使用してください（Bearer プレフィックスは貼り付けないでください）。';
	@override String connectionFailedWithMessage({required Object message}) => '接続に失敗しました: ${message}';
	@override String connectionFailed({required Object error}) => '接続に失敗しました: ${error}';
	@override String get signInFailed => 'サインインに失敗しました。ユーザー名とパスワードを確認してください。';
	@override String signInFailedWithMessage({required Object message}) => 'サインインに失敗しました: ${message}';
	@override String get invalidServerUrl => 'サーバーURLが無効です';
	@override String get serverUrlNormalized => 'サーバーURLを正規化しました（余分なパスを削除）';
}

// Path: strings.settings.preferences
class _StringsStringsSettingsPreferencesJa extends _StringsStringsSettingsPreferencesEn {
	_StringsStringsSettingsPreferencesJa._(_StringsJa root) : this._root = root, super._(root);

	@override final _StringsJa _root; // ignore: unused_field

	// Translations
	@override String get title => '設定';
	@override String get language => '言語';
	@override String get fontSize => '文字サイズ';
	@override String get lineHeight => '行間';
	@override String get font => 'フォント';
	@override String get systemDefault => 'システム標準';
	@override String get noSystemFonts => 'システムフォントが見つかりません';
	@override String loadFontsFailed({required Object error}) => 'フォントの読み込みに失敗しました: ${error}';
	@override String get collapseLongContent => '長文を折りたたむ';
	@override String get collapseReferences => '参照を折りたたむ';
	@override String get showEngagementInAllMemoDetails => 'すべてのメモ詳細でいいねとコメントを表示';
	@override String get launchAction => '起動時の動作';
	@override String get quickInputKeyboard => 'クイック入力で自動的にキーボードを開く';
	@override String get appearance => '外観';
	@override String get themeColor => 'テーマカラー';
	@override String get haptics => '触覚フィードバック';
	@override String get customTheme => 'カスタムテーマ';
	@override String get history => '履歴';
	@override String get lightMode => 'ライトモード';
	@override String get darkMode => 'ダークモード';
	@override String get surfaces => 'サーフェス';
	@override String get background => '背景';
	@override String get backgroundColor => '背景色';
	@override String get card => 'カード';
	@override String get cardColor => 'カード色';
	@override String get border => '枠線';
	@override String get borderColor => '枠線色';
}

// Path: strings.legacy.app_language
class _StringsStringsLegacyAppLanguageJa extends _StringsStringsLegacyAppLanguageEn {
	_StringsStringsLegacyAppLanguageJa._(_StringsJa root) : this._root = root, super._(root);

	@override final _StringsJa _root; // ignore: unused_field

	// Translations
	@override String get system => 'システムに従う';
	@override String get zh_hans => '中国語（簡体）';
	@override String get zh_hant_tw => '中国語（繁体・中国台湾）';
	@override String get en => '英語';
	@override String get ja => '日本語';
	@override String get de => 'ドイツ語';
}

// Path: strings.legacy.app_theme
class _StringsStringsLegacyAppThemeJa extends _StringsStringsLegacyAppThemeEn {
	_StringsStringsLegacyAppThemeJa._(_StringsJa root) : this._root = root, super._(root);

	@override final _StringsJa _root; // ignore: unused_field

	// Translations
	@override String get system => 'システム';
	@override String get light => 'ライト';
	@override String get dark => 'ダーク';
}

// Path: strings.legacy.app_font_size
class _StringsStringsLegacyAppFontSizeJa extends _StringsStringsLegacyAppFontSizeEn {
	_StringsStringsLegacyAppFontSizeJa._(_StringsJa root) : this._root = root, super._(root);

	@override final _StringsJa _root; // ignore: unused_field

	// Translations
	@override String get standard => '標準';
	@override String get large => '大';
	@override String get small => '小';
}

// Path: strings.legacy.app_line_height
class _StringsStringsLegacyAppLineHeightJa extends _StringsStringsLegacyAppLineHeightEn {
	_StringsStringsLegacyAppLineHeightJa._(_StringsJa root) : this._root = root, super._(root);

	@override final _StringsJa _root; // ignore: unused_field

	// Translations
	@override String get classic => 'クラシック';
	@override String get compact => 'コンパクト';
	@override String get relaxed => 'ゆったり';
}

// Path: strings.legacy.launch_action
class _StringsStringsLegacyLaunchActionJa extends _StringsStringsLegacyLaunchActionEn {
	_StringsStringsLegacyLaunchActionJa._(_StringsJa root) : this._root = root, super._(root);

	@override final _StringsJa _root; // ignore: unused_field

	// Translations
	@override String get none => 'なし';
	@override String get sync => '同期';
	@override String get quick_input => 'クイック入力';
	@override String get daily_review => 'ランダムレビュー';
}

// Path: strings.legacy.auto_lock_time
class _StringsStringsLegacyAutoLockTimeJa extends _StringsStringsLegacyAutoLockTimeEn {
	_StringsStringsLegacyAutoLockTimeJa._(_StringsJa root) : this._root = root, super._(root);

	@override final _StringsJa _root; // ignore: unused_field

	// Translations
	@override String get immediately => 'すぐに';
	@override String get after_1_min => '1分';
	@override String get after_5_min => '5分';
	@override String get after_15_min => '15分';
}

// Path: strings.legacy.reminder
class _StringsStringsLegacyReminderJa extends _StringsStringsLegacyReminderEn {
	_StringsStringsLegacyReminderJa._(_StringsJa root) : this._root = root, super._(root);

	@override final _StringsJa _root; // ignore: unused_field

	// Translations
	@override String get default_title => 'ねえ、このアイデア覚えてる？';
	@override String get default_body => 'タップして詳細を見る';
}

// Path: strings.legacy.location
class _StringsStringsLegacyLocationJa extends _StringsStringsLegacyLocationEn {
	_StringsStringsLegacyLocationJa._(_StringsJa root) : this._root = root, super._(root);

	@override final _StringsJa _root; // ignore: unused_field

	// Translations
	@override String get current => '現在地';
}

// Path: strings.legacy.webdav
class _StringsStringsLegacyWebdavJa extends _StringsStringsLegacyWebdavEn {
	_StringsStringsLegacyWebdavJa._(_StringsJa root) : this._root = root, super._(root);

	@override final _StringsJa _root; // ignore: unused_field

	// Translations
	@override String get not_configured => 'WebDAV が設定されていません';
	@override String get backup_disabled => 'バックアップは無効です';
	@override String get backup_account_missing => 'バックアップ用のアカウントがありません';
	@override String get backup_local_only => 'バックアップはローカルライブラリのみ利用できます';
	@override String get backup_password_missing => 'バックアップパスワードがありません';
	@override String get backup_no_memo_files => 'ローカルライブラリにメモファイルが見つからないため、バックアップをキャンセルしました';
	@override String get restore_account_missing => '復元用のアカウントがありません';
	@override String get restore_local_only => '復元はローカルライブラリのみ利用できます';
	@override String get backup_empty => 'バックアップが空です';
	@override String get backup_no_memos => 'バックアップにメモがありません';
	@override String get snapshot_missing => 'バックアップスナップショットがありません';
	@override String get snapshot_corrupted => 'バックアップスナップショットが破損しています';
	@override String get object_missing => 'バックアップオブジェクトがありません';
	@override String get config_corrupted => 'バックアップ設定が破損しています';
	@override String get config_invalid => '無効なバックアップ設定';
	@override String get password_invalid => 'バックアップパスワードが正しくありません';
	@override String get data_corrupted => 'バックアップデータが破損しています';
	@override String get server_url_invalid => 'WebDAV サーバーURLが無効です';
}

// Path: strings.legacy.app_drawer
class _StringsStringsLegacyAppDrawerJa extends _StringsStringsLegacyAppDrawerEn {
	_StringsStringsLegacyAppDrawerJa._(_StringsJa root) : this._root = root, super._(root);

	@override final _StringsJa _root; // ignore: unused_field

	// Translations
	@override String tooltip_single({required Object date, required Object weekday, required Object count}) => '${date}（${weekday}）・${count} 件';
	@override String tooltip_multi({required Object date, required Object weekday, required Object count}) => '${date}（${weekday}）・${count} 件';
}

// Path: strings.legacy.ai_summary
class _StringsStringsLegacyAiSummaryJa extends _StringsStringsLegacyAiSummaryEn {
	_StringsStringsLegacyAiSummaryJa._(_StringsJa root) : this._root = root, super._(root);

	@override final _StringsJa _root; // ignore: unused_field

	// Translations
	@override String get error_api_key_empty => 'APIキーが空です';
	@override late final _StringsStringsLegacyAiSummarySystemJa system = _StringsStringsLegacyAiSummarySystemJa._(_root);
	@override late final _StringsStringsLegacyAiSummaryUserJa user = _StringsStringsLegacyAiSummaryUserJa._(_root);
	@override String get error_invalid_response => 'AIの応答形式が正しくありません';
	@override String get error_empty_response => 'AIの応答が空です';
	@override String get error_missing_content => 'AIの応答内容が欠落しています';
	@override String get default_prompt => 'あなたはミニマリストなノートアシスタントです。核心的なポイントを抽出し、上品な形式で整理してください。返信はプロフェッショナルで穏やか、簡潔な語調を保ち、できるだけ箇条書きと短い段落を使ってください。';
}

// Path: strings.legacy.ai_summary.system
class _StringsStringsLegacyAiSummarySystemJa extends _StringsStringsLegacyAiSummarySystemEn {
	_StringsStringsLegacyAiSummarySystemJa._(_StringsJa root) : this._root = root, super._(root);

	@override final _StringsJa _root; // ignore: unused_field

	// Translations
	@override String get require_json => 'JSONのみを厳密に出力してください。コードブロックや余計な説明は不要です。';
	@override String get json_format => 'JSON形式：{"insights":["..."],"moodTrend":"...","keywords":["#..."]}';
	@override String get insights_rule => 'insightsは2〜5件、keywordsは#付きの4〜8個にしてください。';
}

// Path: strings.legacy.ai_summary.user
class _StringsStringsLegacyAiSummaryUserJa extends _StringsStringsLegacyAiSummaryUserEn {
	_StringsStringsLegacyAiSummaryUserJa._(_StringsJa root) : this._root = root, super._(root);

	@override final _StringsJa _root; // ignore: unused_field

	// Translations
	@override String range({required Object rangeLabel}) => '期間：${rangeLabel}';
	@override String counts({required Object memoCount, required Object includedCount}) => 'メモ件数：${memoCount}（要約対象：${includedCount}）';
	@override String profile({required Object profile}) => 'ユーザープロフィール：${profile}';
	@override String custom_prompt({required Object customPrompt}) => '追加指示：${customPrompt}';
	@override String get memo_content => 'メモ内容：';
}

// Path: <root>
class _StringsZhHans extends Translations {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	_StringsZhHans.build({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = TranslationMetadata(
		    locale: AppLocale.zhHans,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super.build(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		super.$meta.setFlatMapFunction($meta.getTranslation); // copy base translations to super.$meta
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <zh-Hans>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key) ?? super.$meta.getTranslation(key);

	@override late final _StringsZhHans _root = this; // ignore: unused_field

	// Translations
	@override late final _StringsStringsZhHans strings = _StringsStringsZhHans._(_root);
}

// Path: strings
class _StringsStringsZhHans extends _StringsStringsEn {
	_StringsStringsZhHans._(_StringsZhHans root) : this._root = root, super._(root);

	@override final _StringsZhHans _root; // ignore: unused_field

	// Translations
	@override late final _StringsStringsCommonZhHans common = _StringsStringsCommonZhHans._(_root);
	@override late final _StringsStringsLanguagesZhHans languages = _StringsStringsLanguagesZhHans._(_root);
	@override late final _StringsStringsLanguagesNativeZhHans languagesNative = _StringsStringsLanguagesNativeZhHans._(_root);
	@override late final _StringsStringsOnboardingZhHans onboarding = _StringsStringsOnboardingZhHans._(_root);
	@override late final _StringsStringsLoginZhHans login = _StringsStringsLoginZhHans._(_root);
	@override late final _StringsStringsSettingsZhHans settings = _StringsStringsSettingsZhHans._(_root);
	@override late final _StringsStringsLegacyZhHans legacy = _StringsStringsLegacyZhHans._(_root);
}

// Path: strings.common
class _StringsStringsCommonZhHans extends _StringsStringsCommonEn {
	_StringsStringsCommonZhHans._(_StringsZhHans root) : this._root = root, super._(root);

	@override final _StringsZhHans _root; // ignore: unused_field

	// Translations
	@override String get back => '返回';
	@override String get cancel => '取消';
	@override String get confirm => '确认';
	@override String get save => '保存';
	@override String get saveSettings => '保存设置';
	@override String get auto => '自动';
	@override String get manual => '手动';
	@override String get copiedToClipboard => '已复制到剪贴板';
	@override String get serverVersion => '服务端版本';
	@override String get selectValidServerVersion => '请选择有效服务端版本';
	@override String serverVersionValue({required Object version}) => '服务端版本: ${version}';
	@override String get selectServerVersionRange021To026 => '请先手动选择 0.21~0.26 服务端版本';
}

// Path: strings.languages
class _StringsStringsLanguagesZhHans extends _StringsStringsLanguagesEn {
	_StringsStringsLanguagesZhHans._(_StringsZhHans root) : this._root = root, super._(root);

	@override final _StringsZhHans _root; // ignore: unused_field

	// Translations
	@override String get system => '跟随系统';
	@override String get zhHans => '简体中文';
	@override String get zhHantTw => '繁体中文（中国台湾）';
	@override String get en => '英语';
	@override String get ja => '日语';
	@override String get de => '德语';
}

// Path: strings.languagesNative
class _StringsStringsLanguagesNativeZhHans extends _StringsStringsLanguagesNativeEn {
	_StringsStringsLanguagesNativeZhHans._(_StringsZhHans root) : this._root = root, super._(root);

	@override final _StringsZhHans _root; // ignore: unused_field

	// Translations
	@override String get system => '系统';
	@override String get zhHans => '简体中文';
	@override String get zhHantTw => '繁體中文（中國台灣）';
	@override String get en => '英语';
	@override String get ja => '日本語';
	@override String get de => 'Deutsch';
}

// Path: strings.onboarding
class _StringsStringsOnboardingZhHans extends _StringsStringsOnboardingEn {
	_StringsStringsOnboardingZhHans._(_StringsZhHans root) : this._root = root, super._(root);

	@override final _StringsZhHans _root; // ignore: unused_field

	// Translations
	@override String get tagline => '简约而强大的笔记流';
	@override String get selectLanguage => '选择语言';
	@override String get selectMode => '选择工作模式';
	@override String get modeHint => '您可以随时在设置中更改此项';
	@override String get modeLocalTitle => '单机模式';
	@override String get modeLocalLabel => 'LOCAL MODE';
	@override String get modeLocalDesc => '数据仅保存在手机本地，无需配置服务器，适合追求极致隐私与离线使用的用户。';
	@override String get modeServerTitle => '联机模式';
	@override String get modeServerLabel => 'SERVER MODE';
	@override String get modeServerDesc => '连接到你的 Memos 后端，实现多端实时同步。支持 Web、移动端等多平台无缝衔接。';
	@override String get localLibraryNameTitle => '本地库名称';
	@override String get localLibraryNameHint => '请输入名称';
	@override String get localLibraryDefaultName => '本地库';
	@override String get getStarted => '开始使用';
}

// Path: strings.login
class _StringsStringsLoginZhHans extends _StringsStringsLoginEn {
	_StringsStringsLoginZhHans._(_StringsZhHans root) : this._root = root, super._(root);

	@override final _StringsZhHans _root; // ignore: unused_field

	// Translations
	@override String get title => '连接 Memos';
	@override late final _StringsStringsLoginModeZhHans mode = _StringsStringsLoginModeZhHans._(_root);
	@override late final _StringsStringsLoginFieldZhHans field = _StringsStringsLoginFieldZhHans._(_root);
	@override late final _StringsStringsLoginValidationZhHans validation = _StringsStringsLoginValidationZhHans._(_root);
	@override late final _StringsStringsLoginCompatibilityZhHans compatibility = _StringsStringsLoginCompatibilityZhHans._(_root);
	@override late final _StringsStringsLoginConnectZhHans connect = _StringsStringsLoginConnectZhHans._(_root);
	@override late final _StringsStringsLoginErrorsZhHans errors = _StringsStringsLoginErrorsZhHans._(_root);
}

// Path: strings.settings
class _StringsStringsSettingsZhHans extends _StringsStringsSettingsEn {
	_StringsStringsSettingsZhHans._(_StringsZhHans root) : this._root = root, super._(root);

	@override final _StringsZhHans _root; // ignore: unused_field

	// Translations
	@override late final _StringsStringsSettingsPreferencesZhHans preferences = _StringsStringsSettingsPreferencesZhHans._(_root);
}

// Path: strings.legacy
class _StringsStringsLegacyZhHans extends _StringsStringsLegacyEn {
	_StringsStringsLegacyZhHans._(_StringsZhHans root) : this._root = root, super._(root);

	@override final _StringsZhHans _root; // ignore: unused_field

	// Translations
	@override String get msg_memos_backend_docs => 'memos后端使用文档';
	@override String get msg_remember_moment_feel_warmth_life_take => '记住这一刻，感受生活的温度。\\n每天来一次随机漫步。';
	@override String get msg_sure_want_delete_shortcut => '确定要删除该快捷筛选吗？';
	@override String get msg_scan_completed => '扫描完成';
	@override String get msg_confirm => '确认';
	@override String get msg_unable_open_browser_install_browser_app => '无法打开浏览器，请检查是否安装了浏览器';
	@override String get msg_contributors => '贡献与致谢';
	@override String get msg_enter_keywords_search_box_query_local => '在搜索框输入关键词可检索本地内容与标签。离线可用；首次使用请等待本地索引完成。';
	@override String get msg_memo_not_found_locally => '本地暂无该笔记';
	@override String get msg_token => 'Token 摘要';
	@override String get msg_last_7_days => '最近一周';
	@override String get msg_search_memo_content => '搜索笔记内容';
	@override String get msg_retry_started => '已开始重试同步';
	@override String msg_last_year_memos({required Object lastYearMemos}) => '最近一年记录 ${lastYearMemos} 条笔记';
	@override String get msg_no_content_yet => '暂无内容';
	@override String get msg_no_summary_yet => '暂无总结结果';
	@override String get msg_sooner => ' 上线！';
	@override String get msg_token_copied => 'Token 已复制';
	@override String get msg_share => '分享';
	@override String get msg_gallery_permission_required => '需要相册权限以保存二维码';
	@override String get msg_basic_settings => '基础设置';
	@override String get msg_bad_ssl_certificate => '证书校验失败';
	@override String get msg_no_notifications => '暂无通知';
	@override String get msg_import_markdown => '从 Markdown 导入';
	@override String get msg_upload_zip_package_md_files => '请上传包含 .md 文件的 .zip 压缩包';
	@override String get msg_request_send_timeout_try => '请求发送超时，请稍后重试';
	@override String get msg_select_date_range => '选择时间范围';
	@override String get msg_delete_shortcut => '删除快捷筛选';
	@override String get msg_auto_lock_time => '自动锁定时间';
	@override String get msg_replacing_delete_original_attachment_continue => '替换后将删除原图片附件，是否继续？';
	@override String get msg_add_least_one_condition => '请至少设置一个条件';
	@override String get msg_upload_images_image_bed_append_links => '开启后自动将图片上传到图床，并在文末插入图片链接。';
	@override String get msg_request_cancelled => '请求已取消';
	@override String get msg_generating => '生成中…';
	@override String get msg_permissions_denied_reminders_disabled => '权限未授予，提醒未开启';
	@override String get msg_memoflow_local_reminders => 'MemoFlow 本地提醒';
	@override String get msg_use_legacy_endpoints_older_memos_servers => '使用旧版接口（适配旧版 Memos）';
	@override String get msg_no_comments_yet => '暂无评论';
	@override String get msg_open => '打开';
	@override String get msg_microphone_permission_required => '需要麦克风权限';
	@override String msg_failed_react({required Object e}) => '点赞失败：${e}';
	@override String get msg_restore_backup => '恢复备份？';
	@override String get msg_qr_saved_gallery => '二维码已保存到系统相册';
	@override String get msg_no_attachments => '暂无附件';
	@override String get msg_enable_reminder_permissions => '启用提醒权限';
	@override String get msg_created_time => '创建时间 ↑';
	@override String get msg_prompt_saved_quick_prompts => '提示词将保存在快速总结中';
	@override String get msg_remember_password => '记住密码';
	@override String get msg_enter_valid_url => '请输入有效的 URL';
	@override String get msg_may_take_few_seconds => '可能需要几秒钟';
	@override String msg_local_sync_failed({required Object type, required Object memoError}) => '本地同步失败（${type}）：${memoError}';
	@override String get msg_webdav_sync => 'WebDAV 同步';
	@override String get msg_clear => '清空';
	@override String get msg_clear_recycle_bin_confirm => '确认清空回收站？回收站内所有内容将被永久删除。';
	@override String get msg_save_failed => '保存失败';
	@override String get msg_endpoint_not_found_version_mismatch => '接口不存在（可能是 Memos 版本不兼容）';
	@override String get msg_enable_webdav_sync => '启用 WebDAV 同步';
	@override String get msg_local_libraries => '本地库';
	@override String get msg_apply => '确定';
	@override String get msg_restore_only_available_local_libraries => '仅本地库可恢复备份';
	@override String get msg_sign => '退出登录？';
	@override String get msg_reminders_disabled => '提醒功能已关闭';
	@override String get msg_downloading => '正在下载';
	@override String get msg_path => '路径';
	@override String get msg_match_any => '满足任一条件';
	@override String get msg_local_db_pending_queue => '本地数据库 + 待同步队列';
	@override String msg_scan_failed({required Object e}) => '扫描失败：${e}';
	@override String get msg_user => '用户';
	@override String get msg_pick_future_time => '请选择未来时间';
	@override String get msg_include_pending_queue => '包含待处理队列';
	@override String get msg_enter_days => '输入天数';
	@override String get msg_times => '提醒时间';
	@override String get msg_token_returned_only_once_cannot_fetched => 'Token 仅返回一次，无法再次获取';
	@override String msg_quoted_lines({required Object quoteLines}) => '引用 ${quoteLines} 行';
	@override String get msg_use_remote => '使用远端';
	@override String get msg_enable_memo_location => '启用定位';
	@override String get msg_failed_get_location => '定位失败';
	@override String get msg_after_import_memos_sync_list_automatically => '导入完成后，您的笔记将自动同步到笔记列表。对于压缩包导入，请确保文件结构完整。';
	@override String get msg_legacy_mode => '兼容模式';
	@override String get msg_signed => '登录成功';
	@override String get msg_shortcut_includes_advanced_conditions_saving_overwrite => '该快捷筛选包含高级条件，保存将覆盖这些条件。';
	@override String get msg_no_results_found => '未找到相关内容';
	@override String msg_reply({required Object replyName}) => '回复 ${replyName}...';
	@override String get msg_copy => '复制';
	@override String get msg_enable_reminders_memos => '开启后可为笔记设置提醒时间。';
	@override String get msg_comment => '评论';
	@override String get msg_added_voice_attachment => '已添加录音附件';
	@override String get msg_customize_sidebar => '自定义侧边栏';
	@override String get msg_coffee_add_drumstick => '☕ 这就是我要的咖啡/加个鸡腿';
	@override String get msg_pin => '置顶';
	@override String get msg_enter_password_continue => '请输入密码以继续';
	@override String get msg_remove_local_library => '移除本地库？';
	@override String get msg_comment_2 => '新评论';
	@override String get msg_sync_all => '全部同步';
	@override String get msg_backup_schedule => '备份频率';
	@override String get msg_server_error => '服务器内部错误';
	@override String get msg_analyzing_memos => '正在深度分析您的笔记...';
	@override String get msg_notification => '通知';
	@override String get msg_policy => '策略设置';
	@override String msg_failed_load({required Object error}) => '加载失败: ${error}';
	@override String get msg_default_visibility => '默认可见性';
	@override String get msg_filter => '筛选';
	@override String get msg_imported_memos => '导入笔记';
	@override String get msg_token_created => 'Token 已创建';
	@override String get msg_server_response_timeout_try => '服务器响应超时，请稍后重试';
	@override String get msg_expiring => '即将过期';
	@override String get msg_delete_task => '删除任务';
	@override String get msg_body_must_json => 'Body 必须是 JSON';
	@override String get msg_enable => '去开启';
	@override String get msg_referenced => '被引用';
	@override String get msg_replace_image => '确认替换？';
	@override String get msg_debug_logs => '调试记录';
	@override String get msg_active_tasks => '正在进行的任务';
	@override String get msg_attachments => '附件';
	@override String get msg_range => '时间范围';
	@override String get msg_no_backups_found => '暂无备份记录';
	@override String get msg_create_memo => '创建笔记';
	@override String get msg_street => '街道';
	@override String get msg_display_name => '显示名称';
	@override String get msg_full_text_search => '全文搜索';
	@override String get msg_create_edit_delete_actions_offline_stored => '离线创建/编辑/删除会先保存在本地并加入待同步队列，联网后按顺序发送。为避免误操作，未提交的编辑可保留为草稿。';
	@override String get msg_sign_2 => '退出登录';
	@override String get msg_end_time => '结束时间';
	@override String get msg_sync_recent_content => '同步最近内容';
	@override String get msg_resetting_local_data => '正在重置本地数据...';
	@override String get msg_incorrect_password => '密码错误';
	@override String get msg_content_cannot_empty => '内容不能为空';
	@override String get msg_preparing => '准备中';
	@override String msg_ai_summary_failed({required Object formatSummaryError_e}) => 'AI 总结失败：${formatSummaryError_e}';
	@override String get msg_manage => '管理';
	@override String get msg_keep_data_consistent_across_devices => '保持设备间数据一致。';
	@override String msg_playback_failed({required Object e}) => '播放失败: ${e}';
	@override String get msg_path_copied => '路径已复制';
	@override String get msg_auth_settings => '认证设置';
	@override String get msg_randomly_draw_memo_cards => '随机抽取你的卡片笔记';
	@override String get msg_copy_log_text => '复制日志文本';
	@override String get msg_yes => '是';
	@override String get msg_save_open_alipay_scan => '长按保存后打开支付宝扫一扫';
	@override String get msg_signed_but_no_token_returned => '登录成功，但未返回 Token';
	@override String msg_create_failed({required Object formatError_e_context}) => '创建失败：${formatError_e_context}';
	@override String get msg_expand => '展开';
	@override String get msg_local_library_only => '仅本地库可用';
	@override String get msg_reminder_channel => '提醒通知渠道';
	@override String get msg_grant => '去授权';
	@override String get msg_import_canceled => '已取消导入';
	@override String get msg_never => '永不过期';
	@override String get msg_release_notes => '版本公告';
	@override String get msg_failed_load_references => '加载引用失败';
	@override String get msg_select_tags => '选择标签';
	@override String get msg_failed_load_try => '加载失败，请稍后重试';
	@override String get msg_logs_copied => '记录已复制';
	@override String get msg_shortcuts_not_supported_server => '当前服务器不支持快捷筛选';
	@override String msg_reply_2({required Object name}) => '回复 ${name}...';
	@override String get msg_anonymous => '匿名';
	@override String get msg_username => '用户名';
	@override String get msg_update_memo => '更新笔记';
	@override String msg_saved({required Object targetPath}) => '已保存到: ${targetPath}';
	@override String get msg_chinese_simplified => '简体中文';
	@override String get msg_memo_copied => '已复制笔记内容';
	@override String get msg_collapse => '收起';
	@override String get msg_retry_count_controls_how_many_extra => '重试次数决定了上传失败后的最大尝试频率。设置较高的次数可以提高成功率，但可能增加等待时间。';
	@override String get msg_recording_info_missing => '录音信息缺失';
	@override String get msg_sync_task => '同步任务';
	@override String get msg_clear_all_debug_logs => '确认清空调试记录？';
	@override String get msg_export_finished => '导出完成';
	@override String msg_failed_stop_recording({required Object e}) => '停止录音失败：${e}';
	@override String get msg_my_profile => '我的资料';
	@override String get msg_image_bed => '兰空图床';
	@override String msg_failed_open_notification({required Object e}) => '打开通知失败：${e}';
	@override String get msg_manual => '手动';
	@override String get msg_no_html_file_found_zip => '压缩包内未找到 HTML 文件';
	@override String get msg_also_clear_local_cache_account_offline => '这会同时清除该账号的本地缓存（离线数据/草稿/待同步队列）。此操作无法撤销。';
	@override String get msg_restore => '恢复';
	@override String get msg_auto_backup => '自动备份';
	@override String get msg_generate_summary => '开始生成总结';
	@override String msg_days({required Object stats_activeDays}) => '${stats_activeDays} 天';
	@override String get msg_count => '- 数量';
	@override String get msg_weekly => '每周';
	@override String get msg_notifications => '通知';
	@override String get msg_backup_failed => '备份失败';
	@override String get msg_private => '仅私密';
	@override String get msg_filter_tags => '标签筛选';
	@override String get msg_clear_logs => '清空记录';
	@override String get msg_unable_open_browser => '无法打开浏览器';
	@override String get msg_attachment_too_large => '附件过大，超过服务器限制';
	@override String get msg_query => 'Query';
	@override String get msg_match_all => '满足所有条件';
	@override String get msg_record_request_response_logs => '记录请求/响应日志';
	@override String get msg_import_file => '导入文件';
	@override String get msg_content_tags => '内容 + 标签';
	@override String get msg_feature_not_available_local_library_mode => '本地库模式暂不支持该功能';
	@override String msg_import_failed({required Object e}) => '导入失败: ${e}';
	@override String get msg_save_memo => '保存为笔记';
	@override String get msg_scan_disk_directory_merge_local_database => '扫描磁盘目录并合并到本地数据库？缺失文件将视为删除。';
	@override String get msg_passwords_not_match => '两次密码不一致';
	@override String msg_signed_2({required Object lastLoginUser}) => '当前登录用户: ${lastLoginUser}';
	@override String get msg_made_love_note_taking => '为记录而生';
	@override String get msg_password_updated_local => '密码已更新（仅本地）';
	@override String get msg_retry => '重试';
	@override String get msg_memo_stats => '记录统计';
	@override String get msg_shown_only_once_copy_keep_safe => '仅显示一次，请复制并妥善保存。';
	@override String get msg_describe_issue_time_repro_steps_etc => '描述问题、时间、复现步骤等';
	@override String get msg_how_many_days_back => '过去多少天';
	@override String get msg_local_cache_cleared => '本地缓存已清除';
	@override String get msg_none => '无';
	@override String get msg_body_json => 'Body (JSON)';
	@override String msg_download_failed({required Object e}) => '下载失败: ${e}';
	@override String get msg_recycle_bin => '回收站';
	@override String get msg_unpin => '取消置顶';
	@override String get msg_advanced_security => '高级与安全';
	@override String get msg_run_issues_memoflow_e_g_sync => '如果您在使用 MemoFlow 时遇到问题（如同步失败、崩溃等），请按照以下步骤向我们反馈，这将帮助开发者快速定位并修复问题。\\n\\n';
	@override String get msg_remove_all_reminder_times_memo => '将移除该笔记的全部提醒时间。';
	@override String get msg_no_summary_save => '暂无可保存的总结';
	@override String get msg_reset_language_selection => '重置语言选择状态';
	@override String get msg_v_30_days => '30 天';
	@override String get msg_e_g_mood_check => '如：情绪分析';
	@override String get msg_note_some_tokens_returned_only_once => '提示：Token 可能只返回一次，之后无法再次获取，请妥善保存。';
	@override String get msg_syncing => '同步中...';
	@override String get msg_retention => '版本保留数量';
	@override String get msg_open_login_screen => '打开登录页面';
	@override String get msg_apply_all => '应用到全部';
	@override String get msg_write_something_supports_tag_tasks_x => '写点什么... 支持 #tag 和任务 [ ] / [x]';
	@override String msg_http({required Object base, required Object status, required Object msg}) => '${base}（HTTP ${status}）：${msg}';
	@override String get msg_single => '单次';
	@override String get msg_delete_memo => '删除 Memo？';
	@override String get msg_ai_provider => 'AI 提供方';
	@override String msg_release_notes_v({required Object version}) => '版本公告 v${version}';
	@override String get msg_info_only_used_background_ai_summaries => '这些信息仅用于 AI 总结/报告的背景，不会同步到后端。';
	@override String get msg_not_disturb => '免打扰模式';
	@override String msg_local_library_import_failed({required Object e}) => '本地库导入失败: ${e}';
	@override String get msg_key_insights => '核心洞察';
	@override String get msg_additional_notes_optional => '补充说明（可选）';
	@override String get msg_server_response_error => '服务响应异常';
	@override String get msg_sort => '排序';
	@override String get msg_api_call => 'API 调用';
	@override String get msg_webhooks => 'Webhooks';
	@override String get msg_local_library => '本地库';
	@override String get msg_log_copied => '日志已复制';
	@override String get msg_last_success => '最近成功';
	@override String get msg_restore_cloud => '从云端恢复';
	@override String get msg_search_public_memos => '搜索公开内容';
	@override String get msg_cancel => '取消生成';
	@override String msg_processing({required Object processed, required Object total}) => '正在处理 ${processed} / ${total}';
	@override String get msg_failed_items => '失败条数';
	@override String get msg_recording_file_not_found => '录音文件不存在';
	@override String get msg_local_db_outbox_queue => '本地数据库 + 待同步队列';
	@override String get msg_remove => '移除';
	@override String get msg_export_format => '导出格式';
	@override String get msg_idle => '空闲';
	@override String msg_ago({required Object months}) => '${months}个月前';
	@override String get msg_no_tags_yet => '暂无标签';
	@override String msg_version_v({required Object version}) => '版本 v${version}';
	@override String get msg_sync => '同步';
	@override String get msg_done => '完成';
	@override String get msg_gallery_permission_required_2 => '需要相册权限以保存图片';
	@override String get msg_insufficient_permissions => '权限不足';
	@override String get msg_no_download_url_available => '无法获取下载链接';
	@override String get msg_record_create_memos => '录音生成 memo';
	@override String get msg_signing => '登录中…';
	@override String get msg_memoflow_uses_system_location_permission_get => '定位将使用系统权限获取经纬度，并通过高德 Web API 反向地理解析地址，可在上方选择显示精度。';
	@override String get msg_continue => '继续';
	@override String get msg_notification_content_unavailable => '通知缺少内容';
	@override String get msg_unable_read_file_path => '无法获取文件路径';
	@override String get msg_all_memos => '全部笔记';
	@override String get msg_keywords => '关键词';
	@override String get msg_import_result => '导入结果';
	@override String get msg_offline_sync => '离线同步';
	@override String get msg_imported_memos_local_library => '已从本地库导入笔记';
	@override String get msg_request_failed => '请求失败';
	@override String get msg_log_file => '日志文件';
	@override String get msg_after_confirming_support_unlock_limited_gold => '点击确认赞赏后，将解锁限定版金色标识 or 永久去广告承诺（虽然本来就没广告）';
	@override String get msg_failed_open_system_settings => '无法打开系统设置';
	@override String get msg_no_mood_trend => '暂无情绪趋势';
	@override String get msg_memoflow_export => '# MemoFlow 导出';
	@override String get msg_sync_queue => '同步队列';
	@override String get msg_only_delete_sync_task_memo_kept => '仅删除同步任务，笔记会保留。';
	@override String get msg_add_home_screen => '添加到桌面';
	@override String get msg_past_days => '过去天数';
	@override String get msg_poster_generation_failed => '海报生成失败';
	@override String msg_failed_load_stats({required Object e}) => '加载统计失败：${e}';
	@override String get msg_customize_notification => '自定义通知';
	@override String get msg_updated_time => '修改时间 ↓';
	@override String get msg_network_connection_failed_check_network => '网络连接失败，请检查网络';
	@override String get msg_special_thanks => '本次更新特别鸣谢：';
	@override String msg_failed_comment({required Object e}) => '评论失败：${e}';
	@override String get msg_security_key_sig => '安全密钥（sig）';
	@override String get msg_save_gallery => '保存到相册';
	@override String get msg_request_sent_confirm_system_prompt => '已发送请求，请在系统提示中确认';
	@override String get msg_server_url => '服务器地址';
	@override String get msg_period_review => '阶段回顾';
	@override String get msg_settings_updated => '已更新设置';
	@override String get msg_backend_0_21_not_supported_import => '检测到 0.21 版本，暂不支持导入，请升级后端后再试';
	@override String msg_failed_load_tags({required Object e}) => '加载标签失败：${e}';
	@override String get msg_enter_email => '请输入邮箱';
	@override String get msg_add_webhook => '新增 Webhook';
	@override String get msg_read => '已读';
	@override String get msg_widgets => '小组件';
	@override String get msg_default => '默认';
	@override String get msg_memo_reminders => '笔记提醒';
	@override String get msg_import_flomo => '从 Flomo 导入';
	@override String get msg_format_fixed_markdown_zip => '格式固定为 Markdown + ZIP';
	@override String get msg_enter_username_password => '请输入账号和密码';
	@override String get msg_loading => '加载中...';
	@override String msg_test_scheduled({required Object timeLabel, required Object suffix, required Object pendingLabel}) => '已安排测试提醒：${timeLabel}${suffix}${pendingLabel}';
	@override String get msg_edit_memo => '编辑 Memo';
	@override String get msg_save => '保存';
	@override String get msg_laboratory => '实验室';
	@override String get msg_use_local => '使用本地';
	@override String get msg_retry_sync => '重试同步';
	@override String get msg_e_g_my_role_topics_interest => '例如：我的角色 / 兴趣主题 / 写作风格偏好';
	@override String get msg_confirm_password => '确认密码';
	@override String get msg_not_set => '未设置';
	@override String get msg_no_memos_day => '当天无记录';
	@override String get msg_shortcut_name => '输入名称';
	@override String get msg_edit_shortcut => '编辑快捷筛选';
	@override String get msg_days_memos => '坚持记录天数';
	@override String get msg_delete => '删除';
	@override String get msg_test_reminder => '测试提醒';
	@override String get msg_enable_reminders => '开启提醒';
	@override String get msg_links => '双链';
	@override String get msg_location => '定位设置';
	@override String get msg_import_file_2 => '从文件导入';
	@override String msg_reply_3({required Object creatorDisplayName_commentCreator_commentMemo_creator}) => '回复 ${creatorDisplayName_commentCreator_commentMemo_creator}...';
	@override String msg_created({required Object widget_createdAtLabel}) => '创建于 ${widget_createdAtLabel}';
	@override String get msg_notifications_coming_soon => '通知功能即将上线';
	@override String get msg_view_full_contributors => '查看完整致谢名单';
	@override String get msg_no_times_set => '尚未设置提醒时间';
	@override String get msg_ignore_tls_errors => '忽略证书校验';
	@override String get msg_no_content => '无内容';
	@override String get msg_about_15_seconds_left => '预计还需 15 秒';
	@override String get msg_view_imported_memos => '查看导入笔记';
	@override String get msg_load_failed => '加载失败';
	@override String get msg_disk_content_conflicts_local_pending_changes => '磁盘与本地未同步内容冲突。选择“以磁盘为准”将覆盖本地内容。';
	@override String get msg_all_history_so_far_memoflow_since => '以上是全部历史内容\\nMEMOFLOW SINCE 2023';
	@override String get msg_cancelling => '取消中';
	@override String get msg_reading_file => '正在读取文件...';
	@override String get msg_switch_workspace => '切换工作区';
	@override String get msg_optional_leave_empty_default => '选填，使用默认存储策略时请留空';
	@override String get msg_memo_reminders_2 => '笔记提醒';
	@override String msg_save_failed_2({required Object e}) => '保存失败: ${e}';
	@override String get msg_record_create_memos_sync_later => '录音生成 memo（可稍后同步）';
	@override String get msg_use_https_avoid_ignoring_tls_errors => '为了安全，建议使用 HTTPS，且避免忽略证书校验。';
	@override String get msg_failed_load_announcement_config => '未获取到公告配置';
	@override String get msg_shortcuts => '快捷筛选';
	@override String get msg_memo => '笔记';
	@override String get msg_maybe_later => '稍后再说';
	@override String get msg_server_connection => '服务器连接';
	@override String get msg_days_2 => '天';
	@override String get msg_include_archived => '包含归档';
	@override String get msg_during_quiet_hours_reminders_silenced => '在免打扰期间，应用将保持静默，不会弹出任何提醒。';
	@override String get msg_preview_not_supported_type => '暂不支持该类型预览';
	@override String get msg_failed_load_2 => '加载失败';
	@override String get msg_create_token => '创建新 Token';
	@override String get msg_enter_name => '请输入筛选名称';
	@override String get msg_api_url_incorrect => 'API URL 不正确';
	@override String get msg_user_general_settings => '用户通用设置';
	@override String get msg_saved_memo => '已保存为笔记';
	@override String msg_restore_failed({required Object e}) => '恢复失败：${e}';
	@override String msg_token_tail({required Object tail}) => 'Token 尾号 ${tail}';
	@override String get msg_manual_token => '手动 Token';
	@override String msg_ago_2({required Object years}) => '${years}年前';
	@override String get msg_recent_searches => '最近搜索';
	@override String get msg_restored => '已恢复';
	@override String get msg_no_contributors_yet => '暂无致谢名单';
	@override String get msg_no_record_yet => '暂无记录';
	@override String get msg_reminder => '提醒';
	@override String get msg_enter_api_key_ai_settings => '请先在 AI 设置中填写 API Key';
	@override String get msg_reminder_settings => '提醒设置';
	@override String msg_http_2({required Object base, required Object status}) => '${base}（HTTP ${status}）';
	@override String get msg_edit_webhook => '编辑 Webhook';
	@override String get msg_generate_share_poster => '生成分享海报';
	@override String msg_archive_failed({required Object e}) => '归档失败：${e}';
	@override String msg_comments({required Object widget_commentCount}) => '${widget_commentCount} æ¡è¯è®º';
	@override String get msg_remove_account => '移除账号？';
	@override String get msg_chinese_traditional => '繁體中文';
	@override String get msg_private_2 => '私密';
	@override String get msg_current_streak => '当前连击';
	@override String get msg_generated_ai_memoflow => '由 AI 生成 · MemoFlow';
	@override String get msg_edit_completed => '编辑完成';
	@override String get msg_local => '本地调试';
	@override String get msg_edit => '编辑';
	@override String msg_text({required Object shortUserName_item_sender}) => '来自 ${shortUserName_item_sender}';
	@override String get msg_got => '知道了';
	@override String get msg_web_api_key => 'Web API Key';
	@override String get msg_preview => '预览';
	@override String get msg_enter_password => '请输入密码';
	@override String get msg_api => '接口';
	@override String get msg_ok => '确定';
	@override String get msg_failed_load_shortcuts => '快捷筛选加载失败';
	@override String get msg_after_recording_audio_added_current_draft => '录音完成后会将音频作为附件加入当前草稿，便于继续编辑后再发送。最长 60 分钟；可后续通过第三方服务转写。';
	@override String get msg_pull_refresh => '下拉刷新';
	@override String get msg_unable_open_photo => '无法打开照片';
	@override String get msg_existing_tokens => '已有 Token';
	@override String get msg_ai_settings => 'AI 设置';
	@override String get msg_app_lock => '应用锁';
	@override String get msg_total_notes => '总记录';
	@override String get msg_stats_loading => '统计数据加载中...';
	@override String get msg_enter_token_description => '请输入 Token 描述';
	@override String get msg_enter_token => '请输入 Token';
	@override String get msg_api_plugins => 'API 与插件';
	@override String get msg_parsing_file => '正在解析文件...';
	@override String get msg_english => '英语';
	@override String get msg_activity_heatmap => '记录热力图';
	@override String get msg_mark_read => '标记已读';
	@override String get msg_request => '申请';
	@override String msg_sync_failed({required Object type, required Object memoError}) => '同步失败（${type}）：${memoError}';
	@override String get msg_error_copied => '已复制错误信息';
	@override String get msg_only_local_index_removed_disk_files => '仅移除本地索引，磁盘文件保留。此操作无法撤销。';
	@override String get msg_switch_account => '切换账号';
	@override String get msg_invalid_download_link => '无效的更新链接';
	@override String get msg_about => '关于';
	@override String get msg_icon => '图标选择';
	@override String get msg_reset_done_syncing => '已重置，开始重新同步';
	@override String get msg_enter_amap_web_api_key => '请输入高德 Web API Key';
	@override String get msg_recycle_bin_coming_soon => '回收站功能暂未开放';
	@override String get msg_empty_content => '（空内容）';
	@override String get msg_note_most_features_offline_stats_ai => '提示：大部分功能（离线/统计/AI 总结/导出）无需后端改动，但 Token 只返回一次，请妥善保存。';
	@override String get msg_fixed => '修复：';
	@override String get msg_allow_sharing_links_images_other_apps => '允许从其他应用分享链接或图片到 MemoFlow。';
	@override String get msg_invalid_request_parameters => '请求参数错误';
	@override String get msg_enter_api_url => '请输入 API URL';
	@override String msg_pending({required Object result_pendingCount}) => '（待发送 ${result_pendingCount}）';
	@override String msg_days_3({required Object currentStreak}) => '${currentStreak} 天';
	@override String get msg_poster_not_ready_yet => '暂时无法生成海报';
	@override String get msg_generated_memoflow => '由 MemoFlow 生成';
	@override String get msg_enter_name_2 => '请输入名称';
	@override String get msg_version => '版本';
	@override String get msg_memo_missing_disk_but_has_local => '磁盘缺失该笔记，但本地还有未同步改动。选择“以磁盘为准”将删除本地记录。';
	@override String get msg_legacy_api_compatibility => '旧版 API 兼容';
	@override String get msg_sync_parameters => '同步参数';
	@override String get msg_quick_prompts => '快速提示词';
	@override String msg_share_failed({required Object e}) => '分享失败：${e}';
	@override String get msg_no_memos_summarize_range => '该时间范围内没有可总结的笔记';
	@override String get msg_characters => '字数';
	@override String get msg_capture_every_moment_record => '记录每一个瞬间';
	@override String get msg_vibration => '震动';
	@override String get msg_days_4 => '天';
	@override String get msg_prompt_title => '提示词标题';
	@override String get msg_show_all => '展开';
	@override String get msg_no_memos_available => '暂无可关联的笔记';
	@override String get msg_comment_unavailable => '评论内容不可用';
	@override String get msg_refresh => '刷新';
	@override String get msg_syncing_2 => '同步中';
	@override String get msg_body => '通知正文';
	@override String get msg_clear_2 => '清除';
	@override String get msg_third_party_share => '第三方分享';
	@override String get msg_charging_station => '充电站';
	@override String get msg_attachments_2 => '附件资源';
	@override String get msg_when_enabled_must_verify_each_app => '开启后每次进入应用需要验证。自动锁定时间决定应用进入后台后多久需要再次验证。';
	@override String get msg_add_prompt => '添加提示词';
	@override String get msg_include => '包含';
	@override String get msg_created_time_2 => '创建时间 ↓';
	@override String get msg_choose_data_source_start_importing_memos => '选择一个数据来源开始导入您的笔记';
	@override String get msg_describe_how_want_summary => '请分析我本周笔记中体现的情绪波动曲线…';
	@override String get msg_keep_token_safe_not_share_api => '请妥善保存 Token，不要泄露。\\nAPI 访问频率限制为每分钟 60 次。';
	@override String get msg_open_2 => '去开启';
	@override String get msg_e_g_claude_3_5_sonnet => '例如 claude-3-5-sonnet-20241022';
	@override String get msg_failed_request_whitelist => '无法申请电池白名单';
	@override String get msg_notification_deleted => '通知已删除';
	@override String get msg_accounts => '账号';
	@override String get msg_add_local_library => '添加本地库';
	@override String get msg_sign_first => '请先登录';
	@override String get msg_failed_parse_query => 'Query 解析失败';
	@override String get msg_note_logs_sanitized_automatically_sensitive_data => '提示：日志已自动去除敏感信息，如仍包含敏感数据，请提交前自行处理。';
	@override String get msg_add => '新增';
	@override String msg_failed_load_3({required Object memosError}) => '加载失败：${memosError}';
	@override String get msg_max_chars_day => '单日最多字数';
	@override String get msg_choose_what_edited_image => '请选择要执行的操作';
	@override String get msg_select => '请选择';
	@override String get msg_unnamed_token => '(未命名 Token)';
	@override String get msg_name => '筛选名称';
	@override String get msg_sure_want_delete_webhook => '确定要删除该 Webhook 吗？';
	@override String get msg_back => '返回';
	@override String get msg_no => '否';
	@override String get msg_untitled => '未命名';
	@override String get msg_open_language_onboarding => '打开语言首次设置';
	@override String get msg_voice_memos => '语音备忘';
	@override String get msg_unable_open_browser_try => '无法打开浏览器，请稍后重试';
	@override String get msg_date_range => '时间范围';
	@override String get msg_not_authenticated => '未登录';
	@override String get msg_back_2 => 'Back';
	@override String get msg_local_library_removed => '本地库已移除';
	@override String get msg_exact_alarm_permission_required => '需要闹钟与提醒权限';
	@override String get msg_visibility => '可见性';
	@override String msg_failed_start_recording({required Object e}) => '启动录音失败：${e}';
	@override String get msg_mood_trend => '情绪趋势';
	@override String get msg_local_library_name => '本地库名称';
	@override String get msg_no_tokens_yet => '暂无 Token';
	@override String get msg_loading_2 => '加载中…';
	@override String get msg_location_permission_denied_permanently => '定位权限被永久拒绝';
	@override String get msg_download => '下载';
	@override String get msg_export_time => '- 导出时间';
	@override String get msg_enter_password_2 => '请输入密码';
	@override String get msg_no_image_available => '没有可显示的图片';
	@override String get msg_daily => '每天';
	@override String get msg_no_likes_yet => '暂无点赞';
	@override String get msg_basics => '基础配置';
	@override String get msg_shortcut => '新建快捷筛选';
	@override String get msg_debug_tools => '调试工具';
	@override String get msg_save_settings => '保存设置';
	@override String get msg_date_range_2 => '日期范围';
	@override String get msg_feedback => '反馈';
	@override String get msg_image_bed_2 => '图床';
	@override String get msg_restoring => '恢复中…';
	@override String get msg_export => '导出';
	@override String get msg_enter_token_name => '请输入 Token 名称';
	@override String get msg_start_time => '开始时间';
	@override String get msg_preparing_file_structure => '正在准备文件结构';
	@override String get msg_sign_3 => '登录';
	@override String get msg_scan_local_library => '扫描本地库';
	@override String get msg_lsky_pro => '兰空图床 (Lsky Pro)';
	@override String get msg_exact_alarm_permission_off_reminders_may => '未开启闹钟与提醒权限，定时提醒可能无法触发。是否前往开启？';
	@override String get msg_last_30_days => '最近一月';
	@override String get msg_match => '匹配方式';
	@override String get msg_auth_mode => '认证方式';
	@override String get msg_unsupported_file_type => '不支持的文件格式';
	@override String get msg_only_delete_sync_task => '仅删除同步任务。';
	@override String get msg_change_password => '修改密码';
	@override String get msg_saved_2 => '已保存';
	@override String get msg_import_export => '导入 / 导出';
	@override String get msg_created_2 => '创建时间';
	@override String get msg_ai_summary => 'AI 总结';
	@override String get msg_progress => '完成进度';
	@override String get msg_replace_memo_image => '替换笔记图片';
	@override String get msg_app_settings => '应用设置';
	@override String get msg_copy_path => '复制路径';
	@override String get msg_components => '功能组件';
	@override String get msg_no_shortcuts => '暂无快捷筛选';
	@override String get msg_location_timed_try => '定位超时，请重试';
	@override String get msg_attach_location_info_memos_show_subtle => '为笔记记录定位信息，并展示简洁地名。';
	@override String msg_send_failed({required Object e}) => '发送失败：${e}';
	@override String get msg_repeat => '重复';
	@override String get msg_not_signed => '未登录';
	@override String get msg_no_webhooks_configured => '暂无 Webhooks';
	@override String get msg_apply_token => '应用 Token';
	@override String get msg_enable_reminder_permissions_2 => '开启提醒权限';
	@override String get msg_enter_backup_password => '请输入备份密码';
	@override String get msg_start_backup => '开始备份';
	@override String get msg_last_sync => '上次同步';
	@override String get msg_note_export_includes_content_already_synced => '提示：导出包含已同步到本地数据库的内容（含离线数据）。';
	@override String get msg_enter_username => '请输入用户名';
	@override String get msg_settings_saved => '设置已保存';
	@override String get msg_no_keywords => '暂无关键词';
	@override String get msg_these_settings_apply_newly_created_memos => '此设置将应用于新建的 Memo。';
	@override String get msg_back_home => '返回主页';
	@override String get msg_quiet_hours => '休息时间';
	@override String get msg_add_account => '添加账号';
	@override String get msg_reset_complete => '已重置';
	@override String get msg_no_shortcuts_configured => '暂无快捷筛选';
	@override String get msg_password => '密码';
	@override String get msg_importing => '导入中';
	@override String msg_visibility_2({required Object visibilityLabel}) => '可见性：${visibilityLabel}';
	@override String get msg_no_logs_yet => '暂无记录';
	@override String get msg_v_9_times_allowed => '最多设置 9 个提醒时间';
	@override String get msg_last_14_days => '最近 14 天';
	@override String get msg_location_disabled_enable_settings_first => '定位未启用，请先在设置中开启。';
	@override String get msg_add_2 => '添加';
	@override String get msg_logs => '日志';
	@override String get msg_references => '引用了';
	@override String get msg_importing_memos => '正在导入笔记...';
	@override String get msg_account_security => '账号与安全';
	@override String get msg_reminder_2 => '提醒设置';
	@override String get msg_enable_scheduled_reminder_notifications => '开启后将按计划发送笔记提醒通知。';
	@override String get msg_no_links => '暂无双链';
	@override String get msg_delete_memo_2 => '删除笔记';
	@override String get msg_one_tap_add_not_supported_add => '不支持一键添加，请从小组件列表添加';
	@override String get msg_password_2 => '新密码';
	@override String get msg_processing_content => '正在处理内容...';
	@override String get msg_status => '状态';
	@override String get msg_local_library_added => '本地库已添加';
	@override String get msg_failed_open_try => '打开失败，请稍后重试';
	@override String get msg_removed_locally_now_deleted_server_when => '本地会立即移除，联网后将同步删除服务器内容。';
	@override String get msg_server_url_unavailable => '未找到服务器地址';
	@override String get msg_no_release_notes_yet => '暂无更新日志';
	@override String get msg_cancelling_2 => '正在取消...';
	@override String get msg_summaries_selected_range => '支持按时间范围总结';
	@override String get msg_expand_2 => '展开更多';
	@override String get msg_close => '关闭';
	@override String msg_more_comments({required Object remainingComments}) => '还有 ${remainingComments} 条评论';
	@override String get msg_backing => '备份中…';
	@override String get msg_view_debug_logs => '查看调试记录';
	@override String get msg_location_permission_denied => '定位权限被拒绝';
	@override String get msg_self_repair_reset_heatmap => '自助修复：重置热力图';
	@override String get msg_these_settings_changed_locally_remotely_choose => '以下设置在本地和远端都有修改，请选择保留哪个版本。';
	@override String get msg_not_authenticated_2 => '未登录账号';
	@override String msg_action_failed({required Object e}) => '操作失败：${e}';
	@override String get msg_shortcut_2 => '新建快捷筛选';
	@override String get msg_url => 'URL';
	@override String get msg_no_memos_found_html => 'HTML 内未找到可导入的内容';
	@override String get msg_enter_what_want_summarize => '输入你想总结的内容或指令...';
	@override String get msg_unable_load_audio_source => '无法读取音频资源';
	@override String get msg_strategy_id => '策略 ID';
	@override String msg_copy_failed({required Object e}) => '复制失败：${e}';
	@override String get msg_enable_image_bed => '启用图床';
	@override String get msg_active => '有效';
	@override String get msg_account => '账号';
	@override String get msg_invalid_webdav_server_url => 'WebDAV 服务器地址无效';
	@override String get msg_keep_local => '以本地为准';
	@override String get msg_within_range => '在时间范围内';
	@override String get msg_generate_log_file => '生成日志文件';
	@override String get msg_ai_reports => 'AI 总结';
	@override String get msg_battery_optimization => '电池优化';
	@override String get msg_sync_overview => '同步概览';
	@override String get msg_legacy_servers_not_support_search_filters => '旧版本服务器不支持搜索过滤，结果可能不完整。';
	@override String get msg_conflicts_detected_run_manual_sync => '存在冲突，需要手动同步';
	@override String get msg_authentication_failed_check_token => '认证失败，请检查 Token';
	@override String get msg_date_range_3 => '时间范围';
	@override String get msg_help_ai_understand_better => '帮助 AI 更了解你';
	@override String get msg_no_search_history => '暂无搜索记录';
	@override String get msg_enter_api_path => '请输入接口路径';
	@override String get msg_stats => '统计';
	@override String get msg_text_2 => '新增：';
	@override String get msg_removing_signing_clear_local_cache_account => '移除/退出将清除该账号的本地缓存（离线数据/草稿/待同步队列）。';
	@override String get msg_updated_time_2 => '修改时间 ↑';
	@override String get msg_province => '省';
	@override String get msg_submitting_sync_queue => '正在提交同步队列';
	@override String get msg_failed => '失败';
	@override String get msg_set_time => '设置时间';
	@override String get msg_enable_local_library_backup => '启用本地库备份';
	@override String get msg_cancel_2 => '取消';
	@override String get msg_week => '本周回顾';
	@override String get msg_like => '赞';
	@override String get msg_location_services_disabled => '定位服务未开启';
	@override String get msg_clears_local_cache_offline_memos_pending => '这会清空本地缓存（离线笔记/待同步队列）并重新全量同步。未同步内容会丢失，可能需要一些时间。是否继续？';
	@override String get msg_load_more => '加载更多';
	@override String get msg_pull_memo_list_refresh_sync_sync => '在笔记列表下拉即可刷新并同步。同步会优先拉取最新内容；建议定期全量同步以保持统计/热力图完整。';
	@override String msg_server_returned_error({required Object code}) => '服务返回错误（${code}）';
	@override String get msg_sound_feedback => '声音与反馈';
	@override String msg_memos_skipped_attachments_skipped({required Object exportedMemoCount, required Object skippedMemoCount, required Object exportedAttachmentCount, required Object skippedAttachmentCount}) => '笔记 ${exportedMemoCount} 条（跳过 ${skippedMemoCount} 条），附件 ${exportedAttachmentCount} 个（跳过 ${skippedAttachmentCount} 个）';
	@override String get msg_import_complete => '导入完成';
	@override String get msg_text_3 => '新增';
	@override String get msg_max_per_day => '单日最多条数';
	@override String get msg_permissions_denied => '权限未授予';
	@override String get msg_memo_2 => '新建 Memo';
	@override String get msg_delete_reminder => '删除提醒';
	@override String get msg_select_month => '选择月份';
	@override String get msg_select_backup => '选择备份';
	@override String get msg_no_keywords_2 => '#暂无关键词';
	@override String get msg_preparing_memo_content => '正在准备笔记内容';
	@override String get msg_prompt_content => '具体指令内容';
	@override String get msg_default_prompt_ai_summaries_reports => '用于 AI 总结/报告的默认提示词';
	@override String get msg_intro => '引言';
	@override String get msg_monthly_stats => '每月统计';
	@override String get msg_times_2 => '次';
	@override String get msg_file_has_already_been_imported_skipped => '该文件已导入过，已跳过';
	@override String get msg_token_tail_unknown => 'Token 尾号未知';
	@override String get msg_press_back_exit => '再按一次返回退出';
	@override String get msg_enter_password_3 => '输入密码';
	@override String get msg_sync_conflicts => '同步冲突';
	@override String get msg_locale => '语言';
	@override String get msg_any => '包含任一';
	@override String get msg_provider => '服务商';
	@override String get msg_preview_2 => '预览效果';
	@override String get msg_automatically_upload_images_append_links_memo => '开启后自动上传图片并在正文末尾插入链接。';
	@override String get msg_import_file_not_found => '找不到导入文件';
	@override String get msg_today => '今天';
	@override String get msg_link_card => '关联卡片';
	@override String get msg_expiration => '有效期';
	@override String get msg_summary_prompt_optional => '总结指令 (可选)';
	@override String get msg_memos => '笔记';
	@override String get msg_recording_file_not_found_2 => '录音文件不存在';
	@override String get msg_backup_settings => '备份设置';
	@override String get msg_mode => '提醒模式';
	@override String get msg_no_markdown_memos_found_zip => '压缩包内未找到 Markdown 笔记';
	@override String get msg_archived => '已归档';
	@override String msg_update_failed({required Object e}) => '更新失败：${e}';
	@override String get msg_enable_app_lock => '启用应用锁';
	@override String get msg_html_zip => 'HTML / ZIP';
	@override String get msg_all => '包含全部';
	@override String get msg_model => '模型';
	@override String get msg_title => '通知标题';
	@override String get msg_amap_web_api => '高德 Web API';
	@override String get msg_saved_gallery => '已保存到相册';
	@override String get msg_unread => '未读';
	@override String get msg_exporting => '正在导出...';
	@override String get msg_network_timeout_try => '网络超时，请稍后重试';
	@override String get msg_unlock => '解锁';
	@override String msg_ago_3({required Object diff_inDays}) => '${diff_inDays}天前';
	@override String get msg_deserve_coffee_i_m_pulling_all => '为了对得起这杯咖啡，今晚我决定不睡了，写它个一百行代码！';
	@override String get msg_token_name => 'Token 名称';
	@override String get msg_restore_completed => '恢复完成';
	@override String get msg_copied_clipboard => '已复制到剪贴板';
	@override String msg_failed_2({required Object attempts}) => '失败 ${attempts}次';
	@override String get msg_too_many_requests_try_later => '请求过于频繁，请稍后重试';
	@override String get msg_more => '更多';
	@override String get msg_already_whitelisted => '已在电池白名单';
	@override String get msg_local_library_backup => '本地库备份';
	@override String get msg_awesome => '太棒啦！ ❤️';
	@override String get msg_now => '现在';
	@override String get msg_select_reminder_time => '请设置提醒时间';
	@override String get msg_protected => '受保护';
	@override String msg_failed_load_4({required Object e}) => '加载失败：${e}';
	@override String msg_operation_failed({required Object e}) => '操作失败：${e}';
	@override String get msg_no_tags => '暂无标签';
	@override String get msg_server => '服务器';
	@override String get msg_improved => '优化';
	@override String get msg_request_2 => '请求';
	@override String msg_export_failed({required Object e}) => '导出失败：${e}';
	@override String get msg_notification_settings => '通知设置';
	@override String get msg_related_memo_was_deleted => '通知对应的内容已被删除';
	@override String get msg_email => '邮箱';
	@override String get msg_enter_password_4 => '请输入密码';
	@override String get msg_retry_count => '失败重试次数';
	@override String get msg_import_exported_html_zip_package => '导入导出的 HTML 或压缩包';
	@override String get msg_archive => '归档';
	@override String get msg_reset_heatmap => '重置热力图？';
	@override String get msg_token_applied => 'Token 已应用';
	@override String get msg_log_file_created => '日志文件已生成';
	@override String get msg_delete_sync_task => '删除同步任务';
	@override String get msg_include_archived_2 => '- 包含归档';
	@override String get msg_memoflow_side_project_i_build_my => 'MemoFlow 是我用业余时间肝出来的孩子。目前开发者已连续熬夜修 Bug，急需一杯冰美式“续命”。你的投喂不仅能恢复我的电量，还能让新功能提早 ';
	@override String msg_failed_generate({required Object e}) => '生成失败：${e}';
	@override String get msg_search_logs => '搜索内容';
	@override String get msg_active_days => '累计天数';
	@override String get msg_back_top => '回到顶部';
	@override String get msg_month => '本月回顾';
	@override String get msg_loading_references => '正在加载引用';
	@override String get msg_silent => '静音';
	@override String get msg_settings => '设置';
	@override String get msg_locating => '正在定位…';
	@override String get msg_scan => '扫描';
	@override String get msg_recording_path_missing => '录音路径缺失';
	@override String get msg_date_range_4 => '- 时间范围';
	@override String get msg_suggested_tags => '推荐标签';
	@override String get msg_energy_restored => '⚡ ENERGY RESTORED';
	@override String get msg_username_2 => '账号';
	@override String get msg_ai_summary_report => 'AI 总结报告';
	@override String get msg_all_tags => '全部标签';
	@override String get msg_preferences => '偏好设置';
	@override String get msg_image_bed_3 => '图床设置';
	@override String get msg_quick_input => '快速输入';
	@override String get msg_tags => '标签';
	@override String get msg_energy_critically_low => '能量值告急！';
	@override String msg_delete_failed({required Object e}) => '删除失败：${e}';
	@override String get msg_server_login => '服务端登录';
	@override String get msg_like_2 => '点赞';
	@override String get msg_save_2 => '确定';
	@override String get msg_unknown => '未知用户';
	@override String get msg_release_notes_2 => '更新日志';
	@override String get msg_include_error_details => '包含错误详情';
	@override String get msg_write_comment => '写下评论...';
	@override String get msg_write_thoughts => '写下你的想法...';
	@override String get msg_local_2 => '本地';
	@override String get msg_expired => '已过期';
	@override String get msg_fixed_2 => '修复';
	@override String get msg_upload_attachment => '上传附件';
	@override String get msg_battery_whitelist => '电池白名单';
	@override String get msg_district => '区';
	@override String get msg_voice_memo => '🎙️ 语音记录\\n';
	@override String get msg_system_default => '系统默认';
	@override String get msg_all_memos_2 => '全部笔记';
	@override String get msg_network_request_failed => '网络请求失败';
	@override String get msg_memo_not_found => '笔记不存在';
	@override String msg_playback_failed_2({required Object e}) => '播放失败：${e}';
	@override String get msg_sync_settings_webdav_across_devices => '将设置同步到 WebDAV，在设备之间保持一致。';
	@override String get msg_offline_first_client_memos_backend => '一个基于 Memos 后端的离线优先客户端。';
	@override String get msg_user_guide => '使用指南';
	@override String get msg_notice => '通知';
	@override String get msg_exact_alarms => '闹钟与提醒';
	@override String get msg_restoring_overwrite_local_library_files_rebuild => '恢复会覆盖本地库文件，并重新导入数据库。此操作无法撤销。';
	@override String get msg_enter_api_url_ai_settings => '请先在 AI 设置中填写 API URL';
	@override String msg_create_failed_2({required Object e}) => '创建失败：${e}';
	@override String get msg_close_search => '关闭搜索';
	@override String get msg_imported_memos_2 => '查看导入笔记';
	@override String get msg_explore => '探索';
	@override String get msg_network_connection_failed => '网络连接失败，请检查网络';
	@override String msg_save_failed_3({required Object e}) => '保存失败：${e}';
	@override String get msg_no_summary_share => '暂无可分享的总结';
	@override String get msg_custom_model => '自定义模型';
	@override String msg_sign_failed({required Object message}) => '登录失败: ${message}';
	@override String get msg_notification_exact_alarm_permissions_required_send => '需要通知权限与精确闹钟权限，才能在指定时间发送提醒。';
	@override String get msg_random_review => '随机漫步';
	@override String get msg_public => '公开';
	@override String get msg_all_2 => '全部';
	@override String get msg_add_custom_model => '添加自定义模型';
	@override String get msg_backup_password => '备份密码';
	@override String get msg_optional_used_sign_requests => '选填，用于签名请求';
	@override String get msg_search => '搜索';
	@override String get msg_set_password => '设置密码';
	@override String get msg_submit_logs => '提交日志';
	@override String get msg_activity_heatmap_2 => '记录热力图';
	@override String get msg_invalid_api_key_insufficient_permissions => 'API Key 无效或无权限';
	@override String get msg_data_has_been_migrated_app_successfully => '您的数据已成功迁移至本应用。';
	@override String get msg_get_version => '立即获取新版本';
	@override String get msg_token_source => 'Token 来源';
	@override String get msg_send => '发送';
	@override String get msg_no_pending_sync_tasks => '暂无待同步任务';
	@override String get msg_locating_memo_content => '正在定位笔记内容';
	@override String get msg_offline_ready => '离线可用';
	@override String get msg_use_relative_path => '请使用相对路径';
	@override String get msg_total => '总记录';
	@override String get msg_location_2 => '定位';
	@override String get msg_show_location_metadata_memos_not_configured => '在笔记中显示定位信息，未配置密钥时将仅显示经纬度。';
	@override String get msg_api_url => 'API 地址';
	@override String get msg_parsing_progress => '解析进度';
	@override String get msg_parsing => '解析中';
	@override String get msg_custom => '自定义';
	@override String get msg_tags_created => '新生成的标签';
	@override String get msg_third_party_share_disabled => '第三方分享未开启';
	@override String get msg_loading_links => '双链加载中';
	@override String get msg_how_report => '如何反馈？';
	@override String get msg_confirm_password_2 => '再次输入确认';
	@override String get msg_search_title_content_tags => '您可以搜索标题、内容或标签';
	@override String msg_reset_failed({required Object e}) => '重置失败：${e}';
	@override String get msg_debug_preview_update_dialog => '调试：预览更新公告';
	@override String get msg_what_s => '写点什么…';
	@override String get msg_ringtone => '提醒铃声';
	@override String get msg_unable_detect_backend_version_check_server => '无法识别后端版本，请检查地址或网络';
	@override String get msg_pending_2 => '待同步';
	@override String get msg_parsing_html => '正在解析 HTML...';
	@override String get msg_actions => '操作';
	@override String get msg_import_complete_2 => '导入完成';
	@override String get msg_use_disk => '以磁盘为准';
	@override String get msg_root_path => '根路径';
	@override String get msg_disabled => '未启用';
	@override String get msg_improved_2 => '优化：';
	@override String get msg_city => '市';
	@override String get msg_decoding_zip => '正在解压 ZIP...';
	@override String get msg_notification_content => '通知内容';
	@override String get msg_resolve_conflict => '冲突处理';
	@override String get msg_webhooks_not_supported_server => '当前服务器不支持 Webhooks';
	@override String get msg_may_delayed => '（可能延迟）';
	@override String get msg_permissions_system_settings => '权限与系统设置';
	@override String get msg_waiting_tasks_stop => '正在等待任务停止';
	@override String get msg_done_2 => '确定';
	@override String get msg_parsing_memoflow_export => '正在解析 MemoFlow 导出...';
	@override String msg_location_updated({required Object next_displayText_fractionDigits_6}) => '定位成功：${next_displayText_fractionDigits_6}';
	@override String get msg_checking_server_version => '正在检查后端版本...';
	@override String get msg_next_time_back_fixing_bugs => '👀 下次一定，先去修 Bug';
	@override String msg_ago_4({required Object weeks}) => '${weeks}周前';
	@override String get msg_import => '导入';
	@override String get msg_ios_long_press_home_screen_add => 'iOS 请长按桌面添加 MemoFlow 小组件';
	@override String get msg_create_token_2 => '创建 Token';
	@override String get msg_marked_read => '已标记为已读';
	@override String get msg_pinned => '置顶';
	@override String get msg_version_update => '版本更新';
	@override String get msg_allow_private_memos => '允许发送私有权限笔记';
	@override String get msg_token_copied_clipboard => 'Token 已复制到剪贴板';
	@override String get msg_keeping_more_versions_uses_more_storage => '增加保留数量会占用更多存储空间，建议定期清理旧版本。';
	@override String get msg_delete_webhook => '删除 Webhook';
	@override String get msg_prompt => '提示词 (Prompt)';
	@override String get msg_location_precision => '定位精度';
	@override String get msg_password_required => '需要密码';
	@override String get msg_exit_app => '退出应用';
	@override String get msg_thanks_energy_fully_restored => '收到心意！能量已充满 ⚡';
	@override String get msg_connection_timeout_check_network_api_url => '连接超时，请检查网络或 API URL';
	@override late final _StringsStringsLegacyAppLanguageZhHans app_language = _StringsStringsLegacyAppLanguageZhHans._(_root);
	@override late final _StringsStringsLegacyAppThemeZhHans app_theme = _StringsStringsLegacyAppThemeZhHans._(_root);
	@override late final _StringsStringsLegacyAppFontSizeZhHans app_font_size = _StringsStringsLegacyAppFontSizeZhHans._(_root);
	@override late final _StringsStringsLegacyAppLineHeightZhHans app_line_height = _StringsStringsLegacyAppLineHeightZhHans._(_root);
	@override late final _StringsStringsLegacyLaunchActionZhHans launch_action = _StringsStringsLegacyLaunchActionZhHans._(_root);
	@override late final _StringsStringsLegacyAutoLockTimeZhHans auto_lock_time = _StringsStringsLegacyAutoLockTimeZhHans._(_root);
	@override late final _StringsStringsLegacyReminderZhHans reminder = _StringsStringsLegacyReminderZhHans._(_root);
	@override late final _StringsStringsLegacyLocationZhHans location = _StringsStringsLegacyLocationZhHans._(_root);
	@override late final _StringsStringsLegacyWebdavZhHans webdav = _StringsStringsLegacyWebdavZhHans._(_root);
	@override String import_count_memos({required Object count}) => '${count}条';
	@override String import_count_attachments({required Object count}) => '${count}个';
	@override late final _StringsStringsLegacyAppDrawerZhHans app_drawer = _StringsStringsLegacyAppDrawerZhHans._(_root);
	@override late final _StringsStringsLegacyAiSummaryZhHans ai_summary = _StringsStringsLegacyAiSummaryZhHans._(_root);
}

// Path: strings.login.mode
class _StringsStringsLoginModeZhHans extends _StringsStringsLoginModeEn {
	_StringsStringsLoginModeZhHans._(_StringsZhHans root) : this._root = root, super._(root);

	@override final _StringsZhHans _root; // ignore: unused_field

	// Translations
	@override String get password => '账号密码';
	@override String get token => 'Token 登录';
	@override String get descPassword => '使用账号密码登录';
	@override String get descToken => '使用个人访问令牌登录';
	@override String get signInMethod => '登录方式';
}

// Path: strings.login.field
class _StringsStringsLoginFieldZhHans extends _StringsStringsLoginFieldEn {
	_StringsStringsLoginFieldZhHans._(_StringsZhHans root) : this._root = root, super._(root);

	@override final _StringsZhHans _root; // ignore: unused_field

	// Translations
	@override String get serverUrlLabel => '服务器地址';
	@override String get serverUrlHint => 'http://localhost:5230';
	@override String get usernameLabel => '账号';
	@override String get usernameHint => '请输入账号';
	@override String get passwordLabel => '密码';
	@override String get passwordHint => '请输入密码';
	@override String get tokenLabel => 'Token (PAT)';
	@override String get tokenHint => 'Token (PAT)';
}

// Path: strings.login.validation
class _StringsStringsLoginValidationZhHans extends _StringsStringsLoginValidationEn {
	_StringsStringsLoginValidationZhHans._(_StringsZhHans root) : this._root = root, super._(root);

	@override final _StringsZhHans _root; // ignore: unused_field

	// Translations
	@override String get serverUrlRequired => '请输入服务器地址';
	@override String get serverUrlInvalid => '请输入完整地址（包含 http/https 与端口）';
	@override String get usernameRequired => '请输入账号';
	@override String get passwordRequired => '请输入密码';
	@override String get tokenRequired => '请输入 Token';
}

// Path: strings.login.compatibility
class _StringsStringsLoginCompatibilityZhHans extends _StringsStringsLoginCompatibilityEn {
	_StringsStringsLoginCompatibilityZhHans._(_StringsZhHans root) : this._root = root, super._(root);

	@override final _StringsZhHans _root; // ignore: unused_field

	// Translations
	@override String get title => '兼容模式';
	@override String get description => '使用旧版接口（适配旧版 Memos）';
}

// Path: strings.login.connect
class _StringsStringsLoginConnectZhHans extends _StringsStringsLoginConnectEn {
	_StringsStringsLoginConnectZhHans._(_StringsZhHans root) : this._root = root, super._(root);

	@override final _StringsZhHans _root; // ignore: unused_field

	// Translations
	@override String get connecting => '连接中…';
	@override String get action => '连接';
}

// Path: strings.login.errors
class _StringsStringsLoginErrorsZhHans extends _StringsStringsLoginErrorsEn {
	_StringsStringsLoginErrorsZhHans._(_StringsZhHans root) : this._root = root, super._(root);

	@override final _StringsZhHans _root; // ignore: unused_field

	// Translations
	@override String get authFailedToken => '认证失败，请确认 Token 是否有效或未过期';
	@override String get authFailedPat => '认证失败。新版 Memos 请使用以 memos_pat_ 开头的 PAT（不要粘贴 Bearer 前缀）';
	@override String connectionFailedWithMessage({required Object message}) => '连接失败：${message}';
	@override String connectionFailed({required Object error}) => '连接失败：${error}';
	@override String get signInFailed => '登录失败，请检查账号和密码';
	@override String signInFailedWithMessage({required Object message}) => '登录失败：${message}';
	@override String get invalidServerUrl => '服务器地址无效';
	@override String get serverUrlNormalized => '已规范化服务器地址（移除多余路径）';
}

// Path: strings.settings.preferences
class _StringsStringsSettingsPreferencesZhHans extends _StringsStringsSettingsPreferencesEn {
	_StringsStringsSettingsPreferencesZhHans._(_StringsZhHans root) : this._root = root, super._(root);

	@override final _StringsZhHans _root; // ignore: unused_field

	// Translations
	@override String get title => '偏好设置';
	@override String get language => '语言';
	@override String get fontSize => '字号';
	@override String get lineHeight => '行高';
	@override String get font => '字体';
	@override String get systemDefault => '系统默认';
	@override String get noSystemFonts => '未找到系统字体';
	@override String loadFontsFailed({required Object error}) => '字体加载失败：${error}';
	@override String get collapseLongContent => '折叠长内容';
	@override String get collapseReferences => '折叠引用';
	@override String get showEngagementInAllMemoDetails => '在全部笔记详情中显示点赞和评论';
	@override String get launchAction => '启动动作';
	@override String get quickInputKeyboard => '快速记录时唤醒键盘';
	@override String get appearance => '外观';
	@override String get themeColor => '主题色';
	@override String get haptics => '触感反馈';
	@override String get customTheme => '自定义主题';
	@override String get history => '历史';
	@override String get lightMode => '浅色模式';
	@override String get darkMode => '深色模式';
	@override String get surfaces => '表面色';
	@override String get background => '背景';
	@override String get backgroundColor => '背景色';
	@override String get card => '卡片';
	@override String get cardColor => '卡片色';
	@override String get border => '边框';
	@override String get borderColor => '边框色';
}

// Path: strings.legacy.app_language
class _StringsStringsLegacyAppLanguageZhHans extends _StringsStringsLegacyAppLanguageEn {
	_StringsStringsLegacyAppLanguageZhHans._(_StringsZhHans root) : this._root = root, super._(root);

	@override final _StringsZhHans _root; // ignore: unused_field

	// Translations
	@override String get system => '跟随系统';
	@override String get zh_hans => '简体中文';
	@override String get zh_hant_tw => '繁体中文（中国台湾）';
	@override String get en => '英语';
	@override String get ja => '日语';
	@override String get de => '德语';
}

// Path: strings.legacy.app_theme
class _StringsStringsLegacyAppThemeZhHans extends _StringsStringsLegacyAppThemeEn {
	_StringsStringsLegacyAppThemeZhHans._(_StringsZhHans root) : this._root = root, super._(root);

	@override final _StringsZhHans _root; // ignore: unused_field

	// Translations
	@override String get system => '系统';
	@override String get light => '浅色';
	@override String get dark => '深色';
}

// Path: strings.legacy.app_font_size
class _StringsStringsLegacyAppFontSizeZhHans extends _StringsStringsLegacyAppFontSizeEn {
	_StringsStringsLegacyAppFontSizeZhHans._(_StringsZhHans root) : this._root = root, super._(root);

	@override final _StringsZhHans _root; // ignore: unused_field

	// Translations
	@override String get standard => '标准';
	@override String get large => '大';
	@override String get small => '小';
}

// Path: strings.legacy.app_line_height
class _StringsStringsLegacyAppLineHeightZhHans extends _StringsStringsLegacyAppLineHeightEn {
	_StringsStringsLegacyAppLineHeightZhHans._(_StringsZhHans root) : this._root = root, super._(root);

	@override final _StringsZhHans _root; // ignore: unused_field

	// Translations
	@override String get classic => '经典';
	@override String get compact => '紧凑';
	@override String get relaxed => '舒适';
}

// Path: strings.legacy.launch_action
class _StringsStringsLegacyLaunchActionZhHans extends _StringsStringsLegacyLaunchActionEn {
	_StringsStringsLegacyLaunchActionZhHans._(_StringsZhHans root) : this._root = root, super._(root);

	@override final _StringsZhHans _root; // ignore: unused_field

	// Translations
	@override String get none => '无';
	@override String get sync => '同步';
	@override String get quick_input => '快速记录';
	@override String get daily_review => '随机漫步';
}

// Path: strings.legacy.auto_lock_time
class _StringsStringsLegacyAutoLockTimeZhHans extends _StringsStringsLegacyAutoLockTimeEn {
	_StringsStringsLegacyAutoLockTimeZhHans._(_StringsZhHans root) : this._root = root, super._(root);

	@override final _StringsZhHans _root; // ignore: unused_field

	// Translations
	@override String get immediately => '立即';
	@override String get after_1_min => '1 分钟';
	@override String get after_5_min => '5 分钟';
	@override String get after_15_min => '15 分钟';
}

// Path: strings.legacy.reminder
class _StringsStringsLegacyReminderZhHans extends _StringsStringsLegacyReminderEn {
	_StringsStringsLegacyReminderZhHans._(_StringsZhHans root) : this._root = root, super._(root);

	@override final _StringsZhHans _root; // ignore: unused_field

	// Translations
	@override String get default_title => '嗨，你还记得这个想法吗？';
	@override String get default_body => '点击查看详情';
}

// Path: strings.legacy.location
class _StringsStringsLegacyLocationZhHans extends _StringsStringsLegacyLocationEn {
	_StringsStringsLegacyLocationZhHans._(_StringsZhHans root) : this._root = root, super._(root);

	@override final _StringsZhHans _root; // ignore: unused_field

	// Translations
	@override String get current => '当前位置';
}

// Path: strings.legacy.webdav
class _StringsStringsLegacyWebdavZhHans extends _StringsStringsLegacyWebdavEn {
	_StringsStringsLegacyWebdavZhHans._(_StringsZhHans root) : this._root = root, super._(root);

	@override final _StringsZhHans _root; // ignore: unused_field

	// Translations
	@override String get not_configured => 'WebDAV 未配置';
	@override String get backup_disabled => '备份未启用';
	@override String get backup_account_missing => '账号缺失，无法备份';
	@override String get backup_local_only => '仅本地库可用备份';
	@override String get backup_password_missing => '缺少备份密码';
	@override String get backup_no_memo_files => '本地库未发现笔记文件，备份已取消';
	@override String get restore_account_missing => '账号缺失，无法恢复';
	@override String get restore_local_only => '仅本地库可恢复备份';
	@override String get backup_empty => '备份内容为空';
	@override String get backup_no_memos => '备份中没有笔记';
	@override String get snapshot_missing => '备份快照丢失';
	@override String get snapshot_corrupted => '备份快照损坏';
	@override String get object_missing => '备份对象缺失';
	@override String get config_corrupted => '备份配置损坏';
	@override String get config_invalid => '备份配置无效';
	@override String get password_invalid => '备份密码错误';
	@override String get data_corrupted => '备份数据损坏';
	@override String get server_url_invalid => 'WebDAV 服务器地址无效';
}

// Path: strings.legacy.app_drawer
class _StringsStringsLegacyAppDrawerZhHans extends _StringsStringsLegacyAppDrawerEn {
	_StringsStringsLegacyAppDrawerZhHans._(_StringsZhHans root) : this._root = root, super._(root);

	@override final _StringsZhHans _root; // ignore: unused_field

	// Translations
	@override String tooltip_single({required Object date, required Object weekday, required Object count}) => '${date}（${weekday}）· ${count} 条';
	@override String tooltip_multi({required Object date, required Object weekday, required Object count}) => '${date}（${weekday}）· ${count} 条';
}

// Path: strings.legacy.ai_summary
class _StringsStringsLegacyAiSummaryZhHans extends _StringsStringsLegacyAiSummaryEn {
	_StringsStringsLegacyAiSummaryZhHans._(_StringsZhHans root) : this._root = root, super._(root);

	@override final _StringsZhHans _root; // ignore: unused_field

	// Translations
	@override String get error_api_key_empty => 'API Key 为空';
	@override late final _StringsStringsLegacyAiSummarySystemZhHans system = _StringsStringsLegacyAiSummarySystemZhHans._(_root);
	@override late final _StringsStringsLegacyAiSummaryUserZhHans user = _StringsStringsLegacyAiSummaryUserZhHans._(_root);
	@override String get error_invalid_response => 'AI 响应格式不正确';
	@override String get error_empty_response => 'AI 响应为空';
	@override String get error_missing_content => 'AI 响应内容缺失';
	@override String get default_prompt => '你是一位极简主义的笔记助手，擅长提炼核心观点并以优雅的格式排版。在回复时，请保持专业、温和且简洁的语气。尽量使用列表和简短的段落。';
}

// Path: strings.legacy.ai_summary.system
class _StringsStringsLegacyAiSummarySystemZhHans extends _StringsStringsLegacyAiSummarySystemEn {
	_StringsStringsLegacyAiSummarySystemZhHans._(_StringsZhHans root) : this._root = root, super._(root);

	@override final _StringsZhHans _root; // ignore: unused_field

	// Translations
	@override String get require_json => '请严格输出 JSON，不要使用代码块，不要额外说明文字。';
	@override String get json_format => 'JSON 格式：{"insights":["..."],"moodTrend":"...","keywords":["#..."]}';
	@override String get insights_rule => 'insights 控制在 2-5 条，keywords 为 4-8 个带 # 的词。';
}

// Path: strings.legacy.ai_summary.user
class _StringsStringsLegacyAiSummaryUserZhHans extends _StringsStringsLegacyAiSummaryUserEn {
	_StringsStringsLegacyAiSummaryUserZhHans._(_StringsZhHans root) : this._root = root, super._(root);

	@override final _StringsZhHans _root; // ignore: unused_field

	// Translations
	@override String range({required Object rangeLabel}) => '时间范围：${rangeLabel}';
	@override String counts({required Object memoCount, required Object includedCount}) => '笔记条数：${memoCount}（提供用于总结：${includedCount}）';
	@override String profile({required Object profile}) => '用户背景：${profile}';
	@override String custom_prompt({required Object customPrompt}) => '用户补充指令：${customPrompt}';
	@override String get memo_content => '笔记内容：';
}

// Path: <root>
class _StringsZhHantTw extends Translations {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	_StringsZhHantTw.build({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = TranslationMetadata(
		    locale: AppLocale.zhHantTw,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super.build(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		super.$meta.setFlatMapFunction($meta.getTranslation); // copy base translations to super.$meta
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <zh-Hant-TW>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key) ?? super.$meta.getTranslation(key);

	@override late final _StringsZhHantTw _root = this; // ignore: unused_field

	// Translations
	@override late final _StringsStringsZhHantTw strings = _StringsStringsZhHantTw._(_root);
}

// Path: strings
class _StringsStringsZhHantTw extends _StringsStringsEn {
	_StringsStringsZhHantTw._(_StringsZhHantTw root) : this._root = root, super._(root);

	@override final _StringsZhHantTw _root; // ignore: unused_field

	// Translations
	@override late final _StringsStringsCommonZhHantTw common = _StringsStringsCommonZhHantTw._(_root);
	@override late final _StringsStringsLanguagesZhHantTw languages = _StringsStringsLanguagesZhHantTw._(_root);
	@override late final _StringsStringsLanguagesNativeZhHantTw languagesNative = _StringsStringsLanguagesNativeZhHantTw._(_root);
	@override late final _StringsStringsOnboardingZhHantTw onboarding = _StringsStringsOnboardingZhHantTw._(_root);
	@override late final _StringsStringsLoginZhHantTw login = _StringsStringsLoginZhHantTw._(_root);
	@override late final _StringsStringsSettingsZhHantTw settings = _StringsStringsSettingsZhHantTw._(_root);
	@override late final _StringsStringsLegacyZhHantTw legacy = _StringsStringsLegacyZhHantTw._(_root);
}

// Path: strings.common
class _StringsStringsCommonZhHantTw extends _StringsStringsCommonEn {
	_StringsStringsCommonZhHantTw._(_StringsZhHantTw root) : this._root = root, super._(root);

	@override final _StringsZhHantTw _root; // ignore: unused_field

	// Translations
	@override String get back => '返回';
	@override String get cancel => '取消';
	@override String get confirm => '確認';
	@override String get save => '儲存';
	@override String get saveSettings => '儲存設定';
	@override String get auto => '自動';
	@override String get manual => '手動';
	@override String get copiedToClipboard => '已複製到剪貼簿';
	@override String get serverVersion => '伺服器版本';
	@override String get selectValidServerVersion => '請選擇有效的伺服器版本';
	@override String serverVersionValue({required Object version}) => '伺服器版本: ${version}';
	@override String get selectServerVersionRange021To026 => '請先手動選擇 0.21~0.26 伺服器版本';
}

// Path: strings.languages
class _StringsStringsLanguagesZhHantTw extends _StringsStringsLanguagesEn {
	_StringsStringsLanguagesZhHantTw._(_StringsZhHantTw root) : this._root = root, super._(root);

	@override final _StringsZhHantTw _root; // ignore: unused_field

	// Translations
	@override String get system => '跟隨系統';
	@override String get zhHans => '簡體中文';
	@override String get zhHantTw => '繁體中文（中國台灣）';
	@override String get en => '英文';
	@override String get ja => '日文';
	@override String get de => '德文';
}

// Path: strings.languagesNative
class _StringsStringsLanguagesNativeZhHantTw extends _StringsStringsLanguagesNativeEn {
	_StringsStringsLanguagesNativeZhHantTw._(_StringsZhHantTw root) : this._root = root, super._(root);

	@override final _StringsZhHantTw _root; // ignore: unused_field

	// Translations
	@override String get system => '系統';
	@override String get zhHans => '简体中文';
	@override String get zhHantTw => '繁體中文（中國台灣）';
	@override String get en => 'English';
	@override String get ja => '日本語';
	@override String get de => 'Deutsch';
}

// Path: strings.onboarding
class _StringsStringsOnboardingZhHantTw extends _StringsStringsOnboardingEn {
	_StringsStringsOnboardingZhHantTw._(_StringsZhHantTw root) : this._root = root, super._(root);

	@override final _StringsZhHantTw _root; // ignore: unused_field

	// Translations
	@override String get tagline => '簡約而強大的筆記流';
	@override String get selectLanguage => '選擇語言';
	@override String get selectMode => '選擇工作模式';
	@override String get modeHint => '您可以隨時在設定中變更此項';
	@override String get modeLocalTitle => '本機模式';
	@override String get modeLocalLabel => '本機模式';
	@override String get modeLocalDesc => '資料僅保存在手機本機，無需設定伺服器，適合重視隱私與離線使用的使用者。';
	@override String get modeServerTitle => '連線模式';
	@override String get modeServerLabel => '伺服器模式';
	@override String get modeServerDesc => '連線到你的 Memos 後端，實現多端即時同步。支援 Web、行動端等多平台無縫銜接。';
	@override String get localLibraryNameTitle => '本機庫名稱';
	@override String get localLibraryNameHint => '請輸入名稱';
	@override String get localLibraryDefaultName => '本機庫';
	@override String get getStarted => '開始使用';
}

// Path: strings.login
class _StringsStringsLoginZhHantTw extends _StringsStringsLoginEn {
	_StringsStringsLoginZhHantTw._(_StringsZhHantTw root) : this._root = root, super._(root);

	@override final _StringsZhHantTw _root; // ignore: unused_field

	// Translations
	@override String get title => '連線 Memos';
	@override late final _StringsStringsLoginModeZhHantTw mode = _StringsStringsLoginModeZhHantTw._(_root);
	@override late final _StringsStringsLoginFieldZhHantTw field = _StringsStringsLoginFieldZhHantTw._(_root);
	@override late final _StringsStringsLoginValidationZhHantTw validation = _StringsStringsLoginValidationZhHantTw._(_root);
	@override late final _StringsStringsLoginCompatibilityZhHantTw compatibility = _StringsStringsLoginCompatibilityZhHantTw._(_root);
	@override late final _StringsStringsLoginConnectZhHantTw connect = _StringsStringsLoginConnectZhHantTw._(_root);
	@override late final _StringsStringsLoginErrorsZhHantTw errors = _StringsStringsLoginErrorsZhHantTw._(_root);
}

// Path: strings.settings
class _StringsStringsSettingsZhHantTw extends _StringsStringsSettingsEn {
	_StringsStringsSettingsZhHantTw._(_StringsZhHantTw root) : this._root = root, super._(root);

	@override final _StringsZhHantTw _root; // ignore: unused_field

	// Translations
	@override late final _StringsStringsSettingsPreferencesZhHantTw preferences = _StringsStringsSettingsPreferencesZhHantTw._(_root);
}

// Path: strings.legacy
class _StringsStringsLegacyZhHantTw extends _StringsStringsLegacyEn {
	_StringsStringsLegacyZhHantTw._(_StringsZhHantTw root) : this._root = root, super._(root);

	@override final _StringsZhHantTw _root; // ignore: unused_field

	// Translations
	@override String get msg_memos_backend_docs => 'memos后端使用文档';
	@override String get msg_remember_moment_feel_warmth_life_take => '记住这一刻，感受生活的温度。\\n每天来一次随机漫步。';
	@override String get msg_sure_want_delete_shortcut => '确定要删除该快捷筛选吗？';
	@override String get msg_scan_completed => '扫描完成';
	@override String get msg_confirm => '确认';
	@override String get msg_unable_open_browser_install_browser_app => '无法打开浏览器，请检查是否安装了浏览器';
	@override String get msg_contributors => '贡献与致谢';
	@override String get msg_enter_keywords_search_box_query_local => '在搜索框输入关键词可检索本地内容与标签。离线可用；首次使用请等待本地索引完成。';
	@override String get msg_memo_not_found_locally => '本地暂无该笔记';
	@override String get msg_token => 'Token 摘要';
	@override String get msg_last_7_days => '最近一周';
	@override String get msg_search_memo_content => '搜索笔记内容';
	@override String get msg_retry_started => '已开始重试同步';
	@override String msg_last_year_memos({required Object lastYearMemos}) => '最近一年记录 ${lastYearMemos} 条笔记';
	@override String get msg_no_content_yet => '暂无内容';
	@override String get msg_no_summary_yet => '暂无总结结果';
	@override String get msg_sooner => ' 上线！';
	@override String get msg_token_copied => 'Token 已复制';
	@override String get msg_share => '分享';
	@override String get msg_gallery_permission_required => '需要相册权限以保存二维码';
	@override String get msg_basic_settings => '基础设置';
	@override String get msg_bad_ssl_certificate => '证书校验失败';
	@override String get msg_no_notifications => '暂无通知';
	@override String get msg_import_markdown => '从 Markdown 导入';
	@override String get msg_upload_zip_package_md_files => '请上传包含 .md 文件的 .zip 压缩包';
	@override String get msg_request_send_timeout_try => '请求发送超时，请稍后重试';
	@override String get msg_select_date_range => '选择时间范围';
	@override String get msg_delete_shortcut => '删除快捷筛选';
	@override String get msg_auto_lock_time => '自动锁定时间';
	@override String get msg_replacing_delete_original_attachment_continue => '替换后将删除原图片附件，是否继续？';
	@override String get msg_add_least_one_condition => '请至少设置一个条件';
	@override String get msg_upload_images_image_bed_append_links => '开启后自动将图片上传到图床，并在文末插入图片链接。';
	@override String get msg_request_cancelled => '请求已取消';
	@override String get msg_generating => '生成中…';
	@override String get msg_permissions_denied_reminders_disabled => '权限未授予，提醒未开启';
	@override String get msg_memoflow_local_reminders => 'MemoFlow 本地提醒';
	@override String get msg_use_legacy_endpoints_older_memos_servers => '使用旧版接口（适配旧版 Memos）';
	@override String get msg_no_comments_yet => '暂无评论';
	@override String get msg_open => '打开';
	@override String get msg_microphone_permission_required => '需要麦克风权限';
	@override String msg_failed_react({required Object e}) => '点赞失败：${e}';
	@override String get msg_restore_backup => '恢复备份？';
	@override String get msg_qr_saved_gallery => '二维码已保存到系统相册';
	@override String get msg_no_attachments => '暂无附件';
	@override String get msg_enable_reminder_permissions => '启用提醒权限';
	@override String get msg_created_time => '创建时间 ↑';
	@override String get msg_prompt_saved_quick_prompts => '提示词将保存在快速总结中';
	@override String get msg_remember_password => '记住密码';
	@override String get msg_enter_valid_url => '请输入有效的 URL';
	@override String get msg_may_take_few_seconds => '可能需要几秒钟';
	@override String msg_local_sync_failed({required Object type, required Object memoError}) => '本地同步失败（${type}）：${memoError}';
	@override String get msg_webdav_sync => 'WebDAV 同步';
	@override String get msg_clear => '清空';
	@override String get msg_clear_recycle_bin_confirm => '確認清空回收站？回收站內所有內容將被永久刪除。';
	@override String get msg_save_failed => '保存失败';
	@override String get msg_endpoint_not_found_version_mismatch => '接口不存在（可能是 Memos 版本不兼容）';
	@override String get msg_enable_webdav_sync => '启用 WebDAV 同步';
	@override String get msg_local_libraries => '本地库';
	@override String get msg_apply => '确定';
	@override String get msg_restore_only_available_local_libraries => '仅本地库可恢复备份';
	@override String get msg_sign => '退出登录？';
	@override String get msg_reminders_disabled => '提醒功能已关闭';
	@override String get msg_downloading => '正在下载';
	@override String get msg_path => '路径';
	@override String get msg_match_any => '满足任一条件';
	@override String get msg_local_db_pending_queue => '本地数据库 + 待同步队列';
	@override String msg_scan_failed({required Object e}) => '扫描失败：${e}';
	@override String get msg_user => '用户';
	@override String get msg_pick_future_time => '请选择未来时间';
	@override String get msg_include_pending_queue => '包含待处理队列';
	@override String get msg_enter_days => '输入天数';
	@override String get msg_times => '提醒时间';
	@override String get msg_token_returned_only_once_cannot_fetched => 'Token 仅返回一次，无法再次获取';
	@override String msg_quoted_lines({required Object quoteLines}) => '引用 ${quoteLines} 行';
	@override String get msg_use_remote => '使用远端';
	@override String get msg_enable_memo_location => '启用定位';
	@override String get msg_failed_get_location => '定位失败';
	@override String get msg_after_import_memos_sync_list_automatically => '导入完成后，您的笔记将自动同步到笔记列表。对于压缩包导入，请确保文件结构完整。';
	@override String get msg_legacy_mode => '兼容模式';
	@override String get msg_signed => '登录成功';
	@override String get msg_shortcut_includes_advanced_conditions_saving_overwrite => '该快捷筛选包含高级条件，保存将覆盖这些条件。';
	@override String get msg_no_results_found => '未找到相关内容';
	@override String msg_reply({required Object replyName}) => '回复 ${replyName}...';
	@override String get msg_copy => '复制';
	@override String get msg_enable_reminders_memos => '开启后可为笔记设置提醒时间。';
	@override String get msg_comment => '评论';
	@override String get msg_added_voice_attachment => '已添加录音附件';
	@override String get msg_customize_sidebar => '自定义侧边栏';
	@override String get msg_coffee_add_drumstick => '☕ 这就是我要的咖啡/加个鸡腿';
	@override String get msg_pin => '置顶';
	@override String get msg_enter_password_continue => '请输入密码以继续';
	@override String get msg_remove_local_library => '移除本地库？';
	@override String get msg_comment_2 => '新评论';
	@override String get msg_sync_all => '全部同步';
	@override String get msg_backup_schedule => '备份频率';
	@override String get msg_server_error => '服务器内部错误';
	@override String get msg_analyzing_memos => '正在深度分析您的笔记...';
	@override String get msg_notification => '通知';
	@override String get msg_policy => '策略设置';
	@override String msg_failed_load({required Object error}) => '加载失败: ${error}';
	@override String get msg_default_visibility => '默认可见性';
	@override String get msg_filter => '筛选';
	@override String get msg_imported_memos => '导入笔记';
	@override String get msg_token_created => 'Token 已创建';
	@override String get msg_server_response_timeout_try => '服务器响应超时，请稍后重试';
	@override String get msg_expiring => '即将过期';
	@override String get msg_delete_task => '删除任务';
	@override String get msg_body_must_json => 'Body 必须是 JSON';
	@override String get msg_enable => '去开启';
	@override String get msg_referenced => '被引用';
	@override String get msg_replace_image => '确认替换？';
	@override String get msg_debug_logs => '调试记录';
	@override String get msg_active_tasks => '正在进行的任务';
	@override String get msg_attachments => '附件';
	@override String get msg_range => '時間範圍';
	@override String get msg_no_backups_found => '暂无备份记录';
	@override String get msg_create_memo => '创建笔记';
	@override String get msg_street => '街道';
	@override String get msg_display_name => '显示名称';
	@override String get msg_full_text_search => '全文搜索';
	@override String get msg_create_edit_delete_actions_offline_stored => '离线创建/编辑/删除会先保存在本地并加入待同步队列，联网后按顺序发送。为避免误操作，未提交的编辑可保留为草稿。';
	@override String get msg_sign_2 => '退出登录';
	@override String get msg_end_time => '结束时间';
	@override String get msg_sync_recent_content => '同步最近内容';
	@override String get msg_resetting_local_data => '正在重置本地数据...';
	@override String get msg_incorrect_password => '密码错误';
	@override String get msg_content_cannot_empty => '内容不能为空';
	@override String get msg_preparing => '准备中';
	@override String msg_ai_summary_failed({required Object formatSummaryError_e}) => 'AI 总结失败：${formatSummaryError_e}';
	@override String get msg_manage => '管理';
	@override String get msg_keep_data_consistent_across_devices => '保持设备间数据一致。';
	@override String msg_playback_failed({required Object e}) => '播放失败: ${e}';
	@override String get msg_path_copied => '路径已复制';
	@override String get msg_auth_settings => '认证设置';
	@override String get msg_randomly_draw_memo_cards => '随机抽取你的卡片笔记';
	@override String get msg_copy_log_text => '复制日志文本';
	@override String get msg_yes => '是';
	@override String get msg_save_open_alipay_scan => '长按保存后打开支付宝扫一扫';
	@override String get msg_signed_but_no_token_returned => '登录成功，但未返回 Token';
	@override String msg_create_failed({required Object formatError_e_context}) => '创建失败：${formatError_e_context}';
	@override String get msg_expand => '展开';
	@override String get msg_local_library_only => '仅本地库可用';
	@override String get msg_reminder_channel => '提醒通知渠道';
	@override String get msg_grant => '去授权';
	@override String get msg_import_canceled => '已取消导入';
	@override String get msg_never => '永不过期';
	@override String get msg_release_notes => '版本公告';
	@override String get msg_failed_load_references => '加载引用失败';
	@override String get msg_select_tags => '选择标签';
	@override String get msg_failed_load_try => '加载失败，请稍后重试';
	@override String get msg_logs_copied => '记录已复制';
	@override String get msg_shortcuts_not_supported_server => '当前服务器不支持快捷筛选';
	@override String msg_reply_2({required Object name}) => '回复 ${name}...';
	@override String get msg_anonymous => '匿名';
	@override String get msg_username => '用户名';
	@override String get msg_update_memo => '更新笔记';
	@override String msg_saved({required Object targetPath}) => '已保存到: ${targetPath}';
	@override String get msg_chinese_simplified => '简体中文';
	@override String get msg_memo_copied => '已复制笔记内容';
	@override String get msg_collapse => '收起';
	@override String get msg_retry_count_controls_how_many_extra => '重试次数决定了上传失败后的最大尝试频率。设置较高的次数可以提高成功率，但可能增加等待时间。';
	@override String get msg_recording_info_missing => '录音信息缺失';
	@override String get msg_sync_task => '同步任务';
	@override String get msg_clear_all_debug_logs => '确认清空调试记录？';
	@override String get msg_export_finished => '导出完成';
	@override String msg_failed_stop_recording({required Object e}) => '停止录音失败：${e}';
	@override String get msg_my_profile => '我的资料';
	@override String get msg_image_bed => '兰空图床';
	@override String msg_failed_open_notification({required Object e}) => '打开通知失败：${e}';
	@override String get msg_manual => '手动';
	@override String get msg_no_html_file_found_zip => '压缩包内未找到 HTML 文件';
	@override String get msg_also_clear_local_cache_account_offline => '这会同时清除该账号的本地缓存（离线数据/草稿/待同步队列）。此操作无法撤销。';
	@override String get msg_restore => '恢复';
	@override String get msg_auto_backup => '自动备份';
	@override String get msg_generate_summary => '开始生成总结';
	@override String msg_days({required Object stats_activeDays}) => '${stats_activeDays} 天';
	@override String get msg_count => '- 數量';
	@override String get msg_weekly => '每周';
	@override String get msg_notifications => '通知';
	@override String get msg_backup_failed => '备份失败';
	@override String get msg_private => '仅私密';
	@override String get msg_filter_tags => '标签筛选';
	@override String get msg_clear_logs => '清空记录';
	@override String get msg_unable_open_browser => '无法打开浏览器';
	@override String get msg_attachment_too_large => '附件过大，超过服务器限制';
	@override String get msg_query => 'Query';
	@override String get msg_match_all => '满足所有条件';
	@override String get msg_record_request_response_logs => '记录请求/响应日志';
	@override String get msg_import_file => '导入文件';
	@override String get msg_content_tags => '内容 + 标签';
	@override String get msg_feature_not_available_local_library_mode => '本地库模式暂不支持该功能';
	@override String msg_import_failed({required Object e}) => '导入失败: ${e}';
	@override String get msg_save_memo => '保存为笔记';
	@override String get msg_scan_disk_directory_merge_local_database => '扫描磁盘目录并合并到本地数据库？缺失文件将视为删除。';
	@override String get msg_passwords_not_match => '两次密码不一致';
	@override String msg_signed_2({required Object lastLoginUser}) => '当前登录用户: ${lastLoginUser}';
	@override String get msg_made_love_note_taking => '为记录而生';
	@override String get msg_password_updated_local => '密码已更新（仅本地）';
	@override String get msg_retry => '重试';
	@override String get msg_memo_stats => '记录统计';
	@override String get msg_shown_only_once_copy_keep_safe => '仅显示一次，请复制并妥善保存。';
	@override String get msg_describe_issue_time_repro_steps_etc => '描述问题、时间、复现步骤等';
	@override String get msg_how_many_days_back => '过去多少天';
	@override String get msg_local_cache_cleared => '本地缓存已清除';
	@override String get msg_none => '无';
	@override String get msg_body_json => 'Body (JSON)';
	@override String msg_download_failed({required Object e}) => '下载失败: ${e}';
	@override String get msg_recycle_bin => '回收站';
	@override String get msg_unpin => '取消置顶';
	@override String get msg_advanced_security => '高级与安全';
	@override String get msg_run_issues_memoflow_e_g_sync => '如果您在使用 MemoFlow 时遇到问题（如同步失败、崩溃等），请按照以下步骤向我们反馈，这将帮助开发者快速定位并修复问题。\\n\\n';
	@override String get msg_remove_all_reminder_times_memo => '将移除该笔记的全部提醒时间。';
	@override String get msg_no_summary_save => '暂无可保存的总结';
	@override String get msg_reset_language_selection => '重置语言选择状态';
	@override String get msg_v_30_days => '30 天';
	@override String get msg_e_g_mood_check => '如：情绪分析';
	@override String get msg_note_some_tokens_returned_only_once => '提示：Token 可能只返回一次，之后无法再次获取，请妥善保存。';
	@override String get msg_syncing => '同步中...';
	@override String get msg_retention => '版本保留数量';
	@override String get msg_open_login_screen => '打开登录页面';
	@override String get msg_apply_all => '应用到全部';
	@override String get msg_write_something_supports_tag_tasks_x => '写点什么... 支持 #tag 和任务 [ ] / [x]';
	@override String msg_http({required Object base, required Object status, required Object msg}) => '${base}（HTTP ${status}）：${msg}';
	@override String get msg_single => '单次';
	@override String get msg_delete_memo => '删除 Memo？';
	@override String get msg_ai_provider => 'AI 提供方';
	@override String msg_release_notes_v({required Object version}) => '版本公告 v${version}';
	@override String get msg_info_only_used_background_ai_summaries => '这些信息仅用于 AI 总结/报告的背景，不会同步到后端。';
	@override String get msg_not_disturb => '免打扰模式';
	@override String msg_local_library_import_failed({required Object e}) => '本地库导入失败: ${e}';
	@override String get msg_key_insights => '核心洞察';
	@override String get msg_additional_notes_optional => '补充说明（可选）';
	@override String get msg_server_response_error => '服务响应异常';
	@override String get msg_sort => '排序';
	@override String get msg_api_call => 'API 调用';
	@override String get msg_webhooks => 'Webhooks';
	@override String get msg_local_library => '本地库';
	@override String get msg_log_copied => '日志已复制';
	@override String get msg_last_success => '最近成功';
	@override String get msg_restore_cloud => '从云端恢复';
	@override String get msg_search_public_memos => '搜索公开内容';
	@override String get msg_cancel => '取消生成';
	@override String msg_processing({required Object processed, required Object total}) => '正在处理 ${processed} / ${total}';
	@override String get msg_failed_items => '失败条数';
	@override String get msg_recording_file_not_found => '录音文件不存在';
	@override String get msg_local_db_outbox_queue => '本地数据库 + 待同步队列';
	@override String get msg_remove => '移除';
	@override String get msg_export_format => '导出格式';
	@override String get msg_idle => '空闲';
	@override String msg_ago({required Object months}) => '${months}個月前';
	@override String get msg_no_tags_yet => '暂无标签';
	@override String msg_version_v({required Object version}) => '版本 v${version}';
	@override String get msg_sync => '同步';
	@override String get msg_done => '完成';
	@override String get msg_gallery_permission_required_2 => '需要相册权限以保存图片';
	@override String get msg_insufficient_permissions => '权限不足';
	@override String get msg_no_download_url_available => '无法获取下载链接';
	@override String get msg_record_create_memos => '录音生成 memo';
	@override String get msg_signing => '登录中…';
	@override String get msg_memoflow_uses_system_location_permission_get => '定位将使用系统权限获取经纬度，并通过高德 Web API 反向地理解析地址，可在上方选择显示精度。';
	@override String get msg_continue => '继续';
	@override String get msg_notification_content_unavailable => '通知缺少内容';
	@override String get msg_unable_read_file_path => '无法获取文件路径';
	@override String get msg_all_memos => '全部笔记';
	@override String get msg_keywords => '關鍵詞';
	@override String get msg_import_result => '导入结果';
	@override String get msg_offline_sync => '离线同步';
	@override String get msg_imported_memos_local_library => '已从本地库导入笔记';
	@override String get msg_request_failed => '请求失败';
	@override String get msg_log_file => '日志文件';
	@override String get msg_after_confirming_support_unlock_limited_gold => '点击确认赞赏后，将解锁限定版金色标识 or 永久去广告承诺（虽然本来就没广告）';
	@override String get msg_failed_open_system_settings => '无法打开系统设置';
	@override String get msg_no_mood_trend => '暂无情绪趋势';
	@override String get msg_memoflow_export => '# MemoFlow 导出';
	@override String get msg_sync_queue => '同步队列';
	@override String get msg_only_delete_sync_task_memo_kept => '仅删除同步任务，笔记会保留。';
	@override String get msg_add_home_screen => '添加到桌面';
	@override String get msg_past_days => '过去天数';
	@override String get msg_poster_generation_failed => '海报生成失败';
	@override String msg_failed_load_stats({required Object e}) => '加载统计失败：${e}';
	@override String get msg_customize_notification => '自定义通知';
	@override String get msg_updated_time => '修改时间 ↓';
	@override String get msg_network_connection_failed_check_network => '网络连接失败，请检查网络';
	@override String get msg_special_thanks => '本次更新特別鳴謝：';
	@override String msg_failed_comment({required Object e}) => '评论失败：${e}';
	@override String get msg_security_key_sig => '安全密钥（sig）';
	@override String get msg_save_gallery => '保存到相册';
	@override String get msg_request_sent_confirm_system_prompt => '已发送请求，请在系统提示中确认';
	@override String get msg_server_url => '服务器地址';
	@override String get msg_period_review => '阶段回顾';
	@override String get msg_settings_updated => '已更新设置';
	@override String get msg_backend_0_21_not_supported_import => '检测到 0.21 版本，暂不支持导入，请升级后端后再试';
	@override String msg_failed_load_tags({required Object e}) => '加载标签失败：${e}';
	@override String get msg_enter_email => '请输入邮箱';
	@override String get msg_add_webhook => '新增 Webhook';
	@override String get msg_read => '已读';
	@override String get msg_widgets => '小组件';
	@override String get msg_default => '默认';
	@override String get msg_memo_reminders => '笔记提醒';
	@override String get msg_import_flomo => '从 Flomo 导入';
	@override String get msg_format_fixed_markdown_zip => '格式固定为 Markdown + ZIP';
	@override String get msg_enter_username_password => '请输入账号和密码';
	@override String get msg_loading => '加载中...';
	@override String msg_test_scheduled({required Object timeLabel, required Object suffix, required Object pendingLabel}) => '已安排测试提醒：${timeLabel}${suffix}${pendingLabel}';
	@override String get msg_edit_memo => '编辑 Memo';
	@override String get msg_save => '保存';
	@override String get msg_laboratory => '实验室';
	@override String get msg_use_local => '使用本地';
	@override String get msg_retry_sync => '重试同步';
	@override String get msg_e_g_my_role_topics_interest => '例如：我的角色 / 兴趣主题 / 写作风格偏好';
	@override String get msg_confirm_password => '确认密码';
	@override String get msg_not_set => '未设置';
	@override String get msg_no_memos_day => '当天无记录';
	@override String get msg_shortcut_name => '输入名称';
	@override String get msg_edit_shortcut => '编辑快捷筛选';
	@override String get msg_days_memos => '坚持记录天数';
	@override String get msg_delete => '删除';
	@override String get msg_test_reminder => '测试提醒';
	@override String get msg_enable_reminders => '开启提醒';
	@override String get msg_links => '双链';
	@override String get msg_location => '定位设置';
	@override String get msg_import_file_2 => '从文件导入';
	@override String msg_reply_3({required Object creatorDisplayName_commentCreator_commentMemo_creator}) => '回复 ${creatorDisplayName_commentCreator_commentMemo_creator}...';
	@override String msg_created({required Object widget_createdAtLabel}) => '创建于 ${widget_createdAtLabel}';
	@override String get msg_notifications_coming_soon => '通知功能即将上线';
	@override String get msg_view_full_contributors => '查看完整致谢名单';
	@override String get msg_no_times_set => '尚未设置提醒时间';
	@override String get msg_ignore_tls_errors => '忽略证书校验';
	@override String get msg_no_content => '无内容';
	@override String get msg_about_15_seconds_left => '预计还需 15 秒';
	@override String get msg_view_imported_memos => '查看导入笔记';
	@override String get msg_load_failed => '加载失败';
	@override String get msg_disk_content_conflicts_local_pending_changes => '磁盘与本地未同步内容冲突。选择“以磁盘为准”将覆盖本地内容。';
	@override String get msg_all_history_so_far_memoflow_since => '以上是全部历史内容\\nMEMOFLOW SINCE 2023';
	@override String get msg_cancelling => '取消中';
	@override String get msg_reading_file => '正在读取文件...';
	@override String get msg_switch_workspace => '切换工作区';
	@override String get msg_optional_leave_empty_default => '选填，使用默认存储策略时请留空';
	@override String get msg_memo_reminders_2 => '笔记提醒';
	@override String msg_save_failed_2({required Object e}) => '保存失败: ${e}';
	@override String get msg_record_create_memos_sync_later => '录音生成 memo（可稍后同步）';
	@override String get msg_use_https_avoid_ignoring_tls_errors => '为了安全，建议使用 HTTPS，且避免忽略证书校验。';
	@override String get msg_failed_load_announcement_config => '未获取到公告配置';
	@override String get msg_shortcuts => '快捷筛选';
	@override String get msg_memo => '笔记';
	@override String get msg_maybe_later => '稍后再说';
	@override String get msg_server_connection => '服务器连接';
	@override String get msg_days_2 => '天';
	@override String get msg_include_archived => '包含归档';
	@override String get msg_during_quiet_hours_reminders_silenced => '在免打扰期间，应用将保持静默，不会弹出任何提醒。';
	@override String get msg_preview_not_supported_type => '暂不支持该类型预览';
	@override String get msg_failed_load_2 => '加载失败';
	@override String get msg_create_token => '创建新 Token';
	@override String get msg_enter_name => '请输入筛选名称';
	@override String get msg_api_url_incorrect => 'API URL 不正确';
	@override String get msg_user_general_settings => '用户通用设置';
	@override String get msg_saved_memo => '已保存为笔记';
	@override String msg_restore_failed({required Object e}) => '恢复失败：${e}';
	@override String msg_token_tail({required Object tail}) => 'Token 尾号 ${tail}';
	@override String get msg_manual_token => '手动 Token';
	@override String msg_ago_2({required Object years}) => '${years}年前';
	@override String get msg_recent_searches => '最近搜索';
	@override String get msg_restored => '已恢复';
	@override String get msg_no_contributors_yet => '暂无致谢名单';
	@override String get msg_no_record_yet => '暂无记录';
	@override String get msg_reminder => '提醒';
	@override String get msg_enter_api_key_ai_settings => '请先在 AI 设置中填写 API Key';
	@override String get msg_reminder_settings => '提醒设置';
	@override String msg_http_2({required Object base, required Object status}) => '${base}（HTTP ${status}）';
	@override String get msg_edit_webhook => '编辑 Webhook';
	@override String get msg_generate_share_poster => '生成分享海报';
	@override String msg_archive_failed({required Object e}) => '归档失败：${e}';
	@override String msg_comments({required Object widget_commentCount}) => '${widget_commentCount} æ¢è©è«';
	@override String get msg_remove_account => '移除账号？';
	@override String get msg_chinese_traditional => '繁體中文';
	@override String get msg_private_2 => '私密';
	@override String get msg_current_streak => '当前连击';
	@override String get msg_generated_ai_memoflow => '由 AI 生成 · MemoFlow';
	@override String get msg_edit_completed => '编辑完成';
	@override String get msg_local => '本地调试';
	@override String get msg_edit => '编辑';
	@override String msg_text({required Object shortUserName_item_sender}) => '来自 ${shortUserName_item_sender}';
	@override String get msg_got => '知道了';
	@override String get msg_web_api_key => 'Web API Key';
	@override String get msg_preview => '预览';
	@override String get msg_enter_password => '请输入密码';
	@override String get msg_api => '接口';
	@override String get msg_ok => '确定';
	@override String get msg_failed_load_shortcuts => '快捷筛选加载失败';
	@override String get msg_after_recording_audio_added_current_draft => '录音完成后会将音频作为附件加入当前草稿，便于继续编辑后再发送。最长 60 分钟；可后续通过第三方服务转写。';
	@override String get msg_pull_refresh => '下拉刷新';
	@override String get msg_unable_open_photo => '无法打开照片';
	@override String get msg_existing_tokens => '已有 Token';
	@override String get msg_ai_settings => 'AI 设置';
	@override String get msg_app_lock => '应用锁';
	@override String get msg_total_notes => '总记录';
	@override String get msg_stats_loading => '统计数据加载中...';
	@override String get msg_enter_token_description => '请输入 Token 描述';
	@override String get msg_enter_token => '请输入 Token';
	@override String get msg_api_plugins => 'API 与插件';
	@override String get msg_parsing_file => '正在解析文件...';
	@override String get msg_english => '英语';
	@override String get msg_activity_heatmap => '记录热力图';
	@override String get msg_mark_read => '标记已读';
	@override String get msg_request => '申请';
	@override String msg_sync_failed({required Object type, required Object memoError}) => '同步失败（${type}）：${memoError}';
	@override String get msg_error_copied => '已复制错误信息';
	@override String get msg_only_local_index_removed_disk_files => '仅移除本地索引，磁盘文件保留。此操作无法撤销。';
	@override String get msg_switch_account => '切换账号';
	@override String get msg_invalid_download_link => '无效的更新链接';
	@override String get msg_about => '关于';
	@override String get msg_icon => '图标选择';
	@override String get msg_reset_done_syncing => '已重置，开始重新同步';
	@override String get msg_enter_amap_web_api_key => '请输入高德 Web API Key';
	@override String get msg_recycle_bin_coming_soon => '回收站功能暂未开放';
	@override String get msg_empty_content => '（空内容）';
	@override String get msg_note_most_features_offline_stats_ai => '提示：大部分功能（离线/统计/AI 总结/导出）无需后端改动，但 Token 只返回一次，请妥善保存。';
	@override String get msg_fixed => '修复：';
	@override String get msg_allow_sharing_links_images_other_apps => '允许从其他应用分享链接或图片到 MemoFlow。';
	@override String get msg_invalid_request_parameters => '请求参数错误';
	@override String get msg_enter_api_url => '请输入 API URL';
	@override String msg_pending({required Object result_pendingCount}) => '（待发送 ${result_pendingCount}）';
	@override String msg_days_3({required Object currentStreak}) => '${currentStreak} 天';
	@override String get msg_poster_not_ready_yet => '暂时无法生成海报';
	@override String get msg_generated_memoflow => '由 MemoFlow 生成';
	@override String get msg_enter_name_2 => '请输入名称';
	@override String get msg_version => '版本';
	@override String get msg_memo_missing_disk_but_has_local => '磁盘缺失该笔记，但本地还有未同步改动。选择“以磁盘为准”将删除本地记录。';
	@override String get msg_legacy_api_compatibility => '旧版 API 兼容';
	@override String get msg_sync_parameters => '同步参数';
	@override String get msg_quick_prompts => '快速提示词';
	@override String msg_share_failed({required Object e}) => '分享失败：${e}';
	@override String get msg_no_memos_summarize_range => '该时间范围内没有可总结的笔记';
	@override String get msg_characters => '字数';
	@override String get msg_capture_every_moment_record => '记录每一个瞬间';
	@override String get msg_vibration => '震动';
	@override String get msg_days_4 => '天';
	@override String get msg_prompt_title => '提示词标题';
	@override String get msg_show_all => '展开';
	@override String get msg_no_memos_available => '暂无可关联的笔记';
	@override String get msg_comment_unavailable => '评论内容不可用';
	@override String get msg_refresh => '刷新';
	@override String get msg_syncing_2 => '同步中';
	@override String get msg_body => '通知正文';
	@override String get msg_clear_2 => '清除';
	@override String get msg_third_party_share => '第三方分享';
	@override String get msg_charging_station => '充电站';
	@override String get msg_attachments_2 => '附件资源';
	@override String get msg_when_enabled_must_verify_each_app => '开启后每次进入应用需要验证。自动锁定时间决定应用进入后台后多久需要再次验证。';
	@override String get msg_add_prompt => '添加提示词';
	@override String get msg_include => '包含';
	@override String get msg_created_time_2 => '创建时间 ↓';
	@override String get msg_choose_data_source_start_importing_memos => '选择一个数据来源开始导入您的笔记';
	@override String get msg_describe_how_want_summary => '请分析我本周笔记中体现的情绪波动曲线…';
	@override String get msg_keep_token_safe_not_share_api => '请妥善保存 Token，不要泄露。\\nAPI 访问频率限制为每分钟 60 次。';
	@override String get msg_open_2 => '去开启';
	@override String get msg_e_g_claude_3_5_sonnet => '例如 claude-3-5-sonnet-20241022';
	@override String get msg_failed_request_whitelist => '无法申请电池白名单';
	@override String get msg_notification_deleted => '通知已删除';
	@override String get msg_accounts => '账号';
	@override String get msg_add_local_library => '添加本地库';
	@override String get msg_sign_first => '请先登录';
	@override String get msg_failed_parse_query => 'Query 解析失败';
	@override String get msg_note_logs_sanitized_automatically_sensitive_data => '提示：日志已自动去除敏感信息，如仍包含敏感数据，请提交前自行处理。';
	@override String get msg_add => '新增';
	@override String msg_failed_load_3({required Object memosError}) => '加载失败：${memosError}';
	@override String get msg_max_chars_day => '单日最多字数';
	@override String get msg_choose_what_edited_image => '请选择要执行的操作';
	@override String get msg_select => '请选择';
	@override String get msg_unnamed_token => '(未命名 Token)';
	@override String get msg_name => '筛选名称';
	@override String get msg_sure_want_delete_webhook => '确定要删除该 Webhook 吗？';
	@override String get msg_back => '返回';
	@override String get msg_no => '否';
	@override String get msg_untitled => '未命名';
	@override String get msg_open_language_onboarding => '打开语言首次设置';
	@override String get msg_voice_memos => '语音备忘';
	@override String get msg_unable_open_browser_try => '无法打开浏览器，请稍后重试';
	@override String get msg_date_range => '时间范围';
	@override String get msg_not_authenticated => '未登录';
	@override String get msg_back_2 => 'Back';
	@override String get msg_local_library_removed => '本地库已移除';
	@override String get msg_exact_alarm_permission_required => '需要闹钟与提醒权限';
	@override String get msg_visibility => '可见性';
	@override String msg_failed_start_recording({required Object e}) => '启动录音失败：${e}';
	@override String get msg_mood_trend => '情緒趨勢';
	@override String get msg_local_library_name => '本地库名称';
	@override String get msg_no_tokens_yet => '暂无 Token';
	@override String get msg_loading_2 => '加载中…';
	@override String get msg_location_permission_denied_permanently => '定位权限被永久拒绝';
	@override String get msg_download => '下载';
	@override String get msg_export_time => '- 匯出時間';
	@override String get msg_enter_password_2 => '请输入密码';
	@override String get msg_no_image_available => '没有可显示的图片';
	@override String get msg_daily => '每天';
	@override String get msg_no_likes_yet => '暂无点赞';
	@override String get msg_basics => '基础配置';
	@override String get msg_shortcut => '新建快捷筛选';
	@override String get msg_debug_tools => '调试工具';
	@override String get msg_save_settings => '保存设置';
	@override String get msg_date_range_2 => '日期范围';
	@override String get msg_feedback => '反馈';
	@override String get msg_image_bed_2 => '图床';
	@override String get msg_restoring => '恢复中…';
	@override String get msg_export => '导出';
	@override String get msg_enter_token_name => '请输入 Token 名称';
	@override String get msg_start_time => '开始时间';
	@override String get msg_preparing_file_structure => '正在准备文件结构';
	@override String get msg_sign_3 => '登录';
	@override String get msg_scan_local_library => '扫描本地库';
	@override String get msg_lsky_pro => '兰空图床 (Lsky Pro)';
	@override String get msg_exact_alarm_permission_off_reminders_may => '未开启闹钟与提醒权限，定时提醒可能无法触发。是否前往开启？';
	@override String get msg_last_30_days => '最近一月';
	@override String get msg_match => '匹配方式';
	@override String get msg_auth_mode => '认证方式';
	@override String get msg_unsupported_file_type => '不支持的文件格式';
	@override String get msg_only_delete_sync_task => '仅删除同步任务。';
	@override String get msg_change_password => '修改密码';
	@override String get msg_saved_2 => '已保存';
	@override String get msg_import_export => '导入 / 导出';
	@override String get msg_created_2 => '创建时间';
	@override String get msg_ai_summary => 'AI 总结';
	@override String get msg_progress => '完成進度';
	@override String get msg_replace_memo_image => '替换笔记图片';
	@override String get msg_app_settings => '应用设置';
	@override String get msg_copy_path => '复制路径';
	@override String get msg_components => '功能组件';
	@override String get msg_no_shortcuts => '暂无快捷筛选';
	@override String get msg_location_timed_try => '定位超时，请重试';
	@override String get msg_attach_location_info_memos_show_subtle => '为笔记记录定位信息，并展示简洁地名。';
	@override String msg_send_failed({required Object e}) => '发送失败：${e}';
	@override String get msg_repeat => '重复';
	@override String get msg_not_signed => '未登录';
	@override String get msg_no_webhooks_configured => '暂无 Webhooks';
	@override String get msg_apply_token => '应用 Token';
	@override String get msg_enable_reminder_permissions_2 => '开启提醒权限';
	@override String get msg_enter_backup_password => '请输入备份密码';
	@override String get msg_start_backup => '开始备份';
	@override String get msg_last_sync => '上次同步';
	@override String get msg_note_export_includes_content_already_synced => '提示：导出包含已同步到本地数据库的内容（含离线数据）。';
	@override String get msg_enter_username => '请输入用户名';
	@override String get msg_settings_saved => '设置已保存';
	@override String get msg_no_keywords => '暂无关键词';
	@override String get msg_these_settings_apply_newly_created_memos => '此设置将应用于新建的 Memo。';
	@override String get msg_back_home => '返回主页';
	@override String get msg_quiet_hours => '休息时间';
	@override String get msg_add_account => '添加账号';
	@override String get msg_reset_complete => '已重置';
	@override String get msg_no_shortcuts_configured => '暂无快捷筛选';
	@override String get msg_password => '密码';
	@override String get msg_importing => '导入中';
	@override String msg_visibility_2({required Object visibilityLabel}) => '可见性：${visibilityLabel}';
	@override String get msg_no_logs_yet => '暂无记录';
	@override String get msg_v_9_times_allowed => '最多设置 9 个提醒时间';
	@override String get msg_last_14_days => '最近 14 天';
	@override String get msg_location_disabled_enable_settings_first => '定位未启用，请先在设置中开启。';
	@override String get msg_add_2 => '添加';
	@override String get msg_logs => '日志';
	@override String get msg_references => '引用了';
	@override String get msg_importing_memos => '正在导入笔记...';
	@override String get msg_account_security => '账号与安全';
	@override String get msg_reminder_2 => '提醒设置';
	@override String get msg_enable_scheduled_reminder_notifications => '开启后将按计划发送笔记提醒通知。';
	@override String get msg_no_links => '暂无双链';
	@override String get msg_delete_memo_2 => '删除笔记';
	@override String get msg_one_tap_add_not_supported_add => '不支持一键添加，请从小组件列表添加';
	@override String get msg_password_2 => '新密码';
	@override String get msg_processing_content => '正在处理内容...';
	@override String get msg_status => '状态';
	@override String get msg_local_library_added => '本地库已添加';
	@override String get msg_failed_open_try => '打开失败，请稍后重试';
	@override String get msg_removed_locally_now_deleted_server_when => '本地会立即移除，联网后将同步删除服务器内容。';
	@override String get msg_server_url_unavailable => '未找到服务器地址';
	@override String get msg_no_release_notes_yet => '暂无更新日志';
	@override String get msg_cancelling_2 => '正在取消...';
	@override String get msg_summaries_selected_range => '支持按时间范围总结';
	@override String get msg_expand_2 => '展开更多';
	@override String get msg_close => '关闭';
	@override String msg_more_comments({required Object remainingComments}) => '还有 ${remainingComments} 条评论';
	@override String get msg_backing => '备份中…';
	@override String get msg_view_debug_logs => '查看调试记录';
	@override String get msg_location_permission_denied => '定位权限被拒绝';
	@override String get msg_self_repair_reset_heatmap => '自助修复：重置热力图';
	@override String get msg_these_settings_changed_locally_remotely_choose => '以下设置在本地和远端都有修改，请选择保留哪个版本。';
	@override String get msg_not_authenticated_2 => '未登录账号';
	@override String msg_action_failed({required Object e}) => '操作失败：${e}';
	@override String get msg_shortcut_2 => '新建快捷筛选';
	@override String get msg_url => 'URL';
	@override String get msg_no_memos_found_html => 'HTML 内未找到可导入的内容';
	@override String get msg_enter_what_want_summarize => '输入你想总结的内容或指令...';
	@override String get msg_unable_load_audio_source => '无法读取音频资源';
	@override String get msg_strategy_id => '策略 ID';
	@override String msg_copy_failed({required Object e}) => '复制失败：${e}';
	@override String get msg_enable_image_bed => '启用图床';
	@override String get msg_active => '有效';
	@override String get msg_account => '账号';
	@override String get msg_invalid_webdav_server_url => 'WebDAV 服务器地址无效';
	@override String get msg_keep_local => '以本地为准';
	@override String get msg_within_range => '在时间范围内';
	@override String get msg_generate_log_file => '生成日志文件';
	@override String get msg_ai_reports => 'AI 总结';
	@override String get msg_battery_optimization => '电池优化';
	@override String get msg_sync_overview => '同步概览';
	@override String get msg_legacy_servers_not_support_search_filters => '旧版本服务器不支持搜索过滤，结果可能不完整。';
	@override String get msg_conflicts_detected_run_manual_sync => '存在冲突，需要手动同步';
	@override String get msg_authentication_failed_check_token => '认证失败，请检查 Token';
	@override String get msg_date_range_3 => '时间范围';
	@override String get msg_help_ai_understand_better => '帮助 AI 更了解你';
	@override String get msg_no_search_history => '暂无搜索记录';
	@override String get msg_enter_api_path => '请输入接口路径';
	@override String get msg_stats => '统计';
	@override String get msg_text_2 => '新增：';
	@override String get msg_removing_signing_clear_local_cache_account => '移除/退出将清除该账号的本地缓存（离线数据/草稿/待同步队列）。';
	@override String get msg_updated_time_2 => '修改时间 ↑';
	@override String get msg_province => '省';
	@override String get msg_submitting_sync_queue => '正在提交同步队列';
	@override String get msg_failed => '失败';
	@override String get msg_set_time => '设置时间';
	@override String get msg_enable_local_library_backup => '启用本地库备份';
	@override String get msg_cancel_2 => '取消';
	@override String get msg_week => '本周回顾';
	@override String get msg_like => '赞';
	@override String get msg_location_services_disabled => '定位服务未开启';
	@override String get msg_clears_local_cache_offline_memos_pending => '这会清空本地缓存（离线笔记/待同步队列）并重新全量同步。未同步内容会丢失，可能需要一些时间。是否继续？';
	@override String get msg_load_more => '加载更多';
	@override String get msg_pull_memo_list_refresh_sync_sync => '在笔记列表下拉即可刷新并同步。同步会优先拉取最新内容；建议定期全量同步以保持统计/热力图完整。';
	@override String msg_server_returned_error({required Object code}) => '服务返回错误（${code}）';
	@override String get msg_sound_feedback => '声音与反馈';
	@override String msg_memos_skipped_attachments_skipped({required Object exportedMemoCount, required Object skippedMemoCount, required Object exportedAttachmentCount, required Object skippedAttachmentCount}) => '笔记 ${exportedMemoCount} 条（跳过 ${skippedMemoCount} 条），附件 ${exportedAttachmentCount} 个（跳过 ${skippedAttachmentCount} 个）';
	@override String get msg_import_complete => '导入完成';
	@override String get msg_text_3 => '新增';
	@override String get msg_max_per_day => '单日最多条数';
	@override String get msg_permissions_denied => '权限未授予';
	@override String get msg_memo_2 => '新建 Memo';
	@override String get msg_delete_reminder => '删除提醒';
	@override String get msg_select_month => '选择月份';
	@override String get msg_select_backup => '选择备份';
	@override String get msg_no_keywords_2 => '#暂无关键词';
	@override String get msg_preparing_memo_content => '正在准备笔记内容';
	@override String get msg_prompt_content => '具体指令内容';
	@override String get msg_default_prompt_ai_summaries_reports => '用于 AI 总结/报告的默认提示词';
	@override String get msg_intro => '引言';
	@override String get msg_monthly_stats => '每月统计';
	@override String get msg_times_2 => '次';
	@override String get msg_file_has_already_been_imported_skipped => '该文件已导入过，已跳过';
	@override String get msg_token_tail_unknown => 'Token 尾号未知';
	@override String get msg_press_back_exit => '再按一次返回退出';
	@override String get msg_enter_password_3 => '输入密码';
	@override String get msg_sync_conflicts => '同步冲突';
	@override String get msg_locale => '语言';
	@override String get msg_any => '包含任一';
	@override String get msg_provider => '服务商';
	@override String get msg_preview_2 => '预览效果';
	@override String get msg_automatically_upload_images_append_links_memo => '开启后自动上传图片并在正文末尾插入链接。';
	@override String get msg_import_file_not_found => '找不到导入文件';
	@override String get msg_today => '今天';
	@override String get msg_link_card => '关联卡片';
	@override String get msg_expiration => '有效期';
	@override String get msg_summary_prompt_optional => '总结指令 (可选)';
	@override String get msg_memos => '笔记';
	@override String get msg_recording_file_not_found_2 => '录音文件不存在';
	@override String get msg_backup_settings => '备份设置';
	@override String get msg_mode => '提醒模式';
	@override String get msg_no_markdown_memos_found_zip => '压缩包内未找到 Markdown 笔记';
	@override String get msg_archived => '已归档';
	@override String msg_update_failed({required Object e}) => '更新失败：${e}';
	@override String get msg_enable_app_lock => '启用应用锁';
	@override String get msg_html_zip => 'HTML / ZIP';
	@override String get msg_all => '包含全部';
	@override String get msg_model => '模型';
	@override String get msg_title => '通知标题';
	@override String get msg_amap_web_api => '高德 Web API';
	@override String get msg_saved_gallery => '已保存到相册';
	@override String get msg_unread => '未读';
	@override String get msg_exporting => '正在导出...';
	@override String get msg_network_timeout_try => '网络超时，请稍后重试';
	@override String get msg_unlock => '解锁';
	@override String msg_ago_3({required Object diff_inDays}) => '${diff_inDays}天前';
	@override String get msg_deserve_coffee_i_m_pulling_all => '为了对得起这杯咖啡，今晚我决定不睡了，写它个一百行代码！';
	@override String get msg_token_name => 'Token 名称';
	@override String get msg_restore_completed => '恢复完成';
	@override String get msg_copied_clipboard => '已复制到剪贴板';
	@override String msg_failed_2({required Object attempts}) => '失敗 ${attempts}次';
	@override String get msg_too_many_requests_try_later => '请求过于频繁，请稍后重试';
	@override String get msg_more => '更多';
	@override String get msg_already_whitelisted => '已在电池白名单';
	@override String get msg_local_library_backup => '本地库备份';
	@override String get msg_awesome => '太棒啦！ ❤️';
	@override String get msg_now => '现在';
	@override String get msg_select_reminder_time => '请设置提醒时间';
	@override String get msg_protected => '受保护';
	@override String msg_failed_load_4({required Object e}) => '加载失败：${e}';
	@override String msg_operation_failed({required Object e}) => '操作失败：${e}';
	@override String get msg_no_tags => '暂无标签';
	@override String get msg_server => '服务器';
	@override String get msg_improved => '优化';
	@override String get msg_request_2 => '请求';
	@override String msg_export_failed({required Object e}) => '导出失败：${e}';
	@override String get msg_notification_settings => '通知设置';
	@override String get msg_related_memo_was_deleted => '通知对应的内容已被删除';
	@override String get msg_email => '邮箱';
	@override String get msg_enter_password_4 => '请输入密码';
	@override String get msg_retry_count => '失败重试次数';
	@override String get msg_import_exported_html_zip_package => '导入导出的 HTML 或压缩包';
	@override String get msg_archive => '归档';
	@override String get msg_reset_heatmap => '重置热力图？';
	@override String get msg_token_applied => 'Token 已应用';
	@override String get msg_log_file_created => '日志文件已生成';
	@override String get msg_delete_sync_task => '删除同步任务';
	@override String get msg_include_archived_2 => '- 包含歸檔';
	@override String get msg_memoflow_side_project_i_build_my => 'MemoFlow 是我用业余时间肝出来的孩子。目前开发者已连续熬夜修 Bug，急需一杯冰美式“续命”。你的投喂不仅能恢复我的电量，还能让新功能提早 ';
	@override String msg_failed_generate({required Object e}) => '生成失败：${e}';
	@override String get msg_search_logs => '搜索内容';
	@override String get msg_active_days => '累计天数';
	@override String get msg_back_top => '回到顶部';
	@override String get msg_month => '本月回顾';
	@override String get msg_loading_references => '正在加载引用';
	@override String get msg_silent => '静音';
	@override String get msg_settings => '设置';
	@override String get msg_locating => '正在定位…';
	@override String get msg_scan => '扫描';
	@override String get msg_recording_path_missing => '录音路径缺失';
	@override String get msg_date_range_4 => '- 時間範圍';
	@override String get msg_suggested_tags => '推荐标签';
	@override String get msg_energy_restored => '⚡ ENERGY RESTORED';
	@override String get msg_username_2 => '账号';
	@override String get msg_ai_summary_report => 'AI 总结报告';
	@override String get msg_all_tags => '全部标签';
	@override String get msg_preferences => '偏好设置';
	@override String get msg_image_bed_3 => '图床设置';
	@override String get msg_quick_input => '快速输入';
	@override String get msg_tags => '标签';
	@override String get msg_energy_critically_low => '能量值告急！';
	@override String msg_delete_failed({required Object e}) => '删除失败：${e}';
	@override String get msg_server_login => '服务端登录';
	@override String get msg_like_2 => '点赞';
	@override String get msg_save_2 => '确定';
	@override String get msg_unknown => '未知用户';
	@override String get msg_release_notes_2 => '更新日志';
	@override String get msg_include_error_details => '包含错误详情';
	@override String get msg_write_comment => '写下评论...';
	@override String get msg_write_thoughts => '写下你的想法...';
	@override String get msg_local_2 => '本地';
	@override String get msg_expired => '已过期';
	@override String get msg_fixed_2 => '修复';
	@override String get msg_upload_attachment => '上传附件';
	@override String get msg_battery_whitelist => '电池白名单';
	@override String get msg_district => '区';
	@override String get msg_voice_memo => '🎙️ 语音记录\\n';
	@override String get msg_system_default => '系统默认';
	@override String get msg_all_memos_2 => '全部笔记';
	@override String get msg_network_request_failed => '网络请求失败';
	@override String get msg_memo_not_found => '笔记不存在';
	@override String msg_playback_failed_2({required Object e}) => '播放失败：${e}';
	@override String get msg_sync_settings_webdav_across_devices => '将设置同步到 WebDAV，在设备之间保持一致。';
	@override String get msg_offline_first_client_memos_backend => '一个基于 Memos 后端的离线优先客户端。';
	@override String get msg_user_guide => '使用指南';
	@override String get msg_notice => '通知';
	@override String get msg_exact_alarms => '闹钟与提醒';
	@override String get msg_restoring_overwrite_local_library_files_rebuild => '恢复会覆盖本地库文件，并重新导入数据库。此操作无法撤销。';
	@override String get msg_enter_api_url_ai_settings => '请先在 AI 设置中填写 API URL';
	@override String msg_create_failed_2({required Object e}) => '创建失败：${e}';
	@override String get msg_close_search => '关闭搜索';
	@override String get msg_imported_memos_2 => '查看导入笔记';
	@override String get msg_explore => '探索';
	@override String get msg_network_connection_failed => '网络连接失败，请检查网络';
	@override String msg_save_failed_3({required Object e}) => '保存失败：${e}';
	@override String get msg_no_summary_share => '暂无可分享的总结';
	@override String get msg_custom_model => '自定义模型';
	@override String msg_sign_failed({required Object message}) => '登录失败: ${message}';
	@override String get msg_notification_exact_alarm_permissions_required_send => '需要通知权限与精确闹钟权限，才能在指定时间发送提醒。';
	@override String get msg_random_review => '随机漫步';
	@override String get msg_public => '公开';
	@override String get msg_all_2 => '全部';
	@override String get msg_add_custom_model => '添加自定义模型';
	@override String get msg_backup_password => '备份密码';
	@override String get msg_optional_used_sign_requests => '选填，用于签名请求';
	@override String get msg_search => '搜索';
	@override String get msg_set_password => '设置密码';
	@override String get msg_submit_logs => '提交日志';
	@override String get msg_activity_heatmap_2 => '记录热力图';
	@override String get msg_invalid_api_key_insufficient_permissions => 'API Key 无效或无权限';
	@override String get msg_data_has_been_migrated_app_successfully => '您的数据已成功迁移至本应用。';
	@override String get msg_get_version => '立即获取新版本';
	@override String get msg_token_source => 'Token 来源';
	@override String get msg_send => '发送';
	@override String get msg_no_pending_sync_tasks => '暂无待同步任务';
	@override String get msg_locating_memo_content => '正在定位笔记内容';
	@override String get msg_offline_ready => '离线可用';
	@override String get msg_use_relative_path => '请使用相对路径';
	@override String get msg_total => '总记录';
	@override String get msg_location_2 => '定位';
	@override String get msg_show_location_metadata_memos_not_configured => '在笔记中显示定位信息，未配置密钥时将仅显示经纬度。';
	@override String get msg_api_url => 'API 地址';
	@override String get msg_parsing_progress => '解析进度';
	@override String get msg_parsing => '解析中';
	@override String get msg_custom => '自定义';
	@override String get msg_tags_created => '新生成的标签';
	@override String get msg_third_party_share_disabled => '第三方分享未开启';
	@override String get msg_loading_links => '双链加载中';
	@override String get msg_how_report => '如何反馈？';
	@override String get msg_confirm_password_2 => '再次输入确认';
	@override String get msg_search_title_content_tags => '您可以搜索标题、内容或标签';
	@override String msg_reset_failed({required Object e}) => '重置失败：${e}';
	@override String get msg_debug_preview_update_dialog => '调试：预览更新公告';
	@override String get msg_what_s => '写点什么…';
	@override String get msg_ringtone => '提醒铃声';
	@override String get msg_unable_detect_backend_version_check_server => '无法识别后端版本，请检查地址或网络';
	@override String get msg_pending_2 => '待同步';
	@override String get msg_parsing_html => '正在解析 HTML...';
	@override String get msg_actions => '操作';
	@override String get msg_import_complete_2 => '导入完成';
	@override String get msg_use_disk => '以磁盘为准';
	@override String get msg_root_path => '根路径';
	@override String get msg_disabled => '未启用';
	@override String get msg_improved_2 => '优化：';
	@override String get msg_city => '市';
	@override String get msg_decoding_zip => '正在解压 ZIP...';
	@override String get msg_notification_content => '通知内容';
	@override String get msg_resolve_conflict => '冲突处理';
	@override String get msg_webhooks_not_supported_server => '当前服务器不支持 Webhooks';
	@override String get msg_may_delayed => '（可能延迟）';
	@override String get msg_permissions_system_settings => '权限与系统设置';
	@override String get msg_waiting_tasks_stop => '正在等待任务停止';
	@override String get msg_done_2 => '确定';
	@override String get msg_parsing_memoflow_export => '正在解析 MemoFlow 导出...';
	@override String msg_location_updated({required Object next_displayText_fractionDigits_6}) => '定位成功：${next_displayText_fractionDigits_6}';
	@override String get msg_checking_server_version => '正在检查后端版本...';
	@override String get msg_next_time_back_fixing_bugs => '👀 下次一定，先去修 Bug';
	@override String msg_ago_4({required Object weeks}) => '${weeks}週前';
	@override String get msg_import => '导入';
	@override String get msg_ios_long_press_home_screen_add => 'iOS 请长按桌面添加 MemoFlow 小组件';
	@override String get msg_create_token_2 => '创建 Token';
	@override String get msg_marked_read => '已标记为已读';
	@override String get msg_pinned => '置顶';
	@override String get msg_version_update => '版本更新';
	@override String get msg_allow_private_memos => '允许发送私有权限笔记';
	@override String get msg_token_copied_clipboard => 'Token 已复制到剪贴板';
	@override String get msg_keeping_more_versions_uses_more_storage => '增加保留数量会占用更多存储空间，建议定期清理旧版本。';
	@override String get msg_delete_webhook => '删除 Webhook';
	@override String get msg_prompt => '提示词 (Prompt)';
	@override String get msg_location_precision => '定位精度';
	@override String get msg_password_required => '需要密码';
	@override String get msg_exit_app => '退出应用';
	@override String get msg_thanks_energy_fully_restored => '收到心意！能量已充满 ⚡';
	@override String get msg_connection_timeout_check_network_api_url => '连接超时，请检查网络或 API URL';
	@override late final _StringsStringsLegacyAppLanguageZhHantTw app_language = _StringsStringsLegacyAppLanguageZhHantTw._(_root);
	@override late final _StringsStringsLegacyAppThemeZhHantTw app_theme = _StringsStringsLegacyAppThemeZhHantTw._(_root);
	@override late final _StringsStringsLegacyAppFontSizeZhHantTw app_font_size = _StringsStringsLegacyAppFontSizeZhHantTw._(_root);
	@override late final _StringsStringsLegacyAppLineHeightZhHantTw app_line_height = _StringsStringsLegacyAppLineHeightZhHantTw._(_root);
	@override late final _StringsStringsLegacyLaunchActionZhHantTw launch_action = _StringsStringsLegacyLaunchActionZhHantTw._(_root);
	@override late final _StringsStringsLegacyAutoLockTimeZhHantTw auto_lock_time = _StringsStringsLegacyAutoLockTimeZhHantTw._(_root);
	@override late final _StringsStringsLegacyReminderZhHantTw reminder = _StringsStringsLegacyReminderZhHantTw._(_root);
	@override late final _StringsStringsLegacyLocationZhHantTw location = _StringsStringsLegacyLocationZhHantTw._(_root);
	@override late final _StringsStringsLegacyWebdavZhHantTw webdav = _StringsStringsLegacyWebdavZhHantTw._(_root);
	@override String import_count_memos({required Object count}) => '${count}條';
	@override String import_count_attachments({required Object count}) => '${count}個';
	@override late final _StringsStringsLegacyAppDrawerZhHantTw app_drawer = _StringsStringsLegacyAppDrawerZhHantTw._(_root);
	@override late final _StringsStringsLegacyAiSummaryZhHantTw ai_summary = _StringsStringsLegacyAiSummaryZhHantTw._(_root);
}

// Path: strings.login.mode
class _StringsStringsLoginModeZhHantTw extends _StringsStringsLoginModeEn {
	_StringsStringsLoginModeZhHantTw._(_StringsZhHantTw root) : this._root = root, super._(root);

	@override final _StringsZhHantTw _root; // ignore: unused_field

	// Translations
	@override String get password => '帳號密碼';
	@override String get token => 'Token 登入';
	@override String get descPassword => '使用帳號密碼登入';
	@override String get descToken => '使用個人存取權杖登入';
	@override String get signInMethod => '登入方式';
}

// Path: strings.login.field
class _StringsStringsLoginFieldZhHantTw extends _StringsStringsLoginFieldEn {
	_StringsStringsLoginFieldZhHantTw._(_StringsZhHantTw root) : this._root = root, super._(root);

	@override final _StringsZhHantTw _root; // ignore: unused_field

	// Translations
	@override String get serverUrlLabel => '伺服器位址';
	@override String get serverUrlHint => 'http://localhost:5230';
	@override String get usernameLabel => '帳號';
	@override String get usernameHint => '請輸入帳號';
	@override String get passwordLabel => '密碼';
	@override String get passwordHint => '請輸入密碼';
	@override String get tokenLabel => 'Token (PAT)';
	@override String get tokenHint => 'Token (PAT)';
}

// Path: strings.login.validation
class _StringsStringsLoginValidationZhHantTw extends _StringsStringsLoginValidationEn {
	_StringsStringsLoginValidationZhHantTw._(_StringsZhHantTw root) : this._root = root, super._(root);

	@override final _StringsZhHantTw _root; // ignore: unused_field

	// Translations
	@override String get serverUrlRequired => '請輸入伺服器位址';
	@override String get serverUrlInvalid => '請輸入完整位址（包含 http/https 與埠號）';
	@override String get usernameRequired => '請輸入帳號';
	@override String get passwordRequired => '請輸入密碼';
	@override String get tokenRequired => '請輸入 Token';
}

// Path: strings.login.compatibility
class _StringsStringsLoginCompatibilityZhHantTw extends _StringsStringsLoginCompatibilityEn {
	_StringsStringsLoginCompatibilityZhHantTw._(_StringsZhHantTw root) : this._root = root, super._(root);

	@override final _StringsZhHantTw _root; // ignore: unused_field

	// Translations
	@override String get title => '相容模式';
	@override String get description => '使用舊版端點（適配舊版 Memos）';
}

// Path: strings.login.connect
class _StringsStringsLoginConnectZhHantTw extends _StringsStringsLoginConnectEn {
	_StringsStringsLoginConnectZhHantTw._(_StringsZhHantTw root) : this._root = root, super._(root);

	@override final _StringsZhHantTw _root; // ignore: unused_field

	// Translations
	@override String get connecting => '連線中…';
	@override String get action => '連線';
}

// Path: strings.login.errors
class _StringsStringsLoginErrorsZhHantTw extends _StringsStringsLoginErrorsEn {
	_StringsStringsLoginErrorsZhHantTw._(_StringsZhHantTw root) : this._root = root, super._(root);

	@override final _StringsZhHantTw _root; // ignore: unused_field

	// Translations
	@override String get authFailedToken => '認證失敗，請確認 Token 是否有效或未過期';
	@override String get authFailedPat => '認證失敗。新版 Memos 請使用以 memos_pat_ 開頭的 PAT（不要貼上 Bearer 前綴）';
	@override String connectionFailedWithMessage({required Object message}) => '連線失敗：${message}';
	@override String connectionFailed({required Object error}) => '連線失敗：${error}';
	@override String get signInFailed => '登入失敗，請檢查帳號與密碼';
	@override String signInFailedWithMessage({required Object message}) => '登入失敗：${message}';
	@override String get invalidServerUrl => '伺服器位址無效';
	@override String get serverUrlNormalized => '已正規化伺服器位址（移除多餘路徑）';
}

// Path: strings.settings.preferences
class _StringsStringsSettingsPreferencesZhHantTw extends _StringsStringsSettingsPreferencesEn {
	_StringsStringsSettingsPreferencesZhHantTw._(_StringsZhHantTw root) : this._root = root, super._(root);

	@override final _StringsZhHantTw _root; // ignore: unused_field

	// Translations
	@override String get title => '偏好設定';
	@override String get language => '語言';
	@override String get fontSize => '字體大小';
	@override String get lineHeight => '行高';
	@override String get font => '字型';
	@override String get systemDefault => '系統預設';
	@override String get noSystemFonts => '未找到系統字型';
	@override String loadFontsFailed({required Object error}) => '字型載入失敗：${error}';
	@override String get collapseLongContent => '折疊長內容';
	@override String get collapseReferences => '折疊引用';
	@override String get showEngagementInAllMemoDetails => '在全部筆記詳情中顯示按讚和評論';
	@override String get launchAction => '啟動動作';
	@override String get quickInputKeyboard => '快速記錄時自動開啟鍵盤';
	@override String get appearance => '外觀';
	@override String get themeColor => '主題色';
	@override String get haptics => '觸覺回饋';
	@override String get customTheme => '自訂主題';
	@override String get history => '歷史';
	@override String get lightMode => '淺色模式';
	@override String get darkMode => '深色模式';
	@override String get surfaces => '表面色';
	@override String get background => '背景';
	@override String get backgroundColor => '背景色';
	@override String get card => '卡片';
	@override String get cardColor => '卡片色';
	@override String get border => '邊框';
	@override String get borderColor => '邊框色';
}

// Path: strings.legacy.app_language
class _StringsStringsLegacyAppLanguageZhHantTw extends _StringsStringsLegacyAppLanguageEn {
	_StringsStringsLegacyAppLanguageZhHantTw._(_StringsZhHantTw root) : this._root = root, super._(root);

	@override final _StringsZhHantTw _root; // ignore: unused_field

	// Translations
	@override String get system => '跟隨系統';
	@override String get zh_hans => '簡體中文';
	@override String get zh_hant_tw => '繁體中文（中國台灣）';
	@override String get en => '英語';
	@override String get ja => '日語';
	@override String get de => '德語';
}

// Path: strings.legacy.app_theme
class _StringsStringsLegacyAppThemeZhHantTw extends _StringsStringsLegacyAppThemeEn {
	_StringsStringsLegacyAppThemeZhHantTw._(_StringsZhHantTw root) : this._root = root, super._(root);

	@override final _StringsZhHantTw _root; // ignore: unused_field

	// Translations
	@override String get system => '系統';
	@override String get light => '淺色';
	@override String get dark => '深色';
}

// Path: strings.legacy.app_font_size
class _StringsStringsLegacyAppFontSizeZhHantTw extends _StringsStringsLegacyAppFontSizeEn {
	_StringsStringsLegacyAppFontSizeZhHantTw._(_StringsZhHantTw root) : this._root = root, super._(root);

	@override final _StringsZhHantTw _root; // ignore: unused_field

	// Translations
	@override String get standard => '標準';
	@override String get large => '大';
	@override String get small => '小';
}

// Path: strings.legacy.app_line_height
class _StringsStringsLegacyAppLineHeightZhHantTw extends _StringsStringsLegacyAppLineHeightEn {
	_StringsStringsLegacyAppLineHeightZhHantTw._(_StringsZhHantTw root) : this._root = root, super._(root);

	@override final _StringsZhHantTw _root; // ignore: unused_field

	// Translations
	@override String get classic => '經典';
	@override String get compact => '緊湊';
	@override String get relaxed => '舒適';
}

// Path: strings.legacy.launch_action
class _StringsStringsLegacyLaunchActionZhHantTw extends _StringsStringsLegacyLaunchActionEn {
	_StringsStringsLegacyLaunchActionZhHantTw._(_StringsZhHantTw root) : this._root = root, super._(root);

	@override final _StringsZhHantTw _root; // ignore: unused_field

	// Translations
	@override String get none => '無';
	@override String get sync => '同步';
	@override String get quick_input => '快速記錄';
	@override String get daily_review => '隨機漫步';
}

// Path: strings.legacy.auto_lock_time
class _StringsStringsLegacyAutoLockTimeZhHantTw extends _StringsStringsLegacyAutoLockTimeEn {
	_StringsStringsLegacyAutoLockTimeZhHantTw._(_StringsZhHantTw root) : this._root = root, super._(root);

	@override final _StringsZhHantTw _root; // ignore: unused_field

	// Translations
	@override String get immediately => '立即';
	@override String get after_1_min => '1 分鐘';
	@override String get after_5_min => '5 分鐘';
	@override String get after_15_min => '15 分鐘';
}

// Path: strings.legacy.reminder
class _StringsStringsLegacyReminderZhHantTw extends _StringsStringsLegacyReminderEn {
	_StringsStringsLegacyReminderZhHantTw._(_StringsZhHantTw root) : this._root = root, super._(root);

	@override final _StringsZhHantTw _root; // ignore: unused_field

	// Translations
	@override String get default_title => '嗨，你還記得這個想法嗎？';
	@override String get default_body => '點擊查看詳情';
}

// Path: strings.legacy.location
class _StringsStringsLegacyLocationZhHantTw extends _StringsStringsLegacyLocationEn {
	_StringsStringsLegacyLocationZhHantTw._(_StringsZhHantTw root) : this._root = root, super._(root);

	@override final _StringsZhHantTw _root; // ignore: unused_field

	// Translations
	@override String get current => '當前位置';
}

// Path: strings.legacy.webdav
class _StringsStringsLegacyWebdavZhHantTw extends _StringsStringsLegacyWebdavEn {
	_StringsStringsLegacyWebdavZhHantTw._(_StringsZhHantTw root) : this._root = root, super._(root);

	@override final _StringsZhHantTw _root; // ignore: unused_field

	// Translations
	@override String get not_configured => 'WebDAV 未設定';
	@override String get backup_disabled => '備份未啟用';
	@override String get backup_account_missing => '帳號缺失，無法備份';
	@override String get backup_local_only => '僅本地庫可用備份';
	@override String get backup_password_missing => '缺少備份密碼';
	@override String get backup_no_memo_files => '本地庫未發現筆記檔案，備份已取消';
	@override String get restore_account_missing => '帳號缺失，無法恢復';
	@override String get restore_local_only => '僅本地庫可恢復備份';
	@override String get backup_empty => '備份內容為空';
	@override String get backup_no_memos => '備份中沒有筆記';
	@override String get snapshot_missing => '備份快照遺失';
	@override String get snapshot_corrupted => '備份快照損壞';
	@override String get object_missing => '備份對象缺失';
	@override String get config_corrupted => '備份配置損壞';
	@override String get config_invalid => '備份配置無效';
	@override String get password_invalid => '備份密碼錯誤';
	@override String get data_corrupted => '備份資料損壞';
	@override String get server_url_invalid => 'WebDAV 伺服器地址無效';
}

// Path: strings.legacy.app_drawer
class _StringsStringsLegacyAppDrawerZhHantTw extends _StringsStringsLegacyAppDrawerEn {
	_StringsStringsLegacyAppDrawerZhHantTw._(_StringsZhHantTw root) : this._root = root, super._(root);

	@override final _StringsZhHantTw _root; // ignore: unused_field

	// Translations
	@override String tooltip_single({required Object date, required Object weekday, required Object count}) => '${date}（${weekday}）· ${count} 條';
	@override String tooltip_multi({required Object date, required Object weekday, required Object count}) => '${date}（${weekday}）· ${count} 條';
}

// Path: strings.legacy.ai_summary
class _StringsStringsLegacyAiSummaryZhHantTw extends _StringsStringsLegacyAiSummaryEn {
	_StringsStringsLegacyAiSummaryZhHantTw._(_StringsZhHantTw root) : this._root = root, super._(root);

	@override final _StringsZhHantTw _root; // ignore: unused_field

	// Translations
	@override String get error_api_key_empty => 'API Key 為空';
	@override late final _StringsStringsLegacyAiSummarySystemZhHantTw system = _StringsStringsLegacyAiSummarySystemZhHantTw._(_root);
	@override late final _StringsStringsLegacyAiSummaryUserZhHantTw user = _StringsStringsLegacyAiSummaryUserZhHantTw._(_root);
	@override String get error_invalid_response => 'AI 回應格式不正確';
	@override String get error_empty_response => 'AI 回應為空';
	@override String get error_missing_content => 'AI 回應內容缺失';
	@override String get default_prompt => '你是一位極簡主義的筆記助手，擅長提煉核心觀點並以優雅的格式排版。在回覆時，請保持專業、溫和且簡潔的語氣。盡量使用列表和簡短的段落。';
}

// Path: strings.legacy.ai_summary.system
class _StringsStringsLegacyAiSummarySystemZhHantTw extends _StringsStringsLegacyAiSummarySystemEn {
	_StringsStringsLegacyAiSummarySystemZhHantTw._(_StringsZhHantTw root) : this._root = root, super._(root);

	@override final _StringsZhHantTw _root; // ignore: unused_field

	// Translations
	@override String get require_json => '請嚴格輸出 JSON，不要使用程式碼區塊，不要額外說明文字。';
	@override String get json_format => 'JSON 格式：{"insights":["..."],"moodTrend":"...","keywords":["#..."]}';
	@override String get insights_rule => 'insights 控制在 2-5 條，keywords 為 4-8 個帶 # 的詞。';
}

// Path: strings.legacy.ai_summary.user
class _StringsStringsLegacyAiSummaryUserZhHantTw extends _StringsStringsLegacyAiSummaryUserEn {
	_StringsStringsLegacyAiSummaryUserZhHantTw._(_StringsZhHantTw root) : this._root = root, super._(root);

	@override final _StringsZhHantTw _root; // ignore: unused_field

	// Translations
	@override String range({required Object rangeLabel}) => '時間範圍：${rangeLabel}';
	@override String counts({required Object memoCount, required Object includedCount}) => '筆記條數：${memoCount}（提供用於總結：${includedCount}）';
	@override String profile({required Object profile}) => '用戶背景：${profile}';
	@override String custom_prompt({required Object customPrompt}) => '用戶補充指令：${customPrompt}';
	@override String get memo_content => '筆記內容：';
}

/// Flat map(s) containing all translations.
/// Only for edge cases! For simple maps, use the map function of this library.

extension on Translations {
	dynamic _flatMapFunction(String path) {
		switch (path) {
			case 'strings.common.back': return 'Back';
			case 'strings.common.cancel': return 'Cancel';
			case 'strings.common.confirm': return 'Confirm';
			case 'strings.common.save': return 'Save';
			case 'strings.common.saveSettings': return 'Save Settings';
			case 'strings.common.auto': return 'Auto';
			case 'strings.common.manual': return 'Manual';
			case 'strings.common.copiedToClipboard': return 'Copied to clipboard';
			case 'strings.common.serverVersion': return 'Server Version';
			case 'strings.common.selectValidServerVersion': return 'Please select a valid server version';
			case 'strings.common.serverVersionValue': return ({required Object version}) => 'Server version: ${version}';
			case 'strings.common.selectServerVersionRange021To026': return 'Please manually select a server version between 0.21 and 0.26';
			case 'strings.languages.system': return 'Follow System';
			case 'strings.languages.zhHans': return 'Chinese (Simplified)';
			case 'strings.languages.zhHantTw': return 'Chinese (Traditional, China Taiwan)';
			case 'strings.languages.en': return 'English';
			case 'strings.languages.ja': return 'Japanese';
			case 'strings.languages.de': return 'German';
			case 'strings.languagesNative.system': return 'System';
			case 'strings.languagesNative.zhHans': return '简体中文';
			case 'strings.languagesNative.zhHantTw': return '繁體中文（中國台灣）';
			case 'strings.languagesNative.en': return 'English';
			case 'strings.languagesNative.ja': return '日本語';
			case 'strings.languagesNative.de': return 'Deutsch';
			case 'strings.onboarding.tagline': return 'Minimal, powerful note stream';
			case 'strings.onboarding.selectLanguage': return 'Select language';
			case 'strings.onboarding.selectMode': return 'Choose a mode';
			case 'strings.onboarding.modeHint': return 'You can change this later in Settings.';
			case 'strings.onboarding.modeLocalTitle': return 'Local mode';
			case 'strings.onboarding.modeLocalLabel': return 'LOCAL MODE';
			case 'strings.onboarding.modeLocalDesc': return 'Data stays on device. No server setup required, ideal for privacy and offline use.';
			case 'strings.onboarding.modeServerTitle': return 'Server mode';
			case 'strings.onboarding.modeServerLabel': return 'SERVER MODE';
			case 'strings.onboarding.modeServerDesc': return 'Connect to your Memos backend for real-time multi-device sync.';
			case 'strings.onboarding.localLibraryNameTitle': return 'Local library name';
			case 'strings.onboarding.localLibraryNameHint': return 'Enter a name';
			case 'strings.onboarding.localLibraryDefaultName': return 'Local library';
			case 'strings.onboarding.getStarted': return 'Get started';
			case 'strings.login.title': return 'Connect to Memos';
			case 'strings.login.mode.password': return 'Username & Password';
			case 'strings.login.mode.token': return 'Token';
			case 'strings.login.mode.descPassword': return 'Sign in with username and password';
			case 'strings.login.mode.descToken': return 'Sign in with Personal Access Token';
			case 'strings.login.mode.signInMethod': return 'Sign-in method';
			case 'strings.login.field.serverUrlLabel': return 'Server URL';
			case 'strings.login.field.serverUrlHint': return 'http://localhost:5230';
			case 'strings.login.field.usernameLabel': return 'Username';
			case 'strings.login.field.usernameHint': return 'Enter username';
			case 'strings.login.field.passwordLabel': return 'Password';
			case 'strings.login.field.passwordHint': return 'Enter password';
			case 'strings.login.field.tokenLabel': return 'Token (PAT)';
			case 'strings.login.field.tokenHint': return 'Token (PAT)';
			case 'strings.login.validation.serverUrlRequired': return 'Please enter server URL';
			case 'strings.login.validation.serverUrlInvalid': return 'Enter full URL (including http/https and port)';
			case 'strings.login.validation.usernameRequired': return 'Please enter username';
			case 'strings.login.validation.passwordRequired': return 'Please enter password';
			case 'strings.login.validation.tokenRequired': return 'Please enter token';
			case 'strings.login.compatibility.title': return 'Compatibility Mode';
			case 'strings.login.compatibility.description': return 'Use legacy endpoints (for older Memos servers)';
			case 'strings.login.connect.connecting': return 'Connecting…';
			case 'strings.login.connect.action': return 'Connect';
			case 'strings.login.errors.authFailedToken': return 'Authentication failed. Check that the token is valid and not expired.';
			case 'strings.login.errors.authFailedPat': return 'Authentication failed. For new Memos use a PAT starting with memos_pat_ (do not paste the Bearer prefix).';
			case 'strings.login.errors.connectionFailedWithMessage': return ({required Object message}) => 'Connection failed: ${message}';
			case 'strings.login.errors.connectionFailed': return ({required Object error}) => 'Connection failed: ${error}';
			case 'strings.login.errors.signInFailed': return 'Sign-in failed. Check username and password.';
			case 'strings.login.errors.signInFailedWithMessage': return ({required Object message}) => 'Sign-in failed: ${message}';
			case 'strings.login.errors.invalidServerUrl': return 'Invalid server URL';
			case 'strings.login.errors.serverUrlNormalized': return 'Server URL normalized (removed extra path segments)';
			case 'strings.settings.preferences.title': return 'Preferences';
			case 'strings.settings.preferences.language': return 'Language';
			case 'strings.settings.preferences.fontSize': return 'Font Size';
			case 'strings.settings.preferences.lineHeight': return 'Line Height';
			case 'strings.settings.preferences.font': return 'Font';
			case 'strings.settings.preferences.systemDefault': return 'System Default';
			case 'strings.settings.preferences.noSystemFonts': return 'No system fonts found';
			case 'strings.settings.preferences.loadFontsFailed': return ({required Object error}) => 'Failed to load fonts: ${error}';
			case 'strings.settings.preferences.collapseLongContent': return 'Collapse Long Content';
			case 'strings.settings.preferences.collapseReferences': return 'Collapse References';
			case 'strings.settings.preferences.showEngagementInAllMemoDetails': return 'Show likes and comments in all memo details';
			case 'strings.settings.preferences.launchAction': return 'Launch Action';
			case 'strings.settings.preferences.quickInputKeyboard': return 'Auto-open keyboard for Quick Input';
			case 'strings.settings.preferences.appearance': return 'Appearance';
			case 'strings.settings.preferences.themeColor': return 'Theme Color';
			case 'strings.settings.preferences.haptics': return 'Haptics';
			case 'strings.settings.preferences.customTheme': return 'Custom Theme';
			case 'strings.settings.preferences.history': return 'History';
			case 'strings.settings.preferences.lightMode': return 'Light Mode';
			case 'strings.settings.preferences.darkMode': return 'Dark Mode';
			case 'strings.settings.preferences.surfaces': return 'Surfaces';
			case 'strings.settings.preferences.background': return 'Background';
			case 'strings.settings.preferences.backgroundColor': return 'Background Color';
			case 'strings.settings.preferences.card': return 'Card';
			case 'strings.settings.preferences.cardColor': return 'Card Color';
			case 'strings.settings.preferences.border': return 'Border';
			case 'strings.settings.preferences.borderColor': return 'Border Color';
			case 'strings.legacy.msg_memos_backend_docs': return 'Memos Backend Docs';
			case 'strings.legacy.msg_remember_moment_feel_warmth_life_take': return 'Remember the moment, feel the warmth of life.\\nTake a quick review every day.';
			case 'strings.legacy.msg_sure_want_delete_shortcut': return 'Are you sure you want to delete this shortcut?';
			case 'strings.legacy.msg_scan_completed': return 'Scan completed';
			case 'strings.legacy.msg_confirm': return 'Confirm';
			case 'strings.legacy.msg_unable_open_browser_install_browser_app': return 'Unable to open browser. Please install a browser app.';
			case 'strings.legacy.msg_contributors': return 'Contributors';
			case 'strings.legacy.msg_enter_keywords_search_box_query_local': return 'Enter keywords in the search box to query local content and tags. Works offline; for first use, wait until local indexing finishes.';
			case 'strings.legacy.msg_memo_not_found_locally': return 'Memo not found locally';
			case 'strings.legacy.msg_token': return 'Token';
			case 'strings.legacy.msg_last_7_days': return 'Last 7 days';
			case 'strings.legacy.msg_search_memo_content': return 'Search memo content';
			case 'strings.legacy.msg_retry_started': return 'Retry started';
			case 'strings.legacy.msg_last_year_memos': return ({required Object lastYearMemos}) => 'Last year: ${lastYearMemos} memos';
			case 'strings.legacy.msg_no_content_yet': return 'No content yet';
			case 'strings.legacy.msg_no_summary_yet': return 'No summary yet';
			case 'strings.legacy.msg_sooner': return ' sooner!';
			case 'strings.legacy.msg_token_copied': return 'Token copied';
			case 'strings.legacy.msg_share': return 'Share';
			case 'strings.legacy.msg_gallery_permission_required': return 'Gallery permission required';
			case 'strings.legacy.msg_basic_settings': return 'Basic settings';
			case 'strings.legacy.msg_bad_ssl_certificate': return 'Bad SSL certificate.';
			case 'strings.legacy.msg_no_notifications': return 'No notifications';
			case 'strings.legacy.msg_import_markdown': return 'Import from Markdown';
			case 'strings.legacy.msg_upload_zip_package_md_files': return 'Upload a .zip package with .md files';
			case 'strings.legacy.msg_request_send_timeout_try': return 'Request send timeout. Try again.';
			case 'strings.legacy.msg_select_date_range': return 'Select date range';
			case 'strings.legacy.msg_delete_shortcut': return 'Delete Shortcut';
			case 'strings.legacy.msg_auto_lock_time': return 'Auto-lock time';
			case 'strings.legacy.msg_replacing_delete_original_attachment_continue': return 'Replacing will delete the original attachment. Continue?';
			case 'strings.legacy.msg_add_least_one_condition': return 'Please add at least one condition.';
			case 'strings.legacy.msg_upload_images_image_bed_append_links': return 'Upload images to the image bed and append links to the memo.';
			case 'strings.legacy.msg_request_cancelled': return 'Request cancelled.';
			case 'strings.legacy.msg_generating': return 'Generating?';
			case 'strings.legacy.msg_permissions_denied_reminders_disabled': return 'Permissions denied. Reminders disabled.';
			case 'strings.legacy.msg_memoflow_local_reminders': return 'MemoFlow local reminders';
			case 'strings.legacy.msg_use_legacy_endpoints_older_memos_servers': return 'Use legacy endpoints (for older Memos servers).';
			case 'strings.legacy.msg_no_comments_yet': return 'No comments yet';
			case 'strings.legacy.msg_open': return 'Open';
			case 'strings.legacy.msg_microphone_permission_required': return 'Microphone permission required';
			case 'strings.legacy.msg_failed_react': return ({required Object e}) => 'Failed to react: ${e}';
			case 'strings.legacy.msg_restore_backup': return 'Restore backup?';
			case 'strings.legacy.msg_qr_saved_gallery': return 'QR saved to gallery';
			case 'strings.legacy.msg_no_attachments': return 'No attachments';
			case 'strings.legacy.msg_enable_reminder_permissions': return 'Enable reminder permissions';
			case 'strings.legacy.msg_created_time': return 'Created time ↑';
			case 'strings.legacy.msg_prompt_saved_quick_prompts': return 'Your prompt will be saved in Quick prompts';
			case 'strings.legacy.msg_remember_password': return 'Remember password';
			case 'strings.legacy.msg_enter_valid_url': return 'Please enter a valid URL';
			case 'strings.legacy.msg_may_take_few_seconds': return 'This may take a few seconds';
			case 'strings.legacy.msg_local_sync_failed': return ({required Object type, required Object memoError}) => 'Local sync failed (${type}): ${memoError}';
			case 'strings.legacy.msg_webdav_sync': return 'WebDAV Sync';
			case 'strings.legacy.msg_clear': return 'Clear';
			case 'strings.legacy.msg_clear_recycle_bin_confirm': return 'Clear recycle bin? All items will be permanently deleted.';
			case 'strings.legacy.msg_save_failed': return 'Save failed';
			case 'strings.legacy.msg_endpoint_not_found_version_mismatch': return 'Endpoint not found (version mismatch?)';
			case 'strings.legacy.msg_enable_webdav_sync': return 'Enable WebDAV sync';
			case 'strings.legacy.msg_local_libraries': return 'Local libraries';
			case 'strings.legacy.msg_apply': return 'Apply';
			case 'strings.legacy.msg_restore_only_available_local_libraries': return 'Restore is only available for local libraries.';
			case 'strings.legacy.msg_sign': return 'Sign out?';
			case 'strings.legacy.msg_reminders_disabled': return 'Reminders are disabled';
			case 'strings.legacy.msg_downloading': return 'Downloading...';
			case 'strings.legacy.msg_path': return 'Path';
			case 'strings.legacy.msg_match_any': return 'Match any';
			case 'strings.legacy.msg_local_db_pending_queue': return 'Local DB + pending queue';
			case 'strings.legacy.msg_scan_failed': return ({required Object e}) => 'Scan failed: ${e}';
			case 'strings.legacy.msg_user': return 'User';
			case 'strings.legacy.msg_pick_future_time': return 'Pick a future time';
			case 'strings.legacy.msg_include_pending_queue': return 'Include pending queue';
			case 'strings.legacy.msg_enter_days': return 'Enter days';
			case 'strings.legacy.msg_times': return 'Times';
			case 'strings.legacy.msg_token_returned_only_once_cannot_fetched': return 'Token is returned only once and cannot be fetched again';
			case 'strings.legacy.msg_quoted_lines': return ({required Object quoteLines}) => 'Quoted ${quoteLines} lines';
			case 'strings.legacy.msg_use_remote': return 'Use remote';
			case 'strings.legacy.msg_enable_memo_location': return 'Enable memo location';
			case 'strings.legacy.msg_failed_get_location': return 'Failed to get location';
			case 'strings.legacy.msg_after_import_memos_sync_list_automatically': return 'After import, your memos sync to the list automatically. For ZIP imports, ensure the file structure is intact.';
			case 'strings.legacy.msg_legacy_mode': return 'Legacy Mode';
			case 'strings.legacy.msg_signed': return 'Signed in';
			case 'strings.legacy.msg_shortcut_includes_advanced_conditions_saving_overwrite': return 'This shortcut includes advanced conditions. Saving will overwrite them.';
			case 'strings.legacy.msg_no_results_found': return 'No results found';
			case 'strings.legacy.msg_reply': return ({required Object replyName}) => 'Reply ${replyName}...';
			case 'strings.legacy.msg_copy': return 'Copy';
			case 'strings.legacy.msg_enable_reminders_memos': return 'Enable reminders for your memos.';
			case 'strings.legacy.msg_comment': return 'Comment';
			case 'strings.legacy.msg_added_voice_attachment': return 'Added voice attachment.';
			case 'strings.legacy.msg_customize_sidebar': return 'Customize Sidebar';
			case 'strings.legacy.msg_coffee_add_drumstick': return '☕ Coffee it is / add a drumstick';
			case 'strings.legacy.msg_pin': return 'Pin';
			case 'strings.legacy.msg_enter_password_continue': return 'Enter password to continue';
			case 'strings.legacy.msg_remove_local_library': return 'Remove local library?';
			case 'strings.legacy.msg_comment_2': return 'New comment';
			case 'strings.legacy.msg_sync_all': return 'Sync all';
			case 'strings.legacy.msg_backup_schedule': return 'Backup schedule';
			case 'strings.legacy.msg_server_error': return 'Server error';
			case 'strings.legacy.msg_analyzing_memos': return 'Analyzing your memos...';
			case 'strings.legacy.msg_notification': return 'Notification';
			case 'strings.legacy.msg_policy': return 'Policy';
			case 'strings.legacy.msg_failed_load': return ({required Object error}) => 'Failed to load: ${error}';
			case 'strings.legacy.msg_default_visibility': return 'Default visibility';
			case 'strings.legacy.msg_filter': return 'Filter';
			case 'strings.legacy.msg_imported_memos': return 'Imported memos';
			case 'strings.legacy.msg_token_created': return 'Token created';
			case 'strings.legacy.msg_server_response_timeout_try': return 'Server response timeout. Try again.';
			case 'strings.legacy.msg_expiring': return 'Expiring';
			case 'strings.legacy.msg_delete_task': return 'Delete task';
			case 'strings.legacy.msg_body_must_json': return 'Body must be JSON';
			case 'strings.legacy.msg_enable': return 'Enable';
			case 'strings.legacy.msg_referenced': return 'Referenced by';
			case 'strings.legacy.msg_replace_image': return 'Replace image?';
			case 'strings.legacy.msg_debug_logs': return 'Debug Logs';
			case 'strings.legacy.msg_active_tasks': return 'Active tasks';
			case 'strings.legacy.msg_attachments': return 'Attachments';
			case 'strings.legacy.msg_range': return 'Range';
			case 'strings.legacy.msg_no_backups_found': return 'No backups found';
			case 'strings.legacy.msg_create_memo': return 'Create memo';
			case 'strings.legacy.msg_street': return 'Street';
			case 'strings.legacy.msg_display_name': return 'Display name';
			case 'strings.legacy.msg_full_text_search': return 'Full-Text Search';
			case 'strings.legacy.msg_create_edit_delete_actions_offline_stored': return 'Create/edit/delete actions offline are stored locally and queued for sync. They are sent in order when online. To avoid mistakes, unsubmitted edits can be kept as drafts.';
			case 'strings.legacy.msg_sign_2': return 'Sign Out';
			case 'strings.legacy.msg_end_time': return 'End time';
			case 'strings.legacy.msg_sync_recent_content': return 'Sync recent content';
			case 'strings.legacy.msg_resetting_local_data': return 'Resetting local data...';
			case 'strings.legacy.msg_incorrect_password': return 'Incorrect password';
			case 'strings.legacy.msg_content_cannot_empty': return 'Content cannot be empty';
			case 'strings.legacy.msg_preparing': return 'Preparing';
			case 'strings.legacy.msg_ai_summary_failed': return ({required Object formatSummaryError_e}) => 'AI summary failed: ${formatSummaryError_e}';
			case 'strings.legacy.msg_manage': return 'Manage';
			case 'strings.legacy.msg_keep_data_consistent_across_devices': return 'Keep data consistent across devices.';
			case 'strings.legacy.msg_playback_failed': return ({required Object e}) => 'Playback failed: ${e}';
			case 'strings.legacy.msg_path_copied': return 'Path copied';
			case 'strings.legacy.msg_auth_settings': return 'Auth settings';
			case 'strings.legacy.msg_randomly_draw_memo_cards': return 'Randomly draw your memo cards';
			case 'strings.legacy.msg_copy_log_text': return 'Copy log text';
			case 'strings.legacy.msg_yes': return 'Yes';
			case 'strings.legacy.msg_save_open_alipay_scan': return 'Save and open Alipay to scan';
			case 'strings.legacy.msg_signed_but_no_token_returned': return 'Signed in, but no token returned';
			case 'strings.legacy.msg_create_failed': return ({required Object formatError_e_context}) => 'Create failed: ${formatError_e_context}';
			case 'strings.legacy.msg_expand': return 'Expand';
			case 'strings.legacy.msg_local_library_only': return 'Local library only';
			case 'strings.legacy.msg_reminder_channel': return 'Reminder channel';
			case 'strings.legacy.msg_grant': return 'Grant';
			case 'strings.legacy.msg_import_canceled': return 'Import canceled.';
			case 'strings.legacy.msg_never': return 'Never';
			case 'strings.legacy.msg_release_notes': return 'Release Notes';
			case 'strings.legacy.msg_failed_load_references': return 'Failed to load references';
			case 'strings.legacy.msg_select_tags': return 'Select tags';
			case 'strings.legacy.msg_failed_load_try': return 'Failed to load. Please try again.';
			case 'strings.legacy.msg_logs_copied': return 'Logs copied';
			case 'strings.legacy.msg_shortcuts_not_supported_server': return 'Shortcuts are not supported on this server.';
			case 'strings.legacy.msg_reply_2': return ({required Object name}) => 'Reply ${name}...';
			case 'strings.legacy.msg_anonymous': return 'Anonymous';
			case 'strings.legacy.msg_username': return 'Username';
			case 'strings.legacy.msg_update_memo': return 'Update memo';
			case 'strings.legacy.msg_saved': return ({required Object targetPath}) => 'Saved to: ${targetPath}';
			case 'strings.legacy.msg_chinese_simplified': return 'Chinese (Simplified)';
			case 'strings.legacy.msg_memo_copied': return 'Memo copied';
			case 'strings.legacy.msg_collapse': return 'Collapse';
			case 'strings.legacy.msg_retry_count_controls_how_many_extra': return 'Retry count controls how many extra attempts are made on failure. Higher values may improve success but take longer.';
			case 'strings.legacy.msg_recording_info_missing': return 'Recording info missing';
			case 'strings.legacy.msg_sync_task': return 'Sync task';
			case 'strings.legacy.msg_clear_all_debug_logs': return 'Clear all debug logs?';
			case 'strings.legacy.msg_export_finished': return 'Export finished';
			case 'strings.legacy.msg_failed_stop_recording': return ({required Object e}) => 'Failed to stop recording: ${e}';
			case 'strings.legacy.msg_my_profile': return 'My Profile';
			case 'strings.legacy.msg_image_bed': return 'Image Bed';
			case 'strings.legacy.msg_failed_open_notification': return ({required Object e}) => 'Failed to open notification: ${e}';
			case 'strings.legacy.msg_manual': return 'Manual';
			case 'strings.legacy.msg_no_html_file_found_zip': return 'No HTML file found in ZIP.';
			case 'strings.legacy.msg_also_clear_local_cache_account_offline': return 'This will also clear local cache for this account (offline data/drafts/pending sync queue). This action cannot be undone.';
			case 'strings.legacy.msg_restore': return 'Restore';
			case 'strings.legacy.msg_auto_backup': return 'Auto backup';
			case 'strings.legacy.msg_generate_summary': return 'Generate summary';
			case 'strings.legacy.msg_days': return ({required Object stats_activeDays}) => '${stats_activeDays} days';
			case 'strings.legacy.msg_count': return '- Count';
			case 'strings.legacy.msg_weekly': return 'Weekly';
			case 'strings.legacy.msg_notifications': return 'Notifications';
			case 'strings.legacy.msg_backup_failed': return 'Backup failed';
			case 'strings.legacy.msg_private': return 'Private';
			case 'strings.legacy.msg_filter_tags': return 'Filter by tags';
			case 'strings.legacy.msg_clear_logs': return 'Clear logs';
			case 'strings.legacy.msg_unable_open_browser': return 'Unable to open browser';
			case 'strings.legacy.msg_attachment_too_large': return 'Attachment too large';
			case 'strings.legacy.msg_query': return 'Query';
			case 'strings.legacy.msg_match_all': return 'Match all';
			case 'strings.legacy.msg_record_request_response_logs': return 'Record request/response logs';
			case 'strings.legacy.msg_import_file': return 'Import File';
			case 'strings.legacy.msg_content_tags': return 'Content + tags';
			case 'strings.legacy.msg_feature_not_available_local_library_mode': return 'This feature is not available in local library mode.';
			case 'strings.legacy.msg_import_failed': return ({required Object e}) => 'Import failed: ${e}';
			case 'strings.legacy.msg_save_memo': return 'Save as memo';
			case 'strings.legacy.msg_scan_disk_directory_merge_local_database': return 'Scan disk directory and merge into local database? Missing files will be treated as deletions.';
			case 'strings.legacy.msg_passwords_not_match': return 'Passwords do not match';
			case 'strings.legacy.msg_signed_2': return ({required Object lastLoginUser}) => 'Signed in as: ${lastLoginUser}';
			case 'strings.legacy.msg_made_love_note_taking': return 'Made with love for note-taking';
			case 'strings.legacy.msg_password_updated_local': return 'Password updated (local)';
			case 'strings.legacy.msg_retry': return 'Retry';
			case 'strings.legacy.msg_memo_stats': return 'Memo stats';
			case 'strings.legacy.msg_shown_only_once_copy_keep_safe': return 'Shown only once, please copy and keep it safe.';
			case 'strings.legacy.msg_describe_issue_time_repro_steps_etc': return 'Describe the issue, time, repro steps, etc.';
			case 'strings.legacy.msg_how_many_days_back': return 'How many days back';
			case 'strings.legacy.msg_local_cache_cleared': return 'Local cache cleared';
			case 'strings.legacy.msg_none': return 'None';
			case 'strings.legacy.msg_body_json': return 'Body (JSON)';
			case 'strings.legacy.msg_download_failed': return ({required Object e}) => 'Download failed: ${e}';
			case 'strings.legacy.msg_recycle_bin': return 'Recycle Bin';
			case 'strings.legacy.msg_unpin': return 'Unpin';
			case 'strings.legacy.msg_advanced_security': return 'Advanced & security';
			case 'strings.legacy.msg_run_issues_memoflow_e_g_sync': return 'If you run into issues in MemoFlow (e.g. sync failures, crashes), please follow the steps below to help us diagnose and fix the problem faster.\\n\\n';
			case 'strings.legacy.msg_remove_all_reminder_times_memo': return 'Remove all reminder times for this memo.';
			case 'strings.legacy.msg_no_summary_save': return 'No summary to save';
			case 'strings.legacy.msg_reset_language_selection': return 'Reset language selection';
			case 'strings.legacy.msg_v_30_days': return '30 days';
			case 'strings.legacy.msg_e_g_mood_check': return 'e.g. Mood check';
			case 'strings.legacy.msg_note_some_tokens_returned_only_once': return 'Note: Some tokens are returned only once and cannot be retrieved later. Please keep them safe.';
			case 'strings.legacy.msg_syncing': return 'Syncing...';
			case 'strings.legacy.msg_retention': return 'Retention';
			case 'strings.legacy.msg_open_login_screen': return 'Open login screen';
			case 'strings.legacy.msg_apply_all': return 'Apply to all';
			case 'strings.legacy.msg_write_something_supports_tag_tasks_x': return 'Write something... Supports #tag and tasks [ ] / [x]';
			case 'strings.legacy.msg_http': return ({required Object base, required Object status, required Object msg}) => '${base} (HTTP ${status}): ${msg}';
			case 'strings.legacy.msg_single': return 'Single';
			case 'strings.legacy.msg_delete_memo': return 'Delete memo?';
			case 'strings.legacy.msg_ai_provider': return 'AI Provider';
			case 'strings.legacy.msg_release_notes_v': return ({required Object version}) => 'Release Notes v${version}';
			case 'strings.legacy.msg_info_only_used_background_ai_summaries': return 'This info is only used as background for AI summaries/reports and is not synced to the backend.';
			case 'strings.legacy.msg_not_disturb': return 'Do not disturb';
			case 'strings.legacy.msg_local_library_import_failed': return ({required Object e}) => 'Local library import failed: ${e}';
			case 'strings.legacy.msg_key_insights': return 'Key insights';
			case 'strings.legacy.msg_additional_notes_optional': return 'Additional notes (optional)';
			case 'strings.legacy.msg_server_response_error': return 'Server response error.';
			case 'strings.legacy.msg_sort': return 'Sort';
			case 'strings.legacy.msg_api_call': return 'API Call';
			case 'strings.legacy.msg_webhooks': return 'Webhooks';
			case 'strings.legacy.msg_local_library': return 'Local library';
			case 'strings.legacy.msg_log_copied': return 'Log copied';
			case 'strings.legacy.msg_last_success': return 'Last success';
			case 'strings.legacy.msg_restore_cloud': return 'Restore from cloud';
			case 'strings.legacy.msg_search_public_memos': return 'Search public memos';
			case 'strings.legacy.msg_cancel': return 'Cancel';
			case 'strings.legacy.msg_processing': return ({required Object processed, required Object total}) => 'Processing ${processed} / ${total}';
			case 'strings.legacy.msg_failed_items': return 'Failed items';
			case 'strings.legacy.msg_recording_file_not_found': return 'Recording file not found';
			case 'strings.legacy.msg_local_db_outbox_queue': return 'Local DB + outbox queue';
			case 'strings.legacy.msg_remove': return 'Remove';
			case 'strings.legacy.msg_export_format': return 'Export Format';
			case 'strings.legacy.msg_idle': return 'Idle';
			case 'strings.legacy.msg_ago': return ({required Object months}) => '${months} ago';
			case 'strings.legacy.msg_no_tags_yet': return 'No tags yet';
			case 'strings.legacy.msg_version_v': return ({required Object version}) => 'Version v${version}';
			case 'strings.legacy.msg_sync': return 'Sync';
			case 'strings.legacy.msg_done': return 'Done';
			case 'strings.legacy.msg_gallery_permission_required_2': return 'Gallery permission required';
			case 'strings.legacy.msg_insufficient_permissions': return 'Insufficient permissions';
			case 'strings.legacy.msg_no_download_url_available': return 'No download URL available';
			case 'strings.legacy.msg_record_create_memos': return 'Record to create memos';
			case 'strings.legacy.msg_signing': return 'Signing in...';
			case 'strings.legacy.msg_memoflow_uses_system_location_permission_get': return 'MemoFlow uses system location permission to get coordinates, then reverse geocodes via Amap Web API. You can choose the display precision above.';
			case 'strings.legacy.msg_continue': return 'Continue';
			case 'strings.legacy.msg_notification_content_unavailable': return 'Notification content unavailable';
			case 'strings.legacy.msg_unable_read_file_path': return 'Unable to read file path.';
			case 'strings.legacy.msg_all_memos': return 'All Memos';
			case 'strings.legacy.msg_keywords': return 'Keywords';
			case 'strings.legacy.msg_import_result': return 'Import Result';
			case 'strings.legacy.msg_offline_sync': return 'Offline Sync';
			case 'strings.legacy.msg_imported_memos_local_library': return 'Imported memos from local library';
			case 'strings.legacy.msg_request_failed': return 'Request failed';
			case 'strings.legacy.msg_log_file': return 'Log file';
			case 'strings.legacy.msg_after_confirming_support_unlock_limited_gold': return 'After confirming support, you will unlock a limited gold badge or a forever ad-free promise (though there were never ads).';
			case 'strings.legacy.msg_failed_open_system_settings': return 'Failed to open system settings';
			case 'strings.legacy.msg_no_mood_trend': return 'No mood trend';
			case 'strings.legacy.msg_memoflow_export': return '# MemoFlow Export';
			case 'strings.legacy.msg_sync_queue': return 'Sync queue';
			case 'strings.legacy.msg_only_delete_sync_task_memo_kept': return 'Only delete the sync task; the memo will be kept.';
			case 'strings.legacy.msg_add_home_screen': return 'Add to Home Screen';
			case 'strings.legacy.msg_past_days': return 'Past days';
			case 'strings.legacy.msg_poster_generation_failed': return 'Poster generation failed';
			case 'strings.legacy.msg_failed_load_stats': return ({required Object e}) => 'Failed to load stats: ${e}';
			case 'strings.legacy.msg_customize_notification': return 'Customize Notification';
			case 'strings.legacy.msg_updated_time': return 'Updated time ↓';
			case 'strings.legacy.msg_network_connection_failed_check_network': return 'Network connection failed. Please check your network.';
			case 'strings.legacy.msg_special_thanks': return 'Special thanks:';
			case 'strings.legacy.msg_failed_comment': return ({required Object e}) => 'Failed to comment: ${e}';
			case 'strings.legacy.msg_security_key_sig': return 'Security Key (sig)';
			case 'strings.legacy.msg_save_gallery': return 'Save to gallery';
			case 'strings.legacy.msg_request_sent_confirm_system_prompt': return 'Request sent. Confirm in the system prompt';
			case 'strings.legacy.msg_server_url': return 'Server URL';
			case 'strings.legacy.msg_period_review': return 'Period Review';
			case 'strings.legacy.msg_settings_updated': return 'Settings updated';
			case 'strings.legacy.msg_backend_0_21_not_supported_import': return 'Backend 0.21 is not supported for import. Please upgrade and try again.';
			case 'strings.legacy.msg_failed_load_tags': return ({required Object e}) => 'Failed to load tags: ${e}';
			case 'strings.legacy.msg_enter_email': return 'Enter email';
			case 'strings.legacy.msg_add_webhook': return 'Add Webhook';
			case 'strings.legacy.msg_read': return 'Read';
			case 'strings.legacy.msg_widgets': return 'Widgets';
			case 'strings.legacy.msg_default': return 'Default';
			case 'strings.legacy.msg_memo_reminders': return 'Memo Reminders';
			case 'strings.legacy.msg_import_flomo': return 'Import from Flomo';
			case 'strings.legacy.msg_format_fixed_markdown_zip': return 'Format is fixed to Markdown + ZIP';
			case 'strings.legacy.msg_enter_username_password': return 'Enter username and password';
			case 'strings.legacy.msg_loading': return 'Loading...';
			case 'strings.legacy.msg_test_scheduled': return ({required Object timeLabel, required Object suffix, required Object pendingLabel}) => 'Test scheduled at ${timeLabel}${suffix}${pendingLabel}';
			case 'strings.legacy.msg_edit_memo': return 'Edit Memo';
			case 'strings.legacy.msg_save': return 'Save';
			case 'strings.legacy.msg_laboratory': return 'Laboratory';
			case 'strings.legacy.msg_use_local': return 'Use local';
			case 'strings.legacy.msg_retry_sync': return 'Retry sync';
			case 'strings.legacy.msg_e_g_my_role_topics_interest': return 'e.g., my role / topics of interest / writing style preferences?';
			case 'strings.legacy.msg_confirm_password': return 'Confirm Password';
			case 'strings.legacy.msg_not_set': return 'Not set';
			case 'strings.legacy.msg_no_memos_day': return 'No memos on this day';
			case 'strings.legacy.msg_shortcut_name': return 'Shortcut name';
			case 'strings.legacy.msg_edit_shortcut': return 'Edit Shortcut';
			case 'strings.legacy.msg_days_memos': return 'Days with memos';
			case 'strings.legacy.msg_delete': return 'Delete';
			case 'strings.legacy.msg_test_reminder': return 'Test reminder';
			case 'strings.legacy.msg_enable_reminders': return 'Enable reminders';
			case 'strings.legacy.msg_links': return 'Links';
			case 'strings.legacy.msg_location': return 'Location';
			case 'strings.legacy.msg_import_file_2': return 'Import from file';
			case 'strings.legacy.msg_reply_3': return ({required Object creatorDisplayName_commentCreator_commentMemo_creator}) => 'Reply ${creatorDisplayName_commentCreator_commentMemo_creator}...';
			case 'strings.legacy.msg_created': return ({required Object widget_createdAtLabel}) => 'Created ${widget_createdAtLabel}';
			case 'strings.legacy.msg_notifications_coming_soon': return 'Notifications: coming soon';
			case 'strings.legacy.msg_view_full_contributors': return 'View full contributors';
			case 'strings.legacy.msg_no_times_set': return 'No times set';
			case 'strings.legacy.msg_ignore_tls_errors': return 'Ignore TLS errors';
			case 'strings.legacy.msg_no_content': return 'No content';
			case 'strings.legacy.msg_about_15_seconds_left': return 'About 15 seconds left';
			case 'strings.legacy.msg_view_imported_memos': return 'View imported memos';
			case 'strings.legacy.msg_load_failed': return 'Load failed';
			case 'strings.legacy.msg_disk_content_conflicts_local_pending_changes': return 'Disk content conflicts with local pending changes. Use disk to overwrite local content.';
			case 'strings.legacy.msg_all_history_so_far_memoflow_since': return 'That is all the history so far\\nMEMOFLOW SINCE 2023';
			case 'strings.legacy.msg_cancelling': return 'Cancelling';
			case 'strings.legacy.msg_reading_file': return 'Reading file...';
			case 'strings.legacy.msg_switch_workspace': return 'Switch workspace';
			case 'strings.legacy.msg_optional_leave_empty_default': return 'Optional. Leave empty for default.';
			case 'strings.legacy.msg_memo_reminders_2': return 'Memo reminders';
			case 'strings.legacy.msg_save_failed_2': return ({required Object e}) => 'Save failed: ${e}';
			case 'strings.legacy.msg_record_create_memos_sync_later': return 'Record and create memos (sync later)';
			case 'strings.legacy.msg_use_https_avoid_ignoring_tls_errors': return 'Use HTTPS and avoid ignoring TLS errors to protect credentials.';
			case 'strings.legacy.msg_failed_load_announcement_config': return 'Failed to load announcement config';
			case 'strings.legacy.msg_shortcuts': return 'Shortcuts';
			case 'strings.legacy.msg_memo': return 'Memo';
			case 'strings.legacy.msg_maybe_later': return 'Maybe later';
			case 'strings.legacy.msg_server_connection': return 'Server connection';
			case 'strings.legacy.msg_days_2': return 'Days';
			case 'strings.legacy.msg_include_archived': return 'Include Archived';
			case 'strings.legacy.msg_during_quiet_hours_reminders_silenced': return 'During quiet hours, reminders will be silenced.';
			case 'strings.legacy.msg_preview_not_supported_type': return 'Preview not supported for this type';
			case 'strings.legacy.msg_failed_load_2': return 'Failed to load';
			case 'strings.legacy.msg_create_token': return 'Create New Token';
			case 'strings.legacy.msg_enter_name': return 'Please enter a name.';
			case 'strings.legacy.msg_api_url_incorrect': return 'API URL is incorrect.';
			case 'strings.legacy.msg_user_general_settings': return 'User General Settings';
			case 'strings.legacy.msg_saved_memo': return 'Saved as memo';
			case 'strings.legacy.msg_restore_failed': return ({required Object e}) => 'Restore failed: ${e}';
			case 'strings.legacy.msg_token_tail': return ({required Object tail}) => 'Token tail ${tail}';
			case 'strings.legacy.msg_manual_token': return 'Manual Token';
			case 'strings.legacy.msg_ago_2': return ({required Object years}) => '${years} ago';
			case 'strings.legacy.msg_recent_searches': return 'Recent searches';
			case 'strings.legacy.msg_restored': return 'Restored';
			case 'strings.legacy.msg_no_contributors_yet': return 'No contributors yet';
			case 'strings.legacy.msg_no_record_yet': return 'No record yet';
			case 'strings.legacy.msg_reminder': return 'Reminder';
			case 'strings.legacy.msg_enter_api_key_ai_settings': return 'Please enter API Key in AI settings';
			case 'strings.legacy.msg_reminder_settings': return 'Reminder Settings';
			case 'strings.legacy.msg_http_2': return ({required Object base, required Object status}) => '${base} (HTTP ${status})';
			case 'strings.legacy.msg_edit_webhook': return 'Edit Webhook';
			case 'strings.legacy.msg_generate_share_poster': return 'Generate share poster';
			case 'strings.legacy.msg_archive_failed': return ({required Object e}) => 'Archive failed: ${e}';
			case 'strings.legacy.msg_comments': return ({required Object widget_commentCount}) => '${widget_commentCount} comments';
			case 'strings.legacy.msg_remove_account': return 'Remove account?';
			case 'strings.legacy.msg_chinese_traditional': return 'Chinese (Traditional)';
			case 'strings.legacy.msg_private_2': return 'Private';
			case 'strings.legacy.msg_current_streak': return 'Current streak';
			case 'strings.legacy.msg_generated_ai_memoflow': return 'Generated by AI · MemoFlow';
			case 'strings.legacy.msg_edit_completed': return 'Edit completed';
			case 'strings.legacy.msg_local': return 'Local';
			case 'strings.legacy.msg_edit': return 'Edit';
			case 'strings.legacy.msg_text': return ({required Object shortUserName_item_sender}) => 'From ${shortUserName_item_sender}';
			case 'strings.legacy.msg_got': return 'Got it';
			case 'strings.legacy.msg_web_api_key': return 'Web API Key';
			case 'strings.legacy.msg_preview': return 'Preview';
			case 'strings.legacy.msg_enter_password': return 'Please enter password';
			case 'strings.legacy.msg_api': return 'API';
			case 'strings.legacy.msg_ok': return 'OK';
			case 'strings.legacy.msg_failed_load_shortcuts': return 'Failed to load shortcuts.';
			case 'strings.legacy.msg_after_recording_audio_added_current_draft': return 'After recording, the audio is added to the current draft as an attachment so you can edit before sending. Max length is 60 minutes; transcription can be added via third-party services later.';
			case 'strings.legacy.msg_pull_refresh': return 'Pull to Refresh';
			case 'strings.legacy.msg_unable_open_photo': return 'Unable to open photo';
			case 'strings.legacy.msg_existing_tokens': return 'Existing Tokens';
			case 'strings.legacy.msg_ai_settings': return 'AI Settings';
			case 'strings.legacy.msg_app_lock': return 'App Lock';
			case 'strings.legacy.msg_total_notes': return 'Total notes';
			case 'strings.legacy.msg_stats_loading': return 'Stats are loading';
			case 'strings.legacy.msg_enter_token_description': return 'Enter a token description';
			case 'strings.legacy.msg_enter_token': return 'Enter a token';
			case 'strings.legacy.msg_api_plugins': return 'API & Plugins';
			case 'strings.legacy.msg_parsing_file': return 'Parsing file...';
			case 'strings.legacy.msg_english': return 'English';
			case 'strings.legacy.msg_activity_heatmap': return 'Activity Heatmap';
			case 'strings.legacy.msg_mark_read': return 'Mark as read';
			case 'strings.legacy.msg_request': return 'Request';
			case 'strings.legacy.msg_sync_failed': return ({required Object type, required Object memoError}) => 'Sync failed (${type}): ${memoError}';
			case 'strings.legacy.msg_error_copied': return 'Error copied';
			case 'strings.legacy.msg_only_local_index_removed_disk_files': return 'Only local index will be removed; disk files are kept. This cannot be undone.';
			case 'strings.legacy.msg_switch_account': return 'Switch account';
			case 'strings.legacy.msg_invalid_download_link': return 'Invalid download link';
			case 'strings.legacy.msg_about': return 'About';
			case 'strings.legacy.msg_icon': return 'Icon';
			case 'strings.legacy.msg_reset_done_syncing': return 'Reset done. Syncing...';
			case 'strings.legacy.msg_enter_amap_web_api_key': return 'Enter your Amap Web API Key';
			case 'strings.legacy.msg_recycle_bin_coming_soon': return 'Recycle bin: coming soon';
			case 'strings.legacy.msg_empty_content': return '(Empty content)';
			case 'strings.legacy.msg_note_most_features_offline_stats_ai': return 'Note: Most features (offline/stats/AI reports/export) work without backend changes, but tokens are returned only once?please keep them safe.';
			case 'strings.legacy.msg_fixed': return 'Fixed: ';
			case 'strings.legacy.msg_allow_sharing_links_images_other_apps': return 'Allow sharing links or images from other apps into MemoFlow.';
			case 'strings.legacy.msg_invalid_request_parameters': return 'Invalid request parameters';
			case 'strings.legacy.msg_enter_api_url': return 'Please enter API URL';
			case 'strings.legacy.msg_pending': return ({required Object result_pendingCount}) => ' (pending ${result_pendingCount})';
			case 'strings.legacy.msg_days_3': return ({required Object currentStreak}) => '${currentStreak} days';
			case 'strings.legacy.msg_poster_not_ready_yet': return 'Poster is not ready yet';
			case 'strings.legacy.msg_generated_memoflow': return 'Generated by MemoFlow';
			case 'strings.legacy.msg_enter_name_2': return 'Enter a name';
			case 'strings.legacy.msg_version': return 'Version';
			case 'strings.legacy.msg_memo_missing_disk_but_has_local': return 'The memo is missing on disk but has local pending changes. Use disk to delete locally.';
			case 'strings.legacy.msg_legacy_api_compatibility': return 'Legacy API Compatibility';
			case 'strings.legacy.msg_sync_parameters': return 'Sync parameters';
			case 'strings.legacy.msg_quick_prompts': return 'Quick prompts';
			case 'strings.legacy.msg_share_failed': return ({required Object e}) => 'Share failed: ${e}';
			case 'strings.legacy.msg_no_memos_summarize_range': return 'No memos to summarize in this range';
			case 'strings.legacy.msg_characters': return 'Characters';
			case 'strings.legacy.msg_capture_every_moment_record': return 'Capture every moment you record';
			case 'strings.legacy.msg_vibration': return 'Vibration';
			case 'strings.legacy.msg_days_4': return 'days';
			case 'strings.legacy.msg_prompt_title': return 'Prompt title';
			case 'strings.legacy.msg_show_all': return 'Show all';
			case 'strings.legacy.msg_no_memos_available': return 'No memos available';
			case 'strings.legacy.msg_comment_unavailable': return 'Comment unavailable';
			case 'strings.legacy.msg_refresh': return 'Refresh';
			case 'strings.legacy.msg_syncing_2': return 'Syncing';
			case 'strings.legacy.msg_body': return 'Body';
			case 'strings.legacy.msg_clear_2': return 'Clear';
			case 'strings.legacy.msg_third_party_share': return 'Third-party Share';
			case 'strings.legacy.msg_charging_station': return 'Charging Station';
			case 'strings.legacy.msg_attachments_2': return 'Attachments';
			case 'strings.legacy.msg_when_enabled_must_verify_each_app': return 'When enabled, you must verify on each app launch. Auto-lock time controls how soon verification is required after the app goes to background.';
			case 'strings.legacy.msg_add_prompt': return 'Add prompt';
			case 'strings.legacy.msg_include': return 'Include';
			case 'strings.legacy.msg_created_time_2': return 'Created time ↓';
			case 'strings.legacy.msg_choose_data_source_start_importing_memos': return 'Choose a data source to start importing your memos';
			case 'strings.legacy.msg_describe_how_want_summary': return 'Describe how you want the summary…';
			case 'strings.legacy.msg_keep_token_safe_not_share_api': return 'Keep your token safe and do not share it.\\nAPI rate limit is 60 requests per minute.';
			case 'strings.legacy.msg_open_2': return 'Open';
			case 'strings.legacy.msg_e_g_claude_3_5_sonnet': return 'e.g. claude-3-5-sonnet-20241022';
			case 'strings.legacy.msg_failed_request_whitelist': return 'Failed to request whitelist';
			case 'strings.legacy.msg_notification_deleted': return 'Notification deleted';
			case 'strings.legacy.msg_accounts': return 'Accounts';
			case 'strings.legacy.msg_add_local_library': return 'Add local library';
			case 'strings.legacy.msg_sign_first': return 'Please sign in first';
			case 'strings.legacy.msg_failed_parse_query': return 'Failed to parse query';
			case 'strings.legacy.msg_note_logs_sanitized_automatically_sensitive_data': return 'Note: logs are sanitized automatically. If sensitive data remains, redact before submitting.';
			case 'strings.legacy.msg_add': return 'Add';
			case 'strings.legacy.msg_failed_load_3': return ({required Object memosError}) => 'Failed to load: ${memosError}';
			case 'strings.legacy.msg_max_chars_day': return 'Max chars/day';
			case 'strings.legacy.msg_choose_what_edited_image': return 'Choose what to do with the edited image.';
			case 'strings.legacy.msg_select': return 'Select';
			case 'strings.legacy.msg_unnamed_token': return '(Unnamed Token)';
			case 'strings.legacy.msg_name': return 'Name';
			case 'strings.legacy.msg_sure_want_delete_webhook': return 'Are you sure you want to delete this webhook?';
			case 'strings.legacy.msg_back': return 'Back';
			case 'strings.legacy.msg_no': return 'No';
			case 'strings.legacy.msg_untitled': return 'Untitled';
			case 'strings.legacy.msg_open_language_onboarding': return 'Open language onboarding';
			case 'strings.legacy.msg_voice_memos': return 'Voice Memos';
			case 'strings.legacy.msg_unable_open_browser_try': return 'Unable to open browser. Please try again.';
			case 'strings.legacy.msg_date_range': return 'Date Range';
			case 'strings.legacy.msg_not_authenticated': return 'Not authenticated';
			case 'strings.legacy.msg_back_2': return 'Back';
			case 'strings.legacy.msg_local_library_removed': return 'Local library removed';
			case 'strings.legacy.msg_exact_alarm_permission_required': return 'Exact alarm permission required';
			case 'strings.legacy.msg_visibility': return 'Visibility';
			case 'strings.legacy.msg_failed_start_recording': return ({required Object e}) => 'Failed to start recording: ${e}';
			case 'strings.legacy.msg_mood_trend': return 'Mood trend';
			case 'strings.legacy.msg_local_library_name': return 'Local library name';
			case 'strings.legacy.msg_no_tokens_yet': return 'No tokens yet';
			case 'strings.legacy.msg_loading_2': return 'Loading?';
			case 'strings.legacy.msg_location_permission_denied_permanently': return 'Location permission denied permanently';
			case 'strings.legacy.msg_download': return 'Download';
			case 'strings.legacy.msg_export_time': return '- Export time';
			case 'strings.legacy.msg_enter_password_2': return 'Enter password';
			case 'strings.legacy.msg_no_image_available': return 'No image available';
			case 'strings.legacy.msg_daily': return 'Daily';
			case 'strings.legacy.msg_no_likes_yet': return 'No likes yet';
			case 'strings.legacy.msg_basics': return 'Basics';
			case 'strings.legacy.msg_shortcut': return 'New shortcut';
			case 'strings.legacy.msg_debug_tools': return 'Debug Tools';
			case 'strings.legacy.msg_save_settings': return 'Save Settings';
			case 'strings.legacy.msg_date_range_2': return 'Date range';
			case 'strings.legacy.msg_feedback': return 'Feedback';
			case 'strings.legacy.msg_image_bed_2': return 'Image Bed';
			case 'strings.legacy.msg_restoring': return 'Restoring…';
			case 'strings.legacy.msg_export': return 'Export';
			case 'strings.legacy.msg_enter_token_name': return 'Please enter token name';
			case 'strings.legacy.msg_start_time': return 'Start time';
			case 'strings.legacy.msg_preparing_file_structure': return 'Preparing file structure';
			case 'strings.legacy.msg_sign_3': return 'Sign in';
			case 'strings.legacy.msg_scan_local_library': return 'Scan local library';
			case 'strings.legacy.msg_lsky_pro': return 'Lsky Pro';
			case 'strings.legacy.msg_exact_alarm_permission_off_reminders_may': return 'Exact alarm permission is off. Reminders may not fire on time. Open settings now?';
			case 'strings.legacy.msg_last_30_days': return 'Last 30 days';
			case 'strings.legacy.msg_match': return 'Match';
			case 'strings.legacy.msg_auth_mode': return 'Auth mode';
			case 'strings.legacy.msg_unsupported_file_type': return 'Unsupported file type.';
			case 'strings.legacy.msg_only_delete_sync_task': return 'Only delete the sync task.';
			case 'strings.legacy.msg_change_password': return 'Change Password';
			case 'strings.legacy.msg_saved_2': return 'Saved';
			case 'strings.legacy.msg_import_export': return 'Import / Export';
			case 'strings.legacy.msg_created_2': return 'Created';
			case 'strings.legacy.msg_ai_summary': return 'AI Summary';
			case 'strings.legacy.msg_progress': return 'Progress';
			case 'strings.legacy.msg_replace_memo_image': return 'Replace memo image';
			case 'strings.legacy.msg_app_settings': return 'App settings';
			case 'strings.legacy.msg_copy_path': return 'Copy path';
			case 'strings.legacy.msg_components': return 'Components';
			case 'strings.legacy.msg_no_shortcuts': return 'No shortcuts';
			case 'strings.legacy.msg_location_timed_try': return 'Location timed out. Please try again.';
			case 'strings.legacy.msg_attach_location_info_memos_show_subtle': return 'Attach location info to memos and show subtle place names.';
			case 'strings.legacy.msg_send_failed': return ({required Object e}) => 'Send failed: ${e}';
			case 'strings.legacy.msg_repeat': return 'Repeat';
			case 'strings.legacy.msg_not_signed': return 'Not signed in';
			case 'strings.legacy.msg_no_webhooks_configured': return 'No webhooks configured';
			case 'strings.legacy.msg_apply_token': return 'Apply token';
			case 'strings.legacy.msg_enable_reminder_permissions_2': return 'Enable reminder permissions';
			case 'strings.legacy.msg_enter_backup_password': return 'Enter backup password';
			case 'strings.legacy.msg_start_backup': return 'Start backup';
			case 'strings.legacy.msg_last_sync': return 'Last sync';
			case 'strings.legacy.msg_note_export_includes_content_already_synced': return 'Note: Export includes content already synced to the local database (offline data included).';
			case 'strings.legacy.msg_enter_username': return 'Enter username';
			case 'strings.legacy.msg_settings_saved': return 'Settings saved';
			case 'strings.legacy.msg_no_keywords': return 'No keywords';
			case 'strings.legacy.msg_these_settings_apply_newly_created_memos': return 'These settings apply to newly created memos.';
			case 'strings.legacy.msg_back_home': return 'Back to Home';
			case 'strings.legacy.msg_quiet_hours': return 'Quiet hours';
			case 'strings.legacy.msg_add_account': return 'Add Account';
			case 'strings.legacy.msg_reset_complete': return 'Reset complete';
			case 'strings.legacy.msg_no_shortcuts_configured': return 'No shortcuts configured';
			case 'strings.legacy.msg_password': return 'Password';
			case 'strings.legacy.msg_importing': return 'Importing';
			case 'strings.legacy.msg_visibility_2': return ({required Object visibilityLabel}) => 'Visibility: ${visibilityLabel}';
			case 'strings.legacy.msg_no_logs_yet': return 'No logs yet';
			case 'strings.legacy.msg_v_9_times_allowed': return 'Up to 9 times allowed';
			case 'strings.legacy.msg_last_14_days': return 'Last 14 days';
			case 'strings.legacy.msg_location_disabled_enable_settings_first': return 'Location is disabled. Enable it in settings first.';
			case 'strings.legacy.msg_add_2': return 'Add';
			case 'strings.legacy.msg_logs': return 'Logs';
			case 'strings.legacy.msg_references': return 'References';
			case 'strings.legacy.msg_importing_memos': return 'Importing memos...';
			case 'strings.legacy.msg_account_security': return 'Account & Security';
			case 'strings.legacy.msg_reminder_2': return 'Reminder';
			case 'strings.legacy.msg_enable_scheduled_reminder_notifications': return 'Enable scheduled reminder notifications.';
			case 'strings.legacy.msg_no_links': return 'No links';
			case 'strings.legacy.msg_delete_memo_2': return 'Delete memo';
			case 'strings.legacy.msg_one_tap_add_not_supported_add': return 'One-tap add not supported. Add it from the widget picker';
			case 'strings.legacy.msg_password_2': return 'New Password';
			case 'strings.legacy.msg_processing_content': return 'Processing content...';
			case 'strings.legacy.msg_status': return 'Status';
			case 'strings.legacy.msg_local_library_added': return 'Local library added';
			case 'strings.legacy.msg_failed_open_try': return 'Failed to open. Please try again.';
			case 'strings.legacy.msg_removed_locally_now_deleted_server_when': return 'It will be removed locally now and deleted on the server when online.';
			case 'strings.legacy.msg_server_url_unavailable': return 'Server URL unavailable';
			case 'strings.legacy.msg_no_release_notes_yet': return 'No release notes yet';
			case 'strings.legacy.msg_cancelling_2': return 'Cancelling...';
			case 'strings.legacy.msg_summaries_selected_range': return 'Summaries over selected range';
			case 'strings.legacy.msg_expand_2': return 'Expand';
			case 'strings.legacy.msg_close': return 'Close';
			case 'strings.legacy.msg_more_comments': return ({required Object remainingComments}) => '${remainingComments} more comments';
			case 'strings.legacy.msg_backing': return 'Backing up…';
			case 'strings.legacy.msg_view_debug_logs': return 'View debug logs';
			case 'strings.legacy.msg_location_permission_denied': return 'Location permission denied';
			case 'strings.legacy.msg_self_repair_reset_heatmap': return 'Self repair: reset heatmap';
			case 'strings.legacy.msg_these_settings_changed_locally_remotely_choose': return 'These settings changed locally and remotely. Choose which version to keep.';
			case 'strings.legacy.msg_not_authenticated_2': return 'Not authenticated.';
			case 'strings.legacy.msg_action_failed': return ({required Object e}) => 'Action failed: ${e}';
			case 'strings.legacy.msg_shortcut_2': return 'New Shortcut';
			case 'strings.legacy.msg_url': return 'URL';
			case 'strings.legacy.msg_no_memos_found_html': return 'No memos found in HTML.';
			case 'strings.legacy.msg_enter_what_want_summarize': return 'Enter what you want to summarize...';
			case 'strings.legacy.msg_unable_load_audio_source': return 'Unable to load audio source.';
			case 'strings.legacy.msg_strategy_id': return 'Strategy ID';
			case 'strings.legacy.msg_copy_failed': return ({required Object e}) => 'Copy failed: ${e}';
			case 'strings.legacy.msg_enable_image_bed': return 'Enable image bed';
			case 'strings.legacy.msg_active': return 'Active';
			case 'strings.legacy.msg_account': return 'Account';
			case 'strings.legacy.msg_invalid_webdav_server_url': return 'Invalid WebDAV server URL';
			case 'strings.legacy.msg_keep_local': return 'Keep local';
			case 'strings.legacy.msg_within_range': return 'Within range';
			case 'strings.legacy.msg_generate_log_file': return 'Generate log file';
			case 'strings.legacy.msg_ai_reports': return 'AI Reports';
			case 'strings.legacy.msg_battery_optimization': return 'Battery optimization';
			case 'strings.legacy.msg_sync_overview': return 'Sync overview';
			case 'strings.legacy.msg_legacy_servers_not_support_search_filters': return 'Legacy servers do not support search filters; results may be incomplete.';
			case 'strings.legacy.msg_conflicts_detected_run_manual_sync': return 'Conflicts detected. Run manual sync.';
			case 'strings.legacy.msg_authentication_failed_check_token': return 'Authentication failed. Check token.';
			case 'strings.legacy.msg_date_range_3': return 'Date range';
			case 'strings.legacy.msg_help_ai_understand_better': return 'Help AI understand you better';
			case 'strings.legacy.msg_no_search_history': return 'No search history';
			case 'strings.legacy.msg_enter_api_path': return 'Enter API path';
			case 'strings.legacy.msg_stats': return 'Stats';
			case 'strings.legacy.msg_text_2': return 'New: ';
			case 'strings.legacy.msg_removing_signing_clear_local_cache_account': return 'Removing/signing out will clear local cache for this account (offline data/drafts/pending sync queue).';
			case 'strings.legacy.msg_updated_time_2': return 'Updated time ↑';
			case 'strings.legacy.msg_province': return 'Province';
			case 'strings.legacy.msg_submitting_sync_queue': return 'Submitting sync queue';
			case 'strings.legacy.msg_failed': return 'Failed';
			case 'strings.legacy.msg_set_time': return 'Set time';
			case 'strings.legacy.msg_enable_local_library_backup': return 'Enable local library backup';
			case 'strings.legacy.msg_cancel_2': return 'Cancel';
			case 'strings.legacy.msg_week': return 'This Week';
			case 'strings.legacy.msg_like': return 'Like';
			case 'strings.legacy.msg_location_services_disabled': return 'Location services are disabled';
			case 'strings.legacy.msg_clears_local_cache_offline_memos_pending': return 'This clears local cache (offline memos/pending queue) and triggers a full resync. Unsynced content will be lost and it may take a while. Continue?';
			case 'strings.legacy.msg_load_more': return 'Load more';
			case 'strings.legacy.msg_pull_memo_list_refresh_sync_sync': return 'Pull down in the memo list to refresh and sync. Sync fetches the most recent items first; run a full sync periodically to keep stats/heatmap complete.';
			case 'strings.legacy.msg_server_returned_error': return ({required Object code}) => 'Server returned error (${code}).';
			case 'strings.legacy.msg_sound_feedback': return 'Sound & feedback';
			case 'strings.legacy.msg_memos_skipped_attachments_skipped': return ({required Object exportedMemoCount, required Object skippedMemoCount, required Object exportedAttachmentCount, required Object skippedAttachmentCount}) => '${exportedMemoCount} memos (skipped ${skippedMemoCount}), ${exportedAttachmentCount} attachments (skipped ${skippedAttachmentCount}).';
			case 'strings.legacy.msg_import_complete': return 'Import complete';
			case 'strings.legacy.msg_text_3': return 'New';
			case 'strings.legacy.msg_max_per_day': return 'Max per day';
			case 'strings.legacy.msg_permissions_denied': return 'Permissions denied';
			case 'strings.legacy.msg_memo_2': return 'New Memo';
			case 'strings.legacy.msg_delete_reminder': return 'Delete reminder';
			case 'strings.legacy.msg_select_month': return 'Select month';
			case 'strings.legacy.msg_select_backup': return 'Select backup';
			case 'strings.legacy.msg_no_keywords_2': return '#No keywords';
			case 'strings.legacy.msg_preparing_memo_content': return 'Preparing memo content';
			case 'strings.legacy.msg_prompt_content': return 'Prompt content';
			case 'strings.legacy.msg_default_prompt_ai_summaries_reports': return 'Default prompt for AI summaries/reports';
			case 'strings.legacy.msg_intro': return 'Intro';
			case 'strings.legacy.msg_monthly_stats': return 'Monthly stats';
			case 'strings.legacy.msg_times_2': return 'times';
			case 'strings.legacy.msg_file_has_already_been_imported_skipped': return 'This file has already been imported. Skipped.';
			case 'strings.legacy.msg_token_tail_unknown': return 'Token tail unknown';
			case 'strings.legacy.msg_press_back_exit': return 'Press back again to exit';
			case 'strings.legacy.msg_enter_password_3': return 'Enter password';
			case 'strings.legacy.msg_sync_conflicts': return 'Sync conflicts';
			case 'strings.legacy.msg_locale': return 'Locale';
			case 'strings.legacy.msg_any': return 'Any';
			case 'strings.legacy.msg_provider': return 'Provider';
			case 'strings.legacy.msg_preview_2': return 'Preview';
			case 'strings.legacy.msg_automatically_upload_images_append_links_memo': return 'Automatically upload images and append links to the memo.';
			case 'strings.legacy.msg_import_file_not_found': return 'Import file not found.';
			case 'strings.legacy.msg_today': return 'Today';
			case 'strings.legacy.msg_link_card': return 'Link Card';
			case 'strings.legacy.msg_expiration': return 'Expiration';
			case 'strings.legacy.msg_summary_prompt_optional': return 'Summary prompt (optional)';
			case 'strings.legacy.msg_memos': return 'Memos';
			case 'strings.legacy.msg_recording_file_not_found_2': return 'Recording file not found.';
			case 'strings.legacy.msg_backup_settings': return 'Backup settings';
			case 'strings.legacy.msg_mode': return 'Mode';
			case 'strings.legacy.msg_no_markdown_memos_found_zip': return 'No Markdown memos found in ZIP.';
			case 'strings.legacy.msg_archived': return 'Archived';
			case 'strings.legacy.msg_update_failed': return ({required Object e}) => 'Update failed: ${e}';
			case 'strings.legacy.msg_enable_app_lock': return 'Enable App Lock';
			case 'strings.legacy.msg_html_zip': return 'HTML / ZIP';
			case 'strings.legacy.msg_all': return 'All';
			case 'strings.legacy.msg_model': return 'Model';
			case 'strings.legacy.msg_title': return 'Title';
			case 'strings.legacy.msg_amap_web_api': return 'Amap Web API';
			case 'strings.legacy.msg_saved_gallery': return 'Saved to gallery';
			case 'strings.legacy.msg_unread': return 'Unread';
			case 'strings.legacy.msg_exporting': return 'Exporting...';
			case 'strings.legacy.msg_network_timeout_try': return 'Network timeout. Please try again.';
			case 'strings.legacy.msg_unlock': return 'Unlock';
			case 'strings.legacy.msg_ago_3': return ({required Object diff_inDays}) => '${diff_inDays} ago';
			case 'strings.legacy.msg_deserve_coffee_i_m_pulling_all': return 'To deserve this coffee, I\'m pulling an all-nighter to write 100 lines of code!';
			case 'strings.legacy.msg_token_name': return 'Token Name';
			case 'strings.legacy.msg_restore_completed': return 'Restore completed';
			case 'strings.legacy.msg_copied_clipboard': return 'Copied to clipboard';
			case 'strings.legacy.msg_failed_2': return ({required Object attempts}) => 'Failed ${attempts}';
			case 'strings.legacy.msg_too_many_requests_try_later': return 'Too many requests. Try again later.';
			case 'strings.legacy.msg_more': return 'More';
			case 'strings.legacy.msg_already_whitelisted': return 'Already whitelisted';
			case 'strings.legacy.msg_local_library_backup': return 'Local library backup';
			case 'strings.legacy.msg_awesome': return 'Awesome! ❤️';
			case 'strings.legacy.msg_now': return 'Now';
			case 'strings.legacy.msg_select_reminder_time': return 'Select reminder time';
			case 'strings.legacy.msg_protected': return 'Protected';
			case 'strings.legacy.msg_failed_load_4': return ({required Object e}) => 'Failed to load: ${e}';
			case 'strings.legacy.msg_operation_failed': return ({required Object e}) => 'Operation failed: ${e}';
			case 'strings.legacy.msg_no_tags': return 'No tags';
			case 'strings.legacy.msg_server': return 'Server';
			case 'strings.legacy.msg_improved': return 'Improved';
			case 'strings.legacy.msg_request_2': return 'Request';
			case 'strings.legacy.msg_export_failed': return ({required Object e}) => 'Export failed: ${e}';
			case 'strings.legacy.msg_notification_settings': return 'Notification settings';
			case 'strings.legacy.msg_related_memo_was_deleted': return 'The related memo was deleted';
			case 'strings.legacy.msg_email': return 'Email';
			case 'strings.legacy.msg_enter_password_4': return 'Please enter a password';
			case 'strings.legacy.msg_retry_count': return 'Retry Count';
			case 'strings.legacy.msg_import_exported_html_zip_package': return 'Import exported HTML or ZIP package';
			case 'strings.legacy.msg_archive': return 'Archive';
			case 'strings.legacy.msg_reset_heatmap': return 'Reset heatmap?';
			case 'strings.legacy.msg_token_applied': return 'Token applied';
			case 'strings.legacy.msg_log_file_created': return 'Log file created';
			case 'strings.legacy.msg_delete_sync_task': return 'Delete sync task';
			case 'strings.legacy.msg_include_archived_2': return '- Include archived';
			case 'strings.legacy.msg_memoflow_side_project_i_build_my': return 'MemoFlow is a side project I build in my spare time. I have been up late fixing bugs and could really use an iced Americano. Your support refuels my battery and helps new features ship ';
			case 'strings.legacy.msg_failed_generate': return ({required Object e}) => 'Failed to generate: ${e}';
			case 'strings.legacy.msg_search_logs': return 'Search logs';
			case 'strings.legacy.msg_active_days': return 'Active days';
			case 'strings.legacy.msg_back_top': return 'Back to top';
			case 'strings.legacy.msg_month': return 'This Month';
			case 'strings.legacy.msg_loading_references': return 'Loading references';
			case 'strings.legacy.msg_silent': return 'Silent';
			case 'strings.legacy.msg_settings': return 'Settings';
			case 'strings.legacy.msg_locating': return 'Locating...';
			case 'strings.legacy.msg_scan': return 'Scan';
			case 'strings.legacy.msg_recording_path_missing': return 'Recording path missing.';
			case 'strings.legacy.msg_date_range_4': return '- Date range';
			case 'strings.legacy.msg_suggested_tags': return 'Suggested tags';
			case 'strings.legacy.msg_energy_restored': return '⚡ ENERGY RESTORED';
			case 'strings.legacy.msg_username_2': return 'Username';
			case 'strings.legacy.msg_ai_summary_report': return 'AI Summary Report';
			case 'strings.legacy.msg_all_tags': return 'All Tags';
			case 'strings.legacy.msg_preferences': return 'Preferences';
			case 'strings.legacy.msg_image_bed_3': return 'Image Bed';
			case 'strings.legacy.msg_quick_input': return 'Quick Input';
			case 'strings.legacy.msg_tags': return 'Tags';
			case 'strings.legacy.msg_energy_critically_low': return 'Energy critically low!';
			case 'strings.legacy.msg_delete_failed': return ({required Object e}) => 'Delete failed: ${e}';
			case 'strings.legacy.msg_server_login': return 'Server Login';
			case 'strings.legacy.msg_like_2': return 'Like';
			case 'strings.legacy.msg_save_2': return 'Save';
			case 'strings.legacy.msg_unknown': return 'Unknown';
			case 'strings.legacy.msg_release_notes_2': return 'Release Notes';
			case 'strings.legacy.msg_include_error_details': return 'Include error details';
			case 'strings.legacy.msg_write_comment': return 'Write a comment...';
			case 'strings.legacy.msg_write_thoughts': return 'Write down your thoughts...';
			case 'strings.legacy.msg_local_2': return 'Local';
			case 'strings.legacy.msg_expired': return 'Expired';
			case 'strings.legacy.msg_fixed_2': return 'Fixed';
			case 'strings.legacy.msg_upload_attachment': return 'Upload attachment';
			case 'strings.legacy.msg_battery_whitelist': return 'Battery whitelist';
			case 'strings.legacy.msg_district': return 'District';
			case 'strings.legacy.msg_voice_memo': return '🎙️ Voice memo\\n';
			case 'strings.legacy.msg_system_default': return 'System default';
			case 'strings.legacy.msg_all_memos_2': return 'All memos';
			case 'strings.legacy.msg_network_request_failed': return 'Network request failed';
			case 'strings.legacy.msg_memo_not_found': return 'Memo not found';
			case 'strings.legacy.msg_playback_failed_2': return ({required Object e}) => 'Playback failed: ${e}';
			case 'strings.legacy.msg_sync_settings_webdav_across_devices': return 'Sync settings to WebDAV across devices.';
			case 'strings.legacy.msg_offline_first_client_memos_backend': return 'An offline-first client for the Memos backend.';
			case 'strings.legacy.msg_user_guide': return 'User Guide';
			case 'strings.legacy.msg_notice': return 'Notice';
			case 'strings.legacy.msg_exact_alarms': return 'Exact alarms';
			case 'strings.legacy.msg_restoring_overwrite_local_library_files_rebuild': return 'Restoring will overwrite local library files and rebuild the database. This cannot be undone.';
			case 'strings.legacy.msg_enter_api_url_ai_settings': return 'Please enter API URL in AI settings';
			case 'strings.legacy.msg_create_failed_2': return ({required Object e}) => 'Create failed: ${e}';
			case 'strings.legacy.msg_close_search': return 'Close search';
			case 'strings.legacy.msg_imported_memos_2': return 'Imported memos';
			case 'strings.legacy.msg_explore': return 'Explore';
			case 'strings.legacy.msg_network_connection_failed': return 'Network connection failed.';
			case 'strings.legacy.msg_save_failed_3': return ({required Object e}) => 'Save failed: ${e}';
			case 'strings.legacy.msg_no_summary_share': return 'No summary to share';
			case 'strings.legacy.msg_custom_model': return 'Custom Model';
			case 'strings.legacy.msg_sign_failed': return ({required Object message}) => 'Sign-in failed: ${message}';
			case 'strings.legacy.msg_notification_exact_alarm_permissions_required_send': return 'Notification and exact alarm permissions are required to send reminders on time.';
			case 'strings.legacy.msg_random_review': return 'Random Review';
			case 'strings.legacy.msg_public': return 'Public';
			case 'strings.legacy.msg_all_2': return 'All';
			case 'strings.legacy.msg_add_custom_model': return 'Add custom model';
			case 'strings.legacy.msg_backup_password': return 'Backup password';
			case 'strings.legacy.msg_optional_used_sign_requests': return 'Optional. Used to sign requests.';
			case 'strings.legacy.msg_search': return 'Search';
			case 'strings.legacy.msg_set_password': return 'Set Password';
			case 'strings.legacy.msg_submit_logs': return 'Submit Logs';
			case 'strings.legacy.msg_activity_heatmap_2': return 'ACTIVITY HEATMAP';
			case 'strings.legacy.msg_invalid_api_key_insufficient_permissions': return 'Invalid API key or insufficient permissions.';
			case 'strings.legacy.msg_data_has_been_migrated_app_successfully': return 'Your data has been migrated to this app successfully.';
			case 'strings.legacy.msg_get_version': return 'Get the new version';
			case 'strings.legacy.msg_token_source': return 'Token Source';
			case 'strings.legacy.msg_send': return 'Send';
			case 'strings.legacy.msg_no_pending_sync_tasks': return 'No pending sync tasks';
			case 'strings.legacy.msg_locating_memo_content': return 'Locating memo content';
			case 'strings.legacy.msg_offline_ready': return 'Offline Ready';
			case 'strings.legacy.msg_use_relative_path': return 'Use a relative path';
			case 'strings.legacy.msg_total': return 'Total';
			case 'strings.legacy.msg_location_2': return 'Location';
			case 'strings.legacy.msg_show_location_metadata_memos_not_configured': return 'Show location metadata on memos. If not configured, coordinates will be shown instead.';
			case 'strings.legacy.msg_api_url': return 'API URL';
			case 'strings.legacy.msg_parsing_progress': return 'Parsing progress';
			case 'strings.legacy.msg_parsing': return 'Parsing';
			case 'strings.legacy.msg_custom': return 'Custom';
			case 'strings.legacy.msg_tags_created': return 'New tags created';
			case 'strings.legacy.msg_third_party_share_disabled': return 'Third-party share is disabled';
			case 'strings.legacy.msg_loading_links': return 'Loading links...';
			case 'strings.legacy.msg_how_report': return 'How to report?';
			case 'strings.legacy.msg_confirm_password_2': return 'Confirm password';
			case 'strings.legacy.msg_search_title_content_tags': return 'Search by title, content, or tags';
			case 'strings.legacy.msg_reset_failed': return ({required Object e}) => 'Reset failed: ${e}';
			case 'strings.legacy.msg_debug_preview_update_dialog': return 'Debug: Preview update dialog';
			case 'strings.legacy.msg_what_s': return 'What\'s new?';
			case 'strings.legacy.msg_ringtone': return 'Ringtone';
			case 'strings.legacy.msg_unable_detect_backend_version_check_server': return 'Unable to detect backend version. Check the server URL or network.';
			case 'strings.legacy.msg_pending_2': return 'Pending';
			case 'strings.legacy.msg_parsing_html': return 'Parsing HTML...';
			case 'strings.legacy.msg_actions': return 'Actions';
			case 'strings.legacy.msg_import_complete_2': return 'Import Complete';
			case 'strings.legacy.msg_use_disk': return 'Use disk';
			case 'strings.legacy.msg_root_path': return 'Root path';
			case 'strings.legacy.msg_disabled': return 'Disabled';
			case 'strings.legacy.msg_improved_2': return 'Improved: ';
			case 'strings.legacy.msg_city': return 'City';
			case 'strings.legacy.msg_decoding_zip': return 'Decoding ZIP...';
			case 'strings.legacy.msg_notification_content': return 'Notification content';
			case 'strings.legacy.msg_resolve_conflict': return 'Resolve conflict';
			case 'strings.legacy.msg_webhooks_not_supported_server': return 'Webhooks are not supported on this server.';
			case 'strings.legacy.msg_may_delayed': return ' (may be delayed)';
			case 'strings.legacy.msg_permissions_system_settings': return 'Permissions & system settings';
			case 'strings.legacy.msg_waiting_tasks_stop': return 'Waiting for tasks to stop';
			case 'strings.legacy.msg_done_2': return 'Done';
			case 'strings.legacy.msg_parsing_memoflow_export': return 'Parsing MemoFlow export...';
			case 'strings.legacy.msg_location_updated': return ({required Object next_displayText_fractionDigits_6}) => 'Location updated: ${next_displayText_fractionDigits_6}';
			case 'strings.legacy.msg_checking_server_version': return 'Checking server version...';
			case 'strings.legacy.msg_next_time_back_fixing_bugs': return '👀 Next time, back to fixing bugs';
			case 'strings.legacy.msg_ago_4': return ({required Object weeks}) => '${weeks} ago';
			case 'strings.legacy.msg_import': return 'Import';
			case 'strings.legacy.msg_ios_long_press_home_screen_add': return 'On iOS, long-press the home screen to add MemoFlow widgets';
			case 'strings.legacy.msg_create_token_2': return 'Create Token';
			case 'strings.legacy.msg_marked_read': return 'Marked as read';
			case 'strings.legacy.msg_pinned': return 'Pinned';
			case 'strings.legacy.msg_version_update': return 'Version update';
			case 'strings.legacy.msg_allow_private_memos': return 'Allow private memos';
			case 'strings.legacy.msg_token_copied_clipboard': return 'Token copied to clipboard';
			case 'strings.legacy.msg_keeping_more_versions_uses_more_storage': return 'Keeping more versions uses more storage. Consider cleaning old versions.';
			case 'strings.legacy.msg_delete_webhook': return 'Delete Webhook';
			case 'strings.legacy.msg_prompt': return 'Prompt';
			case 'strings.legacy.msg_location_precision': return 'Location precision';
			case 'strings.legacy.msg_password_required': return 'Password required';
			case 'strings.legacy.msg_exit_app': return 'Exit app';
			case 'strings.legacy.msg_thanks_energy_fully_restored': return 'Thanks! Energy fully restored ⚡';
			case 'strings.legacy.msg_connection_timeout_check_network_api_url': return 'Connection timeout. Check network or API URL.';
			case 'strings.legacy.app_language.system': return 'Follow System';
			case 'strings.legacy.app_language.zh_hans': return 'Chinese (Simplified)';
			case 'strings.legacy.app_language.zh_hant_tw': return 'Chinese (Traditional, China Taiwan)';
			case 'strings.legacy.app_language.en': return 'English';
			case 'strings.legacy.app_language.ja': return 'Japanese';
			case 'strings.legacy.app_language.de': return 'German';
			case 'strings.legacy.app_theme.system': return 'System';
			case 'strings.legacy.app_theme.light': return 'Light';
			case 'strings.legacy.app_theme.dark': return 'Dark';
			case 'strings.legacy.app_font_size.standard': return 'Standard';
			case 'strings.legacy.app_font_size.large': return 'Large';
			case 'strings.legacy.app_font_size.small': return 'Small';
			case 'strings.legacy.app_line_height.classic': return 'Classic';
			case 'strings.legacy.app_line_height.compact': return 'Compact';
			case 'strings.legacy.app_line_height.relaxed': return 'Relaxed';
			case 'strings.legacy.launch_action.none': return 'None';
			case 'strings.legacy.launch_action.sync': return 'Sync';
			case 'strings.legacy.launch_action.quick_input': return 'Quick Input';
			case 'strings.legacy.launch_action.daily_review': return 'Random Review';
			case 'strings.legacy.auto_lock_time.immediately': return 'Immediately';
			case 'strings.legacy.auto_lock_time.after_1_min': return '1 minute';
			case 'strings.legacy.auto_lock_time.after_5_min': return '5 minutes';
			case 'strings.legacy.auto_lock_time.after_15_min': return '15 minutes';
			case 'strings.legacy.reminder.default_title': return 'Hey, remember this idea?';
			case 'strings.legacy.reminder.default_body': return 'Tap to view details';
			case 'strings.legacy.location.current': return 'Current location';
			case 'strings.legacy.webdav.not_configured': return 'WebDAV is not configured';
			case 'strings.legacy.webdav.backup_disabled': return 'Backup is disabled';
			case 'strings.legacy.webdav.backup_account_missing': return 'Account missing for backup';
			case 'strings.legacy.webdav.backup_local_only': return 'Backup is available only for local libraries';
			case 'strings.legacy.webdav.backup_password_missing': return 'Backup password missing';
			case 'strings.legacy.webdav.backup_no_memo_files': return 'No memo files found in local library; backup cancelled';
			case 'strings.legacy.webdav.restore_account_missing': return 'Account missing for restore';
			case 'strings.legacy.webdav.restore_local_only': return 'Restore is only available for local libraries';
			case 'strings.legacy.webdav.backup_empty': return 'Backup is empty';
			case 'strings.legacy.webdav.backup_no_memos': return 'No memos found in backup';
			case 'strings.legacy.webdav.snapshot_missing': return 'Backup snapshot missing';
			case 'strings.legacy.webdav.snapshot_corrupted': return 'Backup snapshot corrupted';
			case 'strings.legacy.webdav.object_missing': return 'Backup object missing';
			case 'strings.legacy.webdav.config_corrupted': return 'Backup config corrupted';
			case 'strings.legacy.webdav.config_invalid': return 'Invalid backup config';
			case 'strings.legacy.webdav.password_invalid': return 'Invalid backup password';
			case 'strings.legacy.webdav.data_corrupted': return 'Backup data corrupted';
			case 'strings.legacy.webdav.server_url_invalid': return 'Invalid WebDAV server URL';
			case 'strings.legacy.import_count_memos': return ({required Object count}) => '${count}';
			case 'strings.legacy.import_count_attachments': return ({required Object count}) => '${count}';
			case 'strings.legacy.app_drawer.tooltip_single': return ({required Object date, required Object weekday, required Object count}) => '${date} (${weekday}) · ${count} memo';
			case 'strings.legacy.app_drawer.tooltip_multi': return ({required Object date, required Object weekday, required Object count}) => '${date} (${weekday}) · ${count} memos';
			case 'strings.legacy.ai_summary.error_api_key_empty': return 'API key is empty';
			case 'strings.legacy.ai_summary.system.require_json': return 'Please output JSON strictly. Do not use code blocks or extra text.';
			case 'strings.legacy.ai_summary.system.json_format': return 'JSON format: {"insights":["..."],"moodTrend":"...","keywords":["#..."]}';
			case 'strings.legacy.ai_summary.system.insights_rule': return 'insights should be 2-5 items; keywords should be 4-8 items with #.';
			case 'strings.legacy.ai_summary.user.range': return ({required Object rangeLabel}) => 'Time range: ${rangeLabel}';
			case 'strings.legacy.ai_summary.user.counts': return ({required Object memoCount, required Object includedCount}) => 'Memos: ${memoCount} (included for summary: ${includedCount})';
			case 'strings.legacy.ai_summary.user.profile': return ({required Object profile}) => 'User profile: ${profile}';
			case 'strings.legacy.ai_summary.user.custom_prompt': return ({required Object customPrompt}) => 'Additional instructions: ${customPrompt}';
			case 'strings.legacy.ai_summary.user.memo_content': return 'Memo content:';
			case 'strings.legacy.ai_summary.error_invalid_response': return 'AI response has an invalid format';
			case 'strings.legacy.ai_summary.error_empty_response': return 'AI response is empty';
			case 'strings.legacy.ai_summary.error_missing_content': return 'AI response content is missing';
			case 'strings.legacy.ai_summary.default_prompt': return 'You are a minimalist note assistant. Extract key points and present them in a clean format. Keep the tone professional, warm, and concise. Prefer lists and short paragraphs.';
			default: return null;
		}
	}
}

extension on _StringsDe {
	dynamic _flatMapFunction(String path) {
		switch (path) {
			case 'strings.common.back': return 'Zurück';
			case 'strings.common.cancel': return 'Abbrechen';
			case 'strings.common.confirm': return 'Bestätigen';
			case 'strings.common.save': return 'Speichern';
			case 'strings.common.saveSettings': return 'Einstellungen speichern';
			case 'strings.common.auto': return 'Automatisch';
			case 'strings.common.manual': return 'Manuell';
			case 'strings.common.copiedToClipboard': return 'In die Zwischenablage kopiert';
			case 'strings.common.serverVersion': return 'Serverversion';
			case 'strings.common.selectValidServerVersion': return 'Bitte eine gültige Serverversion auswählen';
			case 'strings.common.serverVersionValue': return ({required Object version}) => 'Serverversion: ${version}';
			case 'strings.common.selectServerVersionRange021To026': return 'Bitte wählen Sie manuell eine Serverversion zwischen 0.21 und 0.26';
			case 'strings.languages.system': return 'System folgen';
			case 'strings.languages.zhHans': return 'Chinesisch (Vereinfacht)';
			case 'strings.languages.zhHantTw': return 'Chinesisch (Traditionell, China Taiwan)';
			case 'strings.languages.en': return 'Englisch';
			case 'strings.languages.ja': return 'Japanisch';
			case 'strings.languages.de': return 'Deutsch';
			case 'strings.languagesNative.system': return 'System';
			case 'strings.languagesNative.zhHans': return '简体中文';
			case 'strings.languagesNative.zhHantTw': return '繁體中文（中國台灣）';
			case 'strings.languagesNative.en': return 'English';
			case 'strings.languagesNative.ja': return '日本語';
			case 'strings.languagesNative.de': return 'Deutsch';
			case 'strings.onboarding.tagline': return 'Minimaler, leistungsstarker Notiz-Stream';
			case 'strings.onboarding.selectLanguage': return 'Sprache auswählen';
			case 'strings.onboarding.selectMode': return 'Modus wählen';
			case 'strings.onboarding.modeHint': return 'Sie können dies später in den Einstellungen ändern.';
			case 'strings.onboarding.modeLocalTitle': return 'Lokaler Modus';
			case 'strings.onboarding.modeLocalLabel': return 'LOKALER MODUS';
			case 'strings.onboarding.modeLocalDesc': return 'Daten bleiben auf dem Gerät. Keine Server-Einrichtung erforderlich – ideal für Datenschutz und Offline-Nutzung.';
			case 'strings.onboarding.modeServerTitle': return 'Servermodus';
			case 'strings.onboarding.modeServerLabel': return 'SERVERMODUS';
			case 'strings.onboarding.modeServerDesc': return 'Verbinden Sie Ihr Memos-Backend für die Echtzeit-Synchronisierung auf mehreren Geräten.';
			case 'strings.onboarding.localLibraryNameTitle': return 'Name der lokalen Bibliothek';
			case 'strings.onboarding.localLibraryNameHint': return 'Name eingeben';
			case 'strings.onboarding.localLibraryDefaultName': return 'Lokale Bibliothek';
			case 'strings.onboarding.getStarted': return 'Loslegen';
			case 'strings.login.title': return 'Mit Memos verbinden';
			case 'strings.login.mode.password': return 'Benutzername & Passwort';
			case 'strings.login.mode.token': return 'Token';
			case 'strings.login.mode.descPassword': return 'Mit Benutzername und Passwort anmelden';
			case 'strings.login.mode.descToken': return 'Mit Personal Access Token anmelden';
			case 'strings.login.mode.signInMethod': return 'Anmeldeart';
			case 'strings.login.field.serverUrlLabel': return 'Server-URL';
			case 'strings.login.field.serverUrlHint': return 'http://localhost:5230';
			case 'strings.login.field.usernameLabel': return 'Benutzername';
			case 'strings.login.field.usernameHint': return 'Benutzernamen eingeben';
			case 'strings.login.field.passwordLabel': return 'Passwort';
			case 'strings.login.field.passwordHint': return 'Passwort eingeben';
			case 'strings.login.field.tokenLabel': return 'Token (PAT)';
			case 'strings.login.field.tokenHint': return 'Token (PAT)';
			case 'strings.login.validation.serverUrlRequired': return 'Bitte Server-URL eingeben';
			case 'strings.login.validation.serverUrlInvalid': return 'Bitte vollständige URL eingeben (inkl. http/https und Port)';
			case 'strings.login.validation.usernameRequired': return 'Bitte Benutzernamen eingeben';
			case 'strings.login.validation.passwordRequired': return 'Bitte Passwort eingeben';
			case 'strings.login.validation.tokenRequired': return 'Bitte Token eingeben';
			case 'strings.login.compatibility.title': return 'Kompatibilitätsmodus';
			case 'strings.login.compatibility.description': return 'Legacy-Endpunkte verwenden (für ältere Memos-Server)';
			case 'strings.login.connect.connecting': return 'Verbindung wird hergestellt…';
			case 'strings.login.connect.action': return 'Verbinden';
			case 'strings.login.errors.authFailedToken': return 'Authentifizierung fehlgeschlagen. Prüfen Sie, ob das Token gültig und nicht abgelaufen ist.';
			case 'strings.login.errors.authFailedPat': return 'Authentifizierung fehlgeschlagen. Für neue Memos ein PAT verwenden, das mit memos_pat_ beginnt (den Bearer-Präfix nicht einfügen).';
			case 'strings.login.errors.connectionFailedWithMessage': return ({required Object message}) => 'Verbindung fehlgeschlagen: ${message}';
			case 'strings.login.errors.connectionFailed': return ({required Object error}) => 'Verbindung fehlgeschlagen: ${error}';
			case 'strings.login.errors.signInFailed': return 'Anmeldung fehlgeschlagen. Benutzername und Passwort prüfen.';
			case 'strings.login.errors.signInFailedWithMessage': return ({required Object message}) => 'Anmeldung fehlgeschlagen: ${message}';
			case 'strings.login.errors.invalidServerUrl': return 'Ungültige Server-URL';
			case 'strings.login.errors.serverUrlNormalized': return 'Server-URL normalisiert (zusätzliche Pfadsegmente entfernt)';
			case 'strings.settings.preferences.title': return 'Einstellungen';
			case 'strings.settings.preferences.language': return 'Sprache';
			case 'strings.settings.preferences.fontSize': return 'Schriftgröße';
			case 'strings.settings.preferences.lineHeight': return 'Zeilenhöhe';
			case 'strings.settings.preferences.font': return 'Schriftart';
			case 'strings.settings.preferences.systemDefault': return 'Systemstandard';
			case 'strings.settings.preferences.noSystemFonts': return 'Keine Systemschriftarten gefunden';
			case 'strings.settings.preferences.loadFontsFailed': return ({required Object error}) => 'Schriftarten konnten nicht geladen werden: ${error}';
			case 'strings.settings.preferences.collapseLongContent': return 'Lange Inhalte einklappen';
			case 'strings.settings.preferences.collapseReferences': return 'Referenzen einklappen';
			case 'strings.settings.preferences.showEngagementInAllMemoDetails': return 'Likes und Kommentare in allen Memo-Details anzeigen';
			case 'strings.settings.preferences.launchAction': return 'Aktion beim Start';
			case 'strings.settings.preferences.quickInputKeyboard': return 'Tastatur bei Schnellnotiz automatisch öffnen';
			case 'strings.settings.preferences.appearance': return 'Darstellung';
			case 'strings.settings.preferences.themeColor': return 'Themenfarbe';
			case 'strings.settings.preferences.haptics': return 'Haptik';
			case 'strings.settings.preferences.customTheme': return 'Benutzerdefiniertes Thema';
			case 'strings.settings.preferences.history': return 'Verlauf';
			case 'strings.settings.preferences.lightMode': return 'Heller Modus';
			case 'strings.settings.preferences.darkMode': return 'Dunkler Modus';
			case 'strings.settings.preferences.surfaces': return 'Oberflächen';
			case 'strings.settings.preferences.background': return 'Hintergrund';
			case 'strings.settings.preferences.backgroundColor': return 'Hintergrundfarbe';
			case 'strings.settings.preferences.card': return 'Karte';
			case 'strings.settings.preferences.cardColor': return 'Kartenfarbe';
			case 'strings.settings.preferences.border': return 'Rahmen';
			case 'strings.settings.preferences.borderColor': return 'Rahmenfarbe';
			case 'strings.legacy.msg_memos_backend_docs': return 'MemoFlow-Backend-Dokumentation';
			case 'strings.legacy.msg_remember_moment_feel_warmth_life_take': return 'Erinnere dich an den Moment und spüre die Wärme des Lebens.\\nMach jeden Tag eine kurze Rückschau.';
			case 'strings.legacy.msg_sure_want_delete_shortcut': return 'Möchten Sie diese Verknüpfung wirklich löschen?';
			case 'strings.legacy.msg_scan_completed': return 'Scan abgeschlossen';
			case 'strings.legacy.msg_confirm': return 'Bestätigen';
			case 'strings.legacy.msg_unable_open_browser_install_browser_app': return 'Browser kann nicht geöffnet werden. Bitte installieren Sie eine Browser-App.';
			case 'strings.legacy.msg_contributors': return 'Mitwirkende';
			case 'strings.legacy.msg_enter_keywords_search_box_query_local': return 'Geben Sie Schlüsselwörter in das Suchfeld ein, um lokale Inhalte und Tags zu durchsuchen. Funktioniert offline; warten Sie bei der ersten Nutzung, bis die lokale Indizierung abgeschlossen ist.';
			case 'strings.legacy.msg_memo_not_found_locally': return 'Memo lokal nicht gefunden';
			case 'strings.legacy.msg_token': return 'Token';
			case 'strings.legacy.msg_last_7_days': return 'Letzte 7 Tage';
			case 'strings.legacy.msg_search_memo_content': return 'Memo-Inhalt durchsuchen';
			case 'strings.legacy.msg_retry_started': return 'Erneuter Versuch gestartet';
			case 'strings.legacy.msg_last_year_memos': return ({required Object lastYearMemos}) => 'Letztes Jahr: ${lastYearMemos} Memos';
			case 'strings.legacy.msg_no_content_yet': return 'Noch kein Inhalt';
			case 'strings.legacy.msg_no_summary_yet': return 'Noch keine Zusammenfassung';
			case 'strings.legacy.msg_sooner': return ' früher!';
			case 'strings.legacy.msg_token_copied': return 'Token kopiert';
			case 'strings.legacy.msg_share': return 'Teilen';
			case 'strings.legacy.msg_gallery_permission_required': return 'Galerieberechtigung erforderlich';
			case 'strings.legacy.msg_basic_settings': return 'Grundeinstellungen';
			case 'strings.legacy.msg_bad_ssl_certificate': return 'Ungültiges SSL-Zertifikat.';
			case 'strings.legacy.msg_no_notifications': return 'Keine Benachrichtigungen';
			case 'strings.legacy.msg_import_markdown': return 'Aus Markdown importieren';
			case 'strings.legacy.msg_upload_zip_package_md_files': return 'Laden Sie ein .zip-Paket mit .md-Dateien hoch';
			case 'strings.legacy.msg_request_send_timeout_try': return 'Zeitüberschreitung beim Senden der Anfrage. Versuchen Sie es erneut.';
			case 'strings.legacy.msg_select_date_range': return 'Datumsbereich auswählen';
			case 'strings.legacy.msg_delete_shortcut': return 'Verknüpfung löschen';
			case 'strings.legacy.msg_auto_lock_time': return 'Zeit bis zur automatischen Sperre';
			case 'strings.legacy.msg_replacing_delete_original_attachment_continue': return 'Beim Ersetzen wird der ursprüngliche Anhang gelöscht. Fortfahren?';
			case 'strings.legacy.msg_add_least_one_condition': return 'Bitte fügen Sie mindestens eine Bedingung hinzu.';
			case 'strings.legacy.msg_upload_images_image_bed_append_links': return 'Laden Sie Bilder in den Bildspeicher hoch und fügen Sie Links zum Memo hinzu.';
			case 'strings.legacy.msg_request_cancelled': return 'Anfrage abgebrochen.';
			case 'strings.legacy.msg_generating': return 'Wird generiert?';
			case 'strings.legacy.msg_permissions_denied_reminders_disabled': return 'Berechtigungen verweigert. Erinnerungen deaktiviert.';
			case 'strings.legacy.msg_memoflow_local_reminders': return 'MemoFlow lokale Erinnerungen';
			case 'strings.legacy.msg_use_legacy_endpoints_older_memos_servers': return 'Verwenden Sie Legacy-Endpunkte (für ältere Memos-Server).';
			case 'strings.legacy.msg_no_comments_yet': return 'Noch keine Kommentare';
			case 'strings.legacy.msg_open': return 'Öffnen';
			case 'strings.legacy.msg_microphone_permission_required': return 'Mikrofonberechtigung erforderlich';
			case 'strings.legacy.msg_failed_react': return ({required Object e}) => 'Reaktion fehlgeschlagen: ${e}';
			case 'strings.legacy.msg_restore_backup': return 'Backup wiederherstellen?';
			case 'strings.legacy.msg_qr_saved_gallery': return 'QR in Galerie gespeichert';
			case 'strings.legacy.msg_no_attachments': return 'Keine Anhänge';
			case 'strings.legacy.msg_enable_reminder_permissions': return 'Erinnerungsberechtigungen aktivieren';
			case 'strings.legacy.msg_created_time': return 'Erstellungszeit ↑';
			case 'strings.legacy.msg_prompt_saved_quick_prompts': return 'Ihr Prompt wird in den Schnell-Prompts gespeichert';
			case 'strings.legacy.msg_remember_password': return 'Passwort merken';
			case 'strings.legacy.msg_enter_valid_url': return 'Bitte geben Sie eine gültige URL ein';
			case 'strings.legacy.msg_may_take_few_seconds': return 'Dies kann einige Sekunden dauern';
			case 'strings.legacy.msg_local_sync_failed': return ({required Object type, required Object memoError}) => 'Lokale Synchronisierung fehlgeschlagen (${type}): ${memoError}';
			case 'strings.legacy.msg_webdav_sync': return 'WebDAV-Synchronisierung';
			case 'strings.legacy.msg_clear': return 'Löschen';
			case 'strings.legacy.msg_clear_recycle_bin_confirm': return 'Papierkorb leeren? Alle Einträge werden dauerhaft gelöscht.';
			case 'strings.legacy.msg_save_failed': return 'Speichern fehlgeschlagen';
			case 'strings.legacy.msg_endpoint_not_found_version_mismatch': return 'Endpunkt nicht gefunden (Versionskonflikt?)';
			case 'strings.legacy.msg_enable_webdav_sync': return 'WebDAV-Synchronisierung aktivieren';
			case 'strings.legacy.msg_local_libraries': return 'Lokale Bibliotheken';
			case 'strings.legacy.msg_apply': return 'Anwenden';
			case 'strings.legacy.msg_restore_only_available_local_libraries': return 'Wiederherstellung ist nur für lokale Bibliotheken verfügbar.';
			case 'strings.legacy.msg_sign': return 'Abmelden?';
			case 'strings.legacy.msg_reminders_disabled': return 'Erinnerungen sind deaktiviert';
			case 'strings.legacy.msg_downloading': return 'Wird heruntergeladen...';
			case 'strings.legacy.msg_path': return 'Pfad';
			case 'strings.legacy.msg_match_any': return 'Beliebige Übereinstimmung';
			case 'strings.legacy.msg_local_db_pending_queue': return 'Lokale DB + ausstehende Warteschlange';
			case 'strings.legacy.msg_scan_failed': return ({required Object e}) => 'Scan fehlgeschlagen: ${e}';
			case 'strings.legacy.msg_user': return 'Benutzer';
			case 'strings.legacy.msg_pick_future_time': return 'Wählen Sie einen zukünftigen Zeitpunkt';
			case 'strings.legacy.msg_include_pending_queue': return 'Ausstehende Warteschlange einschließen';
			case 'strings.legacy.msg_enter_days': return 'Tage eingeben';
			case 'strings.legacy.msg_times': return 'Zeiten';
			case 'strings.legacy.msg_token_returned_only_once_cannot_fetched': return 'Das Token wird nur einmal zurückgegeben und kann nicht erneut abgerufen werden';
			case 'strings.legacy.msg_quoted_lines': return ({required Object quoteLines}) => 'Zitierte ${quoteLines} Zeilen';
			case 'strings.legacy.msg_use_remote': return 'Remote verwenden';
			case 'strings.legacy.msg_enable_memo_location': return 'Memo-Standort aktivieren';
			case 'strings.legacy.msg_failed_get_location': return 'Standort konnte nicht abgerufen werden';
			case 'strings.legacy.msg_after_import_memos_sync_list_automatically': return 'Nach dem Import werden Ihre Memos automatisch mit der Liste synchronisiert. Stellen Sie bei ZIP-Importen sicher, dass die Dateistruktur intakt ist.';
			case 'strings.legacy.msg_legacy_mode': return 'Legacy-Modus';
			case 'strings.legacy.msg_signed': return 'Angemeldet';
			case 'strings.legacy.msg_shortcut_includes_advanced_conditions_saving_overwrite': return 'Diese Verknüpfung enthält erweiterte Bedingungen. Beim Speichern werden sie überschrieben.';
			case 'strings.legacy.msg_no_results_found': return 'Keine Ergebnisse gefunden';
			case 'strings.legacy.msg_reply': return ({required Object replyName}) => 'Antworten ${replyName}...';
			case 'strings.legacy.msg_copy': return 'Kopieren';
			case 'strings.legacy.msg_enable_reminders_memos': return 'Erinnerungen für deine Memos aktivieren.';
			case 'strings.legacy.msg_comment': return 'Kommentar';
			case 'strings.legacy.msg_added_voice_attachment': return 'Sprachanhang hinzugefügt.';
			case 'strings.legacy.msg_customize_sidebar': return 'Seitenleiste anpassen';
			case 'strings.legacy.msg_coffee_add_drumstick': return '☕ Dann eben Kaffee / füge einen Drumstick hinzu';
			case 'strings.legacy.msg_pin': return 'Anheften';
			case 'strings.legacy.msg_enter_password_continue': return 'Passwort eingeben, um fortzufahren';
			case 'strings.legacy.msg_remove_local_library': return 'Lokale Bibliothek entfernen?';
			case 'strings.legacy.msg_comment_2': return 'Neuer Kommentar';
			case 'strings.legacy.msg_sync_all': return 'Alle synchronisieren';
			case 'strings.legacy.msg_backup_schedule': return 'Sicherungszeitplan';
			case 'strings.legacy.msg_server_error': return 'Serverfehler';
			case 'strings.legacy.msg_analyzing_memos': return 'Deine Memos werden analysiert...';
			case 'strings.legacy.msg_notification': return 'Benachrichtigung';
			case 'strings.legacy.msg_policy': return 'Richtlinie';
			case 'strings.legacy.msg_failed_load': return ({required Object error}) => 'Laden fehlgeschlagen: ${error}';
			case 'strings.legacy.msg_default_visibility': return 'Standard-Sichtbarkeit';
			case 'strings.legacy.msg_filter': return 'Filter';
			case 'strings.legacy.msg_imported_memos': return 'Memos importiert';
			case 'strings.legacy.msg_token_created': return 'Token erstellt';
			case 'strings.legacy.msg_server_response_timeout_try': return 'Zeitüberschreitung bei Serverantwort. Versuche es erneut.';
			case 'strings.legacy.msg_expiring': return 'Läuft ab';
			case 'strings.legacy.msg_delete_task': return 'Aufgabe löschen';
			case 'strings.legacy.msg_body_must_json': return 'Body muss JSON sein';
			case 'strings.legacy.msg_enable': return 'Aktivieren';
			case 'strings.legacy.msg_referenced': return 'Referenziert von';
			case 'strings.legacy.msg_replace_image': return 'Bild ersetzen?';
			case 'strings.legacy.msg_debug_logs': return 'Debug-Protokolle';
			case 'strings.legacy.msg_active_tasks': return 'Aktive Aufgaben';
			case 'strings.legacy.msg_attachments': return 'Anhänge';
			case 'strings.legacy.msg_range': return 'Bereich';
			case 'strings.legacy.msg_no_backups_found': return 'Keine Sicherungen gefunden';
			case 'strings.legacy.msg_create_memo': return 'Memo erstellen';
			case 'strings.legacy.msg_street': return 'Straße';
			case 'strings.legacy.msg_display_name': return 'Anzeigename';
			case 'strings.legacy.msg_full_text_search': return 'Volltextsuche';
			case 'strings.legacy.msg_create_edit_delete_actions_offline_stored': return 'Erstellen-/Bearbeiten-/Löschen-Aktionen im Offline-Modus werden lokal gespeichert und zur Synchronisierung in eine Warteschlange gestellt. Sie werden online der Reihenfolge nach gesendet. Um Fehler zu vermeiden, können nicht übermittelte Bearbeitungen als Entwürfe behalten werden.';
			case 'strings.legacy.msg_sign_2': return 'Abmelden';
			case 'strings.legacy.msg_end_time': return 'Endzeit';
			case 'strings.legacy.msg_sync_recent_content': return 'Aktuelle Inhalte synchronisieren';
			case 'strings.legacy.msg_resetting_local_data': return 'Lokale Daten werden zurückgesetzt...';
			case 'strings.legacy.msg_incorrect_password': return 'Falsches Passwort';
			case 'strings.legacy.msg_content_cannot_empty': return 'Inhalt darf nicht leer sein';
			case 'strings.legacy.msg_preparing': return 'Wird vorbereitet';
			case 'strings.legacy.msg_ai_summary_failed': return ({required Object formatSummaryError_e}) => 'KI-Zusammenfassung fehlgeschlagen: ${formatSummaryError_e}';
			case 'strings.legacy.msg_manage': return 'Verwalten';
			case 'strings.legacy.msg_keep_data_consistent_across_devices': return 'Daten auf allen Geräten konsistent halten.';
			case 'strings.legacy.msg_playback_failed': return ({required Object e}) => 'Wiedergabe fehlgeschlagen: ${e}';
			case 'strings.legacy.msg_path_copied': return 'Pfad kopiert';
			case 'strings.legacy.msg_auth_settings': return 'Authentifizierungseinstellungen';
			case 'strings.legacy.msg_randomly_draw_memo_cards': return 'Ziehe zufällig deine Memo-Karten';
			case 'strings.legacy.msg_copy_log_text': return 'Protokolltext kopieren';
			case 'strings.legacy.msg_yes': return 'Ja';
			case 'strings.legacy.msg_save_open_alipay_scan': return 'Speichern und Alipay zum Scannen öffnen';
			case 'strings.legacy.msg_signed_but_no_token_returned': return 'Angemeldet, aber kein Token zurückgegeben';
			case 'strings.legacy.msg_create_failed': return ({required Object formatError_e_context}) => 'Erstellen fehlgeschlagen: ${formatError_e_context}';
			case 'strings.legacy.msg_expand': return 'Erweitern';
			case 'strings.legacy.msg_local_library_only': return 'Nur lokale Bibliothek';
			case 'strings.legacy.msg_reminder_channel': return 'Erinnerungskanal';
			case 'strings.legacy.msg_grant': return 'Gewähren';
			case 'strings.legacy.msg_import_canceled': return 'Import abgebrochen.';
			case 'strings.legacy.msg_never': return 'Nie';
			case 'strings.legacy.msg_release_notes': return 'Versionshinweise';
			case 'strings.legacy.msg_failed_load_references': return 'Referenzen konnten nicht geladen werden';
			case 'strings.legacy.msg_select_tags': return 'Tags auswählen';
			case 'strings.legacy.msg_failed_load_try': return 'Laden fehlgeschlagen. Bitte versuche es erneut.';
			case 'strings.legacy.msg_logs_copied': return 'Protokolle kopiert';
			case 'strings.legacy.msg_shortcuts_not_supported_server': return 'Kurzbefehle werden auf diesem Server nicht unterstützt.';
			case 'strings.legacy.msg_reply_2': return ({required Object name}) => 'Antworten ${name}...';
			case 'strings.legacy.msg_anonymous': return 'Anonym';
			case 'strings.legacy.msg_username': return 'Benutzername';
			case 'strings.legacy.msg_update_memo': return 'Memo aktualisieren';
			case 'strings.legacy.msg_saved': return ({required Object targetPath}) => 'Gespeichert unter: ${targetPath}';
			case 'strings.legacy.msg_chinese_simplified': return 'Chinesisch (Vereinfacht)';
			case 'strings.legacy.msg_memo_copied': return 'Memo kopiert';
			case 'strings.legacy.msg_collapse': return 'Einklappen';
			case 'strings.legacy.msg_retry_count_controls_how_many_extra': return 'Die Anzahl der Wiederholungsversuche legt fest, wie viele zusätzliche Versuche bei einem Fehlschlag unternommen werden. Höhere Werte können die Erfolgsquote verbessern, dauern aber länger.';
			case 'strings.legacy.msg_recording_info_missing': return 'Aufzeichnungsinformationen fehlen';
			case 'strings.legacy.msg_sync_task': return 'Synchronisierungsaufgabe';
			case 'strings.legacy.msg_clear_all_debug_logs': return 'Alle Debug-Protokolle löschen?';
			case 'strings.legacy.msg_export_finished': return 'Export abgeschlossen';
			case 'strings.legacy.msg_failed_stop_recording': return ({required Object e}) => 'Aufzeichnung konnte nicht gestoppt werden: ${e}';
			case 'strings.legacy.msg_my_profile': return 'Mein Profil';
			case 'strings.legacy.msg_image_bed': return 'Bildspeicher';
			case 'strings.legacy.msg_failed_open_notification': return ({required Object e}) => 'Benachrichtigung konnte nicht geöffnet werden: ${e}';
			case 'strings.legacy.msg_manual': return 'Handbuch';
			case 'strings.legacy.msg_no_html_file_found_zip': return 'Keine HTML-Datei in der ZIP gefunden.';
			case 'strings.legacy.msg_also_clear_local_cache_account_offline': return 'Dadurch wird auch der lokale Cache für dieses Konto gelöscht (Offline-Daten/Entwürfe/wartende Synchronisierungswarteschlange). Diese Aktion kann nicht rückgängig gemacht werden.';
			case 'strings.legacy.msg_restore': return 'Wiederherstellen';
			case 'strings.legacy.msg_auto_backup': return 'Automatische Sicherung';
			case 'strings.legacy.msg_generate_summary': return 'Zusammenfassung erstellen';
			case 'strings.legacy.msg_days': return ({required Object stats_activeDays}) => '${stats_activeDays} Tage';
			case 'strings.legacy.msg_count': return '- Anzahl';
			case 'strings.legacy.msg_weekly': return 'Wöchentlich';
			case 'strings.legacy.msg_notifications': return 'Benachrichtigungen';
			case 'strings.legacy.msg_backup_failed': return 'Sicherung fehlgeschlagen';
			case 'strings.legacy.msg_private': return 'Privat';
			case 'strings.legacy.msg_filter_tags': return 'Nach Tags filtern';
			case 'strings.legacy.msg_clear_logs': return 'Protokolle löschen';
			case 'strings.legacy.msg_unable_open_browser': return 'Browser kann nicht geöffnet werden';
			case 'strings.legacy.msg_attachment_too_large': return 'Anhang zu groß';
			case 'strings.legacy.msg_query': return 'Abfrage';
			case 'strings.legacy.msg_match_all': return 'Alle erfüllen';
			case 'strings.legacy.msg_record_request_response_logs': return 'Anfrage-/Antwortprotokolle aufzeichnen';
			case 'strings.legacy.msg_import_file': return 'Datei importieren';
			case 'strings.legacy.msg_content_tags': return 'Inhalt + Tags';
			case 'strings.legacy.msg_feature_not_available_local_library_mode': return 'Diese Funktion ist im Modus der lokalen Bibliothek nicht verfügbar.';
			case 'strings.legacy.msg_import_failed': return ({required Object e}) => 'Import fehlgeschlagen: ${e}';
			case 'strings.legacy.msg_save_memo': return 'Als Memo speichern';
			case 'strings.legacy.msg_scan_disk_directory_merge_local_database': return 'Datenträgerverzeichnis scannen und mit lokaler Datenbank zusammenführen? Fehlende Dateien werden als Löschungen behandelt.';
			case 'strings.legacy.msg_passwords_not_match': return 'Passwörter stimmen nicht überein';
			case 'strings.legacy.msg_signed_2': return ({required Object lastLoginUser}) => 'Angemeldet als: ${lastLoginUser}';
			case 'strings.legacy.msg_made_love_note_taking': return 'Mit Liebe fürs Notieren gemacht';
			case 'strings.legacy.msg_password_updated_local': return 'Passwort aktualisiert (lokal)';
			case 'strings.legacy.msg_retry': return 'Erneut versuchen';
			case 'strings.legacy.msg_memo_stats': return 'Memo-Statistiken';
			case 'strings.legacy.msg_shown_only_once_copy_keep_safe': return 'Wird nur einmal angezeigt, bitte kopieren und sicher aufbewahren.';
			case 'strings.legacy.msg_describe_issue_time_repro_steps_etc': return 'Beschreibe das Problem, den Zeitpunkt, die Reproduktionsschritte usw.';
			case 'strings.legacy.msg_how_many_days_back': return 'Wie viele Tage zurück';
			case 'strings.legacy.msg_local_cache_cleared': return 'Lokaler Cache gelöscht';
			case 'strings.legacy.msg_none': return 'Keine';
			case 'strings.legacy.msg_body_json': return 'Textkörper (JSON)';
			case 'strings.legacy.msg_download_failed': return ({required Object e}) => 'Download fehlgeschlagen: ${e}';
			case 'strings.legacy.msg_recycle_bin': return 'Papierkorb';
			case 'strings.legacy.msg_unpin': return 'Lösen';
			case 'strings.legacy.msg_advanced_security': return 'Erweitert & Sicherheit';
			case 'strings.legacy.msg_run_issues_memoflow_e_g_sync': return 'Wenn du in MemoFlow auf Probleme stößt (z. B. Synchronisierungsfehler, Abstürze), befolge bitte die folgenden Schritte, damit wir das Problem schneller diagnostizieren und beheben können.\\n\\n';
			case 'strings.legacy.msg_remove_all_reminder_times_memo': return 'Alle Erinnerungszeiten für dieses Memo entfernen.';
			case 'strings.legacy.msg_no_summary_save': return 'Keine Zusammenfassung zum Speichern';
			case 'strings.legacy.msg_reset_language_selection': return 'Sprachauswahl zurücksetzen';
			case 'strings.legacy.msg_v_30_days': return '30 Tage';
			case 'strings.legacy.msg_e_g_mood_check': return 'z. B. Stimmungscheck';
			case 'strings.legacy.msg_note_some_tokens_returned_only_once': return 'Hinweis: Einige Token werden nur einmal zurückgegeben und können später nicht wieder abgerufen werden. Bitte bewahre sie sicher auf.';
			case 'strings.legacy.msg_syncing': return 'Synchronisierung läuft...';
			case 'strings.legacy.msg_retention': return 'Aufbewahrung';
			case 'strings.legacy.msg_open_login_screen': return 'Anmeldebildschirm öffnen';
			case 'strings.legacy.msg_apply_all': return 'Auf alle anwenden';
			case 'strings.legacy.msg_write_something_supports_tag_tasks_x': return 'Schreibe etwas... Unterstützt #tag und Aufgaben [ ] / [x]';
			case 'strings.legacy.msg_http': return ({required Object base, required Object status, required Object msg}) => '${base} (HTTP ${status}): ${msg}';
			case 'strings.legacy.msg_single': return 'Einzeln';
			case 'strings.legacy.msg_delete_memo': return 'Memo löschen?';
			case 'strings.legacy.msg_ai_provider': return 'AI-Anbieter';
			case 'strings.legacy.msg_release_notes_v': return ({required Object version}) => 'Versionshinweise v${version}';
			case 'strings.legacy.msg_info_only_used_background_ai_summaries': return 'Diese Information wird nur als Hintergrund für KI-Zusammenfassungen/-Berichte verwendet und nicht mit dem Backend synchronisiert.';
			case 'strings.legacy.msg_not_disturb': return 'Nicht stören';
			case 'strings.legacy.msg_local_library_import_failed': return ({required Object e}) => 'Import der lokalen Bibliothek fehlgeschlagen: ${e}';
			case 'strings.legacy.msg_key_insights': return 'Wichtige Erkenntnisse';
			case 'strings.legacy.msg_additional_notes_optional': return 'Zusätzliche Notizen (optional)';
			case 'strings.legacy.msg_server_response_error': return 'Fehler in der Serverantwort.';
			case 'strings.legacy.msg_sort': return 'Sortieren';
			case 'strings.legacy.msg_api_call': return 'API-Aufruf';
			case 'strings.legacy.msg_webhooks': return 'Webhooks';
			case 'strings.legacy.msg_local_library': return 'Lokale Bibliothek';
			case 'strings.legacy.msg_log_copied': return 'Protokoll kopiert';
			case 'strings.legacy.msg_last_success': return 'Letzter Erfolg';
			case 'strings.legacy.msg_restore_cloud': return 'Aus der Cloud wiederherstellen';
			case 'strings.legacy.msg_search_public_memos': return 'Öffentliche Memos durchsuchen';
			case 'strings.legacy.msg_cancel': return 'Abbrechen';
			case 'strings.legacy.msg_processing': return ({required Object processed, required Object total}) => 'Verarbeite ${processed} / ${total}';
			case 'strings.legacy.msg_failed_items': return 'Fehlgeschlagene Elemente';
			case 'strings.legacy.msg_recording_file_not_found': return 'Aufnahmedatei nicht gefunden';
			case 'strings.legacy.msg_local_db_outbox_queue': return 'Lokale DB + Outbox-Warteschlange';
			case 'strings.legacy.msg_remove': return 'Entfernen';
			case 'strings.legacy.msg_export_format': return 'Exportformat';
			case 'strings.legacy.msg_idle': return 'Leerlauf';
			case 'strings.legacy.msg_ago': return ({required Object months}) => 'vor ${months}';
			case 'strings.legacy.msg_no_tags_yet': return 'Noch keine Tags';
			case 'strings.legacy.msg_version_v': return ({required Object version}) => 'Version v${version}';
			case 'strings.legacy.msg_sync': return 'Synchronisieren';
			case 'strings.legacy.msg_done': return 'Fertig';
			case 'strings.legacy.msg_gallery_permission_required_2': return 'Galerieberechtigung erforderlich';
			case 'strings.legacy.msg_insufficient_permissions': return 'Unzureichende Berechtigungen';
			case 'strings.legacy.msg_no_download_url_available': return 'Keine Download-URL verfügbar';
			case 'strings.legacy.msg_record_create_memos': return 'Aufnehmen, um Memos zu erstellen';
			case 'strings.legacy.msg_signing': return 'Anmeldung...';
			case 'strings.legacy.msg_memoflow_uses_system_location_permission_get': return 'MemoFlow verwendet die Standortberechtigung des Systems, um Koordinaten zu erhalten, und führt dann eine Reverse-Geokodierung über die Amap Web API durch. Oben können Sie die Anzeigegenauigkeit auswählen.';
			case 'strings.legacy.msg_continue': return 'Weiter';
			case 'strings.legacy.msg_notification_content_unavailable': return 'Benachrichtigungsinhalt nicht verfügbar';
			case 'strings.legacy.msg_unable_read_file_path': return 'Dateipfad kann nicht gelesen werden.';
			case 'strings.legacy.msg_all_memos': return 'Alle Memos';
			case 'strings.legacy.msg_keywords': return 'Schlüsselwörter';
			case 'strings.legacy.msg_import_result': return 'Importergebnis';
			case 'strings.legacy.msg_offline_sync': return 'Offline-Synchronisierung';
			case 'strings.legacy.msg_imported_memos_local_library': return 'Memos aus der lokalen Bibliothek importiert';
			case 'strings.legacy.msg_request_failed': return 'Anfrage fehlgeschlagen';
			case 'strings.legacy.msg_log_file': return 'Protokolldatei';
			case 'strings.legacy.msg_after_confirming_support_unlock_limited_gold': return 'Nach bestätigter Unterstützung schalten Sie entweder ein zeitlich begrenztes Gold-Abzeichen oder ein dauerhaft werbefreies Versprechen frei (obwohl es nie Werbung gab).';
			case 'strings.legacy.msg_failed_open_system_settings': return 'Systemeinstellungen konnten nicht geöffnet werden';
			case 'strings.legacy.msg_no_mood_trend': return 'Kein Stimmungstrend';
			case 'strings.legacy.msg_memoflow_export': return '# MemoFlow-Export';
			case 'strings.legacy.msg_sync_queue': return 'Synchronisierungswarteschlange';
			case 'strings.legacy.msg_only_delete_sync_task_memo_kept': return 'Nur die Synchronisierungsaufgabe löschen; das Memo bleibt erhalten.';
			case 'strings.legacy.msg_add_home_screen': return 'Zum Startbildschirm hinzufügen';
			case 'strings.legacy.msg_past_days': return 'Vergangene Tage';
			case 'strings.legacy.msg_poster_generation_failed': return 'Postergenerierung fehlgeschlagen';
			case 'strings.legacy.msg_failed_load_stats': return ({required Object e}) => 'Statistiken konnten nicht geladen werden: ${e}';
			case 'strings.legacy.msg_customize_notification': return 'Benachrichtigung anpassen';
			case 'strings.legacy.msg_updated_time': return 'Aktualisierte Zeit ↓';
			case 'strings.legacy.msg_network_connection_failed_check_network': return 'Netzwerkverbindung fehlgeschlagen. Bitte überprüfen Sie Ihre Netzwerkverbindung.';
			case 'strings.legacy.msg_special_thanks': return 'Besonderer Dank:';
			case 'strings.legacy.msg_failed_comment': return ({required Object e}) => 'Kommentieren fehlgeschlagen: ${e}';
			case 'strings.legacy.msg_security_key_sig': return 'Sicherheitsschlüssel (sig)';
			case 'strings.legacy.msg_save_gallery': return 'In Galerie speichern';
			case 'strings.legacy.msg_request_sent_confirm_system_prompt': return 'Anfrage gesendet. Im Systemhinweis bestätigen';
			case 'strings.legacy.msg_server_url': return 'Server-URL';
			case 'strings.legacy.msg_period_review': return 'Zeitraumrückblick';
			case 'strings.legacy.msg_settings_updated': return 'Einstellungen aktualisiert';
			case 'strings.legacy.msg_backend_0_21_not_supported_import': return 'Backend 0.21 wird für den Import nicht unterstützt. Bitte aktualisieren Sie und versuchen Sie es erneut.';
			case 'strings.legacy.msg_failed_load_tags': return ({required Object e}) => 'Tags konnten nicht geladen werden: ${e}';
			case 'strings.legacy.msg_enter_email': return 'E-Mail eingeben';
			case 'strings.legacy.msg_add_webhook': return 'Webhook hinzufügen';
			case 'strings.legacy.msg_read': return 'Gelesen';
			case 'strings.legacy.msg_widgets': return 'Widgets';
			case 'strings.legacy.msg_default': return 'Standard';
			case 'strings.legacy.msg_memo_reminders': return 'Memo-Erinnerungen';
			case 'strings.legacy.msg_import_flomo': return 'Aus Flomo importieren';
			case 'strings.legacy.msg_format_fixed_markdown_zip': return 'Format ist auf Markdown + ZIP festgelegt';
			case 'strings.legacy.msg_enter_username_password': return 'Benutzername und Passwort eingeben';
			case 'strings.legacy.msg_loading': return 'Lädt...';
			case 'strings.legacy.msg_test_scheduled': return ({required Object timeLabel, required Object suffix, required Object pendingLabel}) => 'Test geplant um ${timeLabel}${suffix}${pendingLabel}';
			case 'strings.legacy.msg_edit_memo': return 'Memo bearbeiten';
			case 'strings.legacy.msg_save': return 'Speichern';
			case 'strings.legacy.msg_laboratory': return 'Labor';
			case 'strings.legacy.msg_use_local': return 'Lokal verwenden';
			case 'strings.legacy.msg_retry_sync': return 'Synchronisierung erneut versuchen';
			case 'strings.legacy.msg_e_g_my_role_topics_interest': return 'z. B. meine Rolle / interessante Themen / Präferenzen beim Schreibstil?';
			case 'strings.legacy.msg_confirm_password': return 'Passwort bestätigen';
			case 'strings.legacy.msg_not_set': return 'Nicht festgelegt';
			case 'strings.legacy.msg_no_memos_day': return 'Keine Memos an diesem Tag';
			case 'strings.legacy.msg_shortcut_name': return 'Name der Verknüpfung';
			case 'strings.legacy.msg_edit_shortcut': return 'Verknüpfung bearbeiten';
			case 'strings.legacy.msg_days_memos': return 'Tage mit Memos';
			case 'strings.legacy.msg_delete': return 'Löschen';
			case 'strings.legacy.msg_test_reminder': return 'Erinnerung testen';
			case 'strings.legacy.msg_enable_reminders': return 'Erinnerungen aktivieren';
			case 'strings.legacy.msg_links': return 'Links';
			case 'strings.legacy.msg_location': return 'Standort';
			case 'strings.legacy.msg_import_file_2': return 'Aus Datei importieren';
			case 'strings.legacy.msg_reply_3': return ({required Object creatorDisplayName_commentCreator_commentMemo_creator}) => 'Antworten ${creatorDisplayName_commentCreator_commentMemo_creator}...';
			case 'strings.legacy.msg_created': return ({required Object widget_createdAtLabel}) => 'Erstellt ${widget_createdAtLabel}';
			case 'strings.legacy.msg_notifications_coming_soon': return 'Benachrichtigungen: demnächst verfügbar';
			case 'strings.legacy.msg_view_full_contributors': return 'Alle Mitwirkenden anzeigen';
			case 'strings.legacy.msg_no_times_set': return 'Keine Zeiten festgelegt';
			case 'strings.legacy.msg_ignore_tls_errors': return 'TLS-Fehler ignorieren';
			case 'strings.legacy.msg_no_content': return 'Kein Inhalt';
			case 'strings.legacy.msg_about_15_seconds_left': return 'Noch etwa 15 Sekunden';
			case 'strings.legacy.msg_view_imported_memos': return 'Importierte Memos anzeigen';
			case 'strings.legacy.msg_load_failed': return 'Laden fehlgeschlagen';
			case 'strings.legacy.msg_disk_content_conflicts_local_pending_changes': return 'Der Festplatteninhalt steht in Konflikt mit lokalen ausstehenden Änderungen. Verwende die Festplatte, um den lokalen Inhalt zu überschreiben.';
			case 'strings.legacy.msg_all_history_so_far_memoflow_since': return 'Das ist bisher die gesamte Chronik\\nMEMOFLOW SEIT 2023';
			case 'strings.legacy.msg_cancelling': return 'Wird abgebrochen';
			case 'strings.legacy.msg_reading_file': return 'Datei wird gelesen...';
			case 'strings.legacy.msg_switch_workspace': return 'Arbeitsbereich wechseln';
			case 'strings.legacy.msg_optional_leave_empty_default': return 'Optional. Für den Standard leer lassen.';
			case 'strings.legacy.msg_memo_reminders_2': return 'Memo-Erinnerungen';
			case 'strings.legacy.msg_save_failed_2': return ({required Object e}) => 'Speichern fehlgeschlagen: ${e}';
			case 'strings.legacy.msg_record_create_memos_sync_later': return 'Aufnehmen und Memos erstellen (später synchronisieren)';
			case 'strings.legacy.msg_use_https_avoid_ignoring_tls_errors': return 'Verwende HTTPS und vermeide das Ignorieren von TLS-Fehlern, um Anmeldedaten zu schützen.';
			case 'strings.legacy.msg_failed_load_announcement_config': return 'Ankündigungskonfiguration konnte nicht geladen werden';
			case 'strings.legacy.msg_shortcuts': return 'Tastenkürzel';
			case 'strings.legacy.msg_memo': return 'Memo';
			case 'strings.legacy.msg_maybe_later': return 'Vielleicht später';
			case 'strings.legacy.msg_server_connection': return 'Serververbindung';
			case 'strings.legacy.msg_days_2': return 'Tage';
			case 'strings.legacy.msg_include_archived': return 'Archivierte einschließen';
			case 'strings.legacy.msg_during_quiet_hours_reminders_silenced': return 'Während der Ruhezeiten werden Erinnerungen stummgeschaltet.';
			case 'strings.legacy.msg_preview_not_supported_type': return 'Vorschau für diesen Typ nicht unterstützt';
			case 'strings.legacy.msg_failed_load_2': return 'Laden fehlgeschlagen';
			case 'strings.legacy.msg_create_token': return 'Neues Token erstellen';
			case 'strings.legacy.msg_enter_name': return 'Bitte gib einen Namen ein.';
			case 'strings.legacy.msg_api_url_incorrect': return 'API-URL ist falsch.';
			case 'strings.legacy.msg_user_general_settings': return 'Allgemeine Benutzereinstellungen';
			case 'strings.legacy.msg_saved_memo': return 'Als Memo gespeichert';
			case 'strings.legacy.msg_restore_failed': return ({required Object e}) => 'Wiederherstellen fehlgeschlagen: ${e}';
			case 'strings.legacy.msg_token_tail': return ({required Object tail}) => 'Token-Ende ${tail}';
			case 'strings.legacy.msg_manual_token': return 'Manuelles Token';
			case 'strings.legacy.msg_ago_2': return ({required Object years}) => 'vor ${years}';
			case 'strings.legacy.msg_recent_searches': return 'Letzte Suchen';
			case 'strings.legacy.msg_restored': return 'Wiederhergestellt';
			case 'strings.legacy.msg_no_contributors_yet': return 'Noch keine Mitwirkenden';
			case 'strings.legacy.msg_no_record_yet': return 'Noch kein Eintrag';
			case 'strings.legacy.msg_reminder': return 'Erinnerung';
			case 'strings.legacy.msg_enter_api_key_ai_settings': return 'Bitte gib den API-Schlüssel in den KI-Einstellungen ein';
			case 'strings.legacy.msg_reminder_settings': return 'Erinnerungseinstellungen';
			case 'strings.legacy.msg_http_2': return ({required Object base, required Object status}) => '${base} (HTTP ${status})';
			case 'strings.legacy.msg_edit_webhook': return 'Webhook bearbeiten';
			case 'strings.legacy.msg_generate_share_poster': return 'Share-Poster generieren';
			case 'strings.legacy.msg_archive_failed': return ({required Object e}) => 'Archivieren fehlgeschlagen: ${e}';
			case 'strings.legacy.msg_comments': return ({required Object widget_commentCount}) => '${widget_commentCount} Kommentare';
			case 'strings.legacy.msg_remove_account': return 'Konto entfernen?';
			case 'strings.legacy.msg_chinese_traditional': return 'Chinesisch (Traditionell)';
			case 'strings.legacy.msg_private_2': return 'Privat';
			case 'strings.legacy.msg_current_streak': return 'Aktuelle Serie';
			case 'strings.legacy.msg_generated_ai_memoflow': return 'Erstellt von KI · MemoFlow';
			case 'strings.legacy.msg_edit_completed': return 'Bearbeitung abgeschlossen';
			case 'strings.legacy.msg_local': return 'Lokal';
			case 'strings.legacy.msg_edit': return 'Bearbeiten';
			case 'strings.legacy.msg_text': return ({required Object shortUserName_item_sender}) => 'Von ${shortUserName_item_sender}';
			case 'strings.legacy.msg_got': return 'Verstanden';
			case 'strings.legacy.msg_web_api_key': return 'Web-API-Schlüssel';
			case 'strings.legacy.msg_preview': return 'Vorschau';
			case 'strings.legacy.msg_enter_password': return 'Bitte Passwort eingeben';
			case 'strings.legacy.msg_api': return 'API';
			case 'strings.legacy.msg_ok': return 'OK';
			case 'strings.legacy.msg_failed_load_shortcuts': return 'Tastenkürzel konnten nicht geladen werden.';
			case 'strings.legacy.msg_after_recording_audio_added_current_draft': return 'Nach der Aufnahme wird die Audiodatei als Anhang zum aktuellen Entwurf hinzugefügt, sodass du sie vor dem Senden bearbeiten kannst. Die maximale Länge beträgt 60 Minuten; eine Transkription kann später über Drittanbieterdienste hinzugefügt werden.';
			case 'strings.legacy.msg_pull_refresh': return 'Zum Aktualisieren ziehen';
			case 'strings.legacy.msg_unable_open_photo': return 'Foto kann nicht geöffnet werden';
			case 'strings.legacy.msg_existing_tokens': return 'Vorhandene Tokens';
			case 'strings.legacy.msg_ai_settings': return 'KI-Einstellungen';
			case 'strings.legacy.msg_app_lock': return 'App-Sperre';
			case 'strings.legacy.msg_total_notes': return 'Gesamtnotizen';
			case 'strings.legacy.msg_stats_loading': return 'Statistiken werden geladen';
			case 'strings.legacy.msg_enter_token_description': return 'Gib eine Token-Beschreibung ein';
			case 'strings.legacy.msg_enter_token': return 'Gib ein Token ein';
			case 'strings.legacy.msg_api_plugins': return 'API & Plugins';
			case 'strings.legacy.msg_parsing_file': return 'Datei wird analysiert...';
			case 'strings.legacy.msg_english': return 'Englisch';
			case 'strings.legacy.msg_activity_heatmap': return 'Aktivitäts-Heatmap';
			case 'strings.legacy.msg_mark_read': return 'Als gelesen markieren';
			case 'strings.legacy.msg_request': return 'Anfrage';
			case 'strings.legacy.msg_sync_failed': return ({required Object type, required Object memoError}) => 'Synchronisierung fehlgeschlagen (${type}): ${memoError}';
			case 'strings.legacy.msg_error_copied': return 'Fehler kopiert';
			case 'strings.legacy.msg_only_local_index_removed_disk_files': return 'Nur der lokale Index wird entfernt; die Dateien auf der Festplatte bleiben erhalten. Dies kann nicht rückgängig gemacht werden.';
			case 'strings.legacy.msg_switch_account': return 'Konto wechseln';
			case 'strings.legacy.msg_invalid_download_link': return 'Ungültiger Download-Link';
			case 'strings.legacy.msg_about': return 'Info';
			case 'strings.legacy.msg_icon': return 'Symbol';
			case 'strings.legacy.msg_reset_done_syncing': return 'Zurücksetzen abgeschlossen. Synchronisierung läuft...';
			case 'strings.legacy.msg_enter_amap_web_api_key': return 'Geben Sie Ihren Amap Web-API-Schlüssel ein';
			case 'strings.legacy.msg_recycle_bin_coming_soon': return 'Papierkorb: kommt bald';
			case 'strings.legacy.msg_empty_content': return '(Leerer Inhalt)';
			case 'strings.legacy.msg_note_most_features_offline_stats_ai': return 'Hinweis: Die meisten Funktionen (offline/Statistiken/KI-Berichte/Export) funktionieren ohne Backend-Änderungen, aber Token werden nur einmal zurückgegeben?bitte bewahren Sie sie sicher auf.';
			case 'strings.legacy.msg_fixed': return 'Behoben: ';
			case 'strings.legacy.msg_allow_sharing_links_images_other_apps': return 'Erlauben Sie das Teilen von Links oder Bildern aus anderen Apps in MemoFlow.';
			case 'strings.legacy.msg_invalid_request_parameters': return 'Ungültige Anfrageparameter';
			case 'strings.legacy.msg_enter_api_url': return 'Bitte API-URL eingeben';
			case 'strings.legacy.msg_pending': return ({required Object result_pendingCount}) => ' (ausstehend ${result_pendingCount})';
			case 'strings.legacy.msg_days_3': return ({required Object currentStreak}) => '${currentStreak} Tage';
			case 'strings.legacy.msg_poster_not_ready_yet': return 'Poster ist noch nicht bereit';
			case 'strings.legacy.msg_generated_memoflow': return 'Erstellt von MemoFlow';
			case 'strings.legacy.msg_enter_name_2': return 'Geben Sie einen Namen ein';
			case 'strings.legacy.msg_version': return 'Version';
			case 'strings.legacy.msg_memo_missing_disk_but_has_local': return 'Das Memo fehlt auf der Festplatte, hat aber lokale ausstehende Änderungen. Verwenden Sie die Festplatte, um lokal zu löschen.';
			case 'strings.legacy.msg_legacy_api_compatibility': return 'Legacy-API-Kompatibilität';
			case 'strings.legacy.msg_sync_parameters': return 'Synchronisierungsparameter';
			case 'strings.legacy.msg_quick_prompts': return 'Schnell-Prompts';
			case 'strings.legacy.msg_share_failed': return ({required Object e}) => 'Teilen fehlgeschlagen: ${e}';
			case 'strings.legacy.msg_no_memos_summarize_range': return 'Keine Memos zum Zusammenfassen in diesem Bereich';
			case 'strings.legacy.msg_characters': return 'Zeichen';
			case 'strings.legacy.msg_capture_every_moment_record': return 'Halte jeden Moment fest, den du aufnimmst';
			case 'strings.legacy.msg_vibration': return 'Vibration';
			case 'strings.legacy.msg_days_4': return 'Tage';
			case 'strings.legacy.msg_prompt_title': return 'Prompt-Titel';
			case 'strings.legacy.msg_show_all': return 'Alle anzeigen';
			case 'strings.legacy.msg_no_memos_available': return 'Keine Memos verfügbar';
			case 'strings.legacy.msg_comment_unavailable': return 'Kommentar nicht verfügbar';
			case 'strings.legacy.msg_refresh': return 'Aktualisieren';
			case 'strings.legacy.msg_syncing_2': return 'Synchronisierung läuft';
			case 'strings.legacy.msg_body': return 'Text';
			case 'strings.legacy.msg_clear_2': return 'Löschen';
			case 'strings.legacy.msg_third_party_share': return 'Teilen über Drittanbieter';
			case 'strings.legacy.msg_charging_station': return 'Ladestation';
			case 'strings.legacy.msg_attachments_2': return 'Anhänge';
			case 'strings.legacy.msg_when_enabled_must_verify_each_app': return 'Wenn aktiviert, müssen Sie bei jedem App-Start eine Verifizierung durchführen. Die automatische Sperrzeit legt fest, wie schnell nach dem Wechsel der App in den Hintergrund eine Verifizierung erforderlich ist.';
			case 'strings.legacy.msg_add_prompt': return 'Prompt hinzufügen';
			case 'strings.legacy.msg_include': return 'Einschließen';
			case 'strings.legacy.msg_created_time_2': return 'Erstellungszeit ↓';
			case 'strings.legacy.msg_choose_data_source_start_importing_memos': return 'Wählen Sie eine Datenquelle, um mit dem Import Ihrer Memos zu beginnen';
			case 'strings.legacy.msg_describe_how_want_summary': return 'Beschreiben Sie, wie Sie die Zusammenfassung möchten…';
			case 'strings.legacy.msg_keep_token_safe_not_share_api': return 'Bewahren Sie Ihr Token sicher auf und teilen Sie es nicht.\\nDas API-Rate-Limit beträgt 60 Anfragen pro Minute.';
			case 'strings.legacy.msg_open_2': return 'Öffnen';
			case 'strings.legacy.msg_e_g_claude_3_5_sonnet': return 'z. B. claude-3-5-sonnet-20241022';
			case 'strings.legacy.msg_failed_request_whitelist': return 'Whitelist konnte nicht angefordert werden';
			case 'strings.legacy.msg_notification_deleted': return 'Benachrichtigung gelöscht';
			case 'strings.legacy.msg_accounts': return 'Konten';
			case 'strings.legacy.msg_add_local_library': return 'Lokale Bibliothek hinzufügen';
			case 'strings.legacy.msg_sign_first': return 'Bitte zuerst anmelden';
			case 'strings.legacy.msg_failed_parse_query': return 'Abfrage konnte nicht geparst werden';
			case 'strings.legacy.msg_note_logs_sanitized_automatically_sensitive_data': return 'Hinweis: Protokolle werden automatisch bereinigt. Wenn sensible Daten verbleiben, schwärzen Sie sie vor dem Absenden.';
			case 'strings.legacy.msg_add': return 'Hinzufügen';
			case 'strings.legacy.msg_failed_load_3': return ({required Object memosError}) => 'Laden fehlgeschlagen: ${memosError}';
			case 'strings.legacy.msg_max_chars_day': return 'Max. Zeichen/Tag';
			case 'strings.legacy.msg_choose_what_edited_image': return 'Wählen Sie aus, was mit dem bearbeiteten Bild geschehen soll.';
			case 'strings.legacy.msg_select': return 'Auswählen';
			case 'strings.legacy.msg_unnamed_token': return '(Unbenanntes Token)';
			case 'strings.legacy.msg_name': return 'Name';
			case 'strings.legacy.msg_sure_want_delete_webhook': return 'Möchten Sie diesen Webhook wirklich löschen?';
			case 'strings.legacy.msg_back': return 'Zurück';
			case 'strings.legacy.msg_no': return 'Nein';
			case 'strings.legacy.msg_untitled': return 'Ohne Titel';
			case 'strings.legacy.msg_open_language_onboarding': return 'Sprach-Einführung öffnen';
			case 'strings.legacy.msg_voice_memos': return 'Sprachmemos';
			case 'strings.legacy.msg_unable_open_browser_try': return 'Browser kann nicht geöffnet werden. Bitte versuchen Sie es erneut.';
			case 'strings.legacy.msg_date_range': return 'Datumsbereich';
			case 'strings.legacy.msg_not_authenticated': return 'Nicht authentifiziert';
			case 'strings.legacy.msg_back_2': return 'Zurück';
			case 'strings.legacy.msg_local_library_removed': return 'Lokale Bibliothek entfernt';
			case 'strings.legacy.msg_exact_alarm_permission_required': return 'Exakte Alarmberechtigung erforderlich';
			case 'strings.legacy.msg_visibility': return 'Sichtbarkeit';
			case 'strings.legacy.msg_failed_start_recording': return ({required Object e}) => 'Aufnahme konnte nicht gestartet werden: ${e}';
			case 'strings.legacy.msg_mood_trend': return 'Stimmungstrend';
			case 'strings.legacy.msg_local_library_name': return 'Name der lokalen Bibliothek';
			case 'strings.legacy.msg_no_tokens_yet': return 'Noch keine Tokens';
			case 'strings.legacy.msg_loading_2': return 'Lädt?';
			case 'strings.legacy.msg_location_permission_denied_permanently': return 'Standortberechtigung dauerhaft verweigert';
			case 'strings.legacy.msg_download': return 'Herunterladen';
			case 'strings.legacy.msg_export_time': return '- Exportzeit';
			case 'strings.legacy.msg_enter_password_2': return 'Passwort eingeben';
			case 'strings.legacy.msg_no_image_available': return 'Kein Bild verfügbar';
			case 'strings.legacy.msg_daily': return 'Täglich';
			case 'strings.legacy.msg_no_likes_yet': return 'Noch keine Likes';
			case 'strings.legacy.msg_basics': return 'Grundlagen';
			case 'strings.legacy.msg_shortcut': return 'Neue Verknüpfung';
			case 'strings.legacy.msg_debug_tools': return 'Debug-Tools';
			case 'strings.legacy.msg_save_settings': return 'Einstellungen speichern';
			case 'strings.legacy.msg_date_range_2': return 'Datumsbereich';
			case 'strings.legacy.msg_feedback': return 'Feedback';
			case 'strings.legacy.msg_image_bed_2': return 'Bildspeicher';
			case 'strings.legacy.msg_restoring': return 'Wird wiederhergestellt…';
			case 'strings.legacy.msg_export': return 'Exportieren';
			case 'strings.legacy.msg_enter_token_name': return 'Bitte Token-Namen eingeben';
			case 'strings.legacy.msg_start_time': return 'Startzeit';
			case 'strings.legacy.msg_preparing_file_structure': return 'Dateistruktur wird vorbereitet';
			case 'strings.legacy.msg_sign_3': return 'Anmelden';
			case 'strings.legacy.msg_scan_local_library': return 'Lokale Bibliothek scannen';
			case 'strings.legacy.msg_lsky_pro': return 'Lsky Pro';
			case 'strings.legacy.msg_exact_alarm_permission_off_reminders_may': return 'Die Berechtigung für genaue Alarme ist deaktiviert. Erinnerungen werden möglicherweise nicht rechtzeitig ausgelöst. Einstellungen jetzt öffnen?';
			case 'strings.legacy.msg_last_30_days': return 'Letzte 30 Tage';
			case 'strings.legacy.msg_match': return 'Übereinstimmung';
			case 'strings.legacy.msg_auth_mode': return 'Authentifizierungsmodus';
			case 'strings.legacy.msg_unsupported_file_type': return 'Nicht unterstützter Dateityp.';
			case 'strings.legacy.msg_only_delete_sync_task': return 'Nur die Synchronisierungsaufgabe löschen.';
			case 'strings.legacy.msg_change_password': return 'Passwort ändern';
			case 'strings.legacy.msg_saved_2': return 'Gespeichert';
			case 'strings.legacy.msg_import_export': return 'Import / Export';
			case 'strings.legacy.msg_created_2': return 'Erstellt';
			case 'strings.legacy.msg_ai_summary': return 'KI-Zusammenfassung';
			case 'strings.legacy.msg_progress': return 'Fortschritt';
			case 'strings.legacy.msg_replace_memo_image': return 'Memo-Bild ersetzen';
			case 'strings.legacy.msg_app_settings': return 'App-Einstellungen';
			case 'strings.legacy.msg_copy_path': return 'Pfad kopieren';
			case 'strings.legacy.msg_components': return 'Komponenten';
			case 'strings.legacy.msg_no_shortcuts': return 'Keine Verknüpfungen';
			case 'strings.legacy.msg_location_timed_try': return 'Zeitüberschreitung beim Standort. Bitte erneut versuchen.';
			case 'strings.legacy.msg_attach_location_info_memos_show_subtle': return 'Standortinformationen an Memos anhängen und dezente Ortsnamen anzeigen.';
			case 'strings.legacy.msg_send_failed': return ({required Object e}) => 'Senden fehlgeschlagen: ${e}';
			case 'strings.legacy.msg_repeat': return 'Wiederholen';
			case 'strings.legacy.msg_not_signed': return 'Nicht angemeldet';
			case 'strings.legacy.msg_no_webhooks_configured': return 'Keine Webhooks konfiguriert';
			case 'strings.legacy.msg_apply_token': return 'Token anwenden';
			case 'strings.legacy.msg_enable_reminder_permissions_2': return 'Erinnerungsberechtigungen aktivieren';
			case 'strings.legacy.msg_enter_backup_password': return 'Backup-Passwort eingeben';
			case 'strings.legacy.msg_start_backup': return 'Backup starten';
			case 'strings.legacy.msg_last_sync': return 'Letzte Synchronisierung';
			case 'strings.legacy.msg_note_export_includes_content_already_synced': return 'Hinweis: Der Export enthält Inhalte, die bereits mit der lokalen Datenbank synchronisiert wurden (einschließlich Offlinedaten).';
			case 'strings.legacy.msg_enter_username': return 'Benutzernamen eingeben';
			case 'strings.legacy.msg_settings_saved': return 'Einstellungen gespeichert';
			case 'strings.legacy.msg_no_keywords': return 'Keine Schlüsselwörter';
			case 'strings.legacy.msg_these_settings_apply_newly_created_memos': return 'Diese Einstellungen gelten für neu erstellte Memos.';
			case 'strings.legacy.msg_back_home': return 'Zurück zur Startseite';
			case 'strings.legacy.msg_quiet_hours': return 'Ruhezeiten';
			case 'strings.legacy.msg_add_account': return 'Konto hinzufügen';
			case 'strings.legacy.msg_reset_complete': return 'Zurücksetzen abgeschlossen';
			case 'strings.legacy.msg_no_shortcuts_configured': return 'Keine Verknüpfungen konfiguriert';
			case 'strings.legacy.msg_password': return 'Passwort';
			case 'strings.legacy.msg_importing': return 'Importieren';
			case 'strings.legacy.msg_visibility_2': return ({required Object visibilityLabel}) => 'Sichtbarkeit: ${visibilityLabel}';
			case 'strings.legacy.msg_no_logs_yet': return 'Noch keine Protokolle';
			case 'strings.legacy.msg_v_9_times_allowed': return 'Bis zu 9 Mal erlaubt';
			case 'strings.legacy.msg_last_14_days': return 'Letzte 14 Tage';
			case 'strings.legacy.msg_location_disabled_enable_settings_first': return 'Standort ist deaktiviert. Aktivieren Sie ihn zuerst in den Einstellungen.';
			case 'strings.legacy.msg_add_2': return 'Hinzufügen';
			case 'strings.legacy.msg_logs': return 'Protokolle';
			case 'strings.legacy.msg_references': return 'Referenzen';
			case 'strings.legacy.msg_importing_memos': return 'Memos werden importiert...';
			case 'strings.legacy.msg_account_security': return 'Konto & Sicherheit';
			case 'strings.legacy.msg_reminder_2': return 'Erinnerung';
			case 'strings.legacy.msg_enable_scheduled_reminder_notifications': return 'Geplante Erinnerungsbenachrichtigungen aktivieren.';
			case 'strings.legacy.msg_no_links': return 'Keine Links';
			case 'strings.legacy.msg_delete_memo_2': return 'Memo löschen';
			case 'strings.legacy.msg_one_tap_add_not_supported_add': return 'Hinzufügen mit einem Tippen wird nicht unterstützt. Fügen Sie es über die Widget-Auswahl hinzu';
			case 'strings.legacy.msg_password_2': return 'Neues Passwort';
			case 'strings.legacy.msg_processing_content': return 'Inhalt wird verarbeitet...';
			case 'strings.legacy.msg_status': return 'Status';
			case 'strings.legacy.msg_local_library_added': return 'Lokale Bibliothek hinzugefügt';
			case 'strings.legacy.msg_failed_open_try': return 'Konnte nicht geöffnet werden. Bitte erneut versuchen.';
			case 'strings.legacy.msg_removed_locally_now_deleted_server_when': return 'Es wird jetzt lokal entfernt und auf dem Server gelöscht, sobald eine Verbindung besteht.';
			case 'strings.legacy.msg_server_url_unavailable': return 'Server-URL nicht verfügbar';
			case 'strings.legacy.msg_no_release_notes_yet': return 'Noch keine Versionshinweise';
			case 'strings.legacy.msg_cancelling_2': return 'Abbrechen...';
			case 'strings.legacy.msg_summaries_selected_range': return 'Zusammenfassungen über den ausgewählten Bereich';
			case 'strings.legacy.msg_expand_2': return 'Erweitern';
			case 'strings.legacy.msg_close': return 'Schließen';
			case 'strings.legacy.msg_more_comments': return ({required Object remainingComments}) => '${remainingComments} weitere Kommentare';
			case 'strings.legacy.msg_backing': return 'Sicherung wird erstellt…';
			case 'strings.legacy.msg_view_debug_logs': return 'Debug-Protokolle anzeigen';
			case 'strings.legacy.msg_location_permission_denied': return 'Standortberechtigung verweigert';
			case 'strings.legacy.msg_self_repair_reset_heatmap': return 'Selbstreparatur: Heatmap zurücksetzen';
			case 'strings.legacy.msg_these_settings_changed_locally_remotely_choose': return 'Diese Einstellungen wurden lokal und remote geändert. Wählen Sie, welche Version beibehalten werden soll.';
			case 'strings.legacy.msg_not_authenticated_2': return 'Nicht authentifiziert.';
			case 'strings.legacy.msg_action_failed': return ({required Object e}) => 'Aktion fehlgeschlagen: ${e}';
			case 'strings.legacy.msg_shortcut_2': return 'Neue Verknüpfung';
			case 'strings.legacy.msg_url': return 'URL';
			case 'strings.legacy.msg_no_memos_found_html': return 'Keine Memos in HTML gefunden.';
			case 'strings.legacy.msg_enter_what_want_summarize': return 'Geben Sie ein, was Sie zusammenfassen möchten...';
			case 'strings.legacy.msg_unable_load_audio_source': return 'Audioquelle konnte nicht geladen werden.';
			case 'strings.legacy.msg_strategy_id': return 'Strategie-ID';
			case 'strings.legacy.msg_copy_failed': return ({required Object e}) => 'Kopieren fehlgeschlagen: ${e}';
			case 'strings.legacy.msg_enable_image_bed': return 'Bildbett aktivieren';
			case 'strings.legacy.msg_active': return 'Aktiv';
			case 'strings.legacy.msg_account': return 'Konto';
			case 'strings.legacy.msg_invalid_webdav_server_url': return 'Ungültige WebDAV-Server-URL';
			case 'strings.legacy.msg_keep_local': return 'Lokal beibehalten';
			case 'strings.legacy.msg_within_range': return 'Innerhalb des Bereichs';
			case 'strings.legacy.msg_generate_log_file': return 'Protokolldatei erstellen';
			case 'strings.legacy.msg_ai_reports': return 'KI-Berichte';
			case 'strings.legacy.msg_battery_optimization': return 'Akkuoptimierung';
			case 'strings.legacy.msg_sync_overview': return 'Synchronisierungsübersicht';
			case 'strings.legacy.msg_legacy_servers_not_support_search_filters': return 'Legacy-Server unterstützen keine Suchfilter; Ergebnisse können unvollständig sein.';
			case 'strings.legacy.msg_conflicts_detected_run_manual_sync': return 'Konflikte erkannt. Führen Sie eine manuelle Synchronisierung aus.';
			case 'strings.legacy.msg_authentication_failed_check_token': return 'Authentifizierung fehlgeschlagen. Prüfen Sie das Token.';
			case 'strings.legacy.msg_date_range_3': return 'Datumsbereich';
			case 'strings.legacy.msg_help_ai_understand_better': return 'Hilf der KI, dich besser zu verstehen';
			case 'strings.legacy.msg_no_search_history': return 'Kein Suchverlauf';
			case 'strings.legacy.msg_enter_api_path': return 'API-Pfad eingeben';
			case 'strings.legacy.msg_stats': return 'Statistiken';
			case 'strings.legacy.msg_text_2': return 'Neu: ';
			case 'strings.legacy.msg_removing_signing_clear_local_cache_account': return 'Entfernen/Abmelden löscht den lokalen Cache für dieses Konto (Offline-Daten/Entwürfe/ausstehende Synchronisierungswarteschlange).';
			case 'strings.legacy.msg_updated_time_2': return 'Aktualisierte Zeit ↑';
			case 'strings.legacy.msg_province': return 'Bundesland';
			case 'strings.legacy.msg_submitting_sync_queue': return 'Synchronisierungswarteschlange wird übermittelt';
			case 'strings.legacy.msg_failed': return 'Fehlgeschlagen';
			case 'strings.legacy.msg_set_time': return 'Zeit festlegen';
			case 'strings.legacy.msg_enable_local_library_backup': return 'Lokale Bibliothekssicherung aktivieren';
			case 'strings.legacy.msg_cancel_2': return 'Abbrechen';
			case 'strings.legacy.msg_week': return 'Diese Woche';
			case 'strings.legacy.msg_like': return 'Gefällt mir';
			case 'strings.legacy.msg_location_services_disabled': return 'Standortdienste sind deaktiviert';
			case 'strings.legacy.msg_clears_local_cache_offline_memos_pending': return 'Dadurch wird der lokale Cache (Offline-Memos/ausstehende Warteschlange) gelöscht und eine vollständige Neusynchronisierung ausgelöst. Nicht synchronisierte Inhalte gehen verloren, und es kann eine Weile dauern. Fortfahren?';
			case 'strings.legacy.msg_load_more': return 'Mehr laden';
			case 'strings.legacy.msg_pull_memo_list_refresh_sync_sync': return 'Zum Aktualisieren und Synchronisieren in der Memoliste nach unten ziehen. Die Synchronisierung ruft zuerst die neuesten Elemente ab; führen Sie regelmäßig eine vollständige Synchronisierung durch, damit Statistiken/Heatmap vollständig bleiben.';
			case 'strings.legacy.msg_server_returned_error': return ({required Object code}) => 'Server hat einen Fehler zurückgegeben (${code}).';
			case 'strings.legacy.msg_sound_feedback': return 'Ton & Feedback';
			case 'strings.legacy.msg_memos_skipped_attachments_skipped': return ({required Object exportedMemoCount, required Object skippedMemoCount, required Object exportedAttachmentCount, required Object skippedAttachmentCount}) => '${exportedMemoCount} Memos (übersprungen: ${skippedMemoCount}), ${exportedAttachmentCount} Anhänge (übersprungen: ${skippedAttachmentCount}).';
			case 'strings.legacy.msg_import_complete': return 'Import abgeschlossen';
			case 'strings.legacy.msg_text_3': return 'Neu';
			case 'strings.legacy.msg_max_per_day': return 'Max. pro Tag';
			case 'strings.legacy.msg_permissions_denied': return 'Berechtigungen verweigert';
			case 'strings.legacy.msg_memo_2': return 'Neues Memo';
			case 'strings.legacy.msg_delete_reminder': return 'Erinnerung löschen';
			case 'strings.legacy.msg_select_month': return 'Monat auswählen';
			case 'strings.legacy.msg_select_backup': return 'Sicherung auswählen';
			case 'strings.legacy.msg_no_keywords_2': return '#Keine Schlüsselwörter';
			case 'strings.legacy.msg_preparing_memo_content': return 'Memo-Inhalt wird vorbereitet';
			case 'strings.legacy.msg_prompt_content': return 'Prompt-Inhalt';
			case 'strings.legacy.msg_default_prompt_ai_summaries_reports': return 'Standard-Prompt für KI-Zusammenfassungen/-Berichte';
			case 'strings.legacy.msg_intro': return 'Einführung';
			case 'strings.legacy.msg_monthly_stats': return 'Monatliche Statistiken';
			case 'strings.legacy.msg_times_2': return 'Mal';
			case 'strings.legacy.msg_file_has_already_been_imported_skipped': return 'Diese Datei wurde bereits importiert. Übersprungen.';
			case 'strings.legacy.msg_token_tail_unknown': return 'Token-Ende unbekannt';
			case 'strings.legacy.msg_press_back_exit': return 'Zum Beenden erneut Zurück drücken';
			case 'strings.legacy.msg_enter_password_3': return 'Passwort eingeben';
			case 'strings.legacy.msg_sync_conflicts': return 'Synchronisierungskonflikte';
			case 'strings.legacy.msg_locale': return 'Gebietsschema';
			case 'strings.legacy.msg_any': return 'Beliebig';
			case 'strings.legacy.msg_provider': return 'Anbieter';
			case 'strings.legacy.msg_preview_2': return 'Vorschau';
			case 'strings.legacy.msg_automatically_upload_images_append_links_memo': return 'Bilder automatisch hochladen und Links an das Memo anhängen.';
			case 'strings.legacy.msg_import_file_not_found': return 'Importdatei nicht gefunden.';
			case 'strings.legacy.msg_today': return 'Heute';
			case 'strings.legacy.msg_link_card': return 'Karte verknüpfen';
			case 'strings.legacy.msg_expiration': return 'Ablaufdatum';
			case 'strings.legacy.msg_summary_prompt_optional': return 'Zusammenfassungs-Prompt (optional)';
			case 'strings.legacy.msg_memos': return 'Notizen';
			case 'strings.legacy.msg_recording_file_not_found_2': return 'Aufnahmedatei nicht gefunden.';
			case 'strings.legacy.msg_backup_settings': return 'Sicherungseinstellungen';
			case 'strings.legacy.msg_mode': return 'Modus';
			case 'strings.legacy.msg_no_markdown_memos_found_zip': return 'Keine Markdown-Notizen in der ZIP gefunden.';
			case 'strings.legacy.msg_archived': return 'Archiviert';
			case 'strings.legacy.msg_update_failed': return ({required Object e}) => 'Aktualisierung fehlgeschlagen: ${e}';
			case 'strings.legacy.msg_enable_app_lock': return 'App-Sperre aktivieren';
			case 'strings.legacy.msg_html_zip': return 'HTML / ZIP';
			case 'strings.legacy.msg_all': return 'Alle';
			case 'strings.legacy.msg_model': return 'Modell';
			case 'strings.legacy.msg_title': return 'Titel';
			case 'strings.legacy.msg_amap_web_api': return 'Amap Web API';
			case 'strings.legacy.msg_saved_gallery': return 'In Galerie gespeichert';
			case 'strings.legacy.msg_unread': return 'Ungelesen';
			case 'strings.legacy.msg_exporting': return 'Exportiere...';
			case 'strings.legacy.msg_network_timeout_try': return 'Netzwerk-Timeout. Bitte versuche es erneut.';
			case 'strings.legacy.msg_unlock': return 'Entsperren';
			case 'strings.legacy.msg_ago_3': return ({required Object diff_inDays}) => 'vor ${diff_inDays}';
			case 'strings.legacy.msg_deserve_coffee_i_m_pulling_all': return 'Um diesen Kaffee zu verdienen, mache ich eine Nachtschicht, um 100 Zeilen Code zu schreiben!';
			case 'strings.legacy.msg_token_name': return 'Token-Name';
			case 'strings.legacy.msg_restore_completed': return 'Wiederherstellung abgeschlossen';
			case 'strings.legacy.msg_copied_clipboard': return 'In die Zwischenablage kopiert';
			case 'strings.legacy.msg_failed_2': return ({required Object attempts}) => 'Fehlgeschlagen ${attempts}';
			case 'strings.legacy.msg_too_many_requests_try_later': return 'Zu viele Anfragen. Versuche es später erneut.';
			case 'strings.legacy.msg_more': return 'Mehr';
			case 'strings.legacy.msg_already_whitelisted': return 'Bereits auf der Whitelist';
			case 'strings.legacy.msg_local_library_backup': return 'Lokale Bibliothekssicherung';
			case 'strings.legacy.msg_awesome': return 'Großartig! ❤️';
			case 'strings.legacy.msg_now': return 'Jetzt';
			case 'strings.legacy.msg_select_reminder_time': return 'Erinnerungszeit auswählen';
			case 'strings.legacy.msg_protected': return 'Geschützt';
			case 'strings.legacy.msg_failed_load_4': return ({required Object e}) => 'Laden fehlgeschlagen: ${e}';
			case 'strings.legacy.msg_operation_failed': return ({required Object e}) => 'Vorgang fehlgeschlagen: ${e}';
			case 'strings.legacy.msg_no_tags': return 'Keine Tags';
			case 'strings.legacy.msg_server': return 'Server';
			case 'strings.legacy.msg_improved': return 'Verbessert';
			case 'strings.legacy.msg_request_2': return 'Anfrage';
			case 'strings.legacy.msg_export_failed': return ({required Object e}) => 'Export fehlgeschlagen: ${e}';
			case 'strings.legacy.msg_notification_settings': return 'Benachrichtigungseinstellungen';
			case 'strings.legacy.msg_related_memo_was_deleted': return 'Die zugehörige Notiz wurde gelöscht';
			case 'strings.legacy.msg_email': return 'E-Mail';
			case 'strings.legacy.msg_enter_password_4': return 'Bitte ein Passwort eingeben';
			case 'strings.legacy.msg_retry_count': return 'Anzahl der Wiederholungen';
			case 'strings.legacy.msg_import_exported_html_zip_package': return 'Exportiertes HTML- oder ZIP-Paket importieren';
			case 'strings.legacy.msg_archive': return 'Archiv';
			case 'strings.legacy.msg_reset_heatmap': return 'Heatmap zurücksetzen?';
			case 'strings.legacy.msg_token_applied': return 'Token angewendet';
			case 'strings.legacy.msg_log_file_created': return 'Protokolldatei erstellt';
			case 'strings.legacy.msg_delete_sync_task': return 'Synchronisierungsaufgabe löschen';
			case 'strings.legacy.msg_include_archived_2': return '- Archivierte einschließen';
			case 'strings.legacy.msg_memoflow_side_project_i_build_my': return 'MemoFlow ist ein Nebenprojekt, das ich in meiner Freizeit entwickle. Ich habe bis spät in die Nacht Bugs behoben und könnte wirklich einen Iced Americano gebrauchen. Deine Unterstützung lädt meine Batterie wieder auf und hilft dabei, neue Funktionen zu veröffentlichen ';
			case 'strings.legacy.msg_failed_generate': return ({required Object e}) => 'Generierung fehlgeschlagen: ${e}';
			case 'strings.legacy.msg_search_logs': return 'Protokolle durchsuchen';
			case 'strings.legacy.msg_active_days': return 'Aktive Tage';
			case 'strings.legacy.msg_back_top': return 'Zurück nach oben';
			case 'strings.legacy.msg_month': return 'Dieser Monat';
			case 'strings.legacy.msg_loading_references': return 'Referenzen werden geladen';
			case 'strings.legacy.msg_silent': return 'Lautlos';
			case 'strings.legacy.msg_settings': return 'Einstellungen';
			case 'strings.legacy.msg_locating': return 'Wird lokalisiert...';
			case 'strings.legacy.msg_scan': return 'Scannen';
			case 'strings.legacy.msg_recording_path_missing': return 'Aufnahmepfad fehlt.';
			case 'strings.legacy.msg_date_range_4': return '- Datumsbereich';
			case 'strings.legacy.msg_suggested_tags': return 'Vorgeschlagene Tags';
			case 'strings.legacy.msg_energy_restored': return '⚡ ENERGIE WIEDERHERGESTELLT';
			case 'strings.legacy.msg_username_2': return 'Benutzername';
			case 'strings.legacy.msg_ai_summary_report': return 'KI-Zusammenfassungsbericht';
			case 'strings.legacy.msg_all_tags': return 'Alle Tags';
			case 'strings.legacy.msg_preferences': return 'Präferenzen';
			case 'strings.legacy.msg_image_bed_3': return 'Bildspeicher';
			case 'strings.legacy.msg_quick_input': return 'Schnelleingabe';
			case 'strings.legacy.msg_tags': return 'Tags';
			case 'strings.legacy.msg_energy_critically_low': return 'Energie kritisch niedrig!';
			case 'strings.legacy.msg_delete_failed': return ({required Object e}) => 'Löschen fehlgeschlagen: ${e}';
			case 'strings.legacy.msg_server_login': return 'Server-Anmeldung';
			case 'strings.legacy.msg_like_2': return 'Gefällt mir';
			case 'strings.legacy.msg_save_2': return 'Speichern';
			case 'strings.legacy.msg_unknown': return 'Unbekannt';
			case 'strings.legacy.msg_release_notes_2': return 'Versionshinweise';
			case 'strings.legacy.msg_include_error_details': return 'Fehlerdetails einschließen';
			case 'strings.legacy.msg_write_comment': return 'Einen Kommentar schreiben...';
			case 'strings.legacy.msg_write_thoughts': return 'Schreibe deine Gedanken auf...';
			case 'strings.legacy.msg_local_2': return 'Lokal';
			case 'strings.legacy.msg_expired': return 'Abgelaufen';
			case 'strings.legacy.msg_fixed_2': return 'Behoben';
			case 'strings.legacy.msg_upload_attachment': return 'Anhang hochladen';
			case 'strings.legacy.msg_battery_whitelist': return 'Batterie-Whitelist';
			case 'strings.legacy.msg_district': return 'Bezirk';
			case 'strings.legacy.msg_voice_memo': return '🎙️ Sprachnotiz\\n';
			case 'strings.legacy.msg_system_default': return 'Systemstandard';
			case 'strings.legacy.msg_all_memos_2': return 'Alle Notizen';
			case 'strings.legacy.msg_network_request_failed': return 'Netzwerkanfrage fehlgeschlagen';
			case 'strings.legacy.msg_memo_not_found': return 'Notiz nicht gefunden';
			case 'strings.legacy.msg_playback_failed_2': return ({required Object e}) => 'Wiedergabe fehlgeschlagen: ${e}';
			case 'strings.legacy.msg_sync_settings_webdav_across_devices': return 'Synchronisiere Einstellungen über Geräte hinweg mit WebDAV.';
			case 'strings.legacy.msg_offline_first_client_memos_backend': return 'Ein Offline-First-Client für das Memos-Backend.';
			case 'strings.legacy.msg_user_guide': return 'Benutzerhandbuch';
			case 'strings.legacy.msg_notice': return 'Hinweis';
			case 'strings.legacy.msg_exact_alarms': return 'Exakte Alarme';
			case 'strings.legacy.msg_restoring_overwrite_local_library_files_rebuild': return 'Beim Wiederherstellen werden lokale Bibliotheksdateien überschrieben und die Datenbank neu aufgebaut. Dies kann nicht rückgängig gemacht werden.';
			case 'strings.legacy.msg_enter_api_url_ai_settings': return 'Bitte geben Sie die API-URL in den KI-Einstellungen ein';
			case 'strings.legacy.msg_create_failed_2': return ({required Object e}) => 'Erstellen fehlgeschlagen: ${e}';
			case 'strings.legacy.msg_close_search': return 'Suche schließen';
			case 'strings.legacy.msg_imported_memos_2': return 'Memos importiert';
			case 'strings.legacy.msg_explore': return 'Entdecken';
			case 'strings.legacy.msg_network_connection_failed': return 'Netzwerkverbindung fehlgeschlagen.';
			case 'strings.legacy.msg_save_failed_3': return ({required Object e}) => 'Speichern fehlgeschlagen: ${e}';
			case 'strings.legacy.msg_no_summary_share': return 'Keine Zusammenfassung zum Teilen';
			case 'strings.legacy.msg_custom_model': return 'Benutzerdefiniertes Modell';
			case 'strings.legacy.msg_sign_failed': return ({required Object message}) => 'Anmeldung fehlgeschlagen: ${message}';
			case 'strings.legacy.msg_notification_exact_alarm_permissions_required_send': return 'Benachrichtigungs- und Berechtigungen für exakte Alarme sind erforderlich, um Erinnerungen pünktlich zu senden.';
			case 'strings.legacy.msg_random_review': return 'Zufällige Überprüfung';
			case 'strings.legacy.msg_public': return 'Öffentlich';
			case 'strings.legacy.msg_all_2': return 'Alle';
			case 'strings.legacy.msg_add_custom_model': return 'Benutzerdefiniertes Modell hinzufügen';
			case 'strings.legacy.msg_backup_password': return 'Backup-Passwort';
			case 'strings.legacy.msg_optional_used_sign_requests': return 'Optional. Wird zum Signieren von Anfragen verwendet.';
			case 'strings.legacy.msg_search': return 'Suchen';
			case 'strings.legacy.msg_set_password': return 'Passwort festlegen';
			case 'strings.legacy.msg_submit_logs': return 'Protokolle senden';
			case 'strings.legacy.msg_activity_heatmap_2': return 'AKTIVITÄTS-HEATMAP';
			case 'strings.legacy.msg_invalid_api_key_insufficient_permissions': return 'Ungültiger API-Schlüssel oder unzureichende Berechtigungen.';
			case 'strings.legacy.msg_data_has_been_migrated_app_successfully': return 'Ihre Daten wurden erfolgreich in diese App migriert.';
			case 'strings.legacy.msg_get_version': return 'Neue Version herunterladen';
			case 'strings.legacy.msg_token_source': return 'Token-Quelle';
			case 'strings.legacy.msg_send': return 'Senden';
			case 'strings.legacy.msg_no_pending_sync_tasks': return 'Keine ausstehenden Synchronisierungsaufgaben';
			case 'strings.legacy.msg_locating_memo_content': return 'Notizinhalt wird lokalisiert';
			case 'strings.legacy.msg_offline_ready': return 'Offline bereit';
			case 'strings.legacy.msg_use_relative_path': return 'Einen relativen Pfad verwenden';
			case 'strings.legacy.msg_total': return 'Gesamt';
			case 'strings.legacy.msg_location_2': return 'Standort';
			case 'strings.legacy.msg_show_location_metadata_memos_not_configured': return 'Standortmetadaten in Notizen anzeigen. Wenn nicht konfiguriert, werden stattdessen Koordinaten angezeigt.';
			case 'strings.legacy.msg_api_url': return 'API-URL';
			case 'strings.legacy.msg_parsing_progress': return 'Analysefortschritt';
			case 'strings.legacy.msg_parsing': return 'Analysieren';
			case 'strings.legacy.msg_custom': return 'Benutzerdefiniert';
			case 'strings.legacy.msg_tags_created': return 'Neue Tags erstellt';
			case 'strings.legacy.msg_third_party_share_disabled': return 'Teilen über Drittanbieter ist deaktiviert';
			case 'strings.legacy.msg_loading_links': return 'Links werden geladen...';
			case 'strings.legacy.msg_how_report': return 'Wie melden?';
			case 'strings.legacy.msg_confirm_password_2': return 'Passwort bestätigen';
			case 'strings.legacy.msg_search_title_content_tags': return 'Nach Titel, Inhalt oder Tags suchen';
			case 'strings.legacy.msg_reset_failed': return ({required Object e}) => 'Zurücksetzen fehlgeschlagen: ${e}';
			case 'strings.legacy.msg_debug_preview_update_dialog': return 'Debug: Vorschau des Update-Dialogs';
			case 'strings.legacy.msg_what_s': return 'Was ist neu?';
			case 'strings.legacy.msg_ringtone': return 'Klingelton';
			case 'strings.legacy.msg_unable_detect_backend_version_check_server': return 'Backend-Version kann nicht erkannt werden. Überprüfen Sie die Server-URL oder das Netzwerk.';
			case 'strings.legacy.msg_pending_2': return 'Ausstehend';
			case 'strings.legacy.msg_parsing_html': return 'HTML wird analysiert...';
			case 'strings.legacy.msg_actions': return 'Aktionen';
			case 'strings.legacy.msg_import_complete_2': return 'Import abgeschlossen';
			case 'strings.legacy.msg_use_disk': return 'Datenträger verwenden';
			case 'strings.legacy.msg_root_path': return 'Root-Pfad';
			case 'strings.legacy.msg_disabled': return 'Deaktiviert';
			case 'strings.legacy.msg_improved_2': return 'Verbessert: ';
			case 'strings.legacy.msg_city': return 'Stadt';
			case 'strings.legacy.msg_decoding_zip': return 'ZIP wird decodiert...';
			case 'strings.legacy.msg_notification_content': return 'Benachrichtigungsinhalt';
			case 'strings.legacy.msg_resolve_conflict': return 'Konflikt lösen';
			case 'strings.legacy.msg_webhooks_not_supported_server': return 'Webhooks werden auf diesem Server nicht unterstützt.';
			case 'strings.legacy.msg_may_delayed': return ' (kann verzögert sein)';
			case 'strings.legacy.msg_permissions_system_settings': return 'Berechtigungen & Systemeinstellungen';
			case 'strings.legacy.msg_waiting_tasks_stop': return 'Warten, bis Aufgaben beendet sind';
			case 'strings.legacy.msg_done_2': return 'Fertig';
			case 'strings.legacy.msg_parsing_memoflow_export': return 'MemoFlow-Export wird analysiert...';
			case 'strings.legacy.msg_location_updated': return ({required Object next_displayText_fractionDigits_6}) => 'Standort aktualisiert: ${next_displayText_fractionDigits_6}';
			case 'strings.legacy.msg_checking_server_version': return 'Serverversion wird überprüft...';
			case 'strings.legacy.msg_next_time_back_fixing_bugs': return '👀 Nächstes Mal zurück zum Beheben von Fehlern';
			case 'strings.legacy.msg_ago_4': return ({required Object weeks}) => 'vor ${weeks}';
			case 'strings.legacy.msg_import': return 'Importieren';
			case 'strings.legacy.msg_ios_long_press_home_screen_add': return 'Unter iOS: Halte den Home-Bildschirm gedrückt, um MemoFlow-Widgets hinzuzufügen';
			case 'strings.legacy.msg_create_token_2': return 'Token erstellen';
			case 'strings.legacy.msg_marked_read': return 'Als gelesen markiert';
			case 'strings.legacy.msg_pinned': return 'Angepinnt';
			case 'strings.legacy.msg_version_update': return 'Versionsaktualisierung';
			case 'strings.legacy.msg_allow_private_memos': return 'Private Memos zulassen';
			case 'strings.legacy.msg_token_copied_clipboard': return 'Token in die Zwischenablage kopiert';
			case 'strings.legacy.msg_keeping_more_versions_uses_more_storage': return 'Das Beibehalten mehrerer Versionen benötigt mehr Speicherplatz. Erwäge, alte Versionen zu bereinigen.';
			case 'strings.legacy.msg_delete_webhook': return 'Webhook löschen';
			case 'strings.legacy.msg_prompt': return 'Eingabeaufforderung';
			case 'strings.legacy.msg_location_precision': return 'Standortgenauigkeit';
			case 'strings.legacy.msg_password_required': return 'Passwort erforderlich';
			case 'strings.legacy.msg_exit_app': return 'App beenden';
			case 'strings.legacy.msg_thanks_energy_fully_restored': return 'Danke! Energie vollständig wiederhergestellt ⚡';
			case 'strings.legacy.msg_connection_timeout_check_network_api_url': return 'Zeitüberschreitung bei der Verbindung. Überprüfe das Netzwerk oder die API-URL.';
			case 'strings.legacy.app_language.system': return 'System';
			case 'strings.legacy.app_language.zh_hans': return 'Chinesisch (Vereinfacht)';
			case 'strings.legacy.app_language.zh_hant_tw': return 'Chinesisch (Traditionell, China Taiwan)';
			case 'strings.legacy.app_language.en': return 'Englisch';
			case 'strings.legacy.app_language.ja': return 'Japanisch';
			case 'strings.legacy.app_language.de': return 'Deutsch';
			case 'strings.legacy.app_theme.system': return 'System';
			case 'strings.legacy.app_theme.light': return 'Hell';
			case 'strings.legacy.app_theme.dark': return 'Dunkel';
			case 'strings.legacy.app_font_size.standard': return 'Standard';
			case 'strings.legacy.app_font_size.large': return 'Groß';
			case 'strings.legacy.app_font_size.small': return 'Klein';
			case 'strings.legacy.app_line_height.classic': return 'Klassisch';
			case 'strings.legacy.app_line_height.compact': return 'Kompakt';
			case 'strings.legacy.app_line_height.relaxed': return 'Entspannt';
			case 'strings.legacy.launch_action.none': return 'Keine';
			case 'strings.legacy.launch_action.sync': return 'Synchronisieren';
			case 'strings.legacy.launch_action.quick_input': return 'Schnelleingabe';
			case 'strings.legacy.launch_action.daily_review': return 'Zufällige Rückschau';
			case 'strings.legacy.auto_lock_time.immediately': return 'Sofort';
			case 'strings.legacy.auto_lock_time.after_1_min': return '1 Minute';
			case 'strings.legacy.auto_lock_time.after_5_min': return '5 Minuten';
			case 'strings.legacy.auto_lock_time.after_15_min': return '15 Minuten';
			case 'strings.legacy.reminder.default_title': return 'Hey, erinnerst du dich an diese Idee?';
			case 'strings.legacy.reminder.default_body': return 'Tippen, um Details anzusehen';
			case 'strings.legacy.location.current': return 'Aktueller Standort';
			case 'strings.legacy.webdav.not_configured': return 'WebDAV ist nicht konfiguriert';
			case 'strings.legacy.webdav.backup_disabled': return 'Backup ist deaktiviert';
			case 'strings.legacy.webdav.backup_account_missing': return 'Konto für das Backup fehlt';
			case 'strings.legacy.webdav.backup_local_only': return 'Backup ist nur für lokale Bibliotheken verfügbar';
			case 'strings.legacy.webdav.backup_password_missing': return 'Backup-Passwort fehlt';
			case 'strings.legacy.webdav.backup_no_memo_files': return 'Keine Memo-Dateien in der lokalen Bibliothek gefunden; Backup abgebrochen';
			case 'strings.legacy.webdav.restore_account_missing': return 'Konto für die Wiederherstellung fehlt';
			case 'strings.legacy.webdav.restore_local_only': return 'Wiederherstellung ist nur für lokale Bibliotheken verfügbar';
			case 'strings.legacy.webdav.backup_empty': return 'Backup ist leer';
			case 'strings.legacy.webdav.backup_no_memos': return 'Keine Memos im Backup gefunden';
			case 'strings.legacy.webdav.snapshot_missing': return 'Backup-Snapshot fehlt';
			case 'strings.legacy.webdav.snapshot_corrupted': return 'Backup-Snapshot ist beschädigt';
			case 'strings.legacy.webdav.object_missing': return 'Backup-Objekt fehlt';
			case 'strings.legacy.webdav.config_corrupted': return 'Backup-Konfiguration ist beschädigt';
			case 'strings.legacy.webdav.config_invalid': return 'Ungültige Backup-Konfiguration';
			case 'strings.legacy.webdav.password_invalid': return 'Ungültiges Backup-Passwort';
			case 'strings.legacy.webdav.data_corrupted': return 'Backup-Daten sind beschädigt';
			case 'strings.legacy.webdav.server_url_invalid': return 'Ungültige WebDAV-Server-URL';
			case 'strings.legacy.import_count_memos': return ({required Object count}) => '${count}';
			case 'strings.legacy.import_count_attachments': return ({required Object count}) => '${count}';
			case 'strings.legacy.app_drawer.tooltip_single': return ({required Object date, required Object weekday, required Object count}) => '${date} (${weekday}) · ${count} Notiz';
			case 'strings.legacy.app_drawer.tooltip_multi': return ({required Object date, required Object weekday, required Object count}) => '${date} (${weekday}) · ${count} Notizen';
			case 'strings.legacy.ai_summary.error_api_key_empty': return 'API-Schlüssel ist leer';
			case 'strings.legacy.ai_summary.system.require_json': return 'Bitte ausschließlich JSON ausgeben. Keine Codeblöcke und keine zusätzlichen Erläuterungen.';
			case 'strings.legacy.ai_summary.system.json_format': return 'JSON-Format: {"insights":["..."],"moodTrend":"...","keywords":["#..."]}';
			case 'strings.legacy.ai_summary.system.insights_rule': return 'insights 2-5 Einträge, keywords 4-8 Begriffe mit #.';
			case 'strings.legacy.ai_summary.user.range': return ({required Object rangeLabel}) => 'Zeitraum: ${rangeLabel}';
			case 'strings.legacy.ai_summary.user.counts': return ({required Object memoCount, required Object includedCount}) => 'Memos: ${memoCount} (für die Zusammenfassung: ${includedCount})';
			case 'strings.legacy.ai_summary.user.profile': return ({required Object profile}) => 'Nutzerprofil: ${profile}';
			case 'strings.legacy.ai_summary.user.custom_prompt': return ({required Object customPrompt}) => 'Zusätzliche Anweisungen: ${customPrompt}';
			case 'strings.legacy.ai_summary.user.memo_content': return 'Memo-Inhalt:';
			case 'strings.legacy.ai_summary.error_invalid_response': return 'Ungültiges AI-Antwortformat';
			case 'strings.legacy.ai_summary.error_empty_response': return 'AI-Antwort ist leer';
			case 'strings.legacy.ai_summary.error_missing_content': return 'Inhalt der AI-Antwort fehlt';
			case 'strings.legacy.ai_summary.default_prompt': return 'Du bist ein minimalistischer Notizassistent. Extrahiere die Kernaussagen und formatiere sie elegant. Antworte professionell, freundlich und prägnant. Verwende nach Möglichkeit Listen und kurze Absätze.';
			default: return null;
		}
	}
}

extension on _StringsJa {
	dynamic _flatMapFunction(String path) {
		switch (path) {
			case 'strings.common.back': return '戻る';
			case 'strings.common.cancel': return 'キャンセル';
			case 'strings.common.confirm': return '確認';
			case 'strings.common.save': return '保存';
			case 'strings.common.saveSettings': return '設定を保存';
			case 'strings.common.auto': return '自動';
			case 'strings.common.manual': return '手動';
			case 'strings.common.copiedToClipboard': return 'クリップボードにコピーしました';
			case 'strings.common.serverVersion': return 'サーバーバージョン';
			case 'strings.common.selectValidServerVersion': return '有効なサーバーバージョンを選択してください';
			case 'strings.common.serverVersionValue': return ({required Object version}) => 'サーバーバージョン: ${version}';
			case 'strings.common.selectServerVersionRange021To026': return '0.21〜0.26 のサーバーバージョンを手動で選択してください';
			case 'strings.languages.system': return 'システムに従う';
			case 'strings.languages.zhHans': return '中国語（簡体字）';
			case 'strings.languages.zhHantTw': return '中国語（繁体字・中国台湾）';
			case 'strings.languages.en': return '英語';
			case 'strings.languages.ja': return '日本語';
			case 'strings.languages.de': return 'ドイツ語';
			case 'strings.languagesNative.system': return 'システム';
			case 'strings.languagesNative.zhHans': return '简体中文';
			case 'strings.languagesNative.zhHantTw': return '繁體中文（中國台灣）';
			case 'strings.languagesNative.en': return 'English';
			case 'strings.languagesNative.ja': return '日本語';
			case 'strings.languagesNative.de': return 'Deutsch';
			case 'strings.onboarding.tagline': return 'ミニマルで強力なノートストリーム';
			case 'strings.onboarding.selectLanguage': return '言語を選択';
			case 'strings.onboarding.selectMode': return 'モードを選択';
			case 'strings.onboarding.modeHint': return '後で設定で変更できます。';
			case 'strings.onboarding.modeLocalTitle': return 'ローカルモード';
			case 'strings.onboarding.modeLocalLabel': return 'ローカルモード';
			case 'strings.onboarding.modeLocalDesc': return 'データは端末内に保存されます。サーバー設定は不要で、プライバシー重視やオフライン利用に最適です。';
			case 'strings.onboarding.modeServerTitle': return 'サーバーモード';
			case 'strings.onboarding.modeServerLabel': return 'サーバーモード';
			case 'strings.onboarding.modeServerDesc': return 'Memos バックエンドに接続して、複数端末でリアルタイム同期します。';
			case 'strings.onboarding.localLibraryNameTitle': return 'ローカルライブラリ名';
			case 'strings.onboarding.localLibraryNameHint': return '名前を入力';
			case 'strings.onboarding.localLibraryDefaultName': return 'ローカルライブラリ';
			case 'strings.onboarding.getStarted': return 'はじめる';
			case 'strings.login.title': return 'Memos に接続';
			case 'strings.login.mode.password': return 'ユーザー名とパスワード';
			case 'strings.login.mode.token': return 'トークン';
			case 'strings.login.mode.descPassword': return 'ユーザー名とパスワードでサインイン';
			case 'strings.login.mode.descToken': return 'パーソナルアクセストークンでサインイン';
			case 'strings.login.mode.signInMethod': return 'サインイン方法';
			case 'strings.login.field.serverUrlLabel': return 'サーバーURL';
			case 'strings.login.field.serverUrlHint': return 'http://localhost:5230';
			case 'strings.login.field.usernameLabel': return 'ユーザー名';
			case 'strings.login.field.usernameHint': return 'ユーザー名を入力';
			case 'strings.login.field.passwordLabel': return 'パスワード';
			case 'strings.login.field.passwordHint': return 'パスワードを入力';
			case 'strings.login.field.tokenLabel': return 'トークン (PAT)';
			case 'strings.login.field.tokenHint': return 'トークン (PAT)';
			case 'strings.login.validation.serverUrlRequired': return 'サーバーURLを入力してください';
			case 'strings.login.validation.serverUrlInvalid': return 'http/https とポートを含む完全なURLを入力してください';
			case 'strings.login.validation.usernameRequired': return 'ユーザー名を入力してください';
			case 'strings.login.validation.passwordRequired': return 'パスワードを入力してください';
			case 'strings.login.validation.tokenRequired': return 'トークンを入力してください';
			case 'strings.login.compatibility.title': return '互換モード';
			case 'strings.login.compatibility.description': return '旧版 Memos 用のレガシーエンドポイントを使用します';
			case 'strings.login.connect.connecting': return '接続中…';
			case 'strings.login.connect.action': return '接続';
			case 'strings.login.errors.authFailedToken': return '認証に失敗しました。トークンが有効で期限切れでないか確認してください。';
			case 'strings.login.errors.authFailedPat': return '認証に失敗しました。新しい Memos では memos_pat_ で始まる PAT を使用してください（Bearer プレフィックスは貼り付けないでください）。';
			case 'strings.login.errors.connectionFailedWithMessage': return ({required Object message}) => '接続に失敗しました: ${message}';
			case 'strings.login.errors.connectionFailed': return ({required Object error}) => '接続に失敗しました: ${error}';
			case 'strings.login.errors.signInFailed': return 'サインインに失敗しました。ユーザー名とパスワードを確認してください。';
			case 'strings.login.errors.signInFailedWithMessage': return ({required Object message}) => 'サインインに失敗しました: ${message}';
			case 'strings.login.errors.invalidServerUrl': return 'サーバーURLが無効です';
			case 'strings.login.errors.serverUrlNormalized': return 'サーバーURLを正規化しました（余分なパスを削除）';
			case 'strings.settings.preferences.title': return '設定';
			case 'strings.settings.preferences.language': return '言語';
			case 'strings.settings.preferences.fontSize': return '文字サイズ';
			case 'strings.settings.preferences.lineHeight': return '行間';
			case 'strings.settings.preferences.font': return 'フォント';
			case 'strings.settings.preferences.systemDefault': return 'システム標準';
			case 'strings.settings.preferences.noSystemFonts': return 'システムフォントが見つかりません';
			case 'strings.settings.preferences.loadFontsFailed': return ({required Object error}) => 'フォントの読み込みに失敗しました: ${error}';
			case 'strings.settings.preferences.collapseLongContent': return '長文を折りたたむ';
			case 'strings.settings.preferences.collapseReferences': return '参照を折りたたむ';
			case 'strings.settings.preferences.showEngagementInAllMemoDetails': return 'すべてのメモ詳細でいいねとコメントを表示';
			case 'strings.settings.preferences.launchAction': return '起動時の動作';
			case 'strings.settings.preferences.quickInputKeyboard': return 'クイック入力で自動的にキーボードを開く';
			case 'strings.settings.preferences.appearance': return '外観';
			case 'strings.settings.preferences.themeColor': return 'テーマカラー';
			case 'strings.settings.preferences.haptics': return '触覚フィードバック';
			case 'strings.settings.preferences.customTheme': return 'カスタムテーマ';
			case 'strings.settings.preferences.history': return '履歴';
			case 'strings.settings.preferences.lightMode': return 'ライトモード';
			case 'strings.settings.preferences.darkMode': return 'ダークモード';
			case 'strings.settings.preferences.surfaces': return 'サーフェス';
			case 'strings.settings.preferences.background': return '背景';
			case 'strings.settings.preferences.backgroundColor': return '背景色';
			case 'strings.settings.preferences.card': return 'カード';
			case 'strings.settings.preferences.cardColor': return 'カード色';
			case 'strings.settings.preferences.border': return '枠線';
			case 'strings.settings.preferences.borderColor': return '枠線色';
			case 'strings.legacy.msg_memos_backend_docs': return 'Memos バックエンドドキュメント';
			case 'strings.legacy.msg_remember_moment_feel_warmth_life_take': return 'その瞬間を記録し、暮らしのぬくもりを感じましょう。\\n毎日さっと振り返りましょう。';
			case 'strings.legacy.msg_sure_want_delete_shortcut': return 'このショートカットを削除してもよろしいですか？';
			case 'strings.legacy.msg_scan_completed': return 'スキャン完了';
			case 'strings.legacy.msg_confirm': return '確認';
			case 'strings.legacy.msg_unable_open_browser_install_browser_app': return 'ブラウザを開けません。ブラウザアプリをインストールしてください。';
			case 'strings.legacy.msg_contributors': return '貢献者';
			case 'strings.legacy.msg_enter_keywords_search_box_query_local': return '検索ボックスにキーワードを入力して、ローカルの内容とタグを検索します。オフラインで利用可能です。初回利用時はローカルインデックスの作成完了までお待ちください。';
			case 'strings.legacy.msg_memo_not_found_locally': return 'メモがローカルに見つかりません';
			case 'strings.legacy.msg_token': return 'トークン';
			case 'strings.legacy.msg_last_7_days': return '過去7日間';
			case 'strings.legacy.msg_search_memo_content': return 'メモ内容を検索';
			case 'strings.legacy.msg_retry_started': return '再試行を開始しました';
			case 'strings.legacy.msg_last_year_memos': return ({required Object lastYearMemos}) => '昨年: ${lastYearMemos} 件のメモ';
			case 'strings.legacy.msg_no_content_yet': return 'まだ内容がありません';
			case 'strings.legacy.msg_no_summary_yet': return 'まだ要約がありません';
			case 'strings.legacy.msg_sooner': return ' 今すぐ！';
			case 'strings.legacy.msg_token_copied': return 'トークンをコピーしました';
			case 'strings.legacy.msg_share': return '共有';
			case 'strings.legacy.msg_gallery_permission_required': return 'ギャラリーへのアクセス権が必要です';
			case 'strings.legacy.msg_basic_settings': return '基本設定';
			case 'strings.legacy.msg_bad_ssl_certificate': return 'SSL証明書が不正です。';
			case 'strings.legacy.msg_no_notifications': return '通知はありません';
			case 'strings.legacy.msg_import_markdown': return 'Markdown からインポート';
			case 'strings.legacy.msg_upload_zip_package_md_files': return '.md ファイルを含む .zip パッケージをアップロードしてください';
			case 'strings.legacy.msg_request_send_timeout_try': return 'リクエストの送信がタイムアウトしました。再試行してください。';
			case 'strings.legacy.msg_select_date_range': return '日付範囲を選択';
			case 'strings.legacy.msg_delete_shortcut': return 'ショートカットを削除';
			case 'strings.legacy.msg_auto_lock_time': return '自動ロック時間';
			case 'strings.legacy.msg_replacing_delete_original_attachment_continue': return '置き換えると元の添付ファイルは削除されます。続行しますか？';
			case 'strings.legacy.msg_add_least_one_condition': return '条件を少なくとも1つ追加してください。';
			case 'strings.legacy.msg_upload_images_image_bed_append_links': return '画像を画像ホスティングにアップロードし、リンクをメモに追記します。';
			case 'strings.legacy.msg_request_cancelled': return 'リクエストがキャンセルされました。';
			case 'strings.legacy.msg_generating': return '生成しますか？';
			case 'strings.legacy.msg_permissions_denied_reminders_disabled': return '権限が拒否されました。リマインダーは無効です。';
			case 'strings.legacy.msg_memoflow_local_reminders': return 'MemoFlow ローカルリマインダー';
			case 'strings.legacy.msg_use_legacy_endpoints_older_memos_servers': return 'レガシーエンドポイントを使用（旧Memosサーバー向け）。';
			case 'strings.legacy.msg_no_comments_yet': return 'まだコメントがありません';
			case 'strings.legacy.msg_open': return '開く';
			case 'strings.legacy.msg_microphone_permission_required': return 'マイクへのアクセス権が必要です';
			case 'strings.legacy.msg_failed_react': return ({required Object e}) => 'リアクションに失敗しました: ${e}';
			case 'strings.legacy.msg_restore_backup': return 'バックアップを復元しますか？';
			case 'strings.legacy.msg_qr_saved_gallery': return 'QRをギャラリーに保存しました';
			case 'strings.legacy.msg_no_attachments': return '添付ファイルはありません';
			case 'strings.legacy.msg_enable_reminder_permissions': return 'リマインダー権限を有効にする';
			case 'strings.legacy.msg_created_time': return '作成日時 ↑';
			case 'strings.legacy.msg_prompt_saved_quick_prompts': return 'あなたのプロンプトはクイックプロンプトに保存されます';
			case 'strings.legacy.msg_remember_password': return 'パスワードを記憶';
			case 'strings.legacy.msg_enter_valid_url': return '有効なURLを入力してください';
			case 'strings.legacy.msg_may_take_few_seconds': return 'これには数秒かかる場合があります';
			case 'strings.legacy.msg_local_sync_failed': return ({required Object type, required Object memoError}) => 'ローカル同期に失敗しました（${type}）: ${memoError}';
			case 'strings.legacy.msg_webdav_sync': return 'WebDAV 同期';
			case 'strings.legacy.msg_clear': return 'クリア';
			case 'strings.legacy.msg_clear_recycle_bin_confirm': return 'ごみ箱を空にしますか？中の項目はすべて完全に削除されます。';
			case 'strings.legacy.msg_save_failed': return '保存に失敗しました';
			case 'strings.legacy.msg_endpoint_not_found_version_mismatch': return 'エンドポイントが見つかりません（バージョン不一致？）';
			case 'strings.legacy.msg_enable_webdav_sync': return 'WebDAV 同期を有効にする';
			case 'strings.legacy.msg_local_libraries': return 'ローカルライブラリ';
			case 'strings.legacy.msg_apply': return '適用';
			case 'strings.legacy.msg_restore_only_available_local_libraries': return '復元はローカルライブラリでのみ利用できます。';
			case 'strings.legacy.msg_sign': return 'サインアウトしますか？';
			case 'strings.legacy.msg_reminders_disabled': return 'リマインダーは無効です';
			case 'strings.legacy.msg_downloading': return 'ダウンロード中...';
			case 'strings.legacy.msg_path': return 'パス';
			case 'strings.legacy.msg_match_any': return 'いずれかに一致';
			case 'strings.legacy.msg_local_db_pending_queue': return 'ローカルDB + 保留キュー';
			case 'strings.legacy.msg_scan_failed': return ({required Object e}) => 'スキャンに失敗しました: ${e}';
			case 'strings.legacy.msg_user': return 'ユーザー';
			case 'strings.legacy.msg_pick_future_time': return '未来の時刻を選択してください';
			case 'strings.legacy.msg_include_pending_queue': return '保留キューを含める';
			case 'strings.legacy.msg_enter_days': return '日数を入力';
			case 'strings.legacy.msg_times': return '回数';
			case 'strings.legacy.msg_token_returned_only_once_cannot_fetched': return 'トークンは一度だけ返され、再取得できません';
			case 'strings.legacy.msg_quoted_lines': return ({required Object quoteLines}) => '${quoteLines} 行を引用';
			case 'strings.legacy.msg_use_remote': return 'リモートを使用';
			case 'strings.legacy.msg_enable_memo_location': return 'メモの位置情報を有効にする';
			case 'strings.legacy.msg_failed_get_location': return '位置情報の取得に失敗しました';
			case 'strings.legacy.msg_after_import_memos_sync_list_automatically': return 'インポート後、メモは自動的に一覧へ同期されます。ZIPインポートの場合は、ファイル構造が正しいことを確認してください。';
			case 'strings.legacy.msg_legacy_mode': return 'レガシーモード';
			case 'strings.legacy.msg_signed': return 'サインイン済み';
			case 'strings.legacy.msg_shortcut_includes_advanced_conditions_saving_overwrite': return 'このショートカットには高度な条件が含まれています。保存するとそれらは上書きされます。';
			case 'strings.legacy.msg_no_results_found': return '結果が見つかりません';
			case 'strings.legacy.msg_reply': return ({required Object replyName}) => '${replyName} に返信...';
			case 'strings.legacy.msg_copy': return 'コピー';
			case 'strings.legacy.msg_enable_reminders_memos': return 'メモのリマインダーを有効にします。';
			case 'strings.legacy.msg_comment': return 'コメント';
			case 'strings.legacy.msg_added_voice_attachment': return '音声添付を追加しました。';
			case 'strings.legacy.msg_customize_sidebar': return 'サイドバーをカスタマイズ';
			case 'strings.legacy.msg_coffee_add_drumstick': return '☕ コーヒーで / ドラムスティックを追加';
			case 'strings.legacy.msg_pin': return 'ピン留め';
			case 'strings.legacy.msg_enter_password_continue': return '続行するにはパスワードを入力してください';
			case 'strings.legacy.msg_remove_local_library': return 'ローカルライブラリを削除しますか？';
			case 'strings.legacy.msg_comment_2': return '新しいコメント';
			case 'strings.legacy.msg_sync_all': return 'すべて同期';
			case 'strings.legacy.msg_backup_schedule': return 'バックアップスケジュール';
			case 'strings.legacy.msg_server_error': return 'サーバーエラー';
			case 'strings.legacy.msg_analyzing_memos': return 'メモを解析中...';
			case 'strings.legacy.msg_notification': return '通知';
			case 'strings.legacy.msg_policy': return 'ポリシー';
			case 'strings.legacy.msg_failed_load': return ({required Object error}) => '読み込みに失敗しました: ${error}';
			case 'strings.legacy.msg_default_visibility': return 'デフォルトの公開範囲';
			case 'strings.legacy.msg_filter': return 'フィルター';
			case 'strings.legacy.msg_imported_memos': return 'メモをインポートしました';
			case 'strings.legacy.msg_token_created': return 'トークンを作成しました';
			case 'strings.legacy.msg_server_response_timeout_try': return 'サーバーの応答がタイムアウトしました。もう一度お試しください。';
			case 'strings.legacy.msg_expiring': return '期限切れ予定';
			case 'strings.legacy.msg_delete_task': return 'タスクを削除';
			case 'strings.legacy.msg_body_must_json': return '本文はJSONである必要があります';
			case 'strings.legacy.msg_enable': return '有効にする';
			case 'strings.legacy.msg_referenced': return '参照元';
			case 'strings.legacy.msg_replace_image': return '画像を置き換えますか？';
			case 'strings.legacy.msg_debug_logs': return 'デバッグログ';
			case 'strings.legacy.msg_active_tasks': return 'アクティブなタスク';
			case 'strings.legacy.msg_attachments': return '添付ファイル';
			case 'strings.legacy.msg_range': return '範囲';
			case 'strings.legacy.msg_no_backups_found': return 'バックアップが見つかりません';
			case 'strings.legacy.msg_create_memo': return 'メモを作成';
			case 'strings.legacy.msg_street': return '番地';
			case 'strings.legacy.msg_display_name': return '表示名';
			case 'strings.legacy.msg_full_text_search': return '全文検索';
			case 'strings.legacy.msg_create_edit_delete_actions_offline_stored': return 'オフラインでの作成・編集・削除操作はローカルに保存され、同期キューに追加されます。オンライン時に順番に送信されます。ミスを防ぐため、未送信の編集は下書きとして保持できます。';
			case 'strings.legacy.msg_sign_2': return 'サインアウト';
			case 'strings.legacy.msg_end_time': return '終了時刻';
			case 'strings.legacy.msg_sync_recent_content': return '最近のコンテンツを同期';
			case 'strings.legacy.msg_resetting_local_data': return 'ローカルデータをリセット中...';
			case 'strings.legacy.msg_incorrect_password': return 'パスワードが正しくありません';
			case 'strings.legacy.msg_content_cannot_empty': return '内容を空にすることはできません';
			case 'strings.legacy.msg_preparing': return '準備中';
			case 'strings.legacy.msg_ai_summary_failed': return ({required Object formatSummaryError_e}) => 'AI要約に失敗しました: ${formatSummaryError_e}';
			case 'strings.legacy.msg_manage': return '管理';
			case 'strings.legacy.msg_keep_data_consistent_across_devices': return 'デバイス間でデータの整合性を保ちます。';
			case 'strings.legacy.msg_playback_failed': return ({required Object e}) => '再生に失敗しました: ${e}';
			case 'strings.legacy.msg_path_copied': return 'パスをコピーしました';
			case 'strings.legacy.msg_auth_settings': return '認証設定';
			case 'strings.legacy.msg_randomly_draw_memo_cards': return 'メモカードをランダムに引く';
			case 'strings.legacy.msg_copy_log_text': return 'ログテキストをコピー';
			case 'strings.legacy.msg_yes': return 'はい';
			case 'strings.legacy.msg_save_open_alipay_scan': return '保存してAlipayを開き、スキャンしてください';
			case 'strings.legacy.msg_signed_but_no_token_returned': return 'サインインしましたが、トークンが返されませんでした';
			case 'strings.legacy.msg_create_failed': return ({required Object formatError_e_context}) => '作成に失敗しました: ${formatError_e_context}';
			case 'strings.legacy.msg_expand': return '展開';
			case 'strings.legacy.msg_local_library_only': return 'ローカルライブラリのみ';
			case 'strings.legacy.msg_reminder_channel': return 'リマインダーチャンネル';
			case 'strings.legacy.msg_grant': return '許可';
			case 'strings.legacy.msg_import_canceled': return 'インポートをキャンセルしました。';
			case 'strings.legacy.msg_never': return 'しない';
			case 'strings.legacy.msg_release_notes': return 'リリースノート';
			case 'strings.legacy.msg_failed_load_references': return '参照の読み込みに失敗しました';
			case 'strings.legacy.msg_select_tags': return 'タグを選択';
			case 'strings.legacy.msg_failed_load_try': return '読み込みに失敗しました。もう一度お試しください。';
			case 'strings.legacy.msg_logs_copied': return 'ログをコピーしました';
			case 'strings.legacy.msg_shortcuts_not_supported_server': return 'このサーバーではショートカットはサポートされていません。';
			case 'strings.legacy.msg_reply_2': return ({required Object name}) => '${name} に返信...';
			case 'strings.legacy.msg_anonymous': return '匿名';
			case 'strings.legacy.msg_username': return 'ユーザー名';
			case 'strings.legacy.msg_update_memo': return 'メモを更新';
			case 'strings.legacy.msg_saved': return ({required Object targetPath}) => '保存先: ${targetPath}';
			case 'strings.legacy.msg_chinese_simplified': return '中国語（簡体字）';
			case 'strings.legacy.msg_memo_copied': return 'メモをコピーしました';
			case 'strings.legacy.msg_collapse': return '折りたたむ';
			case 'strings.legacy.msg_retry_count_controls_how_many_extra': return '再試行回数は、失敗時に行う追加試行の回数を制御します。値を大きくすると成功率が上がる可能性がありますが、時間がかかります。';
			case 'strings.legacy.msg_recording_info_missing': return '記録情報がありません';
			case 'strings.legacy.msg_sync_task': return '同期タスク';
			case 'strings.legacy.msg_clear_all_debug_logs': return 'すべてのデバッグログを消去しますか？';
			case 'strings.legacy.msg_export_finished': return 'エクスポートが完了しました';
			case 'strings.legacy.msg_failed_stop_recording': return ({required Object e}) => '記録の停止に失敗しました: ${e}';
			case 'strings.legacy.msg_my_profile': return 'マイプロフィール';
			case 'strings.legacy.msg_image_bed': return '画像ベッド';
			case 'strings.legacy.msg_failed_open_notification': return ({required Object e}) => '通知を開けませんでした: ${e}';
			case 'strings.legacy.msg_manual': return 'マニュアル';
			case 'strings.legacy.msg_no_html_file_found_zip': return 'ZIP内にHTMLファイルが見つかりませんでした。';
			case 'strings.legacy.msg_also_clear_local_cache_account_offline': return 'この操作により、このアカウントのローカルキャッシュ（オフラインデータ／下書き／保留中の同期キュー）も削除されます。この操作は元に戻せません。';
			case 'strings.legacy.msg_restore': return '復元';
			case 'strings.legacy.msg_auto_backup': return '自動バックアップ';
			case 'strings.legacy.msg_generate_summary': return '要約を生成';
			case 'strings.legacy.msg_days': return ({required Object stats_activeDays}) => '${stats_activeDays}日';
			case 'strings.legacy.msg_count': return '- 件数';
			case 'strings.legacy.msg_weekly': return '毎週';
			case 'strings.legacy.msg_notifications': return '通知';
			case 'strings.legacy.msg_backup_failed': return 'バックアップに失敗しました';
			case 'strings.legacy.msg_private': return '非公開';
			case 'strings.legacy.msg_filter_tags': return 'タグで絞り込む';
			case 'strings.legacy.msg_clear_logs': return 'ログを消去';
			case 'strings.legacy.msg_unable_open_browser': return 'ブラウザを開けません';
			case 'strings.legacy.msg_attachment_too_large': return '添付ファイルが大きすぎます';
			case 'strings.legacy.msg_query': return 'クエリ';
			case 'strings.legacy.msg_match_all': return 'すべて一致';
			case 'strings.legacy.msg_record_request_response_logs': return 'リクエスト／レスポンスログを記録';
			case 'strings.legacy.msg_import_file': return 'ファイルをインポート';
			case 'strings.legacy.msg_content_tags': return '本文＋タグ';
			case 'strings.legacy.msg_feature_not_available_local_library_mode': return 'この機能はローカルライブラリモードでは利用できません。';
			case 'strings.legacy.msg_import_failed': return ({required Object e}) => 'インポートに失敗しました: ${e}';
			case 'strings.legacy.msg_save_memo': return 'メモとして保存';
			case 'strings.legacy.msg_scan_disk_directory_merge_local_database': return 'ディスクディレクトリをスキャンしてローカルデータベースに統合しますか？ 見つからないファイルは削除として扱われます。';
			case 'strings.legacy.msg_passwords_not_match': return 'パスワードが一致しません';
			case 'strings.legacy.msg_signed_2': return ({required Object lastLoginUser}) => 'サインイン中: ${lastLoginUser}';
			case 'strings.legacy.msg_made_love_note_taking': return 'メモ作成を愛するあなたへ、心を込めて';
			case 'strings.legacy.msg_password_updated_local': return 'パスワードを更新しました（ローカル）';
			case 'strings.legacy.msg_retry': return '再試行';
			case 'strings.legacy.msg_memo_stats': return 'メモ統計';
			case 'strings.legacy.msg_shown_only_once_copy_keep_safe': return '一度だけ表示されます。コピーして安全に保管してください。';
			case 'strings.legacy.msg_describe_issue_time_repro_steps_etc': return '問題の内容、発生時刻、再現手順などを記載してください。';
			case 'strings.legacy.msg_how_many_days_back': return '何日前まで';
			case 'strings.legacy.msg_local_cache_cleared': return 'ローカルキャッシュを消去しました';
			case 'strings.legacy.msg_none': return 'なし';
			case 'strings.legacy.msg_body_json': return '本文（JSON）';
			case 'strings.legacy.msg_download_failed': return ({required Object e}) => 'ダウンロードに失敗しました: ${e}';
			case 'strings.legacy.msg_recycle_bin': return 'ごみ箱';
			case 'strings.legacy.msg_unpin': return 'ピン留めを解除';
			case 'strings.legacy.msg_advanced_security': return '詳細とセキュリティ';
			case 'strings.legacy.msg_run_issues_memoflow_e_g_sync': return 'MemoFlowで問題（例: 同期失敗、クラッシュ）が発生した場合は、以下の手順に従ってください。問題の診断と修正をより迅速に行うために役立ちます。\\n\\n';
			case 'strings.legacy.msg_remove_all_reminder_times_memo': return 'このメモのすべてのリマインダー時刻を削除します。';
			case 'strings.legacy.msg_no_summary_save': return '保存する要約がありません';
			case 'strings.legacy.msg_reset_language_selection': return '言語選択をリセット';
			case 'strings.legacy.msg_v_30_days': return '30日';
			case 'strings.legacy.msg_e_g_mood_check': return '例: 気分チェック';
			case 'strings.legacy.msg_note_some_tokens_returned_only_once': return '注意: 一部のトークンは一度しか返されず、後から取得できません。安全に保管してください。';
			case 'strings.legacy.msg_syncing': return '同期中...';
			case 'strings.legacy.msg_retention': return '保持期間';
			case 'strings.legacy.msg_open_login_screen': return 'ログイン画面を開く';
			case 'strings.legacy.msg_apply_all': return 'すべてに適用';
			case 'strings.legacy.msg_write_something_supports_tag_tasks_x': return '何か書いてみましょう... #タグ とタスク [ ] / [x] をサポート';
			case 'strings.legacy.msg_http': return ({required Object base, required Object status, required Object msg}) => '${base}（HTTP ${status}）: ${msg}';
			case 'strings.legacy.msg_single': return '単一';
			case 'strings.legacy.msg_delete_memo': return 'メモを削除しますか？';
			case 'strings.legacy.msg_ai_provider': return 'AIプロバイダー';
			case 'strings.legacy.msg_release_notes_v': return ({required Object version}) => 'リリースノート v${version}';
			case 'strings.legacy.msg_info_only_used_background_ai_summaries': return 'この情報はAI要約／レポートの背景情報としてのみ使用され、バックエンドには同期されません。';
			case 'strings.legacy.msg_not_disturb': return 'おやすみモード';
			case 'strings.legacy.msg_local_library_import_failed': return ({required Object e}) => 'ローカルライブラリのインポートに失敗しました: ${e}';
			case 'strings.legacy.msg_key_insights': return '主なインサイト';
			case 'strings.legacy.msg_additional_notes_optional': return '追加メモ（任意）';
			case 'strings.legacy.msg_server_response_error': return 'サーバー応答エラー。';
			case 'strings.legacy.msg_sort': return '並び替え';
			case 'strings.legacy.msg_api_call': return 'API呼び出し';
			case 'strings.legacy.msg_webhooks': return 'Webhook';
			case 'strings.legacy.msg_local_library': return 'ローカルライブラリ';
			case 'strings.legacy.msg_log_copied': return 'ログをコピーしました';
			case 'strings.legacy.msg_last_success': return '最終成功';
			case 'strings.legacy.msg_restore_cloud': return 'クラウドから復元';
			case 'strings.legacy.msg_search_public_memos': return '公開メモを検索';
			case 'strings.legacy.msg_cancel': return 'キャンセル';
			case 'strings.legacy.msg_processing': return ({required Object processed, required Object total}) => '${processed} / ${total} を処理中';
			case 'strings.legacy.msg_failed_items': return '失敗した項目';
			case 'strings.legacy.msg_recording_file_not_found': return '録音ファイルが見つかりません';
			case 'strings.legacy.msg_local_db_outbox_queue': return 'ローカルDB＋outboxキュー';
			case 'strings.legacy.msg_remove': return '削除';
			case 'strings.legacy.msg_export_format': return 'エクスポート形式';
			case 'strings.legacy.msg_idle': return '待機中';
			case 'strings.legacy.msg_ago': return ({required Object months}) => '${months}前';
			case 'strings.legacy.msg_no_tags_yet': return 'タグはまだありません';
			case 'strings.legacy.msg_version_v': return ({required Object version}) => 'バージョン v${version}';
			case 'strings.legacy.msg_sync': return '同期';
			case 'strings.legacy.msg_done': return '完了';
			case 'strings.legacy.msg_gallery_permission_required_2': return 'ギャラリーへのアクセス権が必要です';
			case 'strings.legacy.msg_insufficient_permissions': return '権限が不足しています';
			case 'strings.legacy.msg_no_download_url_available': return 'ダウンロードURLが利用できません';
			case 'strings.legacy.msg_record_create_memos': return 'メモを作成するために記録する';
			case 'strings.legacy.msg_signing': return 'サインイン中...';
			case 'strings.legacy.msg_memoflow_uses_system_location_permission_get': return 'MemoFlowは座標を取得するためにシステムの位置情報権限を使用し、その後Amap Web APIで逆ジオコーディングを行います。表示精度は上で選択できます。';
			case 'strings.legacy.msg_continue': return '続行';
			case 'strings.legacy.msg_notification_content_unavailable': return '通知内容を利用できません';
			case 'strings.legacy.msg_unable_read_file_path': return 'ファイルパスを読み取れません。';
			case 'strings.legacy.msg_all_memos': return 'すべてのメモ';
			case 'strings.legacy.msg_keywords': return 'キーワード';
			case 'strings.legacy.msg_import_result': return 'インポート結果';
			case 'strings.legacy.msg_offline_sync': return 'オフライン同期';
			case 'strings.legacy.msg_imported_memos_local_library': return 'ローカルライブラリからメモをインポートしました';
			case 'strings.legacy.msg_request_failed': return 'リクエストに失敗しました';
			case 'strings.legacy.msg_log_file': return 'ログファイル';
			case 'strings.legacy.msg_after_confirming_support_unlock_limited_gold': return 'サポートを確認すると、期間限定のゴールドバッジまたは永久広告なしの約束（そもそも広告はありませんでした）が解除されます。';
			case 'strings.legacy.msg_failed_open_system_settings': return 'システム設定を開けませんでした';
			case 'strings.legacy.msg_no_mood_trend': return '気分の推移はありません';
			case 'strings.legacy.msg_memoflow_export': return '# MemoFlow エクスポート';
			case 'strings.legacy.msg_sync_queue': return '同期キュー';
			case 'strings.legacy.msg_only_delete_sync_task_memo_kept': return '同期タスクのみを削除します。メモは保持されます。';
			case 'strings.legacy.msg_add_home_screen': return 'ホーム画面に追加';
			case 'strings.legacy.msg_past_days': return '過去の日数';
			case 'strings.legacy.msg_poster_generation_failed': return 'ポスターの生成に失敗しました';
			case 'strings.legacy.msg_failed_load_stats': return ({required Object e}) => '統計の読み込みに失敗しました: ${e}';
			case 'strings.legacy.msg_customize_notification': return '通知をカスタマイズ';
			case 'strings.legacy.msg_updated_time': return '更新時刻 ↓';
			case 'strings.legacy.msg_network_connection_failed_check_network': return 'ネットワーク接続に失敗しました。ネットワークをご確認ください。';
			case 'strings.legacy.msg_special_thanks': return '特別な感謝:';
			case 'strings.legacy.msg_failed_comment': return ({required Object e}) => 'コメントに失敗しました: ${e}';
			case 'strings.legacy.msg_security_key_sig': return 'セキュリティキー（sig）';
			case 'strings.legacy.msg_save_gallery': return 'ギャラリーに保存';
			case 'strings.legacy.msg_request_sent_confirm_system_prompt': return 'リクエストを送信しました。システムのプロンプトで確認してください';
			case 'strings.legacy.msg_server_url': return 'サーバーURL';
			case 'strings.legacy.msg_period_review': return '期間レビュー';
			case 'strings.legacy.msg_settings_updated': return '設定を更新しました';
			case 'strings.legacy.msg_backend_0_21_not_supported_import': return 'バックエンド 0.21 はインポートに対応していません。アップグレードして再試行してください。';
			case 'strings.legacy.msg_failed_load_tags': return ({required Object e}) => 'タグの読み込みに失敗しました: ${e}';
			case 'strings.legacy.msg_enter_email': return 'メールアドレスを入力';
			case 'strings.legacy.msg_add_webhook': return 'Webhookを追加';
			case 'strings.legacy.msg_read': return '既読';
			case 'strings.legacy.msg_widgets': return 'ウィジェット';
			case 'strings.legacy.msg_default': return 'デフォルト';
			case 'strings.legacy.msg_memo_reminders': return 'メモのリマインダー';
			case 'strings.legacy.msg_import_flomo': return 'Flomoからインポート';
			case 'strings.legacy.msg_format_fixed_markdown_zip': return '形式はMarkdown + ZIPに固定されています';
			case 'strings.legacy.msg_enter_username_password': return 'ユーザー名とパスワードを入力';
			case 'strings.legacy.msg_loading': return '読み込み中...';
			case 'strings.legacy.msg_test_scheduled': return ({required Object timeLabel, required Object suffix, required Object pendingLabel}) => 'テストは ${timeLabel}${suffix}${pendingLabel} に予定されています';
			case 'strings.legacy.msg_edit_memo': return 'メモを編集';
			case 'strings.legacy.msg_save': return '保存';
			case 'strings.legacy.msg_laboratory': return 'ラボ';
			case 'strings.legacy.msg_use_local': return 'ローカルを使用';
			case 'strings.legacy.msg_retry_sync': return '同期を再試行';
			case 'strings.legacy.msg_e_g_my_role_topics_interest': return '例：自分の役割／関心のあるトピック／文体の好み など';
			case 'strings.legacy.msg_confirm_password': return 'パスワードを確認';
			case 'strings.legacy.msg_not_set': return '未設定';
			case 'strings.legacy.msg_no_memos_day': return 'この日のメモはありません';
			case 'strings.legacy.msg_shortcut_name': return 'ショートカット名';
			case 'strings.legacy.msg_edit_shortcut': return 'ショートカットを編集';
			case 'strings.legacy.msg_days_memos': return 'メモのある日数';
			case 'strings.legacy.msg_delete': return '削除';
			case 'strings.legacy.msg_test_reminder': return 'テスト通知';
			case 'strings.legacy.msg_enable_reminders': return 'リマインダーを有効にする';
			case 'strings.legacy.msg_links': return 'リンク';
			case 'strings.legacy.msg_location': return '位置情報';
			case 'strings.legacy.msg_import_file_2': return 'ファイルからインポート';
			case 'strings.legacy.msg_reply_3': return ({required Object creatorDisplayName_commentCreator_commentMemo_creator}) => '${creatorDisplayName_commentCreator_commentMemo_creator} に返信…';
			case 'strings.legacy.msg_created': return ({required Object widget_createdAtLabel}) => '${widget_createdAtLabel} を作成';
			case 'strings.legacy.msg_notifications_coming_soon': return '通知：近日公開';
			case 'strings.legacy.msg_view_full_contributors': return 'すべてのコントリビューターを見る';
			case 'strings.legacy.msg_no_times_set': return '時間が設定されていません';
			case 'strings.legacy.msg_ignore_tls_errors': return 'TLS エラーを無視';
			case 'strings.legacy.msg_no_content': return '内容がありません';
			case 'strings.legacy.msg_about_15_seconds_left': return '約15秒残っています';
			case 'strings.legacy.msg_view_imported_memos': return 'インポートしたメモを見る';
			case 'strings.legacy.msg_load_failed': return '読み込みに失敗しました';
			case 'strings.legacy.msg_disk_content_conflicts_local_pending_changes': return 'ディスク上の内容がローカルの保留中の変更と競合しています。ディスク上の内容でローカルの内容を上書きしてください。';
			case 'strings.legacy.msg_all_history_so_far_memoflow_since': return 'これまでの履歴は以上です\\nMEMOFLOW SINCE 2023';
			case 'strings.legacy.msg_cancelling': return 'キャンセル中';
			case 'strings.legacy.msg_reading_file': return 'ファイルを読み込み中…';
			case 'strings.legacy.msg_switch_workspace': return 'ワークスペースを切り替え';
			case 'strings.legacy.msg_optional_leave_empty_default': return '任意。デフォルトを使用する場合は空欄のままにしてください。';
			case 'strings.legacy.msg_memo_reminders_2': return 'メモのリマインダー';
			case 'strings.legacy.msg_save_failed_2': return ({required Object e}) => '保存に失敗しました: ${e}';
			case 'strings.legacy.msg_record_create_memos_sync_later': return '録音してメモを作成（後で同期）';
			case 'strings.legacy.msg_use_https_avoid_ignoring_tls_errors': return '認証情報を保護するため、HTTPS を使用し、TLS エラーの無視は避けてください。';
			case 'strings.legacy.msg_failed_load_announcement_config': return 'お知らせ設定の読み込みに失敗しました';
			case 'strings.legacy.msg_shortcuts': return 'ショートカット';
			case 'strings.legacy.msg_memo': return 'メモ';
			case 'strings.legacy.msg_maybe_later': return '後で';
			case 'strings.legacy.msg_server_connection': return 'サーバー接続';
			case 'strings.legacy.msg_days_2': return '日';
			case 'strings.legacy.msg_include_archived': return 'アーカイブを含む';
			case 'strings.legacy.msg_during_quiet_hours_reminders_silenced': return '静かな時間帯は、リマインダーは通知されません。';
			case 'strings.legacy.msg_preview_not_supported_type': return 'この種類ではプレビューはサポートされていません';
			case 'strings.legacy.msg_failed_load_2': return '読み込みに失敗しました';
			case 'strings.legacy.msg_create_token': return '新しいトークンを作成';
			case 'strings.legacy.msg_enter_name': return '名前を入力してください。';
			case 'strings.legacy.msg_api_url_incorrect': return 'API URL が正しくありません。';
			case 'strings.legacy.msg_user_general_settings': return 'ユーザー一般設定';
			case 'strings.legacy.msg_saved_memo': return 'メモとして保存しました';
			case 'strings.legacy.msg_restore_failed': return ({required Object e}) => '復元に失敗しました: ${e}';
			case 'strings.legacy.msg_token_tail': return ({required Object tail}) => 'トークン末尾 ${tail}';
			case 'strings.legacy.msg_manual_token': return '手動トークン';
			case 'strings.legacy.msg_ago_2': return ({required Object years}) => '${years} 前';
			case 'strings.legacy.msg_recent_searches': return '最近の検索';
			case 'strings.legacy.msg_restored': return '復元しました';
			case 'strings.legacy.msg_no_contributors_yet': return 'コントリビューターはまだいません';
			case 'strings.legacy.msg_no_record_yet': return '記録はまだありません';
			case 'strings.legacy.msg_reminder': return 'リマインダー';
			case 'strings.legacy.msg_enter_api_key_ai_settings': return 'AI 設定で API キーを入力してください';
			case 'strings.legacy.msg_reminder_settings': return 'リマインダー設定';
			case 'strings.legacy.msg_http_2': return ({required Object base, required Object status}) => '${base}（HTTP ${status}）';
			case 'strings.legacy.msg_edit_webhook': return 'Webhook を編集';
			case 'strings.legacy.msg_generate_share_poster': return '共有ポスターを生成';
			case 'strings.legacy.msg_archive_failed': return ({required Object e}) => 'アーカイブに失敗しました: ${e}';
			case 'strings.legacy.msg_comments': return ({required Object widget_commentCount}) => '${widget_commentCount} 件のコメント';
			case 'strings.legacy.msg_remove_account': return 'アカウントを削除しますか？';
			case 'strings.legacy.msg_chinese_traditional': return '中国語（繁体字）';
			case 'strings.legacy.msg_private_2': return '非公開';
			case 'strings.legacy.msg_current_streak': return '現在の連続記録';
			case 'strings.legacy.msg_generated_ai_memoflow': return 'AI により生成 · MemoFlow';
			case 'strings.legacy.msg_edit_completed': return '編集が完了しました';
			case 'strings.legacy.msg_local': return 'ローカル';
			case 'strings.legacy.msg_edit': return '編集';
			case 'strings.legacy.msg_text': return ({required Object shortUserName_item_sender}) => '${shortUserName_item_sender} から';
			case 'strings.legacy.msg_got': return '了解';
			case 'strings.legacy.msg_web_api_key': return 'Web API キー';
			case 'strings.legacy.msg_preview': return 'プレビュー';
			case 'strings.legacy.msg_enter_password': return 'パスワードを入力してください';
			case 'strings.legacy.msg_api': return 'API';
			case 'strings.legacy.msg_ok': return 'OK';
			case 'strings.legacy.msg_failed_load_shortcuts': return 'ショートカットの読み込みに失敗しました。';
			case 'strings.legacy.msg_after_recording_audio_added_current_draft': return '録音後、音声は添付ファイルとして現在の下書きに追加されるため、送信前に編集できます。最大長は60分です。文字起こしは後でサードパーティサービスを使って追加できます。';
			case 'strings.legacy.msg_pull_refresh': return '引っ張って更新';
			case 'strings.legacy.msg_unable_open_photo': return '写真を開けません';
			case 'strings.legacy.msg_existing_tokens': return '既存のトークン';
			case 'strings.legacy.msg_ai_settings': return 'AI 設定';
			case 'strings.legacy.msg_app_lock': return 'アプリロック';
			case 'strings.legacy.msg_total_notes': return 'メモ総数';
			case 'strings.legacy.msg_stats_loading': return '統計を読み込み中';
			case 'strings.legacy.msg_enter_token_description': return 'トークンの説明を入力';
			case 'strings.legacy.msg_enter_token': return 'トークンを入力';
			case 'strings.legacy.msg_api_plugins': return 'API とプラグイン';
			case 'strings.legacy.msg_parsing_file': return 'ファイルを解析中…';
			case 'strings.legacy.msg_english': return '英語';
			case 'strings.legacy.msg_activity_heatmap': return 'アクティビティヒートマップ';
			case 'strings.legacy.msg_mark_read': return '既読にする';
			case 'strings.legacy.msg_request': return 'リクエスト';
			case 'strings.legacy.msg_sync_failed': return ({required Object type, required Object memoError}) => '同期に失敗しました（${type}）: ${memoError}';
			case 'strings.legacy.msg_error_copied': return 'エラーをコピーしました';
			case 'strings.legacy.msg_only_local_index_removed_disk_files': return 'ローカルインデックスのみが削除され、ディスク上のファイルは保持されます。これは元に戻せません。';
			case 'strings.legacy.msg_switch_account': return 'アカウントを切り替え';
			case 'strings.legacy.msg_invalid_download_link': return '無効なダウンロードリンク';
			case 'strings.legacy.msg_about': return '情報';
			case 'strings.legacy.msg_icon': return 'アイコン';
			case 'strings.legacy.msg_reset_done_syncing': return 'リセット完了。同期中...';
			case 'strings.legacy.msg_enter_amap_web_api_key': return 'Amap Web APIキーを入力してください';
			case 'strings.legacy.msg_recycle_bin_coming_soon': return 'ごみ箱：近日対応';
			case 'strings.legacy.msg_empty_content': return '（内容が空です）';
			case 'strings.legacy.msg_note_most_features_offline_stats_ai': return '注: ほとんどの機能（オフライン/統計/AIレポート/エクスポート）はバックエンド変更なしで動作しますが、トークンは一度しか返されません？安全に保管してください。';
			case 'strings.legacy.msg_fixed': return '修正済み: ';
			case 'strings.legacy.msg_allow_sharing_links_images_other_apps': return '他のアプリからのリンクや画像をMemoFlowに共有できるようにします。';
			case 'strings.legacy.msg_invalid_request_parameters': return 'リクエストパラメータが無効です';
			case 'strings.legacy.msg_enter_api_url': return 'API URLを入力してください';
			case 'strings.legacy.msg_pending': return ({required Object result_pendingCount}) => '（保留中 ${result_pendingCount}）';
			case 'strings.legacy.msg_days_3': return ({required Object currentStreak}) => '${currentStreak}日';
			case 'strings.legacy.msg_poster_not_ready_yet': return 'ポスターはまだ準備できていません';
			case 'strings.legacy.msg_generated_memoflow': return 'MemoFlow により生成';
			case 'strings.legacy.msg_enter_name_2': return '名前を入力してください';
			case 'strings.legacy.msg_version': return 'バージョン';
			case 'strings.legacy.msg_memo_missing_disk_but_has_local': return 'メモがディスク上に見つかりませんが、ローカルに保留中の変更があります。ローカルで削除するにはディスクを使用してください。';
			case 'strings.legacy.msg_legacy_api_compatibility': return 'レガシーAPI互換性';
			case 'strings.legacy.msg_sync_parameters': return '同期パラメータ';
			case 'strings.legacy.msg_quick_prompts': return 'クイックプロンプト';
			case 'strings.legacy.msg_share_failed': return ({required Object e}) => '共有に失敗しました: ${e}';
			case 'strings.legacy.msg_no_memos_summarize_range': return 'この範囲に要約できるメモはありません';
			case 'strings.legacy.msg_characters': return '文字数';
			case 'strings.legacy.msg_capture_every_moment_record': return '記録するすべての瞬間を残そう';
			case 'strings.legacy.msg_vibration': return 'バイブレーション';
			case 'strings.legacy.msg_days_4': return '日';
			case 'strings.legacy.msg_prompt_title': return 'プロンプトタイトル';
			case 'strings.legacy.msg_show_all': return 'すべて表示';
			case 'strings.legacy.msg_no_memos_available': return '利用可能なメモがありません';
			case 'strings.legacy.msg_comment_unavailable': return 'コメントは利用できません';
			case 'strings.legacy.msg_refresh': return '更新';
			case 'strings.legacy.msg_syncing_2': return '同期中';
			case 'strings.legacy.msg_body': return '本文';
			case 'strings.legacy.msg_clear_2': return 'クリア';
			case 'strings.legacy.msg_third_party_share': return 'サードパーティ共有';
			case 'strings.legacy.msg_charging_station': return '充電ステーション';
			case 'strings.legacy.msg_attachments_2': return '添付ファイル';
			case 'strings.legacy.msg_when_enabled_must_verify_each_app': return '有効にすると、アプリ起動のたびに認証が必要になります。自動ロック時間は、アプリがバックグラウンドに移行した後、どれくらいで認証を要求するかを制御します。';
			case 'strings.legacy.msg_add_prompt': return 'プロンプトを追加';
			case 'strings.legacy.msg_include': return '含める';
			case 'strings.legacy.msg_created_time_2': return '作成日時 ↓';
			case 'strings.legacy.msg_choose_data_source_start_importing_memos': return 'メモのインポートを開始するデータソースを選択してください';
			case 'strings.legacy.msg_describe_how_want_summary': return '要約の希望内容を説明してください…';
			case 'strings.legacy.msg_keep_token_safe_not_share_api': return 'トークンは安全に保管し、共有しないでください。\\nAPIのレート制限は1分あたり60リクエストです。';
			case 'strings.legacy.msg_open_2': return '開く';
			case 'strings.legacy.msg_e_g_claude_3_5_sonnet': return '例: claude-3-5-sonnet-20241022';
			case 'strings.legacy.msg_failed_request_whitelist': return 'ホワイトリストのリクエストに失敗しました';
			case 'strings.legacy.msg_notification_deleted': return '通知を削除しました';
			case 'strings.legacy.msg_accounts': return 'アカウント';
			case 'strings.legacy.msg_add_local_library': return 'ローカルライブラリを追加';
			case 'strings.legacy.msg_sign_first': return '先にサインインしてください';
			case 'strings.legacy.msg_failed_parse_query': return 'クエリの解析に失敗しました';
			case 'strings.legacy.msg_note_logs_sanitized_automatically_sensitive_data': return '注: ログは自動的にサニタイズされます。機密データが残っている場合は、送信前にマスキングしてください。';
			case 'strings.legacy.msg_add': return '追加';
			case 'strings.legacy.msg_failed_load_3': return ({required Object memosError}) => '読み込みに失敗しました: ${memosError}';
			case 'strings.legacy.msg_max_chars_day': return '1日あたりの最大文字数';
			case 'strings.legacy.msg_choose_what_edited_image': return '編集した画像をどうするか選択してください。';
			case 'strings.legacy.msg_select': return '選択';
			case 'strings.legacy.msg_unnamed_token': return '（名前のないトークン）';
			case 'strings.legacy.msg_name': return '名前';
			case 'strings.legacy.msg_sure_want_delete_webhook': return 'このWebhookを削除してもよろしいですか？';
			case 'strings.legacy.msg_back': return '戻る';
			case 'strings.legacy.msg_no': return 'いいえ';
			case 'strings.legacy.msg_untitled': return '無題';
			case 'strings.legacy.msg_open_language_onboarding': return '言語オンボーディングを開く';
			case 'strings.legacy.msg_voice_memos': return 'ボイスメモ';
			case 'strings.legacy.msg_unable_open_browser_try': return 'ブラウザを開けませんでした。もう一度お試しください。';
			case 'strings.legacy.msg_date_range': return '日付範囲';
			case 'strings.legacy.msg_not_authenticated': return '認証されていません';
			case 'strings.legacy.msg_back_2': return '戻る';
			case 'strings.legacy.msg_local_library_removed': return 'ローカルライブラリを削除しました';
			case 'strings.legacy.msg_exact_alarm_permission_required': return '正確なアラーム権限が必要です';
			case 'strings.legacy.msg_visibility': return '公開範囲';
			case 'strings.legacy.msg_failed_start_recording': return ({required Object e}) => '録音の開始に失敗しました: ${e}';
			case 'strings.legacy.msg_mood_trend': return '気分の傾向';
			case 'strings.legacy.msg_local_library_name': return 'ローカルライブラリ名';
			case 'strings.legacy.msg_no_tokens_yet': return 'トークンはまだありません';
			case 'strings.legacy.msg_loading_2': return '読み込み中？';
			case 'strings.legacy.msg_location_permission_denied_permanently': return '位置情報の権限が永久に拒否されています';
			case 'strings.legacy.msg_download': return 'ダウンロード';
			case 'strings.legacy.msg_export_time': return '- エクスポート時刻';
			case 'strings.legacy.msg_enter_password_2': return 'パスワードを入力してください';
			case 'strings.legacy.msg_no_image_available': return '利用可能な画像がありません';
			case 'strings.legacy.msg_daily': return '毎日';
			case 'strings.legacy.msg_no_likes_yet': return 'いいねはまだありません';
			case 'strings.legacy.msg_basics': return '基本';
			case 'strings.legacy.msg_shortcut': return '新しいショートカット';
			case 'strings.legacy.msg_debug_tools': return 'デバッグツール';
			case 'strings.legacy.msg_save_settings': return '設定を保存';
			case 'strings.legacy.msg_date_range_2': return '日付範囲';
			case 'strings.legacy.msg_feedback': return 'フィードバック';
			case 'strings.legacy.msg_image_bed_2': return '画像ベッド';
			case 'strings.legacy.msg_restoring': return '復元中…';
			case 'strings.legacy.msg_export': return 'エクスポート';
			case 'strings.legacy.msg_enter_token_name': return 'トークン名を入力してください';
			case 'strings.legacy.msg_start_time': return '開始時刻';
			case 'strings.legacy.msg_preparing_file_structure': return 'ファイル構造を準備中';
			case 'strings.legacy.msg_sign_3': return 'サインイン';
			case 'strings.legacy.msg_scan_local_library': return 'ローカルライブラリをスキャン';
			case 'strings.legacy.msg_lsky_pro': return 'Lsky Pro';
			case 'strings.legacy.msg_exact_alarm_permission_off_reminders_may': return '正確なアラーム権限がオフです。リマインダーが時間どおりに通知されない可能性があります。今すぐ設定を開きますか？';
			case 'strings.legacy.msg_last_30_days': return '過去30日間';
			case 'strings.legacy.msg_match': return '一致';
			case 'strings.legacy.msg_auth_mode': return '認証モード';
			case 'strings.legacy.msg_unsupported_file_type': return 'サポートされていないファイル形式です。';
			case 'strings.legacy.msg_only_delete_sync_task': return '同期タスクのみを削除します。';
			case 'strings.legacy.msg_change_password': return 'パスワードを変更';
			case 'strings.legacy.msg_saved_2': return '保存済み';
			case 'strings.legacy.msg_import_export': return 'インポート / エクスポート';
			case 'strings.legacy.msg_created_2': return '作成日';
			case 'strings.legacy.msg_ai_summary': return 'AI要約';
			case 'strings.legacy.msg_progress': return '進行状況';
			case 'strings.legacy.msg_replace_memo_image': return 'メモ画像を置き換える';
			case 'strings.legacy.msg_app_settings': return 'アプリ設定';
			case 'strings.legacy.msg_copy_path': return 'パスをコピー';
			case 'strings.legacy.msg_components': return 'コンポーネント';
			case 'strings.legacy.msg_no_shortcuts': return 'ショートカットはありません';
			case 'strings.legacy.msg_location_timed_try': return '位置情報の取得がタイムアウトしました。もう一度お試しください。';
			case 'strings.legacy.msg_attach_location_info_memos_show_subtle': return '位置情報をメモに添付し、控えめな地名を表示します。';
			case 'strings.legacy.msg_send_failed': return ({required Object e}) => '送信に失敗しました: ${e}';
			case 'strings.legacy.msg_repeat': return '繰り返し';
			case 'strings.legacy.msg_not_signed': return 'サインインしていません';
			case 'strings.legacy.msg_no_webhooks_configured': return 'Webhook が設定されていません';
			case 'strings.legacy.msg_apply_token': return 'トークンを適用';
			case 'strings.legacy.msg_enable_reminder_permissions_2': return 'リマインダー権限を有効にする';
			case 'strings.legacy.msg_enter_backup_password': return 'バックアップパスワードを入力してください';
			case 'strings.legacy.msg_start_backup': return 'バックアップを開始';
			case 'strings.legacy.msg_last_sync': return '最終同期';
			case 'strings.legacy.msg_note_export_includes_content_already_synced': return '注: エクスポートには、すでにローカルデータベースに同期済みの内容（オフラインデータを含む）が含まれます。';
			case 'strings.legacy.msg_enter_username': return 'ユーザー名を入力してください';
			case 'strings.legacy.msg_settings_saved': return '設定を保存しました';
			case 'strings.legacy.msg_no_keywords': return 'キーワードはありません';
			case 'strings.legacy.msg_these_settings_apply_newly_created_memos': return 'これらの設定は新しく作成されるメモに適用されます。';
			case 'strings.legacy.msg_back_home': return 'ホームに戻る';
			case 'strings.legacy.msg_quiet_hours': return 'おやすみ時間';
			case 'strings.legacy.msg_add_account': return 'アカウントを追加';
			case 'strings.legacy.msg_reset_complete': return 'リセット完了';
			case 'strings.legacy.msg_no_shortcuts_configured': return 'ショートカットが設定されていません';
			case 'strings.legacy.msg_password': return 'パスワード';
			case 'strings.legacy.msg_importing': return 'インポート中';
			case 'strings.legacy.msg_visibility_2': return ({required Object visibilityLabel}) => '公開範囲: ${visibilityLabel}';
			case 'strings.legacy.msg_no_logs_yet': return 'ログはまだありません';
			case 'strings.legacy.msg_v_9_times_allowed': return '最大9回まで可能';
			case 'strings.legacy.msg_last_14_days': return '過去14日間';
			case 'strings.legacy.msg_location_disabled_enable_settings_first': return '位置情報が無効です。先に設定で有効にしてください。';
			case 'strings.legacy.msg_add_2': return '追加';
			case 'strings.legacy.msg_logs': return 'ログ';
			case 'strings.legacy.msg_references': return '参照';
			case 'strings.legacy.msg_importing_memos': return 'メモをインポート中...';
			case 'strings.legacy.msg_account_security': return 'アカウントとセキュリティ';
			case 'strings.legacy.msg_reminder_2': return 'リマインダー';
			case 'strings.legacy.msg_enable_scheduled_reminder_notifications': return 'スケジュールされたリマインダー通知を有効にします。';
			case 'strings.legacy.msg_no_links': return 'リンクはありません';
			case 'strings.legacy.msg_delete_memo_2': return 'メモを削除';
			case 'strings.legacy.msg_one_tap_add_not_supported_add': return 'ワンタップ追加はサポートされていません。ウィジェットピッカーから追加してください';
			case 'strings.legacy.msg_password_2': return '新しいパスワード';
			case 'strings.legacy.msg_processing_content': return 'コンテンツを処理中...';
			case 'strings.legacy.msg_status': return 'ステータス';
			case 'strings.legacy.msg_local_library_added': return 'ローカルライブラリを追加しました';
			case 'strings.legacy.msg_failed_open_try': return '開けませんでした。もう一度お試しください。';
			case 'strings.legacy.msg_removed_locally_now_deleted_server_when': return '今ローカルで削除され、オンライン時にサーバーからも削除されます。';
			case 'strings.legacy.msg_server_url_unavailable': return 'サーバーURLを利用できません';
			case 'strings.legacy.msg_no_release_notes_yet': return 'リリースノートはまだありません';
			case 'strings.legacy.msg_cancelling_2': return 'キャンセルしています...';
			case 'strings.legacy.msg_summaries_selected_range': return '選択範囲の要約';
			case 'strings.legacy.msg_expand_2': return '展開';
			case 'strings.legacy.msg_close': return '閉じる';
			case 'strings.legacy.msg_more_comments': return ({required Object remainingComments}) => 'コメントがあと${remainingComments}件';
			case 'strings.legacy.msg_backing': return 'バックアップ中…';
			case 'strings.legacy.msg_view_debug_logs': return 'デバッグログを表示';
			case 'strings.legacy.msg_location_permission_denied': return '位置情報の権限が拒否されました';
			case 'strings.legacy.msg_self_repair_reset_heatmap': return '自己修復: ヒートマップをリセット';
			case 'strings.legacy.msg_these_settings_changed_locally_remotely_choose': return 'これらの設定はローカルとリモートの両方で変更されました。どちらのバージョンを保持するか選択してください。';
			case 'strings.legacy.msg_not_authenticated_2': return '認証されていません。';
			case 'strings.legacy.msg_action_failed': return ({required Object e}) => '操作に失敗しました: ${e}';
			case 'strings.legacy.msg_shortcut_2': return '新しいショートカット';
			case 'strings.legacy.msg_url': return 'URL';
			case 'strings.legacy.msg_no_memos_found_html': return 'HTML内にメモが見つかりません。';
			case 'strings.legacy.msg_enter_what_want_summarize': return '要約したい内容を入力してください...';
			case 'strings.legacy.msg_unable_load_audio_source': return '音声ソースを読み込めません。';
			case 'strings.legacy.msg_strategy_id': return 'ストラテジーID';
			case 'strings.legacy.msg_copy_failed': return ({required Object e}) => 'コピーに失敗しました: ${e}';
			case 'strings.legacy.msg_enable_image_bed': return '画像ベッドを有効化';
			case 'strings.legacy.msg_active': return '有効';
			case 'strings.legacy.msg_account': return 'アカウント';
			case 'strings.legacy.msg_invalid_webdav_server_url': return '無効なWebDAVサーバーURL';
			case 'strings.legacy.msg_keep_local': return 'ローカルを保持';
			case 'strings.legacy.msg_within_range': return '範囲内';
			case 'strings.legacy.msg_generate_log_file': return 'ログファイルを生成';
			case 'strings.legacy.msg_ai_reports': return 'AIレポート';
			case 'strings.legacy.msg_battery_optimization': return 'バッテリー最適化';
			case 'strings.legacy.msg_sync_overview': return '同期の概要';
			case 'strings.legacy.msg_legacy_servers_not_support_search_filters': return '旧式サーバーは検索フィルターをサポートしていないため、結果が不完全な場合があります。';
			case 'strings.legacy.msg_conflicts_detected_run_manual_sync': return '競合が検出されました。手動同期を実行してください。';
			case 'strings.legacy.msg_authentication_failed_check_token': return '認証に失敗しました。トークンを確認してください。';
			case 'strings.legacy.msg_date_range_3': return '日付範囲';
			case 'strings.legacy.msg_help_ai_understand_better': return 'AIがあなたをよりよく理解できるようにする';
			case 'strings.legacy.msg_no_search_history': return '検索履歴がありません';
			case 'strings.legacy.msg_enter_api_path': return 'APIパスを入力';
			case 'strings.legacy.msg_stats': return '統計';
			case 'strings.legacy.msg_text_2': return '新規: ';
			case 'strings.legacy.msg_removing_signing_clear_local_cache_account': return '削除/サインアウトすると、このアカウントのローカルキャッシュ（オフラインデータ/下書き/保留中の同期キュー）が消去されます。';
			case 'strings.legacy.msg_updated_time_2': return '更新時刻 ↑';
			case 'strings.legacy.msg_province': return '都道府県';
			case 'strings.legacy.msg_submitting_sync_queue': return '同期キューを送信中';
			case 'strings.legacy.msg_failed': return '失敗';
			case 'strings.legacy.msg_set_time': return '時刻を設定';
			case 'strings.legacy.msg_enable_local_library_backup': return 'ローカルライブラリのバックアップを有効化';
			case 'strings.legacy.msg_cancel_2': return 'キャンセル';
			case 'strings.legacy.msg_week': return '今週';
			case 'strings.legacy.msg_like': return 'いいね';
			case 'strings.legacy.msg_location_services_disabled': return '位置情報サービスが無効です';
			case 'strings.legacy.msg_clears_local_cache_offline_memos_pending': return 'これによりローカルキャッシュ（オフラインメモ/保留キュー）が消去され、完全な再同期が実行されます。未同期のコンテンツは失われ、時間がかかる場合があります。続行しますか？';
			case 'strings.legacy.msg_load_more': return 'さらに読み込む';
			case 'strings.legacy.msg_pull_memo_list_refresh_sync_sync': return 'メモ一覧で下に引っ張って更新・同期してください。同期では最新の項目から取得します。統計/ヒートマップを完全に保つため、定期的に完全同期を実行してください。';
			case 'strings.legacy.msg_server_returned_error': return ({required Object code}) => 'サーバーがエラーを返しました（${code}）。';
			case 'strings.legacy.msg_sound_feedback': return 'サウンドとフィードバック';
			case 'strings.legacy.msg_memos_skipped_attachments_skipped': return ({required Object exportedMemoCount, required Object skippedMemoCount, required Object exportedAttachmentCount, required Object skippedAttachmentCount}) => 'メモ${exportedMemoCount}件（スキップ${skippedMemoCount}件）、添付ファイル${exportedAttachmentCount}件（スキップ${skippedAttachmentCount}件）。';
			case 'strings.legacy.msg_import_complete': return 'インポート完了';
			case 'strings.legacy.msg_text_3': return '新規';
			case 'strings.legacy.msg_max_per_day': return '1日あたりの最大数';
			case 'strings.legacy.msg_permissions_denied': return '権限が拒否されました';
			case 'strings.legacy.msg_memo_2': return '新しいメモ';
			case 'strings.legacy.msg_delete_reminder': return 'リマインダーを削除';
			case 'strings.legacy.msg_select_month': return '月を選択';
			case 'strings.legacy.msg_select_backup': return 'バックアップを選択';
			case 'strings.legacy.msg_no_keywords_2': return '#キーワードなし';
			case 'strings.legacy.msg_preparing_memo_content': return 'メモ内容を準備中';
			case 'strings.legacy.msg_prompt_content': return 'プロンプト内容';
			case 'strings.legacy.msg_default_prompt_ai_summaries_reports': return 'AI要約/レポートのデフォルトプロンプト';
			case 'strings.legacy.msg_intro': return '紹介';
			case 'strings.legacy.msg_monthly_stats': return '月間統計';
			case 'strings.legacy.msg_times_2': return '回';
			case 'strings.legacy.msg_file_has_already_been_imported_skipped': return 'このファイルはすでにインポートされています。スキップしました。';
			case 'strings.legacy.msg_token_tail_unknown': return 'トークン末尾が不明です';
			case 'strings.legacy.msg_press_back_exit': return '終了するにはもう一度戻るを押してください';
			case 'strings.legacy.msg_enter_password_3': return 'パスワードを入力してください';
			case 'strings.legacy.msg_sync_conflicts': return '同期の競合';
			case 'strings.legacy.msg_locale': return 'ロケール';
			case 'strings.legacy.msg_any': return '任意';
			case 'strings.legacy.msg_provider': return 'プロバイダー';
			case 'strings.legacy.msg_preview_2': return 'プレビュー';
			case 'strings.legacy.msg_automatically_upload_images_append_links_memo': return '画像を自動アップロードし、メモにリンクを追記します。';
			case 'strings.legacy.msg_import_file_not_found': return 'インポートファイルが見つかりません。';
			case 'strings.legacy.msg_today': return '今日';
			case 'strings.legacy.msg_link_card': return 'リンクカード';
			case 'strings.legacy.msg_expiration': return '有効期限';
			case 'strings.legacy.msg_summary_prompt_optional': return '要約プロンプト（任意）';
			case 'strings.legacy.msg_memos': return 'メモ';
			case 'strings.legacy.msg_recording_file_not_found_2': return '録音ファイルが見つかりません。';
			case 'strings.legacy.msg_backup_settings': return 'バックアップ設定';
			case 'strings.legacy.msg_mode': return 'モード';
			case 'strings.legacy.msg_no_markdown_memos_found_zip': return 'ZIP内にMarkdownメモが見つかりません。';
			case 'strings.legacy.msg_archived': return 'アーカイブ済み';
			case 'strings.legacy.msg_update_failed': return ({required Object e}) => '更新に失敗しました: ${e}';
			case 'strings.legacy.msg_enable_app_lock': return 'アプリロックを有効にする';
			case 'strings.legacy.msg_html_zip': return 'HTML / ZIP';
			case 'strings.legacy.msg_all': return 'すべて';
			case 'strings.legacy.msg_model': return 'モデル';
			case 'strings.legacy.msg_title': return 'タイトル';
			case 'strings.legacy.msg_amap_web_api': return 'Amap Web API';
			case 'strings.legacy.msg_saved_gallery': return 'ギャラリーに保存しました';
			case 'strings.legacy.msg_unread': return '未読';
			case 'strings.legacy.msg_exporting': return 'エクスポート中...';
			case 'strings.legacy.msg_network_timeout_try': return 'ネットワークがタイムアウトしました。もう一度お試しください。';
			case 'strings.legacy.msg_unlock': return 'ロック解除';
			case 'strings.legacy.msg_ago_3': return ({required Object diff_inDays}) => '${diff_inDays}前';
			case 'strings.legacy.msg_deserve_coffee_i_m_pulling_all': return 'このコーヒーに見合うように、100行のコードを書くために徹夜しています！';
			case 'strings.legacy.msg_token_name': return 'トークン名';
			case 'strings.legacy.msg_restore_completed': return '復元が完了しました';
			case 'strings.legacy.msg_copied_clipboard': return 'クリップボードにコピーしました';
			case 'strings.legacy.msg_failed_2': return ({required Object attempts}) => '失敗 ${attempts}';
			case 'strings.legacy.msg_too_many_requests_try_later': return 'リクエストが多すぎます。後でもう一度お試しください。';
			case 'strings.legacy.msg_more': return 'もっと見る';
			case 'strings.legacy.msg_already_whitelisted': return 'すでにホワイトリストに登録されています';
			case 'strings.legacy.msg_local_library_backup': return 'ローカルライブラリのバックアップ';
			case 'strings.legacy.msg_awesome': return '最高！ ❤️';
			case 'strings.legacy.msg_now': return '今';
			case 'strings.legacy.msg_select_reminder_time': return 'リマインダー時刻を選択';
			case 'strings.legacy.msg_protected': return '保護済み';
			case 'strings.legacy.msg_failed_load_4': return ({required Object e}) => '読み込みに失敗しました: ${e}';
			case 'strings.legacy.msg_operation_failed': return ({required Object e}) => '操作に失敗しました: ${e}';
			case 'strings.legacy.msg_no_tags': return 'タグなし';
			case 'strings.legacy.msg_server': return 'サーバー';
			case 'strings.legacy.msg_improved': return '改善済み';
			case 'strings.legacy.msg_request_2': return 'リクエスト';
			case 'strings.legacy.msg_export_failed': return ({required Object e}) => 'エクスポートに失敗しました: ${e}';
			case 'strings.legacy.msg_notification_settings': return '通知設定';
			case 'strings.legacy.msg_related_memo_was_deleted': return '関連するメモは削除されました';
			case 'strings.legacy.msg_email': return 'メール';
			case 'strings.legacy.msg_enter_password_4': return 'パスワードを入力してください';
			case 'strings.legacy.msg_retry_count': return '再試行回数';
			case 'strings.legacy.msg_import_exported_html_zip_package': return 'エクスポートしたHTMLまたはZIPパッケージをインポート';
			case 'strings.legacy.msg_archive': return 'アーカイブ';
			case 'strings.legacy.msg_reset_heatmap': return 'ヒートマップをリセットしますか？';
			case 'strings.legacy.msg_token_applied': return 'トークンを適用しました';
			case 'strings.legacy.msg_log_file_created': return 'ログファイルを作成しました';
			case 'strings.legacy.msg_delete_sync_task': return '同期タスクを削除';
			case 'strings.legacy.msg_include_archived_2': return '- アーカイブを含める';
			case 'strings.legacy.msg_memoflow_side_project_i_build_my': return 'MemoFlowは、空き時間に開発しているサイドプロジェクトです。バグ修正で夜更かしが続いていて、アイスアメリカーノが本当に欲しいです。あなたのサポートがエネルギー補給になり、新機能のリリースを後押ししてくれます ';
			case 'strings.legacy.msg_failed_generate': return ({required Object e}) => '生成に失敗しました: ${e}';
			case 'strings.legacy.msg_search_logs': return 'ログを検索';
			case 'strings.legacy.msg_active_days': return 'アクティブ日数';
			case 'strings.legacy.msg_back_top': return 'トップに戻る';
			case 'strings.legacy.msg_month': return '今月';
			case 'strings.legacy.msg_loading_references': return '参照を読み込み中';
			case 'strings.legacy.msg_silent': return 'サイレント';
			case 'strings.legacy.msg_settings': return '設定';
			case 'strings.legacy.msg_locating': return '位置情報を取得中...';
			case 'strings.legacy.msg_scan': return 'スキャン';
			case 'strings.legacy.msg_recording_path_missing': return '録音パスが見つかりません。';
			case 'strings.legacy.msg_date_range_4': return '- 日付範囲';
			case 'strings.legacy.msg_suggested_tags': return 'おすすめタグ';
			case 'strings.legacy.msg_energy_restored': return '⚡ エネルギー回復';
			case 'strings.legacy.msg_username_2': return 'ユーザー名';
			case 'strings.legacy.msg_ai_summary_report': return 'AI要約レポート';
			case 'strings.legacy.msg_all_tags': return 'すべてのタグ';
			case 'strings.legacy.msg_preferences': return '環境設定';
			case 'strings.legacy.msg_image_bed_3': return '画像ベッド';
			case 'strings.legacy.msg_quick_input': return 'クイック入力';
			case 'strings.legacy.msg_tags': return 'タグ';
			case 'strings.legacy.msg_energy_critically_low': return 'エネルギーが危険水準です！';
			case 'strings.legacy.msg_delete_failed': return ({required Object e}) => '削除に失敗しました: ${e}';
			case 'strings.legacy.msg_server_login': return 'サーバーログイン';
			case 'strings.legacy.msg_like_2': return 'いいね';
			case 'strings.legacy.msg_save_2': return '保存';
			case 'strings.legacy.msg_unknown': return '不明';
			case 'strings.legacy.msg_release_notes_2': return 'リリースノート';
			case 'strings.legacy.msg_include_error_details': return 'エラー詳細を含める';
			case 'strings.legacy.msg_write_comment': return 'コメントを書く...';
			case 'strings.legacy.msg_write_thoughts': return '考えを書き留めてください...';
			case 'strings.legacy.msg_local_2': return 'ローカル';
			case 'strings.legacy.msg_expired': return '期限切れ';
			case 'strings.legacy.msg_fixed_2': return '修正済み';
			case 'strings.legacy.msg_upload_attachment': return '添付ファイルをアップロード';
			case 'strings.legacy.msg_battery_whitelist': return 'バッテリーのホワイトリスト';
			case 'strings.legacy.msg_district': return '地区';
			case 'strings.legacy.msg_voice_memo': return '🎙️ ボイスメモ\\n';
			case 'strings.legacy.msg_system_default': return 'システムのデフォルト';
			case 'strings.legacy.msg_all_memos_2': return 'すべてのメモ';
			case 'strings.legacy.msg_network_request_failed': return 'ネットワークリクエストに失敗しました';
			case 'strings.legacy.msg_memo_not_found': return 'メモが見つかりません';
			case 'strings.legacy.msg_playback_failed_2': return ({required Object e}) => '再生に失敗しました: ${e}';
			case 'strings.legacy.msg_sync_settings_webdav_across_devices': return 'デバイス間で同期するために、WebDAVへ設定を保存します。';
			case 'strings.legacy.msg_offline_first_client_memos_backend': return 'Memosバックエンド向けのオフラインファーストクライアント。';
			case 'strings.legacy.msg_user_guide': return 'ユーザーガイド';
			case 'strings.legacy.msg_notice': return 'お知らせ';
			case 'strings.legacy.msg_exact_alarms': return '正確なアラーム';
			case 'strings.legacy.msg_restoring_overwrite_local_library_files_rebuild': return '復元するとローカルライブラリのファイルが上書きされ、データベースが再構築されます。これは元に戻せません。';
			case 'strings.legacy.msg_enter_api_url_ai_settings': return 'AI設定でAPI URLを入力してください';
			case 'strings.legacy.msg_create_failed_2': return ({required Object e}) => '作成に失敗しました: ${e}';
			case 'strings.legacy.msg_close_search': return '検索を閉じる';
			case 'strings.legacy.msg_imported_memos_2': return 'メモをインポートしました';
			case 'strings.legacy.msg_explore': return '探索';
			case 'strings.legacy.msg_network_connection_failed': return 'ネットワーク接続に失敗しました。';
			case 'strings.legacy.msg_save_failed_3': return ({required Object e}) => '保存に失敗しました: ${e}';
			case 'strings.legacy.msg_no_summary_share': return '共有できる要約がありません';
			case 'strings.legacy.msg_custom_model': return 'カスタムモデル';
			case 'strings.legacy.msg_sign_failed': return ({required Object message}) => 'サインインに失敗しました: ${message}';
			case 'strings.legacy.msg_notification_exact_alarm_permissions_required_send': return '通知と正確なアラームの権限は、リマインダーを時間どおりに送信するために必要です。';
			case 'strings.legacy.msg_random_review': return 'ランダムレビュー';
			case 'strings.legacy.msg_public': return '公開';
			case 'strings.legacy.msg_all_2': return 'すべて';
			case 'strings.legacy.msg_add_custom_model': return 'カスタムモデルを追加';
			case 'strings.legacy.msg_backup_password': return 'バックアップパスワード';
			case 'strings.legacy.msg_optional_used_sign_requests': return '任意。リクエストの署名に使用されます。';
			case 'strings.legacy.msg_search': return '検索';
			case 'strings.legacy.msg_set_password': return 'パスワードを設定';
			case 'strings.legacy.msg_submit_logs': return 'ログを送信';
			case 'strings.legacy.msg_activity_heatmap_2': return 'アクティビティヒートマップ';
			case 'strings.legacy.msg_invalid_api_key_insufficient_permissions': return 'APIキーが無効か、権限が不足しています。';
			case 'strings.legacy.msg_data_has_been_migrated_app_successfully': return 'データはこのアプリに正常に移行されました。';
			case 'strings.legacy.msg_get_version': return '新しいバージョンを入手';
			case 'strings.legacy.msg_token_source': return 'トークンソース';
			case 'strings.legacy.msg_send': return '送信';
			case 'strings.legacy.msg_no_pending_sync_tasks': return '保留中の同期タスクはありません';
			case 'strings.legacy.msg_locating_memo_content': return 'メモ内容を特定中';
			case 'strings.legacy.msg_offline_ready': return 'オフライン対応';
			case 'strings.legacy.msg_use_relative_path': return '相対パスを使用';
			case 'strings.legacy.msg_total': return '合計';
			case 'strings.legacy.msg_location_2': return '位置情報';
			case 'strings.legacy.msg_show_location_metadata_memos_not_configured': return 'メモに位置情報メタデータを表示します。設定されていない場合は、代わりに座標が表示されます。';
			case 'strings.legacy.msg_api_url': return 'API URL';
			case 'strings.legacy.msg_parsing_progress': return '解析の進捗';
			case 'strings.legacy.msg_parsing': return '解析中';
			case 'strings.legacy.msg_custom': return 'カスタム';
			case 'strings.legacy.msg_tags_created': return '新しいタグが作成されました';
			case 'strings.legacy.msg_third_party_share_disabled': return 'サードパーティ共有は無効です';
			case 'strings.legacy.msg_loading_links': return 'リンクを読み込み中...';
			case 'strings.legacy.msg_how_report': return '報告方法は？';
			case 'strings.legacy.msg_confirm_password_2': return 'パスワードを確認';
			case 'strings.legacy.msg_search_title_content_tags': return 'タイトル、内容、またはタグで検索';
			case 'strings.legacy.msg_reset_failed': return ({required Object e}) => 'リセットに失敗しました: ${e}';
			case 'strings.legacy.msg_debug_preview_update_dialog': return 'デバッグ: 更新ダイアログをプレビュー';
			case 'strings.legacy.msg_what_s': return '新機能';
			case 'strings.legacy.msg_ringtone': return '着信音';
			case 'strings.legacy.msg_unable_detect_backend_version_check_server': return 'バックエンドのバージョンを検出できません。サーバーURLまたはネットワークを確認してください。';
			case 'strings.legacy.msg_pending_2': return '保留中';
			case 'strings.legacy.msg_parsing_html': return 'HTMLを解析中...';
			case 'strings.legacy.msg_actions': return '操作';
			case 'strings.legacy.msg_import_complete_2': return 'インポート完了';
			case 'strings.legacy.msg_use_disk': return 'ディスクを使用';
			case 'strings.legacy.msg_root_path': return 'ルートパス';
			case 'strings.legacy.msg_disabled': return '無効';
			case 'strings.legacy.msg_improved_2': return '改善: ';
			case 'strings.legacy.msg_city': return '市';
			case 'strings.legacy.msg_decoding_zip': return 'ZIPをデコード中...';
			case 'strings.legacy.msg_notification_content': return '通知内容';
			case 'strings.legacy.msg_resolve_conflict': return '競合を解決';
			case 'strings.legacy.msg_webhooks_not_supported_server': return 'このサーバーではWebhookはサポートされていません。';
			case 'strings.legacy.msg_may_delayed': return ' （遅延する可能性があります）';
			case 'strings.legacy.msg_permissions_system_settings': return '権限とシステム設定';
			case 'strings.legacy.msg_waiting_tasks_stop': return 'タスクの停止を待機中';
			case 'strings.legacy.msg_done_2': return '完了';
			case 'strings.legacy.msg_parsing_memoflow_export': return 'MemoFlowエクスポートを解析中...';
			case 'strings.legacy.msg_location_updated': return ({required Object next_displayText_fractionDigits_6}) => '位置情報が更新されました: ${next_displayText_fractionDigits_6}';
			case 'strings.legacy.msg_checking_server_version': return 'サーバーバージョンを確認中...';
			case 'strings.legacy.msg_next_time_back_fixing_bugs': return '👀 次回は、バグ修正に戻る';
			case 'strings.legacy.msg_ago_4': return ({required Object weeks}) => '${weeks}前';
			case 'strings.legacy.msg_import': return 'インポート';
			case 'strings.legacy.msg_ios_long_press_home_screen_add': return 'iOSでは、ホーム画面を長押ししてMemoFlowウィジェットを追加します';
			case 'strings.legacy.msg_create_token_2': return 'トークンを作成';
			case 'strings.legacy.msg_marked_read': return '既読にしました';
			case 'strings.legacy.msg_pinned': return 'ピン留め済み';
			case 'strings.legacy.msg_version_update': return 'バージョン更新';
			case 'strings.legacy.msg_allow_private_memos': return 'プライベートメモを許可';
			case 'strings.legacy.msg_token_copied_clipboard': return 'トークンをクリップボードにコピーしました';
			case 'strings.legacy.msg_keeping_more_versions_uses_more_storage': return 'より多くのバージョンを保持すると、より多くのストレージを使用します。古いバージョンの整理を検討してください。';
			case 'strings.legacy.msg_delete_webhook': return 'Webhookを削除';
			case 'strings.legacy.msg_prompt': return 'プロンプト';
			case 'strings.legacy.msg_location_precision': return '位置情報の精度';
			case 'strings.legacy.msg_password_required': return 'パスワードが必要です';
			case 'strings.legacy.msg_exit_app': return 'アプリを終了';
			case 'strings.legacy.msg_thanks_energy_fully_restored': return 'ありがとうございます！エネルギーが完全に回復しました⚡';
			case 'strings.legacy.msg_connection_timeout_check_network_api_url': return '接続がタイムアウトしました。ネットワークまたはAPI URLを確認してください。';
			case 'strings.legacy.app_language.system': return 'システムに従う';
			case 'strings.legacy.app_language.zh_hans': return '中国語（簡体）';
			case 'strings.legacy.app_language.zh_hant_tw': return '中国語（繁体・中国台湾）';
			case 'strings.legacy.app_language.en': return '英語';
			case 'strings.legacy.app_language.ja': return '日本語';
			case 'strings.legacy.app_language.de': return 'ドイツ語';
			case 'strings.legacy.app_theme.system': return 'システム';
			case 'strings.legacy.app_theme.light': return 'ライト';
			case 'strings.legacy.app_theme.dark': return 'ダーク';
			case 'strings.legacy.app_font_size.standard': return '標準';
			case 'strings.legacy.app_font_size.large': return '大';
			case 'strings.legacy.app_font_size.small': return '小';
			case 'strings.legacy.app_line_height.classic': return 'クラシック';
			case 'strings.legacy.app_line_height.compact': return 'コンパクト';
			case 'strings.legacy.app_line_height.relaxed': return 'ゆったり';
			case 'strings.legacy.launch_action.none': return 'なし';
			case 'strings.legacy.launch_action.sync': return '同期';
			case 'strings.legacy.launch_action.quick_input': return 'クイック入力';
			case 'strings.legacy.launch_action.daily_review': return 'ランダムレビュー';
			case 'strings.legacy.auto_lock_time.immediately': return 'すぐに';
			case 'strings.legacy.auto_lock_time.after_1_min': return '1分';
			case 'strings.legacy.auto_lock_time.after_5_min': return '5分';
			case 'strings.legacy.auto_lock_time.after_15_min': return '15分';
			case 'strings.legacy.reminder.default_title': return 'ねえ、このアイデア覚えてる？';
			case 'strings.legacy.reminder.default_body': return 'タップして詳細を見る';
			case 'strings.legacy.location.current': return '現在地';
			case 'strings.legacy.webdav.not_configured': return 'WebDAV が設定されていません';
			case 'strings.legacy.webdav.backup_disabled': return 'バックアップは無効です';
			case 'strings.legacy.webdav.backup_account_missing': return 'バックアップ用のアカウントがありません';
			case 'strings.legacy.webdav.backup_local_only': return 'バックアップはローカルライブラリのみ利用できます';
			case 'strings.legacy.webdav.backup_password_missing': return 'バックアップパスワードがありません';
			case 'strings.legacy.webdav.backup_no_memo_files': return 'ローカルライブラリにメモファイルが見つからないため、バックアップをキャンセルしました';
			case 'strings.legacy.webdav.restore_account_missing': return '復元用のアカウントがありません';
			case 'strings.legacy.webdav.restore_local_only': return '復元はローカルライブラリのみ利用できます';
			case 'strings.legacy.webdav.backup_empty': return 'バックアップが空です';
			case 'strings.legacy.webdav.backup_no_memos': return 'バックアップにメモがありません';
			case 'strings.legacy.webdav.snapshot_missing': return 'バックアップスナップショットがありません';
			case 'strings.legacy.webdav.snapshot_corrupted': return 'バックアップスナップショットが破損しています';
			case 'strings.legacy.webdav.object_missing': return 'バックアップオブジェクトがありません';
			case 'strings.legacy.webdav.config_corrupted': return 'バックアップ設定が破損しています';
			case 'strings.legacy.webdav.config_invalid': return '無効なバックアップ設定';
			case 'strings.legacy.webdav.password_invalid': return 'バックアップパスワードが正しくありません';
			case 'strings.legacy.webdav.data_corrupted': return 'バックアップデータが破損しています';
			case 'strings.legacy.webdav.server_url_invalid': return 'WebDAV サーバーURLが無効です';
			case 'strings.legacy.import_count_memos': return ({required Object count}) => '${count}';
			case 'strings.legacy.import_count_attachments': return ({required Object count}) => '${count}';
			case 'strings.legacy.app_drawer.tooltip_single': return ({required Object date, required Object weekday, required Object count}) => '${date}（${weekday}）・${count} 件';
			case 'strings.legacy.app_drawer.tooltip_multi': return ({required Object date, required Object weekday, required Object count}) => '${date}（${weekday}）・${count} 件';
			case 'strings.legacy.ai_summary.error_api_key_empty': return 'APIキーが空です';
			case 'strings.legacy.ai_summary.system.require_json': return 'JSONのみを厳密に出力してください。コードブロックや余計な説明は不要です。';
			case 'strings.legacy.ai_summary.system.json_format': return 'JSON形式：{"insights":["..."],"moodTrend":"...","keywords":["#..."]}';
			case 'strings.legacy.ai_summary.system.insights_rule': return 'insightsは2〜5件、keywordsは#付きの4〜8個にしてください。';
			case 'strings.legacy.ai_summary.user.range': return ({required Object rangeLabel}) => '期間：${rangeLabel}';
			case 'strings.legacy.ai_summary.user.counts': return ({required Object memoCount, required Object includedCount}) => 'メモ件数：${memoCount}（要約対象：${includedCount}）';
			case 'strings.legacy.ai_summary.user.profile': return ({required Object profile}) => 'ユーザープロフィール：${profile}';
			case 'strings.legacy.ai_summary.user.custom_prompt': return ({required Object customPrompt}) => '追加指示：${customPrompt}';
			case 'strings.legacy.ai_summary.user.memo_content': return 'メモ内容：';
			case 'strings.legacy.ai_summary.error_invalid_response': return 'AIの応答形式が正しくありません';
			case 'strings.legacy.ai_summary.error_empty_response': return 'AIの応答が空です';
			case 'strings.legacy.ai_summary.error_missing_content': return 'AIの応答内容が欠落しています';
			case 'strings.legacy.ai_summary.default_prompt': return 'あなたはミニマリストなノートアシスタントです。核心的なポイントを抽出し、上品な形式で整理してください。返信はプロフェッショナルで穏やか、簡潔な語調を保ち、できるだけ箇条書きと短い段落を使ってください。';
			default: return null;
		}
	}
}

extension on _StringsZhHans {
	dynamic _flatMapFunction(String path) {
		switch (path) {
			case 'strings.common.back': return '返回';
			case 'strings.common.cancel': return '取消';
			case 'strings.common.confirm': return '确认';
			case 'strings.common.save': return '保存';
			case 'strings.common.saveSettings': return '保存设置';
			case 'strings.common.auto': return '自动';
			case 'strings.common.manual': return '手动';
			case 'strings.common.copiedToClipboard': return '已复制到剪贴板';
			case 'strings.common.serverVersion': return '服务端版本';
			case 'strings.common.selectValidServerVersion': return '请选择有效服务端版本';
			case 'strings.common.serverVersionValue': return ({required Object version}) => '服务端版本: ${version}';
			case 'strings.common.selectServerVersionRange021To026': return '请先手动选择 0.21~0.26 服务端版本';
			case 'strings.languages.system': return '跟随系统';
			case 'strings.languages.zhHans': return '简体中文';
			case 'strings.languages.zhHantTw': return '繁体中文（中国台湾）';
			case 'strings.languages.en': return '英语';
			case 'strings.languages.ja': return '日语';
			case 'strings.languages.de': return '德语';
			case 'strings.languagesNative.system': return '系统';
			case 'strings.languagesNative.zhHans': return '简体中文';
			case 'strings.languagesNative.zhHantTw': return '繁體中文（中國台灣）';
			case 'strings.languagesNative.en': return '英语';
			case 'strings.languagesNative.ja': return '日本語';
			case 'strings.languagesNative.de': return 'Deutsch';
			case 'strings.onboarding.tagline': return '简约而强大的笔记流';
			case 'strings.onboarding.selectLanguage': return '选择语言';
			case 'strings.onboarding.selectMode': return '选择工作模式';
			case 'strings.onboarding.modeHint': return '您可以随时在设置中更改此项';
			case 'strings.onboarding.modeLocalTitle': return '单机模式';
			case 'strings.onboarding.modeLocalLabel': return 'LOCAL MODE';
			case 'strings.onboarding.modeLocalDesc': return '数据仅保存在手机本地，无需配置服务器，适合追求极致隐私与离线使用的用户。';
			case 'strings.onboarding.modeServerTitle': return '联机模式';
			case 'strings.onboarding.modeServerLabel': return 'SERVER MODE';
			case 'strings.onboarding.modeServerDesc': return '连接到你的 Memos 后端，实现多端实时同步。支持 Web、移动端等多平台无缝衔接。';
			case 'strings.onboarding.localLibraryNameTitle': return '本地库名称';
			case 'strings.onboarding.localLibraryNameHint': return '请输入名称';
			case 'strings.onboarding.localLibraryDefaultName': return '本地库';
			case 'strings.onboarding.getStarted': return '开始使用';
			case 'strings.login.title': return '连接 Memos';
			case 'strings.login.mode.password': return '账号密码';
			case 'strings.login.mode.token': return 'Token 登录';
			case 'strings.login.mode.descPassword': return '使用账号密码登录';
			case 'strings.login.mode.descToken': return '使用个人访问令牌登录';
			case 'strings.login.mode.signInMethod': return '登录方式';
			case 'strings.login.field.serverUrlLabel': return '服务器地址';
			case 'strings.login.field.serverUrlHint': return 'http://localhost:5230';
			case 'strings.login.field.usernameLabel': return '账号';
			case 'strings.login.field.usernameHint': return '请输入账号';
			case 'strings.login.field.passwordLabel': return '密码';
			case 'strings.login.field.passwordHint': return '请输入密码';
			case 'strings.login.field.tokenLabel': return 'Token (PAT)';
			case 'strings.login.field.tokenHint': return 'Token (PAT)';
			case 'strings.login.validation.serverUrlRequired': return '请输入服务器地址';
			case 'strings.login.validation.serverUrlInvalid': return '请输入完整地址（包含 http/https 与端口）';
			case 'strings.login.validation.usernameRequired': return '请输入账号';
			case 'strings.login.validation.passwordRequired': return '请输入密码';
			case 'strings.login.validation.tokenRequired': return '请输入 Token';
			case 'strings.login.compatibility.title': return '兼容模式';
			case 'strings.login.compatibility.description': return '使用旧版接口（适配旧版 Memos）';
			case 'strings.login.connect.connecting': return '连接中…';
			case 'strings.login.connect.action': return '连接';
			case 'strings.login.errors.authFailedToken': return '认证失败，请确认 Token 是否有效或未过期';
			case 'strings.login.errors.authFailedPat': return '认证失败。新版 Memos 请使用以 memos_pat_ 开头的 PAT（不要粘贴 Bearer 前缀）';
			case 'strings.login.errors.connectionFailedWithMessage': return ({required Object message}) => '连接失败：${message}';
			case 'strings.login.errors.connectionFailed': return ({required Object error}) => '连接失败：${error}';
			case 'strings.login.errors.signInFailed': return '登录失败，请检查账号和密码';
			case 'strings.login.errors.signInFailedWithMessage': return ({required Object message}) => '登录失败：${message}';
			case 'strings.login.errors.invalidServerUrl': return '服务器地址无效';
			case 'strings.login.errors.serverUrlNormalized': return '已规范化服务器地址（移除多余路径）';
			case 'strings.settings.preferences.title': return '偏好设置';
			case 'strings.settings.preferences.language': return '语言';
			case 'strings.settings.preferences.fontSize': return '字号';
			case 'strings.settings.preferences.lineHeight': return '行高';
			case 'strings.settings.preferences.font': return '字体';
			case 'strings.settings.preferences.systemDefault': return '系统默认';
			case 'strings.settings.preferences.noSystemFonts': return '未找到系统字体';
			case 'strings.settings.preferences.loadFontsFailed': return ({required Object error}) => '字体加载失败：${error}';
			case 'strings.settings.preferences.collapseLongContent': return '折叠长内容';
			case 'strings.settings.preferences.collapseReferences': return '折叠引用';
			case 'strings.settings.preferences.showEngagementInAllMemoDetails': return '在全部笔记详情中显示点赞和评论';
			case 'strings.settings.preferences.launchAction': return '启动动作';
			case 'strings.settings.preferences.quickInputKeyboard': return '快速记录时唤醒键盘';
			case 'strings.settings.preferences.appearance': return '外观';
			case 'strings.settings.preferences.themeColor': return '主题色';
			case 'strings.settings.preferences.haptics': return '触感反馈';
			case 'strings.settings.preferences.customTheme': return '自定义主题';
			case 'strings.settings.preferences.history': return '历史';
			case 'strings.settings.preferences.lightMode': return '浅色模式';
			case 'strings.settings.preferences.darkMode': return '深色模式';
			case 'strings.settings.preferences.surfaces': return '表面色';
			case 'strings.settings.preferences.background': return '背景';
			case 'strings.settings.preferences.backgroundColor': return '背景色';
			case 'strings.settings.preferences.card': return '卡片';
			case 'strings.settings.preferences.cardColor': return '卡片色';
			case 'strings.settings.preferences.border': return '边框';
			case 'strings.settings.preferences.borderColor': return '边框色';
			case 'strings.legacy.msg_memos_backend_docs': return 'memos后端使用文档';
			case 'strings.legacy.msg_remember_moment_feel_warmth_life_take': return '记住这一刻，感受生活的温度。\\n每天来一次随机漫步。';
			case 'strings.legacy.msg_sure_want_delete_shortcut': return '确定要删除该快捷筛选吗？';
			case 'strings.legacy.msg_scan_completed': return '扫描完成';
			case 'strings.legacy.msg_confirm': return '确认';
			case 'strings.legacy.msg_unable_open_browser_install_browser_app': return '无法打开浏览器，请检查是否安装了浏览器';
			case 'strings.legacy.msg_contributors': return '贡献与致谢';
			case 'strings.legacy.msg_enter_keywords_search_box_query_local': return '在搜索框输入关键词可检索本地内容与标签。离线可用；首次使用请等待本地索引完成。';
			case 'strings.legacy.msg_memo_not_found_locally': return '本地暂无该笔记';
			case 'strings.legacy.msg_token': return 'Token 摘要';
			case 'strings.legacy.msg_last_7_days': return '最近一周';
			case 'strings.legacy.msg_search_memo_content': return '搜索笔记内容';
			case 'strings.legacy.msg_retry_started': return '已开始重试同步';
			case 'strings.legacy.msg_last_year_memos': return ({required Object lastYearMemos}) => '最近一年记录 ${lastYearMemos} 条笔记';
			case 'strings.legacy.msg_no_content_yet': return '暂无内容';
			case 'strings.legacy.msg_no_summary_yet': return '暂无总结结果';
			case 'strings.legacy.msg_sooner': return ' 上线！';
			case 'strings.legacy.msg_token_copied': return 'Token 已复制';
			case 'strings.legacy.msg_share': return '分享';
			case 'strings.legacy.msg_gallery_permission_required': return '需要相册权限以保存二维码';
			case 'strings.legacy.msg_basic_settings': return '基础设置';
			case 'strings.legacy.msg_bad_ssl_certificate': return '证书校验失败';
			case 'strings.legacy.msg_no_notifications': return '暂无通知';
			case 'strings.legacy.msg_import_markdown': return '从 Markdown 导入';
			case 'strings.legacy.msg_upload_zip_package_md_files': return '请上传包含 .md 文件的 .zip 压缩包';
			case 'strings.legacy.msg_request_send_timeout_try': return '请求发送超时，请稍后重试';
			case 'strings.legacy.msg_select_date_range': return '选择时间范围';
			case 'strings.legacy.msg_delete_shortcut': return '删除快捷筛选';
			case 'strings.legacy.msg_auto_lock_time': return '自动锁定时间';
			case 'strings.legacy.msg_replacing_delete_original_attachment_continue': return '替换后将删除原图片附件，是否继续？';
			case 'strings.legacy.msg_add_least_one_condition': return '请至少设置一个条件';
			case 'strings.legacy.msg_upload_images_image_bed_append_links': return '开启后自动将图片上传到图床，并在文末插入图片链接。';
			case 'strings.legacy.msg_request_cancelled': return '请求已取消';
			case 'strings.legacy.msg_generating': return '生成中…';
			case 'strings.legacy.msg_permissions_denied_reminders_disabled': return '权限未授予，提醒未开启';
			case 'strings.legacy.msg_memoflow_local_reminders': return 'MemoFlow 本地提醒';
			case 'strings.legacy.msg_use_legacy_endpoints_older_memos_servers': return '使用旧版接口（适配旧版 Memos）';
			case 'strings.legacy.msg_no_comments_yet': return '暂无评论';
			case 'strings.legacy.msg_open': return '打开';
			case 'strings.legacy.msg_microphone_permission_required': return '需要麦克风权限';
			case 'strings.legacy.msg_failed_react': return ({required Object e}) => '点赞失败：${e}';
			case 'strings.legacy.msg_restore_backup': return '恢复备份？';
			case 'strings.legacy.msg_qr_saved_gallery': return '二维码已保存到系统相册';
			case 'strings.legacy.msg_no_attachments': return '暂无附件';
			case 'strings.legacy.msg_enable_reminder_permissions': return '启用提醒权限';
			case 'strings.legacy.msg_created_time': return '创建时间 ↑';
			case 'strings.legacy.msg_prompt_saved_quick_prompts': return '提示词将保存在快速总结中';
			case 'strings.legacy.msg_remember_password': return '记住密码';
			case 'strings.legacy.msg_enter_valid_url': return '请输入有效的 URL';
			case 'strings.legacy.msg_may_take_few_seconds': return '可能需要几秒钟';
			case 'strings.legacy.msg_local_sync_failed': return ({required Object type, required Object memoError}) => '本地同步失败（${type}）：${memoError}';
			case 'strings.legacy.msg_webdav_sync': return 'WebDAV 同步';
			case 'strings.legacy.msg_clear': return '清空';
			case 'strings.legacy.msg_clear_recycle_bin_confirm': return '确认清空回收站？回收站内所有内容将被永久删除。';
			case 'strings.legacy.msg_save_failed': return '保存失败';
			case 'strings.legacy.msg_endpoint_not_found_version_mismatch': return '接口不存在（可能是 Memos 版本不兼容）';
			case 'strings.legacy.msg_enable_webdav_sync': return '启用 WebDAV 同步';
			case 'strings.legacy.msg_local_libraries': return '本地库';
			case 'strings.legacy.msg_apply': return '确定';
			case 'strings.legacy.msg_restore_only_available_local_libraries': return '仅本地库可恢复备份';
			case 'strings.legacy.msg_sign': return '退出登录？';
			case 'strings.legacy.msg_reminders_disabled': return '提醒功能已关闭';
			case 'strings.legacy.msg_downloading': return '正在下载';
			case 'strings.legacy.msg_path': return '路径';
			case 'strings.legacy.msg_match_any': return '满足任一条件';
			case 'strings.legacy.msg_local_db_pending_queue': return '本地数据库 + 待同步队列';
			case 'strings.legacy.msg_scan_failed': return ({required Object e}) => '扫描失败：${e}';
			case 'strings.legacy.msg_user': return '用户';
			case 'strings.legacy.msg_pick_future_time': return '请选择未来时间';
			case 'strings.legacy.msg_include_pending_queue': return '包含待处理队列';
			case 'strings.legacy.msg_enter_days': return '输入天数';
			case 'strings.legacy.msg_times': return '提醒时间';
			case 'strings.legacy.msg_token_returned_only_once_cannot_fetched': return 'Token 仅返回一次，无法再次获取';
			case 'strings.legacy.msg_quoted_lines': return ({required Object quoteLines}) => '引用 ${quoteLines} 行';
			case 'strings.legacy.msg_use_remote': return '使用远端';
			case 'strings.legacy.msg_enable_memo_location': return '启用定位';
			case 'strings.legacy.msg_failed_get_location': return '定位失败';
			case 'strings.legacy.msg_after_import_memos_sync_list_automatically': return '导入完成后，您的笔记将自动同步到笔记列表。对于压缩包导入，请确保文件结构完整。';
			case 'strings.legacy.msg_legacy_mode': return '兼容模式';
			case 'strings.legacy.msg_signed': return '登录成功';
			case 'strings.legacy.msg_shortcut_includes_advanced_conditions_saving_overwrite': return '该快捷筛选包含高级条件，保存将覆盖这些条件。';
			case 'strings.legacy.msg_no_results_found': return '未找到相关内容';
			case 'strings.legacy.msg_reply': return ({required Object replyName}) => '回复 ${replyName}...';
			case 'strings.legacy.msg_copy': return '复制';
			case 'strings.legacy.msg_enable_reminders_memos': return '开启后可为笔记设置提醒时间。';
			case 'strings.legacy.msg_comment': return '评论';
			case 'strings.legacy.msg_added_voice_attachment': return '已添加录音附件';
			case 'strings.legacy.msg_customize_sidebar': return '自定义侧边栏';
			case 'strings.legacy.msg_coffee_add_drumstick': return '☕ 这就是我要的咖啡/加个鸡腿';
			case 'strings.legacy.msg_pin': return '置顶';
			case 'strings.legacy.msg_enter_password_continue': return '请输入密码以继续';
			case 'strings.legacy.msg_remove_local_library': return '移除本地库？';
			case 'strings.legacy.msg_comment_2': return '新评论';
			case 'strings.legacy.msg_sync_all': return '全部同步';
			case 'strings.legacy.msg_backup_schedule': return '备份频率';
			case 'strings.legacy.msg_server_error': return '服务器内部错误';
			case 'strings.legacy.msg_analyzing_memos': return '正在深度分析您的笔记...';
			case 'strings.legacy.msg_notification': return '通知';
			case 'strings.legacy.msg_policy': return '策略设置';
			case 'strings.legacy.msg_failed_load': return ({required Object error}) => '加载失败: ${error}';
			case 'strings.legacy.msg_default_visibility': return '默认可见性';
			case 'strings.legacy.msg_filter': return '筛选';
			case 'strings.legacy.msg_imported_memos': return '导入笔记';
			case 'strings.legacy.msg_token_created': return 'Token 已创建';
			case 'strings.legacy.msg_server_response_timeout_try': return '服务器响应超时，请稍后重试';
			case 'strings.legacy.msg_expiring': return '即将过期';
			case 'strings.legacy.msg_delete_task': return '删除任务';
			case 'strings.legacy.msg_body_must_json': return 'Body 必须是 JSON';
			case 'strings.legacy.msg_enable': return '去开启';
			case 'strings.legacy.msg_referenced': return '被引用';
			case 'strings.legacy.msg_replace_image': return '确认替换？';
			case 'strings.legacy.msg_debug_logs': return '调试记录';
			case 'strings.legacy.msg_active_tasks': return '正在进行的任务';
			case 'strings.legacy.msg_attachments': return '附件';
			case 'strings.legacy.msg_range': return '时间范围';
			case 'strings.legacy.msg_no_backups_found': return '暂无备份记录';
			case 'strings.legacy.msg_create_memo': return '创建笔记';
			case 'strings.legacy.msg_street': return '街道';
			case 'strings.legacy.msg_display_name': return '显示名称';
			case 'strings.legacy.msg_full_text_search': return '全文搜索';
			case 'strings.legacy.msg_create_edit_delete_actions_offline_stored': return '离线创建/编辑/删除会先保存在本地并加入待同步队列，联网后按顺序发送。为避免误操作，未提交的编辑可保留为草稿。';
			case 'strings.legacy.msg_sign_2': return '退出登录';
			case 'strings.legacy.msg_end_time': return '结束时间';
			case 'strings.legacy.msg_sync_recent_content': return '同步最近内容';
			case 'strings.legacy.msg_resetting_local_data': return '正在重置本地数据...';
			case 'strings.legacy.msg_incorrect_password': return '密码错误';
			case 'strings.legacy.msg_content_cannot_empty': return '内容不能为空';
			case 'strings.legacy.msg_preparing': return '准备中';
			case 'strings.legacy.msg_ai_summary_failed': return ({required Object formatSummaryError_e}) => 'AI 总结失败：${formatSummaryError_e}';
			case 'strings.legacy.msg_manage': return '管理';
			case 'strings.legacy.msg_keep_data_consistent_across_devices': return '保持设备间数据一致。';
			case 'strings.legacy.msg_playback_failed': return ({required Object e}) => '播放失败: ${e}';
			case 'strings.legacy.msg_path_copied': return '路径已复制';
			case 'strings.legacy.msg_auth_settings': return '认证设置';
			case 'strings.legacy.msg_randomly_draw_memo_cards': return '随机抽取你的卡片笔记';
			case 'strings.legacy.msg_copy_log_text': return '复制日志文本';
			case 'strings.legacy.msg_yes': return '是';
			case 'strings.legacy.msg_save_open_alipay_scan': return '长按保存后打开支付宝扫一扫';
			case 'strings.legacy.msg_signed_but_no_token_returned': return '登录成功，但未返回 Token';
			case 'strings.legacy.msg_create_failed': return ({required Object formatError_e_context}) => '创建失败：${formatError_e_context}';
			case 'strings.legacy.msg_expand': return '展开';
			case 'strings.legacy.msg_local_library_only': return '仅本地库可用';
			case 'strings.legacy.msg_reminder_channel': return '提醒通知渠道';
			case 'strings.legacy.msg_grant': return '去授权';
			case 'strings.legacy.msg_import_canceled': return '已取消导入';
			case 'strings.legacy.msg_never': return '永不过期';
			case 'strings.legacy.msg_release_notes': return '版本公告';
			case 'strings.legacy.msg_failed_load_references': return '加载引用失败';
			case 'strings.legacy.msg_select_tags': return '选择标签';
			case 'strings.legacy.msg_failed_load_try': return '加载失败，请稍后重试';
			case 'strings.legacy.msg_logs_copied': return '记录已复制';
			case 'strings.legacy.msg_shortcuts_not_supported_server': return '当前服务器不支持快捷筛选';
			case 'strings.legacy.msg_reply_2': return ({required Object name}) => '回复 ${name}...';
			case 'strings.legacy.msg_anonymous': return '匿名';
			case 'strings.legacy.msg_username': return '用户名';
			case 'strings.legacy.msg_update_memo': return '更新笔记';
			case 'strings.legacy.msg_saved': return ({required Object targetPath}) => '已保存到: ${targetPath}';
			case 'strings.legacy.msg_chinese_simplified': return '简体中文';
			case 'strings.legacy.msg_memo_copied': return '已复制笔记内容';
			case 'strings.legacy.msg_collapse': return '收起';
			case 'strings.legacy.msg_retry_count_controls_how_many_extra': return '重试次数决定了上传失败后的最大尝试频率。设置较高的次数可以提高成功率，但可能增加等待时间。';
			case 'strings.legacy.msg_recording_info_missing': return '录音信息缺失';
			case 'strings.legacy.msg_sync_task': return '同步任务';
			case 'strings.legacy.msg_clear_all_debug_logs': return '确认清空调试记录？';
			case 'strings.legacy.msg_export_finished': return '导出完成';
			case 'strings.legacy.msg_failed_stop_recording': return ({required Object e}) => '停止录音失败：${e}';
			case 'strings.legacy.msg_my_profile': return '我的资料';
			case 'strings.legacy.msg_image_bed': return '兰空图床';
			case 'strings.legacy.msg_failed_open_notification': return ({required Object e}) => '打开通知失败：${e}';
			case 'strings.legacy.msg_manual': return '手动';
			case 'strings.legacy.msg_no_html_file_found_zip': return '压缩包内未找到 HTML 文件';
			case 'strings.legacy.msg_also_clear_local_cache_account_offline': return '这会同时清除该账号的本地缓存（离线数据/草稿/待同步队列）。此操作无法撤销。';
			case 'strings.legacy.msg_restore': return '恢复';
			case 'strings.legacy.msg_auto_backup': return '自动备份';
			case 'strings.legacy.msg_generate_summary': return '开始生成总结';
			case 'strings.legacy.msg_days': return ({required Object stats_activeDays}) => '${stats_activeDays} 天';
			case 'strings.legacy.msg_count': return '- 数量';
			case 'strings.legacy.msg_weekly': return '每周';
			case 'strings.legacy.msg_notifications': return '通知';
			case 'strings.legacy.msg_backup_failed': return '备份失败';
			case 'strings.legacy.msg_private': return '仅私密';
			case 'strings.legacy.msg_filter_tags': return '标签筛选';
			case 'strings.legacy.msg_clear_logs': return '清空记录';
			case 'strings.legacy.msg_unable_open_browser': return '无法打开浏览器';
			case 'strings.legacy.msg_attachment_too_large': return '附件过大，超过服务器限制';
			case 'strings.legacy.msg_query': return 'Query';
			case 'strings.legacy.msg_match_all': return '满足所有条件';
			case 'strings.legacy.msg_record_request_response_logs': return '记录请求/响应日志';
			case 'strings.legacy.msg_import_file': return '导入文件';
			case 'strings.legacy.msg_content_tags': return '内容 + 标签';
			case 'strings.legacy.msg_feature_not_available_local_library_mode': return '本地库模式暂不支持该功能';
			case 'strings.legacy.msg_import_failed': return ({required Object e}) => '导入失败: ${e}';
			case 'strings.legacy.msg_save_memo': return '保存为笔记';
			case 'strings.legacy.msg_scan_disk_directory_merge_local_database': return '扫描磁盘目录并合并到本地数据库？缺失文件将视为删除。';
			case 'strings.legacy.msg_passwords_not_match': return '两次密码不一致';
			case 'strings.legacy.msg_signed_2': return ({required Object lastLoginUser}) => '当前登录用户: ${lastLoginUser}';
			case 'strings.legacy.msg_made_love_note_taking': return '为记录而生';
			case 'strings.legacy.msg_password_updated_local': return '密码已更新（仅本地）';
			case 'strings.legacy.msg_retry': return '重试';
			case 'strings.legacy.msg_memo_stats': return '记录统计';
			case 'strings.legacy.msg_shown_only_once_copy_keep_safe': return '仅显示一次，请复制并妥善保存。';
			case 'strings.legacy.msg_describe_issue_time_repro_steps_etc': return '描述问题、时间、复现步骤等';
			case 'strings.legacy.msg_how_many_days_back': return '过去多少天';
			case 'strings.legacy.msg_local_cache_cleared': return '本地缓存已清除';
			case 'strings.legacy.msg_none': return '无';
			case 'strings.legacy.msg_body_json': return 'Body (JSON)';
			case 'strings.legacy.msg_download_failed': return ({required Object e}) => '下载失败: ${e}';
			case 'strings.legacy.msg_recycle_bin': return '回收站';
			case 'strings.legacy.msg_unpin': return '取消置顶';
			case 'strings.legacy.msg_advanced_security': return '高级与安全';
			case 'strings.legacy.msg_run_issues_memoflow_e_g_sync': return '如果您在使用 MemoFlow 时遇到问题（如同步失败、崩溃等），请按照以下步骤向我们反馈，这将帮助开发者快速定位并修复问题。\\n\\n';
			case 'strings.legacy.msg_remove_all_reminder_times_memo': return '将移除该笔记的全部提醒时间。';
			case 'strings.legacy.msg_no_summary_save': return '暂无可保存的总结';
			case 'strings.legacy.msg_reset_language_selection': return '重置语言选择状态';
			case 'strings.legacy.msg_v_30_days': return '30 天';
			case 'strings.legacy.msg_e_g_mood_check': return '如：情绪分析';
			case 'strings.legacy.msg_note_some_tokens_returned_only_once': return '提示：Token 可能只返回一次，之后无法再次获取，请妥善保存。';
			case 'strings.legacy.msg_syncing': return '同步中...';
			case 'strings.legacy.msg_retention': return '版本保留数量';
			case 'strings.legacy.msg_open_login_screen': return '打开登录页面';
			case 'strings.legacy.msg_apply_all': return '应用到全部';
			case 'strings.legacy.msg_write_something_supports_tag_tasks_x': return '写点什么... 支持 #tag 和任务 [ ] / [x]';
			case 'strings.legacy.msg_http': return ({required Object base, required Object status, required Object msg}) => '${base}（HTTP ${status}）：${msg}';
			case 'strings.legacy.msg_single': return '单次';
			case 'strings.legacy.msg_delete_memo': return '删除 Memo？';
			case 'strings.legacy.msg_ai_provider': return 'AI 提供方';
			case 'strings.legacy.msg_release_notes_v': return ({required Object version}) => '版本公告 v${version}';
			case 'strings.legacy.msg_info_only_used_background_ai_summaries': return '这些信息仅用于 AI 总结/报告的背景，不会同步到后端。';
			case 'strings.legacy.msg_not_disturb': return '免打扰模式';
			case 'strings.legacy.msg_local_library_import_failed': return ({required Object e}) => '本地库导入失败: ${e}';
			case 'strings.legacy.msg_key_insights': return '核心洞察';
			case 'strings.legacy.msg_additional_notes_optional': return '补充说明（可选）';
			case 'strings.legacy.msg_server_response_error': return '服务响应异常';
			case 'strings.legacy.msg_sort': return '排序';
			case 'strings.legacy.msg_api_call': return 'API 调用';
			case 'strings.legacy.msg_webhooks': return 'Webhooks';
			case 'strings.legacy.msg_local_library': return '本地库';
			case 'strings.legacy.msg_log_copied': return '日志已复制';
			case 'strings.legacy.msg_last_success': return '最近成功';
			case 'strings.legacy.msg_restore_cloud': return '从云端恢复';
			case 'strings.legacy.msg_search_public_memos': return '搜索公开内容';
			case 'strings.legacy.msg_cancel': return '取消生成';
			case 'strings.legacy.msg_processing': return ({required Object processed, required Object total}) => '正在处理 ${processed} / ${total}';
			case 'strings.legacy.msg_failed_items': return '失败条数';
			case 'strings.legacy.msg_recording_file_not_found': return '录音文件不存在';
			case 'strings.legacy.msg_local_db_outbox_queue': return '本地数据库 + 待同步队列';
			case 'strings.legacy.msg_remove': return '移除';
			case 'strings.legacy.msg_export_format': return '导出格式';
			case 'strings.legacy.msg_idle': return '空闲';
			case 'strings.legacy.msg_ago': return ({required Object months}) => '${months}个月前';
			case 'strings.legacy.msg_no_tags_yet': return '暂无标签';
			case 'strings.legacy.msg_version_v': return ({required Object version}) => '版本 v${version}';
			case 'strings.legacy.msg_sync': return '同步';
			case 'strings.legacy.msg_done': return '完成';
			case 'strings.legacy.msg_gallery_permission_required_2': return '需要相册权限以保存图片';
			case 'strings.legacy.msg_insufficient_permissions': return '权限不足';
			case 'strings.legacy.msg_no_download_url_available': return '无法获取下载链接';
			case 'strings.legacy.msg_record_create_memos': return '录音生成 memo';
			case 'strings.legacy.msg_signing': return '登录中…';
			case 'strings.legacy.msg_memoflow_uses_system_location_permission_get': return '定位将使用系统权限获取经纬度，并通过高德 Web API 反向地理解析地址，可在上方选择显示精度。';
			case 'strings.legacy.msg_continue': return '继续';
			case 'strings.legacy.msg_notification_content_unavailable': return '通知缺少内容';
			case 'strings.legacy.msg_unable_read_file_path': return '无法获取文件路径';
			case 'strings.legacy.msg_all_memos': return '全部笔记';
			case 'strings.legacy.msg_keywords': return '关键词';
			case 'strings.legacy.msg_import_result': return '导入结果';
			case 'strings.legacy.msg_offline_sync': return '离线同步';
			case 'strings.legacy.msg_imported_memos_local_library': return '已从本地库导入笔记';
			case 'strings.legacy.msg_request_failed': return '请求失败';
			case 'strings.legacy.msg_log_file': return '日志文件';
			case 'strings.legacy.msg_after_confirming_support_unlock_limited_gold': return '点击确认赞赏后，将解锁限定版金色标识 or 永久去广告承诺（虽然本来就没广告）';
			case 'strings.legacy.msg_failed_open_system_settings': return '无法打开系统设置';
			case 'strings.legacy.msg_no_mood_trend': return '暂无情绪趋势';
			case 'strings.legacy.msg_memoflow_export': return '# MemoFlow 导出';
			case 'strings.legacy.msg_sync_queue': return '同步队列';
			case 'strings.legacy.msg_only_delete_sync_task_memo_kept': return '仅删除同步任务，笔记会保留。';
			case 'strings.legacy.msg_add_home_screen': return '添加到桌面';
			case 'strings.legacy.msg_past_days': return '过去天数';
			case 'strings.legacy.msg_poster_generation_failed': return '海报生成失败';
			case 'strings.legacy.msg_failed_load_stats': return ({required Object e}) => '加载统计失败：${e}';
			case 'strings.legacy.msg_customize_notification': return '自定义通知';
			case 'strings.legacy.msg_updated_time': return '修改时间 ↓';
			case 'strings.legacy.msg_network_connection_failed_check_network': return '网络连接失败，请检查网络';
			case 'strings.legacy.msg_special_thanks': return '本次更新特别鸣谢：';
			case 'strings.legacy.msg_failed_comment': return ({required Object e}) => '评论失败：${e}';
			case 'strings.legacy.msg_security_key_sig': return '安全密钥（sig）';
			case 'strings.legacy.msg_save_gallery': return '保存到相册';
			case 'strings.legacy.msg_request_sent_confirm_system_prompt': return '已发送请求，请在系统提示中确认';
			case 'strings.legacy.msg_server_url': return '服务器地址';
			case 'strings.legacy.msg_period_review': return '阶段回顾';
			case 'strings.legacy.msg_settings_updated': return '已更新设置';
			case 'strings.legacy.msg_backend_0_21_not_supported_import': return '检测到 0.21 版本，暂不支持导入，请升级后端后再试';
			case 'strings.legacy.msg_failed_load_tags': return ({required Object e}) => '加载标签失败：${e}';
			case 'strings.legacy.msg_enter_email': return '请输入邮箱';
			case 'strings.legacy.msg_add_webhook': return '新增 Webhook';
			case 'strings.legacy.msg_read': return '已读';
			case 'strings.legacy.msg_widgets': return '小组件';
			case 'strings.legacy.msg_default': return '默认';
			case 'strings.legacy.msg_memo_reminders': return '笔记提醒';
			case 'strings.legacy.msg_import_flomo': return '从 Flomo 导入';
			case 'strings.legacy.msg_format_fixed_markdown_zip': return '格式固定为 Markdown + ZIP';
			case 'strings.legacy.msg_enter_username_password': return '请输入账号和密码';
			case 'strings.legacy.msg_loading': return '加载中...';
			case 'strings.legacy.msg_test_scheduled': return ({required Object timeLabel, required Object suffix, required Object pendingLabel}) => '已安排测试提醒：${timeLabel}${suffix}${pendingLabel}';
			case 'strings.legacy.msg_edit_memo': return '编辑 Memo';
			case 'strings.legacy.msg_save': return '保存';
			case 'strings.legacy.msg_laboratory': return '实验室';
			case 'strings.legacy.msg_use_local': return '使用本地';
			case 'strings.legacy.msg_retry_sync': return '重试同步';
			case 'strings.legacy.msg_e_g_my_role_topics_interest': return '例如：我的角色 / 兴趣主题 / 写作风格偏好';
			case 'strings.legacy.msg_confirm_password': return '确认密码';
			case 'strings.legacy.msg_not_set': return '未设置';
			case 'strings.legacy.msg_no_memos_day': return '当天无记录';
			case 'strings.legacy.msg_shortcut_name': return '输入名称';
			case 'strings.legacy.msg_edit_shortcut': return '编辑快捷筛选';
			case 'strings.legacy.msg_days_memos': return '坚持记录天数';
			case 'strings.legacy.msg_delete': return '删除';
			case 'strings.legacy.msg_test_reminder': return '测试提醒';
			case 'strings.legacy.msg_enable_reminders': return '开启提醒';
			case 'strings.legacy.msg_links': return '双链';
			case 'strings.legacy.msg_location': return '定位设置';
			case 'strings.legacy.msg_import_file_2': return '从文件导入';
			case 'strings.legacy.msg_reply_3': return ({required Object creatorDisplayName_commentCreator_commentMemo_creator}) => '回复 ${creatorDisplayName_commentCreator_commentMemo_creator}...';
			case 'strings.legacy.msg_created': return ({required Object widget_createdAtLabel}) => '创建于 ${widget_createdAtLabel}';
			case 'strings.legacy.msg_notifications_coming_soon': return '通知功能即将上线';
			case 'strings.legacy.msg_view_full_contributors': return '查看完整致谢名单';
			case 'strings.legacy.msg_no_times_set': return '尚未设置提醒时间';
			case 'strings.legacy.msg_ignore_tls_errors': return '忽略证书校验';
			case 'strings.legacy.msg_no_content': return '无内容';
			case 'strings.legacy.msg_about_15_seconds_left': return '预计还需 15 秒';
			case 'strings.legacy.msg_view_imported_memos': return '查看导入笔记';
			case 'strings.legacy.msg_load_failed': return '加载失败';
			case 'strings.legacy.msg_disk_content_conflicts_local_pending_changes': return '磁盘与本地未同步内容冲突。选择“以磁盘为准”将覆盖本地内容。';
			case 'strings.legacy.msg_all_history_so_far_memoflow_since': return '以上是全部历史内容\\nMEMOFLOW SINCE 2023';
			case 'strings.legacy.msg_cancelling': return '取消中';
			case 'strings.legacy.msg_reading_file': return '正在读取文件...';
			case 'strings.legacy.msg_switch_workspace': return '切换工作区';
			case 'strings.legacy.msg_optional_leave_empty_default': return '选填，使用默认存储策略时请留空';
			case 'strings.legacy.msg_memo_reminders_2': return '笔记提醒';
			case 'strings.legacy.msg_save_failed_2': return ({required Object e}) => '保存失败: ${e}';
			case 'strings.legacy.msg_record_create_memos_sync_later': return '录音生成 memo（可稍后同步）';
			case 'strings.legacy.msg_use_https_avoid_ignoring_tls_errors': return '为了安全，建议使用 HTTPS，且避免忽略证书校验。';
			case 'strings.legacy.msg_failed_load_announcement_config': return '未获取到公告配置';
			case 'strings.legacy.msg_shortcuts': return '快捷筛选';
			case 'strings.legacy.msg_memo': return '笔记';
			case 'strings.legacy.msg_maybe_later': return '稍后再说';
			case 'strings.legacy.msg_server_connection': return '服务器连接';
			case 'strings.legacy.msg_days_2': return '天';
			case 'strings.legacy.msg_include_archived': return '包含归档';
			case 'strings.legacy.msg_during_quiet_hours_reminders_silenced': return '在免打扰期间，应用将保持静默，不会弹出任何提醒。';
			case 'strings.legacy.msg_preview_not_supported_type': return '暂不支持该类型预览';
			case 'strings.legacy.msg_failed_load_2': return '加载失败';
			case 'strings.legacy.msg_create_token': return '创建新 Token';
			case 'strings.legacy.msg_enter_name': return '请输入筛选名称';
			case 'strings.legacy.msg_api_url_incorrect': return 'API URL 不正确';
			case 'strings.legacy.msg_user_general_settings': return '用户通用设置';
			case 'strings.legacy.msg_saved_memo': return '已保存为笔记';
			case 'strings.legacy.msg_restore_failed': return ({required Object e}) => '恢复失败：${e}';
			case 'strings.legacy.msg_token_tail': return ({required Object tail}) => 'Token 尾号 ${tail}';
			case 'strings.legacy.msg_manual_token': return '手动 Token';
			case 'strings.legacy.msg_ago_2': return ({required Object years}) => '${years}年前';
			case 'strings.legacy.msg_recent_searches': return '最近搜索';
			case 'strings.legacy.msg_restored': return '已恢复';
			case 'strings.legacy.msg_no_contributors_yet': return '暂无致谢名单';
			case 'strings.legacy.msg_no_record_yet': return '暂无记录';
			case 'strings.legacy.msg_reminder': return '提醒';
			case 'strings.legacy.msg_enter_api_key_ai_settings': return '请先在 AI 设置中填写 API Key';
			case 'strings.legacy.msg_reminder_settings': return '提醒设置';
			case 'strings.legacy.msg_http_2': return ({required Object base, required Object status}) => '${base}（HTTP ${status}）';
			case 'strings.legacy.msg_edit_webhook': return '编辑 Webhook';
			case 'strings.legacy.msg_generate_share_poster': return '生成分享海报';
			case 'strings.legacy.msg_archive_failed': return ({required Object e}) => '归档失败：${e}';
			case 'strings.legacy.msg_comments': return ({required Object widget_commentCount}) => '${widget_commentCount} æ¡è¯è®º';
			case 'strings.legacy.msg_remove_account': return '移除账号？';
			case 'strings.legacy.msg_chinese_traditional': return '繁體中文';
			case 'strings.legacy.msg_private_2': return '私密';
			case 'strings.legacy.msg_current_streak': return '当前连击';
			case 'strings.legacy.msg_generated_ai_memoflow': return '由 AI 生成 · MemoFlow';
			case 'strings.legacy.msg_edit_completed': return '编辑完成';
			case 'strings.legacy.msg_local': return '本地调试';
			case 'strings.legacy.msg_edit': return '编辑';
			case 'strings.legacy.msg_text': return ({required Object shortUserName_item_sender}) => '来自 ${shortUserName_item_sender}';
			case 'strings.legacy.msg_got': return '知道了';
			case 'strings.legacy.msg_web_api_key': return 'Web API Key';
			case 'strings.legacy.msg_preview': return '预览';
			case 'strings.legacy.msg_enter_password': return '请输入密码';
			case 'strings.legacy.msg_api': return '接口';
			case 'strings.legacy.msg_ok': return '确定';
			case 'strings.legacy.msg_failed_load_shortcuts': return '快捷筛选加载失败';
			case 'strings.legacy.msg_after_recording_audio_added_current_draft': return '录音完成后会将音频作为附件加入当前草稿，便于继续编辑后再发送。最长 60 分钟；可后续通过第三方服务转写。';
			case 'strings.legacy.msg_pull_refresh': return '下拉刷新';
			case 'strings.legacy.msg_unable_open_photo': return '无法打开照片';
			case 'strings.legacy.msg_existing_tokens': return '已有 Token';
			case 'strings.legacy.msg_ai_settings': return 'AI 设置';
			case 'strings.legacy.msg_app_lock': return '应用锁';
			case 'strings.legacy.msg_total_notes': return '总记录';
			case 'strings.legacy.msg_stats_loading': return '统计数据加载中...';
			case 'strings.legacy.msg_enter_token_description': return '请输入 Token 描述';
			case 'strings.legacy.msg_enter_token': return '请输入 Token';
			case 'strings.legacy.msg_api_plugins': return 'API 与插件';
			case 'strings.legacy.msg_parsing_file': return '正在解析文件...';
			case 'strings.legacy.msg_english': return '英语';
			case 'strings.legacy.msg_activity_heatmap': return '记录热力图';
			case 'strings.legacy.msg_mark_read': return '标记已读';
			case 'strings.legacy.msg_request': return '申请';
			case 'strings.legacy.msg_sync_failed': return ({required Object type, required Object memoError}) => '同步失败（${type}）：${memoError}';
			case 'strings.legacy.msg_error_copied': return '已复制错误信息';
			case 'strings.legacy.msg_only_local_index_removed_disk_files': return '仅移除本地索引，磁盘文件保留。此操作无法撤销。';
			case 'strings.legacy.msg_switch_account': return '切换账号';
			case 'strings.legacy.msg_invalid_download_link': return '无效的更新链接';
			case 'strings.legacy.msg_about': return '关于';
			case 'strings.legacy.msg_icon': return '图标选择';
			case 'strings.legacy.msg_reset_done_syncing': return '已重置，开始重新同步';
			case 'strings.legacy.msg_enter_amap_web_api_key': return '请输入高德 Web API Key';
			case 'strings.legacy.msg_recycle_bin_coming_soon': return '回收站功能暂未开放';
			case 'strings.legacy.msg_empty_content': return '（空内容）';
			case 'strings.legacy.msg_note_most_features_offline_stats_ai': return '提示：大部分功能（离线/统计/AI 总结/导出）无需后端改动，但 Token 只返回一次，请妥善保存。';
			case 'strings.legacy.msg_fixed': return '修复：';
			case 'strings.legacy.msg_allow_sharing_links_images_other_apps': return '允许从其他应用分享链接或图片到 MemoFlow。';
			case 'strings.legacy.msg_invalid_request_parameters': return '请求参数错误';
			case 'strings.legacy.msg_enter_api_url': return '请输入 API URL';
			case 'strings.legacy.msg_pending': return ({required Object result_pendingCount}) => '（待发送 ${result_pendingCount}）';
			case 'strings.legacy.msg_days_3': return ({required Object currentStreak}) => '${currentStreak} 天';
			case 'strings.legacy.msg_poster_not_ready_yet': return '暂时无法生成海报';
			case 'strings.legacy.msg_generated_memoflow': return '由 MemoFlow 生成';
			case 'strings.legacy.msg_enter_name_2': return '请输入名称';
			case 'strings.legacy.msg_version': return '版本';
			case 'strings.legacy.msg_memo_missing_disk_but_has_local': return '磁盘缺失该笔记，但本地还有未同步改动。选择“以磁盘为准”将删除本地记录。';
			case 'strings.legacy.msg_legacy_api_compatibility': return '旧版 API 兼容';
			case 'strings.legacy.msg_sync_parameters': return '同步参数';
			case 'strings.legacy.msg_quick_prompts': return '快速提示词';
			case 'strings.legacy.msg_share_failed': return ({required Object e}) => '分享失败：${e}';
			case 'strings.legacy.msg_no_memos_summarize_range': return '该时间范围内没有可总结的笔记';
			case 'strings.legacy.msg_characters': return '字数';
			case 'strings.legacy.msg_capture_every_moment_record': return '记录每一个瞬间';
			case 'strings.legacy.msg_vibration': return '震动';
			case 'strings.legacy.msg_days_4': return '天';
			case 'strings.legacy.msg_prompt_title': return '提示词标题';
			case 'strings.legacy.msg_show_all': return '展开';
			case 'strings.legacy.msg_no_memos_available': return '暂无可关联的笔记';
			case 'strings.legacy.msg_comment_unavailable': return '评论内容不可用';
			case 'strings.legacy.msg_refresh': return '刷新';
			case 'strings.legacy.msg_syncing_2': return '同步中';
			case 'strings.legacy.msg_body': return '通知正文';
			case 'strings.legacy.msg_clear_2': return '清除';
			case 'strings.legacy.msg_third_party_share': return '第三方分享';
			case 'strings.legacy.msg_charging_station': return '充电站';
			case 'strings.legacy.msg_attachments_2': return '附件资源';
			case 'strings.legacy.msg_when_enabled_must_verify_each_app': return '开启后每次进入应用需要验证。自动锁定时间决定应用进入后台后多久需要再次验证。';
			case 'strings.legacy.msg_add_prompt': return '添加提示词';
			case 'strings.legacy.msg_include': return '包含';
			case 'strings.legacy.msg_created_time_2': return '创建时间 ↓';
			case 'strings.legacy.msg_choose_data_source_start_importing_memos': return '选择一个数据来源开始导入您的笔记';
			case 'strings.legacy.msg_describe_how_want_summary': return '请分析我本周笔记中体现的情绪波动曲线…';
			case 'strings.legacy.msg_keep_token_safe_not_share_api': return '请妥善保存 Token，不要泄露。\\nAPI 访问频率限制为每分钟 60 次。';
			case 'strings.legacy.msg_open_2': return '去开启';
			case 'strings.legacy.msg_e_g_claude_3_5_sonnet': return '例如 claude-3-5-sonnet-20241022';
			case 'strings.legacy.msg_failed_request_whitelist': return '无法申请电池白名单';
			case 'strings.legacy.msg_notification_deleted': return '通知已删除';
			case 'strings.legacy.msg_accounts': return '账号';
			case 'strings.legacy.msg_add_local_library': return '添加本地库';
			case 'strings.legacy.msg_sign_first': return '请先登录';
			case 'strings.legacy.msg_failed_parse_query': return 'Query 解析失败';
			case 'strings.legacy.msg_note_logs_sanitized_automatically_sensitive_data': return '提示：日志已自动去除敏感信息，如仍包含敏感数据，请提交前自行处理。';
			case 'strings.legacy.msg_add': return '新增';
			case 'strings.legacy.msg_failed_load_3': return ({required Object memosError}) => '加载失败：${memosError}';
			case 'strings.legacy.msg_max_chars_day': return '单日最多字数';
			case 'strings.legacy.msg_choose_what_edited_image': return '请选择要执行的操作';
			case 'strings.legacy.msg_select': return '请选择';
			case 'strings.legacy.msg_unnamed_token': return '(未命名 Token)';
			case 'strings.legacy.msg_name': return '筛选名称';
			case 'strings.legacy.msg_sure_want_delete_webhook': return '确定要删除该 Webhook 吗？';
			case 'strings.legacy.msg_back': return '返回';
			case 'strings.legacy.msg_no': return '否';
			case 'strings.legacy.msg_untitled': return '未命名';
			case 'strings.legacy.msg_open_language_onboarding': return '打开语言首次设置';
			case 'strings.legacy.msg_voice_memos': return '语音备忘';
			case 'strings.legacy.msg_unable_open_browser_try': return '无法打开浏览器，请稍后重试';
			case 'strings.legacy.msg_date_range': return '时间范围';
			case 'strings.legacy.msg_not_authenticated': return '未登录';
			case 'strings.legacy.msg_back_2': return 'Back';
			case 'strings.legacy.msg_local_library_removed': return '本地库已移除';
			case 'strings.legacy.msg_exact_alarm_permission_required': return '需要闹钟与提醒权限';
			case 'strings.legacy.msg_visibility': return '可见性';
			case 'strings.legacy.msg_failed_start_recording': return ({required Object e}) => '启动录音失败：${e}';
			case 'strings.legacy.msg_mood_trend': return '情绪趋势';
			case 'strings.legacy.msg_local_library_name': return '本地库名称';
			case 'strings.legacy.msg_no_tokens_yet': return '暂无 Token';
			case 'strings.legacy.msg_loading_2': return '加载中…';
			case 'strings.legacy.msg_location_permission_denied_permanently': return '定位权限被永久拒绝';
			case 'strings.legacy.msg_download': return '下载';
			case 'strings.legacy.msg_export_time': return '- 导出时间';
			case 'strings.legacy.msg_enter_password_2': return '请输入密码';
			case 'strings.legacy.msg_no_image_available': return '没有可显示的图片';
			case 'strings.legacy.msg_daily': return '每天';
			case 'strings.legacy.msg_no_likes_yet': return '暂无点赞';
			case 'strings.legacy.msg_basics': return '基础配置';
			case 'strings.legacy.msg_shortcut': return '新建快捷筛选';
			case 'strings.legacy.msg_debug_tools': return '调试工具';
			case 'strings.legacy.msg_save_settings': return '保存设置';
			case 'strings.legacy.msg_date_range_2': return '日期范围';
			case 'strings.legacy.msg_feedback': return '反馈';
			case 'strings.legacy.msg_image_bed_2': return '图床';
			case 'strings.legacy.msg_restoring': return '恢复中…';
			case 'strings.legacy.msg_export': return '导出';
			case 'strings.legacy.msg_enter_token_name': return '请输入 Token 名称';
			case 'strings.legacy.msg_start_time': return '开始时间';
			case 'strings.legacy.msg_preparing_file_structure': return '正在准备文件结构';
			case 'strings.legacy.msg_sign_3': return '登录';
			case 'strings.legacy.msg_scan_local_library': return '扫描本地库';
			case 'strings.legacy.msg_lsky_pro': return '兰空图床 (Lsky Pro)';
			case 'strings.legacy.msg_exact_alarm_permission_off_reminders_may': return '未开启闹钟与提醒权限，定时提醒可能无法触发。是否前往开启？';
			case 'strings.legacy.msg_last_30_days': return '最近一月';
			case 'strings.legacy.msg_match': return '匹配方式';
			case 'strings.legacy.msg_auth_mode': return '认证方式';
			case 'strings.legacy.msg_unsupported_file_type': return '不支持的文件格式';
			case 'strings.legacy.msg_only_delete_sync_task': return '仅删除同步任务。';
			case 'strings.legacy.msg_change_password': return '修改密码';
			case 'strings.legacy.msg_saved_2': return '已保存';
			case 'strings.legacy.msg_import_export': return '导入 / 导出';
			case 'strings.legacy.msg_created_2': return '创建时间';
			case 'strings.legacy.msg_ai_summary': return 'AI 总结';
			case 'strings.legacy.msg_progress': return '完成进度';
			case 'strings.legacy.msg_replace_memo_image': return '替换笔记图片';
			case 'strings.legacy.msg_app_settings': return '应用设置';
			case 'strings.legacy.msg_copy_path': return '复制路径';
			case 'strings.legacy.msg_components': return '功能组件';
			case 'strings.legacy.msg_no_shortcuts': return '暂无快捷筛选';
			case 'strings.legacy.msg_location_timed_try': return '定位超时，请重试';
			case 'strings.legacy.msg_attach_location_info_memos_show_subtle': return '为笔记记录定位信息，并展示简洁地名。';
			case 'strings.legacy.msg_send_failed': return ({required Object e}) => '发送失败：${e}';
			case 'strings.legacy.msg_repeat': return '重复';
			case 'strings.legacy.msg_not_signed': return '未登录';
			case 'strings.legacy.msg_no_webhooks_configured': return '暂无 Webhooks';
			case 'strings.legacy.msg_apply_token': return '应用 Token';
			case 'strings.legacy.msg_enable_reminder_permissions_2': return '开启提醒权限';
			case 'strings.legacy.msg_enter_backup_password': return '请输入备份密码';
			case 'strings.legacy.msg_start_backup': return '开始备份';
			case 'strings.legacy.msg_last_sync': return '上次同步';
			case 'strings.legacy.msg_note_export_includes_content_already_synced': return '提示：导出包含已同步到本地数据库的内容（含离线数据）。';
			case 'strings.legacy.msg_enter_username': return '请输入用户名';
			case 'strings.legacy.msg_settings_saved': return '设置已保存';
			case 'strings.legacy.msg_no_keywords': return '暂无关键词';
			case 'strings.legacy.msg_these_settings_apply_newly_created_memos': return '此设置将应用于新建的 Memo。';
			case 'strings.legacy.msg_back_home': return '返回主页';
			case 'strings.legacy.msg_quiet_hours': return '休息时间';
			case 'strings.legacy.msg_add_account': return '添加账号';
			case 'strings.legacy.msg_reset_complete': return '已重置';
			case 'strings.legacy.msg_no_shortcuts_configured': return '暂无快捷筛选';
			case 'strings.legacy.msg_password': return '密码';
			case 'strings.legacy.msg_importing': return '导入中';
			case 'strings.legacy.msg_visibility_2': return ({required Object visibilityLabel}) => '可见性：${visibilityLabel}';
			case 'strings.legacy.msg_no_logs_yet': return '暂无记录';
			case 'strings.legacy.msg_v_9_times_allowed': return '最多设置 9 个提醒时间';
			case 'strings.legacy.msg_last_14_days': return '最近 14 天';
			case 'strings.legacy.msg_location_disabled_enable_settings_first': return '定位未启用，请先在设置中开启。';
			case 'strings.legacy.msg_add_2': return '添加';
			case 'strings.legacy.msg_logs': return '日志';
			case 'strings.legacy.msg_references': return '引用了';
			case 'strings.legacy.msg_importing_memos': return '正在导入笔记...';
			case 'strings.legacy.msg_account_security': return '账号与安全';
			case 'strings.legacy.msg_reminder_2': return '提醒设置';
			case 'strings.legacy.msg_enable_scheduled_reminder_notifications': return '开启后将按计划发送笔记提醒通知。';
			case 'strings.legacy.msg_no_links': return '暂无双链';
			case 'strings.legacy.msg_delete_memo_2': return '删除笔记';
			case 'strings.legacy.msg_one_tap_add_not_supported_add': return '不支持一键添加，请从小组件列表添加';
			case 'strings.legacy.msg_password_2': return '新密码';
			case 'strings.legacy.msg_processing_content': return '正在处理内容...';
			case 'strings.legacy.msg_status': return '状态';
			case 'strings.legacy.msg_local_library_added': return '本地库已添加';
			case 'strings.legacy.msg_failed_open_try': return '打开失败，请稍后重试';
			case 'strings.legacy.msg_removed_locally_now_deleted_server_when': return '本地会立即移除，联网后将同步删除服务器内容。';
			case 'strings.legacy.msg_server_url_unavailable': return '未找到服务器地址';
			case 'strings.legacy.msg_no_release_notes_yet': return '暂无更新日志';
			case 'strings.legacy.msg_cancelling_2': return '正在取消...';
			case 'strings.legacy.msg_summaries_selected_range': return '支持按时间范围总结';
			case 'strings.legacy.msg_expand_2': return '展开更多';
			case 'strings.legacy.msg_close': return '关闭';
			case 'strings.legacy.msg_more_comments': return ({required Object remainingComments}) => '还有 ${remainingComments} 条评论';
			case 'strings.legacy.msg_backing': return '备份中…';
			case 'strings.legacy.msg_view_debug_logs': return '查看调试记录';
			case 'strings.legacy.msg_location_permission_denied': return '定位权限被拒绝';
			case 'strings.legacy.msg_self_repair_reset_heatmap': return '自助修复：重置热力图';
			case 'strings.legacy.msg_these_settings_changed_locally_remotely_choose': return '以下设置在本地和远端都有修改，请选择保留哪个版本。';
			case 'strings.legacy.msg_not_authenticated_2': return '未登录账号';
			case 'strings.legacy.msg_action_failed': return ({required Object e}) => '操作失败：${e}';
			case 'strings.legacy.msg_shortcut_2': return '新建快捷筛选';
			case 'strings.legacy.msg_url': return 'URL';
			case 'strings.legacy.msg_no_memos_found_html': return 'HTML 内未找到可导入的内容';
			case 'strings.legacy.msg_enter_what_want_summarize': return '输入你想总结的内容或指令...';
			case 'strings.legacy.msg_unable_load_audio_source': return '无法读取音频资源';
			case 'strings.legacy.msg_strategy_id': return '策略 ID';
			case 'strings.legacy.msg_copy_failed': return ({required Object e}) => '复制失败：${e}';
			case 'strings.legacy.msg_enable_image_bed': return '启用图床';
			case 'strings.legacy.msg_active': return '有效';
			case 'strings.legacy.msg_account': return '账号';
			case 'strings.legacy.msg_invalid_webdav_server_url': return 'WebDAV 服务器地址无效';
			case 'strings.legacy.msg_keep_local': return '以本地为准';
			case 'strings.legacy.msg_within_range': return '在时间范围内';
			case 'strings.legacy.msg_generate_log_file': return '生成日志文件';
			case 'strings.legacy.msg_ai_reports': return 'AI 总结';
			case 'strings.legacy.msg_battery_optimization': return '电池优化';
			case 'strings.legacy.msg_sync_overview': return '同步概览';
			case 'strings.legacy.msg_legacy_servers_not_support_search_filters': return '旧版本服务器不支持搜索过滤，结果可能不完整。';
			case 'strings.legacy.msg_conflicts_detected_run_manual_sync': return '存在冲突，需要手动同步';
			case 'strings.legacy.msg_authentication_failed_check_token': return '认证失败，请检查 Token';
			case 'strings.legacy.msg_date_range_3': return '时间范围';
			case 'strings.legacy.msg_help_ai_understand_better': return '帮助 AI 更了解你';
			case 'strings.legacy.msg_no_search_history': return '暂无搜索记录';
			case 'strings.legacy.msg_enter_api_path': return '请输入接口路径';
			case 'strings.legacy.msg_stats': return '统计';
			case 'strings.legacy.msg_text_2': return '新增：';
			case 'strings.legacy.msg_removing_signing_clear_local_cache_account': return '移除/退出将清除该账号的本地缓存（离线数据/草稿/待同步队列）。';
			case 'strings.legacy.msg_updated_time_2': return '修改时间 ↑';
			case 'strings.legacy.msg_province': return '省';
			case 'strings.legacy.msg_submitting_sync_queue': return '正在提交同步队列';
			case 'strings.legacy.msg_failed': return '失败';
			case 'strings.legacy.msg_set_time': return '设置时间';
			case 'strings.legacy.msg_enable_local_library_backup': return '启用本地库备份';
			case 'strings.legacy.msg_cancel_2': return '取消';
			case 'strings.legacy.msg_week': return '本周回顾';
			case 'strings.legacy.msg_like': return '赞';
			case 'strings.legacy.msg_location_services_disabled': return '定位服务未开启';
			case 'strings.legacy.msg_clears_local_cache_offline_memos_pending': return '这会清空本地缓存（离线笔记/待同步队列）并重新全量同步。未同步内容会丢失，可能需要一些时间。是否继续？';
			case 'strings.legacy.msg_load_more': return '加载更多';
			case 'strings.legacy.msg_pull_memo_list_refresh_sync_sync': return '在笔记列表下拉即可刷新并同步。同步会优先拉取最新内容；建议定期全量同步以保持统计/热力图完整。';
			case 'strings.legacy.msg_server_returned_error': return ({required Object code}) => '服务返回错误（${code}）';
			case 'strings.legacy.msg_sound_feedback': return '声音与反馈';
			case 'strings.legacy.msg_memos_skipped_attachments_skipped': return ({required Object exportedMemoCount, required Object skippedMemoCount, required Object exportedAttachmentCount, required Object skippedAttachmentCount}) => '笔记 ${exportedMemoCount} 条（跳过 ${skippedMemoCount} 条），附件 ${exportedAttachmentCount} 个（跳过 ${skippedAttachmentCount} 个）';
			case 'strings.legacy.msg_import_complete': return '导入完成';
			case 'strings.legacy.msg_text_3': return '新增';
			case 'strings.legacy.msg_max_per_day': return '单日最多条数';
			case 'strings.legacy.msg_permissions_denied': return '权限未授予';
			case 'strings.legacy.msg_memo_2': return '新建 Memo';
			case 'strings.legacy.msg_delete_reminder': return '删除提醒';
			case 'strings.legacy.msg_select_month': return '选择月份';
			case 'strings.legacy.msg_select_backup': return '选择备份';
			case 'strings.legacy.msg_no_keywords_2': return '#暂无关键词';
			case 'strings.legacy.msg_preparing_memo_content': return '正在准备笔记内容';
			case 'strings.legacy.msg_prompt_content': return '具体指令内容';
			case 'strings.legacy.msg_default_prompt_ai_summaries_reports': return '用于 AI 总结/报告的默认提示词';
			case 'strings.legacy.msg_intro': return '引言';
			case 'strings.legacy.msg_monthly_stats': return '每月统计';
			case 'strings.legacy.msg_times_2': return '次';
			case 'strings.legacy.msg_file_has_already_been_imported_skipped': return '该文件已导入过，已跳过';
			case 'strings.legacy.msg_token_tail_unknown': return 'Token 尾号未知';
			case 'strings.legacy.msg_press_back_exit': return '再按一次返回退出';
			case 'strings.legacy.msg_enter_password_3': return '输入密码';
			case 'strings.legacy.msg_sync_conflicts': return '同步冲突';
			case 'strings.legacy.msg_locale': return '语言';
			case 'strings.legacy.msg_any': return '包含任一';
			case 'strings.legacy.msg_provider': return '服务商';
			case 'strings.legacy.msg_preview_2': return '预览效果';
			case 'strings.legacy.msg_automatically_upload_images_append_links_memo': return '开启后自动上传图片并在正文末尾插入链接。';
			case 'strings.legacy.msg_import_file_not_found': return '找不到导入文件';
			case 'strings.legacy.msg_today': return '今天';
			case 'strings.legacy.msg_link_card': return '关联卡片';
			case 'strings.legacy.msg_expiration': return '有效期';
			case 'strings.legacy.msg_summary_prompt_optional': return '总结指令 (可选)';
			case 'strings.legacy.msg_memos': return '笔记';
			case 'strings.legacy.msg_recording_file_not_found_2': return '录音文件不存在';
			case 'strings.legacy.msg_backup_settings': return '备份设置';
			case 'strings.legacy.msg_mode': return '提醒模式';
			case 'strings.legacy.msg_no_markdown_memos_found_zip': return '压缩包内未找到 Markdown 笔记';
			case 'strings.legacy.msg_archived': return '已归档';
			case 'strings.legacy.msg_update_failed': return ({required Object e}) => '更新失败：${e}';
			case 'strings.legacy.msg_enable_app_lock': return '启用应用锁';
			case 'strings.legacy.msg_html_zip': return 'HTML / ZIP';
			case 'strings.legacy.msg_all': return '包含全部';
			case 'strings.legacy.msg_model': return '模型';
			case 'strings.legacy.msg_title': return '通知标题';
			case 'strings.legacy.msg_amap_web_api': return '高德 Web API';
			case 'strings.legacy.msg_saved_gallery': return '已保存到相册';
			case 'strings.legacy.msg_unread': return '未读';
			case 'strings.legacy.msg_exporting': return '正在导出...';
			case 'strings.legacy.msg_network_timeout_try': return '网络超时，请稍后重试';
			case 'strings.legacy.msg_unlock': return '解锁';
			case 'strings.legacy.msg_ago_3': return ({required Object diff_inDays}) => '${diff_inDays}天前';
			case 'strings.legacy.msg_deserve_coffee_i_m_pulling_all': return '为了对得起这杯咖啡，今晚我决定不睡了，写它个一百行代码！';
			case 'strings.legacy.msg_token_name': return 'Token 名称';
			case 'strings.legacy.msg_restore_completed': return '恢复完成';
			case 'strings.legacy.msg_copied_clipboard': return '已复制到剪贴板';
			case 'strings.legacy.msg_failed_2': return ({required Object attempts}) => '失败 ${attempts}次';
			case 'strings.legacy.msg_too_many_requests_try_later': return '请求过于频繁，请稍后重试';
			case 'strings.legacy.msg_more': return '更多';
			case 'strings.legacy.msg_already_whitelisted': return '已在电池白名单';
			case 'strings.legacy.msg_local_library_backup': return '本地库备份';
			case 'strings.legacy.msg_awesome': return '太棒啦！ ❤️';
			case 'strings.legacy.msg_now': return '现在';
			case 'strings.legacy.msg_select_reminder_time': return '请设置提醒时间';
			case 'strings.legacy.msg_protected': return '受保护';
			case 'strings.legacy.msg_failed_load_4': return ({required Object e}) => '加载失败：${e}';
			case 'strings.legacy.msg_operation_failed': return ({required Object e}) => '操作失败：${e}';
			case 'strings.legacy.msg_no_tags': return '暂无标签';
			case 'strings.legacy.msg_server': return '服务器';
			case 'strings.legacy.msg_improved': return '优化';
			case 'strings.legacy.msg_request_2': return '请求';
			case 'strings.legacy.msg_export_failed': return ({required Object e}) => '导出失败：${e}';
			case 'strings.legacy.msg_notification_settings': return '通知设置';
			case 'strings.legacy.msg_related_memo_was_deleted': return '通知对应的内容已被删除';
			case 'strings.legacy.msg_email': return '邮箱';
			case 'strings.legacy.msg_enter_password_4': return '请输入密码';
			case 'strings.legacy.msg_retry_count': return '失败重试次数';
			case 'strings.legacy.msg_import_exported_html_zip_package': return '导入导出的 HTML 或压缩包';
			case 'strings.legacy.msg_archive': return '归档';
			case 'strings.legacy.msg_reset_heatmap': return '重置热力图？';
			case 'strings.legacy.msg_token_applied': return 'Token 已应用';
			case 'strings.legacy.msg_log_file_created': return '日志文件已生成';
			case 'strings.legacy.msg_delete_sync_task': return '删除同步任务';
			case 'strings.legacy.msg_include_archived_2': return '- 包含归档';
			case 'strings.legacy.msg_memoflow_side_project_i_build_my': return 'MemoFlow 是我用业余时间肝出来的孩子。目前开发者已连续熬夜修 Bug，急需一杯冰美式“续命”。你的投喂不仅能恢复我的电量，还能让新功能提早 ';
			case 'strings.legacy.msg_failed_generate': return ({required Object e}) => '生成失败：${e}';
			case 'strings.legacy.msg_search_logs': return '搜索内容';
			case 'strings.legacy.msg_active_days': return '累计天数';
			case 'strings.legacy.msg_back_top': return '回到顶部';
			case 'strings.legacy.msg_month': return '本月回顾';
			case 'strings.legacy.msg_loading_references': return '正在加载引用';
			case 'strings.legacy.msg_silent': return '静音';
			case 'strings.legacy.msg_settings': return '设置';
			case 'strings.legacy.msg_locating': return '正在定位…';
			case 'strings.legacy.msg_scan': return '扫描';
			case 'strings.legacy.msg_recording_path_missing': return '录音路径缺失';
			case 'strings.legacy.msg_date_range_4': return '- 时间范围';
			case 'strings.legacy.msg_suggested_tags': return '推荐标签';
			case 'strings.legacy.msg_energy_restored': return '⚡ ENERGY RESTORED';
			case 'strings.legacy.msg_username_2': return '账号';
			case 'strings.legacy.msg_ai_summary_report': return 'AI 总结报告';
			case 'strings.legacy.msg_all_tags': return '全部标签';
			case 'strings.legacy.msg_preferences': return '偏好设置';
			case 'strings.legacy.msg_image_bed_3': return '图床设置';
			case 'strings.legacy.msg_quick_input': return '快速输入';
			case 'strings.legacy.msg_tags': return '标签';
			case 'strings.legacy.msg_energy_critically_low': return '能量值告急！';
			case 'strings.legacy.msg_delete_failed': return ({required Object e}) => '删除失败：${e}';
			case 'strings.legacy.msg_server_login': return '服务端登录';
			case 'strings.legacy.msg_like_2': return '点赞';
			case 'strings.legacy.msg_save_2': return '确定';
			case 'strings.legacy.msg_unknown': return '未知用户';
			case 'strings.legacy.msg_release_notes_2': return '更新日志';
			case 'strings.legacy.msg_include_error_details': return '包含错误详情';
			case 'strings.legacy.msg_write_comment': return '写下评论...';
			case 'strings.legacy.msg_write_thoughts': return '写下你的想法...';
			case 'strings.legacy.msg_local_2': return '本地';
			case 'strings.legacy.msg_expired': return '已过期';
			case 'strings.legacy.msg_fixed_2': return '修复';
			case 'strings.legacy.msg_upload_attachment': return '上传附件';
			case 'strings.legacy.msg_battery_whitelist': return '电池白名单';
			case 'strings.legacy.msg_district': return '区';
			case 'strings.legacy.msg_voice_memo': return '🎙️ 语音记录\\n';
			case 'strings.legacy.msg_system_default': return '系统默认';
			case 'strings.legacy.msg_all_memos_2': return '全部笔记';
			case 'strings.legacy.msg_network_request_failed': return '网络请求失败';
			case 'strings.legacy.msg_memo_not_found': return '笔记不存在';
			case 'strings.legacy.msg_playback_failed_2': return ({required Object e}) => '播放失败：${e}';
			case 'strings.legacy.msg_sync_settings_webdav_across_devices': return '将设置同步到 WebDAV，在设备之间保持一致。';
			case 'strings.legacy.msg_offline_first_client_memos_backend': return '一个基于 Memos 后端的离线优先客户端。';
			case 'strings.legacy.msg_user_guide': return '使用指南';
			case 'strings.legacy.msg_notice': return '通知';
			case 'strings.legacy.msg_exact_alarms': return '闹钟与提醒';
			case 'strings.legacy.msg_restoring_overwrite_local_library_files_rebuild': return '恢复会覆盖本地库文件，并重新导入数据库。此操作无法撤销。';
			case 'strings.legacy.msg_enter_api_url_ai_settings': return '请先在 AI 设置中填写 API URL';
			case 'strings.legacy.msg_create_failed_2': return ({required Object e}) => '创建失败：${e}';
			case 'strings.legacy.msg_close_search': return '关闭搜索';
			case 'strings.legacy.msg_imported_memos_2': return '查看导入笔记';
			case 'strings.legacy.msg_explore': return '探索';
			case 'strings.legacy.msg_network_connection_failed': return '网络连接失败，请检查网络';
			case 'strings.legacy.msg_save_failed_3': return ({required Object e}) => '保存失败：${e}';
			case 'strings.legacy.msg_no_summary_share': return '暂无可分享的总结';
			case 'strings.legacy.msg_custom_model': return '自定义模型';
			case 'strings.legacy.msg_sign_failed': return ({required Object message}) => '登录失败: ${message}';
			case 'strings.legacy.msg_notification_exact_alarm_permissions_required_send': return '需要通知权限与精确闹钟权限，才能在指定时间发送提醒。';
			case 'strings.legacy.msg_random_review': return '随机漫步';
			case 'strings.legacy.msg_public': return '公开';
			case 'strings.legacy.msg_all_2': return '全部';
			case 'strings.legacy.msg_add_custom_model': return '添加自定义模型';
			case 'strings.legacy.msg_backup_password': return '备份密码';
			case 'strings.legacy.msg_optional_used_sign_requests': return '选填，用于签名请求';
			case 'strings.legacy.msg_search': return '搜索';
			case 'strings.legacy.msg_set_password': return '设置密码';
			case 'strings.legacy.msg_submit_logs': return '提交日志';
			case 'strings.legacy.msg_activity_heatmap_2': return '记录热力图';
			case 'strings.legacy.msg_invalid_api_key_insufficient_permissions': return 'API Key 无效或无权限';
			case 'strings.legacy.msg_data_has_been_migrated_app_successfully': return '您的数据已成功迁移至本应用。';
			case 'strings.legacy.msg_get_version': return '立即获取新版本';
			case 'strings.legacy.msg_token_source': return 'Token 来源';
			case 'strings.legacy.msg_send': return '发送';
			case 'strings.legacy.msg_no_pending_sync_tasks': return '暂无待同步任务';
			case 'strings.legacy.msg_locating_memo_content': return '正在定位笔记内容';
			case 'strings.legacy.msg_offline_ready': return '离线可用';
			case 'strings.legacy.msg_use_relative_path': return '请使用相对路径';
			case 'strings.legacy.msg_total': return '总记录';
			case 'strings.legacy.msg_location_2': return '定位';
			case 'strings.legacy.msg_show_location_metadata_memos_not_configured': return '在笔记中显示定位信息，未配置密钥时将仅显示经纬度。';
			case 'strings.legacy.msg_api_url': return 'API 地址';
			case 'strings.legacy.msg_parsing_progress': return '解析进度';
			case 'strings.legacy.msg_parsing': return '解析中';
			case 'strings.legacy.msg_custom': return '自定义';
			case 'strings.legacy.msg_tags_created': return '新生成的标签';
			case 'strings.legacy.msg_third_party_share_disabled': return '第三方分享未开启';
			case 'strings.legacy.msg_loading_links': return '双链加载中';
			case 'strings.legacy.msg_how_report': return '如何反馈？';
			case 'strings.legacy.msg_confirm_password_2': return '再次输入确认';
			case 'strings.legacy.msg_search_title_content_tags': return '您可以搜索标题、内容或标签';
			case 'strings.legacy.msg_reset_failed': return ({required Object e}) => '重置失败：${e}';
			case 'strings.legacy.msg_debug_preview_update_dialog': return '调试：预览更新公告';
			case 'strings.legacy.msg_what_s': return '写点什么…';
			case 'strings.legacy.msg_ringtone': return '提醒铃声';
			case 'strings.legacy.msg_unable_detect_backend_version_check_server': return '无法识别后端版本，请检查地址或网络';
			case 'strings.legacy.msg_pending_2': return '待同步';
			case 'strings.legacy.msg_parsing_html': return '正在解析 HTML...';
			case 'strings.legacy.msg_actions': return '操作';
			case 'strings.legacy.msg_import_complete_2': return '导入完成';
			case 'strings.legacy.msg_use_disk': return '以磁盘为准';
			case 'strings.legacy.msg_root_path': return '根路径';
			case 'strings.legacy.msg_disabled': return '未启用';
			case 'strings.legacy.msg_improved_2': return '优化：';
			case 'strings.legacy.msg_city': return '市';
			case 'strings.legacy.msg_decoding_zip': return '正在解压 ZIP...';
			case 'strings.legacy.msg_notification_content': return '通知内容';
			case 'strings.legacy.msg_resolve_conflict': return '冲突处理';
			case 'strings.legacy.msg_webhooks_not_supported_server': return '当前服务器不支持 Webhooks';
			case 'strings.legacy.msg_may_delayed': return '（可能延迟）';
			case 'strings.legacy.msg_permissions_system_settings': return '权限与系统设置';
			case 'strings.legacy.msg_waiting_tasks_stop': return '正在等待任务停止';
			case 'strings.legacy.msg_done_2': return '确定';
			case 'strings.legacy.msg_parsing_memoflow_export': return '正在解析 MemoFlow 导出...';
			case 'strings.legacy.msg_location_updated': return ({required Object next_displayText_fractionDigits_6}) => '定位成功：${next_displayText_fractionDigits_6}';
			case 'strings.legacy.msg_checking_server_version': return '正在检查后端版本...';
			case 'strings.legacy.msg_next_time_back_fixing_bugs': return '👀 下次一定，先去修 Bug';
			case 'strings.legacy.msg_ago_4': return ({required Object weeks}) => '${weeks}周前';
			case 'strings.legacy.msg_import': return '导入';
			case 'strings.legacy.msg_ios_long_press_home_screen_add': return 'iOS 请长按桌面添加 MemoFlow 小组件';
			case 'strings.legacy.msg_create_token_2': return '创建 Token';
			case 'strings.legacy.msg_marked_read': return '已标记为已读';
			case 'strings.legacy.msg_pinned': return '置顶';
			case 'strings.legacy.msg_version_update': return '版本更新';
			case 'strings.legacy.msg_allow_private_memos': return '允许发送私有权限笔记';
			case 'strings.legacy.msg_token_copied_clipboard': return 'Token 已复制到剪贴板';
			case 'strings.legacy.msg_keeping_more_versions_uses_more_storage': return '增加保留数量会占用更多存储空间，建议定期清理旧版本。';
			case 'strings.legacy.msg_delete_webhook': return '删除 Webhook';
			case 'strings.legacy.msg_prompt': return '提示词 (Prompt)';
			case 'strings.legacy.msg_location_precision': return '定位精度';
			case 'strings.legacy.msg_password_required': return '需要密码';
			case 'strings.legacy.msg_exit_app': return '退出应用';
			case 'strings.legacy.msg_thanks_energy_fully_restored': return '收到心意！能量已充满 ⚡';
			case 'strings.legacy.msg_connection_timeout_check_network_api_url': return '连接超时，请检查网络或 API URL';
			case 'strings.legacy.app_language.system': return '跟随系统';
			case 'strings.legacy.app_language.zh_hans': return '简体中文';
			case 'strings.legacy.app_language.zh_hant_tw': return '繁体中文（中国台湾）';
			case 'strings.legacy.app_language.en': return '英语';
			case 'strings.legacy.app_language.ja': return '日语';
			case 'strings.legacy.app_language.de': return '德语';
			case 'strings.legacy.app_theme.system': return '系统';
			case 'strings.legacy.app_theme.light': return '浅色';
			case 'strings.legacy.app_theme.dark': return '深色';
			case 'strings.legacy.app_font_size.standard': return '标准';
			case 'strings.legacy.app_font_size.large': return '大';
			case 'strings.legacy.app_font_size.small': return '小';
			case 'strings.legacy.app_line_height.classic': return '经典';
			case 'strings.legacy.app_line_height.compact': return '紧凑';
			case 'strings.legacy.app_line_height.relaxed': return '舒适';
			case 'strings.legacy.launch_action.none': return '无';
			case 'strings.legacy.launch_action.sync': return '同步';
			case 'strings.legacy.launch_action.quick_input': return '快速记录';
			case 'strings.legacy.launch_action.daily_review': return '随机漫步';
			case 'strings.legacy.auto_lock_time.immediately': return '立即';
			case 'strings.legacy.auto_lock_time.after_1_min': return '1 分钟';
			case 'strings.legacy.auto_lock_time.after_5_min': return '5 分钟';
			case 'strings.legacy.auto_lock_time.after_15_min': return '15 分钟';
			case 'strings.legacy.reminder.default_title': return '嗨，你还记得这个想法吗？';
			case 'strings.legacy.reminder.default_body': return '点击查看详情';
			case 'strings.legacy.location.current': return '当前位置';
			case 'strings.legacy.webdav.not_configured': return 'WebDAV 未配置';
			case 'strings.legacy.webdav.backup_disabled': return '备份未启用';
			case 'strings.legacy.webdav.backup_account_missing': return '账号缺失，无法备份';
			case 'strings.legacy.webdav.backup_local_only': return '仅本地库可用备份';
			case 'strings.legacy.webdav.backup_password_missing': return '缺少备份密码';
			case 'strings.legacy.webdav.backup_no_memo_files': return '本地库未发现笔记文件，备份已取消';
			case 'strings.legacy.webdav.restore_account_missing': return '账号缺失，无法恢复';
			case 'strings.legacy.webdav.restore_local_only': return '仅本地库可恢复备份';
			case 'strings.legacy.webdav.backup_empty': return '备份内容为空';
			case 'strings.legacy.webdav.backup_no_memos': return '备份中没有笔记';
			case 'strings.legacy.webdav.snapshot_missing': return '备份快照丢失';
			case 'strings.legacy.webdav.snapshot_corrupted': return '备份快照损坏';
			case 'strings.legacy.webdav.object_missing': return '备份对象缺失';
			case 'strings.legacy.webdav.config_corrupted': return '备份配置损坏';
			case 'strings.legacy.webdav.config_invalid': return '备份配置无效';
			case 'strings.legacy.webdav.password_invalid': return '备份密码错误';
			case 'strings.legacy.webdav.data_corrupted': return '备份数据损坏';
			case 'strings.legacy.webdav.server_url_invalid': return 'WebDAV 服务器地址无效';
			case 'strings.legacy.import_count_memos': return ({required Object count}) => '${count}条';
			case 'strings.legacy.import_count_attachments': return ({required Object count}) => '${count}个';
			case 'strings.legacy.app_drawer.tooltip_single': return ({required Object date, required Object weekday, required Object count}) => '${date}（${weekday}）· ${count} 条';
			case 'strings.legacy.app_drawer.tooltip_multi': return ({required Object date, required Object weekday, required Object count}) => '${date}（${weekday}）· ${count} 条';
			case 'strings.legacy.ai_summary.error_api_key_empty': return 'API Key 为空';
			case 'strings.legacy.ai_summary.system.require_json': return '请严格输出 JSON，不要使用代码块，不要额外说明文字。';
			case 'strings.legacy.ai_summary.system.json_format': return 'JSON 格式：{"insights":["..."],"moodTrend":"...","keywords":["#..."]}';
			case 'strings.legacy.ai_summary.system.insights_rule': return 'insights 控制在 2-5 条，keywords 为 4-8 个带 # 的词。';
			case 'strings.legacy.ai_summary.user.range': return ({required Object rangeLabel}) => '时间范围：${rangeLabel}';
			case 'strings.legacy.ai_summary.user.counts': return ({required Object memoCount, required Object includedCount}) => '笔记条数：${memoCount}（提供用于总结：${includedCount}）';
			case 'strings.legacy.ai_summary.user.profile': return ({required Object profile}) => '用户背景：${profile}';
			case 'strings.legacy.ai_summary.user.custom_prompt': return ({required Object customPrompt}) => '用户补充指令：${customPrompt}';
			case 'strings.legacy.ai_summary.user.memo_content': return '笔记内容：';
			case 'strings.legacy.ai_summary.error_invalid_response': return 'AI 响应格式不正确';
			case 'strings.legacy.ai_summary.error_empty_response': return 'AI 响应为空';
			case 'strings.legacy.ai_summary.error_missing_content': return 'AI 响应内容缺失';
			case 'strings.legacy.ai_summary.default_prompt': return '你是一位极简主义的笔记助手，擅长提炼核心观点并以优雅的格式排版。在回复时，请保持专业、温和且简洁的语气。尽量使用列表和简短的段落。';
			default: return null;
		}
	}
}

extension on _StringsZhHantTw {
	dynamic _flatMapFunction(String path) {
		switch (path) {
			case 'strings.common.back': return '返回';
			case 'strings.common.cancel': return '取消';
			case 'strings.common.confirm': return '確認';
			case 'strings.common.save': return '儲存';
			case 'strings.common.saveSettings': return '儲存設定';
			case 'strings.common.auto': return '自動';
			case 'strings.common.manual': return '手動';
			case 'strings.common.copiedToClipboard': return '已複製到剪貼簿';
			case 'strings.common.serverVersion': return '伺服器版本';
			case 'strings.common.selectValidServerVersion': return '請選擇有效的伺服器版本';
			case 'strings.common.serverVersionValue': return ({required Object version}) => '伺服器版本: ${version}';
			case 'strings.common.selectServerVersionRange021To026': return '請先手動選擇 0.21~0.26 伺服器版本';
			case 'strings.languages.system': return '跟隨系統';
			case 'strings.languages.zhHans': return '簡體中文';
			case 'strings.languages.zhHantTw': return '繁體中文（中國台灣）';
			case 'strings.languages.en': return '英文';
			case 'strings.languages.ja': return '日文';
			case 'strings.languages.de': return '德文';
			case 'strings.languagesNative.system': return '系統';
			case 'strings.languagesNative.zhHans': return '简体中文';
			case 'strings.languagesNative.zhHantTw': return '繁體中文（中國台灣）';
			case 'strings.languagesNative.en': return 'English';
			case 'strings.languagesNative.ja': return '日本語';
			case 'strings.languagesNative.de': return 'Deutsch';
			case 'strings.onboarding.tagline': return '簡約而強大的筆記流';
			case 'strings.onboarding.selectLanguage': return '選擇語言';
			case 'strings.onboarding.selectMode': return '選擇工作模式';
			case 'strings.onboarding.modeHint': return '您可以隨時在設定中變更此項';
			case 'strings.onboarding.modeLocalTitle': return '本機模式';
			case 'strings.onboarding.modeLocalLabel': return '本機模式';
			case 'strings.onboarding.modeLocalDesc': return '資料僅保存在手機本機，無需設定伺服器，適合重視隱私與離線使用的使用者。';
			case 'strings.onboarding.modeServerTitle': return '連線模式';
			case 'strings.onboarding.modeServerLabel': return '伺服器模式';
			case 'strings.onboarding.modeServerDesc': return '連線到你的 Memos 後端，實現多端即時同步。支援 Web、行動端等多平台無縫銜接。';
			case 'strings.onboarding.localLibraryNameTitle': return '本機庫名稱';
			case 'strings.onboarding.localLibraryNameHint': return '請輸入名稱';
			case 'strings.onboarding.localLibraryDefaultName': return '本機庫';
			case 'strings.onboarding.getStarted': return '開始使用';
			case 'strings.login.title': return '連線 Memos';
			case 'strings.login.mode.password': return '帳號密碼';
			case 'strings.login.mode.token': return 'Token 登入';
			case 'strings.login.mode.descPassword': return '使用帳號密碼登入';
			case 'strings.login.mode.descToken': return '使用個人存取權杖登入';
			case 'strings.login.mode.signInMethod': return '登入方式';
			case 'strings.login.field.serverUrlLabel': return '伺服器位址';
			case 'strings.login.field.serverUrlHint': return 'http://localhost:5230';
			case 'strings.login.field.usernameLabel': return '帳號';
			case 'strings.login.field.usernameHint': return '請輸入帳號';
			case 'strings.login.field.passwordLabel': return '密碼';
			case 'strings.login.field.passwordHint': return '請輸入密碼';
			case 'strings.login.field.tokenLabel': return 'Token (PAT)';
			case 'strings.login.field.tokenHint': return 'Token (PAT)';
			case 'strings.login.validation.serverUrlRequired': return '請輸入伺服器位址';
			case 'strings.login.validation.serverUrlInvalid': return '請輸入完整位址（包含 http/https 與埠號）';
			case 'strings.login.validation.usernameRequired': return '請輸入帳號';
			case 'strings.login.validation.passwordRequired': return '請輸入密碼';
			case 'strings.login.validation.tokenRequired': return '請輸入 Token';
			case 'strings.login.compatibility.title': return '相容模式';
			case 'strings.login.compatibility.description': return '使用舊版端點（適配舊版 Memos）';
			case 'strings.login.connect.connecting': return '連線中…';
			case 'strings.login.connect.action': return '連線';
			case 'strings.login.errors.authFailedToken': return '認證失敗，請確認 Token 是否有效或未過期';
			case 'strings.login.errors.authFailedPat': return '認證失敗。新版 Memos 請使用以 memos_pat_ 開頭的 PAT（不要貼上 Bearer 前綴）';
			case 'strings.login.errors.connectionFailedWithMessage': return ({required Object message}) => '連線失敗：${message}';
			case 'strings.login.errors.connectionFailed': return ({required Object error}) => '連線失敗：${error}';
			case 'strings.login.errors.signInFailed': return '登入失敗，請檢查帳號與密碼';
			case 'strings.login.errors.signInFailedWithMessage': return ({required Object message}) => '登入失敗：${message}';
			case 'strings.login.errors.invalidServerUrl': return '伺服器位址無效';
			case 'strings.login.errors.serverUrlNormalized': return '已正規化伺服器位址（移除多餘路徑）';
			case 'strings.settings.preferences.title': return '偏好設定';
			case 'strings.settings.preferences.language': return '語言';
			case 'strings.settings.preferences.fontSize': return '字體大小';
			case 'strings.settings.preferences.lineHeight': return '行高';
			case 'strings.settings.preferences.font': return '字型';
			case 'strings.settings.preferences.systemDefault': return '系統預設';
			case 'strings.settings.preferences.noSystemFonts': return '未找到系統字型';
			case 'strings.settings.preferences.loadFontsFailed': return ({required Object error}) => '字型載入失敗：${error}';
			case 'strings.settings.preferences.collapseLongContent': return '折疊長內容';
			case 'strings.settings.preferences.collapseReferences': return '折疊引用';
			case 'strings.settings.preferences.showEngagementInAllMemoDetails': return '在全部筆記詳情中顯示按讚和評論';
			case 'strings.settings.preferences.launchAction': return '啟動動作';
			case 'strings.settings.preferences.quickInputKeyboard': return '快速記錄時自動開啟鍵盤';
			case 'strings.settings.preferences.appearance': return '外觀';
			case 'strings.settings.preferences.themeColor': return '主題色';
			case 'strings.settings.preferences.haptics': return '觸覺回饋';
			case 'strings.settings.preferences.customTheme': return '自訂主題';
			case 'strings.settings.preferences.history': return '歷史';
			case 'strings.settings.preferences.lightMode': return '淺色模式';
			case 'strings.settings.preferences.darkMode': return '深色模式';
			case 'strings.settings.preferences.surfaces': return '表面色';
			case 'strings.settings.preferences.background': return '背景';
			case 'strings.settings.preferences.backgroundColor': return '背景色';
			case 'strings.settings.preferences.card': return '卡片';
			case 'strings.settings.preferences.cardColor': return '卡片色';
			case 'strings.settings.preferences.border': return '邊框';
			case 'strings.settings.preferences.borderColor': return '邊框色';
			case 'strings.legacy.msg_memos_backend_docs': return 'memos后端使用文档';
			case 'strings.legacy.msg_remember_moment_feel_warmth_life_take': return '记住这一刻，感受生活的温度。\\n每天来一次随机漫步。';
			case 'strings.legacy.msg_sure_want_delete_shortcut': return '确定要删除该快捷筛选吗？';
			case 'strings.legacy.msg_scan_completed': return '扫描完成';
			case 'strings.legacy.msg_confirm': return '确认';
			case 'strings.legacy.msg_unable_open_browser_install_browser_app': return '无法打开浏览器，请检查是否安装了浏览器';
			case 'strings.legacy.msg_contributors': return '贡献与致谢';
			case 'strings.legacy.msg_enter_keywords_search_box_query_local': return '在搜索框输入关键词可检索本地内容与标签。离线可用；首次使用请等待本地索引完成。';
			case 'strings.legacy.msg_memo_not_found_locally': return '本地暂无该笔记';
			case 'strings.legacy.msg_token': return 'Token 摘要';
			case 'strings.legacy.msg_last_7_days': return '最近一周';
			case 'strings.legacy.msg_search_memo_content': return '搜索笔记内容';
			case 'strings.legacy.msg_retry_started': return '已开始重试同步';
			case 'strings.legacy.msg_last_year_memos': return ({required Object lastYearMemos}) => '最近一年记录 ${lastYearMemos} 条笔记';
			case 'strings.legacy.msg_no_content_yet': return '暂无内容';
			case 'strings.legacy.msg_no_summary_yet': return '暂无总结结果';
			case 'strings.legacy.msg_sooner': return ' 上线！';
			case 'strings.legacy.msg_token_copied': return 'Token 已复制';
			case 'strings.legacy.msg_share': return '分享';
			case 'strings.legacy.msg_gallery_permission_required': return '需要相册权限以保存二维码';
			case 'strings.legacy.msg_basic_settings': return '基础设置';
			case 'strings.legacy.msg_bad_ssl_certificate': return '证书校验失败';
			case 'strings.legacy.msg_no_notifications': return '暂无通知';
			case 'strings.legacy.msg_import_markdown': return '从 Markdown 导入';
			case 'strings.legacy.msg_upload_zip_package_md_files': return '请上传包含 .md 文件的 .zip 压缩包';
			case 'strings.legacy.msg_request_send_timeout_try': return '请求发送超时，请稍后重试';
			case 'strings.legacy.msg_select_date_range': return '选择时间范围';
			case 'strings.legacy.msg_delete_shortcut': return '删除快捷筛选';
			case 'strings.legacy.msg_auto_lock_time': return '自动锁定时间';
			case 'strings.legacy.msg_replacing_delete_original_attachment_continue': return '替换后将删除原图片附件，是否继续？';
			case 'strings.legacy.msg_add_least_one_condition': return '请至少设置一个条件';
			case 'strings.legacy.msg_upload_images_image_bed_append_links': return '开启后自动将图片上传到图床，并在文末插入图片链接。';
			case 'strings.legacy.msg_request_cancelled': return '请求已取消';
			case 'strings.legacy.msg_generating': return '生成中…';
			case 'strings.legacy.msg_permissions_denied_reminders_disabled': return '权限未授予，提醒未开启';
			case 'strings.legacy.msg_memoflow_local_reminders': return 'MemoFlow 本地提醒';
			case 'strings.legacy.msg_use_legacy_endpoints_older_memos_servers': return '使用旧版接口（适配旧版 Memos）';
			case 'strings.legacy.msg_no_comments_yet': return '暂无评论';
			case 'strings.legacy.msg_open': return '打开';
			case 'strings.legacy.msg_microphone_permission_required': return '需要麦克风权限';
			case 'strings.legacy.msg_failed_react': return ({required Object e}) => '点赞失败：${e}';
			case 'strings.legacy.msg_restore_backup': return '恢复备份？';
			case 'strings.legacy.msg_qr_saved_gallery': return '二维码已保存到系统相册';
			case 'strings.legacy.msg_no_attachments': return '暂无附件';
			case 'strings.legacy.msg_enable_reminder_permissions': return '启用提醒权限';
			case 'strings.legacy.msg_created_time': return '创建时间 ↑';
			case 'strings.legacy.msg_prompt_saved_quick_prompts': return '提示词将保存在快速总结中';
			case 'strings.legacy.msg_remember_password': return '记住密码';
			case 'strings.legacy.msg_enter_valid_url': return '请输入有效的 URL';
			case 'strings.legacy.msg_may_take_few_seconds': return '可能需要几秒钟';
			case 'strings.legacy.msg_local_sync_failed': return ({required Object type, required Object memoError}) => '本地同步失败（${type}）：${memoError}';
			case 'strings.legacy.msg_webdav_sync': return 'WebDAV 同步';
			case 'strings.legacy.msg_clear': return '清空';
			case 'strings.legacy.msg_clear_recycle_bin_confirm': return '確認清空回收站？回收站內所有內容將被永久刪除。';
			case 'strings.legacy.msg_save_failed': return '保存失败';
			case 'strings.legacy.msg_endpoint_not_found_version_mismatch': return '接口不存在（可能是 Memos 版本不兼容）';
			case 'strings.legacy.msg_enable_webdav_sync': return '启用 WebDAV 同步';
			case 'strings.legacy.msg_local_libraries': return '本地库';
			case 'strings.legacy.msg_apply': return '确定';
			case 'strings.legacy.msg_restore_only_available_local_libraries': return '仅本地库可恢复备份';
			case 'strings.legacy.msg_sign': return '退出登录？';
			case 'strings.legacy.msg_reminders_disabled': return '提醒功能已关闭';
			case 'strings.legacy.msg_downloading': return '正在下载';
			case 'strings.legacy.msg_path': return '路径';
			case 'strings.legacy.msg_match_any': return '满足任一条件';
			case 'strings.legacy.msg_local_db_pending_queue': return '本地数据库 + 待同步队列';
			case 'strings.legacy.msg_scan_failed': return ({required Object e}) => '扫描失败：${e}';
			case 'strings.legacy.msg_user': return '用户';
			case 'strings.legacy.msg_pick_future_time': return '请选择未来时间';
			case 'strings.legacy.msg_include_pending_queue': return '包含待处理队列';
			case 'strings.legacy.msg_enter_days': return '输入天数';
			case 'strings.legacy.msg_times': return '提醒时间';
			case 'strings.legacy.msg_token_returned_only_once_cannot_fetched': return 'Token 仅返回一次，无法再次获取';
			case 'strings.legacy.msg_quoted_lines': return ({required Object quoteLines}) => '引用 ${quoteLines} 行';
			case 'strings.legacy.msg_use_remote': return '使用远端';
			case 'strings.legacy.msg_enable_memo_location': return '启用定位';
			case 'strings.legacy.msg_failed_get_location': return '定位失败';
			case 'strings.legacy.msg_after_import_memos_sync_list_automatically': return '导入完成后，您的笔记将自动同步到笔记列表。对于压缩包导入，请确保文件结构完整。';
			case 'strings.legacy.msg_legacy_mode': return '兼容模式';
			case 'strings.legacy.msg_signed': return '登录成功';
			case 'strings.legacy.msg_shortcut_includes_advanced_conditions_saving_overwrite': return '该快捷筛选包含高级条件，保存将覆盖这些条件。';
			case 'strings.legacy.msg_no_results_found': return '未找到相关内容';
			case 'strings.legacy.msg_reply': return ({required Object replyName}) => '回复 ${replyName}...';
			case 'strings.legacy.msg_copy': return '复制';
			case 'strings.legacy.msg_enable_reminders_memos': return '开启后可为笔记设置提醒时间。';
			case 'strings.legacy.msg_comment': return '评论';
			case 'strings.legacy.msg_added_voice_attachment': return '已添加录音附件';
			case 'strings.legacy.msg_customize_sidebar': return '自定义侧边栏';
			case 'strings.legacy.msg_coffee_add_drumstick': return '☕ 这就是我要的咖啡/加个鸡腿';
			case 'strings.legacy.msg_pin': return '置顶';
			case 'strings.legacy.msg_enter_password_continue': return '请输入密码以继续';
			case 'strings.legacy.msg_remove_local_library': return '移除本地库？';
			case 'strings.legacy.msg_comment_2': return '新评论';
			case 'strings.legacy.msg_sync_all': return '全部同步';
			case 'strings.legacy.msg_backup_schedule': return '备份频率';
			case 'strings.legacy.msg_server_error': return '服务器内部错误';
			case 'strings.legacy.msg_analyzing_memos': return '正在深度分析您的笔记...';
			case 'strings.legacy.msg_notification': return '通知';
			case 'strings.legacy.msg_policy': return '策略设置';
			case 'strings.legacy.msg_failed_load': return ({required Object error}) => '加载失败: ${error}';
			case 'strings.legacy.msg_default_visibility': return '默认可见性';
			case 'strings.legacy.msg_filter': return '筛选';
			case 'strings.legacy.msg_imported_memos': return '导入笔记';
			case 'strings.legacy.msg_token_created': return 'Token 已创建';
			case 'strings.legacy.msg_server_response_timeout_try': return '服务器响应超时，请稍后重试';
			case 'strings.legacy.msg_expiring': return '即将过期';
			case 'strings.legacy.msg_delete_task': return '删除任务';
			case 'strings.legacy.msg_body_must_json': return 'Body 必须是 JSON';
			case 'strings.legacy.msg_enable': return '去开启';
			case 'strings.legacy.msg_referenced': return '被引用';
			case 'strings.legacy.msg_replace_image': return '确认替换？';
			case 'strings.legacy.msg_debug_logs': return '调试记录';
			case 'strings.legacy.msg_active_tasks': return '正在进行的任务';
			case 'strings.legacy.msg_attachments': return '附件';
			case 'strings.legacy.msg_range': return '時間範圍';
			case 'strings.legacy.msg_no_backups_found': return '暂无备份记录';
			case 'strings.legacy.msg_create_memo': return '创建笔记';
			case 'strings.legacy.msg_street': return '街道';
			case 'strings.legacy.msg_display_name': return '显示名称';
			case 'strings.legacy.msg_full_text_search': return '全文搜索';
			case 'strings.legacy.msg_create_edit_delete_actions_offline_stored': return '离线创建/编辑/删除会先保存在本地并加入待同步队列，联网后按顺序发送。为避免误操作，未提交的编辑可保留为草稿。';
			case 'strings.legacy.msg_sign_2': return '退出登录';
			case 'strings.legacy.msg_end_time': return '结束时间';
			case 'strings.legacy.msg_sync_recent_content': return '同步最近内容';
			case 'strings.legacy.msg_resetting_local_data': return '正在重置本地数据...';
			case 'strings.legacy.msg_incorrect_password': return '密码错误';
			case 'strings.legacy.msg_content_cannot_empty': return '内容不能为空';
			case 'strings.legacy.msg_preparing': return '准备中';
			case 'strings.legacy.msg_ai_summary_failed': return ({required Object formatSummaryError_e}) => 'AI 总结失败：${formatSummaryError_e}';
			case 'strings.legacy.msg_manage': return '管理';
			case 'strings.legacy.msg_keep_data_consistent_across_devices': return '保持设备间数据一致。';
			case 'strings.legacy.msg_playback_failed': return ({required Object e}) => '播放失败: ${e}';
			case 'strings.legacy.msg_path_copied': return '路径已复制';
			case 'strings.legacy.msg_auth_settings': return '认证设置';
			case 'strings.legacy.msg_randomly_draw_memo_cards': return '随机抽取你的卡片笔记';
			case 'strings.legacy.msg_copy_log_text': return '复制日志文本';
			case 'strings.legacy.msg_yes': return '是';
			case 'strings.legacy.msg_save_open_alipay_scan': return '长按保存后打开支付宝扫一扫';
			case 'strings.legacy.msg_signed_but_no_token_returned': return '登录成功，但未返回 Token';
			case 'strings.legacy.msg_create_failed': return ({required Object formatError_e_context}) => '创建失败：${formatError_e_context}';
			case 'strings.legacy.msg_expand': return '展开';
			case 'strings.legacy.msg_local_library_only': return '仅本地库可用';
			case 'strings.legacy.msg_reminder_channel': return '提醒通知渠道';
			case 'strings.legacy.msg_grant': return '去授权';
			case 'strings.legacy.msg_import_canceled': return '已取消导入';
			case 'strings.legacy.msg_never': return '永不过期';
			case 'strings.legacy.msg_release_notes': return '版本公告';
			case 'strings.legacy.msg_failed_load_references': return '加载引用失败';
			case 'strings.legacy.msg_select_tags': return '选择标签';
			case 'strings.legacy.msg_failed_load_try': return '加载失败，请稍后重试';
			case 'strings.legacy.msg_logs_copied': return '记录已复制';
			case 'strings.legacy.msg_shortcuts_not_supported_server': return '当前服务器不支持快捷筛选';
			case 'strings.legacy.msg_reply_2': return ({required Object name}) => '回复 ${name}...';
			case 'strings.legacy.msg_anonymous': return '匿名';
			case 'strings.legacy.msg_username': return '用户名';
			case 'strings.legacy.msg_update_memo': return '更新笔记';
			case 'strings.legacy.msg_saved': return ({required Object targetPath}) => '已保存到: ${targetPath}';
			case 'strings.legacy.msg_chinese_simplified': return '简体中文';
			case 'strings.legacy.msg_memo_copied': return '已复制笔记内容';
			case 'strings.legacy.msg_collapse': return '收起';
			case 'strings.legacy.msg_retry_count_controls_how_many_extra': return '重试次数决定了上传失败后的最大尝试频率。设置较高的次数可以提高成功率，但可能增加等待时间。';
			case 'strings.legacy.msg_recording_info_missing': return '录音信息缺失';
			case 'strings.legacy.msg_sync_task': return '同步任务';
			case 'strings.legacy.msg_clear_all_debug_logs': return '确认清空调试记录？';
			case 'strings.legacy.msg_export_finished': return '导出完成';
			case 'strings.legacy.msg_failed_stop_recording': return ({required Object e}) => '停止录音失败：${e}';
			case 'strings.legacy.msg_my_profile': return '我的资料';
			case 'strings.legacy.msg_image_bed': return '兰空图床';
			case 'strings.legacy.msg_failed_open_notification': return ({required Object e}) => '打开通知失败：${e}';
			case 'strings.legacy.msg_manual': return '手动';
			case 'strings.legacy.msg_no_html_file_found_zip': return '压缩包内未找到 HTML 文件';
			case 'strings.legacy.msg_also_clear_local_cache_account_offline': return '这会同时清除该账号的本地缓存（离线数据/草稿/待同步队列）。此操作无法撤销。';
			case 'strings.legacy.msg_restore': return '恢复';
			case 'strings.legacy.msg_auto_backup': return '自动备份';
			case 'strings.legacy.msg_generate_summary': return '开始生成总结';
			case 'strings.legacy.msg_days': return ({required Object stats_activeDays}) => '${stats_activeDays} 天';
			case 'strings.legacy.msg_count': return '- 數量';
			case 'strings.legacy.msg_weekly': return '每周';
			case 'strings.legacy.msg_notifications': return '通知';
			case 'strings.legacy.msg_backup_failed': return '备份失败';
			case 'strings.legacy.msg_private': return '仅私密';
			case 'strings.legacy.msg_filter_tags': return '标签筛选';
			case 'strings.legacy.msg_clear_logs': return '清空记录';
			case 'strings.legacy.msg_unable_open_browser': return '无法打开浏览器';
			case 'strings.legacy.msg_attachment_too_large': return '附件过大，超过服务器限制';
			case 'strings.legacy.msg_query': return 'Query';
			case 'strings.legacy.msg_match_all': return '满足所有条件';
			case 'strings.legacy.msg_record_request_response_logs': return '记录请求/响应日志';
			case 'strings.legacy.msg_import_file': return '导入文件';
			case 'strings.legacy.msg_content_tags': return '内容 + 标签';
			case 'strings.legacy.msg_feature_not_available_local_library_mode': return '本地库模式暂不支持该功能';
			case 'strings.legacy.msg_import_failed': return ({required Object e}) => '导入失败: ${e}';
			case 'strings.legacy.msg_save_memo': return '保存为笔记';
			case 'strings.legacy.msg_scan_disk_directory_merge_local_database': return '扫描磁盘目录并合并到本地数据库？缺失文件将视为删除。';
			case 'strings.legacy.msg_passwords_not_match': return '两次密码不一致';
			case 'strings.legacy.msg_signed_2': return ({required Object lastLoginUser}) => '当前登录用户: ${lastLoginUser}';
			case 'strings.legacy.msg_made_love_note_taking': return '为记录而生';
			case 'strings.legacy.msg_password_updated_local': return '密码已更新（仅本地）';
			case 'strings.legacy.msg_retry': return '重试';
			case 'strings.legacy.msg_memo_stats': return '记录统计';
			case 'strings.legacy.msg_shown_only_once_copy_keep_safe': return '仅显示一次，请复制并妥善保存。';
			case 'strings.legacy.msg_describe_issue_time_repro_steps_etc': return '描述问题、时间、复现步骤等';
			case 'strings.legacy.msg_how_many_days_back': return '过去多少天';
			case 'strings.legacy.msg_local_cache_cleared': return '本地缓存已清除';
			case 'strings.legacy.msg_none': return '无';
			case 'strings.legacy.msg_body_json': return 'Body (JSON)';
			case 'strings.legacy.msg_download_failed': return ({required Object e}) => '下载失败: ${e}';
			case 'strings.legacy.msg_recycle_bin': return '回收站';
			case 'strings.legacy.msg_unpin': return '取消置顶';
			case 'strings.legacy.msg_advanced_security': return '高级与安全';
			case 'strings.legacy.msg_run_issues_memoflow_e_g_sync': return '如果您在使用 MemoFlow 时遇到问题（如同步失败、崩溃等），请按照以下步骤向我们反馈，这将帮助开发者快速定位并修复问题。\\n\\n';
			case 'strings.legacy.msg_remove_all_reminder_times_memo': return '将移除该笔记的全部提醒时间。';
			case 'strings.legacy.msg_no_summary_save': return '暂无可保存的总结';
			case 'strings.legacy.msg_reset_language_selection': return '重置语言选择状态';
			case 'strings.legacy.msg_v_30_days': return '30 天';
			case 'strings.legacy.msg_e_g_mood_check': return '如：情绪分析';
			case 'strings.legacy.msg_note_some_tokens_returned_only_once': return '提示：Token 可能只返回一次，之后无法再次获取，请妥善保存。';
			case 'strings.legacy.msg_syncing': return '同步中...';
			case 'strings.legacy.msg_retention': return '版本保留数量';
			case 'strings.legacy.msg_open_login_screen': return '打开登录页面';
			case 'strings.legacy.msg_apply_all': return '应用到全部';
			case 'strings.legacy.msg_write_something_supports_tag_tasks_x': return '写点什么... 支持 #tag 和任务 [ ] / [x]';
			case 'strings.legacy.msg_http': return ({required Object base, required Object status, required Object msg}) => '${base}（HTTP ${status}）：${msg}';
			case 'strings.legacy.msg_single': return '单次';
			case 'strings.legacy.msg_delete_memo': return '删除 Memo？';
			case 'strings.legacy.msg_ai_provider': return 'AI 提供方';
			case 'strings.legacy.msg_release_notes_v': return ({required Object version}) => '版本公告 v${version}';
			case 'strings.legacy.msg_info_only_used_background_ai_summaries': return '这些信息仅用于 AI 总结/报告的背景，不会同步到后端。';
			case 'strings.legacy.msg_not_disturb': return '免打扰模式';
			case 'strings.legacy.msg_local_library_import_failed': return ({required Object e}) => '本地库导入失败: ${e}';
			case 'strings.legacy.msg_key_insights': return '核心洞察';
			case 'strings.legacy.msg_additional_notes_optional': return '补充说明（可选）';
			case 'strings.legacy.msg_server_response_error': return '服务响应异常';
			case 'strings.legacy.msg_sort': return '排序';
			case 'strings.legacy.msg_api_call': return 'API 调用';
			case 'strings.legacy.msg_webhooks': return 'Webhooks';
			case 'strings.legacy.msg_local_library': return '本地库';
			case 'strings.legacy.msg_log_copied': return '日志已复制';
			case 'strings.legacy.msg_last_success': return '最近成功';
			case 'strings.legacy.msg_restore_cloud': return '从云端恢复';
			case 'strings.legacy.msg_search_public_memos': return '搜索公开内容';
			case 'strings.legacy.msg_cancel': return '取消生成';
			case 'strings.legacy.msg_processing': return ({required Object processed, required Object total}) => '正在处理 ${processed} / ${total}';
			case 'strings.legacy.msg_failed_items': return '失败条数';
			case 'strings.legacy.msg_recording_file_not_found': return '录音文件不存在';
			case 'strings.legacy.msg_local_db_outbox_queue': return '本地数据库 + 待同步队列';
			case 'strings.legacy.msg_remove': return '移除';
			case 'strings.legacy.msg_export_format': return '导出格式';
			case 'strings.legacy.msg_idle': return '空闲';
			case 'strings.legacy.msg_ago': return ({required Object months}) => '${months}個月前';
			case 'strings.legacy.msg_no_tags_yet': return '暂无标签';
			case 'strings.legacy.msg_version_v': return ({required Object version}) => '版本 v${version}';
			case 'strings.legacy.msg_sync': return '同步';
			case 'strings.legacy.msg_done': return '完成';
			case 'strings.legacy.msg_gallery_permission_required_2': return '需要相册权限以保存图片';
			case 'strings.legacy.msg_insufficient_permissions': return '权限不足';
			case 'strings.legacy.msg_no_download_url_available': return '无法获取下载链接';
			case 'strings.legacy.msg_record_create_memos': return '录音生成 memo';
			case 'strings.legacy.msg_signing': return '登录中…';
			case 'strings.legacy.msg_memoflow_uses_system_location_permission_get': return '定位将使用系统权限获取经纬度，并通过高德 Web API 反向地理解析地址，可在上方选择显示精度。';
			case 'strings.legacy.msg_continue': return '继续';
			case 'strings.legacy.msg_notification_content_unavailable': return '通知缺少内容';
			case 'strings.legacy.msg_unable_read_file_path': return '无法获取文件路径';
			case 'strings.legacy.msg_all_memos': return '全部笔记';
			case 'strings.legacy.msg_keywords': return '關鍵詞';
			case 'strings.legacy.msg_import_result': return '导入结果';
			case 'strings.legacy.msg_offline_sync': return '离线同步';
			case 'strings.legacy.msg_imported_memos_local_library': return '已从本地库导入笔记';
			case 'strings.legacy.msg_request_failed': return '请求失败';
			case 'strings.legacy.msg_log_file': return '日志文件';
			case 'strings.legacy.msg_after_confirming_support_unlock_limited_gold': return '点击确认赞赏后，将解锁限定版金色标识 or 永久去广告承诺（虽然本来就没广告）';
			case 'strings.legacy.msg_failed_open_system_settings': return '无法打开系统设置';
			case 'strings.legacy.msg_no_mood_trend': return '暂无情绪趋势';
			case 'strings.legacy.msg_memoflow_export': return '# MemoFlow 导出';
			case 'strings.legacy.msg_sync_queue': return '同步队列';
			case 'strings.legacy.msg_only_delete_sync_task_memo_kept': return '仅删除同步任务，笔记会保留。';
			case 'strings.legacy.msg_add_home_screen': return '添加到桌面';
			case 'strings.legacy.msg_past_days': return '过去天数';
			case 'strings.legacy.msg_poster_generation_failed': return '海报生成失败';
			case 'strings.legacy.msg_failed_load_stats': return ({required Object e}) => '加载统计失败：${e}';
			case 'strings.legacy.msg_customize_notification': return '自定义通知';
			case 'strings.legacy.msg_updated_time': return '修改时间 ↓';
			case 'strings.legacy.msg_network_connection_failed_check_network': return '网络连接失败，请检查网络';
			case 'strings.legacy.msg_special_thanks': return '本次更新特別鳴謝：';
			case 'strings.legacy.msg_failed_comment': return ({required Object e}) => '评论失败：${e}';
			case 'strings.legacy.msg_security_key_sig': return '安全密钥（sig）';
			case 'strings.legacy.msg_save_gallery': return '保存到相册';
			case 'strings.legacy.msg_request_sent_confirm_system_prompt': return '已发送请求，请在系统提示中确认';
			case 'strings.legacy.msg_server_url': return '服务器地址';
			case 'strings.legacy.msg_period_review': return '阶段回顾';
			case 'strings.legacy.msg_settings_updated': return '已更新设置';
			case 'strings.legacy.msg_backend_0_21_not_supported_import': return '检测到 0.21 版本，暂不支持导入，请升级后端后再试';
			case 'strings.legacy.msg_failed_load_tags': return ({required Object e}) => '加载标签失败：${e}';
			case 'strings.legacy.msg_enter_email': return '请输入邮箱';
			case 'strings.legacy.msg_add_webhook': return '新增 Webhook';
			case 'strings.legacy.msg_read': return '已读';
			case 'strings.legacy.msg_widgets': return '小组件';
			case 'strings.legacy.msg_default': return '默认';
			case 'strings.legacy.msg_memo_reminders': return '笔记提醒';
			case 'strings.legacy.msg_import_flomo': return '从 Flomo 导入';
			case 'strings.legacy.msg_format_fixed_markdown_zip': return '格式固定为 Markdown + ZIP';
			case 'strings.legacy.msg_enter_username_password': return '请输入账号和密码';
			case 'strings.legacy.msg_loading': return '加载中...';
			case 'strings.legacy.msg_test_scheduled': return ({required Object timeLabel, required Object suffix, required Object pendingLabel}) => '已安排测试提醒：${timeLabel}${suffix}${pendingLabel}';
			case 'strings.legacy.msg_edit_memo': return '编辑 Memo';
			case 'strings.legacy.msg_save': return '保存';
			case 'strings.legacy.msg_laboratory': return '实验室';
			case 'strings.legacy.msg_use_local': return '使用本地';
			case 'strings.legacy.msg_retry_sync': return '重试同步';
			case 'strings.legacy.msg_e_g_my_role_topics_interest': return '例如：我的角色 / 兴趣主题 / 写作风格偏好';
			case 'strings.legacy.msg_confirm_password': return '确认密码';
			case 'strings.legacy.msg_not_set': return '未设置';
			case 'strings.legacy.msg_no_memos_day': return '当天无记录';
			case 'strings.legacy.msg_shortcut_name': return '输入名称';
			case 'strings.legacy.msg_edit_shortcut': return '编辑快捷筛选';
			case 'strings.legacy.msg_days_memos': return '坚持记录天数';
			case 'strings.legacy.msg_delete': return '删除';
			case 'strings.legacy.msg_test_reminder': return '测试提醒';
			case 'strings.legacy.msg_enable_reminders': return '开启提醒';
			case 'strings.legacy.msg_links': return '双链';
			case 'strings.legacy.msg_location': return '定位设置';
			case 'strings.legacy.msg_import_file_2': return '从文件导入';
			case 'strings.legacy.msg_reply_3': return ({required Object creatorDisplayName_commentCreator_commentMemo_creator}) => '回复 ${creatorDisplayName_commentCreator_commentMemo_creator}...';
			case 'strings.legacy.msg_created': return ({required Object widget_createdAtLabel}) => '创建于 ${widget_createdAtLabel}';
			case 'strings.legacy.msg_notifications_coming_soon': return '通知功能即将上线';
			case 'strings.legacy.msg_view_full_contributors': return '查看完整致谢名单';
			case 'strings.legacy.msg_no_times_set': return '尚未设置提醒时间';
			case 'strings.legacy.msg_ignore_tls_errors': return '忽略证书校验';
			case 'strings.legacy.msg_no_content': return '无内容';
			case 'strings.legacy.msg_about_15_seconds_left': return '预计还需 15 秒';
			case 'strings.legacy.msg_view_imported_memos': return '查看导入笔记';
			case 'strings.legacy.msg_load_failed': return '加载失败';
			case 'strings.legacy.msg_disk_content_conflicts_local_pending_changes': return '磁盘与本地未同步内容冲突。选择“以磁盘为准”将覆盖本地内容。';
			case 'strings.legacy.msg_all_history_so_far_memoflow_since': return '以上是全部历史内容\\nMEMOFLOW SINCE 2023';
			case 'strings.legacy.msg_cancelling': return '取消中';
			case 'strings.legacy.msg_reading_file': return '正在读取文件...';
			case 'strings.legacy.msg_switch_workspace': return '切换工作区';
			case 'strings.legacy.msg_optional_leave_empty_default': return '选填，使用默认存储策略时请留空';
			case 'strings.legacy.msg_memo_reminders_2': return '笔记提醒';
			case 'strings.legacy.msg_save_failed_2': return ({required Object e}) => '保存失败: ${e}';
			case 'strings.legacy.msg_record_create_memos_sync_later': return '录音生成 memo（可稍后同步）';
			case 'strings.legacy.msg_use_https_avoid_ignoring_tls_errors': return '为了安全，建议使用 HTTPS，且避免忽略证书校验。';
			case 'strings.legacy.msg_failed_load_announcement_config': return '未获取到公告配置';
			case 'strings.legacy.msg_shortcuts': return '快捷筛选';
			case 'strings.legacy.msg_memo': return '笔记';
			case 'strings.legacy.msg_maybe_later': return '稍后再说';
			case 'strings.legacy.msg_server_connection': return '服务器连接';
			case 'strings.legacy.msg_days_2': return '天';
			case 'strings.legacy.msg_include_archived': return '包含归档';
			case 'strings.legacy.msg_during_quiet_hours_reminders_silenced': return '在免打扰期间，应用将保持静默，不会弹出任何提醒。';
			case 'strings.legacy.msg_preview_not_supported_type': return '暂不支持该类型预览';
			case 'strings.legacy.msg_failed_load_2': return '加载失败';
			case 'strings.legacy.msg_create_token': return '创建新 Token';
			case 'strings.legacy.msg_enter_name': return '请输入筛选名称';
			case 'strings.legacy.msg_api_url_incorrect': return 'API URL 不正确';
			case 'strings.legacy.msg_user_general_settings': return '用户通用设置';
			case 'strings.legacy.msg_saved_memo': return '已保存为笔记';
			case 'strings.legacy.msg_restore_failed': return ({required Object e}) => '恢复失败：${e}';
			case 'strings.legacy.msg_token_tail': return ({required Object tail}) => 'Token 尾号 ${tail}';
			case 'strings.legacy.msg_manual_token': return '手动 Token';
			case 'strings.legacy.msg_ago_2': return ({required Object years}) => '${years}年前';
			case 'strings.legacy.msg_recent_searches': return '最近搜索';
			case 'strings.legacy.msg_restored': return '已恢复';
			case 'strings.legacy.msg_no_contributors_yet': return '暂无致谢名单';
			case 'strings.legacy.msg_no_record_yet': return '暂无记录';
			case 'strings.legacy.msg_reminder': return '提醒';
			case 'strings.legacy.msg_enter_api_key_ai_settings': return '请先在 AI 设置中填写 API Key';
			case 'strings.legacy.msg_reminder_settings': return '提醒设置';
			case 'strings.legacy.msg_http_2': return ({required Object base, required Object status}) => '${base}（HTTP ${status}）';
			case 'strings.legacy.msg_edit_webhook': return '编辑 Webhook';
			case 'strings.legacy.msg_generate_share_poster': return '生成分享海报';
			case 'strings.legacy.msg_archive_failed': return ({required Object e}) => '归档失败：${e}';
			case 'strings.legacy.msg_comments': return ({required Object widget_commentCount}) => '${widget_commentCount} æ¢è©è«';
			case 'strings.legacy.msg_remove_account': return '移除账号？';
			case 'strings.legacy.msg_chinese_traditional': return '繁體中文';
			case 'strings.legacy.msg_private_2': return '私密';
			case 'strings.legacy.msg_current_streak': return '当前连击';
			case 'strings.legacy.msg_generated_ai_memoflow': return '由 AI 生成 · MemoFlow';
			case 'strings.legacy.msg_edit_completed': return '编辑完成';
			case 'strings.legacy.msg_local': return '本地调试';
			case 'strings.legacy.msg_edit': return '编辑';
			case 'strings.legacy.msg_text': return ({required Object shortUserName_item_sender}) => '来自 ${shortUserName_item_sender}';
			case 'strings.legacy.msg_got': return '知道了';
			case 'strings.legacy.msg_web_api_key': return 'Web API Key';
			case 'strings.legacy.msg_preview': return '预览';
			case 'strings.legacy.msg_enter_password': return '请输入密码';
			case 'strings.legacy.msg_api': return '接口';
			case 'strings.legacy.msg_ok': return '确定';
			case 'strings.legacy.msg_failed_load_shortcuts': return '快捷筛选加载失败';
			case 'strings.legacy.msg_after_recording_audio_added_current_draft': return '录音完成后会将音频作为附件加入当前草稿，便于继续编辑后再发送。最长 60 分钟；可后续通过第三方服务转写。';
			case 'strings.legacy.msg_pull_refresh': return '下拉刷新';
			case 'strings.legacy.msg_unable_open_photo': return '无法打开照片';
			case 'strings.legacy.msg_existing_tokens': return '已有 Token';
			case 'strings.legacy.msg_ai_settings': return 'AI 设置';
			case 'strings.legacy.msg_app_lock': return '应用锁';
			case 'strings.legacy.msg_total_notes': return '总记录';
			case 'strings.legacy.msg_stats_loading': return '统计数据加载中...';
			case 'strings.legacy.msg_enter_token_description': return '请输入 Token 描述';
			case 'strings.legacy.msg_enter_token': return '请输入 Token';
			case 'strings.legacy.msg_api_plugins': return 'API 与插件';
			case 'strings.legacy.msg_parsing_file': return '正在解析文件...';
			case 'strings.legacy.msg_english': return '英语';
			case 'strings.legacy.msg_activity_heatmap': return '记录热力图';
			case 'strings.legacy.msg_mark_read': return '标记已读';
			case 'strings.legacy.msg_request': return '申请';
			case 'strings.legacy.msg_sync_failed': return ({required Object type, required Object memoError}) => '同步失败（${type}）：${memoError}';
			case 'strings.legacy.msg_error_copied': return '已复制错误信息';
			case 'strings.legacy.msg_only_local_index_removed_disk_files': return '仅移除本地索引，磁盘文件保留。此操作无法撤销。';
			case 'strings.legacy.msg_switch_account': return '切换账号';
			case 'strings.legacy.msg_invalid_download_link': return '无效的更新链接';
			case 'strings.legacy.msg_about': return '关于';
			case 'strings.legacy.msg_icon': return '图标选择';
			case 'strings.legacy.msg_reset_done_syncing': return '已重置，开始重新同步';
			case 'strings.legacy.msg_enter_amap_web_api_key': return '请输入高德 Web API Key';
			case 'strings.legacy.msg_recycle_bin_coming_soon': return '回收站功能暂未开放';
			case 'strings.legacy.msg_empty_content': return '（空内容）';
			case 'strings.legacy.msg_note_most_features_offline_stats_ai': return '提示：大部分功能（离线/统计/AI 总结/导出）无需后端改动，但 Token 只返回一次，请妥善保存。';
			case 'strings.legacy.msg_fixed': return '修复：';
			case 'strings.legacy.msg_allow_sharing_links_images_other_apps': return '允许从其他应用分享链接或图片到 MemoFlow。';
			case 'strings.legacy.msg_invalid_request_parameters': return '请求参数错误';
			case 'strings.legacy.msg_enter_api_url': return '请输入 API URL';
			case 'strings.legacy.msg_pending': return ({required Object result_pendingCount}) => '（待发送 ${result_pendingCount}）';
			case 'strings.legacy.msg_days_3': return ({required Object currentStreak}) => '${currentStreak} 天';
			case 'strings.legacy.msg_poster_not_ready_yet': return '暂时无法生成海报';
			case 'strings.legacy.msg_generated_memoflow': return '由 MemoFlow 生成';
			case 'strings.legacy.msg_enter_name_2': return '请输入名称';
			case 'strings.legacy.msg_version': return '版本';
			case 'strings.legacy.msg_memo_missing_disk_but_has_local': return '磁盘缺失该笔记，但本地还有未同步改动。选择“以磁盘为准”将删除本地记录。';
			case 'strings.legacy.msg_legacy_api_compatibility': return '旧版 API 兼容';
			case 'strings.legacy.msg_sync_parameters': return '同步参数';
			case 'strings.legacy.msg_quick_prompts': return '快速提示词';
			case 'strings.legacy.msg_share_failed': return ({required Object e}) => '分享失败：${e}';
			case 'strings.legacy.msg_no_memos_summarize_range': return '该时间范围内没有可总结的笔记';
			case 'strings.legacy.msg_characters': return '字数';
			case 'strings.legacy.msg_capture_every_moment_record': return '记录每一个瞬间';
			case 'strings.legacy.msg_vibration': return '震动';
			case 'strings.legacy.msg_days_4': return '天';
			case 'strings.legacy.msg_prompt_title': return '提示词标题';
			case 'strings.legacy.msg_show_all': return '展开';
			case 'strings.legacy.msg_no_memos_available': return '暂无可关联的笔记';
			case 'strings.legacy.msg_comment_unavailable': return '评论内容不可用';
			case 'strings.legacy.msg_refresh': return '刷新';
			case 'strings.legacy.msg_syncing_2': return '同步中';
			case 'strings.legacy.msg_body': return '通知正文';
			case 'strings.legacy.msg_clear_2': return '清除';
			case 'strings.legacy.msg_third_party_share': return '第三方分享';
			case 'strings.legacy.msg_charging_station': return '充电站';
			case 'strings.legacy.msg_attachments_2': return '附件资源';
			case 'strings.legacy.msg_when_enabled_must_verify_each_app': return '开启后每次进入应用需要验证。自动锁定时间决定应用进入后台后多久需要再次验证。';
			case 'strings.legacy.msg_add_prompt': return '添加提示词';
			case 'strings.legacy.msg_include': return '包含';
			case 'strings.legacy.msg_created_time_2': return '创建时间 ↓';
			case 'strings.legacy.msg_choose_data_source_start_importing_memos': return '选择一个数据来源开始导入您的笔记';
			case 'strings.legacy.msg_describe_how_want_summary': return '请分析我本周笔记中体现的情绪波动曲线…';
			case 'strings.legacy.msg_keep_token_safe_not_share_api': return '请妥善保存 Token，不要泄露。\\nAPI 访问频率限制为每分钟 60 次。';
			case 'strings.legacy.msg_open_2': return '去开启';
			case 'strings.legacy.msg_e_g_claude_3_5_sonnet': return '例如 claude-3-5-sonnet-20241022';
			case 'strings.legacy.msg_failed_request_whitelist': return '无法申请电池白名单';
			case 'strings.legacy.msg_notification_deleted': return '通知已删除';
			case 'strings.legacy.msg_accounts': return '账号';
			case 'strings.legacy.msg_add_local_library': return '添加本地库';
			case 'strings.legacy.msg_sign_first': return '请先登录';
			case 'strings.legacy.msg_failed_parse_query': return 'Query 解析失败';
			case 'strings.legacy.msg_note_logs_sanitized_automatically_sensitive_data': return '提示：日志已自动去除敏感信息，如仍包含敏感数据，请提交前自行处理。';
			case 'strings.legacy.msg_add': return '新增';
			case 'strings.legacy.msg_failed_load_3': return ({required Object memosError}) => '加载失败：${memosError}';
			case 'strings.legacy.msg_max_chars_day': return '单日最多字数';
			case 'strings.legacy.msg_choose_what_edited_image': return '请选择要执行的操作';
			case 'strings.legacy.msg_select': return '请选择';
			case 'strings.legacy.msg_unnamed_token': return '(未命名 Token)';
			case 'strings.legacy.msg_name': return '筛选名称';
			case 'strings.legacy.msg_sure_want_delete_webhook': return '确定要删除该 Webhook 吗？';
			case 'strings.legacy.msg_back': return '返回';
			case 'strings.legacy.msg_no': return '否';
			case 'strings.legacy.msg_untitled': return '未命名';
			case 'strings.legacy.msg_open_language_onboarding': return '打开语言首次设置';
			case 'strings.legacy.msg_voice_memos': return '语音备忘';
			case 'strings.legacy.msg_unable_open_browser_try': return '无法打开浏览器，请稍后重试';
			case 'strings.legacy.msg_date_range': return '时间范围';
			case 'strings.legacy.msg_not_authenticated': return '未登录';
			case 'strings.legacy.msg_back_2': return 'Back';
			case 'strings.legacy.msg_local_library_removed': return '本地库已移除';
			case 'strings.legacy.msg_exact_alarm_permission_required': return '需要闹钟与提醒权限';
			case 'strings.legacy.msg_visibility': return '可见性';
			case 'strings.legacy.msg_failed_start_recording': return ({required Object e}) => '启动录音失败：${e}';
			case 'strings.legacy.msg_mood_trend': return '情緒趨勢';
			case 'strings.legacy.msg_local_library_name': return '本地库名称';
			case 'strings.legacy.msg_no_tokens_yet': return '暂无 Token';
			case 'strings.legacy.msg_loading_2': return '加载中…';
			case 'strings.legacy.msg_location_permission_denied_permanently': return '定位权限被永久拒绝';
			case 'strings.legacy.msg_download': return '下载';
			case 'strings.legacy.msg_export_time': return '- 匯出時間';
			case 'strings.legacy.msg_enter_password_2': return '请输入密码';
			case 'strings.legacy.msg_no_image_available': return '没有可显示的图片';
			case 'strings.legacy.msg_daily': return '每天';
			case 'strings.legacy.msg_no_likes_yet': return '暂无点赞';
			case 'strings.legacy.msg_basics': return '基础配置';
			case 'strings.legacy.msg_shortcut': return '新建快捷筛选';
			case 'strings.legacy.msg_debug_tools': return '调试工具';
			case 'strings.legacy.msg_save_settings': return '保存设置';
			case 'strings.legacy.msg_date_range_2': return '日期范围';
			case 'strings.legacy.msg_feedback': return '反馈';
			case 'strings.legacy.msg_image_bed_2': return '图床';
			case 'strings.legacy.msg_restoring': return '恢复中…';
			case 'strings.legacy.msg_export': return '导出';
			case 'strings.legacy.msg_enter_token_name': return '请输入 Token 名称';
			case 'strings.legacy.msg_start_time': return '开始时间';
			case 'strings.legacy.msg_preparing_file_structure': return '正在准备文件结构';
			case 'strings.legacy.msg_sign_3': return '登录';
			case 'strings.legacy.msg_scan_local_library': return '扫描本地库';
			case 'strings.legacy.msg_lsky_pro': return '兰空图床 (Lsky Pro)';
			case 'strings.legacy.msg_exact_alarm_permission_off_reminders_may': return '未开启闹钟与提醒权限，定时提醒可能无法触发。是否前往开启？';
			case 'strings.legacy.msg_last_30_days': return '最近一月';
			case 'strings.legacy.msg_match': return '匹配方式';
			case 'strings.legacy.msg_auth_mode': return '认证方式';
			case 'strings.legacy.msg_unsupported_file_type': return '不支持的文件格式';
			case 'strings.legacy.msg_only_delete_sync_task': return '仅删除同步任务。';
			case 'strings.legacy.msg_change_password': return '修改密码';
			case 'strings.legacy.msg_saved_2': return '已保存';
			case 'strings.legacy.msg_import_export': return '导入 / 导出';
			case 'strings.legacy.msg_created_2': return '创建时间';
			case 'strings.legacy.msg_ai_summary': return 'AI 总结';
			case 'strings.legacy.msg_progress': return '完成進度';
			case 'strings.legacy.msg_replace_memo_image': return '替换笔记图片';
			case 'strings.legacy.msg_app_settings': return '应用设置';
			case 'strings.legacy.msg_copy_path': return '复制路径';
			case 'strings.legacy.msg_components': return '功能组件';
			case 'strings.legacy.msg_no_shortcuts': return '暂无快捷筛选';
			case 'strings.legacy.msg_location_timed_try': return '定位超时，请重试';
			case 'strings.legacy.msg_attach_location_info_memos_show_subtle': return '为笔记记录定位信息，并展示简洁地名。';
			case 'strings.legacy.msg_send_failed': return ({required Object e}) => '发送失败：${e}';
			case 'strings.legacy.msg_repeat': return '重复';
			case 'strings.legacy.msg_not_signed': return '未登录';
			case 'strings.legacy.msg_no_webhooks_configured': return '暂无 Webhooks';
			case 'strings.legacy.msg_apply_token': return '应用 Token';
			case 'strings.legacy.msg_enable_reminder_permissions_2': return '开启提醒权限';
			case 'strings.legacy.msg_enter_backup_password': return '请输入备份密码';
			case 'strings.legacy.msg_start_backup': return '开始备份';
			case 'strings.legacy.msg_last_sync': return '上次同步';
			case 'strings.legacy.msg_note_export_includes_content_already_synced': return '提示：导出包含已同步到本地数据库的内容（含离线数据）。';
			case 'strings.legacy.msg_enter_username': return '请输入用户名';
			case 'strings.legacy.msg_settings_saved': return '设置已保存';
			case 'strings.legacy.msg_no_keywords': return '暂无关键词';
			case 'strings.legacy.msg_these_settings_apply_newly_created_memos': return '此设置将应用于新建的 Memo。';
			case 'strings.legacy.msg_back_home': return '返回主页';
			case 'strings.legacy.msg_quiet_hours': return '休息时间';
			case 'strings.legacy.msg_add_account': return '添加账号';
			case 'strings.legacy.msg_reset_complete': return '已重置';
			case 'strings.legacy.msg_no_shortcuts_configured': return '暂无快捷筛选';
			case 'strings.legacy.msg_password': return '密码';
			case 'strings.legacy.msg_importing': return '导入中';
			case 'strings.legacy.msg_visibility_2': return ({required Object visibilityLabel}) => '可见性：${visibilityLabel}';
			case 'strings.legacy.msg_no_logs_yet': return '暂无记录';
			case 'strings.legacy.msg_v_9_times_allowed': return '最多设置 9 个提醒时间';
			case 'strings.legacy.msg_last_14_days': return '最近 14 天';
			case 'strings.legacy.msg_location_disabled_enable_settings_first': return '定位未启用，请先在设置中开启。';
			case 'strings.legacy.msg_add_2': return '添加';
			case 'strings.legacy.msg_logs': return '日志';
			case 'strings.legacy.msg_references': return '引用了';
			case 'strings.legacy.msg_importing_memos': return '正在导入笔记...';
			case 'strings.legacy.msg_account_security': return '账号与安全';
			case 'strings.legacy.msg_reminder_2': return '提醒设置';
			case 'strings.legacy.msg_enable_scheduled_reminder_notifications': return '开启后将按计划发送笔记提醒通知。';
			case 'strings.legacy.msg_no_links': return '暂无双链';
			case 'strings.legacy.msg_delete_memo_2': return '删除笔记';
			case 'strings.legacy.msg_one_tap_add_not_supported_add': return '不支持一键添加，请从小组件列表添加';
			case 'strings.legacy.msg_password_2': return '新密码';
			case 'strings.legacy.msg_processing_content': return '正在处理内容...';
			case 'strings.legacy.msg_status': return '状态';
			case 'strings.legacy.msg_local_library_added': return '本地库已添加';
			case 'strings.legacy.msg_failed_open_try': return '打开失败，请稍后重试';
			case 'strings.legacy.msg_removed_locally_now_deleted_server_when': return '本地会立即移除，联网后将同步删除服务器内容。';
			case 'strings.legacy.msg_server_url_unavailable': return '未找到服务器地址';
			case 'strings.legacy.msg_no_release_notes_yet': return '暂无更新日志';
			case 'strings.legacy.msg_cancelling_2': return '正在取消...';
			case 'strings.legacy.msg_summaries_selected_range': return '支持按时间范围总结';
			case 'strings.legacy.msg_expand_2': return '展开更多';
			case 'strings.legacy.msg_close': return '关闭';
			case 'strings.legacy.msg_more_comments': return ({required Object remainingComments}) => '还有 ${remainingComments} 条评论';
			case 'strings.legacy.msg_backing': return '备份中…';
			case 'strings.legacy.msg_view_debug_logs': return '查看调试记录';
			case 'strings.legacy.msg_location_permission_denied': return '定位权限被拒绝';
			case 'strings.legacy.msg_self_repair_reset_heatmap': return '自助修复：重置热力图';
			case 'strings.legacy.msg_these_settings_changed_locally_remotely_choose': return '以下设置在本地和远端都有修改，请选择保留哪个版本。';
			case 'strings.legacy.msg_not_authenticated_2': return '未登录账号';
			case 'strings.legacy.msg_action_failed': return ({required Object e}) => '操作失败：${e}';
			case 'strings.legacy.msg_shortcut_2': return '新建快捷筛选';
			case 'strings.legacy.msg_url': return 'URL';
			case 'strings.legacy.msg_no_memos_found_html': return 'HTML 内未找到可导入的内容';
			case 'strings.legacy.msg_enter_what_want_summarize': return '输入你想总结的内容或指令...';
			case 'strings.legacy.msg_unable_load_audio_source': return '无法读取音频资源';
			case 'strings.legacy.msg_strategy_id': return '策略 ID';
			case 'strings.legacy.msg_copy_failed': return ({required Object e}) => '复制失败：${e}';
			case 'strings.legacy.msg_enable_image_bed': return '启用图床';
			case 'strings.legacy.msg_active': return '有效';
			case 'strings.legacy.msg_account': return '账号';
			case 'strings.legacy.msg_invalid_webdav_server_url': return 'WebDAV 服务器地址无效';
			case 'strings.legacy.msg_keep_local': return '以本地为准';
			case 'strings.legacy.msg_within_range': return '在时间范围内';
			case 'strings.legacy.msg_generate_log_file': return '生成日志文件';
			case 'strings.legacy.msg_ai_reports': return 'AI 总结';
			case 'strings.legacy.msg_battery_optimization': return '电池优化';
			case 'strings.legacy.msg_sync_overview': return '同步概览';
			case 'strings.legacy.msg_legacy_servers_not_support_search_filters': return '旧版本服务器不支持搜索过滤，结果可能不完整。';
			case 'strings.legacy.msg_conflicts_detected_run_manual_sync': return '存在冲突，需要手动同步';
			case 'strings.legacy.msg_authentication_failed_check_token': return '认证失败，请检查 Token';
			case 'strings.legacy.msg_date_range_3': return '时间范围';
			case 'strings.legacy.msg_help_ai_understand_better': return '帮助 AI 更了解你';
			case 'strings.legacy.msg_no_search_history': return '暂无搜索记录';
			case 'strings.legacy.msg_enter_api_path': return '请输入接口路径';
			case 'strings.legacy.msg_stats': return '统计';
			case 'strings.legacy.msg_text_2': return '新增：';
			case 'strings.legacy.msg_removing_signing_clear_local_cache_account': return '移除/退出将清除该账号的本地缓存（离线数据/草稿/待同步队列）。';
			case 'strings.legacy.msg_updated_time_2': return '修改时间 ↑';
			case 'strings.legacy.msg_province': return '省';
			case 'strings.legacy.msg_submitting_sync_queue': return '正在提交同步队列';
			case 'strings.legacy.msg_failed': return '失败';
			case 'strings.legacy.msg_set_time': return '设置时间';
			case 'strings.legacy.msg_enable_local_library_backup': return '启用本地库备份';
			case 'strings.legacy.msg_cancel_2': return '取消';
			case 'strings.legacy.msg_week': return '本周回顾';
			case 'strings.legacy.msg_like': return '赞';
			case 'strings.legacy.msg_location_services_disabled': return '定位服务未开启';
			case 'strings.legacy.msg_clears_local_cache_offline_memos_pending': return '这会清空本地缓存（离线笔记/待同步队列）并重新全量同步。未同步内容会丢失，可能需要一些时间。是否继续？';
			case 'strings.legacy.msg_load_more': return '加载更多';
			case 'strings.legacy.msg_pull_memo_list_refresh_sync_sync': return '在笔记列表下拉即可刷新并同步。同步会优先拉取最新内容；建议定期全量同步以保持统计/热力图完整。';
			case 'strings.legacy.msg_server_returned_error': return ({required Object code}) => '服务返回错误（${code}）';
			case 'strings.legacy.msg_sound_feedback': return '声音与反馈';
			case 'strings.legacy.msg_memos_skipped_attachments_skipped': return ({required Object exportedMemoCount, required Object skippedMemoCount, required Object exportedAttachmentCount, required Object skippedAttachmentCount}) => '笔记 ${exportedMemoCount} 条（跳过 ${skippedMemoCount} 条），附件 ${exportedAttachmentCount} 个（跳过 ${skippedAttachmentCount} 个）';
			case 'strings.legacy.msg_import_complete': return '导入完成';
			case 'strings.legacy.msg_text_3': return '新增';
			case 'strings.legacy.msg_max_per_day': return '单日最多条数';
			case 'strings.legacy.msg_permissions_denied': return '权限未授予';
			case 'strings.legacy.msg_memo_2': return '新建 Memo';
			case 'strings.legacy.msg_delete_reminder': return '删除提醒';
			case 'strings.legacy.msg_select_month': return '选择月份';
			case 'strings.legacy.msg_select_backup': return '选择备份';
			case 'strings.legacy.msg_no_keywords_2': return '#暂无关键词';
			case 'strings.legacy.msg_preparing_memo_content': return '正在准备笔记内容';
			case 'strings.legacy.msg_prompt_content': return '具体指令内容';
			case 'strings.legacy.msg_default_prompt_ai_summaries_reports': return '用于 AI 总结/报告的默认提示词';
			case 'strings.legacy.msg_intro': return '引言';
			case 'strings.legacy.msg_monthly_stats': return '每月统计';
			case 'strings.legacy.msg_times_2': return '次';
			case 'strings.legacy.msg_file_has_already_been_imported_skipped': return '该文件已导入过，已跳过';
			case 'strings.legacy.msg_token_tail_unknown': return 'Token 尾号未知';
			case 'strings.legacy.msg_press_back_exit': return '再按一次返回退出';
			case 'strings.legacy.msg_enter_password_3': return '输入密码';
			case 'strings.legacy.msg_sync_conflicts': return '同步冲突';
			case 'strings.legacy.msg_locale': return '语言';
			case 'strings.legacy.msg_any': return '包含任一';
			case 'strings.legacy.msg_provider': return '服务商';
			case 'strings.legacy.msg_preview_2': return '预览效果';
			case 'strings.legacy.msg_automatically_upload_images_append_links_memo': return '开启后自动上传图片并在正文末尾插入链接。';
			case 'strings.legacy.msg_import_file_not_found': return '找不到导入文件';
			case 'strings.legacy.msg_today': return '今天';
			case 'strings.legacy.msg_link_card': return '关联卡片';
			case 'strings.legacy.msg_expiration': return '有效期';
			case 'strings.legacy.msg_summary_prompt_optional': return '总结指令 (可选)';
			case 'strings.legacy.msg_memos': return '笔记';
			case 'strings.legacy.msg_recording_file_not_found_2': return '录音文件不存在';
			case 'strings.legacy.msg_backup_settings': return '备份设置';
			case 'strings.legacy.msg_mode': return '提醒模式';
			case 'strings.legacy.msg_no_markdown_memos_found_zip': return '压缩包内未找到 Markdown 笔记';
			case 'strings.legacy.msg_archived': return '已归档';
			case 'strings.legacy.msg_update_failed': return ({required Object e}) => '更新失败：${e}';
			case 'strings.legacy.msg_enable_app_lock': return '启用应用锁';
			case 'strings.legacy.msg_html_zip': return 'HTML / ZIP';
			case 'strings.legacy.msg_all': return '包含全部';
			case 'strings.legacy.msg_model': return '模型';
			case 'strings.legacy.msg_title': return '通知标题';
			case 'strings.legacy.msg_amap_web_api': return '高德 Web API';
			case 'strings.legacy.msg_saved_gallery': return '已保存到相册';
			case 'strings.legacy.msg_unread': return '未读';
			case 'strings.legacy.msg_exporting': return '正在导出...';
			case 'strings.legacy.msg_network_timeout_try': return '网络超时，请稍后重试';
			case 'strings.legacy.msg_unlock': return '解锁';
			case 'strings.legacy.msg_ago_3': return ({required Object diff_inDays}) => '${diff_inDays}天前';
			case 'strings.legacy.msg_deserve_coffee_i_m_pulling_all': return '为了对得起这杯咖啡，今晚我决定不睡了，写它个一百行代码！';
			case 'strings.legacy.msg_token_name': return 'Token 名称';
			case 'strings.legacy.msg_restore_completed': return '恢复完成';
			case 'strings.legacy.msg_copied_clipboard': return '已复制到剪贴板';
			case 'strings.legacy.msg_failed_2': return ({required Object attempts}) => '失敗 ${attempts}次';
			case 'strings.legacy.msg_too_many_requests_try_later': return '请求过于频繁，请稍后重试';
			case 'strings.legacy.msg_more': return '更多';
			case 'strings.legacy.msg_already_whitelisted': return '已在电池白名单';
			case 'strings.legacy.msg_local_library_backup': return '本地库备份';
			case 'strings.legacy.msg_awesome': return '太棒啦！ ❤️';
			case 'strings.legacy.msg_now': return '现在';
			case 'strings.legacy.msg_select_reminder_time': return '请设置提醒时间';
			case 'strings.legacy.msg_protected': return '受保护';
			case 'strings.legacy.msg_failed_load_4': return ({required Object e}) => '加载失败：${e}';
			case 'strings.legacy.msg_operation_failed': return ({required Object e}) => '操作失败：${e}';
			case 'strings.legacy.msg_no_tags': return '暂无标签';
			case 'strings.legacy.msg_server': return '服务器';
			case 'strings.legacy.msg_improved': return '优化';
			case 'strings.legacy.msg_request_2': return '请求';
			case 'strings.legacy.msg_export_failed': return ({required Object e}) => '导出失败：${e}';
			case 'strings.legacy.msg_notification_settings': return '通知设置';
			case 'strings.legacy.msg_related_memo_was_deleted': return '通知对应的内容已被删除';
			case 'strings.legacy.msg_email': return '邮箱';
			case 'strings.legacy.msg_enter_password_4': return '请输入密码';
			case 'strings.legacy.msg_retry_count': return '失败重试次数';
			case 'strings.legacy.msg_import_exported_html_zip_package': return '导入导出的 HTML 或压缩包';
			case 'strings.legacy.msg_archive': return '归档';
			case 'strings.legacy.msg_reset_heatmap': return '重置热力图？';
			case 'strings.legacy.msg_token_applied': return 'Token 已应用';
			case 'strings.legacy.msg_log_file_created': return '日志文件已生成';
			case 'strings.legacy.msg_delete_sync_task': return '删除同步任务';
			case 'strings.legacy.msg_include_archived_2': return '- 包含歸檔';
			case 'strings.legacy.msg_memoflow_side_project_i_build_my': return 'MemoFlow 是我用业余时间肝出来的孩子。目前开发者已连续熬夜修 Bug，急需一杯冰美式“续命”。你的投喂不仅能恢复我的电量，还能让新功能提早 ';
			case 'strings.legacy.msg_failed_generate': return ({required Object e}) => '生成失败：${e}';
			case 'strings.legacy.msg_search_logs': return '搜索内容';
			case 'strings.legacy.msg_active_days': return '累计天数';
			case 'strings.legacy.msg_back_top': return '回到顶部';
			case 'strings.legacy.msg_month': return '本月回顾';
			case 'strings.legacy.msg_loading_references': return '正在加载引用';
			case 'strings.legacy.msg_silent': return '静音';
			case 'strings.legacy.msg_settings': return '设置';
			case 'strings.legacy.msg_locating': return '正在定位…';
			case 'strings.legacy.msg_scan': return '扫描';
			case 'strings.legacy.msg_recording_path_missing': return '录音路径缺失';
			case 'strings.legacy.msg_date_range_4': return '- 時間範圍';
			case 'strings.legacy.msg_suggested_tags': return '推荐标签';
			case 'strings.legacy.msg_energy_restored': return '⚡ ENERGY RESTORED';
			case 'strings.legacy.msg_username_2': return '账号';
			case 'strings.legacy.msg_ai_summary_report': return 'AI 总结报告';
			case 'strings.legacy.msg_all_tags': return '全部标签';
			case 'strings.legacy.msg_preferences': return '偏好设置';
			case 'strings.legacy.msg_image_bed_3': return '图床设置';
			case 'strings.legacy.msg_quick_input': return '快速输入';
			case 'strings.legacy.msg_tags': return '标签';
			case 'strings.legacy.msg_energy_critically_low': return '能量值告急！';
			case 'strings.legacy.msg_delete_failed': return ({required Object e}) => '删除失败：${e}';
			case 'strings.legacy.msg_server_login': return '服务端登录';
			case 'strings.legacy.msg_like_2': return '点赞';
			case 'strings.legacy.msg_save_2': return '确定';
			case 'strings.legacy.msg_unknown': return '未知用户';
			case 'strings.legacy.msg_release_notes_2': return '更新日志';
			case 'strings.legacy.msg_include_error_details': return '包含错误详情';
			case 'strings.legacy.msg_write_comment': return '写下评论...';
			case 'strings.legacy.msg_write_thoughts': return '写下你的想法...';
			case 'strings.legacy.msg_local_2': return '本地';
			case 'strings.legacy.msg_expired': return '已过期';
			case 'strings.legacy.msg_fixed_2': return '修复';
			case 'strings.legacy.msg_upload_attachment': return '上传附件';
			case 'strings.legacy.msg_battery_whitelist': return '电池白名单';
			case 'strings.legacy.msg_district': return '区';
			case 'strings.legacy.msg_voice_memo': return '🎙️ 语音记录\\n';
			case 'strings.legacy.msg_system_default': return '系统默认';
			case 'strings.legacy.msg_all_memos_2': return '全部笔记';
			case 'strings.legacy.msg_network_request_failed': return '网络请求失败';
			case 'strings.legacy.msg_memo_not_found': return '笔记不存在';
			case 'strings.legacy.msg_playback_failed_2': return ({required Object e}) => '播放失败：${e}';
			case 'strings.legacy.msg_sync_settings_webdav_across_devices': return '将设置同步到 WebDAV，在设备之间保持一致。';
			case 'strings.legacy.msg_offline_first_client_memos_backend': return '一个基于 Memos 后端的离线优先客户端。';
			case 'strings.legacy.msg_user_guide': return '使用指南';
			case 'strings.legacy.msg_notice': return '通知';
			case 'strings.legacy.msg_exact_alarms': return '闹钟与提醒';
			case 'strings.legacy.msg_restoring_overwrite_local_library_files_rebuild': return '恢复会覆盖本地库文件，并重新导入数据库。此操作无法撤销。';
			case 'strings.legacy.msg_enter_api_url_ai_settings': return '请先在 AI 设置中填写 API URL';
			case 'strings.legacy.msg_create_failed_2': return ({required Object e}) => '创建失败：${e}';
			case 'strings.legacy.msg_close_search': return '关闭搜索';
			case 'strings.legacy.msg_imported_memos_2': return '查看导入笔记';
			case 'strings.legacy.msg_explore': return '探索';
			case 'strings.legacy.msg_network_connection_failed': return '网络连接失败，请检查网络';
			case 'strings.legacy.msg_save_failed_3': return ({required Object e}) => '保存失败：${e}';
			case 'strings.legacy.msg_no_summary_share': return '暂无可分享的总结';
			case 'strings.legacy.msg_custom_model': return '自定义模型';
			case 'strings.legacy.msg_sign_failed': return ({required Object message}) => '登录失败: ${message}';
			case 'strings.legacy.msg_notification_exact_alarm_permissions_required_send': return '需要通知权限与精确闹钟权限，才能在指定时间发送提醒。';
			case 'strings.legacy.msg_random_review': return '随机漫步';
			case 'strings.legacy.msg_public': return '公开';
			case 'strings.legacy.msg_all_2': return '全部';
			case 'strings.legacy.msg_add_custom_model': return '添加自定义模型';
			case 'strings.legacy.msg_backup_password': return '备份密码';
			case 'strings.legacy.msg_optional_used_sign_requests': return '选填，用于签名请求';
			case 'strings.legacy.msg_search': return '搜索';
			case 'strings.legacy.msg_set_password': return '设置密码';
			case 'strings.legacy.msg_submit_logs': return '提交日志';
			case 'strings.legacy.msg_activity_heatmap_2': return '记录热力图';
			case 'strings.legacy.msg_invalid_api_key_insufficient_permissions': return 'API Key 无效或无权限';
			case 'strings.legacy.msg_data_has_been_migrated_app_successfully': return '您的数据已成功迁移至本应用。';
			case 'strings.legacy.msg_get_version': return '立即获取新版本';
			case 'strings.legacy.msg_token_source': return 'Token 来源';
			case 'strings.legacy.msg_send': return '发送';
			case 'strings.legacy.msg_no_pending_sync_tasks': return '暂无待同步任务';
			case 'strings.legacy.msg_locating_memo_content': return '正在定位笔记内容';
			case 'strings.legacy.msg_offline_ready': return '离线可用';
			case 'strings.legacy.msg_use_relative_path': return '请使用相对路径';
			case 'strings.legacy.msg_total': return '总记录';
			case 'strings.legacy.msg_location_2': return '定位';
			case 'strings.legacy.msg_show_location_metadata_memos_not_configured': return '在笔记中显示定位信息，未配置密钥时将仅显示经纬度。';
			case 'strings.legacy.msg_api_url': return 'API 地址';
			case 'strings.legacy.msg_parsing_progress': return '解析进度';
			case 'strings.legacy.msg_parsing': return '解析中';
			case 'strings.legacy.msg_custom': return '自定义';
			case 'strings.legacy.msg_tags_created': return '新生成的标签';
			case 'strings.legacy.msg_third_party_share_disabled': return '第三方分享未开启';
			case 'strings.legacy.msg_loading_links': return '双链加载中';
			case 'strings.legacy.msg_how_report': return '如何反馈？';
			case 'strings.legacy.msg_confirm_password_2': return '再次输入确认';
			case 'strings.legacy.msg_search_title_content_tags': return '您可以搜索标题、内容或标签';
			case 'strings.legacy.msg_reset_failed': return ({required Object e}) => '重置失败：${e}';
			case 'strings.legacy.msg_debug_preview_update_dialog': return '调试：预览更新公告';
			case 'strings.legacy.msg_what_s': return '写点什么…';
			case 'strings.legacy.msg_ringtone': return '提醒铃声';
			case 'strings.legacy.msg_unable_detect_backend_version_check_server': return '无法识别后端版本，请检查地址或网络';
			case 'strings.legacy.msg_pending_2': return '待同步';
			case 'strings.legacy.msg_parsing_html': return '正在解析 HTML...';
			case 'strings.legacy.msg_actions': return '操作';
			case 'strings.legacy.msg_import_complete_2': return '导入完成';
			case 'strings.legacy.msg_use_disk': return '以磁盘为准';
			case 'strings.legacy.msg_root_path': return '根路径';
			case 'strings.legacy.msg_disabled': return '未启用';
			case 'strings.legacy.msg_improved_2': return '优化：';
			case 'strings.legacy.msg_city': return '市';
			case 'strings.legacy.msg_decoding_zip': return '正在解压 ZIP...';
			case 'strings.legacy.msg_notification_content': return '通知内容';
			case 'strings.legacy.msg_resolve_conflict': return '冲突处理';
			case 'strings.legacy.msg_webhooks_not_supported_server': return '当前服务器不支持 Webhooks';
			case 'strings.legacy.msg_may_delayed': return '（可能延迟）';
			case 'strings.legacy.msg_permissions_system_settings': return '权限与系统设置';
			case 'strings.legacy.msg_waiting_tasks_stop': return '正在等待任务停止';
			case 'strings.legacy.msg_done_2': return '确定';
			case 'strings.legacy.msg_parsing_memoflow_export': return '正在解析 MemoFlow 导出...';
			case 'strings.legacy.msg_location_updated': return ({required Object next_displayText_fractionDigits_6}) => '定位成功：${next_displayText_fractionDigits_6}';
			case 'strings.legacy.msg_checking_server_version': return '正在检查后端版本...';
			case 'strings.legacy.msg_next_time_back_fixing_bugs': return '👀 下次一定，先去修 Bug';
			case 'strings.legacy.msg_ago_4': return ({required Object weeks}) => '${weeks}週前';
			case 'strings.legacy.msg_import': return '导入';
			case 'strings.legacy.msg_ios_long_press_home_screen_add': return 'iOS 请长按桌面添加 MemoFlow 小组件';
			case 'strings.legacy.msg_create_token_2': return '创建 Token';
			case 'strings.legacy.msg_marked_read': return '已标记为已读';
			case 'strings.legacy.msg_pinned': return '置顶';
			case 'strings.legacy.msg_version_update': return '版本更新';
			case 'strings.legacy.msg_allow_private_memos': return '允许发送私有权限笔记';
			case 'strings.legacy.msg_token_copied_clipboard': return 'Token 已复制到剪贴板';
			case 'strings.legacy.msg_keeping_more_versions_uses_more_storage': return '增加保留数量会占用更多存储空间，建议定期清理旧版本。';
			case 'strings.legacy.msg_delete_webhook': return '删除 Webhook';
			case 'strings.legacy.msg_prompt': return '提示词 (Prompt)';
			case 'strings.legacy.msg_location_precision': return '定位精度';
			case 'strings.legacy.msg_password_required': return '需要密码';
			case 'strings.legacy.msg_exit_app': return '退出应用';
			case 'strings.legacy.msg_thanks_energy_fully_restored': return '收到心意！能量已充满 ⚡';
			case 'strings.legacy.msg_connection_timeout_check_network_api_url': return '连接超时，请检查网络或 API URL';
			case 'strings.legacy.app_language.system': return '跟隨系統';
			case 'strings.legacy.app_language.zh_hans': return '簡體中文';
			case 'strings.legacy.app_language.zh_hant_tw': return '繁體中文（中國台灣）';
			case 'strings.legacy.app_language.en': return '英語';
			case 'strings.legacy.app_language.ja': return '日語';
			case 'strings.legacy.app_language.de': return '德語';
			case 'strings.legacy.app_theme.system': return '系統';
			case 'strings.legacy.app_theme.light': return '淺色';
			case 'strings.legacy.app_theme.dark': return '深色';
			case 'strings.legacy.app_font_size.standard': return '標準';
			case 'strings.legacy.app_font_size.large': return '大';
			case 'strings.legacy.app_font_size.small': return '小';
			case 'strings.legacy.app_line_height.classic': return '經典';
			case 'strings.legacy.app_line_height.compact': return '緊湊';
			case 'strings.legacy.app_line_height.relaxed': return '舒適';
			case 'strings.legacy.launch_action.none': return '無';
			case 'strings.legacy.launch_action.sync': return '同步';
			case 'strings.legacy.launch_action.quick_input': return '快速記錄';
			case 'strings.legacy.launch_action.daily_review': return '隨機漫步';
			case 'strings.legacy.auto_lock_time.immediately': return '立即';
			case 'strings.legacy.auto_lock_time.after_1_min': return '1 分鐘';
			case 'strings.legacy.auto_lock_time.after_5_min': return '5 分鐘';
			case 'strings.legacy.auto_lock_time.after_15_min': return '15 分鐘';
			case 'strings.legacy.reminder.default_title': return '嗨，你還記得這個想法嗎？';
			case 'strings.legacy.reminder.default_body': return '點擊查看詳情';
			case 'strings.legacy.location.current': return '當前位置';
			case 'strings.legacy.webdav.not_configured': return 'WebDAV 未設定';
			case 'strings.legacy.webdav.backup_disabled': return '備份未啟用';
			case 'strings.legacy.webdav.backup_account_missing': return '帳號缺失，無法備份';
			case 'strings.legacy.webdav.backup_local_only': return '僅本地庫可用備份';
			case 'strings.legacy.webdav.backup_password_missing': return '缺少備份密碼';
			case 'strings.legacy.webdav.backup_no_memo_files': return '本地庫未發現筆記檔案，備份已取消';
			case 'strings.legacy.webdav.restore_account_missing': return '帳號缺失，無法恢復';
			case 'strings.legacy.webdav.restore_local_only': return '僅本地庫可恢復備份';
			case 'strings.legacy.webdav.backup_empty': return '備份內容為空';
			case 'strings.legacy.webdav.backup_no_memos': return '備份中沒有筆記';
			case 'strings.legacy.webdav.snapshot_missing': return '備份快照遺失';
			case 'strings.legacy.webdav.snapshot_corrupted': return '備份快照損壞';
			case 'strings.legacy.webdav.object_missing': return '備份對象缺失';
			case 'strings.legacy.webdav.config_corrupted': return '備份配置損壞';
			case 'strings.legacy.webdav.config_invalid': return '備份配置無效';
			case 'strings.legacy.webdav.password_invalid': return '備份密碼錯誤';
			case 'strings.legacy.webdav.data_corrupted': return '備份資料損壞';
			case 'strings.legacy.webdav.server_url_invalid': return 'WebDAV 伺服器地址無效';
			case 'strings.legacy.import_count_memos': return ({required Object count}) => '${count}條';
			case 'strings.legacy.import_count_attachments': return ({required Object count}) => '${count}個';
			case 'strings.legacy.app_drawer.tooltip_single': return ({required Object date, required Object weekday, required Object count}) => '${date}（${weekday}）· ${count} 條';
			case 'strings.legacy.app_drawer.tooltip_multi': return ({required Object date, required Object weekday, required Object count}) => '${date}（${weekday}）· ${count} 條';
			case 'strings.legacy.ai_summary.error_api_key_empty': return 'API Key 為空';
			case 'strings.legacy.ai_summary.system.require_json': return '請嚴格輸出 JSON，不要使用程式碼區塊，不要額外說明文字。';
			case 'strings.legacy.ai_summary.system.json_format': return 'JSON 格式：{"insights":["..."],"moodTrend":"...","keywords":["#..."]}';
			case 'strings.legacy.ai_summary.system.insights_rule': return 'insights 控制在 2-5 條，keywords 為 4-8 個帶 # 的詞。';
			case 'strings.legacy.ai_summary.user.range': return ({required Object rangeLabel}) => '時間範圍：${rangeLabel}';
			case 'strings.legacy.ai_summary.user.counts': return ({required Object memoCount, required Object includedCount}) => '筆記條數：${memoCount}（提供用於總結：${includedCount}）';
			case 'strings.legacy.ai_summary.user.profile': return ({required Object profile}) => '用戶背景：${profile}';
			case 'strings.legacy.ai_summary.user.custom_prompt': return ({required Object customPrompt}) => '用戶補充指令：${customPrompt}';
			case 'strings.legacy.ai_summary.user.memo_content': return '筆記內容：';
			case 'strings.legacy.ai_summary.error_invalid_response': return 'AI 回應格式不正確';
			case 'strings.legacy.ai_summary.error_empty_response': return 'AI 回應為空';
			case 'strings.legacy.ai_summary.error_missing_content': return 'AI 回應內容缺失';
			case 'strings.legacy.ai_summary.default_prompt': return '你是一位極簡主義的筆記助手，擅長提煉核心觀點並以優雅的格式排版。在回覆時，請保持專業、溫和且簡潔的語氣。盡量使用列表和簡短的段落。';
			default: return null;
		}
	}
}
