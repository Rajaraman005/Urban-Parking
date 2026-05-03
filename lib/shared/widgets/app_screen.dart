import 'package:flutter/material.dart';

class AppScreen extends StatelessWidget {
  const AppScreen({
    required this.child,
    super.key,
    this.padded = true,
    this.appBar,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.safeAreaBackgroundColor,
    this.safeAreaTop = true,
    this.safeAreaBottom = true,
  });

  final Widget child;
  final bool padded;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;
  final Color? safeAreaBackgroundColor;
  final bool safeAreaTop;
  final bool safeAreaBottom;

  @override
  Widget build(BuildContext context) {
    final bodyChild = padded
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: child,
          )
        : child;
    final effectiveBackground =
        backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;
    final body = safeAreaBackgroundColor == null
        ? SafeArea(top: safeAreaTop, bottom: safeAreaBottom, child: bodyChild)
        : ColoredBox(
            color: safeAreaBackgroundColor!,
            child: SafeArea(
              top: safeAreaTop,
              bottom: safeAreaBottom,
              child: ColoredBox(
                color: effectiveBackground,
                child: SizedBox.expand(child: bodyChild),
              ),
            ),
          );

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      body: body,
    );
  }
}
