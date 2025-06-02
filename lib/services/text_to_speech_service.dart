import 'dart:io';
import 'package:cloud_text_to_speech/cloud_text_to_speech.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'logging_service.dart';
import '../models/audio_file.dart';

class TextToSpeechService {
  bool _isInitialized = false;
  List<VoiceGoogle>? _cachedVoices; // Cache des voix
  AudioPlayer? _directAudioPlayer; // Pour la lecture directe

  // Votre clé API Google Cloud fonctionnelle
  final String _apiKey = 'AIzaSyCcj0KjrlTuj8a6JTdowDMODjZSlTGVGvo';

  FlutterTts? _flutterTts;

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

      // ✅ NOUVELLE SYNTAXE (version 2.3.2)
      TtsGoogle.init(params: InitParamsGoogle(apiKey: _apiKey), withLogs: true);

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
    logInfo('=== FALLBACK: LECTURE AVEC FLUTTER_TTS ===');

    try {
      // Initialiser flutter_tts si nécessaire
      _flutterTts ??= FlutterTts();

      // Each voice is a Map containing at least these keys: name, locale
      // - Windows (UWP voices) only: gender, identifier
      // - iOS, macOS only: quality, gender, identifier
      // - Android only: quality, latency, network_required, features
      final List<dynamic> dynamicVoices = await _flutterTts!.getVoices;
      final List<Map<String, String>> voices =
          dynamicVoices
              .map((voice) => Map<String, String>.from(voice as Map))
              .toList();

      final List<Map<String, String>> frenchVoices =
          voices
              .where(
                (voice) =>
                    voice['name']!.startsWith("fr-") &&
                    voice['locale'] == "fr-FR",
              )
              .toList();

      await _flutterTts!.setVoice(frenchVoices[10]);

      // Configuration française
      await _flutterTts!.setSpeechRate(0.4);
      await _flutterTts!.setVolume(1.0);
      await _flutterTts!.setPitch(1.0);

      logInfo('Configuration flutter_tts terminée');
      logInfo('Lecture du texte: "$text"');

      // Lire le texte avec flutter_tts
      final result = await _flutterTts!.speak(text);

      if (result == 1) {
        logInfo('✅ Lecture flutter_tts lancée avec succès');
      } else {
        logWarning('⚠️ Problème avec flutter_tts, code: $result');
      }
    } catch (e) {
      logError('Erreur avec flutter_tts', e);

      // Dernier recours : essayer avec voix par défaut
      try {
        logWarning('Dernier recours avec voix système...');
        await _flutterTts!.setLanguage("en-US"); // Anglais par défaut
        await _flutterTts!.speak(text);
        logInfo('✅ Lecture avec voix anglaise système');
      } catch (finalError) {
        logError('Toutes les options TTS ont échoué', finalError);
        rethrow;
      }
    }
  }

  // Méthode stop() mise à jour
  Future<void> stop() async {
    try {
      // Arrêter les deux systèmes
      await _directAudioPlayer?.stop();
      await _flutterTts?.stop();
      logInfo('Lecture arrêtée (tous systèmes)');
    } catch (e) {
      logError('Erreur lors de l\'arrêt', e);
    }
  }

  Future<List<VoiceGoogle>> getAvailableVoices() async {
    // Attendre que l'initialisation soit terminée
    if (!_isInitialized) {
      await _initTts();
    }

    if (!_isInitialized) {
      throw Exception(
        'Service TTS non initialisé. Vérifiez votre clé API Google Cloud.',
      );
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
      final frenchVoices =
          allVoices
              .where((voice) => voice.locale.code.startsWith("fr-"))
              .toList();
      final otherVoices =
          allVoices
              .where((voice) => !voice.locale.code.startsWith("fr-"))
              .toList();

      logInfo('Voix françaises trouvées: ${frenchVoices.length}');
      logInfo('Autres voix: ${otherVoices.length}');

      // Mettre en cache et retourner
      _cachedVoices = [...frenchVoices, ...otherVoices];
      return _cachedVoices!;
    } catch (e) {
      logInfo('Erreur lors de la récupération des voix: $e');
      if (e.toString().contains('400') ||
          e.toString().contains('Bad Request')) {
        throw Exception(
          'Clé API invalide ou manquante. Vérifiez votre configuration Google Cloud.',
        );
      }
      throw Exception('Erreur de connexion à Google Cloud: $e');
    }
  }

  Future<AudioFile?> convertTextToMP3WithCustomName(
    String text,
    String customFileName,
  ) async {
    try {
      logInfo('=== CONVERSION MP3 DIRECTE (API HTTP) ===');
      logInfo('Texte: "$text"');
      logInfo('Fichier: "$customFileName"');

      // Choisir le dossier
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) {
        logInfo('Sélection annulée');
        return null;
      }

      // Liste des voix à essayer (ordre de préférence)
      final voicesToTry = [
        {'name': 'fr-CA-Standard-A', 'lang': 'fr-CA'}, // Oliver équivalent
        {'name': 'fr-CA-Standard-B', 'lang': 'fr-CA'},
        {'name': 'fr-FR-Standard-A', 'lang': 'fr-FR'},
        {'name': 'fr-FR-Standard-B', 'lang': 'fr-FR'},
      ];

      AudioFile? result;

      // Essayer chaque voix jusqu'à en trouver une qui marche
      for (final voice in voicesToTry) {
        try {
          logInfo('Tentative avec voix: ${voice['name']}');

          final requestBody = {
            'input': {'text': text},
            'voice': {'languageCode': voice['lang'], 'name': voice['name']},
            'audioConfig': {'audioEncoding': 'MP3', 'sampleRateHertz': 24000},
          };

          final response = await http.post(
            Uri.parse(
              'https://texttospeech.googleapis.com/v1/text:synthesize?key=$_apiKey',
            ),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          );

          if (response.statusCode == 200) {
            final responseData = jsonDecode(response.body);
            final audioContent = responseData['audioContent'] as String;
            final audioBytes = base64Decode(audioContent);

            logInfo(
              '✅ Succès avec ${voice['name']}: ${audioBytes.length} bytes',
            );

            // Sauvegarder le fichier
            final fileName =
                customFileName.endsWith('.mp3')
                    ? customFileName
                    : '$customFileName.mp3';
            final filePath = '$selectedDirectory/$fileName';

            final file = File(filePath);
            await file.writeAsBytes(audioBytes);

            logInfo('✅ Fichier sauvegardé: $filePath');

            result = AudioFile(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              text: text,
              filePath: filePath,
              createdAt: DateTime.now(),
              sizeBytes: audioBytes.length,
            );

            break; // Succès ! Sortir de la boucle
          } else {
            logWarning('Échec ${voice['name']}: ${response.statusCode}');
            logDebug('Erreur: ${response.body}');
          }
        } catch (voiceError) {
          logWarning('Erreur avec ${voice['name']}: $voiceError');
          continue; // Essayer la voix suivante
        }
      }

      if (result == null) {
        throw Exception('Toutes les voix ont échoué');
      }

      logInfo('=== CONVERSION MP3 TERMINÉE ===');
      return result;
    } catch (e) {
      logError('Erreur conversion MP3 directe', e);
      rethrow;
    }
  }

  Future<AudioFile?> convertTextToMP3WithVoice(
    String text,
    String fileName,
    dynamic voice,
  ) async {
    if (!_isInitialized) {
      await _initTts();
    }

    if (!_isInitialized) {
      throw Exception(
        'Service TTS non initialisé. Vérifiez votre clé API Google Cloud.',
      );
    }

    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory == null) {
        return null;
      }

      final fullFileName =
          fileName.endsWith('.mp3') ? fileName : '$fileName.mp3';
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
