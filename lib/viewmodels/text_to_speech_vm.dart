import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/direct_google_tts_service.dart';
import '../services/logging_service.dart';
import '../models/audio_file.dart';
import '../services/text_to_speech_service.dart';
import '../services/audio_player_service.dart';

class TextToSpeechVM extends ChangeNotifier {
  final TextToSpeechService _ttsService = TextToSpeechService();
  final DirectGoogleTtsService _directGoogleTtsService =
      DirectGoogleTtsService();
  final AudioPlayerService _audioPlayerService = AudioPlayerService();

  String _inputText = '';
  bool _isConverting = false;
  bool _isPlaying = false;
  AudioFile? _currentAudioFile;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  // Getters
  String get inputText => _inputText;
  bool get isConverting => _isConverting;
  bool get isPlaying => _isPlaying;
  AudioFile? get currentAudioFile => _currentAudioFile;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;

  TextToSpeechVM() {
    _audioPlayerService.playerStateStream.listen((state) {
      _isPlaying = state == PlayerState.playing;
      notifyListeners();
    });

    _audioPlayerService.positionStream.listen((position) {
      _currentPosition = position;
      notifyListeners();
    });

    _audioPlayerService.durationStream.listen((duration) {
      _totalDuration = duration;
      notifyListeners();
    });
  }

  void updateInputText(String text) {
    _inputText = text;
    notifyListeners();
  }

  Future<void> speakText() async {
    if (_inputText.trim().isEmpty) return;
    await _ttsService.speak(_inputText);
  }

  Future<void> stopSpeaking() async {
    try {
      await _ttsService.stop();
      logInfo('Lecture arrêtée');
    } catch (e) {
      logInfo('Erreur lors de l\'arrêt: $e');
    }
  }

  Future<void> convertTextToMP3WithFileName(String fileName) async {
    if (_inputText.trim().isEmpty) return;

    _isConverting = true;
    notifyListeners();

    try {
      AudioFile? audioFile;

      audioFile = await _directGoogleTtsService.convertTextToMP3(
        _inputText,
        fileName,
      );

      if (audioFile != null) {
        _currentAudioFile = audioFile;
        notifyListeners();
      }
    } catch (e) {
      logInfo('Erreur lors de la conversion: $e');
      rethrow;
    } finally {
      _isConverting = false;
      notifyListeners();
    }
  }

  Future<void> playCurrentAudio() async {
    if (_currentAudioFile != null) {
      await _audioPlayerService.playAudioFile(_currentAudioFile!);
    }
  }

  Future<void> playAudioFile(AudioFile audioFile) async {
    _currentAudioFile = audioFile;
    await _audioPlayerService.playAudioFile(audioFile);
    notifyListeners();
  }

  Future<void> pauseAudio() async {
    await _audioPlayerService.pauseAudio();
  }

  Future<void> stopAudio() async {
    await _audioPlayerService.stopAudio();
  }
}
