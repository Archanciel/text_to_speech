import 'dart:io';
import 'package:cloud_text_to_speech/cloud_text_to_speech.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'logging_service.dart';
import '../models/audio_file.dart';

class TextToSpeechService {
  bool _isInitialized = false;
  List<VoiceGoogle>? _cachedVoices; // Cache des voix
  AudioPlayer? _directAudioPlayer; // Pour la lecture directe
  
  // Votre clé API Google Cloud fonctionnelle
  final String _apiKey = 'AIzaSyCcj0KjrlTuj8a6JTdowDMODjZSlTGVGvo';

  TextToSpeechService() {
    _initTts();
    _directAudioPlayer = AudioPlayer();
  }

  Future<void> _initTts() async {
    // Éviter la double initialisation
    if (_isInitialized) {
      logInfo('TTS déjà initialisé, skip');
      return;
    }

    try {
      logInfo('=== DEBUT INITIALISATION TTS ===');
      logInfo('Clé API: ${_apiKey.substring(0, 15)}...');
      logInfo('Longueur clé: ${_apiKey.length}');
      
      // Initialiser Google Text-to-Speech
      TtsGoogle.init(
        apiKey: _apiKey,
        withLogs: true,
      );
      
      logInfo('TTS initialisé, test de connexion...');
      _isInitialized = true;
      
      // Test simple pour vérifier que ça marche
      try {
        final testVoices = await TtsGoogle.getVoices();
        logInfo('Test réussi! Nombre de voix: ${testVoices.voices.length}');
        logInfo('=== TTS INITIALISE AVEC SUCCES ===');
      } catch (testError) {
        logInfo('Erreur lors du test: $testError');
      }
      
    } catch (e) {
      logInfo('Erreur lors de l\'initialisation TTS: $e');
      _isInitialized = false;
    }
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await _initTts();
    }

    try {
      logInfo('=== LECTURE DIRECTE AVEC CLOUD TTS ===');
      
      // Obtenir les voix disponibles
      final voices = await getAvailableVoices();
      if (voices.isEmpty) {
        throw Exception('Aucune voix disponible');
      }

      // Sélectionner la même voix que pour les MP3 (Oliver fr-CA ou première française)
      dynamic voice;
      final oliverVoice = voices.where((v) => 
        v.name.toLowerCase().contains('oliver')
      ).toList();
      
      if (oliverVoice.isNotEmpty) {
        voice = oliverVoice.first;
        logInfo('Utilisation de la voix oliver (fr-CA) pour la lecture directe');
      } else {
        final frenchVoices = voices.where((v) => v.locale.code.startsWith("fr-")).toList();
        voice = frenchVoices.isNotEmpty ? frenchVoices.first : voices.first;
        logInfo('Utilisation de la voix: ${voice.name}');
      }

      // Paramètres de conversion pour audio temporaire
      final ttsParams = TtsParamsGoogle(
        voice: voice,
        audioFormat: AudioOutputFormatGoogle.mp3,
        text: text,
        rate: null,
        pitch: null,
      );

      logInfo('Génération audio temporaire...');
      
      // Générer l'audio avec Cloud TTS
      final ttsResponse = await TtsGoogle.convertTts(ttsParams);
      final audioBytes = ttsResponse.audio.buffer.asUint8List();

      logInfo('Audio généré: ${audioBytes.length} bytes');

      // Créer un fichier temporaire
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_speak_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await tempFile.writeAsBytes(audioBytes);

      logInfo('Lecture du fichier temporaire...');

      // Lire le fichier temporaire avec AudioPlayer
      await _directAudioPlayer?.play(DeviceFileSource(tempFile.path));

      // Supprimer le fichier temporaire après un délai
      Future.delayed(Duration(seconds: 30), () async {
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
            logInfo('Fichier temporaire supprimé');
          }
        } catch (e) {
          logInfo('Erreur lors de la suppression du fichier temporaire: $e');
        }
      });

    } catch (e) {
      logInfo('Erreur lors de la lecture: $e');
      rethrow;
    }
  }

  Future<void> stop() async {
    try {
      await _directAudioPlayer?.stop();
      logInfo('Lecture arrêtée');
    } catch (e) {
      logInfo('Erreur lors de l\'arrêt: $e');
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

    // Utiliser le cache si disponible
    if (_cachedVoices != null) {
      logInfo('Utilisation du cache de voix (${_cachedVoices!.length} voix)');
      return _cachedVoices!;
    }

    try {
      logInfo('Récupération des voix depuis l\'API...');
      final voicesResponse = await TtsGoogle.getVoices();
      final allVoices = voicesResponse.voices;
      
      // Filtrer les voix françaises en premier, puis toutes les autres
      final frenchVoices = allVoices.where((voice) => voice.locale.code.startsWith("fr-")).toList();
      final otherVoices = allVoices.where((voice) => !voice.locale.code.startsWith("fr-")).toList();
      
      logInfo('Voix françaises trouvées: ${frenchVoices.length}');
      logInfo('Autres voix: ${otherVoices.length}');
      
      // Mettre en cache et retourner
      _cachedVoices = [...frenchVoices, ...otherVoices];
      return _cachedVoices!;
    } catch (e) {
      logInfo('Erreur lors de la récupération des voix: $e');
      if (e.toString().contains('400') || e.toString().contains('Bad Request')) {
        throw Exception('Clé API invalide ou manquante. Vérifiez votre configuration Google Cloud.');
      }
      throw Exception('Erreur de connexion à Google Cloud: $e');
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
      logInfo('=== DEBUT CONVERSION MP3 ===');
      logInfo('Texte à convertir: "$text"');
      logInfo('Longueur du texte: ${text.length} caractères');
      logInfo('Nom de fichier: "$customFileName"');
      
      // Vérifier la longueur du texte
      if (text.isEmpty) {
        throw Exception('Le texte ne peut pas être vide');
      }
      
      if (text.length > 5000) {
        logInfo('ATTENTION: Texte très long (${text.length} caractères)');
      }
      
      // Ouvrir le sélecteur de fichier pour choisir l'emplacement
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      
      if (selectedDirectory == null) {
        logInfo('Sélection de dossier annulée');
        return null;
      }

      logInfo('Dossier sélectionné: $selectedDirectory');

      // Utiliser les voix en cache plutôt que de les récupérer à nouveau
      final voices = await getAvailableVoices();
      
      if (voices.isEmpty) {
        throw Exception('Aucune voix disponible');
      }

      // Sélectionner une voix française en priorisant Oliver (fr-CA)
      dynamic voice;
      
      final oliverVoice = voices.where((v) => 
        v.name.toLowerCase().contains('oliver')
      ).toList();
      
      if (oliverVoice.isNotEmpty) {
        voice = oliverVoice.first;
        logInfo('Utilisation de la voix oliver (fr-CA) - voix testée et fonctionnelle');
      } else {
        final frenchVoices = voices.where((v) => v.locale.code.startsWith("fr-")).toList();
        if (frenchVoices.isNotEmpty) {
          voice = frenchVoices.first;
          logInfo('Utilisation de la voix française par défaut: ${voice.name}');
        } else {
          voice = voices.first;
          logInfo('Utilisation de la première voix disponible: ${voice.name}');
        }
      }

      logInfo('Voix sélectionnée: ${voice.name} (${voice.locale.code})');

      // Utiliser le nom personnalisé fourni
      final fileName = customFileName.endsWith('.mp3') ? customFileName : '$customFileName.mp3';
      final filePath = '$selectedDirectory/$fileName';

      logInfo('Chemin final: $filePath');

      // Paramètres de conversion avec des valeurs simples et valides
      final ttsParams = TtsParamsGoogle(
        voice: voice,
        audioFormat: AudioOutputFormatGoogle.mp3,
        text: text,
        rate: null, // Laisser par défaut
        pitch: null, // Laisser par défaut
      );

      logInfo('Paramètres TTS configurés:');
      logInfo('  - Voix: ${voice.name}');
      logInfo('  - Locale: ${voice.locale.code}');
      logInfo('  - Format: MP3');
      logInfo('  - Texte: "${text.substring(0, text.length.clamp(0, 30))}${text.length > 30 ? '...' : ''}"');
      logInfo('  - Rate: null (défaut)');
      logInfo('  - Pitch: null (défaut)');

      logInfo('Lancement de la conversion...');
      
      // Générer l'audio MP3
      final ttsResponse = await TtsGoogle.convertTts(ttsParams);
      
      logInfo('Conversion réussie, récupération des bytes...');
      
      // Obtenir les bytes audio
      final audioBytes = ttsResponse.audio.buffer.asUint8List();

      logInfo('Bytes audio récupérés: ${audioBytes.length} bytes');

      // Sauvegarder le fichier MP3
      final file = File(filePath);
      await file.writeAsBytes(audioBytes);

      logInfo('Fichier MP3 sauvegardé: $filePath');

      // Créer l'objet AudioFile
      final audioFile = AudioFile(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        filePath: filePath,
        createdAt: DateTime.now(),
        sizeBytes: audioBytes.length,
      );

      logInfo('=== CONVERSION MP3 TERMINEE ===');
      return audioFile;
    } catch (e) {
      logInfo('Erreur lors de la conversion: $e');
      rethrow;
    }
  }

  Future<AudioFile?> convertTextToMP3WithVoice(String text, String fileName, dynamic voice) async {
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
        rate: null,
        pitch: null,
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
      logInfo('Erreur lors de la conversion: $e');
      rethrow;
    }
  }

  // Méthode pour nettoyer les ressources
  void dispose() {
    _directAudioPlayer?.dispose();
  }
}
