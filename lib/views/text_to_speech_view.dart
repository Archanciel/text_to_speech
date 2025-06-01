import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../viewmodels/text_to_speech_vm.dart';

class TextToSpeechView extends StatefulWidget {
  const TextToSpeechView({super.key});

  @override
  State<TextToSpeechView> createState() => _TextToSpeechViewState();
}

class _TextToSpeechViewState extends State<TextToSpeechView> {
  // Add FocusNode for the name field
  final FocusNode _nameFocusNode = FocusNode();
  // Add TextEditingController for the text field
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Auto-focus and select the name field when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameFocusNode.dispose();
    _textController.dispose(); // Dispose the controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Text to MP3'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(context),
          ),
        ],
      ),
      body: Consumer<TextToSpeechVM>(
        builder: (context, textToSpeechVMlistenTrue, child) {
          return Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildInputSection(context, textToSpeechVMlistenTrue),
                SizedBox(height: 20),
                _buildControlButtons(context, textToSpeechVMlistenTrue),
                SizedBox(height: 20),
                _buildCurrentAudioSection(context, textToSpeechVMlistenTrue),
                // SizedBox(height: 20),
                // _buildHistorySection(context, viewModel),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputSection(BuildContext context, TextToSpeechVM viewModel) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with title and clear button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Texte à convertir en MP3:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                // Clear button
                IconButton(
                  onPressed: viewModel.inputText.trim().isEmpty 
                    ? null 
                    : () => _clearTextField(viewModel),
                  icon: Icon(Icons.clear),
                  tooltip: 'Effacer le texte',
                  iconSize: 20,
                  constraints: BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  style: IconButton.styleFrom(
                    foregroundColor: viewModel.inputText.trim().isEmpty 
                      ? Colors.grey 
                      : Colors.red,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            TextField(
              controller: _textController,
              maxLines: 4,
              focusNode: _nameFocusNode,
              decoration: InputDecoration(
                hintText: 'Entrez votre texte ici...',
                border: OutlineInputBorder(),
                // Alternative: Add clear button as suffix icon in the text field
              ),
              onChanged: (text) {
                viewModel.updateInputText(text);
                // Keep the controller in sync
                if (_textController.text != text) {
                  _textController.text = text;
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // Method to clear the text field
  void _clearTextField(TextToSpeechVM viewModel) {
    _textController.clear();
    viewModel.updateInputText('');
    
    // Show a brief feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Texte effacé'),
        duration: Duration(seconds: 1),
        backgroundColor: Colors.grey[600],
      ),
    );
  }

  Widget _buildControlButtons(BuildContext context, TextToSpeechVM viewModel) {
    // Check if either TTS is speaking OR audio file is playing
    bool isAnythingPlaying = viewModel.isPlaying || viewModel.isSpeaking;
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed:
                  viewModel.inputText.trim().isEmpty
                      ? null
                      : viewModel.speakText,
              icon: Icon(Icons.volume_up),
              label: Text('Écouter'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed:
                  viewModel.inputText.trim().isEmpty
                      ? null
                      : () => _showFileNameDialog(context, viewModel),
              icon:
                  viewModel.isConverting
                      ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : Icon(Icons.audiotrack),
              label: Text(
                viewModel.isConverting
                    ? 'Génération du MP3...'
                    : 'Créer fichier MP3',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              // Enable when either TTS is speaking OR audio file is playing
              onPressed: isAnythingPlaying ? () => _stopAllAudio(viewModel) : null,
              icon: Icon(Icons.stop),
              label: Text('Arrêter la lecture'),
              style: ElevatedButton.styleFrom(
                // Dynamic color based on any playing state
                backgroundColor: isAnythingPlaying ? Colors.red : Colors.grey,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Method to stop all audio (both TTS and audio file playback)
  void _stopAllAudio(TextToSpeechVM viewModel) {
    // Stop TTS speaking
    viewModel.stopSpeaking();
  }

  Widget _buildCurrentAudioSection(
    BuildContext context,
    TextToSpeechVM viewModel,
  ) {
    if (viewModel.currentAudioFile == null) {
      return Container();
    }

    TextStyle mp3FileTextStyle = TextStyle(
      color: Colors.green[700],
      fontSize: 14,
      fontWeight: FontWeight.bold,
    );

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Fichier MP3 créé:',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  viewModel.currentAudioFile!.filePath,
                  style: mp3FileTextStyle,
                ),
                SizedBox(height: 6),
                Text(
                  'Taille: ${viewModel.currentAudioFile!.sizeFormatted}',
                  style: mp3FileTextStyle,
                ),
                SizedBox(height: 6),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFileNameDialog(
    BuildContext context,
    TextToSpeechVM viewModel,
  ) async {
    final TextEditingController fileNameController = TextEditingController();

    final fileName = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Nom du fichier MP3'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Entrez le nom du fichier MP3:'),
                SizedBox(height: 16),
                TextField(
                  controller: fileNameController,
                  decoration: InputDecoration(
                    hintText: 'mon_audio',
                    border: OutlineInputBorder(),
                    suffixText: '.mp3',
                  ),
                  autofocus: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = fileNameController.text.trim();
                  if (name.isNotEmpty) {
                    Navigator.of(context).pop(name);
                  }
                },
                child: Text('Créer MP3'),
              ),
            ],
          ),
    );

    if (fileName != null && fileName.trim().isNotEmpty) {
      try {
        await viewModel.convertTextToMP3WithFileName(fileName);

        if (viewModel.currentAudioFile != null) {
          if (!context.mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fichier MP3 créé avec succès !'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          if (!context.mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Création annulée'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (!context.mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Configuration'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Version Text-to-Speech: $kApplicationVersion\n\nConfiguration de l\'API Google Cloud Text-to-Speech'),
                SizedBox(height: 11),
                Text(
                  'Pour utiliser cette application, vous devez:\n'
                  '1. Créer un projet Google Cloud\n'
                  '2. Activer l\'API Text-to-Speech\n'
                  '3. Créer une clé API\n'
                  '4. Configurer la clé dans TextToSpeechService',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Fermer'),
              ),
            ],
          ),
    );
  }
}