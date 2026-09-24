import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Saisie de code PIN : champ invisible + cases visuelles, masquage optionnel.
class PinField extends StatefulWidget {
  final TextEditingController controller;
  final int length;
  final VoidCallback? onCompleted;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final bool obscure;
  final bool showToggle;
  final bool hasError;
  final bool enabled;

  const PinField({
    super.key,
    required this.controller,
    this.length = 6,
    this.onCompleted,
    this.onChanged,
    this.autofocus = true,
    this.obscure = true,
    this.showToggle = true,
    this.hasError = false,
    this.enabled = true,
  });

  @override
  State<PinField> createState() => _PinFieldState();
}

class _PinFieldState extends State<PinField> {
  late final FocusNode _focusNode;
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscure;
    _focusNode = FocusNode();
    _focusNode.addListener(_rebuild);
    widget.controller.addListener(_onChanged);
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _onChanged() {
    final text = widget.controller.text;
    if (text.length > widget.length) {
      widget.controller.text = text.substring(0, widget.length);
      widget.controller.selection = TextSelection.collapsed(offset: widget.length);
      return;
    }
    if (mounted) setState(() {});
    widget.onChanged?.call(widget.controller.text);
    if (widget.controller.text.length == widget.length) {
      _focusNode.unfocus();
      widget.onCompleted?.call();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focusNode.removeListener(_rebuild);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pin = widget.controller.text;
    final focused = _focusNode.hasFocus;

    return Column(
      children: [
        GestureDetector(
          onTap: widget.enabled ? () => _focusNode.requestFocus() : null,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              // Champ réel (invisible) qui reçoit la saisie clavier.
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    enabled: widget.enabled,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: widget.length,
                    showCursor: false,
                    enableInteractiveSelection: false,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(border: InputBorder.none, counterText: '', filled: false),
                  ),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  // Les cases s'adaptent à la largeur disponible (cartes imbriquées,
                  // petits écrans) au lieu d'une largeur fixe qui débordait.
                  final gap = widget.length > 4 ? 5.0 : 8.0;
                  final maxCell = widget.length > 4 ? 46.0 : 56.0;
                  final available = constraints.maxWidth.isFinite ? constraints.maxWidth : maxCell * widget.length;
                  final cell = ((available - gap * 2 * widget.length) / widget.length).clamp(28.0, maxCell);
                  final cellHeight = (cell * 1.26).clamp(40.0, 58.0);
                  final digitSize = (cell * 0.48).clamp(14.0, 22.0);

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(widget.length, (i) {
                      final filled = i < pin.length;
                      final active = focused && i == pin.length;
                      final borderColor = widget.hasError
                          ? AppColors.destructive
                          : (active || filled)
                          ? AppColors.primary
                          : AppColors.border;
                      return AnimatedContainer(
                        duration: AppDurations.fast,
                        margin: EdgeInsets.symmetric(horizontal: gap),
                        width: cell,
                        height: cellHeight,
                        decoration: BoxDecoration(
                          color: filled ? AppColors.primaryLight : AppColors.surface,
                          borderRadius: AppRadius.rMd,
                          border: Border.all(color: borderColor, width: (active || filled) ? 1.8 : 1.2),
                          boxShadow: active ? AppShadows.colored(AppColors.primary, alpha: 0.18) : null,
                        ),
                        alignment: Alignment.center,
                        child: filled
                            ? (_obscure
                                  ? Container(
                                      width: 12,
                                      height: 12,
                                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                    )
                                  : Text(
                                      pin[i],
                                      style: TextStyle(fontSize: digitSize, fontWeight: FontWeight.w800, color: AppColors.primary),
                                    ))
                            : active
                            ? _Caret()
                            : null,
                      );
                    }),
                  );
                },
              ),
            ],
          ),
        ),
        if (widget.showToggle) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => setState(() => _obscure = !_obscure),
            style: TextButton.styleFrom(foregroundColor: AppColors.mutedForeground),
            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
            label: Text(_obscure ? 'Afficher le code' : 'Masquer le code', style: const TextStyle(fontSize: 13)),
          ),
        ],
      ],
    );
  }
}

class _Caret extends StatefulWidget {
  @override
  State<_Caret> createState() => _CaretState();
}

class _CaretState extends State<_Caret> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _c,
      child: Container(
        width: 2,
        height: 24,
        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2)),
      ),
    );
  }
}
