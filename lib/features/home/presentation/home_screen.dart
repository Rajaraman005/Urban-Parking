import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_screen.dart';
import '../../messaging/presentation/messaging_controller.dart';
import '../../notifications/presentation/notification_controller.dart';
import '../data/home_discovery_actions.dart';
import 'home_nearby_filtering.dart';
import 'home_nearby_section.dart';

typedef _HomeHeroSlide = ({
  String image,
  String tag,
  String title,
  String subtitle,
  String route,
});

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeNearbyFilterSelection _selectedNearbyFilters =
      HomeNearbyFilterSelection.defaults;
  HomeNearbyVehicleFilter? _selectedVehicleFilter;

  static const _statusBarColor = Colors.white;
  static const _systemUiStyle = SystemUiOverlayStyle(
    statusBarColor: _statusBarColor,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  );

  static const List<_HomeHeroSlide> _slides = [
    (
      image: 'src/assets/home/carosel_img_1.jpg',
      tag: 'RENTALS',
      title: 'Rent Cars & Bikes',
      subtitle:
          'Premium vehicles at your doorstep - daily, weekly, or monthly plans',
      route: '/rental',
    ),
    (
      image: 'src/assets/home/carosel_img_2.jpg',
      tag: 'SERVICES',
      title: 'Expert Repairs',
      subtitle:
          'Car & bike servicing by certified mechanics - at your location',
      route: '/services',
    ),
    (
      image: 'src/assets/home/carosel_img_3.jpg',
      tag: 'PARKING',
      title: 'Smart Parking',
      subtitle:
          'Find & book secure parking spots instantly - covered & open options',
      route: '/search',
    ),
  ];

  void _toggleVehicleFilter(HomeNearbyVehicleFilter filter) {
    setState(() {
      _selectedVehicleFilter = _selectedVehicleFilter == filter ? null : filter;
    });
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(_systemUiStyle);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _systemUiStyle,
      child: AppScreen(
        padded: false,
        safeAreaBackgroundColor: _statusBarColor,
        child: Column(
          children: [
            const _HomeTopBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  const _HomeHeroCarousel(slides: _slides),
                  _DiscoveryActionBar(
                    onFiltersApplied: (filters) {
                      setState(() => _selectedNearbyFilters = filters);
                    },
                    selectedVehicleFilter: _selectedVehicleFilter,
                    selectedFilters: _selectedNearbyFilters,
                    onVehicleFilterChanged: _toggleVehicleFilter,
                  ),
                  HomeNearbySection(
                    filters: _selectedNearbyFilters,
                    vehicleFilter: _selectedVehicleFilter,
                    onClearVehicleFilter: () {
                      setState(() => _selectedVehicleFilter = null);
                    },
                    onResetFilters: () {
                      setState(
                        () => _selectedNearbyFilters =
                            HomeNearbyFilterSelection.defaults,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeroCarousel extends StatefulWidget {
  const _HomeHeroCarousel({required this.slides});

  final List<_HomeHeroSlide> slides;

  @override
  State<_HomeHeroCarousel> createState() => _HomeHeroCarouselState();
}

class _HomeHeroCarouselState extends State<_HomeHeroCarousel> {
  static const _autoPlayInterval = Duration(milliseconds: 4200);
  static const _pageAnimationDuration = Duration(milliseconds: 780);

  late final PageController _pageController;
  late int _virtualPage;
  Timer? _autoPlayTimer;
  bool _assetsReady = false;
  bool _isAnimating = false;
  bool _precacheStarted = false;

  @override
  void initState() {
    super.initState();
    _virtualPage = widget.slides.isEmpty ? 0 : widget.slides.length * 1000;
    _pageController = PageController(
      initialPage: _virtualPage,
      viewportFraction: 0.94,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precacheStarted && widget.slides.isNotEmpty) {
      _precacheStarted = true;
      unawaited(_precacheSlides(_resolveCacheWidth(context)));
    }
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _precacheSlides(int cacheWidth) async {
    try {
      await Future.wait([
        for (final slide in widget.slides)
          precacheImage(
            ResizeImage(AssetImage(slide.image), width: cacheWidth),
            context,
          ),
      ]);
    } catch (error) {
      debugPrint('Home hero image precache failed: $error');
    }

    if (!mounted) {
      return;
    }

    setState(() => _assetsReady = true);
    _restartAutoPlay();
  }

  int _resolveCacheWidth(BuildContext context) {
    final logicalWidth = MediaQuery.sizeOf(context).width;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return (logicalWidth * pixelRatio).round().clamp(720, 1600).toInt();
  }

  void _restartAutoPlay() {
    _autoPlayTimer?.cancel();
    if (!_assetsReady || widget.slides.length < 2) {
      return;
    }

    _autoPlayTimer = Timer.periodic(
      _autoPlayInterval,
      (_) => unawaited(_animateToNextSlide()),
    );
  }

  Future<void> _animateToNextSlide() async {
    if (_isAnimating ||
        !_pageController.hasClients ||
        widget.slides.length < 2) {
      return;
    }

    _isAnimating = true;
    try {
      await _pageController.animateToPage(
        _virtualPage + 1,
        duration: _pageAnimationDuration,
        curve: Curves.easeInOutCubic,
      );
    } catch (error) {
      debugPrint('Home hero auto-play failed: $error');
    } finally {
      _isAnimating = false;
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _autoPlayTimer?.cancel();
    }

    if (notification is ScrollEndNotification) {
      _restartAutoPlay();
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slides.isEmpty) {
      return const SizedBox.shrink();
    }

    final screenSize = MediaQuery.sizeOf(context);
    final carouselHeight = (screenSize.height * 0.23).clamp(174.0, 218.0);
    final cacheWidth = _resolveCacheWidth(context);

    return SizedBox(
      height: carouselHeight,
      child: _assetsReady
          ? NotificationListener<ScrollNotification>(
              onNotification: _handleScrollNotification,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() => _virtualPage = page);
                },
                itemBuilder: (context, index) {
                  final slideIndex = index % widget.slides.length;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 8,
                    ),
                    child: _HomeHeroCard(
                      slide: widget.slides[slideIndex],
                      cacheWidth: cacheWidth,
                      active: index == _virtualPage,
                    ),
                  );
                },
              ),
            )
          : const Padding(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: _HomeHeroSkeleton(),
            ),
    );
  }
}

class _HomeHeroCard extends StatelessWidget {
  const _HomeHeroCard({
    required this.slide,
    required this.cacheWidth,
    required this.active,
  });

  final _HomeHeroSlide slide;
  final int cacheWidth;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      scale: active ? 1 : 0.965,
      child: Semantics(
        button: true,
        label: '${slide.title}. ${slide.subtitle}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.go(slide.route),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image(
                    image: ResizeImage(
                      AssetImage(slide.image),
                      width: cacheWidth,
                    ),
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                    frameBuilder:
                        (context, child, frame, wasSynchronouslyLoaded) {
                          if (wasSynchronouslyLoaded || frame != null) {
                            return child;
                          }

                          return const ColoredBox(color: Color(0xFF0B0B0C));
                        },
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.02),
                          Colors.black.withValues(alpha: 0.18),
                          Colors.black.withValues(alpha: 0.88),
                        ],
                        stops: const [0.0, 0.48, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 18,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          slide.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          slide.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _HomeHeroButton(label: slide.tag),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeHeroButton extends StatelessWidget {
  const _HomeHeroButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF0B0B0C),
                fontSize: 12,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(width: 7),
            const Icon(
              Icons.arrow_forward_rounded,
              color: Color(0xFF0B0B0C),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeroSkeleton extends StatelessWidget {
  const _HomeHeroSkeleton();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: const DecoratedBox(
        decoration: BoxDecoration(color: Color(0xFF0B0B0C)),
        child: SizedBox.expand(),
      ),
    );
  }
}

class _DiscoveryActionBar extends StatelessWidget {
  const _DiscoveryActionBar({
    required this.onFiltersApplied,
    required this.onVehicleFilterChanged,
    required this.selectedFilters,
    required this.selectedVehicleFilter,
  });

  final ValueChanged<HomeNearbyFilterSelection> onFiltersApplied;
  final ValueChanged<HomeNearbyVehicleFilter> onVehicleFilterChanged;
  final HomeNearbyFilterSelection selectedFilters;
  final HomeNearbyVehicleFilter? selectedVehicleFilter;

  @override
  Widget build(BuildContext context) {
    final bikeAction = homeDiscoveryActions[0];
    final carAction = homeDiscoveryActions[1];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _DiscoveryActionButton(
              item: bikeAction,
              selected: selectedVehicleFilter == HomeNearbyVehicleFilter.bike,
              onTap: () => onVehicleFilterChanged(HomeNearbyVehicleFilter.bike),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _DiscoveryActionButton(
              item: carAction,
              selected: selectedVehicleFilter == HomeNearbyVehicleFilter.car,
              onTap: () => onVehicleFilterChanged(HomeNearbyVehicleFilter.car),
            ),
          ),
          const SizedBox(width: 10),
          _DiscoveryFilterButton(
            item: homeDiscoveryActions.firstWhere(
              (item) => item.id == 'filter',
            ),
            onFiltersApplied: onFiltersApplied,
            selectedFilters: selectedFilters,
          ),
        ],
      ),
    );
  }
}

class _DiscoveryActionButton extends StatelessWidget {
  const _DiscoveryActionButton({
    required this.item,
    required this.onTap,
    required this.selected,
  });

  final HomeDiscoveryActionItem item;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final icon = switch (item.id) {
      'bike' => Icons.two_wheeler_rounded,
      'car' => Icons.directions_car_rounded,
      _ => Icons.apps_rounded,
    };

    return Material(
      color: selected ? const Color(0xFF0B0B0C) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFF0B0B0C)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 46,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: selected ? Colors.white : const Color(0xFF0B0B0C),
                  size: 17,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF0B0B0C),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscoveryFilterButton extends StatelessWidget {
  const _DiscoveryFilterButton({
    required this.item,
    required this.onFiltersApplied,
    required this.selectedFilters,
  });

  final HomeDiscoveryActionItem item;
  final ValueChanged<HomeNearbyFilterSelection> onFiltersApplied;
  final HomeNearbyFilterSelection selectedFilters;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: item.label,
      child: SizedBox(
        width: 46,
        height: 46,
        child: Material(
          color: const Color(0xFF0B0B0C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _openFilterSheet(context),
            child: const Icon(
              Icons.tune_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),
        ),
      ),
    );
  }

  void _openFilterSheet(BuildContext context) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        useSafeArea: true,
        sheetAnimationStyle: const AnimationStyle(
          duration: Duration(milliseconds: 460),
          reverseDuration: Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ),
        barrierColor: Colors.black.withValues(alpha: 0.42),
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => _HomeFilterSheet(
          initialSelection: selectedFilters,
          onApply: (selection) {
            Navigator.of(sheetContext).pop();
            onFiltersApplied(selection);
          },
        ),
      ),
    );
  }
}

class _HomeFilterSheet extends StatefulWidget {
  const _HomeFilterSheet({
    required this.initialSelection,
    required this.onApply,
  });

  final HomeNearbyFilterSelection initialSelection;
  final ValueChanged<HomeNearbyFilterSelection> onApply;

  @override
  State<_HomeFilterSheet> createState() => _HomeFilterSheetState();
}

class _HomeFilterSheetState extends State<_HomeFilterSheet> {
  static const _sortOptions = [
    _FilterSortOption(
      label: 'Nearby',
      description: 'Shortest distance first',
      icon: Icons.near_me_outlined,
      value: HomeNearbySortOption.nearby,
    ),
    _FilterSortOption(
      label: 'Low price',
      description: 'Best value options',
      icon: Icons.currency_rupee_rounded,
      value: HomeNearbySortOption.lowPrice,
    ),
    _FilterSortOption(
      label: 'High rated',
      description: 'Top reviewed spaces',
      icon: Icons.star_rounded,
      value: HomeNearbySortOption.highRated,
    ),
  ];

  static const _quickFilters = [
    _QuickFilterOption(
      label: 'Available now',
      icon: Icons.flash_on_rounded,
      value: HomeNearbyQuickFilter.availableNow,
    ),
    _QuickFilterOption(
      label: 'Covered',
      icon: Icons.roofing_rounded,
      value: HomeNearbyQuickFilter.covered,
    ),
    _QuickFilterOption(
      label: 'EV charging',
      icon: Icons.ev_station_rounded,
      value: HomeNearbyQuickFilter.evCharging,
    ),
    _QuickFilterOption(
      label: 'Security',
      icon: Icons.verified_user_outlined,
      value: HomeNearbyQuickFilter.security,
    ),
  ];

  late Set<HomeNearbyQuickFilter> _selectedFilters;
  late HomeNearbySortOption _selectedSort;

  @override
  void initState() {
    super.initState();
    _selectedSort = widget.initialSelection.sort;
    _selectedFilters = {...widget.initialSelection.quickFilters};
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE4E4E7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const SizedBox(width: 44, height: 5),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Filters',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Color(0xFF0B0B0C),
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                                letterSpacing: 0,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Tune nearby results fast.',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close filters',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Sort by',
                    style: TextStyle(
                      color: Color(0xFF0B0B0C),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final option in _sortOptions) ...[
                    _FilterSortTile(
                      option: option,
                      selected: _selectedSort == option.value,
                      onTap: () => setState(() => _selectedSort = option.value),
                    ),
                    if (option != _sortOptions.last) const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 20),
                  const Text(
                    'Quick filters',
                    style: TextStyle(
                      color: Color(0xFF0B0B0C),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in _quickFilters)
                        _QuickFilterChip(
                          option: option,
                          selected: _selectedFilters.contains(option.value),
                          onTap: () => _toggleQuickFilter(option.value),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _reset,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            foregroundColor: const Color(0xFF0B0B0C),
                            side: const BorderSide(color: Color(0xFF0B0B0C)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: () => widget.onApply(_buildSelection()),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            backgroundColor: const Color(0xFF0B0B0C),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Apply filters'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleQuickFilter(HomeNearbyQuickFilter filter) {
    setState(() {
      if (_selectedFilters.contains(filter)) {
        _selectedFilters.remove(filter);
      } else {
        _selectedFilters.add(filter);
      }
    });
  }

  void _reset() {
    setState(() {
      _selectedSort = HomeNearbyFilterSelection.defaults.sort;
      _selectedFilters = {...HomeNearbyFilterSelection.defaults.quickFilters};
    });
  }

  HomeNearbyFilterSelection _buildSelection() {
    return HomeNearbyFilterSelection(
      quickFilters: Set.unmodifiable(_selectedFilters),
      sort: _selectedSort,
    );
  }
}

class _FilterSortTile extends StatelessWidget {
  const _FilterSortTile({
    required this.onTap,
    required this.option,
    required this.selected,
  });

  final VoidCallback onTap;
  final _FilterSortOption option;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF0B0B0C) : const Color(0xFFF7F7F8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? const Color(0xFF0B0B0C) : const Color(0xFFE4E4E7),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                option.icon,
                color: selected ? Colors.white : const Color(0xFF0B0B0C),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : const Color(0xFF0B0B0C),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      option.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.72)
                            : const Color(0xFF71717A),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedScale(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                scale: selected ? 1 : 0.72,
                child: Icon(
                  Icons.check_circle_rounded,
                  color: selected
                      ? const Color(0xFF82F126)
                      : Colors.transparent,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickFilterChip extends StatelessWidget {
  const _QuickFilterChip({
    required this.onTap,
    required this.option,
    required this.selected,
  });

  final VoidCallback onTap;
  final _QuickFilterOption option;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF0B0B0C) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? const Color(0xFF0B0B0C) : const Color(0xFFE4E4E7),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                option.icon,
                color: selected ? Colors.white : const Color(0xFF0B0B0C),
                size: 16,
              ),
              const SizedBox(width: 7),
              Text(
                option.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF0B0B0C),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterSortOption {
  const _FilterSortOption({
    required this.description,
    required this.icon,
    required this.label,
    required this.value,
  });

  final String description;
  final IconData icon;
  final String label;
  final HomeNearbySortOption value;
}

class _QuickFilterOption {
  const _QuickFilterOption({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final HomeNearbyQuickFilter value;
}

class _HomeTopBar extends ConsumerWidget {
  const _HomeTopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref
        .watch(conversationsProvider)
        .maybeWhen(
          data: (conversations) => conversations.fold<int>(
            0,
            (total, conversation) => total + conversation.unreadCount,
          ),
          orElse: () => 0,
        );
    final notificationUnreadCount = ref.watch(notificationUnreadCountProvider);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      child: SizedBox(
        height: 58,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'Lotzi',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: const Color(0xFF0B0B0C),
                          fontWeight: FontWeight.w900,
                          height: 1,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.favorite,
                      color: Color(0xFFE11D48),
                      size: 19,
                    ),
                  ],
                ),
              ),
              _TopBarNotificationButton(
                unreadCount: notificationUnreadCount,
                onTap: () => context.push('/notifications'),
              ),
              const SizedBox(width: 6),
              _TopBarMessageButton(
                unreadCount: unreadCount,
                onTap: () => context.push('/messages'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBarNotificationButton extends StatelessWidget {
  const _TopBarNotificationButton({
    required this.onTap,
    required this.unreadCount,
  });

  final VoidCallback onTap;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;

    return Semantics(
      button: true,
      label: hasUnread ? '$unreadCount unread notifications' : 'Notifications',
      child: Tooltip(
        message: 'Notifications',
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                highlightColor: Colors.black.withValues(alpha: 0.04),
                splashColor: Colors.black.withValues(alpha: 0.06),
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    Icons.notifications_none_rounded,
                    color: Color(0xFF0B0B0C),
                    size: 25,
                  ),
                ),
              ),
            ),
            if (hasUnread)
              Positioned(
                right: 1,
                top: 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: Center(
                      child: Text(
                        unreadCount > 9 ? '9+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopBarMessageButton extends StatelessWidget {
  const _TopBarMessageButton({required this.onTap, required this.unreadCount});

  final VoidCallback onTap;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;

    return Semantics(
      button: true,
      label: hasUnread ? '$unreadCount unread messages' : 'Messages',
      child: Tooltip(
        message: 'Messages',
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                highlightColor: Colors.black.withValues(alpha: 0.04),
                splashColor: Colors.black.withValues(alpha: 0.06),
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CustomPaint(
                        painter: _PaperPlaneMessageIconPainter(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (hasUnread)
              Positioned(
                right: 0,
                top: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: Center(
                      child: Text(
                        unreadCount > 9 ? '9+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PaperPlaneMessageIconPainter extends CustomPainter {
  const _PaperPlaneMessageIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..isAntiAlias = true
      ..color = const Color(0xFF0B0B0C)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = (size.shortestSide * 0.068).clamp(1.7, 1.9);

    Offset point(double x, double y) => Offset(size.width * x, size.height * y);

    final body = Path()
      ..moveTo(point(0.10, 0.45).dx, point(0.10, 0.45).dy)
      ..lineTo(point(0.86, 0.16).dx, point(0.86, 0.16).dy)
      ..lineTo(point(0.58, 0.88).dx, point(0.58, 0.88).dy)
      ..lineTo(point(0.41, 0.58).dx, point(0.41, 0.58).dy)
      ..close();

    final fold = Path()
      ..moveTo(point(0.41, 0.58).dx, point(0.41, 0.58).dy)
      ..lineTo(point(0.86, 0.16).dx, point(0.86, 0.16).dy);

    canvas.drawPath(body, stroke);
    canvas.drawPath(fold, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
