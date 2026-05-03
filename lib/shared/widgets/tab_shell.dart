import 'package:flutter/material.dart';

import 'urban_bottom_nav.dart';

class TabShell extends StatelessWidget {
  const TabShell({required this.currentIndex, required this.child, super.key});

  final int currentIndex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: UrbanBottomNav(currentIndex: currentIndex),
    );
  }
}
