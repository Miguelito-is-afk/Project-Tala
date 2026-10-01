import 'package:flutter/material.dart';

class ProjectTalaMark extends StatelessWidget {
  const ProjectTalaMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.auto_awesome,
        size: size * 0.55,
        color: colors.onPrimaryContainer,
      ),
    );
  }
}
