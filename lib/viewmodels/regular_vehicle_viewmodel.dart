import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart' as geo;
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
  String currentLocation = '';
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
      // 위치 권한 확인 및 요청
      geo.LocationPermission permission = await geo.Geolocator.checkPermission();
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
          desiredAccuracy: geo.LocationAccuracy.high
      );

      currentLocationCoord = LatLng(position.latitude, position.longitude);
      print('초기 위치 좌표: ${position.latitude}, ${position.longitude}');

      // 현재 위치의 주소 가져오기
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
          localeIdentifier: 'ko_KR', // 한국어 로케일 추가
        );

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;

          // 모든 주소 구성요소 로깅하여 확인
          print('주소 구성요소:');
          print('name: ${place.name}');
          print('street: ${place.street}');
          print('thoroughfare: ${place.thoroughfare}');
          print('subThoroughfare: ${place.subThoroughfare}');
          print('locality: ${place.locality}');
          print('subLocality: ${place.subLocality}');
          print('administrativeArea: ${place.administrativeArea}');
          print('subAdministrativeArea: ${place.subAdministrativeArea}');
          print('postalCode: ${place.postalCode}');
          print('country: ${place.country}');

          // 주소 정보 구성 - 한국식 주소 형태로 상세하게 구성
          List<String> addressParts = [];

          // 시/도 (행정구역)
          if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
            addressParts.add(place.administrativeArea!);
          }

          // 구/군 (하위 행정구역)
          if (place.subAdministrativeArea != null && place.subAdministrativeArea!.isNotEmpty) {
            addressParts.add(place.subAdministrativeArea!);
          } else if (place.locality != null && place.locality!.isNotEmpty) {
            addressParts.add(place.locality!);
          }

          // 동/읍/면 (하위 지역)
          if (place.subLocality != null && place.subLocality!.isNotEmpty) {
            addressParts.add(place.subLocality!);
          }

          // 도로명 또는 지번 주소
          if (place.thoroughfare != null && place.thoroughfare!.isNotEmpty) {
            if (place.subThoroughfare != null && place.subThoroughfare!.isNotEmpty) {
              addressParts.add('${place.thoroughfare!} ${place.subThoroughfare!}');
            } else {
              addressParts.add(place.thoroughfare!);
            }
          } else if (place.name != null && place.name!.isNotEmpty && place.name != 'Unnamed Road') {
            addressParts.add(place.name!);
          }

          // 주소 조합
          currentLocation = addressParts.join(', ');

          // 주소가 비어있으면 좌표 표시
          if (currentLocation.trim().isEmpty || currentLocation == ',') {
            currentLocation = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
          }

          print('초기 변환된 주소: $currentLocation');
        } else {
          print('주소 변환 결과 없음. 좌표 사용.');
          currentLocation = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
        }
      } catch (e) {
        print('주소 변환 오류: $e');
        // 주소 변환 실패 시 좌표 사용
        currentLocation = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      }

      // 초기 마커 설정
      markers = {
        Marker(
          markerId: const MarkerId('current_location'),
          position: currentLocationCoord!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: '현재 위치: $currentLocation'),
        ),
      };

      // 초기 카메라 위치 설정
      initialCameraPosition = CameraPosition(
        target: currentLocationCoord!,
        zoom: 15.0,
      );

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

  // 위치 업데이트 메서드
  Future<void> updateLocation(LatLng newLocation) async {
    try {
      print('updateLocation 호출됨: $newLocation'); // 디버깅용 로그 추가

      currentLocationCoord = newLocation;

      // 주소 변환 - 더 상세한 주소 정보 가져오기
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          newLocation.latitude,
          newLocation.longitude,
          localeIdentifier: 'ko_KR', // 한국어 로케일 추가
        );

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;

          // 모든 주소 구성요소 로깅하여 확인
          print('주소 구성요소:');
          print('name: ${place.name}');
          print('street: ${place.street}');
          print('thoroughfare: ${place.thoroughfare}');
          print('subThoroughfare: ${place.subThoroughfare}');
          print('locality: ${place.locality}');
          print('subLocality: ${place.subLocality}');
          print('administrativeArea: ${place.administrativeArea}');
          print('subAdministrativeArea: ${place.subAdministrativeArea}');
          print('postalCode: ${place.postalCode}');
          print('country: ${place.country}');

          // 주소 정보 구성 - 한국식 주소 형태로 상세하게 구성
          List<String> addressParts = [];

          // 시/도 (행정구역)
          if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
            addressParts.add(place.administrativeArea!);
          }

          // 구/군 (하위 행정구역)
          if (place.subAdministrativeArea != null && place.subAdministrativeArea!.isNotEmpty) {
            addressParts.add(place.subAdministrativeArea!);
          } else if (place.locality != null && place.locality!.isNotEmpty) {
            addressParts.add(place.locality!);
          }

          // 동/읍/면 (하위 지역)
          if (place.subLocality != null && place.subLocality!.isNotEmpty) {
            addressParts.add(place.subLocality!);
          }

          // 도로명 또는 지번 주소
          if (place.thoroughfare != null && place.thoroughfare!.isNotEmpty) {
            if (place.subThoroughfare != null && place.subThoroughfare!.isNotEmpty) {
              addressParts.add('${place.thoroughfare!} ${place.subThoroughfare!}');
            } else {
              addressParts.add(place.thoroughfare!);
            }
          } else if (place.name != null && place.name!.isNotEmpty && place.name != 'Unnamed Road') {
            addressParts.add(place.name!);
          }

          // 주소 조합
          currentLocation = addressParts.join(', ');

          // 주소가 비어있으면 좌표 표시
          if (currentLocation.trim().isEmpty || currentLocation == ',') {
            currentLocation = '${newLocation.latitude.toStringAsFixed(4)}, ${newLocation.longitude.toStringAsFixed(4)}';
          }

          print('변환된 주소: $currentLocation'); // 디버깅용 로그 추가
        } else {
          currentLocation = '${newLocation.latitude.toStringAsFixed(4)}, ${newLocation.longitude.toStringAsFixed(4)}';
          print('주소 변환 결과 없음. 좌표 사용.');
        }
      } catch (e) {
        print('주소 변환 오류: $e');
        currentLocation = '${newLocation.latitude.toStringAsFixed(4)}, ${newLocation.longitude.toStringAsFixed(4)}';
      }

      // 마커 업데이트
      markers = {
        Marker(
          markerId: const MarkerId('current_location'),
          position: currentLocationCoord!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: '현재 위치: $currentLocation'),
        ),
      };

      // 카메라 이동
      if (mapController != null) {
        await mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: currentLocationCoord!, zoom: 15.0),
          ),
        );
        print('카메라 이동 완료'); // 디버깅용 로그 추가
      } else {
        print('mapController가 null임'); // 디버깅용 로그 추가
      }

      notifyListeners();
      print('notifyListeners 호출됨'); // 디버깅용 로그 추가
    } catch (e) {
      print('updateLocation 메서드 오류: $e'); // 오류 로깅
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