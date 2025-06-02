// lib/services/direct_google_tts_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_text_to_speech/cloud_text_to_speech.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../models/audio_file.dart';
import 'logging_service.dart';

class DirectGoogleTtsService {
  final String _apiKey = 'AIzaSyCcj0KjrlTuj8a6JTdowDMODjZSlTGVGvo';

  Future<AudioFile?> convertTextToMP3WithVoice(
    String text,
    String customFileName,
    VoiceGoogle? selectedVoice,
  ) async {
    try {
      logInfo('=== CONVERSION MP3 AVEC VOIX SELECTIONNEE ===');
      logInfo('Texte: "$text"');
      logInfo('Fichier: "$customFileName"');
      logInfo('Voix sélectionnée: ${selectedVoice?.name ?? "Aucune"}');

      // Choisir le dossier
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) {
        logInfo('Sélection annulée');
        return null;
      }

      // Préparer la liste des voix à essayer
      List<Map<String, String>> voicesToTry = [];

      // Si une voix est sélectionnée, l'essayer en premier
      if (selectedVoice != null) {
        voicesToTry.add({
          'name': selectedVoice.name,
          'lang': selectedVoice.locale.code,
        });
        logInfo('Utilisation de la voix sélectionnée: ${selectedVoice.name}');
      }

      // Ajouter les voix de fallback si la voix sélectionnée échoue
      final fallbackVoices = [
        {'name': 'fr-FR-Standard-B', 'lang': 'fr-FR'}, // man voice
        {'name': 'fr-FR-Standard-A', 'lang': 'fr-FR'}, // woman voice
      ];

      // Ajouter les fallbacks seulement s'ils ne sont pas déjà dans la liste
      for (final fallback in fallbackVoices) {
        if (!voicesToTry.any((voice) => voice['name'] == fallback['name'])) {
          voicesToTry.add(fallback);
        }
      }

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

          final response = await http
              .post(
                Uri.parse(
                  'https://texttospeech.googleapis.com/v1/text:synthesize?key=$_apiKey',
                ),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(requestBody),
              )
              .timeout(
                Duration(seconds: 30),
                onTimeout: () {
                  throw TimeoutException(
                    'API request timed out',
                    Duration(seconds: 30),
                  );
                },
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
            _handleHttpError(
              response.statusCode,
              response.body,
              voice['name']!,
            );
          }
        } catch (voiceError) {
          logWarning('Erreur avec ${voice['name']}: $voiceError');
          continue; // Essayer la voix suivante
        }
      }

      if (result == null) {
        throw Exception(
          'Toutes les voix ont échoué - Vérifiez votre connexion internet et votre clé API',
        );
      }

      logInfo('=== CONVERSION MP3 TERMINÉE ===');
      return result;
    } catch (e) {
      logError('Erreur conversion MP3 avec voix', e);
      rethrow;
    }
  }

  // Keep your original method for backward compatibility
  Future<AudioFile?> convertTextToMP3(
    String text,
    String customFileName,
  ) async {
    return convertTextToMP3WithVoice(text, customFileName, null);
  }

  // Test avec différentes voix
  Future<AudioFile?> convertWithVoice(
    String text,
    String fileName,
    String voiceName,
  ) async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) return null;

      final requestBody = {
        'input': {'text': text},
        'voice': {
          'languageCode':
              voiceName.contains('fr-') ? voiceName.substring(0, 5) : 'fr-FR',
          'name': voiceName,
        },
        'audioConfig': {'audioEncoding': 'MP3', 'sampleRateHertz': 24000},
      };

      logInfo('Test avec voix: $voiceName');

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

        final fullFileName =
            fileName.endsWith('.mp3') ? fileName : '$fileName.mp3';
        final filePath = '$selectedDirectory/$fullFileName';

        final file = File(filePath);
        await file.writeAsBytes(audioBytes);

        logInfo('✅ Succès avec $voiceName: ${audioBytes.length} bytes');

        return AudioFile(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: text,
          filePath: filePath,
          createdAt: DateTime.now(),
          sizeBytes: audioBytes.length,
        );
      } else {
        logWarning('Échec avec $voiceName: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      logWarning('Erreur avec $voiceName: $e');
      return null;
    }
  }

  // Obtenir la liste des voix disponibles
  Future<List<Map<String, dynamic>>> getAvailableVoices() async {
    try {
      final response = await http.get(
        Uri.parse('https://texttospeech.googleapis.com/v1/voices?key=$_apiKey'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final voices = data['voices'] as List;

        // Filtrer les voix françaises
        final frenchVoices =
            voices
                .where(
                  (voice) => (voice['languageCodes'] as List).any(
                    (code) => code.toString().startsWith('fr'),
                  ),
                )
                .toList();

        logInfo('Voix françaises trouvées: ${frenchVoices.length}');

        return frenchVoices.cast<Map<String, dynamic>>();
      } else {
        logError('Erreur récupération voix: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      logError('Erreur getAvailableVoices', e);
      return [];
    }
  }

  // Helper method to handle specific HTTP status codes
  void _handleHttpError(int statusCode, String responseBody, String voiceName) {
    switch (statusCode) {
      case 400:
        logError(
          'Erreur 400 avec $voiceName: Requête invalide - $responseBody',
        );
        break;
      case 401:
        logError('Erreur 401 avec $voiceName: Clé API invalide ou manquante');
        throw Exception(
          'Clé API Google Cloud invalide. Vérifiez votre configuration.',
        );
      case 403:
        logError(
          'Erreur 403 avec $voiceName: Accès refusé - Quota dépassé ou API désactivée',
        );
        throw Exception(
          'Quota Google Cloud dépassé ou API désactivée. Vérifiez votre compte.',
        );
      case 404:
        logError('Erreur 404 avec $voiceName: Ressource non trouvée');
        break;
      case 429:
        logError('Erreur 429 avec $voiceName: Trop de requêtes');
        throw Exception(
          'Trop de requêtes. Attendez quelques minutes avant de réessayer.',
        );
      case 500:
      case 502:
      case 503:
        logError(
          'Erreur serveur $statusCode avec $voiceName: Problème côté Google',
        );
        break;
      default:
        logWarning('Échec $voiceName: $statusCode - $responseBody');
    }
  }
}
