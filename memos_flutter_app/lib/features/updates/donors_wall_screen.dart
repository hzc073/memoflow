import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_localization.dart';
import '../../core/memoflow_palette.dart';
import '../../data/updates/update_config.dart';
import '../../state/update_config_provider.dart';
import '../../i18n/strings.g.dart';

const String _defaultAvatarAsset = 'assets/images/default_avatar.webp';

class DonorsWallScreen extends ConsumerStatefulWidget {
  const DonorsWallScreen({super.key});

  @override
  ConsumerState<DonorsWallScreen> createState() => _DonorsWallScreenState();
}

class _DonorsWallScreenState extends ConsumerState<DonorsWallScreen> {
  late final Future<UpdateAnnouncementConfig?> _configFuture;

  @override
  void initState() {
    super.initState();
    _configFuture = ref.read(updateConfigServiceProvider).fetchLatest();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MemoFlowPalette.backgroundDark : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark ? MemoFlowPalette.textDark : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: context.t.strings.legacy.msg_back,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(context.t.strings.legacy.msg_contributors),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          if (isDark)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF0B0B0B),
                      bg,
                      bg,
                    ],
                  ),
                ),
              ),
            ),
          FutureBuilder<UpdateAnnouncementConfig?>(
            future: _configFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final config = snapshot.data;
              final donors = config?.donors ?? const <UpdateDonor>[];
              if (donors.isEmpty) {
                return _EmptyDonorsState(textMuted: textMuted);
              }
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 140,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.86,
                ),
                itemCount: donors.length,
                itemBuilder: (context, index) {
                  return _DonorTile(
                    donor: donors[index],
                    card: card,
                    textMain: textMain,
                    textMuted: textMuted,
                    isDark: isDark,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EmptyDonorsState extends StatelessWidget {
  const _EmptyDonorsState({required this.textMuted});

  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            _defaultAvatarAsset,
            width: 72,
            height: 72,
          ),
          const SizedBox(height: 12),
          Text(
            context.t.strings.legacy.msg_no_contributors_yet,
            style: TextStyle(fontSize: 13, color: textMuted),
          ),
        ],
      ),
    );
  }
}

class _DonorTile extends StatelessWidget {
  const _DonorTile({
    required this.donor,
    required this.card,
    required this.textMain,
    required this.textMuted,
    required this.isDark,
  });

  final UpdateDonor donor;
  final Color card;
  final Color textMain;
  final Color textMuted;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                  color: Colors.black.withValues(alpha: 0.06),
                ),
              ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _DonorAvatar(url: donor.avatar, size: 54, mutedColor: textMuted),
          const SizedBox(height: 10),
          Text(
            donor.name.isEmpty ? context.t.strings.legacy.msg_anonymous : donor.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textMain),
          ),
        ],
      ),
    );
  }
}

class _DonorAvatar extends StatelessWidget {
  const _DonorAvatar({
    required this.url,
    required this.size,
    required this.mutedColor,
  });

  final String url;
  final double size;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: mutedColor.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: SizedBox(
          width: size * 0.4,
          height: size * 0.4,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: mutedColor,
          ),
        ),
      ),
    );

    Widget content;
    if (url.trim().isEmpty) {
      content = Image.asset(
        _defaultAvatarAsset,
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    } else {
      content = CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 220),
        placeholder: (context, url) => placeholder,
        errorWidget: (context, url, error) => Image.asset(
          _defaultAvatarAsset,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    return ClipOval(child: content);
  }
}
