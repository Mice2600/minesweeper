import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../ads/ads.dart';

/// A standard AdMob banner for menu screens. Renders nothing until an ad loads
/// (and nothing at all on platforms without ads), so it never reserves empty
/// space. Intended for the bottom of menu screens — never the gameplay board.
class MenuBanner extends StatefulWidget {
  const MenuBanner({super.key});

  @override
  State<MenuBanner> createState() => _MenuBannerState();
}

class _MenuBannerState extends State<MenuBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _ad = Ads.instance.createMenuBanner(
      onLoaded: () {
        if (mounted) setState(() => _loaded = true);
      },
      onFailed: () {
        _ad = null;
        if (mounted) setState(() => _loaded = false);
      },
    );
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: SizedBox(
        width: double.infinity,
        height: ad.size.height.toDouble(),
        child: Center(
          child: SizedBox(
            width: ad.size.width.toDouble(),
            height: ad.size.height.toDouble(),
            child: AdWidget(ad: ad),
          ),
        ),
      ),
    );
  }
}
