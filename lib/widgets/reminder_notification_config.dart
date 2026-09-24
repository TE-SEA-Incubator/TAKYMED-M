import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_card.dart';
import 'app_text_field.dart';

/// Icônes de marque (police Font Awesome Brands embarquée par font_awesome_flutter).
/// Exposées en [IconData] pour rester utilisables dans un `Icon` const.
class AppBrandIcons {
  AppBrandIcons._();

  /// Logo WhatsApp officiel (et non une bulle de message générique).
  static const IconData whatsapp = IconData(0xf232, fontFamily: 'FontAwesomeBrands', fontPackage: 'font_awesome_flutter');
}

/// Description d'un canal de notification (identifiants alignés sur l'API).
class NotificationChannel {
  final String id;
  final String label;
  final String description;
  final IconData icon;
  final Color color;

  const NotificationChannel({required this.id, required this.label, required this.description, required this.icon, required this.color});

  static const all = [
    NotificationChannel(
      id: 'push',
      label: 'Push',
      description: 'Notification sur ce téléphone',
      icon: Icons.notifications_rounded,
      color: Color(0xFF8B5CF6),
    ),
    NotificationChannel(
      id: 'whatsapp',
      label: 'WhatsApp',
      description: 'Message WhatsApp',
      icon: AppBrandIcons.whatsapp,
      color: Color(0xFF25D366),
    ),
    NotificationChannel(id: 'sms', label: 'SMS', description: 'Message texte classique', icon: Icons.sms_rounded, color: Color(0xFF0EA5E9)),
    NotificationChannel(
      id: 'call',
      label: 'Appel',
      description: 'Appel vocal automatique',
      icon: Icons.phone_in_talk_rounded,
      color: AppColors.primary,
    ),
  ];

  static NotificationChannel byId(String id) => all.firstWhere((c) => c.id == id, orElse: () => all.first);

  static String labelFor(String id) => byId(id).label;
}

/// Sélection des canaux et destinataires — même logique que l'étape 2 du web (Prescription.tsx).
class ReminderNotificationConfig extends StatelessWidget {
  final Set<String> channels;
  final ValueChanged<Set<String>> onChannelsChanged;
  final TextEditingController phoneController;
  final String phonePrefix;
  final bool showCard;

  const ReminderNotificationConfig({
    super.key,
    required this.channels,
    required this.onChannelsChanged,
    required this.phoneController,
    this.phonePrefix = '+237 ',
    this.showCard = true,
  });

  bool get needsPhone => channels.any((c) => c != 'push');

  static bool isValid(Set<String> channels, TextEditingController phone) {
    if (channels.isEmpty) return false;
    if (channels.any((c) => c != 'push') && phone.text.trim().isEmpty) return false;
    return true;
  }

  void _toggleChannel(String id) {
    final next = Set<String>.from(channels);
    if (next.contains(id)) {
      if (next.length > 1) next.remove(id);
    } else {
      next.add(id);
    }
    onChannelsChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CANAUX DE NOTIFICATION', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.8, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        ChannelSelector(channels: channels, onToggle: _toggleChannel),
        if (needsPhone) ...[
          const SizedBox(height: 20),
          Text('DESTINATAIRE', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.8, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          AppTextField(
            controller: phoneController,
            label: 'Téléphone destinataire',
            hint: '6 XX XX XX XX',
            prefixIcon: Icons.phone_rounded,
            prefixText: phonePrefix,
            keyboardType: TextInputType.phone,
            helper: 'Numéro qui recevra les SMS, messages WhatsApp ou appels.',
          ),
        ],
        const SizedBox(height: 16),
        const InfoBanner(message: 'Ces canaux s\'appliquent à cette ordonnance uniquement, comme sur la version web.'),
      ],
    );

    if (!showCard) return content;

    return SectionCard(
      title: 'Méthodes de rappel',
      subtitle: 'Choisissez comment recevoir chaque rappel',
      icon: Icons.notifications_active_rounded,
      child: content,
    );
  }
}

/// Grille de sélection des canaux (réutilisée dans le profil).
class ChannelSelector extends StatelessWidget {
  final Set<String> channels;
  final ValueChanged<String> onToggle;
  final bool disabled;

  const ChannelSelector({super.key, required this.channels, required this.onToggle, this.disabled = false});

  @override
  Widget build(BuildContext context) {
    // Deux colonnes de hauteur intrinsèque : une grille à ratio fixe débordait
    // dès que la carte était imbriquée ou que la police système était agrandie.
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final twoColumns = constraints.maxWidth >= 300;
        final itemWidth = twoColumns ? (constraints.maxWidth - gap) / 2 : constraints.maxWidth;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final c in NotificationChannel.all)
              SizedBox(
                width: itemWidth,
                child: _ChannelOption(channel: c, selected: channels.contains(c.id), onTap: disabled ? null : () => onToggle(c.id)),
              ),
          ],
        );
      },
    );
  }
}

class _ChannelOption extends StatelessWidget {
  final NotificationChannel channel;
  final bool selected;
  final VoidCallback? onTap;

  const _ChannelOption({required this.channel, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = channel.color;
    return Material(
      color: selected ? color.withValues(alpha: 0.1) : AppColors.surface,
      borderRadius: AppRadius.rMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.rMd,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          decoration: BoxDecoration(
            borderRadius: AppRadius.rMd,
            border: Border.all(color: selected ? color : AppColors.border, width: selected ? 1.8 : 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: selected ? color : color.withValues(alpha: 0.12), borderRadius: AppRadius.rSm),
                child: Icon(channel.icon, size: 18, color: selected ? Colors.white : color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: selected ? color : AppColors.foreground),
                    ),
                    Text(
                      channel.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5, color: AppColors.mutedForeground),
                    ),
                  ],
                ),
              ),
              if (selected) ...[const SizedBox(width: 4), Icon(Icons.check_circle_rounded, color: color, size: 18)],
            ],
          ),
        ),
      ),
    );
  }
}
