import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkStatusService {
  Future<bool> get isOnline async {
    final results = await Connectivity().checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }
}
