import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/audio_file.dart';
import '../services/text_to_speech_service.dart';
import '../services/audio_player_service.dart';

class TextToSpeechViewModel extends ChangeNotifier {
  final TextToSpeechService _ttsService = TextToSpeechService();
  final AudioPlayerService _audioPlayerService = AudioPlayerService();

  String _inputText = '';
  bool _isConverting = false;
  bool _isPlaying = false;
  AudioFile? _currentAudioFile;
  List<AudioFile> _audioHistory = [];
  String _selectedLanguage = 'fr-FR';
  double _speechRate = 0.5;
  double _pitch = 1.0;
  List<String> _availableLanguages = [];

  // Getters
  String get inputText => _inputText;
  bool get isConverting => _isConverting;
  set isConverting(bool value) {
    _isConverting = value;
    notifyListeners();
  }

  bool get isPlaying => _isPlaying;
  AudioFile? get currentAudioFile => _currentAudioFile;
  set currentAudioFile(AudioFile? audioFile) {
    _currentAudioFile = audioFile;
    notifyListeners();
  }

  List<AudioFile> get audioHistory => _audioHistory;
  String get selectedLanguage => _selectedLanguage;
  double get speechRate => _speechRate;
  double get pitch => _pitch;
  List<String> get availableLanguages => _availableLanguages;

  TextToSpeechViewModel() {
    _initializeViewModel();
    _audioPlayerService.playerStateStream.listen((state) {
      _isPlaying = state == PlayerState.playing;
      notifyListeners();
    });
  }

  Future<void> _initializeViewModel() async {
    try {
      _availableLanguages = await _ttsService.getAvailableLanguages();
      notifyListeners();
    } catch (e) {
      print('Erreur lors de l\'initialisation: $e');
    }
  }

  void updateInputText(String text) {
    _inputText = text;
    notifyListeners();
  }

  Future<void> convertTextToAudioWithFileName(String fileName) async {
    if (_inputText.trim().isEmpty) return;

    _isConverting = true;
    notifyListeners();

    try {
      final audioFile = await _ttsService.convertTextToAudioWithCustomName(_inputText, fileName);
      if (audioFile != null) {
        _currentAudioFile = audioFile;
        _audioHistory.insert(0, audioFile);
        notifyListeners();
      }
    } catch (e) {
      print('Erreur lors de la conversion: $e');
    } finally {
      _isConverting = false;
      notifyListeners();
    }
  }

  Future<void> convertTextToAudio() async {
    if (_inputText.trim().isEmpty) return;

    _isConverting = true;
    notifyListeners();

    try {
      final audioFile = await _ttsService.convertTextToAudioWithPicker(_inputText);
      if (audioFile != null) {
        _currentAudioFile = audioFile;
        _audioHistory.insert(0, audioFile);
        notifyListeners();
      }
    } catch (e) {
      print('Erreur lors de la conversion: $e');
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

  Future<void> speakText() async {
    if (_inputText.trim().isEmpty) return;
    await _ttsService.speak(_inputText);
  }

  Future<void> stopSpeaking() async {
    await _ttsService.stop();
  }

  Future<void> setLanguage(String language) async {
    _selectedLanguage = language;
    await _ttsService.setLanguage(language);
    notifyListeners();
  }

  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate;
    await _ttsService.setSpeechRate(rate);
    notifyListeners();
  }

  Future<void> setPitch(double pitch) async {
    _pitch = pitch;
    await _ttsService.setPitch(pitch);
    notifyListeners();
  }

  void clearHistory() {
    _audioHistory.clear();
    _currentAudioFile = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _audioPlayerService.dispose();
    super.dispose();
  }
}
