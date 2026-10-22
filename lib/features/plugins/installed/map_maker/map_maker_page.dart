import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import 'city_map_editor_view.dart';
import 'map_maker_hub_view.dart';
import 'map_maker_models.dart';
import 'map_maker_saves_view.dart';
import 'map_maker_store.dart';
import 'transit_map_editor_view.dart';

enum _MapMakerView { hub, saves, editor }

class MapMakerPage extends StatefulWidget {
  const MapMakerPage({super.key, this.store});

  final MapMakerStore? store;

  @override
  State<MapMakerPage> createState() => _MapMakerPageState();
}

class _MapMakerPageState extends State<MapMakerPage> {
  _MapMakerView _currentView = _MapMakerView.hub;
  MapMakerSave? _activeSave;
  MapMakerStore get _store => widget.store ?? MapMakerStore.instance;

  Future<void> _newTransitMap() async {
    final title = 'Transit Map ${_store.saves.length + 1}';
    final save = await _store.createTransit(title: title);
    if (!mounted) return;
    setState(() {
      _activeSave = save;
      _currentView = _MapMakerView.editor;
    });
  }

  Future<void> _newCityMap() async {
    final title = L
        .of(context)
        .mapMakerCityDefaultTitle(
          _store.saves.where((save) => save.kind == MapMakerKind.city).length +
              1,
        );
    final save = await _store.createCity(title: title);
    if (!mounted) return;
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
        onNewCityMap: _newCityMap,
        store: _store,
      ),
      _MapMakerView.saves => MapMakerSavesView(
        onBack: _backToHub,
        onOpenSave: _openSave,
        onNewTransitMap: _newTransitMap,
        onNewCityMap: _newCityMap,
        store: _store,
      ),
      _MapMakerView.editor =>
        _activeSave != null
            ? _activeSave!.kind == MapMakerKind.city
                  ? CityMapEditorView(
                      save: _activeSave!,
                      onBack: _backFromEditor,
                      store: _store,
                    )
                  : TransitMapEditorView(
                      save: _activeSave!,
                      onBack: _backFromEditor,
                    )
            : MapMakerHubView(
                onOpenSaves: _openSaves,
                onNewTransitMap: _newTransitMap,
                onNewCityMap: _newCityMap,
                store: _store,
              ),
    };
  }
}
