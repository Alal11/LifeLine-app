// viewmodels/regular_vehicle_viewmodel.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/shared_service.dart';

class RegularVehicleViewModel extends ChangeNotifier {
  // 서비스 인스턴스
  final LocationService _locationService = LocationService();
  final NotificationService _notificationService = NotificationService();
  final SharedService _sharedService = SharedService();
  Set<Polyline> polylines = {};


  // 상태 변수들
  bool showEmergencyAlert = false;
  String currentLocation = '강남구 행복동로';
  String currentSpeed = '0 km/h';

  // 환자 상태 변수 추가
  String patientCondition = '';
  String patientSeverity = '';

  // 알림 정보
  String estimatedArrival = '';
  String approachDirection = '';
  String emergencyDestination = '';

  // 지도 관련 변수
  GoogleMapController? mapController;
  Set<Marker> markers = {};
  LatLng? currentLocationCoord;

  // 카메라 초기 위치 (서울 강남)
  CameraPosition initialCameraPosition = const CameraPosition(
    target: LatLng(37.498095, 127.027610),
    zoom: 14.0,
  );

  // 위치 구독
  StreamSubscription? _locationSubscription;
  StreamSubscription? _alertSubscription;

  // 초기화
  Future<void> initialize() async {
    await _initializeLocation();
    _subscribeToEmergencyAlerts();
  }

  // 위치 초기화 및 구독
  Future<void> _initializeLocation() async {
    try {
      // 현재 위치 가져오기
      final position = await _locationService.getCurrentLocation();

      // 현재 위치 좌표 설정
      currentLocationCoord = LatLng(position.latitude, position.longitude);

      // 초기 마커 설정
      markers = {
        Marker(
          markerId: const MarkerId('current_location'),
          position: currentLocationCoord!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: '내 위치'),
        ),
      };

      // 위치 스트림 구독
      _locationSubscription = _locationService.getPositionStream().listen((
        position,
      ) {
        // 속도 업데이트 (km/h로 변환)
        currentSpeed = '${(position.speed * 3.6).round()} km/h';

        // 위치 업데이트
        currentLocationCoord = LatLng(position.latitude, position.longitude);

        // 마커 업데이트
        markers = {
          Marker(
            markerId: const MarkerId('current_location'),
            position: currentLocationCoord!,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueBlue,
            ),
            infoWindow: const InfoWindow(title: '내 위치'),
          ),
        };

        // 카메라 위치 업데이트
        mapController?.animateCamera(
          CameraUpdate.newLatLng(currentLocationCoord!),
        );

        notifyListeners();
      });
    } catch (e) {
      print('위치 정보를 가져오는데 실패했습니다: $e');
    }
  }

  // 응급차량 알림 구독
  void _subscribeToEmergencyAlerts() {
    // 공유 서비스로부터 응급 알림 구독
    _alertSubscription = _sharedService.emergencyAlertStream.listen((data) {
      if (data['active'] == true) {
        showEmergencyAlert = true;
        estimatedArrival = data['estimatedTime'];
        approachDirection = data['approachDirection'];
        emergencyDestination = data['destination'];
        patientCondition = data['patientCondition'];
        patientSeverity = data['patientSeverity'];

        // 알림 표시 시 효과음 재생
        _notificationService.playAlertSound();
      } else {
        showEmergencyAlert = false;
      }
      notifyListeners();
    });

    // 기존 알림 서비스 구독 (백그라운드 알림용)
    _notificationService.getEmergencyAlerts().listen((alertData) {
      if (!showEmergencyAlert) {
        showEmergencyAlert = true;
        estimatedArrival = alertData['message'].split('분').first + '분 이내';
        approachDirection = alertData['approach_direction'];
        emergencyDestination = alertData['destination'];

        // 알림 효과음 재생
        _notificationService.playAlertSound();
        notifyListeners();
      }
    });
  }

  // 알림 닫기
  void dismissAlert() {
    showEmergencyAlert = false;
    notifyListeners();
  }

  // 지도 컨트롤러 설정
  void setMapController(GoogleMapController controller) {
    mapController = controller;

    // 현재 위치로 카메라 이동
    if (currentLocationCoord != null) {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(currentLocationCoord!, 15),
      );
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _alertSubscription?.cancel();
    mapController?.dispose();
    super.dispose();
  }
}
