import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/shared_service.dart';
import '../services/shared_location_service.dart';

class RegularVehicleViewModel extends ChangeNotifier {
  // 서비스 인스턴스
  final LocationService _locationService = LocationService();
  final NotificationService _notificationService = NotificationService();
  final SharedService _sharedService = SharedService();
  final SharedLocationService sharedLocationService;

  // 생성자에서 SharedLocationService 주입
  RegularVehicleViewModel({required this.sharedLocationService});

  // 지도 관련 변수
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng? _currentLocationCoord;

  // 상태 변수들
  bool _showEmergencyAlert = false;
  String _currentLocation = '';
  String _currentSpeed = '0 km/h';
  String _patientCondition = '';
  String _patientSeverity = '';
  String _estimatedArrival = '';
  String _approachDirection = '';
  String _emergencyDestination = '';

  // 카메라 초기 위치 (서울 강남)
  CameraPosition _initialCameraPosition = const CameraPosition(
    target: LatLng(37.498095, 127.027610),
    zoom: 14.0,
  );

  // 위치 구독 관리
  StreamSubscription? _locationSubscription;
  StreamSubscription? _alertSubscription;
  StreamSubscription? _locationSyncSubscription;
  StreamSubscription? _patientInfoSubscription;

  // 디바운싱을 위한 타이머
  Timer? _addressUpdateTimer;
  Timer? _cameraUpdateTimer;

  // 최적화를 위한 플래그들
  bool _isInitialized = false;
  bool _isDisposed = false;
  bool _isUpdatingLocation = false;

  // Public getters
  GoogleMapController? get mapController => _mapController;
  Set<Marker> get markers => _markers;
  Set<Polyline> get polylines => _polylines;
  LatLng? get currentLocationCoord => _currentLocationCoord;
  bool get showEmergencyAlert => _showEmergencyAlert;
  String get currentLocation => _currentLocation;
  String get currentSpeed => _currentSpeed;
  String get patientCondition => _patientCondition;
  String get patientSeverity => _patientSeverity;
  String get estimatedArrival => _estimatedArrival;
  String get approachDirection => _approachDirection;
  String get emergencyDestination => _emergencyDestination;
  CameraPosition get initialCameraPosition => _initialCameraPosition;

  // 초기화
  Future<void> initialize() async {
    if (_isInitialized || _isDisposed) return;

    try {
      await _initializeLocation();
      _subscribeToStreams();
      _isInitialized = true;
      print('RegularVehicleViewModel 초기화 완료');
    } catch (e) {
      print('RegularVehicleViewModel 초기화 실패: $e');
    }
  }

  // 모든 스트림 구독을 하나의 메서드로 통합
  void _subscribeToStreams() {
    _subscribeToEmergencyAlerts();
    _subscribeToLocationSync();
    _subscribeToPatientInfo();
  }

  // 위치 초기화 (최적화된 버전)
  Future<void> _initializeLocation() async {
    try {
      // 위치 권한 확인
      if (!await _checkLocationPermission()) return;

      // 현재 위치 가져오기
      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10), // 타임아웃 설정
      );

      await _updateLocationData(LatLng(position.latitude, position.longitude));

    } catch (e) {
      print('위치 정보를 가져오는데 실패했습니다: $e');
      // 기본 위치로 설정
      await _updateLocationData(const LatLng(37.498095, 127.027610));
    }
  }

  // 위치 권한 확인 (분리된 메서드)
  Future<bool> _checkLocationPermission() async {
    geo.LocationPermission permission = await geo.Geolocator.checkPermission();

    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) {
        print('위치 권한이 거부되었습니다.');
        return false;
      }
    }

    if (permission == geo.LocationPermission.deniedForever) {
      print('위치 권한이 영구적으로 거부되었습니다.');
      return false;
    }

    return true;
  }

  // 위치 데이터 업데이트 (최적화된 버전)
  Future<void> _updateLocationData(LatLng newLocation) async {
    if (_isDisposed) return;

    _currentLocationCoord = newLocation;

    // 초기 카메라 위치 설정
    _initialCameraPosition = CameraPosition(
      target: newLocation,
      zoom: 15.0,
    );

    // 마커 업데이트
    _updateMarkers();

    // 주소 변환은 디바운싱 적용
    _scheduleAddressUpdate(newLocation);

    // 카메라 업데이트
    _scheduleCameraUpdate(newLocation);

    if (_isInitialized) notifyListeners();
  }

  // 주소 업데이트 디바운싱
  void _scheduleAddressUpdate(LatLng location) {
    _addressUpdateTimer?.cancel();
    _addressUpdateTimer = Timer(const Duration(milliseconds: 500), () {
      if (!_isDisposed) {
        _updateAddressFromLocation(location);
      }
    });
  }

  // 카메라 업데이트 디바운싱
  void _scheduleCameraUpdate(LatLng location) {
    _cameraUpdateTimer?.cancel();
    _cameraUpdateTimer = Timer(const Duration(milliseconds: 300), () {
      if (!_isDisposed && _mapController != null) {
        _updateCameraPosition(location);
      }
    });
  }

  // 주소 변환 (최적화된 버전)
  Future<void> _updateAddressFromLocation(LatLng location) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
        localeIdentifier: 'ko_KR',
      ).timeout(const Duration(seconds: 5)); // 타임아웃 설정

      if (placemarks.isNotEmpty && !_isDisposed) {
        _currentLocation = _buildAddressString(placemarks.first, location);
        notifyListeners();
      }
    } catch (e) {
      print('주소 변환 오류: $e');
      if (!_isDisposed) {
        _currentLocation = '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
        notifyListeners();
      }
    }
  }

  // 주소 문자열 생성 (최적화된 버전)
  String _buildAddressString(Placemark place, LatLng location) {
    final addressParts = <String>[];

    // 주요 주소 구성요소만 사용
    if (place.administrativeArea?.isNotEmpty == true) {
      addressParts.add(place.administrativeArea!);
    }

    if (place.subAdministrativeArea?.isNotEmpty == true) {
      addressParts.add(place.subAdministrativeArea!);
    } else if (place.locality?.isNotEmpty == true) {
      addressParts.add(place.locality!);
    }

    if (place.subLocality?.isNotEmpty == true) {
      addressParts.add(place.subLocality!);
    }

    // 도로명 주소 처리
    if (place.thoroughfare?.isNotEmpty == true) {
      if (place.subThoroughfare?.isNotEmpty == true) {
        addressParts.add('${place.thoroughfare!} ${place.subThoroughfare!}');
      } else {
        addressParts.add(place.thoroughfare!);
      }
    }

    final address = addressParts.join(', ');
    return address.isNotEmpty ? address :
    '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
  }

  // 마커 업데이트 (최적화된 버전)
  void _updateMarkers() {
    if (_currentLocationCoord == null) return;

    _markers = {
      Marker(
        markerId: const MarkerId('current_location'),
        position: _currentLocationCoord!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: '현재 위치: $_currentLocation'),
      ),
    };
  }

  // 카메라 위치 업데이트
  void _updateCameraPosition(LatLng location) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: location, zoom: 15.0),
      ),
    );
  }

  // 위치 업데이트 메서드 (최적화된 버전)
  Future<void> updateLocation(LatLng newLocation) async {
    if (_isDisposed || _isUpdatingLocation) return;

    _isUpdatingLocation = true;
    try {
      await _updateLocationData(newLocation);
      print('위치 업데이트 완료: $newLocation');
    } finally {
      _isUpdatingLocation = false;
    }
  }

  // 위치 동기화 구독 (최적화된 버전)
  void _subscribeToLocationSync() {
    _locationSyncSubscription = _sharedService.locationUpdateStream.listen(
          (newLocation) {
        if (!_isDisposed) {
          _moveToNearbyLocation(newLocation);
        }
      },
      onError: (error) => print('위치 동기화 오류: $error'),
    );
  }

  // 근처 위치로 이동 (최적화된 버전)
  void _moveToNearbyLocation(LatLng targetLocation) {
    if (_isDisposed) return;

    final random = Random();
    final offsetLat = (random.nextDouble() - 0.5) * 0.03;
    final offsetLng = (random.nextDouble() - 0.5) * 0.03;

    final nearbyLocation = LatLng(
      targetLocation.latitude + offsetLat,
      targetLocation.longitude + offsetLng,
    );

    print('일반차량 위치를 응급차량 근처로 이동: $nearbyLocation');
    updateLocation(nearbyLocation);
  }

  // 응급차량 알림 구독 (최적화된 버전)
  void _subscribeToEmergencyAlerts() {
    _alertSubscription = _sharedService.emergencyAlertStream.listen(
          (data) {
        if (_isDisposed) return;

        if (data['active'] == true) {
          _showEmergencyAlert = true;
          _estimatedArrival = data['estimatedTime'] ?? '';
          _approachDirection = data['approachDirection'] ?? '';
          _emergencyDestination = data['destination'] ?? '';
          _patientCondition = data['patientCondition'] ?? '';
          _patientSeverity = data['patientSeverity'] ?? '';

          print('🚨 응급 알림 수신: $_patientCondition ($_patientSeverity) - $_emergencyDestination');
          _notificationService.playAlertSound();
        } else {
          _showEmergencyAlert = false;
          print('응급 알림 종료');
        }
        notifyListeners();
      },
      onError: (error) => print('응급 알림 구독 오류: $error'),
    );

    // 기존 알림 서비스 구독 (백그라운드 알림용)
    _notificationService.getEmergencyAlerts().listen(
          (alertData) {
        if (!_showEmergencyAlert && !_isDisposed) {
          _showEmergencyAlert = true;
          _estimatedArrival = alertData['message'].split('분').first + '분 이내';
          _approachDirection = alertData['approach_direction'] ?? '';
          _emergencyDestination = alertData['destination'] ?? '';

          _notificationService.playAlertSound();
          notifyListeners();
        }
      },
      onError: (error) => print('백그라운드 알림 오류: $error'),
    );
  }

  // 환자 정보 구독 (새로 추가)
  void _subscribeToPatientInfo() {
    _patientInfoSubscription = _sharedService.patientInfoStream.listen(
          (patientInfo) {
        if (_isDisposed) return;

        if (patientInfo['condition'] != null) {
          _patientCondition = patientInfo['condition']!;
          _patientSeverity = patientInfo['severity'] ?? '';
          print('환자 정보 업데이트: $_patientCondition ($_patientSeverity)');
          notifyListeners();
        }
      },
      onError: (error) => print('환자 정보 구독 오류: $error'),
    );
  }

  // 알림 닫기
  void dismissAlert() {
    if (_isDisposed) return;
    _showEmergencyAlert = false;
    notifyListeners();
  }

  // 지도 컨트롤러 설정 (최적화된 버전)
  void setMapController(GoogleMapController controller) {
    if (_isDisposed) return;

    _mapController = controller;

    // 현재 위치로 카메라 이동
    if (_currentLocationCoord != null) {
      _updateCameraPosition(_currentLocationCoord!);
    }

    notifyListeners();
  }

  // 메모리 정리 (최적화된 버전)
  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    // 타이머 정리
    _addressUpdateTimer?.cancel();
    _cameraUpdateTimer?.cancel();

    // 스트림 구독 정리
    _locationSubscription?.cancel();
    _alertSubscription?.cancel();
    _locationSyncSubscription?.cancel();
    _patientInfoSubscription?.cancel();

    // 지도 컨트롤러 정리
    _mapController?.dispose();

    print('RegularVehicleViewModel 정리 완료');
    super.dispose();
  }
}