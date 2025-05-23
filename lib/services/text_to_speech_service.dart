import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_text_to_speech/cloud_text_to_speech.dart';
import 'package:file_picker/file_picker.dart';
import '../models/audio_file.dart';

class TextToSpeechService {
  bool _isInitialized = false;
  
  // Votre clé API Google Cloud fonctionnelle
  final String _apiKey = 'AIzaSyCcj0KjrlTuj8a6JTdowDMODjZSlTGVGvo';

  TextToSpeechService() {
    _initTts();
  }

  Future<void> _initTts() async {
    // Éviter la double initialisation
    if (_isInitialized) {
      print('TTS déjà initialisé, skip');
      return;
    }

    try {
      print('=== DEBUT INITIALISATION TTS ===');
      print('Clé API: ${_apiKey.substring(0, 15)}...');
      print('Longueur clé: ${_apiKey.length}');
      
      // Initialiser Google Text-to-Speech
      TtsGoogle.init(
        apiKey: _apiKey,
        withLogs: true,
      );
      
      print('TTS initialisé, test de connexion...');
      _isInitialized = true;
      
      // Test simple pour vérifier que ça marche
      try {
        final testVoices = await TtsGoogle.getVoices();
        print('Test réussi! Nombre de voix: ${testVoices.voices.length}');
        _isInitialized = true;
        print('=== TTS INITIALISE AVEC SUCCES ===');
      } catch (testError) {
        print('Erreur lors du test: $testError');
        _isInitialized = false;
      }
      
    } catch (e) {
      print('Erreur lors de l\'initialisation TTS: $e');
      _isInitialized = false;
    }
  }

  Future<AudioFile?> convertTextToMP3WithCustomName(String text, String customFileName) async {
    if (!_isInitialized) {
      await _initTts();
    }

    if (!_isInitialized) {
      throw Exception('Service TTS non initialisé. Vérifiez votre clé API Google Cloud.');
    }

    try {
      // Ouvrir le sélecteur de fichier pour choisir l'emplacement
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      
      if (selectedDirectory == null) {
        return null;
      }

      // Obtenir les voix disponibles avec gestion d'erreur
      List<VoiceGoogle> voices;
      try {
        final voicesResponse = await TtsGoogle.getVoices();
        voices = voicesResponse.voices;
      } catch (e) {
        print('Erreur lors de la récupération des voix: $e');
        throw Exception('Impossible de récupérer les voix. Vérifiez votre clé API Google Cloud.');
      }
      
      // Sélectionner une voix française ou par défaut
      final voice = voices.isNotEmpty 
          ? (voices.where((element) => element.locale.code.startsWith("fr-")).isNotEmpty
              ? voices.where((element) => element.locale.code.startsWith("fr-")).first
              : voices.first)
          : null;

      if (voice == null) {
        throw Exception('Aucune voix disponible');
      }

      // Utiliser le nom personnalisé fourni
      final fileName = customFileName.endsWith('.mp3') ? customFileName : '$customFileName.mp3';
      final filePath = '$selectedDirectory/$fileName';

      // Paramètres de conversion
      final ttsParams = TtsParamsGoogle(
        voice: voice,
        audioFormat: AudioOutputFormatGoogle.mp3,
        text: text,
        rate: 'default',
        pitch: 'default',
      );

      // Générer l'audio MP3
      final ttsResponse = await TtsGoogle.convertTts(ttsParams);
      
      // Obtenir les bytes audio
      final audioBytes = ttsResponse.audio.buffer.asUint8List();

      // Sauvegarder le fichier MP3
      final file = File(filePath);
      await file.writeAsBytes(audioBytes);

      // Créer l'objet AudioFile
      final audioFile = AudioFile(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        filePath: filePath,
        createdAt: DateTime.now(),
        sizeBytes: audioBytes.length,
      );

      return audioFile;
    } catch (e) {
      print('Erreur lors de la conversion: $e');
      rethrow;
    }
  }

  Future<List<VoiceGoogle>> getAvailableVoices() async {
    // Attendre que l'initialisation soit terminée
    if (!_isInitialized) {
      await _initTts();
    }

    if (!_isInitialized) {
      throw Exception('Service TTS non initialisé. Vérifiez votre clé API Google Cloud.');
    }

    try {
      print('Récupération des voix...');
      final voicesResponse = await TtsGoogle.getVoices();
      final allVoices = voicesResponse.voices;
      
      // Filtrer les voix françaises en premier, puis toutes les autres
      final frenchVoices = allVoices.where((voice) => voice.locale.code.startsWith("fr-")).toList();
      final otherVoices = allVoices.where((voice) => !voice.locale.code.startsWith("fr-")).toList();
      
      print('Voix françaises trouvées: ${frenchVoices.length}');
      print('Autres voix: ${otherVoices.length}');
      
      // Retourner les voix françaises en premier
      return [...frenchVoices, ...otherVoices];
    } catch (e) {
      print('Erreur lors de la récupération des voix: $e');
      if (e.toString().contains('400') || e.toString().contains('Bad Request')) {
        throw Exception('Clé API invalide ou manquante. Vérifiez votre configuration Google Cloud.');
      }
      throw Exception('Erreur de connexion à Google Cloud: $e');
    }
  }

  Future<AudioFile?> convertTextToMP3WithVoice(String text, String fileName, VoiceGoogle voice) async {
    if (!_isInitialized) {
      await _initTts();
    }

    if (!_isInitialized) {
      throw Exception('Service TTS non initialisé. Vérifiez votre clé API Google Cloud.');
    }

    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      
      if (selectedDirectory == null) {
        return null;
      }

      final fullFileName = fileName.endsWith('.mp3') ? fileName : '$fileName.mp3';
      final filePath = '$selectedDirectory/$fullFileName';

      final ttsParams = TtsParamsGoogle(
        voice: voice,
        audioFormat: AudioOutputFormatGoogle.mp3,
        text: text,
        rate: 'default',
        pitch: 'default',
      );

      final ttsResponse = await TtsGoogle.convertTts(ttsParams);
      final audioBytes = ttsResponse.audio.buffer.asUint8List();

      final file = File(filePath);
      await file.writeAsBytes(audioBytes);

      final audioFile = AudioFile(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        filePath: filePath,
        createdAt: DateTime.now(),
        sizeBytes: audioBytes.length,
      );

      return audioFile;
    } catch (e) {
      print('Erreur lors de la conversion: $e');
      rethrow;
    }
  }

  // Méthode pour tester la clé API
  Future<bool> testApiKey() async {
    try {
      if (_apiKey == 'VOTRE_CLE_API_GOOGLE_CLOUD' || _apiKey.isEmpty) {
        return false;
      }

      TtsGoogle.init(
        apiKey: _apiKey,
        withLogs: true,
      );

      final voicesResponse = await TtsGoogle.getVoices();
      return voicesResponse.voices.isNotEmpty;
    } catch (e) {
      print('Test de la clé API échoué: $e');
      return false;
    }
  }
}
