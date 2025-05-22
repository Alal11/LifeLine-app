import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:geocoding/geocoding.dart';
import '../models/emergency_route.dart';
import '../services/location_service.dart';
import '../services/route_service.dart';
import '../services/notification_service.dart';
import '../services/shared_service.dart';
import '../services/road_network_service.dart';
import '../services/hospital_service.dart';
import '../services/optimal_route_service.dart';
import '../services/shared_location_service.dart';
import 'dart:math' as math;

class EmergencyVehicleViewModel extends ChangeNotifier {
  // 서비스 인스턴스
  final LocationService _locationService = LocationService();
  final RouteService _routeService = RouteService();
  final NotificationService _notificationService = NotificationService();
  final SharedService _sharedService = SharedService();
  final RoadNetworkService _roadNetworkService = RoadNetworkService();
  final OptimalRouteService _optimalRouteService = OptimalRouteService();
  SharedLocationService? sharedLocationService;

  void setSharedService(SharedLocationService service) {
    sharedLocationService = service;
  }

  final TextEditingController patientLocationController =
      TextEditingController();
  final TextEditingController hospitalLocationController =
      TextEditingController();
  final TextEditingController currentLocationController =
      TextEditingController();

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
    '기타',
  ];

  List<String> patientSeverityOptions = ['경증', '중등', '중증', '사망'];

  // 추천 병원 목록 (새로 추가)
  List<Hospital> recommendedHospitals = [];
  Hospital? selectedHospital;
  bool isLoadingHospitals = false;

  // 지역별 병원 필터링을 위한 변수 추가
  List<Hospital> _allHospitals = []; // 모든 병원 목록 (필터링 전)
  List<String> availableRegions = []; // 가용 지역 목록
  String? selectedRegion; // 선택된 지역

  // 경로 정보
  EmergencyRoute? currentRoute;
  String estimatedTime = '계산 중...';
  int notifiedVehicles = 0;

  // 좌표 관련 변수
  LatLng? currentLocationCoord;
  LatLng? patientLocationCoord;
  LatLng? hospitalLocationCoord;

  // 초기화
  // 🔥 모든 데이터 초기화 메서드 추가
  void resetAllData() {
    // 응급 모드 비활성화
    if (emergencyMode) {
      deactivateEmergencyMode();
    }

    // 모든 입력 데이터 초기화
    patientLocation = '';
    hospitalLocation = '';
    patientCondition = '';
    patientSeverity = '중증';
    estimatedTime = '계산 중...';
    notifiedVehicles = 0;
    routePhase = 'pickup';

    // 컨트롤러 초기화
    patientLocationController.clear();
    hospitalLocationController.clear();

    // 병원 관련 데이터 초기화
    recommendedHospitals.clear();
    selectedHospital = null;
    _allHospitals.clear();
    availableRegions.clear();
    selectedRegion = null;
    isLoadingHospitals = false;

    // 좌표 초기화
    patientLocationCoord = null;
    hospitalLocationCoord = null;

    // 경로 초기화
    currentRoute = null;
    polylines = {};

    // 상태 플래그 초기화
    emergencyMode = false;
    showAlert = false;
    isCalculatingRoute = false;
    routeCalculationError = '';
    routeStatus = EmergencyRouteStatus.ready;

    // 마커를 현재 위치만 남기고 초기화
    if (currentLocationCoord != null) {
      markers = {
        Marker(
          markerId: const MarkerId('current_location'),
          position: currentLocationCoord!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title:
                '현재 위치${currentLocation.isNotEmpty ? ": $currentLocation" : ""}',
          ),
        ),
      };

      // 지도를 현재 위치로 다시 이동
      mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: currentLocationCoord!, zoom: 15.0),
        ),
      );
    }

    // SharedService 상태 초기화
    _sharedService.cancelEmergencyAlert();

    print('🔄 응급차량 데이터 전체 초기화 완료');
    notifyListeners();
  }

  @override
  Future<void> initialize() async {
    await _initializeLocation();
    await _loadSharedState();

    // 컨트롤러 초기화 및 연결
    currentLocationController.text = currentLocation;
    patientLocationController.text = patientLocation;
    hospitalLocationController.text = hospitalLocation;
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
      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );

      // 현재 위치 좌표 설정
      currentLocationCoord = LatLng(position.latitude, position.longitude);

      // 카메라 초기 위치를 현재 위치로 설정
      initialCameraPosition = CameraPosition(
        target: currentLocationCoord!,
        zoom: 15.0,
      );

      // 현재 위치 주소 가져오기 (선택 사항)
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          currentLocation = '${place.street}, ${place.locality}';
          currentLocationController.text = currentLocation;
        }
      } catch (e) {
        print('주소 변환 중 오류 발생: $e');
        // 주소 변환에 실패해도 위치 좌표는 사용 가능
      }

      // 초기 마커 설정
      markers = {
        Marker(
          markerId: const MarkerId('current_location'),
          position: currentLocationCoord!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title:
                '현재 위치${currentLocation.isNotEmpty ? ": $currentLocation" : ""}',
          ),
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

      print('현재 위치 초기화 완료: $currentLocationCoord');
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

      // 🔥 일반차량들을 현재 위치 근처로 이동
      _sharedService.syncVehicleLocation(coordinates);

      // 마커 업데이트
      if (markers.isNotEmpty) {
        final Set<Marker> updatedMarkers = Set<Marker>.from(markers);
        updatedMarkers.removeWhere(
          (marker) => marker.markerId == const MarkerId('current_location'),
        );
        updatedMarkers.add(
          Marker(
            markerId: const MarkerId('current_location'),
            position: currentLocationCoord!,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
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

      // 🔥 일반차량들을 환자 위치 근처로 이동하도록 SharedService에 알림
      _sharedService.updatePatientLocationAndSyncVehicles(value, coordinates);

      // 일반 차량 위치 자동 공유
      sharedLocationService?.updateLocation(coordinates);

      // 패턴 위치 마커 업데이트 및 지도 이동
      if (mapController != null) {
        // 환자 위치 마커 업데이트
        Set<Marker> updatedMarkers = Set<Marker>.from(markers);
        updatedMarkers.removeWhere(
          (marker) => marker.markerId == MarkerId('patient_location'),
        );
        updatedMarkers.add(
          Marker(
            markerId: MarkerId('patient_location'),
            position: patientLocationCoord!,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
            infoWindow: InfoWindow(title: '환자 위치: $patientLocation'),
          ),
        );
        markers = updatedMarkers;

        // 지도를 환자 위치로 이동
        mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: patientLocationCoord!, zoom: 15.0),
          ),
        );
      }

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

      // 🔥 일반차량들을 병원 위치 근처로 이동
      _sharedService.syncVehicleLocation(coordinates);

      notifyListeners();
    }
  }

  // 환자 상태 업데이트 메서드
  void updatePatientCondition(String condition) {
    patientCondition = condition;

    // 🔥 환자 상태 정보를 SharedService에 업데이트
    _sharedService.updatePatientInfo(condition, patientSeverity);

    notifyListeners();
  }

  // 환자 중증도 업데이트 메서드
  void updatePatientSeverity(String severity) {
    patientSeverity = severity;

    // 🔥 환자 상태 정보를 SharedService에 업데이트
    _sharedService.updatePatientInfo(patientCondition, severity);

    notifyListeners();
  }

  // 환자 위치의 지역 정보 가져오기 - 개선된 버전
  Future<String?> _getPatientRegion() async {
    if (patientLocationCoord == null) return null;

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        patientLocationCoord!.latitude,
        patientLocationCoord!.longitude,
        localeIdentifier: 'ko_KR',
      );

      if (placemarks.isNotEmpty) {
        String? administrativeArea = placemarks.first.administrativeArea;
        print('환자 위치 행정구역: $administrativeArea'); // 디버깅용
        return administrativeArea;
      }
    } catch (e) {
      print('주소 변환 오류: $e');
    }

    return null;
  }

  // 가용한 지역 목록 추출
  List<String> _extractAvailableRegions(List<Hospital> hospitals) {
    final Set<String> regions = {};

    for (var hospital in hospitals) {
      if (hospital.region != null && hospital.region!.isNotEmpty) {
        regions.add(hospital.region!);
      }
    }

    return regions.toList()..sort();
  }

  // 선택된 지역에 따라 병원 필터링
  void _filterHospitalsByRegion() {
    if (selectedRegion == null || _allHospitals.isEmpty) return;

    if (selectedRegion == '전체') {
      recommendedHospitals = List.from(_allHospitals);
    } else {
      recommendedHospitals =
          _allHospitals
              .where((hospital) => hospital.region == selectedRegion)
              .toList();
    }

    // 거리순 정렬 유지
    recommendedHospitals.sort((a, b) => a.distance.compareTo(b.distance));

    notifyListeners();
  }

  // 지역 선택 변경
  void changeRegion(String region) {
    if (selectedRegion == region) return;

    selectedRegion = region;
    _filterHospitalsByRegion();

    // 선택된 지역의 첫 번째 병원으로 선택 변경
    if (recommendedHospitals.isNotEmpty) {
      selectHospital(recommendedHospitals.first);
    } else {
      selectedHospital = null;
      hospitalLocation = '';
      hospitalLocationCoord = null;
    }

    _updateHospitalMarkers();
    notifyListeners();
  }

  // 환자 상태 기반 추천 병원 로드 - 전국 지역 대응 강화
  Future<void> loadRecommendedHospitals() async {
    if (patientLocationCoord == null ||
        patientCondition.isEmpty ||
        patientSeverity.isEmpty) {
      return;
    }

    isLoadingHospitals = true;
    notifyListeners();

    try {
      // 환자 위치의 지역 정보 먼저 확인
      final patientRegion = await _getPatientRegion();
      print('환자 지역: $patientRegion');

      // 모든 병원 목록 가져오기 (지역별 맞춤 검색)
      _allHospitals = await _optimalRouteService.recommendHospitals(
        patientLocationCoord!,
        patientCondition,
        patientSeverity,
        searchRadius: _optimalRouteService.getRegionSearchRadius(
          patientLocationCoord!,
        ),
      );

      print('지역 필터링 후 병원 수: ${_allHospitals.length}');

      // 가용한 지역 목록 추출
      availableRegions = _extractAvailableRegions(_allHospitals);

      // 환자 위치의 지역이 있으면 해당 지역으로 선택, 없으면 첫 번째 지역 선택
      if (patientRegion != null && availableRegions.contains(patientRegion)) {
        selectedRegion = patientRegion;
      } else if (availableRegions.isNotEmpty) {
        selectedRegion = availableRegions.first;
      }

      // 선택된 지역에 맞춰 병원 필터링
      _filterHospitalsByRegion();

      // 추천 병원이 있으면 첫 번째 병원 선택
      if (recommendedHospitals.isNotEmpty) {
        selectedHospital = recommendedHospitals.first;
        hospitalLocation = selectedHospital!.name;
        hospitalLocationCoord = LatLng(
          selectedHospital!.latitude,
          selectedHospital!.longitude,
        );

        // 🔥 선택된 병원 위치로 일반차량들 이동
        _sharedService.syncVehicleLocation(hospitalLocationCoord!);

        // 병원 마커 표시
        _updateHospitalMarkers();
      }
    } catch (e) {
      print('병원 추천 로드 중 오류 발생: $e');
    } finally {
      isLoadingHospitals = false;
      notifyListeners();
    }
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

    print('경로 계산 시작');
    isCalculatingRoute = true;
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

      print('출발: $origin, 도착: $destination');

      // 구글 지도 API에서 경로 가져오기
      List<LatLng> routePoints = [];
      final optimalRouteService = OptimalRouteService();

      try {
        print('Google Maps API로 경로 가져오기');
        routePoints = await optimalRouteService.getGoogleMapsRoute(
          origin,
          destination,
        );
        print('Google Maps API에서 ${routePoints.length}개의 경로 포인트를 가져왔습니다.');

        if (routePoints.isEmpty || routePoints.length <= 2) {
          print('가져온 경로 포인트가 없거나 너무 적음, 더미 경로 생성 시도');
          routePoints = _generateRoutePoints(origin, destination);
        }
      } catch (e) {
        print('Google Maps API 경로 가져오기 실패, 더미 경로 사용: $e');
        routePoints = _generateRoutePoints(origin, destination);
      }

      // 모든 마커 초기화
      final Set<Marker> newMarkers = {};

      // 출발지 마커 추가
      newMarkers.add(
        Marker(
          markerId: const MarkerId('origin'),
          position: origin,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(
            title: routePhase == 'pickup' ? '출발 위치: $currentLocation' : '환자 위치',
          ),
        ),
      );

      // 목적지 마커 추가
      newMarkers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: destination,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: routePhase == 'pickup' ? '환자 위치' : '병원',
          ),
        ),
      );

      // 경로 폴리라인 생성
      final Set<Polyline> newPolylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: routePoints,
          color: Colors.blue,
          width: 5,
        ),
      };

      // 화면 업데이트
      markers = newMarkers;
      polylines = newPolylines;

      print('마커와 폴리라인 설정 완료');
      notifyListeners(); // UI 업데이트

      // 경로가 모두 보이도록 카메라 위치 조정
      if (mapController != null && routePoints.isNotEmpty) {
        // 모든 경로 포인트를 포함하는 경계 계산
        double minLat = double.infinity;
        double maxLat = -double.infinity;
        double minLng = double.infinity;
        double maxLng = -double.infinity;

        // 모든 포인트 확인
        for (var point in routePoints) {
          minLat = math.min(minLat, point.latitude);
          maxLat = math.max(maxLat, point.latitude);
          minLng = math.min(minLng, point.longitude);
          maxLng = math.max(maxLng, point.longitude);
        }

        // 여유 공간 추가
        minLat -= 0.005;
        maxLat += 0.005;
        minLng -= 0.005;
        maxLng += 0.005;

        try {
          mapController!.animateCamera(
            CameraUpdate.newLatLngBounds(
              LatLngBounds(
                southwest: LatLng(minLat, minLng),
                northeast: LatLng(maxLat, maxLng),
              ),
              100, // padding
            ),
          );
          print('지도 카메라 경로 포함하도록 이동 완료');
        } catch (e) {
          print('지도 카메라 이동 오류: $e');

          // 백업 방법: 단순히 두 지점 사이의 중간으로 이동
          mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: LatLng(
                  (origin.latitude + destination.latitude) / 2,
                  (origin.longitude + destination.longitude) / 2,
                ),
                zoom: 13,
              ),
            ),
          );
        }
      }

      // 주변 차량에 알림 전송
      final notifiedCount = await _notificationService
          .sendEmergencyAlertToNearbyVehicles(
            'dummy_route_id',
            '$patientCondition ($patientSeverity) 환자 이송 중입니다. 길을 비켜주세요.',
            1.0, // 1km 반경
          );

      // 기타 정보 업데이트
      emergencyMode = true;
      estimatedTime = '계산 중...'; // 나중에 업데이트
      notifiedVehicles = notifiedCount;
      showAlert = true;

      // 실제 경로 데이터를 기반으로 예상 시간 계산
      if (routePoints.isNotEmpty) {
        // 경로 거리 계산
        double totalDistance = 0;
        for (int i = 0; i < routePoints.length - 1; i++) {
          totalDistance += _calculateDistance(
            routePoints[i],
            routePoints[i + 1],
          );
        }

        // 거리(m)를 기반으로 예상 시간 계산 (응급 차량 속도 60km/h 가정)
        int minutes =
            (totalDistance / 1000 / 60 * 60)
                .round(); // m -> km -> 시간(60km/h) -> 분
        estimatedTime = '$minutes분';
      }

      notifyListeners();

      // 공유 서비스를 통해 알림 전파
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
    } finally {
      isCalculatingRoute = false;
      notifyListeners();
    }
  }

  // 두 지점 간의 거리 계산 (미터 단위)
  double _calculateDistance(LatLng start, LatLng end) {
    const double earthRadius = 6371000; // 지구 반지름 (미터)

    // 위도/경도를 라디안으로 변환
    double lat1 = start.latitude * (math.pi / 180);
    double lon1 = start.longitude * (math.pi / 180);
    double lat2 = end.latitude * (math.pi / 180);
    double lon2 = end.longitude * (math.pi / 180);

    // Haversine 공식
    double dLat = lat2 - lat1;
    double dLon = lon2 - lon1;
    double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  // 지도에 경로 표시
  void _displayRoute(LatLng origin, LatLng destination) async {
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

    // 마커만 먼저 표시 (로딩 상태 표시)
    markers = {originMarker, destinationMarker};
    polylines = {};
    notifyListeners();

    try {
      // 1. OptimalRouteService를 사용하여 실제 경로 가져오기
      List<LatLng> routePoints;

      // 이미 경로 계산이 된 경우
      if (currentRoute != null &&
          currentRoute!.points != null &&
          currentRoute!.points!.isNotEmpty) {
        routePoints = currentRoute!.points!;
      } else {
        // 경로를 계산해야 하는 경우
        final routeData = await _routeService.calculateOptimalRoute(
          origin,
          destination,
          isEmergency: true,
        );
        routePoints = routeData['route_points'] as List<LatLng>;
      }

      // 폴리라인 생성
      final polyline = Polyline(
        polylineId: const PolylineId('route'),
        points: routePoints,
        color: Colors.blue,
        width: 5,
      );

      // 마커와 폴리라인 업데이트
      markers = {originMarker, destinationMarker};
      polylines = {polyline};
      notifyListeners();

      // 경로가 모두 보이도록 카메라 위치 조정
      // 경로 포인트를 모두 포함하는 경계 계산
      double minLat = double.infinity;
      double maxLat = -double.infinity;
      double minLng = double.infinity;
      double maxLng = -double.infinity;

      for (var point in routePoints) {
        minLat = math.min(minLat, point.latitude);
        maxLat = math.max(maxLat, point.latitude);
        minLng = math.min(minLng, point.longitude);
        maxLng = math.max(maxLng, point.longitude);
      }

      // 경계에 패딩 추가
      minLat -= 0.01;
      maxLat += 0.01;
      minLng -= 0.01;
      maxLng += 0.01;

      mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          100, // padding
        ),
      );
    } catch (e) {
      print('경로 표시 중 오류 발생: $e');

      // 오류 발생 시 더미 경로라도 표시
      List<LatLng> dummyRoute = _generateRoutePoints(origin, destination);

      // 폴리라인 생성
      final polyline = Polyline(
        polylineId: const PolylineId('route'),
        points: dummyRoute,
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
        infoWindow: InfoWindow(
          title:
              '현재 위치${currentLocation.isNotEmpty ? ": $currentLocation" : ""}',
        ),
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

  // 추천 병원 선택
  void selectHospital(Hospital hospital) {
    selectedHospital = hospital;
    hospitalLocation = hospital.name;
    hospitalLocationCoord = LatLng(hospital.latitude, hospital.longitude);

    // 병원 마커 업데이트
    _updateHospitalMarkers();

    notifyListeners();
  }

  // 병원 마커 업데이트
  void _updateHospitalMarkers() {
    // 현재 마커에서 병원 마커만 제거
    final Set<Marker> updatedMarkers = Set<Marker>.from(markers);
    updatedMarkers.removeWhere(
      (marker) => marker.markerId.value.startsWith('hospital_'),
    );

    // 모든 추천 병원 마커 추가
    for (int i = 0; i < recommendedHospitals.length; i++) {
      final hospital = recommendedHospitals[i];
      final isSelected = selectedHospital == hospital;

      updatedMarkers.add(
        Marker(
          markerId: MarkerId('hospital_$i'),
          position: LatLng(hospital.latitude, hospital.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isSelected ? BitmapDescriptor.hueRed : BitmapDescriptor.hueViolet,
          ),
          infoWindow: InfoWindow(
            title: hospital.name,
            snippet:
                '병상: ${hospital.availableBeds}개 | 예상 시간: ${(hospital.estimatedTimeSeconds / 60).round()}분',
          ),
        ),
      );
    }

    markers = updatedMarkers;

    // 선택된 병원이 있으면 카메라 이동
    if (selectedHospital != null && mapController != null) {
      // 환자 위치와 병원 위치가 함께 보이도록 카메라 조정
      if (patientLocationCoord != null) {
        final LatLngBounds bounds = LatLngBounds(
          southwest: LatLng(
            math.min(
                  patientLocationCoord!.latitude,
                  selectedHospital!.latitude,
                ) -
                0.01,
            math.min(
                  patientLocationCoord!.longitude,
                  selectedHospital!.longitude,
                ) -
                0.01,
          ),
          northeast: LatLng(
            math.max(
                  patientLocationCoord!.latitude,
                  selectedHospital!.latitude,
                ) +
                0.01,
            math.max(
                  patientLocationCoord!.longitude,
                  selectedHospital!.longitude,
                ) +
                0.01,
          ),
        );

        mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
      }
    }
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
        infoWindow: InfoWindow(title: '현재 위치 (환자): $patientLocation'),
      ),
    };

    // 환자 상태에 맞는 최적 병원 자동 검색
    loadRecommendedHospitals();

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
    patientLocationController.dispose();
    hospitalLocationController.dispose();
    currentLocationController.dispose();
    mapController?.dispose();
    super.dispose();
  }
}
