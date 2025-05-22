// shared_service.dart

import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class SharedService {
  // 싱글톤 패턴 구현
  static final SharedService _instance = SharedService._internal();

  factory SharedService() {
    return _instance;
  }

  SharedService._internal();

  // 상태 저장 변수
  bool _emergencyModeActive = false;
  String _patientLocation = '';
  String _hospitalLocation = '';
  String _routePhase = 'pickup';
  String _estimatedTime = '';
  int _notifiedVehicles = 0;
  String _approachDirection = '';

  // 환자 상태 관련 변수 추가
  String _patientCondition = '';
  String _patientSeverity = '';

  // 🔥 위치 동기화를 위한 스트림 컨트롤러 추가
  final _locationUpdateController = StreamController<LatLng>.broadcast();
  Stream<LatLng> get locationUpdateStream => _locationUpdateController.stream;

  // 🔥 환자 정보 업데이트를 위한 스트림 컨트롤러 추가
  final _patientInfoController = StreamController<Map<String, String>>.broadcast();
  Stream<Map<String, String>> get patientInfoStream => _patientInfoController.stream;

  // 알림 상태 getter
  bool get isEmergencyActive => _emergencyModeActive;
  String get patientLocation => _patientLocation;
  String get hospitalLocation => _hospitalLocation;
  String get routePhase => _routePhase;
  String get estimatedTime => _estimatedTime;
  int get notifiedVehicles => _notifiedVehicles;
  String get approachDirection => _approachDirection;
  String get patientCondition => _patientCondition;
  String get patientSeverity => _patientSeverity;

  // 응급 알림 스트림 컨트롤러
  final _emergencyAlertController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get emergencyAlertStream => _emergencyAlertController.stream;

  // 환자 위치 설정
  void setPatientLocation(String location) {
    _patientLocation = location;
  }

  // 병원 위치 설정
  void setHospitalLocation(String location) {
    _hospitalLocation = location;
  }

  // 경로 단계 설정
  void setRoutePhase(String phase) {
    _routePhase = phase;
  }

  // 🔥 환자 위치가 설정될 때 일반차량 위치도 업데이트
  void updatePatientLocationAndSyncVehicles(String location, LatLng coordinates) {
    _patientLocation = location;
    // 일반차량들의 위치를 환자 근처로 이동
    _locationUpdateController.add(coordinates);
    print('환자 위치 설정 및 일반차량 동기화: $location -> $coordinates');
  }

  // 🔥 응급차량 현재 위치 업데이트시에도 일반차량 동기화
  void syncVehicleLocation(LatLng newLocation) {
    _locationUpdateController.add(newLocation);
    print('일반차량 위치 동기화: $newLocation');
  }

  // 🔥 환자 정보 업데이트
  void updatePatientInfo(String condition, String severity) {
    _patientCondition = condition;
    _patientSeverity = severity;

    // 환자 정보 스트림으로 전송
    _patientInfoController.add({
      'condition': condition,
      'severity': severity,
    });

    print('환자 정보 업데이트: $condition ($severity)');
  }

  // 응급차량에서 알림 전송
  void broadcastEmergencyAlert({
    required String destination,
    required String estimatedTime,
    required String approachDirection,
    required int notifiedVehicles,
    required String patientCondition,  // 추가
    required String patientSeverity,   // 추가
  }) {
    // 상태 저장
    _emergencyModeActive = true;
    _estimatedTime = estimatedTime;
    _approachDirection = approachDirection;
    _notifiedVehicles = notifiedVehicles;
    _patientCondition = patientCondition;
    _patientSeverity = patientSeverity;

    if (_routePhase == 'pickup') {
      _patientLocation = destination;
    } else {
      _hospitalLocation = destination;
    }

    print('🚨 응급 알림 전송: $patientCondition ($patientSeverity) -> $destination');

    // 알림 전송
    _emergencyAlertController.add({
      'active': true,
      'destination': destination,
      'estimatedTime': estimatedTime,
      'approachDirection': approachDirection,
      'notifiedVehicles': notifiedVehicles,
      'patientCondition': patientCondition,
      'patientSeverity': patientSeverity,
    });
  }

  // 응급 알림 종료
  void cancelEmergencyAlert() {
    _emergencyModeActive = false;

    print('응급 알림 종료');

    _emergencyAlertController.add({
      'active': false,
    });
  }

  // 서비스 정리
  void dispose() {
    _emergencyAlertController.close();
    _locationUpdateController.close(); // 🔥 추가
    _patientInfoController.close(); // 🔥 추가
  }
}