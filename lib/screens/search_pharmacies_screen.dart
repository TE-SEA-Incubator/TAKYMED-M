import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/pharmacy_garde_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/med_helpers.dart';
import '../widgets/animated_fade_slide.dart';
import '../widgets/app_card.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/app_text_field.dart';
import '../widgets/icon_box.dart';
import '../widgets/loading_view.dart';
import '../widgets/page_header.dart';
import '../widgets/page_transitions.dart';
import '../widgets/primary_button.dart';
import '../widgets/skeleton.dart';
import '../widgets/status_badge.dart';
import 'pharmacy_details_screen.dart';

enum _Mode { nearby, city }

/// Pharmacies : à proximité (GPS, API TAKYMED) ou par ville (API pharmacies de garde).
class SearchPharmaciesScreen extends StatefulWidget {
  final bool embedded;

  const SearchPharmaciesScreen({super.key, this.embedded = false});

  @override
  State<SearchPharmaciesScreen> createState() => _SearchPharmaciesScreenState();
}

class _SearchPharmaciesScreenState extends State<SearchPharmaciesScreen> {
  _Mode _mode = _Mode.nearby;
  bool _onDutyOnly = false;
  final _filterController = TextEditingController();

  // ── À proximité ──
  List<PharmacyGarde> _nearby = [];
  bool _loadingNearby = false;
  String? _nearbyError;
  double? _userLat;
  double? _userLng;
  String? _locationCity;
  bool _locating = false;

  // ── Par ville ──
  List<PharmacyGarde> _cityResults = [];
  List<CityEntry> _cities = [];
  final _cityController = TextEditingController(text: 'Bafoussam');
  String _selectedCity = 'Bafoussam';
  bool _loadingCity = false;
  String? _cityError;
  String? _cityStatus; // ok | empty | unknown_city
  String? _cityMessage;
  String? _cityDidYouMean;
  bool _citySearched = false;

  @override
  void initState() {
    super.initState();
    _filterController.addListener(() => setState(() {}));
    _fetchNearby();
    _loadCities();
  }

  @override
  void dispose() {
    _filterController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  // ─────────────────────────────── Données ───────────────────────────────

  Future<void> _fetchNearby({bool force = false}) async {
    // Affichage immédiat depuis le cache si disponible ; le réseau ne sert qu'à rafraîchir.
    final cached = force ? null : PharmacyGardeService.cachedNearby(_userLat, _userLng);
    if (cached != null) {
      _applyNearby(cached);
      return;
    }
    setState(() {
      _loadingNearby = _nearby.isEmpty;
      _nearbyError = null;
    });
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final data = await api.searchNearbyPharmacies(lat: _userLat, lng: _userLng, limit: 80);
      PharmacyGardeService.rememberNearby(_userLat, _userLng, data);
      if (mounted) _applyNearby(data);
    } catch (e) {
      if (mounted) {
        setState(() {
          _nearby = [];
          _nearbyError = AppSnackbar.clean(e);
        });
      }
    } finally {
      if (mounted) setState(() => _loadingNearby = false);
    }
  }

  void _applyNearby(Map<String, dynamic> data) {
    final allNearby = (data['allNearby'] as List<dynamic>?) ?? [];
    final onDuty = (data['onDuty'] as List<dynamic>?) ?? [];
    final seen = <String>{};
    final list = <PharmacyGarde>[];

    String keyOf(Map<String, dynamic> p) {
      final id = (p['id'] ?? p['id_pharmacie'] ?? '').toString();
      return id.isNotEmpty ? 'id_$id' : 'name_${p['name'] ?? p['nom_pharmacie'] ?? ''}';
    }

    for (final raw in allNearby) {
      final p = Map<String, dynamic>.from(raw as Map);
      if (seen.add(keyOf(p))) list.add(PharmacyGarde.fromNearby(p));
    }
    for (final raw in onDuty) {
      final p = Map<String, dynamic>.from(raw as Map)..['est_garde'] = true;
      if (seen.add(keyOf(p))) list.add(PharmacyGarde.fromNearby(p));
    }

    setState(() {
      _nearby = list;
      _nearbyError = null;
      _loadingNearby = false;
      _locationCity = data['location']?['city']?.toString();
    });
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos == null) {
        if (mounted) AppSnackbar.warning(context, 'Autorisez la localisation pour trier par proximité');
        return;
      }
      setState(() {
        _userLat = pos.latitude;
        _userLng = pos.longitude;
      });
      await _fetchNearby();
    } catch (_) {
      if (mounted) AppSnackbar.error(context, 'Impossible d\'obtenir la position. Réessayez.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _clearLocation() {
    setState(() {
      _userLat = null;
      _userLng = null;
      _locationCity = null;
    });
    _fetchNearby();
  }

  Future<void> _loadCities() async {
    try {
      final cities = await PharmacyGardeService.getCities();
      if (mounted) setState(() => _cities = cities);
    } catch (_) {}
  }

  Future<void> _searchCity({bool force = false}) async {
    final city = _cityController.text.trim();
    if (city.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loadingCity = true;
      _cityError = null;
      _selectedCity = city;
      _citySearched = true;
    });
    try {
      final result = await PharmacyGardeService.searchByCity(city, force: force);
      if (mounted) {
        setState(() {
          _cityResults = result.pharmacies;
          _cityStatus = result.status;
          _cityMessage = result.message;
          _cityDidYouMean = result.didYouMean;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cityError = AppSnackbar.clean(e));
    } finally {
      if (mounted) setState(() => _loadingCity = false);
    }
  }

  /// Filtre local insensible aux accents et à la casse ; chaque mot saisi doit
  /// apparaître dans le nom, l'adresse ou la ville (« pharm soleil » → « Pharmacie du Soleil »).
  List<PharmacyGarde> _applyFilters(List<PharmacyGarde> source) {
    var list = source;
    if (_onDutyOnly) list = list.where((p) => p.isOnDuty).toList();
    final tokens = normalizeSearchText(_filterController.text).split(' ').where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return list;
    return list.where((p) => tokens.every(p.searchKey.contains)).toList();
  }

  void _useCitySuggestion(String city) {
    _cityController.text = city;
    _searchCity();
  }

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:${phone.replaceAll(RegExp(r'\s'), '')}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _openDetails(PharmacyGarde p) => pushSlide(context, PharmacyDetailsScreen(pharmacy: p));

  // ─────────────────────────────── Build ───────────────────────────────

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        if (widget.embedded) const PageHeader(title: 'Pharmacies', subtitle: 'Autour de vous et de garde'),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 10),
          child: _ModeSwitch(mode: _mode, onChanged: (m) => setState(() => _mode = m)),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: AppDurations.normal,
            child: KeyedSubtree(key: ValueKey(_mode), child: _mode == _Mode.nearby ? _buildNearby() : _buildCity()),
          ),
        ),
      ],
    );

    if (widget.embedded) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(bottom: false, child: body),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppTopBar(title: 'Pharmacies', subtitle: 'Autour de vous et de garde'),
      body: body,
    );
  }

  Widget _filtersBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, 8),
      child: Row(
        children: [
          Expanded(
            child: AppSearchField(
              controller: _filterController,
              hint: 'Filtrer par nom ou quartier…',
              onClear: () => _filterController.clear(),
            ),
          ),
          const SizedBox(width: 8),
          _DutyToggle(active: _onDutyOnly, onChanged: (v) => setState(() => _onDutyOnly = v)),
        ],
      ),
    );
  }

  /// Liste paresseuse : seules les cartes visibles sont construites, et seules
  /// les premières sont animées (une liste de 80 cartes toutes animées avec un
  /// décalage cumulé figeait l'écran plusieurs secondes).
  Widget _lazyList({required Future<void> Function() onRefresh, required List<Widget> header, required List<PharmacyGarde> items}) {
    const animatedCount = 8;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: header.length + items.length,
        itemBuilder: (context, index) {
          if (index < header.length) return header[index];
          final i = index - header.length;
          final p = items[i];
          final card = _PharmacyCard(
            pharmacy: p,
            rank: i + 1,
            onTap: () => _openDetails(p),
            onCall: p.phones.isNotEmpty ? () => _call(p.phones.first) : null,
          );
          return Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, 10),
            child: i < animatedCount
                ? AnimatedFadeSlide(key: ValueKey('anim_${p.osmId}_$i'), index: i, duration: const Duration(milliseconds: 320), child: card)
                : card,
          );
        },
      ),
    );
  }

  Widget _buildNearby() {
    final list = _applyFilters(_nearby);
    return _lazyList(
      onRefresh: () => _fetchNearby(force: true),
      items: _loadingNearby || _nearbyError != null || list.isEmpty ? const [] : list,
      header: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, 12),
          child: _LocationCard(
            locating: _locating,
            hasPosition: _userLat != null,
            city: _locationCity,
            onLocate: _locate,
            onClear: _clearLocation,
          ),
        ),
        _filtersBar(),
        if (_loadingNearby)
          const SkeletonList(count: 5, itemHeight: 84)
        else if (_nearbyError != null)
          ErrorState(message: _nearbyError!, onRetry: _fetchNearby)
        else if (list.isEmpty)
          EmptyState(
            image: AppImages.emptyPharmacies,
            imageHeight: 150,
            compact: true,
            title: _onDutyOnly ? 'Aucune pharmacie de garde' : 'Aucune pharmacie trouvée',
            subtitle: _locationCity != null
                ? 'Rien à afficher autour de $_locationCity pour le moment.'
                : 'Activez la localisation ou essayez la recherche par ville.',
            action: _onDutyOnly
                ? SecondaryButton(
                    label: 'Voir toutes les pharmacies',
                    expanded: false,
                    height: 46,
                    onPressed: () => setState(() => _onDutyOnly = false),
                  )
                : SecondaryButton(
                    label: 'Rechercher par ville',
                    icon: Icons.location_city_rounded,
                    expanded: false,
                    height: 46,
                    onPressed: () => setState(() => _mode = _Mode.city),
                  ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 8),
            child: Text(
              '${list.length} pharmacie${list.length > 1 ? 's' : ''}${_userLat != null ? ' · triées par distance' : ''}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }

  Widget _buildCity() {
    final list = _applyFilters(_cityResults);
    final theme = Theme.of(context);
    final showList = _citySearched && !_loadingCity && _cityError == null && _cityStatus != 'unknown_city' && list.isNotEmpty;
    return _lazyList(
      onRefresh: () => _searchCity(force: true),
      items: showList ? list : const [],
      header: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, 12),
          child: AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const IconBox(icon: Icons.location_city_rounded, size: 40, iconSize: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Rechercher par ville', style: theme.textTheme.titleSmall),
                          Text('Pharmacies référencées sur OpenStreetMap', style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _cityAutocomplete()),
                    const SizedBox(width: 8),
                    // Largeur explicite : le thème impose minimumSize = Size.fromHeight(54)
                    // (largeur infinie), ce qui fait planter le layout dans une Row.
                    SizedBox(
                      width: 54,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loadingCity ? null : _searchCity,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(54, 50),
                          fixedSize: const Size(54, 50),
                        ),
                        child: _loadingCity
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.search_rounded),
                      ),
                    ),
                  ],
                ),
                if (_cities.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _cities.length.clamp(0, 12),
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (_, i) {
                        final c = _cities[i];
                        final selected = normalizeSearchText(c.city) == normalizeSearchText(_selectedCity);
                        return ChoiceChip(
                          label: Text(c.city),
                          selected: selected,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: selected ? AppColors.primary : AppColors.foreground,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          onSelected: (_) {
                            _cityController.text = c.city;
                            _searchCity();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_citySearched) _filtersBar(),
        if (_loadingCity)
          const SkeletonList(count: 5, itemHeight: 84)
        else if (_cityError != null)
          ErrorState(message: _cityError!, onRetry: _searchCity)
        else if (!_citySearched)
          EmptyState(
            image: AppImages.emptyPharmacies,
            imageHeight: 160,
            compact: true,
            title: 'Choisissez une ville',
            subtitle: 'Saisissez une ville pour afficher les pharmacies référencées.',
          )
        else if (_cityStatus == 'unknown_city')
          EmptyState(
            icon: Icons.search_off_rounded,
            compact: true,
            title: 'Ville « $_selectedCity » introuvable',
            subtitle: 'Vérifiez l\'orthographe ou choisissez une ville dans la liste.',
            action: _cityDidYouMean != null
                ? SecondaryButton(
                    label: 'Vouliez-vous dire « $_cityDidYouMean » ?',
                    icon: Icons.auto_fix_high_rounded,
                    expanded: false,
                    height: 46,
                    onPressed: () => _useCitySuggestion(_cityDidYouMean!),
                  )
                : null,
          )
        else if (_cityResults.isEmpty)
          EmptyState(
            image: AppImages.emptyPharmacies,
            imageHeight: 150,
            compact: true,
            title: 'Aucune pharmacie à $_selectedCity',
            subtitle: 'Les données proviennent d\'OpenStreetMap ; la couverture peut être partielle.',
            action: _cityDidYouMean != null
                ? SecondaryButton(
                    label: 'Essayer « $_cityDidYouMean »',
                    icon: Icons.auto_fix_high_rounded,
                    expanded: false,
                    height: 46,
                    onPressed: () => _useCitySuggestion(_cityDidYouMean!),
                  )
                : null,
          )
        else if (list.isEmpty)
          EmptyState(
            icon: Icons.filter_alt_off_rounded,
            compact: true,
            title: 'Aucun résultat',
            subtitle: 'Aucune pharmacie ne correspond à vos filtres.',
            action: SecondaryButton(
              label: 'Réinitialiser les filtres',
              expanded: false,
              height: 46,
              onPressed: () => setState(() {
                _onDutyOnly = false;
                _filterController.clear();
              }),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 8),
            child: Row(
              children: [
                Icon(
                  _cityStatus == 'ok' ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
                  size: 14,
                  color: AppColors.mutedForeground,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _cityMessage?.isNotEmpty == true
                        ? _cityMessage!
                        : '${list.length} pharmacie${list.length > 1 ? 's' : ''} à $_selectedCity',
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cityAutocomplete() {
    return Autocomplete<CityEntry>(
      optionsBuilder: (value) {
        final q = normalizeSearchText(value.text);
        if (q.isEmpty) return _cities;
        // Insensible aux accents : « yaounde » propose « Yaoundé »
        return _cities.where((c) => normalizeSearchText(c.city).contains(q) || normalizeSearchText(c.region).startsWith(q));
      },
      displayStringForOption: (c) => c.city,
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        if (controller.text.isEmpty && _cityController.text.isNotEmpty) controller.text = _cityController.text;
        return TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.search,
          onChanged: (v) => _cityController.text = v,
          onSubmitted: (_) {
            _cityController.text = controller.text;
            onSubmitted();
            _searchCity();
          },
          decoration: const InputDecoration(
            hintText: 'Entrez une ville…',
            prefixIcon: Icon(Icons.location_on_outlined, size: 20),
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        );
      },
      onSelected: (city) {
        _cityController.text = city.city;
        _searchCity();
      },
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 8,
          shadowColor: AppColors.foreground.withValues(alpha: 0.12),
          borderRadius: AppRadius.rMd,
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240, maxWidth: 280),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: options.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final city = options.elementAt(i);
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.location_on_rounded, size: 18, color: AppColors.primary),
                  title: Text(city.city, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text(city.region, style: const TextStyle(fontSize: 11.5)),
                  onTap: () => onSelected(city),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────── Widgets ───────────────────────────────

class _ModeSwitch extends StatelessWidget {
  final _Mode mode;
  final ValueChanged<_Mode> onChanged;
  const _ModeSwitch({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.muted, borderRadius: AppRadius.rMd),
      child: Row(
        children: [
          _tab(context, _Mode.nearby, 'À proximité', Icons.near_me_rounded),
          _tab(context, _Mode.city, 'Par ville', Icons.location_city_rounded),
        ],
      ),
    );
  }

  Widget _tab(BuildContext context, _Mode m, String label, IconData icon) {
    final selected = mode == m;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(m),
        child: AnimatedContainer(
          duration: AppDurations.fast,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: AppRadius.rSm,
            boxShadow: selected ? AppShadows.soft : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? AppColors.primary : AppColors.mutedForeground),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: selected ? AppColors.primary : AppColors.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DutyToggle extends StatelessWidget {
  final bool active;
  final ValueChanged<bool> onChanged;
  const _DutyToggle({required this.active, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: active ? 'Afficher toutes les pharmacies' : 'Pharmacies de garde uniquement',
      child: Material(
        color: active ? AppColors.warning : AppColors.surface,
        borderRadius: AppRadius.rMd,
        child: InkWell(
          onTap: () => onChanged(!active),
          borderRadius: AppRadius.rMd,
          child: AnimatedContainer(
            duration: AppDurations.fast,
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: AppRadius.rMd,
              border: Border.all(color: active ? AppColors.warning : AppColors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_moon_rounded, size: 18, color: active ? Colors.white : AppColors.warning),
                const SizedBox(width: 6),
                Text(
                  'Garde',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: active ? Colors.white : AppColors.foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final bool locating;
  final bool hasPosition;
  final String? city;
  final VoidCallback onLocate;
  final VoidCallback onClear;

  const _LocationCard({
    required this.locating,
    required this.hasPosition,
    required this.city,
    required this.onLocate,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!hasPosition) {
      return HeroCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pharmacies autour de vous', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(
                    'Partagez votre position pour trier les pharmacies par distance.',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.88), height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: locating ? 'Localisation…' : 'Ma position',
                    icon: Icons.my_location_rounded,
                    isLoading: locating,
                    expanded: false,
                    height: 42,
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    onPressed: locating ? null : onLocate,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Image.asset(AppImages.pharmacy, height: 90, fit: BoxFit.contain),
          ],
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          const IconBox(icon: Icons.near_me_rounded, color: AppColors.secondary, size: 40, iconSize: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(city != null ? 'Autour de $city' : 'Autour de vous', style: theme.textTheme.titleSmall),
                Text('Triées par proximité', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Actualiser',
            visualDensity: VisualDensity.compact,
            onPressed: locating ? null : onLocate,
            icon: locating
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh_rounded, color: AppColors.primary),
          ),
          IconButton(
            tooltip: 'Ne plus trier par proximité',
            visualDensity: VisualDensity.compact,
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, color: AppColors.mutedForeground),
          ),
        ],
      ),
    );
  }
}

class _PharmacyCard extends StatelessWidget {
  final PharmacyGarde pharmacy;
  final int rank;
  final VoidCallback onTap;
  final VoidCallback? onCall;

  const _PharmacyCard({required this.pharmacy, required this.rank, required this.onTap, this.onCall});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duty = pharmacy.isOnDuty;
    final accent = duty ? AppColors.warning : AppColors.primary;
    final location = MedHelpers.shortLocation(pharmacy.toLegacyMap()..['region'] = pharmacy.city);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
      onTap: onTap,
      child: Row(
        children: [
          Hero(
            tag: 'pharmacy-${pharmacy.osmId}-${pharmacy.name}',
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: AppRadius.rSm),
              alignment: Alignment.center,
              child: pharmacy.distanceKm != null
                  ? Text(
                      MedHelpers.formatDistanceShort(pharmacy.distanceKm),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: accent, height: 1.15),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(4),
                      child: Image.asset(
                        AppImages.pharmacyCard,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Icon(Icons.local_pharmacy_rounded, color: accent, size: 24),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(pharmacy.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                    ),
                    if (duty) ...[
                      const SizedBox(width: 6),
                      const StatusBadge(label: 'Garde', type: StatusType.warning, small: true, icon: Icons.shield_moon_rounded),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  pharmacy.address?.isNotEmpty == true ? pharmacy.address! : location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                if (pharmacy.phones.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.phone_rounded, size: 12, color: AppColors.secondary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          pharmacy.phones.first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(color: AppColors.secondary, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (onCall != null)
            IconButton(
              tooltip: 'Appeler',
              visualDensity: VisualDensity.compact,
              onPressed: onCall,
              icon: Icon(Icons.phone_in_talk_rounded, color: accent),
            )
          else
            const Icon(Icons.chevron_right_rounded, color: AppColors.mutedForeground),
        ],
      ),
    );
  }
}
