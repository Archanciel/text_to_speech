import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart' as path;
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

  Future<AudioFile?> convertTextToAudioWithPicker(String text) async {
    if (!_isInitialized) {
      await _initTts();
    }

    try {
      // Ouvrir le sélecteur de fichier pour choisir l'emplacement
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      
      if (selectedDirectory == null) {
        // L'utilisateur a annulé la sélection
        return null;
      }

      // Demander le nom du fichier (vous pouvez implémenter un dialog pour cela)
      // Pour l'instant, on utilise un nom par défaut avec timestamp
      final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.wav';
      final filePath = '$selectedDirectory${path.separator}$fileName';

      // Créer le fichier temporaire dans le répertoire de l'app
      final tempDirectory = await getTemporaryDirectory();
      final tempFileName = 'temp_$fileName';
      final tempFilePath = '${tempDirectory.path}/$tempFileName';

      // Générer l'audio dans le fichier temporaire
      await _flutterTts.synthesizeToFile(text, tempFileName);

      // Copier le fichier temporaire vers l'emplacement choisi
      final tempFile = File(tempFilePath);
      final finalFile = File(filePath);
      
      if (await tempFile.exists()) {
        await tempFile.copy(filePath);
        await tempFile.delete(); // Supprimer le fichier temporaire
      }

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

  Future<AudioFile?> convertTextToAudioWithCustomName(String text, String customFileName) async {
    if (!_isInitialized) {
      await _initTts();
    }

    try {
      // Ouvrir le sélecteur de fichier pour choisir l'emplacement
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      
      if (selectedDirectory == null) {
        return null;
      }

      // Utiliser le nom personnalisé fourni
      final fileName = customFileName.endsWith('.wav') ? customFileName : '$customFileName.wav';
      final filePath = '$selectedDirectory/$fileName';

      // Créer le fichier temporaire
      final tempDirectory = await getTemporaryDirectory();
      final tempFileName = 'temp_$fileName';
      final tempFilePath = '${tempDirectory.path}/$tempFileName';

      // Générer l'audio
      await _flutterTts.synthesizeToFile(text, tempFileName);

      // Copier vers l'emplacement final
      final tempFile = File(tempFilePath);
      
      if (await tempFile.exists()) {
        await tempFile.copy(filePath);
        await tempFile.delete();
      }

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

  Future<AudioFile?> convertTextToAudio(String text) async {
    if (!_isInitialized) {
      await _initTts();
    }

    try {
      // Obtenir le répertoire de stockage par défaut
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
