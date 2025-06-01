import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_text_to_speech/cloud_text_to_speech.dart';
import '../viewmodels/text_to_speech_vm.dart';

class TextToSpeechView extends StatefulWidget {
  const TextToSpeechView({super.key});

  @override
  State<TextToSpeechView> createState() => _TextToSpeechViewState();
}

class _TextToSpeechViewState extends State<TextToSpeechView> {
  // Add FocusNode for the name field
  final FocusNode _nameFocusNode = FocusNode();

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
        builder: (context, viewModel, child) {
          return Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildInputSection(context, viewModel),
                SizedBox(height: 20),
                _buildVoiceSelector(context, viewModel),
                SizedBox(height: 20),
                _buildControlButtons(context, viewModel),
                SizedBox(height: 20),
                _buildCurrentAudioSection(context, viewModel),
                // SizedBox(height: 20),
                // _buildHistorySection(context, viewModel),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputSection(
    BuildContext context,
    TextToSpeechVM viewModel,
  ) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Texte à convertir en MP3:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            TextField(
              maxLines: 4,
                 focusNode: _nameFocusNode, // Add focus node
             decoration: InputDecoration(
                hintText: 'Entrez votre texte ici...',
                border: OutlineInputBorder(),
              ),
              onChanged: viewModel.updateInputText,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceSelector(
    BuildContext context,
    TextToSpeechVM viewModel,
  ) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Voix sélectionnée:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            DropdownButtonFormField<VoiceGoogle>(
              value: viewModel.selectedVoice,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items:
                  viewModel.availableVoices
                      .map(
                        (voice) => DropdownMenuItem(
                          value: voice,
                          child: Text('${voice.name} (${voice.locale.code})'),
                        ),
                      )
                      .toList(),
              onChanged: (voice) {
                if (voice != null) {
                  viewModel.setSelectedVoice(voice);
                }
              },
              hint: Text('Sélectionnez une voix'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons(
    BuildContext context,
    TextToSpeechVM viewModel,
  ) {
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
        ElevatedButton.icon(
          onPressed: viewModel.stopSpeaking,
          icon: Icon(Icons.stop),
          label: Text('Arrêter la lecture'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentAudioSection(
    BuildContext context,
    TextToSpeechVM viewModel,
  ) {
    if (viewModel.currentAudioFile == null) {
      return Container();
    }

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
                  'Fichier MP3 actuel:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  viewModel.currentAudioFile!.filePath,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                SizedBox(height: 6),
                Text(
                  'Taille: ${viewModel.currentAudioFile!.sizeFormatted}',
                  style: TextStyle(color: Colors.grey[600]),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fichier MP3 créé avec succès !'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Création annulée'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
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
                Text('Configuration de l\'API Google Cloud Text-to-Speech'),
                SizedBox(height: 16),
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
