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
      title: 'Text to MP3',
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
