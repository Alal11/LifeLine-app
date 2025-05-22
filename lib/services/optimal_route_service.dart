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

  // 최적 경로 및 병원 찾기 - 전국 지역 대응 강화
  Future<Map<String, dynamic>> findOptimalRouteAndHospital({
    required LatLng currentLocation,
    required String patientCondition,
    required String patientSeverity,
    double? searchRadius, // 지역별 맞춤 검색 반경
  }) async {
    try {
      print('최적 경로 및 병원 찾기 시작 - 위치: $currentLocation');

      // 1. 현재 위치 기반으로 적합한 병원 찾기 (전국 지역 대응)
      final hospitals = await _emergencyService.findOptimalHospitals(
        currentLocation.latitude,
        currentLocation.longitude,
        patientCondition,
        patientSeverity,
        searchRadius: searchRadius, // 지역별 맞춤 반경 전달
      );

      if (hospitals.isEmpty) {
        print('적합한 병원을 찾을 수 없음, 폴백 병원 생성');
        return {
          'success': false,
          'error': '환자 상태에 적합한 병원을 찾을 수 없습니다.',
          'fallbackHospitalName': '가장 가까운 종합병원',
          'fallbackHospitalCoord': LatLng(
            currentLocation.latitude + 0.02,
            currentLocation.longitude + 0.01,
          ),
          'recommendedHospitals': <Hospital>[], // 빈 리스트
        };
      }

      print('${hospitals.length}개의 적합한 병원을 찾았습니다.');

      // 2. 가장 적합한 병원 선택 (첫 번째 병원 - 이미 소요 시간으로 정렬됨)
      final optimalHospital = hospitals.first;
      final hospitalLocation = LatLng(
        optimalHospital.latitude,
        optimalHospital.longitude,
      );

      print('최적 병원 선택: ${optimalHospital.name} (${optimalHospital.region})');

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
          print('도로망 API로 경로 계산 시도 - 링크ID: $startLinkId -> $endLinkId');

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
          } else {
            print('도로망 API에서 ${routePoints.length}개의 경로 포인트 획득');
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
        'recommendedHospitals': hospitals, // 모든 추천 병원 리스트
        'patientRegion': optimalHospital.region, // 병원 지역 정보
      };
    } catch (e) {
      print('최적 경로 계산 중 오류 발생: $e');
      return {
        'success': false,
        'error': '경로 계산 중 오류가 발생했습니다: $e',
        'recommendedHospitals': <Hospital>[], // 빈 리스트
      };
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

    try {
      // 경로 데이터 파싱
      if (routeData.containsKey('path') && routeData['path'] is List) {
        for (var point in routeData['path']) {
          if (point.containsKey('lat') && point.containsKey('lng')) {
            routePoints.add(LatLng(point['lat'], point['lng']));
          }
        }
      }
      // 다른 가능한 데이터 구조도 체크
      else if (routeData.containsKey('routes') && routeData['routes'] is List) {
        final routes = routeData['routes'] as List;
        if (routes.isNotEmpty && routes[0].containsKey('geometry')) {
          final geometry = routes[0]['geometry'];
          if (geometry.containsKey('coordinates')) {
            final coordinates = geometry['coordinates'] as List;
            for (var coord in coordinates) {
              if (coord is List && coord.length >= 2) {
                // [longitude, latitude] 형식 가정
                routePoints.add(LatLng(coord[1], coord[0]));
              }
            }
          }
        }
      }

      print('도로망 데이터에서 ${routePoints.length}개의 경로 포인트 파싱 완료');
    } catch (e) {
      print('경로 포인트 파싱 중 오류: $e');
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

  // 더미 경로 생성 (API 실패 시) - 지역별 맞춤 생성
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

    print('더미 경로 생성 - 거리: ${(distance / 1000).toStringAsFixed(1)}km');

    // 거리에 따라 중간 포인트 수 조정
    int steps = math.max(10, (distance / 200).round()); // 200m마다 포인트 생성

    // 지역별로 경로 패턴 조정
    double varianceMultiplier = _getRegionVarianceMultiplier(
      origin,
      destination,
    );

    // 방향 벡터 계산
    double dx = destination.longitude - origin.longitude;
    double dy = destination.latitude - origin.latitude;

    // 중간 포인트 추가
    for (int i = 1; i < steps; i++) {
      double fraction = i / steps;

      // 기본 위치 계산
      double lat = origin.latitude + dy * fraction;
      double lng = origin.longitude + dx * fraction;

      // 지역별 맞춤 패턴 생성 (실제 도로처럼 보이게)
      double maxVariance =
          0.0005 * varianceMultiplier * (1 - math.pow(2 * fraction - 1, 2));
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
    print('더미 경로 생성 완료 - ${points.length}개 포인트');
    return points;
  }

  // 지역별 경로 변형 계수 반환
  double _getRegionVarianceMultiplier(LatLng origin, LatLng destination) {
    // 서울, 부산 등 도시 지역은 더 복잡한 경로
    // 강원도, 제주도 등은 상대적으로 단순한 경로

    double avgLat = (origin.latitude + destination.latitude) / 2;
    double avgLng = (origin.longitude + destination.longitude) / 2;

    // 대략적인 지역 판단 (위도/경도 기준)
    if (avgLat >= 37.4 &&
        avgLat <= 37.7 &&
        avgLng >= 126.8 &&
        avgLng <= 127.2) {
      // 서울 지역 - 복잡한 도로망
      return 2.0;
    } else if (avgLat >= 35.0 &&
        avgLat <= 35.3 &&
        avgLng >= 128.9 &&
        avgLng <= 129.3) {
      // 부산 지역 - 복잡한 도로망
      return 1.8;
    } else if (avgLat >= 33.0 && avgLat <= 34.0) {
      // 제주도 - 상대적으로 단순
      return 0.8;
    } else if (avgLat >= 37.0 && avgLng <= 128.0) {
      // 강원도 - 산간 지역, 단순한 경로
      return 0.6;
    } else {
      // 기타 지역 - 보통
      return 1.0;
    }
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

  // 환자 상태에 따른 최적 병원 추천 - 전국 지역 대응
  Future<List<Hospital>> recommendHospitals(
    LatLng currentLocation,
    String patientCondition,
    String patientSeverity, {
    double? searchRadius, // 지역별 맞춤 검색 반경
  }) async {
    try {
      print(
        '병원 추천 요청 - 위치: $currentLocation, 상태: $patientCondition, 중증도: $patientSeverity',
      );

      final hospitals = await _emergencyService.findOptimalHospitals(
        currentLocation.latitude,
        currentLocation.longitude,
        patientCondition,
        patientSeverity,
        searchRadius: searchRadius, // 지역별 맞춤 반경 전달
      );

      print('${hospitals.length}개의 병원 추천 완료');

      // 최대 5개의 병원 추천 (기존 3개에서 확장)
      return hospitals.take(5).toList();
    } catch (e) {
      print('병원 추천 중 오류 발생: $e');
      return [];
    }
  }

  // 지역별 맞춤 검색 반경 계산
  double getRegionSearchRadius(LatLng location) {
    Map<String, RegionConfig> regionConfigs = {
      '서울': RegionConfig(
        regionName: '서울특별시',
        searchRadius: 20.0,
        allowedRegions: ['서울특별시', '경기도'],
        conditionWeights: {
          '심장마비': 1.0,
          '뇌출혈': 1.0,
          '호흡곤란': 0.8,
          '다발성 외상': 1.0,
          '골절': 0.6,
          '의식불명': 0.9,
          '심한 출혈': 0.8,
          '화상': 0.7,
          '중독': 0.8,
          '기타': 0.5,
        },
      ),
      '경기': RegionConfig(
        regionName: '경기도',
        searchRadius: 30.0,
        allowedRegions: ['경기도', '서울특별시', '인천광역시'],
        conditionWeights: {
          '심장마비': 1.0,
          '뇌출혈': 1.0,
          '호흡곤란': 0.8,
          '다발성 외상': 1.0,
          '골절': 0.6,
          '의식불명': 0.9,
          '심한 출혈': 0.8,
          '화상': 0.7,
          '중독': 0.8,
          '기타': 0.5,
        },
      ),
      '부산': RegionConfig(
        regionName: '부산광역시',
        searchRadius: 25.0,
        allowedRegions: ['부산광역시', '경상남도'],
        conditionWeights: {
          '심장마비': 1.0,
          '뇌출혈': 1.0,
          '호흡곤란': 0.8,
          '다발성 외상': 1.0,
          '골절': 0.6,
          '의식불명': 0.9,
          '심한 출혈': 0.8,
          '화상': 0.7,
          '중독': 0.8,
          '기타': 0.5,
        },
      ),
      '대구': RegionConfig(
        regionName: '대구광역시',
        searchRadius: 25.0,
        allowedRegions: ['대구광역시', '경상북도'],
        conditionWeights: {
          '심장마비': 1.0,
          '뇌출혈': 1.0,
          '호흡곤란': 0.8,
          '다발성 외상': 1.0,
          '골절': 0.6,
          '의식불명': 0.9,
          '심한 출혈': 0.8,
          '화상': 0.7,
          '중독': 0.8,
          '기타': 0.5,
        },
      ),
      '강원': RegionConfig(
        regionName: '강원특별자치도',
        searchRadius: 60.0,
        allowedRegions: ['강원특별자치도'],
        conditionWeights: {
          '심장마비': 1.0,
          '뇌출혈': 1.0,
          '호흡곤란': 0.8,
          '다발성 외상': 1.0,
          '골절': 0.6,
          '의식불명': 0.9,
          '심한 출혈': 0.8,
          '화상': 0.7,
          '중독': 0.8,
          '기타': 0.5,
        },
      ),
      '제주': RegionConfig(
        regionName: '제주특별자치도',
        searchRadius: 30.0,
        allowedRegions: ['제주특별자치도'],
        conditionWeights: {
          '심장마비': 1.0,
          '뇌출혈': 1.0,
          '호흡곤란': 0.8,
          '다발성 외상': 1.0,
          '골절': 0.6,
          '의식불명': 0.9,
          '심한 출혈': 0.8,
          '화상': 0.7,
          '중독': 0.8,
          '기타': 0.5,
        },
      ),
    };

    // TODO: 실제 행정구역명을 구하는 로직 필요 (예: Reverse Geocoding API)
    // 아래는 예시 구현
    String regionKey = _getRegionKeyFromLocation(location);

    if (regionConfigs.containsKey(regionKey)) {
      return regionConfigs[regionKey]!.searchRadius;
    }

    // 모든 조건에 해당되지 않을 경우 기본값 반환
    return 30.0;
  }

  // 예시: 위도, 경도로부터 지역 키를 반환하는 함수 (실제로는 Geocoding API로 구현)
  String _getRegionKeyFromLocation(LatLng location) {
    // 예시용 하드코딩 (실제로는 Reverse Geocoding API 사용해야 함)
    // 위도/경도 범위로 지역 키 판별 예시
    if (location.latitude > 37.0 && location.longitude > 126.0) {
      return '서울';
    } else if (location.latitude > 35.0 && location.longitude > 129.0) {
      return '부산';
    }

    // fallback
    return '기타';
  }
}
