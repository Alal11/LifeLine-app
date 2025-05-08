import 'dart:async';
import 'package:flutter/material.dart';

// 더미 위치 데이터 타입
class Position {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double altitude;
  final double speed;
  final double heading;

  Position({
    required this.latitude,
    required this.longitude,
    this.accuracy = 0.0,
    this.altitude = 0.0,
    this.speed = 0.0,
    this.heading = 0.0,
  });
}

class LocationService {
  // 싱글톤 패턴 구현
  static final LocationService _instance = LocationService._internal();

  factory LocationService() {
    return _instance;
  }

  LocationService._internal();

  // 더미 현재 위치 (서울 강남)
  final Position _dummyPosition = Position(
    latitude: 37.498095,
    longitude: 127.027610,
    accuracy: 10.0,
    altitude: 20.0,
    speed: 0.0,
    heading: 90.0,
  );

  // 위치 업데이트 스트림 컨트롤러
  final StreamController<Position> _positionController = StreamController<Position>.broadcast();

  // 위치 서비스 초기화 플래그
  bool _initialized = false;

  // 서비스 초기화
  Future<void> initialize() async {
    if (_initialized) return;

    // 실제 구현에서는 위치 권한 요청 및 설정을 수행
    _initialized = true;

    // 더미 위치 업데이트 시뮬레이션
    Timer.periodic(const Duration(seconds: 5), (timer) {
      // 약간의 변화를 주어 이동하는 것처럼 보이게 함
      final updatedPosition = Position(
        latitude: _dummyPosition.latitude + (0.001 * (DateTime.now().second % 10) / 10),
        longitude: _dummyPosition.longitude + (0.001 * (DateTime.now().millisecond % 10) / 10),
        accuracy: 10.0,
        altitude: 20.0,
        speed: 30.0 + (10 * (DateTime.now().second % 4)),
        heading: (_dummyPosition.heading + 5) % 360,
      );

      _positionController.add(updatedPosition);
    });
  }

  // 현재 위치 가져오기
  Future<Position> getCurrentLocation() async {
    await initialize();

    // 더미 위치 반환 (약간의 변형 추가)
    return Position(
      latitude: _dummyPosition.latitude + (0.0005 * (DateTime.now().second % 10) / 10),
      longitude: _dummyPosition.longitude + (0.0005 * (DateTime.now().millisecond % 10) / 10),
      accuracy: 10.0,
      altitude: 20.0,
      speed: 30.0 + (10 * (DateTime.now().second % 4)),
      heading: (_dummyPosition.heading + 10) % 360,
    );
  }

  // 위치 스트림 가져오기
  Stream<Position> getPositionStream() {
    initialize();
    return _positionController.stream;
  }

  // 두 위치 사이의 거리 계산 (Haversine 공식 사용)
  double calculateDistance(Position start, Position end) {
    const double earthRadius = 6371000; // 지구 반지름 (미터)

    final double startLatRad = _degreesToRadians(start.latitude);
    final double endLatRad = _degreesToRadians(end.latitude);
    final double latDiffRad = _degreesToRadians(end.latitude - start.latitude);
    final double lngDiffRad = _degreesToRadians(end.longitude - start.longitude);

    final double a = sin(latDiffRad / 2) * sin(latDiffRad / 2) +
        cos(startLatRad) * cos(endLatRad) *
            sin(lngDiffRad / 2) * sin(lngDiffRad / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  // 도 -> 라디안 변환
  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  // 수학 함수 (dart:math 패키지 사용할 수 없는 경우를 위한 간단 구현)
  double sin(double x) => x - (x * x * x) / 6;
  double cos(double x) => 1 - (x * x) / 2;
  double sqrt(double x) => x * x;
  double atan2(double y, double x) => y / x;
  double pi = 3.14159265359;

  // 서비스 정리
  void dispose() {
    _positionController.close();
  }
}