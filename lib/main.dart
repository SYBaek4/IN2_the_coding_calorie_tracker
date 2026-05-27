import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'services/api_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calorie Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const CameraPage(),
    );
  }
}

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});
  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  File? _tempImageFile;
  final ImagePicker _picker = ImagePicker();

  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo == null) return;
    final tempDir = await getTemporaryDirectory();
    final tempPath = path.join(tempDir.path, 'temp_food_image.jpg');
    final tempFile = await File(photo.path).copy(tempPath);
    setState(() => _tempImageFile = tempFile);
  }

  Future<void> _pickFromGallery() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.gallery);
    if (photo == null) return;
    final tempDir = await getTemporaryDirectory();
    final tempPath = path.join(tempDir.path, 'temp_food_image.jpg');
    final tempFile = await File(photo.path).copy(tempPath);
    setState(() => _tempImageFile = tempFile);
  }

  Future<void> _analyzeImage() async {
    if (_tempImageFile == null) return;

    // 분석에 시간이 걸리므로 로딩 다이얼로그를 먼저 띄움
    showDialog(
      context: context,
      barrierDismissible: false, // 바깥 탭해도 닫히지 않게
      builder: (context) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('분석 중...'),
          ],
        ),
      ),
    );

    try {
      // ── 1. API 호출 ──────────────────────────────────────────────
      // 이미지 파일 경로를 넘기면 ApiService가 multipart/form-data로 서버에 전송
      final response = await ApiService.analyzeImage(_tempImageFile!.path);

      // ── 2. 응답 수신 ─────────────────────────────────────────────
      // StreamedResponse는 스트림(조각)으로 오므로 bytesToString()으로 합쳐서 문자열로 변환
      // 결과 예시: '{"success":true,"data":{...}}'
      final responseBody = await response.stream.bytesToString();

      // ── 3. JSON 파싱 ─────────────────────────────────────────────
      // 문자열을 Dart Map으로 변환. 이후 json['key'] 형태로 값을 꺼낼 수 있음
      final json = jsonDecode(responseBody);

      if (!mounted) return; // 비동기 중 위젯이 사라졌을 때 대비
      Navigator.of(context).pop(); // 로딩 닫기

      // ── 4. 결과 처리 ─────────────────────────────────────────────
      // 서버 응답 구조: { "success": true, "data": { "top_food": ..., "nutrition": {...} } }
      if (json['success'] == true) {
        _showResultBottomSheet(json['data'] as Map<String, dynamic>);
      } else {
        _showError('분석 실패');
      }
    } catch (e) {
      // 네트워크 오류, 타임아웃, JSON 파싱 실패 등 모든 예외를 잡음
      if (!mounted) return;
      Navigator.of(context).pop();
      _showError('서버 연결 실패: $e');
    }
  }

  void _showResultBottomSheet(Map<String, dynamic> data) {
    // ── 서버 응답 데이터 구조 ─────────────────────────────────────
    // data = {
    //   "top_food": "burger",          // AI가 예측한 음식 이름
    //   "confidence": 0.8134,          // 예측 신뢰도 (0.0 ~ 1.0)
    //   "predictions": [...],          // 상위 N개 예측 목록
    //   "nutrition": {
    //     "calories_per_100g": 161.0,
    //     "protein_per_100g": 10.7,
    //     "fat_per_100g": 12.5,
    //     "carbs_per_100g": 3.6,
    //   },
    //   "model_type": "keras-mobilenetv2"
    // }

    // as String? : JSON 값이 null일 수도 있어서 nullable 타입으로 캐스팅, ?? 로 기본값 처리
    final topFood = (data['top_food'] as String? ?? '알 수 없음')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w)
        .join(' ');

    // num? → double : JSON 숫자는 int일 수도 float일 수도 있어서 num으로 받고 toDouble() 변환
    final confidence = (data['confidence'] as num?)?.toDouble() ?? 0.0;
    final nutrition = data['nutrition'] as Map<String, dynamic>?;

    final calories = (nutrition?['calories_per_100g'] as num?)?.toDouble() ?? 0.0;
    final protein = (nutrition?['protein_per_100g'] as num?)?.toDouble() ?? 0.0;
    final fat = (nutrition?['fat_per_100g'] as num?)?.toDouble() ?? 0.0;
    final carbs = (nutrition?['carbs_per_100g'] as num?)?.toDouble() ?? 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              topFood,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '신뢰도 ${(confidence * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: confidence,
                      minHeight: 8,
                      backgroundColor: Colors.grey[200],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              '영양 정보 (100g 기준)',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.0,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _NutritionCard(
                  label: '칼로리',
                  value: calories.toStringAsFixed(0),
                  unit: 'kcal',
                  color: Colors.orange,
                ),
                _NutritionCard(
                  label: '단백질',
                  value: protein.toStringAsFixed(1),
                  unit: 'g',
                  color: Colors.blue,
                ),
                _NutritionCard(
                  label: '지방',
                  value: fat.toStringAsFixed(1),
                  unit: 'g',
                  color: Colors.red,
                ),
                _NutritionCard(
                  label: '탄수화물',
                  value: carbs.toStringAsFixed(1),
                  unit: 'g',
                  color: Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('오류'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calorie Tracker')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_tempImageFile != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(_tempImageFile!, height: 300, fit: BoxFit.cover),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _analyzeImage,
                icon: const Icon(Icons.search),
                label: const Text('분석하기'),
              ),
            ] else
              const Text('사진을 찍거나 선택해주세요'),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'gallery',
            onPressed: _pickFromGallery,
            child: const Icon(Icons.photo_library),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'camera',
            onPressed: _takePhoto,
            child: const Icon(Icons.camera_alt),
          ),
        ],
      ),
    );
  }
}

class _NutritionCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _NutritionCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
