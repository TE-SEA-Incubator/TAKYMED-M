import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/pharmacy_garde_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/med_helpers.dart';
import '../widgets/app_card.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/icon_box.dart';
import '../widgets/page_header.dart';
import '../widgets/primary_button.dart';
import '../widgets/status_badge.dart';

/// Fiche d'une pharmacie : coordonnées, appel, itinéraire, source OSM.
class PharmacyDetailsScreen extends StatelessWidget {
  final PharmacyGarde pharmacy;

  const PharmacyDetailsScreen({super.key, required this.pharmacy});

  Future<void> _call(BuildContext context, String phone) async {
    final uri = Uri.parse('tel:${phone.replaceAll(RegExp(r'\s'), '')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      AppSnackbar.error(context, 'Impossible d\'ouvrir le composeur téléphonique.');
    }
  }

  Future<void> _openMaps() async {
    if (!pharmacy.hasLocation) return;
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${pharmacy.lat},${pharmacy.lng}&travelmode=driving');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openOsmSource() async {
    if (pharmacy.sourceUrl.isEmpty) return;
    final uri = Uri.parse(pharmacy.sourceUrl);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _copy(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    AppSnackbar.info(context, 'Copié dans le presse-papier');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duty = pharmacy.isOnDuty;
    final accent = duty ? AppColors.warning : AppColors.primary;
    final hasSource = pharmacy.sourceUrl.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppTopBar(title: 'Pharmacie'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 120),
        children: [
          HeroCard(
            gradient: duty ? const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFEA580C)]) : AppColors.brandGradient,
            child: Row(
              children: [
                Hero(
                  tag: 'pharmacy-${pharmacy.osmId}-${pharmacy.name}',
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: AppRadius.rMd),
                    child: const Icon(Icons.local_pharmacy_rounded, color: Colors.white, size: 30),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pharmacy.name, style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(
                        pharmacy.city.isNotEmpty ? pharmacy.city : 'Cameroun',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.88)),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (duty)
                            const StatusBadge(label: 'De garde', type: StatusType.warning, small: true, icon: Icons.shield_moon_rounded, customColor: Colors.white),
                          if (pharmacy.distanceKm != null)
                            StatusBadge(label: 'à ${MedHelpers.formatDistanceShort(pharmacy.distanceKm)}', type: StatusType.info, small: true, icon: Icons.near_me_rounded, customColor: Colors.white),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _InfoTile(
            icon: Icons.location_on_rounded,
            label: 'Adresse',
            value: pharmacy.address?.isNotEmpty == true ? pharmacy.address! : 'Adresse non disponible',
            hint: pharmacy.address?.isNotEmpty == true ? 'Appui long pour copier' : null,
            onLongPress: pharmacy.address?.isNotEmpty == true ? () => _copy(context, pharmacy.address!) : null,
          ),
          if (pharmacy.phones.isNotEmpty) ...[
            const SizedBox(height: 10),
            _InfoTile(
              icon: Icons.phone_rounded,
              label: 'Téléphone${pharmacy.phones.length > 1 ? 's' : ''}',
              value: pharmacy.phones.join('\n'),
              hint: 'Appui long pour copier',
              color: AppColors.secondary,
              onLongPress: () => _copy(context, pharmacy.phones.first),
            ),
          ],
          if (pharmacy.hasLocation) ...[
            const SizedBox(height: 10),
            _InfoTile(
              icon: Icons.gps_fixed_rounded,
              label: 'Coordonnées GPS',
              value: '${pharmacy.lat.toStringAsFixed(6)}, ${pharmacy.lng.toStringAsFixed(6)}',
              hint: 'Appui long pour copier',
              onLongPress: () => _copy(context, '${pharmacy.lat}, ${pharmacy.lng}'),
            ),
          ],
          if (hasSource) ...[
            const SizedBox(height: 10),
            _InfoTile(
              icon: Icons.public_rounded,
              label: 'Source',
              value: 'OpenStreetMap',
              hint: 'Voir la fiche OSM',
              onTap: _openOsmSource,
            ),
          ],
          const SizedBox(height: 20),
          if (pharmacy.hasLocation)
            SecondaryButton(label: 'Itinéraire (Google Maps)', icon: Icons.directions_rounded, color: AppColors.secondary, onPressed: _openMaps),
          if (hasSource) ...[
            const SizedBox(height: 10),
            GhostButton(label: 'Voir sur OpenStreetMap', icon: Icons.map_outlined, onPressed: _openOsmSource),
          ],
          const SizedBox(height: 16),
          Center(
            child: Text(
              hasSource ? '© OpenStreetMap contributors · Licence ODbL' : 'Données fournies par TAKYMED',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
          ),
        ],
      ),
      bottomNavigationBar: pharmacy.phones.isEmpty
          ? null
          : Container(
              padding: EdgeInsets.fromLTRB(AppSpacing.page, 12, AppSpacing.page, 12 + MediaQuery.of(context).padding.bottom),
              decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
              child: PrimaryButton(
                label: 'Appeler la pharmacie',
                icon: Icons.phone_in_talk_rounded,
                backgroundColor: accent,
                onPressed: () => _call(context, pharmacy.phones.first),
              ),
            ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? hint;
  final Color color;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.hint,
    this.color = AppColors.primary,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBox(icon: icon, color: color, size: 40, iconSize: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.4)),
                const SizedBox(height: 3),
                Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.4)),
                if (hint != null) ...[
                  const SizedBox(height: 2),
                  Text(hint!, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
                ],
              ],
            ),
          ),
          if (onTap != null) const Icon(Icons.chevron_right_rounded, color: AppColors.mutedForeground, size: 20),
        ],
      ),
    );
  }
}
