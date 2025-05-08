import 'dart:async';

class NotificationService {
  // 싱글톤 패턴 구현
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  // 로컬 알림 스트림 컨트롤러
  final StreamController<Map<String, dynamic>> _alertController = StreamController<Map<String, dynamic>>.broadcast();

  // 알림 권한 요청 (더미 구현)
  Future<bool> requestNotificationPermission() async {
    // 실제 구현에서는 실제 권한 요청
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }

  // 주변 차량에 알림 전송 (더미 구현)
  Future<int> sendEmergencyAlertToNearbyVehicles(
      String routeId,
      String message,
      double radiusInKm
      ) async {
    // 실제 구현에서는 서버로 알림 요청 전송
    await Future.delayed(const Duration(seconds: 1));

    // 더미 데이터: 주변에 20~40대의 차량이 있다고 가정
    final int vehicleCount = 20 + (DateTime.now().millisecond % 20);

    // 더미 알림 로그
    print('응급 알림이 주변 $vehicleCount대의 차량에 전송되었습니다.');
    print('메시지: $message');
    print('경로 ID: $routeId');
    print('반경: ${radiusInKm}km');

    return vehicleCount;
  }

  // 특정 차량에 알림 전송 (더미 구현)
  Future<bool> sendAlertToVehicle(String vehicleId, String message) async {
    // 실제 구현에서는 FCM이나 다른 푸시 알림 서비스 사용
    await Future.delayed(const Duration(milliseconds: 300));

    // 항상 성공으로 반환
    return true;
  }

  // 알림 리스너 설정 (더미 구현)
  Stream<Map<String, dynamic>> getEmergencyAlerts() {
    // 테스트를 위한 더미 알림 생성
    Future.delayed(const Duration(seconds: 5), () {
      _alertController.add({
        'type': 'emergency_alert',
        'title': '응급차량 접근 중',
        'message': '응급차량이 2분 이내에 접근합니다.',
        'approach_direction': '동남쪽에서 북서쪽',
        'destination': '서울대병원 응급실',
        'route_id': 'dummy_route_123',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    });

    return _alertController.stream;
  }

  // 알림 소리 테스트 (더미 구현)
  Future<void> playAlertSound() async {
    // 실제 구현에서는 실제 소리 재생
    print('알림 소리가 재생됩니다.');
    await Future.delayed(const Duration(milliseconds: 200));
  }

  // 서비스 정리
  void dispose() {
    _alertController.close();
  }
}