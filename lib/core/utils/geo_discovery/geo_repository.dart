import 'package:dio/dio.dart';

import 'geo_types.dart';

class DefaultGeoDiscoveryRepository implements GeoDiscoveryRepository {
  const DefaultGeoDiscoveryRepository(this._dataSource);

  final MarketplaceDataSource _dataSource;

  @override
  Future<GeoDiscoveryBatchResult<Map<String, Object?>>> searchNearby(
    GeoDiscoveryNormalizedQuery query, {
    CancelToken? cancelToken,
  }) {
    return _dataSource.searchNearby(query, cancelToken: cancelToken);
  }
}
