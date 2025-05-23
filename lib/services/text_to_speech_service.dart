import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import '../models/audio_file.dart';

class TextToSpeechService {
  late FlutterTts _flutterTts;
  bool _isInitialized = false;

  TextToSpeechService() {
    _initTts();
  }

  Future<void> _initTts() async {
    _flutterTts = FlutterTts();
    
    await _flutterTts.setLanguage("fr-FR");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    
    _isInitialized = true;
  }

  Future<AudioFile?> convertTextToAudio(String text) async {
    if (!_isInitialized) {
      await _initTts();
    }

    try {
      // Obtenir le répertoire de stockage
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.wav';
      final filePath = '${directory.path}/$fileName';

      // Configurer la sortie vers un fichier
      await _flutterTts.synthesizeToFile(text, fileName);

      // Créer l'objet AudioFile
      final audioFile = AudioFile(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        filePath: filePath,
        createdAt: DateTime.now(),
      );

      return audioFile;
    } catch (e) {
      print('Erreur lors de la conversion: $e');
      return null;
    }
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await _initTts();
    }

    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }

  Future<List<String>> getAvailableLanguages() async {
    if (!_isInitialized) {
      await _initTts();
    }

    final languages = await _flutterTts.getLanguages;
    return List<String>.from(languages);
  }

  Future<void> setLanguage(String language) async {
    await _flutterTts.setLanguage(language);
  }

  Future<void> setSpeechRate(double rate) async {
    await _flutterTts.setSpeechRate(rate);
  }

  Future<void> setPitch(double pitch) async {
    await _flutterTts.setPitch(pitch);
  }
}
