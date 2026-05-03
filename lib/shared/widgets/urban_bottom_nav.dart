import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class UrbanBottomNav extends StatelessWidget {
  const UrbanBottomNav({required this.currentIndex, super.key});

  final int currentIndex;

  static const _contentHeight = 56.0;
  static const _selectedIndicatorSize = 40.0;
  static const _selectedIndicatorTop = 2.0;

  static const destinations = [
    _Destination(label: 'Home', icon: Icons.home_outlined, route: '/home'),
    _Destination(
      label: 'Rent',
      icon: Icons.directions_car_outlined,
      route: '/rental',
    ),
    _Destination(label: 'Search', icon: Icons.search, route: '/search'),
    _Destination(
      label: 'Services',
      icon: Icons.auto_awesome_outlined,
      route: '/services',
    ),
    _Destination(
      label: 'Profile',
      icon: Icons.person_outline,
      route: '/profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final bottomPadding = bottomInset == 0
        ? 10.0
        : (bottomInset + 4).clamp(12.0, 22.0);
    final barHeight = _contentHeight + bottomPadding;

    return Material(
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / destinations.length;
          final safeIndex = currentIndex.clamp(0, destinations.length - 1);

          return SizedBox(
            height: barHeight,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: _contentHeight,
                  child: Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 560),
                        curve: Curves.easeInOutCubic,
                        left:
                            (safeIndex * itemWidth) +
                            ((itemWidth - _selectedIndicatorSize) / 2),
                        top: _selectedIndicatorTop,
                        width: _selectedIndicatorSize,
                        height: _selectedIndicatorSize,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFF0B0B0C),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          for (
                            var index = 0;
                            index < destinations.length;
                            index++
                          )
                            Expanded(
                              child: _BottomNavItem(
                                destination: destinations[index],
                                selected: index == safeIndex,
                                onTap: () => _selectDestination(context, index),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: bottomPadding,
                  child: const SizedBox.shrink(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _selectDestination(BuildContext context, int index) {
    final route = destinations[index].route;
    if (GoRouterState.of(context).matchedLocation != route) {
      context.go(route);
    }
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  static const _unselectedIconSize = 22.0;
  static const _selectedIconSize = _unselectedIconSize * 1.20;
  static const _iconSlotSize = 40.0;

  @override
  Widget build(BuildContext context) {
    final iconColor = selected ? Colors.white : const Color(0xFF0B0B0C);

    return InkResponse(
      onTap: onTap,
      radius: 38,
      containedInkWell: false,
      child: Semantics(
        button: true,
        selected: selected,
        label: destination.label,
        child: SizedBox(
          height: UrbanBottomNav._contentHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox(
                width: _iconSlotSize,
                height: _iconSlotSize,
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey('${destination.route}-$selected'),
                    tween: Tween(begin: selected ? -0.10 : 0, end: 0),
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutBack,
                    builder: (context, turn, child) {
                      return Transform.rotate(
                        angle: turn * 6.283185307179586,
                        child: child,
                      );
                    },
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeInOutCubic,
                      alignment: Alignment.center,
                      child: Icon(
                        destination.icon,
                        color: iconColor,
                        size: selected
                            ? _selectedIconSize
                            : _unselectedIconSize,
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedOpacity(
                opacity: selected ? 0 : 1,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOutCubic,
                child: Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0B0B0C),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1,
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

class _Destination {
  const _Destination({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final String route;
}
