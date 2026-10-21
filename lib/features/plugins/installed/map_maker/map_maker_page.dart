import 'package:flutter/material.dart';

import 'map_maker_hub_view.dart';
import 'map_maker_models.dart';
import 'map_maker_saves_view.dart';
import 'map_maker_store.dart';
import 'transit_map_editor_view.dart';

enum _MapMakerView { hub, saves, editor }

class MapMakerPage extends StatefulWidget {
  const MapMakerPage({super.key});

  @override
  State<MapMakerPage> createState() => _MapMakerPageState();
}

class _MapMakerPageState extends State<MapMakerPage> {
  _MapMakerView _currentView = _MapMakerView.hub;
  MapMakerSave? _activeSave;

  Future<void> _newTransitMap() async {
    final title = 'Transit Map ${MapMakerStore.instance.saves.length + 1}';
    final save = await MapMakerStore.instance.createTransit(title: title);
    setState(() {
      _activeSave = save;
      _currentView = _MapMakerView.editor;
    });
  }

  void _openSave(MapMakerSave save) {
    setState(() {
      _activeSave = save;
      _currentView = _MapMakerView.editor;
    });
  }

  void _openSaves() {
    setState(() {
      _currentView = _MapMakerView.saves;
    });
  }

  void _backToHub() {
    setState(() {
      _currentView = _MapMakerView.hub;
      _activeSave = null;
    });
  }

  void _backFromEditor() {
    setState(() {
      // Return to saves screen if we have saves, or hub
      _currentView = _MapMakerView.saves;
      _activeSave = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return switch (_currentView) {
      _MapMakerView.hub => MapMakerHubView(
          onOpenSaves: _openSaves,
          onNewTransitMap: _newTransitMap,
        ),
      _MapMakerView.saves => MapMakerSavesView(
          onBack: _backToHub,
          onOpenSave: _openSave,
          onNewTransitMap: _newTransitMap,
        ),
      _MapMakerView.editor => _activeSave != null
          ? TransitMapEditorView(
              save: _activeSave!,
              onBack: _backFromEditor,
            )
          : MapMakerHubView(
              onOpenSaves: _openSaves,
              onNewTransitMap: _newTransitMap,
            ),
    };
  }
}
