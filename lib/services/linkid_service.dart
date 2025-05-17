import 'dart:convert';
import 'package:http/http.dart' as http;

class LinkIdService {
  static Future<int?> getNearestLinkId(double lat, double lng) async {
    final url = Uri.parse('http://192.168.0.193:5000/linkid'); // 서버 주소 수정

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'lat': lat, 'lng': lng}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['linkid'];
      } else {
        print("서버 오류: ${response.body}");
        return null;
      }
    } catch (e) {
      print("요청 실패: $e");
      return null;
    }
  }
}
