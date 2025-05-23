import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_text_to_speech/cloud_text_to_speech.dart';
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
  List<VoiceGoogle> _availableVoices = [];
  VoiceGoogle? _selectedVoice;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  // Getters
  String get inputText => _inputText;
  bool get isConverting => _isConverting;
  bool get isPlaying => _isPlaying;
  AudioFile? get currentAudioFile => _currentAudioFile;
  List<AudioFile> get audioHistory => _audioHistory;
  List<VoiceGoogle> get availableVoices => _availableVoices;
  VoiceGoogle? get selectedVoice => _selectedVoice;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;

  TextToSpeechViewModel() {
    _initializeViewModel();
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

  Future<void> _initializeViewModel() async {
    try {
      print('=== DEBUT INITIALISATION VIEWMODEL ===');
      _availableVoices = await _ttsService.getAvailableVoices();
      print('Voix récupérées: ${_availableVoices.length}');
      if (_availableVoices.isNotEmpty) {
        _selectedVoice = _availableVoices.first;
        print('Voix sélectionnée: ${_selectedVoice!.name}');
      }
      print('=== VIEWMODEL INITIALISE ===');
      notifyListeners();
    } catch (e) {
      print('Erreur lors de l\'initialisation du ViewModel: $e');
      // Ne pas bloquer l'app, continuer sans voix
      notifyListeners();
    }
  }

  void updateInputText(String text) {
    _inputText = text;
    notifyListeners();
  }

  Future<void> convertTextToMP3WithFileName(String fileName) async {
    if (_inputText.trim().isEmpty) return;

    _isConverting = true;
    notifyListeners();

    try {
      AudioFile? audioFile;
      
      if (_selectedVoice != null) {
        audioFile = await _ttsService.convertTextToMP3WithVoice(_inputText, fileName, _selectedVoice!);
      } else {
        audioFile = await _ttsService.convertTextToMP3WithCustomName(_inputText, fileName);
      }
      
      if (audioFile != null) {
        _currentAudioFile = audioFile;
        _audioHistory.insert(0, audioFile);
        notifyListeners();
      }
    } catch (e) {
      print('Erreur lors de la conversion: $e');
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

  void setSelectedVoice(VoiceGoogle voice) {
    _selectedVoice = voice;
    notifyListeners();
  }

  void clearHistory() {
    _audioHistory.clear();
    _currentAudioFile = null;
    notifyListeners();
  }

  String formatDuration(Duration duration) {
    String minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    String seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _audioPlayerService.dispose();
    super.dispose();
  }
}