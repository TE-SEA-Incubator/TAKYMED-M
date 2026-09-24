import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/med_helpers.dart';
import '../widgets/app_card.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/icon_box.dart';
import '../widgets/medication_image.dart';
import '../widgets/page_header.dart';
import '../widgets/page_transitions.dart';
import '../widgets/primary_button.dart';
import '../widgets/status_badge.dart';
import 'create_prescription_screen.dart';
import 'search_pharmacies_screen.dart';

/// Fiche détaillée d'un médicament du catalogue (description, précautions, interactions).
class MedicationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> medication;
  final List<dynamic> interactions;
  final String heroTag;

  const MedicationDetailScreen({
    super.key,
    required this.medication,
    this.interactions = const [],
    required this.heroTag,
  });

  @override
  State<MedicationDetailScreen> createState() => _MedicationDetailScreenState();
}

class _MedicationDetailScreenState extends State<MedicationDetailScreen> {
  bool _bookmarked = false;
  int? get _id => MedHelpers.parseId(widget.medication['id']);

  @override
  void initState() {
    super.initState();
    _loadBookmark();
  }

  Future<void> _loadBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('med_bookmarks') ?? const [];
    if (mounted) setState(() => _bookmarked = _id != null && saved.contains(_id.toString()));
  }

  Future<void> _toggleBookmark() async {
    final id = _id;
    if (id == null) return;
    final prefs = await SharedPreferences.getInstance();
    final saved = (prefs.getStringList('med_bookmarks') ?? const []).toList();
    final key = id.toString();
    final next = !saved.contains(key);
    if (next) {
      saved.add(key);
    } else {
      saved.remove(key);
    }
    await prefs.setStringList('med_bookmarks', saved);
    if (!mounted) return;
    setState(() => _bookmarked = next);
    AppSnackbar.info(context, next ? 'Ajouté aux favoris' : 'Retiré des favoris');
  }

  List<dynamic> get _relevantInteractions {
    final name = MedHelpers.safeString(widget.medication['name']).toLowerCase();
    if (name.isEmpty) return const [];
    return widget.interactions.where((i) {
      final m1 = MedHelpers.safeString(i['med1Name']).toLowerCase();
      final m2 = MedHelpers.safeString(i['med2Name']).toLowerCase();
      return m1 == name || m2 == name;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final med = widget.medication;
    final name = MedHelpers.safeString(med['name'], 'Médicament');
    final type = MedHelpers.safeString(med['type']).trim();
    final price = MedHelpers.safeString(med['price']).trim();
    final description = MedHelpers.safeString(med['description']).trim();
    final precautions = MedHelpers.safeString(med['precautions']).trim();
    final hasPrecautions = precautions.isNotEmpty && precautions.toLowerCase() != 'aucune';
    final interactions = _relevantInteractions;
    final lowerName = name.toLowerCase();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppTopBar(
        title: 'Fiche médicament',
        actions: [
          IconButton(
            tooltip: _bookmarked ? 'Retirer des favoris' : 'Ajouter aux favoris',
            onPressed: _toggleBookmark,
            icon: Icon(
              _bookmarked ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
              color: _bookmarked ? AppColors.warning : AppColors.foreground,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 120),
        children: [
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Hero(
                  tag: widget.heroTag,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: MedicationImage(
                        photoUrl: med['photoUrl']?.toString(),
                        width: double.infinity,
                        height: 200,
                        borderRadius: 16,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          StatusBadge(label: type.isEmpty ? 'Médicament' : type, type: StatusType.info, icon: Icons.medication_rounded),
                          if (med['isNew'] == true) const StatusBadge(label: 'Nouveau', type: StatusType.validated, icon: Icons.auto_awesome_rounded),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(name, style: theme.textTheme.headlineSmall),
                      if (price.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(price, style: theme.textTheme.titleLarge?.copyWith(color: AppColors.primary)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Description',
            icon: Icons.info_outline_rounded,
            child: Text(
              description.isEmpty ? 'Aucune description disponible pour ce médicament.' : description,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Précautions & interactions',
            subtitle: interactions.isEmpty ? 'Aucune incompatibilité connue' : '${interactions.length} incompatibilité${interactions.length > 1 ? 's' : ''} connue${interactions.length > 1 ? 's' : ''}',
            icon: Icons.health_and_safety_outlined,
            iconColor: AppColors.warning,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InfoBanner(
                  icon: Icons.restaurant_rounded,
                  color: hasPrecautions ? AppColors.warning : AppColors.secondary,
                  title: 'Recommandations',
                  message: hasPrecautions ? precautions : 'Aucune précaution spécifique enregistrée.',
                ),
                for (final inter in interactions) ...[
                  const SizedBox(height: 10),
                  _InteractionTile(
                    other: MedHelpers.safeString(inter['med1Name']).toLowerCase() == lowerName
                        ? MedHelpers.safeString(inter['med2Name'])
                        : MedHelpers.safeString(inter['med1Name']),
                    riskLevel: MedHelpers.safeString(inter['riskLevel'], 'modere'),
                    description: MedHelpers.safeString(inter['description']).trim(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(AppSpacing.page, 12, AppSpacing.page, 12 + MediaQuery.of(context).padding.bottom),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: 'Pharmacies',
                icon: Icons.local_pharmacy_rounded,
                onPressed: () => pushSlide(context, const SearchPharmaciesScreen()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: PrimaryButton.brand(
                label: 'Ajouter au traitement',
                icon: Icons.add_rounded,
                onPressed: () => pushSlide(context, CreatePrescriptionScreen(initialMedName: name)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InteractionTile extends StatelessWidget {
  final String other;
  final String riskLevel;
  final String description;

  const _InteractionTile({required this.other, required this.riskLevel, required this.description});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (Color color, String label) = switch (riskLevel) {
      'critique' => (AppColors.destructive, 'Risque critique'),
      'eleve' || 'élevé' => (const Color(0xFFF97316), 'Risque élevé'),
      _ => (AppColors.warning, 'Risque modéré'),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: AppRadius.rMd,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBox(icon: Icons.warning_amber_rounded, color: color, size: 38, iconSize: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ne pas associer avec $other', style: theme.textTheme.titleSmall?.copyWith(color: color)),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(description, style: theme.textTheme.bodySmall?.copyWith(height: 1.45)),
                ],
                const SizedBox(height: 8),
                StatusBadge(label: label, type: StatusType.warning, customColor: color, small: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
