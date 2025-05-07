enum EmergencyRouteStatus {
  ready, // 출동 준비 상태
  toPatient, // 환자 위치로 이동 중
  toHospital, // 병원으로 이동 중
  completed, // 임무 완료
}

// 경로 정보를 저장하는 모델
class EmergencyRoute {
  String baseLocation; // 소방서 위치
  String patientLocation; // 환자 위치
  String hospitalLocation; // 병원 위치
  EmergencyRouteStatus status;

  // 추가 경로 정보
  String? estimatedTime;
  double? distance;
  int? notifiedVehicles;

  // 생성자
  EmergencyRoute({
    required this.baseLocation,
    required this.patientLocation,
    this.hospitalLocation = '',
    this.status = EmergencyRouteStatus.ready,
    this.estimatedTime,
    this.distance,
    this.notifiedVehicles,
  });

  // 현재 출발지와 목적지 가져오기
  Map<String, String> getCurrentRoute() {
    switch (status) {
      case EmergencyRouteStatus.toPatient:
        return {'origin': baseLocation, 'destination': patientLocation};
      case EmergencyRouteStatus.toHospital:
        return {'origin': patientLocation, 'destination': hospitalLocation};
      default:
        return {'origin': '', 'destination': ''};
    }
  }
}
