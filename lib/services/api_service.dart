import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://100.92.152.84:8000";

  /// 이미지 파일을 서버로 전송해 음식 분석 결과를 받아옴.
  ///
  /// [MultipartRequest] : 일반 JSON 요청과 달리, 파일(바이너리)을 전송할 때 쓰는 방식.
  ///   HTTP 헤더가 `Content-Type: multipart/form-data`로 설정되고,
  ///   파일 데이터가 바이트 스트림으로 나뉘어 전송된다.
  ///
  /// 반환값 [StreamedResponse] : 응답 데이터를 한번에 받지 않고 스트림(조각)으로 받음.
  ///   그래서 호출부에서 `.stream.bytesToString()`으로 전체 응답 텍스트를 조립해야 한다.
  static Future<http.StreamedResponse> analyzeImage(String imagePath) async {
    // POST /analyze 엔드포인트로 multipart 요청 생성
    var request = http.MultipartRequest(
      'POST',
      Uri.parse("$baseUrl/analyze"),
    );

    // 'file' 이라는 필드명으로 이미지 파일 첨부 (서버가 기대하는 필드명과 일치해야 함)
    request.files.add(
      await http.MultipartFile.fromPath('file', imagePath),
    );

    // 요청을 실제로 전송하고 StreamedResponse 반환
    return await request.send();
  }
}
