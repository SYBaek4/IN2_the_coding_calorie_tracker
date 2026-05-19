import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

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

  // 카메라로 사진 찍기
  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo == null) return;

    // 임시 폴더에 저장
    final tempDir = await getTemporaryDirectory();
    final tempPath = path.join(tempDir.path, 'temp_food_image.jpg');
    final tempFile = await File(photo.path).copy(tempPath);

    setState(() {
      _tempImageFile = tempFile;
    });
  }

  // 임시 파일 삭제
  Future<void> _deleteTempFile() async {
    if (_tempImageFile != null && await _tempImageFile!.exists()) {
      await _tempImageFile!.delete();
      setState(() {
        _tempImageFile = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calorie Tracker'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 사진 미리보기
            if (_tempImageFile != null) ...[
              Image.file(
                _tempImageFile!,
                height: 300,
                width: 300,
                fit: BoxFit.cover,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _deleteTempFile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text('사진 삭제',
                    style: TextStyle(color: Colors.white)),
              ),
            ] else ...[
              const Icon(Icons.camera_alt, size: 100, color: Colors.grey),
              const SizedBox(height: 20),
              const Text('사진을 찍어주세요'),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _takePhoto,
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}