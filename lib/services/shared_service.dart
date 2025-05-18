// shared_service.dart

import 'dart:async';

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

    _emergencyAlertController.add({
      'active': false,
    });
  }

  // 서비스 정리
  void dispose() {
    _emergencyAlertController.close();
  }
}