import '../domain/rental_repository.dart';

class RentalRepositoryImpl implements RentalRepository {
  const RentalRepositoryImpl();

  @override
  Future<List<String>> loadHighlights() async => const [
    'Daily',
    'Monthly',
    'Commute',
  ];
}
