import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/emergency_vehicle_screen.dart';
import '../screens/regular_vehicle_screen.dart';

class AppRoutes {
  static const String home = '/';
  static const String emergencyVehicle = '/emergency-vehicle';
  static const String regularVehicle = '/regular-vehicle';

  static Map<String, WidgetBuilder> get routes {
    return {
      home: (context) => const HomePage(title: 'LifeLine'),
      emergencyVehicle: (context) => const EmergencyVehicleScreen(),
      regularVehicle: (context) => const RegularVehicleScreen(),
    };
  }
}
