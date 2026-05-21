// lib/widgets/responsive_wrapper.dart
import 'package:flutter/material.dart';

class ResponsiveWrapper extends StatelessWidget {
  final Widget child;

  const ResponsiveWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Set a minimum width for web to prevent overflow
        if (constraints.maxWidth < 320) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              width: 320,
              child: child,
            ),
          );
        }
        return child;
      },
    );
  }
}