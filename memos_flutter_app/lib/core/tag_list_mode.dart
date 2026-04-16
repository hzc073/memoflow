enum TagListMode {
  all,
  frequent,
  recent,
  pinned;

  static TagListMode fromStorage(Object? raw) {
    if (raw is String) {
      for (final value in values) {
        if (value.name == raw) return value;
      }
    }
    return TagListMode.all;
  }
}
