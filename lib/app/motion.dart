import 'package:flutter/material.dart';

const talaMotionDuration = Duration(milliseconds: 180);

Duration accessibleMotionDuration(
  BuildContext context, {
  Duration duration = talaMotionDuration,
}) {
  return MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}

class AnimatedValueText extends StatelessWidget {
  const AnimatedValueText(
    this.value, {
    required this.style,
    this.textAlign,
    this.valueKey,
    super.key,
  });

  final String value;
  final TextStyle style;
  final TextAlign? textAlign;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: accessibleMotionDuration(context),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: Text(
        value,
        key: valueKey ?? ValueKey(value),
        textAlign: textAlign,
        style: style,
      ),
    );
  }
}
