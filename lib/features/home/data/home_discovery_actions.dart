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
  HomeDiscoveryActionItem(id: 'bike', label: 'Bike', route: '/search'),
  HomeDiscoveryActionItem(id: 'car', label: 'Cars', route: '/search'),
  HomeDiscoveryActionItem(id: 'filter', label: 'Filters', route: '/search'),
];
