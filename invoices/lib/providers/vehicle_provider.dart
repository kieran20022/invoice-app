import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/vehicle.dart';
import '../services/firestore_service.dart';

class VehicleProvider extends ChangeNotifier {
  final FirestoreService _firestore = FirestoreService();

  List<Vehicle> _vehicles = [];
  bool _isLoaded = false;
  String? _userId;
  StreamSubscription<List<Vehicle>>? _sub;

  List<Vehicle> get vehicles => _vehicles;
  bool get isLoaded => _isLoaded;

  void setUserId(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _sub?.cancel();
    _vehicles = [];
    _isLoaded = false;

    if (userId == null) {
      notifyListeners();
      return;
    }

    _sub = _firestore.vehiclesStream(userId).listen(
      (vehicles) {
        _vehicles = vehicles;
        _isLoaded = true;
        notifyListeners();
      },
      onError: (_) {
        _isLoaded = true;
        notifyListeners();
      },
    );
  }

  Future<void> saveVehicle(Vehicle vehicle) async {
    if (_userId == null) return;
    await _firestore.saveVehicle(_userId!, vehicle);
  }

  /// Removes the vehicle from the shop. The invoice it points at is kept —
  /// it stays available in the Facturen tab.
  Future<void> deleteVehicle(String vehicleId) async {
    if (_userId == null) return;
    await _firestore.deleteVehicle(_userId!, vehicleId);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
