import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/luma_theme.dart';
import 'city_map_models.dart';
import 'city_plan_controller.dart';

class CityPlanInspector extends StatelessWidget {
  const CityPlanInspector({super.key, required this.plan});

  final CityPlanController plan;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final colors = context.luma;
    Widget heading(String label) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 10),
      child: Text(
        label,
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    Widget toggle(
      String key,
      String label,
      bool value,
      ValueChanged<bool> change,
    ) => CheckboxListTile(
      key: ValueKey(key),
      contentPadding: EdgeInsets.zero,
      dense: true,
      visualDensity: VisualDensity.compact,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(label, style: const TextStyle(fontSize: 12)),
      value: value,
      onChanged: (next) => change(next ?? false),
    );
    return ListenableBuilder(
      listenable: plan,
      builder: (context, _) {
        final road = plan.selectedRoad;
        final building = plan.selectedBuilding;
        final selectedName = plan.selectedId == null
            ? null
            : plan.stagedFeatureName(plan.selectedId!) ??
                  road?.name ??
                  building?.name;
        return Material(
          color: colors.surface,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading(t.mapMakerCityProperties),
                if (road == null && building == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      t.mapMakerCityNoSelection,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textMuted,
                        height: 1.6,
                      ),
                    ),
                  ),
                if (selectedName != null) ...[
                  _FeatureNameEditor(
                    key: ValueKey('city-feature-name-${plan.selectedId}'),
                    featureId: plan.selectedId!,
                    value: selectedName,
                    plan: plan,
                  ),
                  const SizedBox(height: 12),
                ],
                if (road != null) ...[
                  DropdownButtonFormField<CityRoadKind>(
                    key: ValueKey(
                      'city-road-class-${road.id}-${road.kind.name}',
                    ),
                    initialValue: road.kind,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: t.mapMakerCityRoadClass,
                      isDense: true,
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                      color: colors.textPrimary,
                    ),
                    items: [
                      for (final kind in CityRoadKind.values)
                        DropdownMenuItem(
                          value: kind,
                          child: Text(t.mapMakerCityRoadType(kind.name)),
                        ),
                    ],
                    onChanged: (kind) {
                      if (kind != null) plan.changeSelectedRoadKind(kind);
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t.mapMakerCityLength(
                      (road.length * kCityMetersPerUnit).toStringAsFixed(1),
                    ),
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                  SwitchListTile(
                    key: const ValueKey('city-feature-curved'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      t.mapMakerCityCurved,
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: road.curved,
                    onChanged: road.points.length >= 3
                        ? plan.changeSelectedRoadCurve
                        : null,
                  ),
                ],
                if (building != null) ...[
                  Text(
                    t.mapMakerCityBuildingType(building.kind.name),
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.mapMakerCityArea(
                      (building.size.width *
                              building.size.height *
                              kCityMetersPerUnit *
                              kCityMetersPerUnit)
                          .toStringAsFixed(1),
                    ),
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                  if (building.hasParcel) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          building.connected
                              ? Icons.link_rounded
                              : Icons.link_off_rounded,
                          size: 16,
                          color: building.connected
                              ? colors.success
                              : colors.warning,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            building.connected
                                ? t.mapMakerCityConnected
                                : t.mapMakerCityDisconnected,
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
                const Divider(height: 28),
                heading(t.mapMakerCityDigitizing),
                SwitchListTile(
                  key: const ValueKey('city-connect-housing'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    t.mapMakerCityAutoConnect,
                    style: const TextStyle(fontSize: 12),
                  ),
                  subtitle: Text(
                    t.mapMakerCityAutoConnectHint,
                    style: TextStyle(fontSize: 11, color: colors.textMuted),
                  ),
                  value: plan.connectHousing,
                  onChanged: plan.setConnectHousing,
                ),
                const Divider(height: 28),
                SwitchListTile(
                  key: const ValueKey('city-snap-enabled'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    t.mapMakerCitySnap,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  value: plan.snapEnabled,
                  onChanged: (value) => plan.setSnapping(enabled: value),
                ),
                toggle(
                  'city-snap-grid',
                  t.mapMakerCitySnapGrid,
                  plan.snapGrid,
                  (value) => plan.setSnapping(grid: value),
                ),
                toggle(
                  'city-snap-vertices',
                  t.mapMakerCitySnapVertices,
                  plan.snapVertices,
                  (value) => plan.setSnapping(vertices: value),
                ),
                toggle(
                  'city-snap-segments',
                  t.mapMakerCitySnapSegments,
                  plan.snapSegments,
                  (value) => plan.setSnapping(segments: value),
                ),
                toggle(
                  'city-snap-intersections',
                  t.mapMakerCitySnapIntersections,
                  plan.snapIntersections,
                  (value) => plan.setSnapping(intersections: value),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.mapMakerCitySnapTolerance,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      '${plan.snapTolerancePixels.round()} px',
                      style: TextStyle(fontSize: 11, color: colors.textMuted),
                    ),
                  ],
                ),
                Slider(
                  key: const ValueKey('city-snap-tolerance'),
                  value: plan.snapTolerancePixels.clamp(4, 24),
                  min: 4,
                  max: 24,
                  divisions: 20,
                  onChanged: (value) {
                    plan.snapTolerancePixels = value;
                    plan.updateHover(plan.hoverSnap?.position);
                  },
                ),
                Text(
                  t.mapMakerCityLocalPlan,
                  style: TextStyle(fontSize: 10, color: colors.textMuted),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FeatureNameEditor extends StatefulWidget {
  const _FeatureNameEditor({
    super.key,
    required this.featureId,
    required this.value,
    required this.plan,
  });

  final String featureId;
  final String value;
  final CityPlanController plan;

  @override
  State<_FeatureNameEditor> createState() => _FeatureNameEditorState();
}

class _FeatureNameEditorState extends State<_FeatureNameEditor> {
  late final TextEditingController _text;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.value);
    _focus.addListener(_onFocus);
  }

  void _onFocus() {
    if (!_focus.hasFocus) widget.plan.commitFeatureNames();
  }

  @override
  void didUpdateWidget(covariant _FeatureNameEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && _text.text != widget.value) {
      _text.text = widget.value;
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _text,
    focusNode: _focus,
    decoration: InputDecoration(
      labelText: L.of(context).mapMakerCityName,
      isDense: true,
    ),
    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
    onChanged: (value) => widget.plan.stageFeatureName(widget.featureId, value),
    onSubmitted: (_) => widget.plan.commitFeatureNames(),
    onTapOutside: (_) => _focus.unfocus(),
  );
}
