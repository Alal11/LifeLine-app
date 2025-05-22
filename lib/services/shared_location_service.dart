import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class SharedLocationService with ChangeNotifier {
  LatLng? _sharedLocation;

  LatLng? get sharedLocation => _sharedLocation;

  void updateLocation(LatLng newLocation) {
    _sharedLocation = newLocation;
    notifyListeners();
  }
}