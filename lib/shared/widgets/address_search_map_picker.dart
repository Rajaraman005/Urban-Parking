import 'package:flutter/material.dart';

import '../../core/utils/geo_discovery/geo_types.dart';
import 'address_map_preview.dart';

class AddressSearchMapPicker<T> extends StatelessWidget {
  const AddressSearchMapPicker({
    required this.fallbackLocation,
    required this.isLocating,
    required this.isSearching,
    required this.location,
    required this.onLocationChanged,
    required this.onSearch,
    required this.onSuggestionSelected,
    required this.onUseCurrentLocation,
    required this.searchController,
    required this.suggestionTitleBuilder,
    required this.suggestions,
    super.key,
    this.enabled = true,
    this.mapHeight = 184,
    this.maxSuggestions = 4,
    this.onClearSearch,
    this.onSearchChanged,
    this.searchLabel = 'Search your address',
    this.showSuggestionsAboveMap = true,
    this.suggestionSubtitleBuilder,
  });

  final bool enabled;
  final GeoPoint fallbackLocation;
  final bool isLocating;
  final bool isSearching;
  final GeoPoint? location;
  final double mapHeight;
  final int maxSuggestions;
  final VoidCallback? onClearSearch;
  final ValueChanged<GeoPoint> onLocationChanged;
  final VoidCallback? onSearch;
  final ValueChanged<String>? onSearchChanged;
  final ValueChanged<T>? onSuggestionSelected;
  final VoidCallback onUseCurrentLocation;
  final TextEditingController searchController;
  final String searchLabel;
  final bool showSuggestionsAboveMap;
  final String? Function(T suggestion)? suggestionSubtitleBuilder;
  final String Function(T suggestion) suggestionTitleBuilder;
  final List<T> suggestions;

  @override
  Widget build(BuildContext context) {
    final visibleSuggestions = suggestions
        .take(maxSuggestions)
        .toList(growable: false);
    final map = AddressMapPreview(
      fallback: fallbackLocation,
      height: mapHeight,
      isLocating: isLocating,
      location: location,
      onLocationChanged: onLocationChanged,
      onUseCurrentLocation: onUseCurrentLocation,
    );
    final suggestionList = _AddressSuggestionList<T>(
      onSuggestionSelected: onSuggestionSelected,
      suggestionSubtitleBuilder: suggestionSubtitleBuilder,
      suggestionTitleBuilder: suggestionTitleBuilder,
      suggestions: visibleSuggestions,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AddressSearchInput(
          controller: searchController,
          enabled: enabled,
          isSearching: isSearching,
          label: searchLabel,
          onChanged: onSearchChanged,
          onClear: onClearSearch,
          onSearch: onSearch,
        ),
        if (showSuggestionsAboveMap && visibleSuggestions.isNotEmpty) ...[
          const SizedBox(height: 6),
          suggestionList,
          const SizedBox(height: 12),
        ] else
          const SizedBox(height: 12),
        map,
        if (!showSuggestionsAboveMap && visibleSuggestions.isNotEmpty) ...[
          const SizedBox(height: 12),
          suggestionList,
        ],
      ],
    );
  }
}

class _AddressSearchInput extends StatelessWidget {
  const _AddressSearchInput({
    required this.controller,
    required this.enabled,
    required this.isSearching,
    required this.label,
    required this.onChanged,
    required this.onClear,
    required this.onSearch,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool isSearching;
  final String label;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) {
    final canSearch = enabled && !isSearching && onSearch != null;
    return SizedBox(
      height: _searchControlHeight,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final hasText = value.text.trim().isNotEmpty;
          return TextFormField(
            controller: controller,
            enabled: enabled,
            decoration: _inputDecoration(
              canSearch: canSearch,
              label: label,
              onClear: hasText ? onClear : null,
              onSearch: onSearch,
            ),
            style: _fieldTextStyle,
            textAlignVertical: TextAlignVertical.center,
            textInputAction: TextInputAction.search,
            onChanged: onChanged,
            onFieldSubmitted: canSearch && hasText ? (_) => onSearch!() : null,
          );
        },
      ),
    );
  }

  InputDecoration _inputDecoration({
    required bool canSearch,
    required String label,
    required VoidCallback? onClear,
    required VoidCallback? onSearch,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF8F8FA),
      hintText: label,
      hintStyle: const TextStyle(
        color: Color(0xFF6B7280),
        fontSize: 13,
        fontWeight: FontWeight.w800,
        height: 1.15,
        letterSpacing: 0,
      ),
      prefixIcon: IconButton(
        tooltip: 'Search address',
        onPressed: canSearch && onSearch != null ? onSearch : null,
        icon: const Icon(Icons.search_rounded, size: 21),
        color: const Color(0xFF18181B),
        disabledColor: const Color(0xFFA1A1AA),
        splashRadius: 21,
      ),
      prefixIconConstraints: const BoxConstraints(
        minHeight: _searchControlHeight,
        minWidth: _searchControlHeight,
      ),
      suffixIcon: onClear == null
          ? null
          : IconButton(
              tooltip: 'Clear search',
              onPressed: enabled ? onClear : null,
              icon: const Icon(Icons.close_rounded, size: 20),
              color: const Color(0xFF71717A),
              splashRadius: 21,
            ),
      suffixIconConstraints: const BoxConstraints(
        minHeight: _searchControlHeight,
        minWidth: _searchControlHeight,
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF0B0B0C), width: 1.4),
      ),
    );
  }
}

class _AddressSuggestionList<T> extends StatelessWidget {
  const _AddressSuggestionList({
    required this.onSuggestionSelected,
    required this.suggestionSubtitleBuilder,
    required this.suggestionTitleBuilder,
    required this.suggestions,
  });

  final ValueChanged<T>? onSuggestionSelected;
  final String? Function(T suggestion)? suggestionSubtitleBuilder;
  final String Function(T suggestion) suggestionTitleBuilder;
  final List<T> suggestions;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < suggestions.length; index++) ...[
              _AddressSuggestionTile<T>(
                onTap: onSuggestionSelected == null
                    ? null
                    : () => onSuggestionSelected!(suggestions[index]),
                subtitle: suggestionSubtitleBuilder?.call(suggestions[index]),
                title: suggestionTitleBuilder(suggestions[index]),
              ),
              if (index != suggestions.length - 1)
                const Divider(
                  height: 1,
                  indent: 46,
                  endIndent: 12,
                  color: Color(0xFFE5E7EB),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddressSuggestionTile<T> extends StatelessWidget {
  const _AddressSuggestionTile({
    required this.onTap,
    required this.subtitle,
    required this.title,
  });

  final VoidCallback? onTap;
  final String? subtitle;
  final String title;

  @override
  Widget build(BuildContext context) {
    final subtitleText = subtitle?.trim();
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: Color(0xFF18181B),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: subtitleText == null || subtitleText.isEmpty
                          ? 2
                          : 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF18181B),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                        letterSpacing: 0,
                      ),
                    ),
                    if (subtitleText != null && subtitleText.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitleText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF71717A),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.north_west_rounded,
                color: Color(0xFFA1A1AA),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _fieldTextStyle = TextStyle(
  color: Color(0xFF18181B),
  fontSize: 15,
  fontWeight: FontWeight.w700,
  height: 1.15,
  letterSpacing: 0,
);

const _searchControlHeight = 50.0;
