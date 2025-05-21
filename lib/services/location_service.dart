import 'dart:async';
import 'package:geolocator/geolocator.dart' as geo;

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

  // Geolocator의 Position을 현재 앱의 Position으로 변환하는 팩토리 메서드
  factory Position.fromGeolocator(geo.Position position) {
    return Position(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      altitude: position.altitude ?? 0.0,
      speed: position.speed,
      heading: position.heading ?? 0.0,
    );
  }
}

class LocationService {
  // 싱글톤 패턴 구현
  static final LocationService _instance = LocationService._internal();

  factory LocationService() {
    return _instance;
  }

  LocationService._internal();

  // 위치 업데이트 스트림 컨트롤러
  final StreamController<Position> _positionController = StreamController<Position>.broadcast();

  // 위치 서비스 초기화 플래그
  bool _initialized = false;

  // 위치 구독 스트림
  StreamSubscription<geo.Position>? _geolocatorStream;

  // 서비스 초기화
  Future<void> initialize() async {
    if (_initialized) return;

    // 위치 권한 확인 및 요청
    bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('위치 서비스가 비활성화되어 있습니다.');
    }

    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) {
        throw Exception('위치 권한이 거부되었습니다.');
      }
    }

    if (permission == geo.LocationPermission.deniedForever) {
      throw Exception('위치 권한이 영구적으로 거부되었습니다. 설정에서 권한을 허용해주세요.');
    }

    _initialized = true;

    // 실제 위치 업데이트 구독
    _geolocatorStream = geo.Geolocator.getPositionStream(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: 10, // 10미터마다 업데이트
      ),
    ).listen((geo.Position geoPosition) {
      // Geolocator의 Position을 앱의 Position으로 변환
      final position = Position.fromGeolocator(geoPosition);
      _positionController.add(position);
    });
  }

  // 현재 위치 가져오기
  Future<Position> getCurrentLocation() async {
    await initialize();

    // 실제 위치 가져오기
    final geoPosition = await geo.Geolocator.getCurrentPosition(
      desiredAccuracy: geo.LocationAccuracy.high,
    );

    return Position.fromGeolocator(geoPosition);
  }

  // 위치 스트림 가져오기
  Stream<Position> getPositionStream() {
    initialize();
    return _positionController.stream;
  }

  // 두 위치 사이의 거리 계산 (Haversine 공식 사용)
  double calculateDistance(Position start, Position end) {
    return geo.Geolocator.distanceBetween(
        start.latitude,
        start.longitude,
        end.latitude,
        end.longitude
    );
  }

  // 서비스 정리
  void dispose() {
    _geolocatorStream?.cancel();
    _positionController.close();
  }
}