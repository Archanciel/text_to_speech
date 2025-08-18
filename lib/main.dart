import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_size/window_size.dart';
import 'views/text_to_speech_view.dart';
import 'viewmodels/text_to_speech_vm.dart';

Future<void> main() async {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await _setWindowsAppSizeAndPosition(
      isTest: false,
    );
  }

  runApp(MyApp());
}

/// If app runs on Windows, Linux or MacOS, set the app size
/// and position.
Future<void> _setWindowsAppSizeAndPosition({required bool isTest}) async {
  WidgetsFlutterBinding.ensureInitialized();

  await getScreenList().then((List<Screen> screens) {
    // Assumez que vous voulez utiliser le premier écran (principal)
    final Screen screen = screens.first;
    final Rect screenRect = screen.visibleFrame;

    // Définissez la largeur et la hauteur de votre fenêtre
    double windowWidth = 850;
    double windowHeight = 1480;

    // Calculez la position X pour placer la fenêtre sur le côté droit de l'écran
    final double posX = screenRect.right - windowWidth + 10;
    // Optionnellement, ajustez la position Y selon vos préférences
    final double posY = (screenRect.height - windowHeight) / 2;

    final Rect windowRect = Rect.fromLTWH(
      posX,
      posY,
      windowWidth,
      windowHeight,
    );
    setWindowFrame(windowRect);
  });
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
        create: (context) => TextToSpeechVM(),
        child: TextToSpeechView(),
      ),
    );
  }
}
