import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';

/// Public privacy-policy URL shown to users and required by the app stores.
/// Update this to the real Cloudflare Pages URL after deploying `privacy/`.
const String kPrivacyPolicyUrl =
    'https://minesweeper-coop.lacon.workers.dev/';

/// Support / contact address surfaced in the About screen and store listing.
const String kSupportEmail = 'manro2600@gmail.com';

/// About screen: app identity, version/build, credits, and the privacy link.
/// Reachable from the main menu.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<GamePalette>() ?? GamePalette.light;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'About',
          style: GoogleFonts.fredoka(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppPalette.grass, AppPalette.leaf],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppPalette.leaf.withValues(alpha: 0.4),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.flag_rounded,
                        size: 44, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Minesweeper Co-op',
                    style: GoogleFonts.fredoka(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const _VersionLabel(),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: g.panel,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: g.panelBorder, width: 1.5),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'A co-op Minesweeper you play together — online '
                          'with a room code, or over local Wi-Fi. Shared '
                          'reveals, flags, cursors, emoji, and chat.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Divider(color: cs.outlineVariant),
                        const SizedBox(height: 6),
                        _LinkRow(
                          icon: Icons.shield_outlined,
                          label: 'Safety & blocked players',
                          external: false,
                          onTap: () => context.push('/safety'),
                        ),
                        _LinkRow(
                          icon: Icons.privacy_tip_outlined,
                          label: 'Privacy Policy',
                          onTap: () => _open(context, kPrivacyPolicyUrl),
                        ),
                        _LinkRow(
                          icon: Icons.mail_outline_rounded,
                          label: kSupportEmail,
                          onTap: () =>
                              _open(context, 'mailto:$kSupportEmail'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Made with Flutter',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Could not open $url')));
    }
  }
}

/// Reads the app version/build at runtime so it always matches the binary.
class _VersionLabel extends StatelessWidget {
  const _VersionLabel();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snap) {
        final info = snap.data;
        final text = info == null
            ? 'Version …'
            : 'Version ${info.version} (build ${info.buildNumber})';
        return Text(
          text,
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        );
      },
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.external = true,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Leaves the app (shows the open-in-new affordance). In-app destinations
  /// get a chevron instead.
  final bool external;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
                external
                    ? Icons.open_in_new_rounded
                    : Icons.chevron_right_rounded,
                size: external ? 16 : 20,
                color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
