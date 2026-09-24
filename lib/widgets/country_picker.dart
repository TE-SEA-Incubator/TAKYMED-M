import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/auth_phone.dart';
import 'app_text_field.dart';

/// Ouvre une feuille de sélection de pays (recherche par nom / indicatif).
Future<CountryOption?> showCountryPickerSheet(
  BuildContext context, {
  required List<CountryOption> countries,
  String? selectedCode,
  String title = 'Choisir un pays',
}) {
  return showModalBottomSheet<CountryOption>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _CountryPickerSheet(
      countries: countries,
      selectedCode: selectedCode,
      title: title,
    ),
  );
}

class _CountryPickerSheet extends StatefulWidget {
  final List<CountryOption> countries;
  final String? selectedCode;
  final String title;

  const _CountryPickerSheet({required this.countries, this.selectedCode, required this.title});

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = widget.countries.where((c) => c.matches(_query)).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scroll) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.countries.length} pays disponibles',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  AppSearchField(
                    controller: _searchController,
                    hint: 'Nom du pays ou indicatif…',
                    autofocus: false,
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text('Aucun pays trouvé', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.mutedForeground)),
                    )
                  : ListView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final c = filtered[i];
                        final selected = c.code == widget.selectedCode;
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.primaryLight : Colors.transparent,
                            borderRadius: AppRadius.rMd,
                          ),
                          child: ListTile(
                            onTap: () => Navigator.pop(context, c),
                            leading: Text(c.flag, style: const TextStyle(fontSize: 26)),
                            title: Text(
                              c.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                                color: selected ? AppColors.primary : AppColors.foreground,
                              ),
                            ),
                            subtitle: c.timezone != null ? Text(c.timezone!, style: theme.textTheme.bodySmall) : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  c.dialCode,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: selected ? AppColors.primary : AppColors.mutedForeground,
                                  ),
                                ),
                                if (selected) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Bouton compact (drapeau + indicatif) à placer devant un champ téléphone.
class CountryDialButton extends StatelessWidget {
  final CountryOption country;
  final VoidCallback? onTap;
  final double height;

  const CountryDialButton({super.key, required this.country, this.onTap, this.height = 54});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.rMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.rMd,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: AppRadius.rMd,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(country.flag, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 6),
              Text(
                country.dialCode,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.expand_more_rounded, size: 18, color: AppColors.mutedForeground),
            ],
          ),
        ),
      ),
    );
  }
}

/// Champ "pays" complet (drapeau + nom + indicatif) pour le profil.
class CountryPickerField extends StatelessWidget {
  final String label;
  final CountryOption country;
  final VoidCallback? onTap;
  final bool loading;

  const CountryPickerField({
    super.key,
    this.label = 'Pays',
    required this.country,
    this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Material(
          color: AppColors.surface,
          borderRadius: AppRadius.rMd,
          child: InkWell(
            onTap: loading ? null : onTap,
            borderRadius: AppRadius.rMd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: AppRadius.rMd,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: AppRadius.rSm),
                    alignment: Alignment.center,
                    child: Text(country.flag, style: const TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(country.name, style: theme.textTheme.titleSmall),
                        Text('${country.code} · ${country.dialCode}', style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  if (loading)
                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    const Icon(Icons.unfold_more_rounded, color: AppColors.mutedForeground),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Ligne téléphone : sélecteur de pays + champ numéro.
class PhoneInputRow extends StatelessWidget {
  final TextEditingController controller;
  final CountryOption country;
  final VoidCallback onPickCountry;
  final String? Function(String?)? validator;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final bool autofocus;
  final TextInputAction? textInputAction;

  const PhoneInputRow({
    super.key,
    required this.controller,
    required this.country,
    required this.onPickCountry,
    this.validator,
    this.hint = '6 XX XX XX XX',
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.autofocus = false,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CountryDialButton(country: country, onTap: onPickCountry),
        const SizedBox(width: 10),
        Expanded(
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            autofocus: autofocus,
            keyboardType: TextInputType.phone,
            textInputAction: textInputAction ?? TextInputAction.done,
            validator: validator,
            onChanged: onChanged,
            onFieldSubmitted: onSubmitted,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: 0.4),
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: const Icon(Icons.phone_outlined, size: 20, color: AppColors.mutedForeground),
            ),
          ),
        ),
      ],
    );
  }
}
