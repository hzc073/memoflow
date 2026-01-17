class UserStatsSummary {
  const UserStatsSummary({
    required this.memoDisplayTimes,
    required this.totalMemoCount,
  });

  final List<DateTime> memoDisplayTimes;
  final int totalMemoCount;
}
