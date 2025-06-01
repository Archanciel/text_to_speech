// lib/services/direct_google_tts_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../models/audio_file.dart';
import 'logging_service.dart';

class DirectGoogleTtsService {
  final String _apiKey = 'AIzaSyCcj0KjrlTuj8a6JTdowDMODjZSlTGVGvo';
  
  Future<AudioFile?> convertTextToMP3(String text, String fileName) async {
    try {
      logInfo('=== CONVERSION MP3 DIRECTE VIA API GOOGLE ===');
      
      // Choisir le dossier de destination
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) {
        logInfo('Sélection annulée');
        return null;
      }

      // Préparer le body de la requête
      final requestBody = {
        'input': {'text': text},
        'voice': {
          'languageCode': 'fr-CA',  // Français canadien (Oliver)
          'name': 'fr-CA-Standard-A'
        },
        'audioConfig': {
          'audioEncoding': 'MP3',
          'sampleRateHertz': 24000
        }
      };

      logInfo('Envoi de la requête à Google...');
      logDebug('Texte: "$text"');
      logDebug('Voix: fr-CA-Standard-A');

      // Appel direct à l'API Google
      final response = await http.post(
        Uri.parse('https://texttospeech.googleapis.com/v1/text:synthesize?key=$_apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final audioContent = responseData['audioContent'] as String;
        
        // Décoder le base64
        final audioBytes = base64Decode(audioContent);
        
        logInfo('✅ Audio reçu: ${audioBytes.length} bytes');

        // Sauvegarder le fichier MP3
        final fullFileName = fileName.endsWith('.mp3') ? fileName : '$fileName.mp3';
        final filePath = '$selectedDirectory/$fullFileName';
        
        final file = File(filePath);
        await file.writeAsBytes(audioBytes);

        logInfo('✅ Fichier MP3 sauvegardé: $filePath');

        // Créer l'objet AudioFile
        final audioFile = AudioFile(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: text,
          filePath: filePath,
          createdAt: DateTime.now(),
          sizeBytes: audioBytes.length,
        );

        return audioFile;

      } else {
        logError('Erreur API Google: ${response.statusCode}');
        logError('Réponse: ${response.body}');
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }

    } catch (e) {
      logError('Erreur lors de la conversion directe', e);
      rethrow;
    }
  }

  // Test avec différentes voix
  Future<AudioFile?> convertWithVoice(String text, String fileName, String voiceName) async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) return null;

      final requestBody = {
        'input': {'text': text},
        'voice': {
          'languageCode': voiceName.contains('fr-') ? voiceName.substring(0, 5) : 'fr-FR',
          'name': voiceName
        },
        'audioConfig': {
          'audioEncoding': 'MP3',
          'sampleRateHertz': 24000
        }
      };

      logInfo('Test avec voix: $voiceName');

      final response = await http.post(
        Uri.parse('https://texttospeech.googleapis.com/v1/text:synthesize?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final audioContent = responseData['audioContent'] as String;
        final audioBytes = base64Decode(audioContent);
        
        final fullFileName = fileName.endsWith('.mp3') ? fileName : '$fileName.mp3';
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
        final frenchVoices = voices.where((voice) => 
          (voice['languageCodes'] as List).any((code) => code.toString().startsWith('fr'))
        ).toList();

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
}