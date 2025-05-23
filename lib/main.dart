// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'views/text_to_speech_view.dart';
import 'viewmodels/text_to_speech_viewmodel.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Text to Speech',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: ChangeNotifierProvider(
        create: (context) => TextToSpeechViewModel(),
        child: TextToSpeechView(),
      ),
    );
  }
}

// lib/models/audio_file.dart
class AudioFile {
  final String id;
  final String text;
  final String filePath;
  final DateTime createdAt;

  AudioFile({
    required this.id,
    required this.text,
    required this.filePath,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'filePath': filePath,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AudioFile.fromJson(Map<String, dynamic> json) {
    return AudioFile(
      id: json['id'],
      text: json['text'],
      filePath: json['filePath'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}