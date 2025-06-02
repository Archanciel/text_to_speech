import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'logging_service.dart';
import '../models/audio_file.dart';

class TextToSpeechService {
  AudioPlayer? _directAudioPlayer;
  final String _apiKey = 'AIzaSyCcj0KjrlTuj8a6JTdowDMODjZSlTGVGvo';
  FlutterTts? _flutterTts;
  
  // Completion callback
  Function()? _onSpeechComplete;

  TextToSpeechService() {
    _directAudioPlayer = AudioPlayer();
    _initializeTts();
  }

  // Initialize TTS with all handlers
  Future<void> _initializeTts() async {
    _flutterTts = FlutterTts();
    
    // Set up completion handler
    _flutterTts!.setCompletionHandler(() {
      logInfo('TTS completed - calling completion callback');
      if (_onSpeechComplete != null) {
        _onSpeechComplete!();
      }
    });

    // Set up error handler
    _flutterTts!.setErrorHandler((msg) {
      logError('TTS Error: $msg');
      if (_onSpeechComplete != null) {
        _onSpeechComplete!();
      }
    });
  }

  // Method to set completion callback from ViewModel
  void setCompletionHandler(Function() onComplete) {
    _onSpeechComplete = onComplete;
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
          voices.where((voice) => voice['locale'] == "fr-FR").toList();

      bool isVoiceMan = true;
      Map<String, String>? selectedVoice; // man voice
      double voiceSpeed; // man voice speed

      if (Platform.isWindows) {
        if (isVoiceMan) {
          selectedVoice = frenchVoices[2]; // man voice
          voiceSpeed = 0.5; // man voice speed
        } else {
          selectedVoice = frenchVoices[0]; // woman voice
          voiceSpeed = 0.6; // woman voice speed
        }
      } else {
        if (isVoiceMan) {
          selectedVoice = frenchVoices[10]; // man voice
          voiceSpeed = 0.5; // man voice speed
        } else {
          selectedVoice = frenchVoices[5]; // woman voice
          voiceSpeed = 0.6; // woman voice speed
        }
      }

      await _flutterTts!.setVoice(selectedVoice);

      // Configuration française
      await _flutterTts!.setSpeechRate(voiceSpeed);
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

  Future<void> stop() async {
    try {
      await _directAudioPlayer?.stop();
      await _flutterTts?.stop();
      logInfo('Lecture arrêtée (tous systèmes)');
    } catch (e) {
      logError('Erreur lors de l\'arrêt', e);
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

      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) {
        logInfo('Sélection annulée');
        return null;
      }

      final voicesToTry = [
        {'name': 'fr-CA-Standard-A', 'lang': 'fr-CA'},
        {'name': 'fr-CA-Standard-B', 'lang': 'fr-CA'},
        {'name': 'fr-FR-Standard-A', 'lang': 'fr-FR'},
        {'name': 'fr-FR-Standard-B', 'lang': 'fr-FR'},
      ];

      AudioFile? result;

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

            logInfo('✅ Succès avec ${voice['name']}: ${audioBytes.length} bytes');

            final fileName = customFileName.endsWith('.mp3')
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

            break;
          } else {
            logWarning('Échec ${voice['name']}: ${response.statusCode}');
            logDebug('Erreur: ${response.body}');
          }
        } catch (voiceError) {
          logWarning('Erreur avec ${voice['name']}: $voiceError');
          continue;
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

  void dispose() {
    _directAudioPlayer?.dispose();
    _flutterTts = null;
  }
}