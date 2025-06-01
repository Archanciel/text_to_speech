import 'dart:async';
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

  TextToSpeechService() {
    _directAudioPlayer = AudioPlayer();
  }

  Future<void> speak(String text) async {
    logInfo('=== FALLBACK: LECTURE AVEC FLUTTER_TTS ===');

    try {
      _flutterTts ??= FlutterTts();
      await _flutterTts!.setLanguage("fr-FR");
      await _flutterTts!.setSpeechRate(0.6);
      await _flutterTts!.setVolume(1.0);
      await _flutterTts!.setPitch(1.0);

      logInfo('Configuration flutter_tts terminée');
      logInfo('Lecture du texte: "$text"');

      final result = await _flutterTts!.speak(text);

      if (result == 1) {
        logInfo('✅ Lecture flutter_tts lancée avec succès');
      } else {
        logWarning('⚠️ Problème avec flutter_tts, code: $result');
      }
    } catch (e) {
      logError('Erreur avec flutter_tts', e);

      try {
        logWarning('Dernier recours avec voix système...');
        await _flutterTts!.setLanguage("en-US");
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

      // Choisir le dossier
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) {
        logInfo('Sélection annulée');
        return null;
      }

      // Liste des voix à essayer (ordre de préférence)
      final voicesToTry = [
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

          // ENHANCED ERROR HANDLING STARTS HERE
          final response = await http.post(
            Uri.parse(
              'https://texttospeech.googleapis.com/v1/text:synthesize?key=$_apiKey',
            ),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          ).timeout(
            Duration(seconds: 30), // Add timeout
            onTimeout: () {
              throw TimeoutException('API request timed out', Duration(seconds: 30));
            },
          );

          if (response.statusCode == 200) {
            final responseData = jsonDecode(response.body);
            final audioContent = responseData['audioContent'] as String;
            final audioBytes = base64Decode(audioContent);

            logInfo('✅ Succès avec ${voice['name']}: ${audioBytes.length} bytes');

            // Sauvegarder le fichier
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

            break; // Succès ! Sortir de la boucle
          } else {
            // Handle specific HTTP status codes
            _handleHttpError(response.statusCode, response.body, voice['name']!);
          }

        } on SocketException catch (e) {
          // Network connectivity issues
          logError('Erreur réseau avec ${voice['name']}: Vérifiez votre connexion internet', e);
          continue;
        } on TimeoutException catch (e) {
          // Request timeout
          logError('Timeout avec ${voice['name']}: La requête a pris trop de temps', e);
          continue;
        } on HttpException catch (e) {
          // HTTP-specific errors
          logError('Erreur HTTP avec ${voice['name']}: ${e.message}', e);
          continue;
        } on FormatException catch (e) {
          // JSON parsing errors
          logError('Erreur de format JSON avec ${voice['name']}: Réponse API invalide', e);
          continue;
        } on FileSystemException catch (e) {
          // File system errors (writing file)
          logError('Erreur de système de fichiers: Impossible d\'écrire le fichier', e);
          throw Exception('Impossible de sauvegarder le fichier: ${e.message}');
        } catch (e) {
          // Generic error handling for this voice
          logWarning('Erreur générique avec ${voice['name']}: $e');
          continue;
        }
      }

      if (result == null) {
        throw Exception('Toutes les voix ont échoué - Vérifiez votre connexion internet et votre clé API');
      }

      logInfo('=== CONVERSION MP3 TERMINÉE ===');
      return result;

    } on SocketException catch (e) {
      // Global network error
      logError('Erreur de connexion réseau globale', e);
      throw Exception('Pas de connexion internet. Vérifiez votre réseau.');
    } on FileSystemException catch (e) {
      // Global file system error
      logError('Erreur de système de fichiers globale', e);
      throw Exception('Impossible d\'accéder au système de fichiers: ${e.message}');
    } on FormatException catch (e) {
      // Global JSON parsing error
      logError('Erreur de format globale', e);
      throw Exception('Réponse de l\'API invalide. Contactez le support.');
    } on TimeoutException catch (e) {
      // Global timeout error
      logError('Timeout global', e);
      throw Exception('La requête a pris trop de temps. Réessayez plus tard.');
    } catch (e) {
      // Catch any other unexpected errors
      logError('Erreur conversion MP3 directe', e);
      throw Exception('Erreur inattendue lors de la conversion: ${e.toString()}');
    }
  }

  // Helper method to handle specific HTTP status codes
  void _handleHttpError(int statusCode, String responseBody, String voiceName) {
    switch (statusCode) {
      case 400:
        logError('Erreur 400 avec $voiceName: Requête invalide - $responseBody');
        break;
      case 401:
        logError('Erreur 401 avec $voiceName: Clé API invalide ou manquante');
        throw Exception('Clé API Google Cloud invalide. Vérifiez votre configuration.');
      case 403:
        logError('Erreur 403 avec $voiceName: Accès refusé - Quota dépassé ou API désactivée');
        throw Exception('Quota Google Cloud dépassé ou API désactivée. Vérifiez votre compte.');
      case 404:
        logError('Erreur 404 avec $voiceName: Ressource non trouvée');
        break;
      case 429:
        logError('Erreur 429 avec $voiceName: Trop de requêtes');
        throw Exception('Trop de requêtes. Attendez quelques minutes avant de réessayer.');
      case 500:
      case 502:
      case 503:
        logError('Erreur serveur ${statusCode} avec $voiceName: Problème côté Google');
        break;
      default:
        logWarning('Échec $voiceName: $statusCode - $responseBody');
    }
  }

  void dispose() {
    _directAudioPlayer?.dispose();
  }
}