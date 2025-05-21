import 'dart:async';
import 'dart:math' as math;
import '../models/emergency_route.dart';
import 'location_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'optimal_route_service.dart';

class RouteService {
  // 싱글톤 패턴 구현
  static final RouteService _instance = RouteService._internal();

  factory RouteService() {
    return _instance;
  }

  RouteService._internal();

  // 위치 서비스 인스턴스
  final LocationService _locationService = LocationService();

  // 더미 경로 생성
  Future<List<LatLng>> generateRoute(LatLng origin, LatLng destination) async {
    // 시작점과 끝점 사이에 중간 포인트를 생성해 경로 시뮬레이션
    final List<LatLng> route = [];

    // 시작점 추가
    route.add(origin);

    // 중간 포인트 추가 (직선이 아닌 약간의 변형 추가)
    const int steps = 5;
    for (int i = 1; i < steps; i++) {
      final double fraction = i / steps;

      // 기본 경로 포인트
      final double lat =
          origin.latitude + (destination.latitude - origin.latitude) * fraction;
      final double lng =
          origin.longitude +
          (destination.longitude - origin.longitude) * fraction;

      // 약간의 랜덤 편차 추가 (실제 도로처럼 보이게)
      final double variance = 0.002 * math.sin(fraction * math.pi);
      final double adjustedLat =
          lat + variance * math.cos(fraction * 5 * math.pi);
      final double adjustedLng =
          lng + variance * math.sin(fraction * 5 * math.pi);

      route.add(LatLng(adjustedLat, adjustedLng));
    }

    // 목적지 추가
    route.add(destination);

    // 네트워크 지연 시뮬레이션
    await Future.delayed(const Duration(milliseconds: 800));

    return route;
  }

  // 최적의 경로 계산
  Future<Map<String, dynamic>> calculateOptimalRoute(
      LatLng origin,
      LatLng destination, {
        bool isEmergency = false,
      }) async {
    List<LatLng> routePoints;

    try {
      // Google Maps Directions API 호출
      final optimalRouteService = OptimalRouteService(); // 이미 싱글톤 패턴이므로 생성자만 호출
      final result = await optimalRouteService.findOptimalRouteAndHospital(
        currentLocation: origin,
        patientCondition: 'emergency', // 기본값
        patientSeverity: '중증',      // 기본값
      );

      if (result['success'] == true && result['routePoints'] != null) {
        routePoints = result['routePoints'] as List<LatLng>;
      } else {
        // Google 경로를 직접 가져오기
        routePoints = await optimalRouteService.getGoogleMapsRoute(origin, destination);
      }
    } catch (e) {
      print('경로 계산 오류: $e');
      // 경로 포인트 생성
      routePoints = await generateRoute(origin, destination);
    }

    // 거리 계산 (각 포인트 간 거리 합산)
    double distance = 0.0;
    for (int i = 0; i < routePoints.length - 1; i++) {
      distance += _calculateDistance(routePoints[i], routePoints[i + 1]);
    }

    // 예상 시간 계산 (응급 상황이면 더 빠름)
    String estimatedTime;
    if (isEmergency) {
      // 응급 상황은 평균 속도 60km/h로 계산
      final double timeInHours = distance / 60000;
      final int minutes = (timeInHours * 60).round();
      estimatedTime = '$minutes분';
    } else {
      // 일반 상황은 평균 속도 40km/h로 계산
      final double timeInHours = distance / 40000;
      final int minutes = (timeInHours * 60).round();
      estimatedTime = '$minutes분';
    }

    // 주변 차량 수 (더미 데이터)
    final int nearbyVehicles = 20 + (DateTime.now().second % 15);

    return {
      'route_points': routePoints,
      'estimated_time': estimatedTime,
      'distance': (distance / 1000).toStringAsFixed(1), // km 단위로 변환
      'nearby_vehicles': nearbyVehicles,
    };
  }

  // 응급 경로 생성
  Future<EmergencyRoute> createEmergencyRoute(
    String baseLocation,
    String patientLocation,
    String hospitalLocation,
  ) async {
    // 더미 구현 - 실제로는 DB에 저장하고 ID 반환
    final EmergencyRoute route = EmergencyRoute(
      baseLocation: baseLocation,
      patientLocation: patientLocation,
      hospitalLocation: hospitalLocation,
      status: EmergencyRouteStatus.toPatient,
      estimatedTime: '12분',
      distance: 5.2,
      notifiedVehicles: 27,
    );

    return route;
  }

  // 경로 상태 업데이트
  Future<void> updateRouteStatus(
    EmergencyRoute route,
    EmergencyRouteStatus status,
  ) async {
    // 실제 구현에서는 DB 업데이트
    route.status = status;
  }

  // 직선 거리 계산 (미터 단위) - 간단한 구현
  double _calculateDistance(LatLng start, LatLng end) {
    const double p = 0.017453292519943295; // Math.PI / 180
    final double a =
        0.5 -
        math.cos((end.latitude - start.latitude) * p) / 2 +
        math.cos(start.latitude * p) *
            math.cos(end.latitude * p) *
            (1 - math.cos((end.longitude - start.longitude) * p)) /
            2;
    return 12742000 * math.asin(math.sqrt(a)); // 2 * R; R = 6371 km * 1000 m
  }
}
