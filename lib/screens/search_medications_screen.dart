import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/med_helpers.dart';
import '../widgets/animated_fade_slide.dart';
import '../widgets/app_card.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/app_text_field.dart';
import '../widgets/icon_box.dart';
import '../widgets/loading_view.dart';
import '../widgets/medication_image.dart';
import '../widgets/page_header.dart';
import '../widgets/page_transitions.dart';
import '../widgets/primary_button.dart';
import '../widgets/skeleton.dart';
import '../widgets/status_badge.dart';
import 'create_prescription_screen.dart';
import 'medication_detail_screen.dart';

/// Recherche dans le catalogue de médicaments, avec repli IA si aucun résultat.
class SearchMedicationsScreen extends StatefulWidget {
  final bool embedded;
  final String? initialQuery;

  const SearchMedicationsScreen({super.key, this.embedded = false, this.initialQuery});

  @override
  State<SearchMedicationsScreen> createState() => _SearchMedicationsScreenState();
}

class _SearchMedicationsScreenState extends State<SearchMedicationsScreen> {
  static const _maxResults = 40;
  static const _fallbackSuggestions = ['Paracétamol', 'Amoxicilline', 'Ibuprofène', 'Vitamine C', 'Artéméther'];

  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  Timer? _suggestDebounce;
  int _searchSeq = 0;

  List<dynamic> _medications = [];
  List<dynamic> _interactions = [];
  List<String> _popular = _fallbackSuggestions;
  List<Map<String, dynamic>> _liveSuggestions = [];
  String? _didYouMean;
  int _total = 0;
  bool _loading = false;
  bool _searched = false;

  bool _aiLoading = false;
  Map<String, dynamic>? _aiResult;
  String? _aiErrorMessage;
  String _lastAiQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchInteractions();
    _fetchPopular();
    final q = widget.initialQuery?.trim();
    if (q != null && q.isNotEmpty) {
      _searchController.text = q;
      WidgetsBinding.instance.addPostFrameCallback((_) => _runSearch());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _suggestDebounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchInteractions() async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final data = await api.getInteractions();
      if (mounted) setState(() => _interactions = data['interactions'] ?? []);
    } catch (_) {}
  }

  Future<void> _fetchPopular() async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final terms = await api.getPopularMedicationSearches();
      if (mounted && terms.isNotEmpty) setState(() => _popular = terms.take(8).toList());
    } catch (_) {}
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _suggestDebounce?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      _reset();
      return;
    }
    // Suggestions quasi instantanées, puis recherche complète un peu après.
    if (q.length >= 2) {
      _suggestDebounce = Timer(const Duration(milliseconds: 180), () => _fetchLiveSuggestions(q));
    } else {
      setState(() => _liveSuggestions = []);
    }
    _debounce = Timer(const Duration(milliseconds: 380), _runSearch);
  }

  Future<void> _fetchLiveSuggestions(String q) async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final list = await api.suggestMedications(q, limit: 5);
      if (!mounted || _searchController.text.trim() != q) return;
      setState(() => _liveSuggestions = list);
    } catch (_) {}
  }

  void _reset() {
    setState(() {
      _loading = false;
      _searched = false;
      _medications = [];
      _liveSuggestions = [];
      _didYouMean = null;
      _total = 0;
      _aiResult = null;
      _aiErrorMessage = null;
      _lastAiQuery = '';
    });
  }

  Future<void> _runSearch() async {
    if (!mounted) return;
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _reset();
      return;
    }

    final seq = ++_searchSeq;
    setState(() {
      _loading = true;
      _searched = true;
      _aiResult = null;
      _aiErrorMessage = null;
      _didYouMean = null;
    });

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final data = await api.searchMedications(query, limit: _maxResults);
      // Une réponse plus ancienne ne doit pas écraser la plus récente.
      if (!mounted || seq != _searchSeq) return;
      final raw = (data['medications'] as List<dynamic>?) ?? [];
      final suggestion = (data['didYouMean']?.toString() ?? '').trim();

      setState(() {
        _total = (data['total'] as num?)?.toInt() ?? raw.length;
        _didYouMean = suggestion.isEmpty || suggestion.toLowerCase() == query.toLowerCase() ? null : suggestion;
        _liveSuggestions = [];
      });

      if (raw.isEmpty) {
        setState(() => _medications = []);
        await _searchWithAI(forcedQuery: query, silent: true);
        return;
      }
      setState(() {
        _medications = raw.take(_maxResults).toList();
        _lastAiQuery = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _medications = []);
      AppSnackbar.error(context, AppSnackbar.clean(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _searchWithAI({String? forcedQuery, bool silent = false}) async {
    final query = (forcedQuery ?? _searchController.text).trim();
    if (query.length < 2 || _aiLoading) return;
    if (_lastAiQuery == query && _aiResult != null) return;

    setState(() {
      _aiLoading = true;
      _aiResult = null;
      _aiErrorMessage = null;
      _lastAiQuery = query;
    });
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final data = await api.searchMedicationWithAI(query);
      if (!mounted) return;
      if (data['error'] != null) {
        setState(() => _aiErrorMessage = data['error'].toString());
      } else {
        setState(() => _aiResult = data['aiResult'] as Map<String, dynamic>?);
      }
    } catch (e) {
      if (!mounted) return;
      final message = AppSnackbar.clean(e);
      setState(() => _aiErrorMessage = message.isEmpty ? 'Recherche IA indisponible' : message);
      if (!silent) AppSnackbar.warning(context, _aiErrorMessage!);
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  void _openDetail(Map<String, dynamic> med, String heroTag) {
    pushSlide(context, MedicationDetailScreen(medication: med, interactions: _interactions, heroTag: heroTag));
  }

  void _useSuggestion(String s) {
    _debounce?.cancel();
    _suggestDebounce?.cancel();
    _searchController.text = s;
    _searchController.selection = TextSelection.collapsed(offset: s.length);
    setState(() => _liveSuggestions = []);
    _runSearch();
  }

  /// Bandeau « Vouliez-vous dire … ? » affiché quand la correspondance est approximative.
  Widget? _didYouMeanBanner() {
    final suggestion = _didYouMean;
    if (suggestion == null) return null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: AppRadius.rMd,
        child: InkWell(
          borderRadius: AppRadius.rMd,
          onTap: () => _useSuggestion(suggestion),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.auto_fix_high_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: 'Vouliez-vous dire ',
                      children: [
                        TextSpan(text: suggestion, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
                        const TextSpan(text: ' ?'),
                      ],
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Suggestions d'autocomplétion (sous le champ) pendant la saisie.
  Widget _liveSuggestionsBar() {
    if (_liveSuggestions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, 6),
      child: SizedBox(
        height: 34,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _liveSuggestions.length,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final s = _liveSuggestions[i];
            final name = MedHelpers.safeString(s['name']);
            return ActionChip(
              avatar: const Icon(Icons.north_west_rounded, size: 14, color: AppColors.primary),
              label: Text(name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              onPressed: () => _useSuggestion(name),
            );
          },
        ),
      ),
    );
  }

  // ─────────────────────────────── Build ───────────────────────────────

  @override
  Widget build(BuildContext context) {
    final searchField = Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 8),
      child: AppSearchField(
        controller: _searchController,
        focusNode: _focusNode,
        hint: 'Nom d\'un médicament…',
        onChanged: _onQueryChanged,
        onSubmitted: (_) {
          _debounce?.cancel();
          _runSearch();
        },
        onClear: _reset,
        trailing: _loading
            ? const Padding(
                padding: EdgeInsets.only(right: 12),
                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : null,
      ),
    );

    final body = Column(
      children: [
        if (widget.embedded)
          PageHeader(
            title: 'Médicaments',
            subtitle: 'Catalogue, précautions et interactions',
            actions: [
              HeaderIconButton(
                icon: Icons.add_rounded,
                tooltip: 'Nouvelle ordonnance',
                onTap: () => pushSlide(context, const CreatePrescriptionScreen()),
              ),
            ],
          ),
        searchField,
        _liveSuggestionsBar(),
        Expanded(child: _buildContent()),
      ],
    );

    if (widget.embedded) {
      return Scaffold(backgroundColor: AppColors.background, body: SafeArea(bottom: false, child: body));
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppTopBar(title: 'Médicaments', subtitle: 'Catalogue, précautions et interactions'),
      body: body,
    );
  }

  Widget _buildContent() {
    if (!_searched) return _buildIdle();
    if (_loading) return const SkeletonList(count: 5, itemHeight: 88);
    if (_medications.isEmpty) return _buildNoResults();

    final banner = _didYouMeanBanner();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 100),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: _medications.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          final shown = _medications.length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ?banner,
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  _total > shown
                      ? '$shown résultats affichés sur $_total — affinez votre recherche'
                      : '$shown médicament${shown > 1 ? 's' : ''} trouvé${shown > 1 ? 's' : ''}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
        }
        final med = Map<String, dynamic>.from(_medications[index - 1] as Map);
        final tag = 'med-${med['id'] ?? index}-${med['name']}';
        return AnimatedFadeSlide(
          index: index - 1,
          child: _MedicationCard(med: med, heroTag: tag, onTap: () => _openDetail(med, tag)),
        );
      },
    );
  }

  Widget _buildIdle() {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, 100),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        AnimatedFadeSlide(
          index: 0,
          child: AppCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tout savoir sur vos médicaments', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(
                        'Description, posologie, précautions alimentaires et incompatibilités entre médicaments.',
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Image.asset(AppImages.safety, height: 96, fit: BoxFit.contain),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        AnimatedFadeSlide(
          index: 1,
          child: SectionTitle(title: 'Recherches populaires', padding: const EdgeInsets.only(bottom: 10)),
        ),
        AnimatedFadeSlide(
          index: 2,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _popular)
                ActionChip(
                  avatar: const Icon(Icons.search_rounded, size: 16, color: AppColors.primary),
                  label: Text(s),
                  onPressed: () => _useSuggestion(s),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        AnimatedFadeSlide(
          index: 3,
          child: AppCard(
            gradient: AppColors.aiGradient,
            onTap: () => _focusNode.requestFocus(),
            child: Row(
              children: [
                const IconBox(icon: Icons.auto_awesome_rounded, color: Colors.white, background: Color(0x33FFFFFF), size: 46),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Assistant IA', style: theme.textTheme.titleSmall?.copyWith(color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(
                        'Si un médicament n\'est pas dans le catalogue, l\'assistant vous propose une fiche indicative.',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.9), height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoResults() {
    final query = _searchController.text.trim();
    final banner = _didYouMeanBanner();
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, 100),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        ?banner,
        if (_aiLoading)
          const _AiSkeleton()
        else if (_aiResult != null)
          _AiResultCard(
            ai: _aiResult!,
            query: query,
            onAdd: () => pushSlide(
              context,
              CreatePrescriptionScreen(initialMedName: (_aiResult!['name'] ?? query).toString()),
            ),
          )
        else ...[
          EmptyState(
            image: AppImages.safety,
            imageHeight: 150,
            compact: true,
            title: 'Aucun résultat pour « $query »',
            subtitle: 'Ce médicament n\'est pas encore dans notre catalogue. Vérifiez l\'orthographe ou interrogez l\'assistant IA.',
            action: PrimaryButton(
              label: 'Demander à l\'assistant IA',
              icon: Icons.auto_awesome_rounded,
              backgroundColor: AppColors.ai,
              expanded: false,
              height: 46,
              onPressed: () => _searchWithAI(),
            ),
          ),
          if (_aiErrorMessage != null) ...[
            const SizedBox(height: 12),
            InfoBanner(color: AppColors.warning, icon: Icons.cloud_off_rounded, message: _aiErrorMessage!),
          ],
        ],
      ],
    );
  }
}

class _MedicationCard extends StatelessWidget {
  final Map<String, dynamic> med;
  final String heroTag;
  final VoidCallback onTap;

  const _MedicationCard({required this.med, required this.heroTag, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = MedHelpers.safeString(med['type']).trim();
    final desc = MedHelpers.safeString(med['description']).trim();
    final matchKind = MedHelpers.safeString(med['matchKind']).trim();
    final approx = matchKind == 'fuzzy' || matchKind == 'secondary';
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          Hero(
            tag: heroTag,
            child: MedicationImage(
              photoUrl: MedHelpers.photoForList(med['photoUrl']?.toString()),
              width: 60,
              height: 60,
              borderRadius: 16,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(MedHelpers.safeString(med['name'], 'Médicament'), style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                if (desc.isNotEmpty)
                  Text(desc, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (type.isNotEmpty) StatusBadge(label: type, type: StatusType.info, small: true),
                    if (approx) ...[
                      if (type.isNotEmpty) const SizedBox(width: 6),
                      const StatusBadge(label: 'orthographe proche', type: StatusType.warning, small: true),
                    ],
                    if (med['price'] != null && med['price'].toString().trim().isNotEmpty) ...[
                      if (type.isNotEmpty) const SizedBox(width: 6),
                      Text(med['price'].toString(), style: theme.textTheme.labelSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.mutedForeground),
        ],
      ),
    );
  }
}

class _AiSkeleton extends StatelessWidget {
  const _AiSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.ai)),
            const SizedBox(width: 12),
            Text('L\'assistant IA rédige une fiche…', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 16),
        const Shimmer(child: SkeletonCard(height: 180, withLeading: false)),
      ],
    );
  }
}

class _AiResultCard extends StatelessWidget {
  final Map<String, dynamic> ai;
  final String query;
  final VoidCallback onAdd;

  const _AiResultCard({required this.ai, required this.query, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = (ai['name'] ?? query).toString();
    final category = ai['category']?.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  gradient: AppColors.aiGradient,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    const IconBox(icon: Icons.auto_awesome_rounded, color: Colors.white, background: Color(0x33FFFFFF), size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Fiche générée par IA', style: theme.textTheme.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.85), letterSpacing: 0.6)),
                          const SizedBox(height: 2),
                          Text(name, style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
                        ],
                      ),
                    ),
                    if (category != null && category.isNotEmpty)
                      StatusBadge(label: category, type: StatusType.ai, small: true),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (ai['description'] != null) _AiRow(icon: Icons.info_outline_rounded, label: 'Description', value: ai['description'].toString(), color: AppColors.primary),
                    if (ai['dosage'] != null) _AiRow(icon: Icons.medication_rounded, label: 'Posologie', value: ai['dosage'].toString(), color: AppColors.secondary),
                    if (ai['precautions'] != null) _AiRow(icon: Icons.warning_amber_rounded, label: 'Précautions', value: ai['precautions'].toString(), color: AppColors.warning),
                    if (ai['sideEffects'] != null) _AiRow(icon: Icons.sick_outlined, label: 'Effets indésirables', value: ai['sideEffects'].toString(), color: AppColors.destructive),
                    const SizedBox(height: 6),
                    PrimaryButton(label: 'Ajouter au traitement', icon: Icons.add_rounded, onPressed: onAdd),
                    const SizedBox(height: 12),
                    Text(
                      'Ces informations sont générées par IA et ne remplacent pas l\'avis d\'un professionnel de santé.',
                      style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AiRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _AiRow({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBox(icon: icon, color: color, size: 36, iconSize: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelLarge?.copyWith(color: color)),
                const SizedBox(height: 3),
                Text(value, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
