import '../domain/services_repository.dart';

class ServicesRepositoryImpl implements ServicesRepository {
  const ServicesRepositoryImpl();

  @override
  Future<List<String>> loadHighlights() async => const [
    'Support',
    'Access help',
    'Add-ons',
  ];
}
