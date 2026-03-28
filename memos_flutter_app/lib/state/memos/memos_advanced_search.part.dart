part of 'memos_providers.dart';

const Object _advancedSearchUnset = Object();

enum SearchToggleFilter { any, yes, no }

enum AdvancedAttachmentType { image, audio, document, other }

@immutable
class AdvancedSearchFilters {
  const AdvancedSearchFilters({
    this.createdDateRange,
    this.hasLocation = SearchToggleFilter.any,
    this.locationContains = '',
    this.hasAttachments = SearchToggleFilter.any,
    this.attachmentNameContains = '',
    this.attachmentType,
    this.hasRelations = SearchToggleFilter.any,
  });

  static const AdvancedSearchFilters empty = AdvancedSearchFilters();

  final DateTimeRange? createdDateRange;
  final SearchToggleFilter hasLocation;
  final String locationContains;
  final SearchToggleFilter hasAttachments;
  final String attachmentNameContains;
  final AdvancedAttachmentType? attachmentType;
  final SearchToggleFilter hasRelations;

  bool get isEmpty {
    final normalizedFilters = normalized();
    return normalizedFilters.createdDateRange == null &&
        normalizedFilters.hasLocation == SearchToggleFilter.any &&
        normalizedFilters.locationContains.isEmpty &&
        normalizedFilters.hasAttachments == SearchToggleFilter.any &&
        normalizedFilters.attachmentNameContains.isEmpty &&
        normalizedFilters.attachmentType == null &&
        normalizedFilters.hasRelations == SearchToggleFilter.any;
  }

  String get signature {
    final normalizedFilters = normalized();
    final range = normalizedFilters.createdDateRange;
    return [
      range?.start.millisecondsSinceEpoch ?? '',
      range?.end.millisecondsSinceEpoch ?? '',
      normalizedFilters.hasLocation.name,
      normalizedFilters.locationContains,
      normalizedFilters.hasAttachments.name,
      normalizedFilters.attachmentNameContains,
      normalizedFilters.attachmentType?.name ?? '',
      normalizedFilters.hasRelations.name,
    ].join('|');
  }

  AdvancedSearchFilters copyWith({
    Object? createdDateRange = _advancedSearchUnset,
    SearchToggleFilter? hasLocation,
    String? locationContains,
    SearchToggleFilter? hasAttachments,
    String? attachmentNameContains,
    Object? attachmentType = _advancedSearchUnset,
    SearchToggleFilter? hasRelations,
  }) {
    return AdvancedSearchFilters(
      createdDateRange: identical(createdDateRange, _advancedSearchUnset)
          ? this.createdDateRange
          : createdDateRange as DateTimeRange?,
      hasLocation: hasLocation ?? this.hasLocation,
      locationContains: locationContains ?? this.locationContains,
      hasAttachments: hasAttachments ?? this.hasAttachments,
      attachmentNameContains:
          attachmentNameContains ?? this.attachmentNameContains,
      attachmentType: identical(attachmentType, _advancedSearchUnset)
          ? this.attachmentType
          : attachmentType as AdvancedAttachmentType?,
      hasRelations: hasRelations ?? this.hasRelations,
    );
  }

  AdvancedSearchFilters normalized() {
    final trimmedLocationContains = locationContains.trim();
    final trimmedAttachmentNameContains = attachmentNameContains.trim();

    final normalizedRange = _normalizeDateRange(createdDateRange);
    var normalizedHasLocation = hasLocation;
    var normalizedLocationContains = trimmedLocationContains;
    var normalizedHasAttachments = hasAttachments;
    var normalizedAttachmentNameContains = trimmedAttachmentNameContains;
    var normalizedAttachmentType = attachmentType;

    if (normalizedHasLocation == SearchToggleFilter.no) {
      normalizedLocationContains = '';
    }

    if (normalizedHasAttachments == SearchToggleFilter.no) {
      normalizedAttachmentNameContains = '';
      normalizedAttachmentType = null;
    }

    return AdvancedSearchFilters(
      createdDateRange: normalizedRange,
      hasLocation: normalizedHasLocation,
      locationContains: normalizedLocationContains,
      hasAttachments: normalizedHasAttachments,
      attachmentNameContains: normalizedAttachmentNameContains,
      attachmentType: normalizedAttachmentType,
      hasRelations: hasRelations,
    );
  }

  bool matches(LocalMemo memo) {
    final filters = normalized();
    if (filters.isEmpty) return true;

    final createdRange = filters.createdDateRange;
    if (createdRange != null) {
      final created = memo.createTime;
      final start = _normalizeLocalDay(createdRange.start);
      final endExclusive = _normalizeLocalDay(
        createdRange.end,
      ).add(const Duration(days: 1));
      if (created.isBefore(start) || !created.isBefore(endExclusive)) {
        return false;
      }
    }

    switch (filters.hasLocation) {
      case SearchToggleFilter.any:
        break;
      case SearchToggleFilter.yes:
        if (memo.location == null) return false;
        break;
      case SearchToggleFilter.no:
        if (memo.location != null) return false;
        break;
    }

    if (filters.locationContains.isNotEmpty) {
      final locationText = (memo.location?.placeholder ?? '')
          .trim()
          .toLowerCase();
      if (locationText.isEmpty ||
          !locationText.contains(filters.locationContains.toLowerCase())) {
        return false;
      }
    }

    switch (filters.hasAttachments) {
      case SearchToggleFilter.any:
        break;
      case SearchToggleFilter.yes:
        if (memo.attachments.isEmpty) return false;
        break;
      case SearchToggleFilter.no:
        if (memo.attachments.isNotEmpty) return false;
        break;
    }

    if (filters.attachmentNameContains.isNotEmpty) {
      final query = filters.attachmentNameContains.toLowerCase();
      final matched = memo.attachments.any((attachment) {
        final label = _advancedSearchAttachmentDisplayName(
          attachment,
        ).trim().toLowerCase();
        return label.isNotEmpty && label.contains(query);
      });
      if (!matched) return false;
    }

    final attachmentType = filters.attachmentType;
    if (attachmentType != null) {
      final matched = memo.attachments.any(
        (attachment) =>
            _advancedSearchAttachmentMatchesType(attachment, attachmentType),
      );
      if (!matched) return false;
    }

    switch (filters.hasRelations) {
      case SearchToggleFilter.any:
        break;
      case SearchToggleFilter.yes:
        if (memo.relationCount <= 0) return false;
        break;
      case SearchToggleFilter.no:
        if (memo.relationCount > 0) return false;
        break;
    }

    return true;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AdvancedSearchFilters &&
        _sameDateRange(createdDateRange, other.createdDateRange) &&
        hasLocation == other.hasLocation &&
        locationContains == other.locationContains &&
        hasAttachments == other.hasAttachments &&
        attachmentNameContains == other.attachmentNameContains &&
        attachmentType == other.attachmentType &&
        hasRelations == other.hasRelations;
  }

  @override
  int get hashCode => Object.hash(
    createdDateRange?.start.millisecondsSinceEpoch,
    createdDateRange?.end.millisecondsSinceEpoch,
    hasLocation,
    locationContains,
    hasAttachments,
    attachmentNameContains,
    attachmentType,
    hasRelations,
  );
}

DateTimeRange? _normalizeDateRange(DateTimeRange? range) {
  if (range == null) return null;
  final start = _normalizeLocalDay(range.start);
  final end = _normalizeLocalDay(range.end);
  if (end.isBefore(start)) {
    return DateTimeRange(start: end, end: start);
  }
  return DateTimeRange(start: start, end: end);
}

DateTime _normalizeLocalDay(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

bool _sameDateRange(DateTimeRange? a, DateTimeRange? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  return a.start.isAtSameMomentAs(b.start) && a.end.isAtSameMomentAs(b.end);
}

String _advancedSearchAttachmentDisplayName(Attachment attachment) {
  return attachment.displayName;
}

bool _advancedSearchAttachmentMatchesType(
  Attachment attachment,
  AdvancedAttachmentType type,
) {
  final category = attachment.searchCategory;
  return switch (type) {
    AdvancedAttachmentType.image => category == AttachmentCategory.image,
    AdvancedAttachmentType.audio => category == AttachmentCategory.audio,
    AdvancedAttachmentType.document => category == AttachmentCategory.document,
    AdvancedAttachmentType.other => category == AttachmentCategory.other,
  };
}
