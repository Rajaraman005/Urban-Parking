class HomeDiscoveryActionItem {
  const HomeDiscoveryActionItem({
    required this.id,
    required this.label,
    required this.route,
  });

  final String id;
  final String label;
  final String route;
}

const homeDiscoveryActions = [
  HomeDiscoveryActionItem(id: 'parking', label: 'Bike', route: '/search'),
  HomeDiscoveryActionItem(id: 'rental', label: 'Cars', route: '/rental'),
  HomeDiscoveryActionItem(id: 'filter', label: 'Filters', route: '/search'),
];
