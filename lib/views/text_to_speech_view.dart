import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_text_to_speech/cloud_text_to_speech.dart';
import '../viewmodels/text_to_speech_viewmodel.dart';
import '../models/audio_file.dart';

class TextToSpeechView extends StatelessWidget {
  const TextToSpeechView({super.key});

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
      body: Consumer<TextToSpeechViewModel>(
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

  Widget _buildInputSection(BuildContext context, TextToSpeechViewModel viewModel) {
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

  Widget _buildVoiceSelector(BuildContext context, TextToSpeechViewModel viewModel) {
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
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: viewModel.availableVoices.map((voice) => DropdownMenuItem(
                value: voice,
                child: Text('${voice.name} (${voice.locale.code})'),
              )).toList(),
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

  Widget _buildControlButtons(BuildContext context, TextToSpeechViewModel viewModel) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: viewModel.inputText.trim().isEmpty ? null : viewModel.speakText,
              icon: Icon(Icons.volume_up),
              label: Text('Écouter'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: viewModel.inputText.trim().isEmpty
                  ? null
                  : () => _showFileNameDialog(context, viewModel),
              icon: viewModel.isConverting
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.audiotrack),
              label: Text(viewModel.isConverting ? 'Génération du MP3...' : 'Créer fichier MP3'),
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

  Widget _buildCurrentAudioSection(BuildContext context, TextToSpeechViewModel viewModel) {
    if (viewModel.currentAudioFile == null) {
      return Container();
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fichier MP3 actuel:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text(
              'Taille: ${viewModel.currentAudioFile!.sizeFormatted}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection(BuildContext context, TextToSpeechViewModel viewModel) {
    return Expanded(
      child: Card(
        elevation: 4,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Fichiers MP3 créés:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  if (viewModel.audioHistory.isNotEmpty)
                    TextButton(
                      onPressed: viewModel.clearHistory,
                      child: Text('Effacer tout'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: viewModel.audioHistory.isEmpty
                  ? Center(
                      child: Text(
                        'Aucun fichier MP3 créé',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: viewModel.audioHistory.length,
                      itemBuilder: (context, index) {
                        final audioFile = viewModel.audioHistory[index];
                        return _buildAudioHistoryItem(context, viewModel, audioFile);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioHistoryItem(BuildContext context, TextToSpeechViewModel viewModel, AudioFile audioFile) {
    return ListTile(
      leading: Icon(Icons.audiotrack, color: Colors.blue),
      title: Text(
        audioFile.text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${audioFile.createdAt.day}/${audioFile.createdAt.month}/${audioFile.createdAt.year} '
            '${audioFile.createdAt.hour}:${audioFile.createdAt.minute.toString().padLeft(2, '0')}',
          ),
          Text(
            'Taille: ${audioFile.sizeFormatted}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
      trailing: IconButton(
        icon: Icon(Icons.play_arrow, color: Colors.green),
        onPressed: () => viewModel.playAudioFile(audioFile),
      ),
    );
  }

  Future<void> _showFileNameDialog(BuildContext context, TextToSpeechViewModel viewModel) async {
    final TextEditingController fileNameController = TextEditingController();
    
    final fileName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
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
      builder: (context) => AlertDialog(
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
