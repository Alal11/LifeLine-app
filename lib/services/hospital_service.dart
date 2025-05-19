import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/emergency_route.dart';
import 'road_network_service.dart';
import 'route_service.dart';
import 'linkid_service.dart';

// 병원 정보를 담는 모델 클래스
class Hospital {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final int availableBeds;
  final List<String> specialties;
  final bool hasEmergencyRoom;

  // 추가 의료 역량 정보
  final bool canTreatTrauma; // 외상 치료 가능
  final bool canTreatCardiac; // 심장 관련 치료 가능
  final bool canTreatStroke; // 뇌졸중 치료 가능
  final bool hasPediatricER; // 소아 응급실 보유
  final bool hasICU; // 중환자실 보유
  final int distanceMeters; // 거리 (미터)
  final int estimatedTimeSeconds; // 예상 소요 시간 (초)

  Hospital({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.availableBeds = 0,
    this.specialties = const [],
    this.hasEmergencyRoom = false,
    this.canTreatTrauma = false,
    this.canTreatCardiac = false,
    this.canTreatStroke = false,
    this.hasPediatricER = false,
    this.hasICU = false,
    this.distanceMeters = 0,
    this.estimatedTimeSeconds = 0,
  });

  // API 응답에서 Hospital 객체 생성
  factory Hospital.fromJson(Map<String, dynamic> json) {
    return Hospital(
      id: json['hpid'] ?? '',
      name: json['dutyName'] ?? '',
      latitude: double.tryParse(json['wgs84Lat'] ?? '0') ?? 0,
      longitude: double.tryParse(json['wgs84Lon'] ?? '0') ?? 0,
      availableBeds: int.tryParse(json['hvec'] ?? '0') ?? 0,
      specialties: List<String>.from(json['specialties'] ?? []),
      hasEmergencyRoom:
          json['hvec'] != null &&
          int.tryParse(json['hvec']) != null &&
          int.tryParse(json['hvec'])! > 0,
      canTreatTrauma: json['MKioskTy25'] == 'Y',
      // 중증외상 수용 가능
      canTreatCardiac: json['MKioskTy1'] == 'Y',
      // 심근경색 수용 가능
      canTreatStroke: json['MKioskTy2'] == 'Y',
      // 뇌졸중 수용 가능
      hasPediatricER: json['MKioskTy7'] == 'Y',
      // 소아응급 수용 가능
      hasICU: json['MKioskTy10'] == 'Y', // 중환자실 보유
    );
  }

  // 지정된 상태에 적합한 병원인지 확인
  bool isMatchForCondition(String condition) {
    condition = condition.toLowerCase();

    // 조건에 따른 병원 적합성 확인
    if (condition.contains('뇌졸중') || condition.contains('stroke')) {
      return canTreatStroke;
    } else if (condition.contains('심장마비') ||
        condition.contains('심근경색') ||
        condition.contains('heart attack') ||
        condition.contains('cardiac')) {
      return canTreatCardiac;
    } else if (condition.contains('외상') ||
        condition.contains('trauma') ||
        condition.contains('골절') ||
        condition.contains('사고')) {
      return canTreatTrauma;
    } else if (condition.contains('소아') ||
        condition.contains('어린이') ||
        condition.contains('child')) {
      return hasPediatricER;
    }

    // 중증 환자인 경우 중환자실이 있는 병원이 필요
    return true;
  }

  // 환자 중증도에 따라 적합한 병원인지 확인
  bool isMatchForSeverity(String severity) {
    if (severity == '중증') {
      return hasICU && availableBeds > 0;
    } else if (severity == '중등') {
      return availableBeds > 0;
    }
    // 경증은 대부분의 병원에서 처리 가능
    return true;
  }

  // 병원과 현재 위치 사이의 예상 소요 시간 계산 (초 단위)
  int calculateEstimatedTime(
    double startLat,
    double startLng,
    double avgSpeed,
  ) {
    // 현재 위치에서 병원까지의 직선 거리 계산 (미터)
    const double earthRadius = 6371000; // 지구 반지름 (미터)
    final double startLatRad = _degreesToRadians(startLat);
    final double endLatRad = _degreesToRadians(latitude);
    final double latDiffRad = _degreesToRadians(latitude - startLat);
    final double lngDiffRad = _degreesToRadians(longitude - startLng);

    final double a =
        _sin(latDiffRad / 2) * _sin(latDiffRad / 2) +
        _cos(startLatRad) *
            _cos(endLatRad) *
            _sin(lngDiffRad / 2) *
            _sin(lngDiffRad / 2);
    final double c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    final double distance = earthRadius * c;

    // 도로 경로는 직선보다 약 30% 길다고 가정
    final double roadDistance = distance * 1.3;

    // 평균 시속 (km/h)을 m/s로 변환
    final double speedInMps = avgSpeed * 1000 / 3600;

    // 예상 소요 시간 (초)
    return (roadDistance / speedInMps).round();
  }

  // 수학 함수 (dart:math 패키지를 사용하지 않는 간단한 구현)
  double _degreesToRadians(double degrees) {
    return degrees * (3.14159265359 / 180);
  }

  double _sin(double x) => x - (x * x * x) / 6; // 간단한 근사
  double _cos(double x) => 1 - (x * x) / 2; // 간단한 근사
  double _sqrt(double x) => x * x; // 간단한 근사
  double _atan2(double y, double x) => y / x; // 간단한 근사
}

// 응급의료기관 API 서비스
class EmergencyMedicalService {
  static const String baseUrl = 'https://www.data.go.kr/api/15000563/v1/uddi';
  static const String apiKey =
      'uJTYl2xqFaLfmL9WJN55JPXdgtm1JLQiXJYRv3UDRwAbsaf3wGLIBDxUTJ0gn54x3eOaJfgIwpzH0l6aZHJefQ%3D%3D'; // API 키 설정 필요

  // 특정 지역 내 응급의료기관 검색
  Future<List<Hospital>> findNearbyHospitals(
    double latitude,
    double longitude,
    double radiusKm,
  ) async {
    try {
      final url = Uri.parse(
        '$baseUrl/nearbyEmergencyMedicalInstitutions?'
        'serviceKey=$apiKey'
        '&lat=$latitude'
        '&lng=$longitude'
        '&radius=${radiusKm * 1000}',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> items = data['items'] ?? [];

        return items.map((item) => Hospital.fromJson(item)).toList();
      } else {
        print('응급의료기관 API 오류: ${response.statusCode}');
        return _getDummyHospitals(latitude, longitude);
      }
    } catch (e) {
      print('응급의료기관 API 호출 실패: $e');
      // API 호출 실패 시 더미 데이터 반환
      return _getDummyHospitals(latitude, longitude);
    }
  }

  // 환자 상태와 중증도에 따른 최적 병원 선택
  Future<List<Hospital>> findOptimalHospitals(
    double latitude,
    double longitude,
    String patientCondition,
    String patientSeverity,
  ) async {
    // 주변 병원 검색 (반경 10km)
    final hospitals = await findNearbyHospitals(latitude, longitude, 10.0);

    // 응급차량 평균 속도 (km/h)
    double avgSpeed = 60.0;
    if (patientSeverity == '중증') {
      avgSpeed = 70.0; // 중증 환자는 더 빠른 속도로 이동
    }

    // 각 병원에 대해 적합성 검사 및 예상 소요 시간 계산
    final List<Hospital> suitableHospitals = [];

    for (var hospital in hospitals) {
      // 환자 상태와 중증도에 맞는지 확인
      if (hospital.isMatchForCondition(patientCondition) &&
          hospital.isMatchForSeverity(patientSeverity)) {
        // 예상 소요 시간 계산
        final estimatedTimeSeconds = hospital.calculateEstimatedTime(
          latitude,
          longitude,
          avgSpeed,
        );

        // 병원 정보 업데이트 (거리와 예상 시간 추가)
        final updatedHospital = Hospital(
          id: hospital.id,
          name: hospital.name,
          latitude: hospital.latitude,
          longitude: hospital.longitude,
          availableBeds: hospital.availableBeds,
          specialties: hospital.specialties,
          hasEmergencyRoom: hospital.hasEmergencyRoom,
          canTreatTrauma: hospital.canTreatTrauma,
          canTreatCardiac: hospital.canTreatCardiac,
          canTreatStroke: hospital.canTreatStroke,
          hasPediatricER: hospital.hasPediatricER,
          hasICU: hospital.hasICU,
          distanceMeters:
              (hospital.calculateEstimatedTime(latitude, longitude, 1.0) * 1.3)
                  .round(),
          estimatedTimeSeconds: estimatedTimeSeconds,
        );

        suitableHospitals.add(updatedHospital);
      }
    }

    // 예상 소요 시간에 따라 정렬
    suitableHospitals.sort(
      (a, b) => a.estimatedTimeSeconds.compareTo(b.estimatedTimeSeconds),
    );

    return suitableHospitals;
  }

  // 더미 병원 데이터 생성 (API 실패 시 사용)
  List<Hospital> _getDummyHospitals(double centerLat, double centerLng) {
    // 주변에 4-5개의 더미 병원 생성
    final random = math.Random();
    final List<Hospital> dummyHospitals = [];

    // 병원 유형 데이터
    final hospitalTypes = [
      {
        "name": "천안충무병원",
        "icu": true,
        "trauma": true,
        "cardiac": true,
        "stroke": true,
      },
      {
        "name": "단국대학교병원",
        "icu": true,
        "trauma": true,
        "cardiac": true,
        "stroke": true,
      },
      {
        "name": "순천향대학교천안병원",
        "icu": true,
        "trauma": true,
        "cardiac": true,
        "stroke": true,
      },
      {
        "name": "천안시립병원",
        "icu": false,
        "trauma": false,
        "cardiac": false,
        "stroke": false,
      },
      {
        "name": "두손의원",
        "icu": false,
        "trauma": false,
        "cardiac": false,
        "stroke": false,
      },
    ];

    // 각 병원 유형에 대해 더미 데이터 생성
    for (int i = 0; i < hospitalTypes.length; i++) {
      // 중심점에서 약간 떨어진 위치 계산
      final latOffset = (random.nextDouble() - 0.5) * 0.05;
      final lngOffset = (random.nextDouble() - 0.5) * 0.05;

      final hospitalLat = centerLat + latOffset;
      final hospitalLng = centerLng + lngOffset;

      final hospitalType = hospitalTypes[i];

      // 거리에 따른 병상 가용성 (가까울수록 병상이 적음을 가정)
      final distance =
          math.sqrt(latOffset * latOffset + lngOffset * lngOffset) * 100000;
      final availableBeds = math.max(1, (10 - distance / 10000).round());

      dummyHospitals.add(
        Hospital(
          id: "dummy_${hospitalType["name"]}",
          name: hospitalType["name"] as String,
          latitude: hospitalLat,
          longitude: hospitalLng,
          availableBeds: availableBeds,
          specialties: ["내과", "외과", "응급의학과"],
          hasEmergencyRoom: true,
          canTreatTrauma: hospitalType["trauma"] as bool,
          canTreatCardiac: hospitalType["cardiac"] as bool,
          canTreatStroke: hospitalType["stroke"] as bool,
          hasPediatricER: random.nextBool(),
          hasICU: hospitalType["icu"] as bool,
        ),
      );
    }

    return dummyHospitals;
  }
}
