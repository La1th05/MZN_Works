import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum TactileButtonVariant { primary, secondary, tertiary, neutral }

class TactileButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final TactileButtonVariant variant;
  final double height;
  final double? width;
  final double borderRadius;
  final double extrusionHeight;
  final TextStyle? textStyle;

  const TactileButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = TactileButtonVariant.primary,
    this.height = 54,
    this.width,
    this.borderRadius = 20,
    this.extrusionHeight = 4.0,
    this.textStyle,
  });

  @override
  State<TactileButton> createState() => _TactileButtonState();
}

class _TactileButtonState extends State<TactileButton> {
  bool _isPressed = false;

  (Color surface, Color extrusion, Color textColor) _getColors() {
    switch (widget.variant) {
      case TactileButtonVariant.primary:
        return (AppColors.primary, AppColors.onPrimaryContainer, Colors.white);
      case TactileButtonVariant.secondary:
        return (AppColors.secondaryContainer, AppColors.secondaryShadow, Colors.white);
      case TactileButtonVariant.tertiary:
        return (AppColors.sunnyYellow, AppColors.yellowShadow, AppColors.onTertiaryFixed);
      case TactileButtonVariant.neutral:
        return (AppColors.surfaceContainerHigh, AppColors.outlineVariant, AppColors.onSurface);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _getColors();

    return GestureDetector(
      onTapDown: widget.onPressed == null ? null : (_) => setState(() => _isPressed = true),
      onTapUp: widget.onPressed == null
          ? null
          : (_) {
              setState(() => _isPressed = false);
              widget.onPressed?.call();
            },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        width: widget.width,
        height: widget.height,
        margin: EdgeInsets.only(
          top: _isPressed ? widget.extrusionHeight : 0,
          bottom: _isPressed ? 0 : widget.extrusionHeight,
        ),
        decoration: BoxDecoration(
          color: colors.$1,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: [
            BoxShadow(
              color: colors.$2,
              offset: Offset(0, _isPressed ? 0 : widget.extrusionHeight),
              blurRadius: 0,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              widget.icon!,
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                widget.label,
                style: widget.textStyle ?? AppTypography.labelLg(color: colors.$3),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
