import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_parking/core/utils/geo_discovery/geo_types.dart';
import 'package:urban_parking/shared/widgets/address_map_preview.dart';
import 'package:urban_parking/shared/widgets/address_search_map_picker.dart';

void main() {
  testWidgets('address picker keeps the search field editable while loading', (
    tester,
  ) async {
    final searchController = TextEditingController();
    addTearDown(searchController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AddressSearchMapPicker<String>(
            fallbackLocation: const GeoPoint(
              latitude: 13.0827,
              longitude: 80.2707,
            ),
            isLocating: false,
            isSearching: true,
            location: null,
            onLocationChanged: (_) {},
            onSearch: () {},
            onSuggestionSelected: (_) {},
            onUseCurrentLocation: () {},
            searchController: searchController,
            suggestionTitleBuilder: (suggestion) => suggestion,
            suggestions: const [],
          ),
        ),
      ),
    );

    expect(find.byTooltip('Search address'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.enterText(find.byType(TextFormField), 'Tirunelveli railway');
    await tester.pump();

    expect(searchController.text, 'Tirunelveli railway');
    expect(find.byTooltip('Clear search'), findsNothing);
  });

  testWidgets('address picker delegates search, clear, suggestions, and gps', (
    tester,
  ) async {
    final searchController = TextEditingController();
    addTearDown(searchController.dispose);

    var searchCount = 0;
    var clearCount = 0;
    var gpsCount = 0;
    var selectedSuggestion = '';
    GeoPoint? selectedLocation;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AddressSearchMapPicker<String>(
                fallbackLocation: const GeoPoint(
                  latitude: 13.0827,
                  longitude: 80.2707,
                ),
                isLocating: false,
                isSearching: false,
                location: null,
                onClearSearch: () {
                  clearCount += 1;
                  searchController.clear();
                },
                onLocationChanged: (location) {
                  selectedLocation = location;
                },
                onSearch: () => searchCount += 1,
                onSuggestionSelected: (suggestion) {
                  selectedSuggestion = suggestion;
                },
                onUseCurrentLocation: () => gpsCount += 1,
                searchController: searchController,
                suggestionTitleBuilder: (suggestion) => suggestion,
                suggestions: const ['Anna Salai, Chennai'],
              ),
            ),
          ),
        ),
      ),
    );

    final searchBottom = tester.getBottomLeft(find.byType(TextFormField)).dy;
    final suggestionTop = tester
        .getTopLeft(find.text('Anna Salai, Chennai'))
        .dy;
    final mapTop = tester.getTopLeft(find.byType(AddressMapPreview)).dy;
    expect(suggestionTop, greaterThan(searchBottom));
    expect(suggestionTop, lessThan(mapTop));

    await tester.tap(find.byTooltip('Search address'));
    await tester.pump();
    expect(searchCount, 1);

    await tester.tap(find.text('Anna Salai, Chennai'));
    await tester.pump();
    expect(selectedSuggestion, 'Anna Salai, Chennai');

    await tester.enterText(find.byType(TextFormField), 'T Nagar');
    await tester.pump();
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();
    expect(clearCount, 1);
    expect(searchController.text, isEmpty);

    await tester.tap(find.byTooltip('Use current location'));
    await tester.pump();
    expect(gpsCount, 1);

    expect(selectedLocation, isNull);
  });
}
