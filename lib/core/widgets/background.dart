import 'package:flutter/material.dart';

/// Full-bleed clean white backdrop for the application.
class AppBackground extends StatelessWidget {
  const AppBackground({
    super.key,
    required this.child,
    this.grid = false,
    this.aurora = false,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final bool grid;
  final bool aurora;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: padding,
      child: child,
    );
  }
}
