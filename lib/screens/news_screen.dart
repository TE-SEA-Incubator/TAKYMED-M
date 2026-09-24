import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/med_helpers.dart';
import '../widgets/animated_fade_slide.dart';
import '../widgets/app_card.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/icon_box.dart';
import '../widgets/loading_view.dart';
import '../widgets/main_shell.dart';
import '../widgets/medication_image.dart';
import '../widgets/page_header.dart';
import '../widgets/page_transitions.dart';
import '../widgets/primary_button.dart';
import '../widgets/reminder_notification_config.dart' show AppBrandIcons;
import '../widgets/skeleton.dart';
import 'create_prescription_screen.dart';
import 'search_medications_screen.dart';
import 'search_pharmacies_screen.dart';

/// Métadonnées d'affichage par type d'actualité.
class NewsTypeMeta {
  final String label;
  final IconData icon;
  final Color color;
  final Color background;

  const NewsTypeMeta(this.label, this.icon, this.color, this.background);

  static const medicament = NewsTypeMeta('Médicament', Icons.medication_rounded, AppColors.primary, AppColors.primaryLight);
  static const pharmacie = NewsTypeMeta('Pharmacie', Icons.local_pharmacy_rounded, AppColors.secondaryDark, AppColors.secondaryLight);
  static const info = NewsTypeMeta('Info santé', Icons.campaign_rounded, Color(0xFFB45309), AppColors.warningLight);

  static NewsTypeMeta of(String? type) => switch (type) {
        'medicament' => medicament,
        'pharmacie' => pharmacie,
        _ => info,
      };
}

/// Page « Actu » : actualités publiées par les administrateurs (GET /news) —
/// nouveaux médicaments, pharmacies partenaires et annonces.
class NewsScreen extends StatefulWidget {
  final bool embedded;
  const NewsScreen({super.key, this.embedded = false});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  static const _filters = <(String?, String)>[(null, 'Tout'), ('medicament', 'Médicaments'), ('pharmacie', 'Pharmacies'), ('info', 'Infos')];

  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _error;
  String? _filter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final list = await api.getNews();
      if (mounted) {
        setState(() {
          _items = list;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = AppSnackbar.clean(e);
        });
      }
    }
  }

  List<Map<String, dynamic>> get _visible => _filter == null ? _items : _items.where((n) => n['type'] == _filter).toList();

  void _openMedication(String name) {
    final shell = MainShell.of(context);
    if (widget.embedded && shell != null) {
      shell.selectTab(ShellTab.medications);
      return;
    }
    pushSlide(context, SearchMedicationsScreen(initialQuery: name));
  }

  void _openPharmacies() {
    final shell = MainShell.of(context);
    if (widget.embedded && shell != null) {
      shell.selectTab(ShellTab.pharmacies);
      return;
    }
    pushSlide(context, const SearchPharmaciesScreen());
  }

  void _openDetail(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewsDetailSheet(
        item: item,
        onOpenMedication: _openMedication,
        onOpenPharmacies: _openPharmacies,
      ),
    );
  }

  Widget _filterBar() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
        itemCount: _filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (key, label) = _filters[i];
          final selected = _filter == key;
          final count = key == null ? _items.length : _items.where((n) => n['type'] == key).length;
          return ChoiceChip(
            label: Text(count > 0 ? '$label · $count' : label),
            selected: selected,
            onSelected: (_) => setState(() => _filter = key),
            showCheckmark: false,
            labelStyle: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.foreground),
            selectedColor: AppColors.foreground,
            backgroundColor: AppColors.surface,
            side: BorderSide(color: selected ? AppColors.foreground : AppColors.border),
            shape: const StadiumBorder(),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = _visible;

    Widget body;
    if (_loading) {
      body = const SkeletonList(count: 3, itemHeight: 220, withLeading: false);
    } else if (_error != null) {
      body = ErrorState(message: _error!, onRetry: _load);
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 32),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: visible.length + 2 + (visible.isEmpty ? 1 : 0),
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, 14),
                child: HeroCard(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ACTU SANTÉ',
                              style: theme.textTheme.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.85), letterSpacing: 1, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            Text('Sélection TAKYMED', style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
                            const SizedBox(height: 4),
                            Text(
                              _items.isEmpty
                                  ? 'Nouveaux médicaments, pharmacies partenaires et annonces.'
                                  : '${_items.length} actualité${_items.length > 1 ? 's' : ''} · nouveaux médicaments, pharmacies partenaires et annonces.',
                              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 84,
                        height: 84,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                        child: Image.asset(AppImages.pharmacy, fit: BoxFit.contain),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (i == 1) {
              return Padding(padding: const EdgeInsets.only(bottom: 14), child: _filterBar());
            }
            if (visible.isEmpty) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, 12, AppSpacing.page, 0),
                child: EmptyState(
                  image: AppImages.safety,
                  title: _filter == null ? 'Aucune actualité pour le moment' : 'Rien dans cette catégorie',
                  subtitle: 'Les publications de l\'équipe TAKYMED apparaîtront ici dès leur mise en ligne.',
                  action: _filter == null
                      ? null
                      : SecondaryButton(label: 'Voir tout', icon: Icons.filter_alt_off_rounded, expanded: false, height: 44, onPressed: () => setState(() => _filter = null)),
                ),
              );
            }
            final item = visible[i - 2];
            return Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, 14),
              child: AnimatedFadeSlide(
                index: (i - 2).clamp(0, 8),
                child: _NewsCard(
                  item: item,
                  featured: i == 2 && item['pinned'] == true,
                  onTap: () => _openDetail(item),
                  onPrimary: () => _primaryAction(item),
                ),
              ),
            );
          },
        ),
      );
    }

    final content = Column(
      children: [
        if (widget.embedded) const PageHeader(title: 'Actu', subtitle: 'Nouveautés et pharmacies partenaires'),
        Expanded(child: body),
      ],
    );

    if (widget.embedded) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(bottom: false, child: content),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppTopBar(title: 'Actu', subtitle: 'Sélection TAKYMED'),
      body: body,
    );
  }

  Future<void> _primaryAction(Map<String, dynamic> item) async {
    final link = item['externalLink']?.toString();
    if (link != null && link.isNotEmpty && link != 'null') {
      final uri = Uri.tryParse(link);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    final med = item['medication'];
    if (item['type'] == 'medicament' && med is Map) {
      _openMedication(med['name']?.toString() ?? '');
      return;
    }
    if (item['type'] == 'pharmacie') {
      _openPharmacies();
      return;
    }
    _openDetail(item);
  }
}

/// Libellé du bouton principal d'une actualité.
String newsCtaLabel(Map<String, dynamic> item) {
  final custom = item['ctaLabel']?.toString();
  if (custom != null && custom.isNotEmpty && custom != 'null') return custom;
  return switch (item['type']) {
    'medicament' => 'Voir le médicament',
    'pharmacie' => 'Voir la pharmacie',
    _ => 'En savoir plus',
  };
}

String _formatNewsDate(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final iso = raw.contains('T') ? raw : '${raw.replaceFirst(' ', 'T')}Z';
  final d = DateTime.tryParse(iso)?.toLocal();
  return d == null ? '' : DateFormat('d MMM', 'fr_FR').format(d);
}

String? _newsImage(Map<String, dynamic> item) {
  final direct = item['imageUrl']?.toString();
  if (direct != null && direct.isNotEmpty && direct != 'null') return MedHelpers.photoForList(direct);
  final med = item['medication'];
  if (med is Map) return MedHelpers.photoForList(med['photoUrl']?.toString());
  return null;
}

class _TypeBadge extends StatelessWidget {
  final String? type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final meta = NewsTypeMeta.of(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.94), borderRadius: AppRadius.rSm, boxShadow: AppShadows.soft),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.icon, size: 13, color: meta.color),
          const SizedBox(width: 5),
          Text(meta.label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: meta.color)),
        ],
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool featured;
  final VoidCallback onTap;
  final VoidCallback onPrimary;

  const _NewsCard({required this.item, required this.featured, required this.onTap, required this.onPrimary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = NewsTypeMeta.of(item['type']?.toString());
    final image = _newsImage(item);
    final med = item['medication'] is Map ? Map<String, dynamic>.from(item['medication'] as Map) : null;
    final pharmacy = item['pharmacy'] is Map ? Map<String, dynamic>.from(item['pharmacy'] as Map) : null;
    final linked = med?['name']?.toString() ?? pharmacy?['name']?.toString();
    final summary = item['summary']?.toString();
    final price = med?['price']?.toString();
    final hasPrice = price != null && price.isNotEmpty && price != 'null';
    final date = _formatNewsDate(item['createdAt']?.toString());
    final pinned = item['pinned'] == true;
    final address = pharmacy == null ? null : [pharmacy['address'], pharmacy['city']].where((v) => v != null && v.toString().isNotEmpty && v != 'null').join(', ');

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              if (image != null)
                MedicationImage(photoUrl: image, width: double.infinity, height: featured ? 210 : 170, borderRadius: 0, fit: BoxFit.cover)
              else
                Container(
                  height: featured ? 210 : 170,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: item['type'] == 'pharmacie'
                          ? const [AppColors.secondary, AppColors.secondaryDark]
                          : item['type'] == 'info'
                              ? const [Color(0xFFF59E0B), Color(0xFFB45309)]
                              : const [AppColors.gradientStart, AppColors.gradientEnd],
                    ),
                  ),
                  child: Icon(meta.icon, size: 64, color: Colors.white.withValues(alpha: 0.85)),
                ),
              Positioned(
                top: 12,
                left: 12,
                child: Row(
                  children: [
                    _TypeBadge(type: item['type']?.toString()),
                    if (pinned) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(color: AppColors.foreground.withValues(alpha: 0.85), borderRadius: AppRadius.rSm),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.push_pin_rounded, size: 12, color: Colors.white),
                            SizedBox(width: 4),
                            Text('À LA UNE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: Colors.white)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (hasPrice)
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.94), borderRadius: AppRadius.rSm, boxShadow: AppShadows.soft),
                    child: Text(price, style: theme.textTheme.labelLarge?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800)),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (date.isNotEmpty) ...[
                      const Icon(Icons.schedule_rounded, size: 13, color: AppColors.subtleForeground),
                      const SizedBox(width: 4),
                      Text(date, style: theme.textTheme.labelSmall?.copyWith(color: AppColors.subtleForeground, fontWeight: FontWeight.w700)),
                    ],
                    if (linked != null && linked.isNotEmpty) ...[
                      if (date.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text('·', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.subtleForeground)),
                        ),
                      Expanded(
                        child: Text(linked, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall?.copyWith(color: AppColors.mutedForeground, fontWeight: FontWeight.w700)),
                      ),
                    ] else
                      const Spacer(),
                  ],
                ),
                const SizedBox(height: 8),
                Text(item['title']?.toString() ?? 'Actualité', style: featured ? theme.textTheme.headlineSmall : theme.textTheme.titleLarge, maxLines: 3, overflow: TextOverflow.ellipsis),
                if (summary != null && summary.isNotEmpty && summary != 'null') ...[
                  const SizedBox(height: 8),
                  Text(summary, maxLines: featured ? 4 : 3, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.mutedForeground, height: 1.5)),
                ],
                if (address != null && address.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.place_outlined, size: 14, color: AppColors.secondaryDark),
                      const SizedBox(width: 6),
                      Expanded(child: Text(address, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall)),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: SecondaryButton(label: 'Lire', icon: Icons.article_outlined, height: 46, onPressed: onTap)),
                    const SizedBox(width: 10),
                    Expanded(flex: 3, child: PrimaryButton(label: newsCtaLabel(item), icon: meta.icon, height: 46, onPressed: onPrimary)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Feuille de détail : texte complet + actions liées (médicament / pharmacie / lien).
class _NewsDetailSheet extends StatelessWidget {
  final Map<String, dynamic> item;
  final void Function(String name) onOpenMedication;
  final VoidCallback onOpenPharmacies;

  const _NewsDetailSheet({required this.item, required this.onOpenMedication, required this.onOpenPharmacies});

  Future<void> _launch(BuildContext context, Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      AppSnackbar.error(context, 'Impossible d\'ouvrir ce lien');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = NewsTypeMeta.of(item['type']?.toString());
    final image = _newsImage(item);
    final med = item['medication'] is Map ? Map<String, dynamic>.from(item['medication'] as Map) : null;
    final pharmacy = item['pharmacy'] is Map ? Map<String, dynamic>.from(item['pharmacy'] as Map) : null;
    final summary = item['summary']?.toString();
    final body = item['body']?.toString();
    final link = item['externalLink']?.toString();
    final hasLink = link != null && link.isNotEmpty && link != 'null';
    final phone = pharmacy?['phone']?.toString();
    final hasPhone = phone != null && phone.isNotEmpty && phone != 'null';
    final date = _formatNewsDate(item['createdAt']?.toString());

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, scroll) => Container(
        decoration: const BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        clipBehavior: Clip.antiAlias,
        child: ListView(
          controller: scroll,
          padding: EdgeInsets.zero,
          children: [
            Stack(
              children: [
                if (image != null)
                  MedicationImage(photoUrl: image, width: double.infinity, height: 220, borderRadius: 0, fit: BoxFit.cover)
                else
                  Container(height: 120, color: meta.background, child: Icon(meta.icon, size: 48, color: meta.color)),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.92),
                    shape: const CircleBorder(),
                    child: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                  ),
                ),
                Positioned(top: 14, left: 14, child: _TypeBadge(type: item['type']?.toString())),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, 18, AppSpacing.page, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (date.isNotEmpty)
                    Text('Publié le $date', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.subtleForeground, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(item['title']?.toString() ?? 'Actualité', style: theme.textTheme.headlineSmall),
                  if (summary != null && summary.isNotEmpty && summary != 'null') ...[
                    const SizedBox(height: 10),
                    Text(summary, style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.mutedForeground, height: 1.5)),
                  ],
                  if (body != null && body.isNotEmpty && body != 'null') ...[
                    const SizedBox(height: 14),
                    Text(body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
                  ],
                  if (med != null) ...[
                    const SizedBox(height: 18),
                    AppCard(
                      color: AppColors.primaryLight,
                      borderColor: AppColors.primarySoft,
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const IconBox(icon: Icons.medication_rounded, size: 44),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(med['name']?.toString() ?? '', style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text(
                                  (med['price']?.toString().isNotEmpty ?? false) && med['price'].toString() != 'null' ? med['price'].toString() : 'Prix : demandez en pharmacie',
                                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          PillButton(
                            label: 'Suivre',
                            icon: Icons.add_alarm_rounded,
                            filled: true,
                            onPressed: () {
                              Navigator.pop(context);
                              pushSlide(context, CreatePrescriptionScreen(initialMedName: med['name']?.toString()));
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (pharmacy != null) ...[
                    const SizedBox(height: 18),
                    AppCard(
                      color: AppColors.secondaryLight,
                      borderColor: AppColors.secondarySoft,
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const IconBox(icon: Icons.local_pharmacy_rounded, color: AppColors.secondaryDark, size: 44),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(pharmacy['name']?.toString() ?? '', style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 2),
                                    Text(
                                      [pharmacy['address'], pharmacy['city']].where((v) => v != null && v.toString().isNotEmpty && v != 'null').join(', ').ifEmpty('Adresse non renseignée'),
                                      style: theme.textTheme.bodySmall,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (hasPhone) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: SecondaryButton(
                                    label: 'Appeler',
                                    icon: Icons.call_rounded,
                                    height: 42,
                                    onPressed: () => _launch(context, Uri.parse('tel:${phone.replaceAll(RegExp(r'\s'), '')}')),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: PrimaryButton(
                                    label: 'WhatsApp',
                                    icon: AppBrandIcons.whatsapp,
                                    height: 42,
                                    backgroundColor: const Color(0xFF25D366),
                                    onPressed: () => _launch(context, Uri.parse('https://wa.me/${phone.replaceAll(RegExp(r'\D'), '')}')),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  PrimaryButton(
                    label: newsCtaLabel(item),
                    icon: hasLink ? Icons.open_in_new_rounded : meta.icon,
                    onPressed: () {
                      if (hasLink) {
                        _launch(context, Uri.parse(link));
                        return;
                      }
                      Navigator.pop(context);
                      if (item['type'] == 'medicament' && med != null) {
                        onOpenMedication(med['name']?.toString() ?? '');
                      } else if (item['type'] == 'pharmacie') {
                        onOpenPharmacies();
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
