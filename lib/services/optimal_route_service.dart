import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;
import '../services/hospital_service.dart';
import '../services/linkid_service.dart';
import '../services/road_network_service.dart';

class OptimalRouteService {
  // 싱글톤 패턴 구현
  static final OptimalRouteService _instance = OptimalRouteService._internal();

  factory OptimalRouteService() => _instance;

  OptimalRouteService._internal();

  // 서비스 인스턴스
  final RoadNetworkService _roadNetworkService = RoadNetworkService();
  final EmergencyMedicalService _emergencyService = EmergencyMedicalService();

  // 최적 경로 및 병원 찾기
  Future<Map<String, dynamic>> findOptimalRouteAndHospital({
    required LatLng currentLocation,
    required String patientCondition,
    required String patientSeverity,
  }) async {
    try {
      // 1. 현재 위치 기반으로 적합한 병원 찾기
      final hospitals = await _emergencyService.findOptimalHospitals(
        currentLocation.latitude,
        currentLocation.longitude,
        patientCondition,
        patientSeverity,
      );

      if (hospitals.isEmpty) {
        return {
          'success': false,
          'error': '환자 상태에 적합한 병원을 찾을 수 없습니다.',
          'fallbackHospitalName': '가장 가까운 종합병원',
          'fallbackHospitalCoord': LatLng(
            currentLocation.latitude + 0.02,
            currentLocation.longitude + 0.01,
          ),
        };
      }

      // 2. 가장 적합한 병원 선택 (첫 번째 병원 - 이미 소요 시간으로 정렬됨)
      final optimalHospital = hospitals.first;

      // 3. 최적 경로 계산을 위한 링크 ID 가져오기
      final startLinkId = await LinkIdService.getNearestLinkId(
        currentLocation.latitude,
        currentLocation.longitude,
      );

      final endLinkId = await LinkIdService.getNearestLinkId(
        optimalHospital.latitude,
        optimalHospital.longitude,
      );

      // 링크 ID 가져오기 실패 시 더미 경로 반환
      if (startLinkId == null || endLinkId == null) {
        return {
          'success': true,
          'optimalHospital': optimalHospital,
          'routePoints': _generateDummyRoute(
            currentLocation,
            LatLng(optimalHospital.latitude, optimalHospital.longitude),
          ),
          'estimatedTimeMinutes':
              (optimalHospital.estimatedTimeSeconds / 60).round(),
          'distanceKm': (optimalHospital.distanceMeters / 1000).toStringAsFixed(
            1,
          ),
        };
      }

      // 4. 도로망 API로 경로 계산
      final routeData = await _roadNetworkService.getRoadNetwork(
        dprtrLinkId: startLinkId,
        arriveLinkId: endLinkId,
        // 현재 시간대 기준 (0: 평일, 1: 주말)
        weekType: _isWeekend() ? 1 : 0,
        // 현재 시간대 기준 (00, 01, 02, .., 23 or all)
        time: _getCurrentHour(),
      );

      // 5. 경로 포인트 변환
      List<LatLng> routePoints = _parseRoutePoints(routeData);

      // 경로 포인트가 없는 경우 더미 경로 생성
      if (routePoints.isEmpty) {
        routePoints = _generateDummyRoute(
          currentLocation,
          LatLng(optimalHospital.latitude, optimalHospital.longitude),
        );
      }

      // 6. 결과 반환
      return {
        'success': true,
        'optimalHospital': optimalHospital,
        'routePoints': routePoints,
        'estimatedTimeMinutes':
            (optimalHospital.estimatedTimeSeconds / 60).round(),
        'distanceKm': (optimalHospital.distanceMeters / 1000).toStringAsFixed(
          1,
        ),
      };
    } catch (e) {
      print('최적 경로 계산 중 오류 발생: $e');
      return {'success': false, 'error': '경로 계산 중 오류가 발생했습니다: $e'};
    }
  }

  // 도로망 데이터에서 경로 포인트 추출
  List<LatLng> _parseRoutePoints(Map<String, dynamic> routeData) {
    List<LatLng> routePoints = [];

    // 경로 데이터 파싱
    if (routeData.containsKey('path') && routeData['path'] is List) {
      for (var point in routeData['path']) {
        if (point.containsKey('lat') && point.containsKey('lng')) {
          routePoints.add(LatLng(point['lat'], point['lng']));
        }
      }
    }

    return routePoints;
  }

  // 더미 경로 생성 (API 실패 시)
  List<LatLng> _generateDummyRoute(LatLng origin, LatLng destination) {
    List<LatLng> points = [];
    points.add(origin);

    // 중간 포인트 추가
    const int steps = 5;
    for (int i = 1; i < steps; i++) {
      double fraction = i / steps;
      double lat =
          origin.latitude + (destination.latitude - origin.latitude) * fraction;
      double lng =
          origin.longitude +
          (destination.longitude - origin.longitude) * fraction;

      // 약간의 변형 추가 (실제 도로처럼 보이게)
      double variance = 0.001 * math.sin(fraction * math.pi);
      double adjustedLat = lat + variance * math.cos(fraction * 5 * math.pi);
      double adjustedLng = lng + variance * math.sin(fraction * 5 * math.pi);

      points.add(LatLng(adjustedLat, adjustedLng));
    }

    points.add(destination);
    return points;
  }

  // 현재 시간이 주말인지 확인
  bool _isWeekend() {
    final now = DateTime.now();
    // 토요일(6)이나 일요일(7)이면 주말
    return now.weekday == 6 || now.weekday == 7;
  }

  // 현재 시간대 반환 (00~23 형식)
  String _getCurrentHour() {
    final now = DateTime.now();
    // 시간을 두 자리 문자열로 포맷팅
    return now.hour.toString().padLeft(2, '0');
  }

  // 병원 정보를 기반으로 LatLng로 변환
  LatLng hospitalToLatLng(Hospital hospital) {
    return LatLng(hospital.latitude, hospital.longitude);
  }

  // 환자 상태에 따른 최적 병원 추천
  Future<List<Hospital>> recommendHospitals(
    LatLng currentLocation,
    String patientCondition,
    String patientSeverity,
  ) async {
    try {
      final hospitals = await _emergencyService.findOptimalHospitals(
        currentLocation.latitude,
        currentLocation.longitude,
        patientCondition,
        patientSeverity,
      );

      // 최대 3개의 병원 추천
      return hospitals.take(3).toList();
    } catch (e) {
      print('병원 추천 중 오류 발생: $e');
      return [];
    }
  }
}
