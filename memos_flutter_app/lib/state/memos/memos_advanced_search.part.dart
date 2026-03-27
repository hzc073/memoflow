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
  final filename = attachment.filename.trim();
  if (filename.isNotEmpty) return filename;
  final uid = attachment.uid.trim();
  if (uid.isNotEmpty) return uid;
  return attachment.name.trim();
}

bool _advancedSearchAttachmentMatchesType(
  Attachment attachment,
  AdvancedAttachmentType type,
) {
  return switch (type) {
    AdvancedAttachmentType.image => _isImageAttachment(attachment),
    AdvancedAttachmentType.audio => _isAudioAttachment(attachment),
    AdvancedAttachmentType.document => _isDocumentAttachment(attachment),
    AdvancedAttachmentType.other =>
      !_isImageAttachment(attachment) &&
          !_isAudioAttachment(attachment) &&
          !_isDocumentAttachment(attachment),
  };
}

bool _isImageAttachment(Attachment attachment) {
  final type = attachment.type.trim().toLowerCase();
  if (type.startsWith('image/')) return true;

  final filename = attachment.filename.trim().toLowerCase();
  if (filename.isEmpty) return false;
  const imageExtensions = <String>[
    '.avif',
    '.bmp',
    '.gif',
    '.heic',
    '.jpeg',
    '.jpg',
    '.png',
    '.svg',
    '.webp',
  ];
  for (final ext in imageExtensions) {
    if (filename.endsWith(ext)) return true;
  }
  return false;
}

bool _isDocumentAttachment(Attachment attachment) {
  final type = attachment.type.trim().toLowerCase();
  const documentMimeTypes = <String>{
    'application/pdf',
    'pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'application/rtf',
    'text/rtf',
    'text/plain',
    'text/markdown',
    'text/csv',
    'text/tab-separated-values',
    'application/csv',
    'application/xml',
    'text/xml',
    'application/vnd.oasis.opendocument.text',
    'application/vnd.oasis.opendocument.spreadsheet',
    'application/vnd.oasis.opendocument.presentation',
    'application/ofd',
    'application/vnd.ofd',
    'application/x-ofd',
  };
  if (documentMimeTypes.contains(type)) return true;

  final filename = attachment.filename.trim().toLowerCase();
  if (filename.isEmpty) return false;

  const documentExtensions = <String>[
    '.pdf',
    '.doc',
    '.docx',
    '.xls',
    '.xlsx',
    '.ppt',
    '.pptx',
    '.rtf',
    '.txt',
    '.md',
    '.markdown',
    '.csv',
    '.tsv',
    '.odt',
    '.ods',
    '.odp',
    '.pages',
    '.numbers',
    '.key',
    '.xml',
    '.ofd',
  ];
  for (final ext in documentExtensions) {
    if (filename.endsWith(ext)) return true;
  }
  return false;
}
