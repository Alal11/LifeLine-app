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

  // Google Maps API 키
  // AndroidManifest.xml 파일에서 가져온 API 키를 여기에 입력하세요
  final String _googleMapsApiKey = 'AIzaSyAg4E_Y8py1lA_AZOipTOxOtG47fakdtKQ';

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
      final hospitalLocation = LatLng(
        optimalHospital.latitude,
        optimalHospital.longitude,
      );

      List<LatLng> routePoints = [];

      // 3. 최적 경로 계산을 위한 링크 ID 가져오기
      final startLinkId = await LinkIdService.getNearestLinkId(
        currentLocation.latitude,
        currentLocation.longitude,
      );

      final endLinkId = await LinkIdService.getNearestLinkId(
        optimalHospital.latitude,
        optimalHospital.longitude,
      );

      // 링크 ID 가져오기 실패 시 Google Maps API 사용
      if (startLinkId == null || endLinkId == null) {
        print('링크 ID 가져오기 실패, Google Maps API 사용');
        routePoints = await getGoogleMapsRoute(
          currentLocation,
          hospitalLocation,
        );
      } else {
        try {
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
          routePoints = _parseRoutePoints(routeData);

          // 경로 포인트가 없는 경우 Google Maps API 사용
          if (routePoints.isEmpty) {
            print('도로망 API 경로 포인트 없음, Google Maps API 사용');
            routePoints = await getGoogleMapsRoute(
              currentLocation,
              hospitalLocation,
            );
          }
        } catch (e) {
          print('도로망 API 오류, Google Maps API 사용: $e');
          routePoints = await getGoogleMapsRoute(
            currentLocation,
            hospitalLocation,
          );
        }
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

  // Google Maps Directions API를 사용하여 경로 가져오기
  Future<List<LatLng>> getGoogleMapsRoute(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&mode=driving'
        '&alternatives=false'
        '&key=$_googleMapsApiKey',
      );

      print('Google Maps Directions API 호출: $url');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'OK') {
          // 경로 포인트 추출
          final List<LatLng> points = [];

          // 첫 번째 경로의 개요 포인트 추출
          final String encodedPoints =
              data['routes'][0]['overview_polyline']['points'];
          points.addAll(_decodePolyline(encodedPoints));

          print('Google Maps API에서 ${points.length}개의 경로 포인트를 가져왔습니다.');
          return points;
        } else {
          print('Google Maps API 오류: ${data['status']}');
          // API 오류 시 더미 경로 생성
          return _generateDummyRoute(origin, destination);
        }
      } else {
        print('Google Maps API 요청 실패: ${response.statusCode}');
        // 요청 실패 시 더미 경로 생성
        return _generateDummyRoute(origin, destination);
      }
    } catch (e) {
      print('Google Maps 경로 가져오기 실패: $e');
      // 예외 발생 시 더미 경로 생성
      return _generateDummyRoute(origin, destination);
    }
  }

  // Google Maps Polyline 디코딩
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      double latValue = lat / 1e5;
      double lngValue = lng / 1e5;
      points.add(LatLng(latValue, lngValue));
    }
    return points;
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

  // OpenStreetMap API를 사용하여 경로 가져오기
  Future<List<LatLng>> getOpenStreetMapRoute(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson',
      );

      print('OpenStreetMap API 호출: $url');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['code'] == 'Ok' &&
            data['routes'] != null &&
            data['routes'].isNotEmpty) {
          final List<LatLng> points = [];

          // 경로 좌표 추출 (GeoJSON 형식)
          final coordinates =
              data['routes'][0]['geometry']['coordinates'] as List;

          for (var coord in coordinates) {
            // OpenStreetMap API는 [경도, 위도] 순서로 반환
            points.add(LatLng(coord[1], coord[0]));
          }

          print('OpenStreetMap API에서 ${points.length}개의 경로 포인트를 가져왔습니다.');
          return points;
        } else {
          print('OpenStreetMap API 오류: ${data['code']}');
          return _generateDummyRoute(origin, destination);
        }
      } else {
        print('OpenStreetMap API 요청 실패: ${response.statusCode}');
        return _generateDummyRoute(origin, destination);
      }
    } catch (e) {
      print('OpenStreetMap 경로 가져오기 실패: $e');
      return _generateDummyRoute(origin, destination);
    }
  }

  // 더미 경로 생성 (API 실패 시)
  List<LatLng> _generateDummyRoute(LatLng origin, LatLng destination) {
    List<LatLng> points = [];
    points.add(origin);

    // 두 지점 사이의 거리 계산
    const double earthRadius = 6371000; // 지구 반지름 (미터)
    double lat1 = origin.latitude * (math.pi / 180);
    double lon1 = origin.longitude * (math.pi / 180);
    double lat2 = destination.latitude * (math.pi / 180);
    double lon2 = destination.longitude * (math.pi / 180);

    double dLat = lat2 - lat1;
    double dLon = lon2 - lon1;
    double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    double distance = earthRadius * c;

    // 거리에 따라 중간 포인트 수 조정
    int steps = math.max(10, (distance / 200).round()); // 200m마다 포인트 생성

    // 방향 벡터 계산
    double dx = destination.longitude - origin.longitude;
    double dy = destination.latitude - origin.latitude;

    // 중간 포인트 추가
    for (int i = 1; i < steps; i++) {
      double fraction = i / steps;

      // 기본 위치 계산
      double lat = origin.latitude + dy * fraction;
      double lng = origin.longitude + dx * fraction;

      // 더 복잡한 패턴 생성 (실제 도로처럼 보이게)
      double maxVariance =
          0.0005 * (1 - math.pow(2 * fraction - 1, 2)); // 중간에 가장 크게 변형
      double variance1 = maxVariance * math.sin(fraction * math.pi * 5);
      double variance2 = maxVariance * math.cos(fraction * math.pi * 7);

      // 원래 방향에 수직인 방향으로 변형 추가
      double perpX = -dy;
      double perpY = dx;
      double norm = math.sqrt(perpX * perpX + perpY * perpY);
      if (norm > 0) {
        perpX /= norm;
        perpY /= norm;
      }

      double adjustedLat = lat + perpY * variance1 + perpX * variance2 * 0.5;
      double adjustedLng = lng + perpX * variance1 - perpY * variance2 * 0.5;

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
