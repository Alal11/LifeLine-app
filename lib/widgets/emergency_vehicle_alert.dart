import 'package:flutter/material.dart';

class EmergencyVehicleAlert extends StatelessWidget {
  final String estimatedArrival;
  final String approachDirection;
  final String destination;
  final String patientCondition; // 추가
  final String patientSeverity; // 추가
  final VoidCallback onDismiss;

  const EmergencyVehicleAlert({
    Key? key,
    required this.estimatedArrival,
    required this.approachDirection,
    required this.destination,
    required this.patientCondition, // 추가
    required this.patientSeverity, // 추가
    required this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.warning_amber, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      '응급차량 접근 중',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                // 닫기 버튼
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: onDismiss,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 환자 상태 정보 (추가)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: _getSeverityColor(patientSeverity).withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "$patientCondition 환자 ($patientSeverity) 이송 중",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 12),

            // 알림 정보
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // 예상 도착 시간
                  Row(
                    children: [
                      const Text(
                        '예상 도착:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        estimatedArrival,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // 접근 방향
                  Row(
                    children: [
                      const Text(
                        '접근 방향:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        approachDirection,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // 목적지
                  Row(
                    children: [
                      const Text(
                        '목적지:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        destination,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 버튼 영역
            Row(
              children: [
                // 확인 버튼
                Expanded(
                  child: ElevatedButton(
                    onPressed: onDismiss,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.check, size: 16),
                        SizedBox(width: 4),
                        Text(
                          '확인',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // 길 안내 받기 버튼
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // 더미 기능
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      '길 안내 받기',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 중증도에 따른 색상 반환 메서드
  Color _getSeverityColor(String severity) {
    switch (severity) {
      case '경증':
        return Colors.green[700]!;
      case '중등':
        return Colors.orange[700]!;
      case '중증':
        return Colors.red[900]!;
      case '사망':
        return Colors.black;
      default:
        return Colors.blue[700]!;
    }
  }
}