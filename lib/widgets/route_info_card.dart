import 'package:flutter/material.dart';

class RouteInfoCard extends StatelessWidget {
  final String destination;
  final String routePhase;
  final String estimatedTime;
  final String notifiedVehicles;

  const RouteInfoCard({
    Key? key,
    required this.destination,
    required this.routePhase,
    required this.estimatedTime,
    required this.notifiedVehicles,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.navigation, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Text(
                  routePhase == 'pickup'
                      ? '환자 위치: $destination'
                      : '병원: $destination',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '예상 도착 시간: $estimatedTime',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  '$notifiedVehicles 차량에 알림 전송됨',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
