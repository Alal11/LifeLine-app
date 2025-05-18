// emergency_vehicle_viewmodel.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:geocoding/geocoding.dart';
import '../models/emergency_route.dart';
import '../services/location_service.dart';
import '../services/route_service.dart' hide LatLng;
import '../services/notification_service.dart';
import '../services/shared_service.dart';
import '../services/road_network_service.dart';
import 'dart:math' as math;

class EmergencyVehicleViewModel extends ChangeNotifier {
  // 서비스 인스턴스
  final LocationService _locationService = LocationService();
  final RouteService _routeService = RouteService();
  final NotificationService _notificationService = NotificationService();
  final SharedService _sharedService = SharedService();
  final RoadNetworkService _roadNetworkService = RoadNetworkService();

  // 지도 관련 변수
  GoogleMapController? mapController;
  Set<Marker> markers = {};
  Set<Polyline> polylines = {};

  // 카메라 초기 위치 (서울 강남)
  CameraPosition initialCameraPosition = const CameraPosition(
    target: LatLng(37.498095, 127.027610),
    zoom: 14.0,
  );

  // 상태 변수들
  bool emergencyMode = false;
  bool showAlert = false;
  bool isCalculatingRoute = false;
  String routeCalculationError = '';
  EmergencyRouteStatus routeStatus = EmergencyRouteStatus.ready;

  // 구급차 경로 정보
  String currentLocation = ''; // 출발 위치 - 빈 문자열로 시작
  String patientLocation = '';
  String hospitalLocation = '';
  String routePhase = 'pickup'; // 'pickup' 또는 'hospital'

  // 환자 상태 관련 변수 추가
  String patientCondition = '';
  String patientSeverity = '중증';

  // 환자 상태 옵션 (드롭다운에 표시될 목록)
  List<String> patientConditionOptions = [
    '심장마비',
    '뇌출혈',
    '호흡곤란',
    '다발성 외상',
    '골절',
    '의식불명',
    '심한 출혈',
    '화상',
    '중독',
    '기타'
  ];

  List<String> patientSeverityOptions = ['경증', '중등', '중증', '사망'];

  // 경로 정보
  EmergencyRoute? currentRoute;
  String estimatedTime = '계산 중...';
  int notifiedVehicles = 0;

  // 좌표 관련 변수
  LatLng? currentLocationCoord;
  LatLng? patientLocationCoord;
  LatLng? hospitalLocationCoord;

  // 초기화
  Future<void> initialize() async {
    await _initializeLocation();
    await _loadSharedState();
  }

  // 위치 초기화
  Future<void> _initializeLocation() async {
    try {
      // 위치 서비스 활성화 확인
      bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('위치 서비스가 비활성화되어 있습니다.');
        return;
      }

      // 위치 권한 확인
      geo.LocationPermission permission =
      await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) {
          print('위치 권한이 거부되었습니다.');
          return;
        }
      }

      if (permission == geo.LocationPermission.deniedForever) {
        print('위치 권한이 영구적으로 거부되었습니다. 설정에서 권한을 허용해주세요.');
        return;
      }

      // 현재 위치 가져오기
      final position = await geo.Geolocator.getCurrentPosition();

      currentLocationCoord = LatLng(position.latitude, position.longitude);

      // 현재 위치를 빈 문자열로 설정
      currentLocation = '';

      // 초기 마커 설정
      markers = {
        Marker(
          markerId: const MarkerId('current_location'),
          position: currentLocationCoord!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: '현재 위치'),
        ),
      };

      // 카메라 위치 업데이트
      if (mapController != null) {
        mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: currentLocationCoord!, zoom: 15.0),
          ),
        );
      }

      notifyListeners();
    } catch (e) {
      print('위치 정보를 가져오는데 실패했습니다: $e');
    }
  }

  // 공유 상태 로드
  Future<void> _loadSharedState() async {
    // 실제 구현에서는 SharedPreferences나 다른 상태 저장소에서 데이터 로드
    patientLocation = _sharedService.patientLocation;
    hospitalLocation = _sharedService.hospitalLocation;
    routePhase = _sharedService.routePhase;
    notifyListeners();
  }

  // 주소를 좌표로 변환하는 메서드 (Geocoding)
  Future<LatLng?> _geocodeAddress(String address) async {
    try {
      // Geocoding 패키지 활용
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return LatLng(locations.first.latitude, locations.first.longitude);
      }
      return null;
    } catch (e) {
      print('주소 변환 중 오류 발생: $e');
      return null;
    }
  }

  // 출발 위치 업데이트
  Future<void> updateCurrentLocation(String value) async {
    currentLocation = value;
    notifyListeners();

    // 주소를 좌표로 변환
    final coordinates = await _geocodeAddress(value);
    if (coordinates != null) {
      currentLocationCoord = coordinates;

      // 마커 업데이트
      if (markers.isNotEmpty) {
        final Set<Marker> updatedMarkers = Set<Marker>.from(markers);
        updatedMarkers.removeWhere((marker) => marker.markerId == const MarkerId('current_location'));
        updatedMarkers.add(
          Marker(
            markerId: const MarkerId('current_location'),
            position: currentLocationCoord!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(title: '출발 위치: $value'),
          ),
        );
        markers = updatedMarkers;
      }

      // 카메라 위치 업데이트
      if (mapController != null) {
        mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: currentLocationCoord!, zoom: 15.0),
          ),
        );
      }

      notifyListeners();
    }
  }

  // 환자 위치 입력 시 좌표 변환
  Future<void> updatePatientLocation(String value) async {
    patientLocation = value;
    notifyListeners();

    // 공유 서비스에 위치 정보 저장
    _sharedService.setPatientLocation(value);

    // 주소를 좌표로 변환
    final coordinates = await _geocodeAddress(value);
    if (coordinates != null) {
      patientLocationCoord = coordinates;
      notifyListeners();
    }
  }

  // 병원 위치 입력 시 좌표 변환
  Future<void> updateHospitalLocation(String value) async {
    hospitalLocation = value;
    notifyListeners();

    // 공유 서비스에 위치 정보 저장
    _sharedService.setHospitalLocation(value);

    // 주소를 좌표로 변환
    final coordinates = await _geocodeAddress(value);
    if (coordinates != null) {
      hospitalLocationCoord = coordinates;
      notifyListeners();
    }
  }

  // 환자 상태 업데이트 메서드
  void updatePatientCondition(String condition) {
    patientCondition = condition;
    notifyListeners();
  }

  // 환자 중증도 업데이트 메서드
  void updatePatientSeverity(String severity) {
    patientSeverity = severity;
    notifyListeners();
  }

  // 응급 모드 활성화
  Future<void> activateEmergencyMode() async {
    // 필수 입력값 확인
    if (currentLocation.isEmpty) {
      print('출발 위치를 입력해주세요.');
      return;
    }

    if (routePhase == 'pickup') {
      if (patientLocation.isEmpty) {
        print('환자 위치를 입력해주세요.');
        return;
      }

      if (patientCondition.isEmpty) {
        print('환자 상태를 선택해주세요.');
        return;
      }
    } else {
      // hospital 단계
      if (hospitalLocation.isEmpty) {
        print('병원 위치를 입력해주세요.');
        return;
      }
    }

    await calculateAndActivateRoute();
  }

  // 경로 계산 및 알림 활성화
  Future<void> calculateAndActivateRoute() async {
    // 좌표가 설정되지 않은 경우 처리
    if (currentLocationCoord == null ||
        (routePhase == 'pickup' && patientLocationCoord == null) ||
        (routePhase == 'hospital' && hospitalLocationCoord == null)) {
      print('출발지 또는 목적지 좌표가 설정되지 않았습니다.');
      return;
    }

    emergencyMode = true;
    notifyListeners();

    try {
      // 출발지와 목적지 설정
      LatLng origin;
      LatLng destination;
      String destinationName;

      if (routePhase == 'pickup') {
        origin = currentLocationCoord!;
        destination = patientLocationCoord!;
        destinationName = patientLocation;
      } else {
        origin = patientLocationCoord!;
        destination = hospitalLocationCoord!;
        destinationName = hospitalLocation;
      }

      // 지도에 경로 표시
      _displayRoute(origin, destination);

      // 경로 계산
      final routeData = await _routeService.calculateOptimalRoute(
        origin,
        destination,
        isEmergency: true,
      );

      // 주변 차량에 알림 전송 - 환자 상태 정보를 포함한 메시지
      final notifiedCount = await _notificationService
          .sendEmergencyAlertToNearbyVehicles(
        'dummy_route_id',
        '$patientCondition ($patientSeverity) 환자 이송 중입니다. 길을 비켜주세요.',
        1.0, // 1km 반경
      );

      estimatedTime = routeData['estimated_time'] as String;
      notifiedVehicles = notifiedCount;
      showAlert = true;
      notifyListeners();

      // 공유 서비스를 통해 알림 전파 - 환자 상태 정보 포함
      _sharedService.broadcastEmergencyAlert(
        destination: destinationName,
        estimatedTime: estimatedTime,
        approachDirection:
        routePhase == 'pickup' ? '$currentLocation에서 환자 방향' : '환자에서 병원 방향',
        notifiedVehicles: notifiedVehicles,
        patientCondition: patientCondition,
        patientSeverity: patientSeverity,
      );
    } catch (e) {
      print('경로 활성화 중 오류 발생: $e');
      emergencyMode = false;
      showAlert = false;
      notifyListeners();
    }
  }

  // 도로망 고려한 경로 계산 메서드
  Future<void> calculateOptimizedRoute() async {
    isCalculatingRoute = true;
    routeCalculationError = '';
    notifyListeners();

    try {
      // 출발지와 목적지 설정
      LatLng origin;
      LatLng destination;

      if (routePhase == 'pickup') {
        origin = currentLocationCoord!;
        destination = patientLocationCoord!;
      } else {
        origin = patientLocationCoord!;
        destination = hospitalLocationCoord!;
      }

      // 도로망 데이터 가져오기
      final roadNetworkData = await _roadNetworkService.getRoadNetwork(
        dprtrLinkId: 1000001, // TODO: 출발 링크 ID
        arriveLinkId: 1000005, // TODO: 도착 링크 ID
      );

      // 도로망 데이터 기반 경로 생성
      List<LatLng> routePoints = _generateRouteFromNetworkData(roadNetworkData);

      // 경로 표시
      _displayRoute(origin, destination);

      // 상태 업데이트
      estimatedTime = _calculateEstimatedTime(routePoints);
      emergencyMode = true;
      showAlert = true;

      notifyListeners();
    } catch (e) {
      routeCalculationError = '경로 계산 중 오류가 발생했습니다: $e';
      print('경로 계산 오류: $e');
    } finally {
      isCalculatingRoute = false;
      notifyListeners();
    }
  }

  // 도로망 데이터로부터 경로 생성
  List<LatLng> _generateRouteFromNetworkData(Map<String, dynamic> networkData) {
    List<LatLng> routePoints = [];

    // 네트워크 데이터에서 경로 포인트 추출
    if (networkData.containsKey('path') && networkData['path'] is List) {
      for (var point in networkData['path']) {
        if (point.containsKey('lat') && point.containsKey('lng')) {
          routePoints.add(LatLng(point['lat'], point['lng']));
        }
      }
    }

    return routePoints;
  }

  // 예상 시간 계산
  String _calculateEstimatedTime(List<LatLng> routePoints) {
    // 경로 길이 계산
    double totalDistance = 0.0;
    for (int i = 0; i < routePoints.length - 1; i++) {
      totalDistance += _calculateDistance(routePoints[i], routePoints[i + 1]);
    }

    // 응급 차량 평균 속도 가정 (km/h)
    const double avgSpeed = 60.0;

    // 시간 계산 (분 단위)
    int estimatedMinutes = ((totalDistance / 1000) / avgSpeed * 60).round();

    return '$estimatedMinutes분';
  }

  double _calculateDistance(LatLng a, LatLng b) {
    const double earthRadius = 6371000;
    double dLat = (b.latitude - a.latitude) * math.pi / 180.0;
    double dLng = (b.longitude - a.longitude) * math.pi / 180.0;
    double lat1 = a.latitude * math.pi / 180.0;
    double lat2 = b.latitude * math.pi / 180.0;

    double aCalc =
        math.pow(math.sin(dLat / 2), 2) +
            math.pow(math.sin(dLng / 2), 2) * math.cos(lat1) * math.cos(lat2);
    double c = 2 * math.atan2(math.sqrt(aCalc), math.sqrt(1 - aCalc));

    return earthRadius * c;
  }

  // 지도에 경로 표시
  void _displayRoute(LatLng origin, LatLng destination) {
    // 마커 생성
    final originMarker = Marker(
      markerId: const MarkerId('origin'),
      position: origin,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: InfoWindow(
        title: routePhase == 'pickup' ? '출발 위치: $currentLocation' : '환자 위치',
      ),
    );

    final destinationMarker = Marker(
      markerId: const MarkerId('destination'),
      position: destination,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(title: routePhase == 'pickup' ? '환자 위치' : '병원'),
    );

    // 더미 경로 생성 (실제로는 API로 경로 얻기)
    List<LatLng> routePoints = _generateRoutePoints(origin, destination);

    // 폴리라인 생성
    final polyline = Polyline(
      polylineId: const PolylineId('route'),
      points: routePoints,
      color: Colors.blue,
      width: 5,
    );

    markers = {originMarker, destinationMarker};
    polylines = {polyline};
    notifyListeners();

    // 경로가 모두 보이도록 카메라 위치 조정
    mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            math.min(origin.latitude, destination.latitude) - 0.01,
            math.min(origin.longitude, destination.longitude) - 0.01,
          ),
          northeast: LatLng(
            math.max(origin.latitude, destination.latitude) + 0.01,
            math.max(origin.longitude, destination.longitude) + 0.01,
          ),
        ),
        100, // padding
      ),
    );
  }

  // 더미 경로 포인트 생성 (실제로는 API로 대체)
  List<LatLng> _generateRoutePoints(LatLng origin, LatLng destination) {
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

  // 응급 모드 비활성화
  void deactivateEmergencyMode() {
    emergencyMode = false;
    showAlert = false;

    // 지도 마커와 경로 초기화
    markers = {
      Marker(
        markerId: const MarkerId('current_location'),
        position: currentLocationCoord!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: '현재 위치${currentLocation.isNotEmpty ? ": $currentLocation" : ""}'),
      ),
    };
    polylines = {};

    // 지도를 현재 위치로 다시 이동
    mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: currentLocationCoord!, zoom: 15.0),
      ),
    );

    notifyListeners();

    // 공유 서비스를 통해 알림 취소
    _sharedService.cancelEmergencyAlert();
  }

  // 환자 픽업 완료 후 병원 단계로 전환
  void switchToHospitalPhase() {
    // 먼저 현재 응급 모드 비활성화
    deactivateEmergencyMode();

    routePhase = 'hospital';
    currentLocation = patientLocation;

    // 현재 위치를 환자 위치로 업데이트
    currentLocationCoord = patientLocationCoord;

    // 마커 업데이트
    markers = {
      Marker(
        markerId: const MarkerId('current_location'),
        position: currentLocationCoord!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: '현재 위치 (환자)'),
      ),
    };

    // 환자 위치에 맞게 지도 이동
    mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: currentLocationCoord!, zoom: 15.0),
      ),
    );

    notifyListeners();

    // 공유 서비스에 경로 단계 업데이트
    _sharedService.setRoutePhase('hospital');
  }

  // 지도 컨트롤러 설정
  void setMapController(GoogleMapController controller) {
    mapController = controller;
    notifyListeners();
  }

  @override
  void dispose() {
    mapController?.dispose();
    super.dispose();
  }
}