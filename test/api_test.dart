import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  test('View-T 도로망 API 호출 테스트', () async {
    final uri = Uri.parse(
      'https://viewt.ktdb.go.kr/cong/api/mainPath_road.do?'
      'DPRTR_LINKID=1000001&ARRIVE_LINKID=1000005&YEAR=2022&WEEKTYPE=0&TIME=all',
    );

    try {
      final response = await http.get(uri);
      print('✅ 상태 코드: ${response.statusCode}');
      print('📦 응답 본문: ${response.body}');
      expect(response.statusCode, 200);
    } catch (e) {
      fail('❌ API 호출 실패: $e');
    }
  });
}
