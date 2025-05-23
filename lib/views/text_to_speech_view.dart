import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:provider/provider.dart';
import '../viewmodels/text_to_speech_viewmodel.dart';
import '../models/audio_file.dart';

class TextToSpeechView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Text to Speech'),
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
                _buildControlButtons(context, viewModel),
                SizedBox(height: 20),
                _buildCurrentAudioSection(context, viewModel),
                SizedBox(height: 20),
                _buildHistorySection(context, viewModel),
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
              'Texte à convertir:',
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
              onPressed: viewModel.isConverting || viewModel.inputText.trim().isEmpty
                  ? null
                  : viewModel.convertTextToAudio,
              icon: viewModel.isConverting
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.save),
              label: Text(viewModel.isConverting ? 'Conversion...' : 'Sauvegarder'),
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
              'Fichier audio actuel:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              viewModel.currentAudioFile!.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: viewModel.playCurrentAudio,
                  icon: Icon(Icons.play_arrow),
                  iconSize: 32,
                  color: Colors.green,
                ),
                IconButton(
                  onPressed: viewModel.pauseAudio,
                  icon: Icon(Icons.pause),
                  iconSize: 32,
                  color: Colors.orange,
                ),
                IconButton(
                  onPressed: viewModel.stopAudio,
                  icon: Icon(Icons.stop),
                  iconSize: 32,
                  color: Colors.red,
                ),
              ],
            ),
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
                    'Historique des audios:',
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
                        'Aucun fichier audio sauvegardé',
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
      subtitle: Text(
        '${audioFile.createdAt.day}/${audioFile.createdAt.month}/${audioFile.createdAt.year} '
        '${audioFile.createdAt.hour}:${audioFile.createdAt.minute.toString().padLeft(2, '0')}',
      ),
      trailing: IconButton(
        icon: Icon(Icons.play_arrow, color: Colors.green),
        onPressed: () => viewModel.playAudioFile(audioFile),
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Consumer<TextToSpeechViewModel>(
        builder: (context, viewModel, child) {
          return AlertDialog(
            title: Text('Paramètres'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Vitesse de parole:'),
                Slider(
                  value: viewModel.speechRate,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  label: viewModel.speechRate.toStringAsFixed(1),
                  onChanged: viewModel.setSpeechRate,
                ),
                SizedBox(height: 16),
                Text('Tonalité:'),
                Slider(
                  value: viewModel.pitch,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  label: viewModel.pitch.toStringAsFixed(1),
                  onChanged: viewModel.setPitch,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Fermer'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showFileNameDialog(BuildContext context, TextToSpeechViewModel viewModel) async {
    final TextEditingController fileNameController = TextEditingController();
    
    // Afficher le dialog pour saisir le nom du fichier
    final fileName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nom du fichier'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Entrez le nom du fichier audio:'),
            SizedBox(height: 16),
            TextField(
              controller: fileNameController,
              decoration: InputDecoration(
                hintText: 'mon_audio',
                border: OutlineInputBorder(),
                suffixText: '.wav',
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
            child: Text('Continuer'),
          ),
        ],
      ),
    );

    if (fileName != null && fileName.trim().isNotEmpty) {
      // Lancer la conversion avec le nom de fichier personnalisé
      try {
        await viewModel.convertTextToAudioWithFileName(fileName);
        
        if (viewModel.currentAudioFile != null) {
          // Afficher un message de succès
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fichier audio sauvegardé avec succès !'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          // Afficher un message d'annulation
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sauvegarde annulée'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        // Afficher un message d'erreur
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la conversion'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}