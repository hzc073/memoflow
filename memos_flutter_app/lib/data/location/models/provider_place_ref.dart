class ProviderPlaceRef {
  const ProviderPlaceRef({
    required this.providerId,
    required this.providerName,
    this.raw = const <String, dynamic>{},
  });

  final String providerId;
  final String providerName;
  final Map<String, dynamic> raw;
}

