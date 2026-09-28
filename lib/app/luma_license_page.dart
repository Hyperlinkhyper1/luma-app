import 'package:flutter/material.dart';

/// Opens the app's license registry in a layout that keeps the detail pane
/// below its toolbar on desktop.
void showLumaLicensePage({
  required BuildContext context,
  required String applicationName,
  required String? applicationVersion,
}) {
  final navigator = Navigator.of(context);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  navigator.push<void>(
    MaterialPageRoute<void>(
      builder: (_) => themes.wrap(
        _LumaLicensePage(
          applicationName: applicationName,
          applicationVersion: applicationVersion,
        ),
      ),
    ),
  );
}

class _LumaLicensePage extends StatefulWidget {
  const _LumaLicensePage({
    required this.applicationName,
    required this.applicationVersion,
  });

  final String applicationName;
  final String? applicationVersion;

  @override
  State<_LumaLicensePage> createState() => _LumaLicensePageState();
}

class _LumaLicensePageState extends State<_LumaLicensePage> {
  late final Future<List<_LicensePackage>> _packages = _loadPackages();
  String? _selectedPackage;

  Future<List<_LicensePackage>> _loadPackages() async {
    final packages = <String, List<_LicenseEntry>>{};
    final packageOrder = <String>[];

    await for (final license in LicenseRegistry.licenses) {
      final paragraphs = await license.paragraphs.toList();
      for (final packageName in license.packages) {
        if (!packages.containsKey(packageName)) {
          packages[packageName] = [];
          packageOrder.add(packageName);
        }
        packages[packageName]!.add(_LicenseEntry(paragraphs));
      }
    }

    if (packageOrder.isNotEmpty) {
      final firstPackage = packageOrder.removeAt(0);
      packageOrder.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      packageOrder.insert(0, firstPackage);
    }

    return [
      for (final name in packageOrder)
        _LicensePackage(name: name, entries: packages[name]!),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final applicationVersion = widget.applicationVersion;
    return Scaffold(
      appBar: AppBar(title: Text(localizations.licensesPageTitle)),
      body: FutureBuilder<List<_LicensePackage>>(
        future: _packages,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          final packages = snapshot.data ?? const <_LicensePackage>[];
          if (packages.isEmpty) return const SizedBox.shrink();
          final selectedName = _selectedPackage ?? packages.first.name;
          final selected = packages.firstWhere(
            (package) => package.name == selectedName,
            orElse: () => packages.first,
          );

          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 720) {
                return _packageList(
                  context,
                  packages,
                  selectedName,
                  onTap: (package) => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => _LicenseDetailPage(package: package),
                    ),
                  ),
                );
              }

              return Row(
                children: [
                  SizedBox(
                    width: 300,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 20,
                          ),
                          child: Column(
                            children: [
                              Text(
                                widget.applicationName,
                                style: Theme.of(context).textTheme.headlineSmall,
                                textAlign: TextAlign.center,
                              ),
                              if (applicationVersion != null)
                                Text(
                                  applicationVersion,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              const SizedBox(height: 20),
                              Text(
                                'Powered by Flutter',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: _packageList(
                            context,
                            packages,
                            selectedName,
                            onTap: (package) => setState(
                              () => _selectedPackage = package.name,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: _LicenseDetails(package: selected)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _packageList(
    BuildContext context,
    List<_LicensePackage> packages,
    String selectedName, {
    required ValueChanged<_LicensePackage> onTap,
  }) {
    final localizations = MaterialLocalizations.of(context);
    return ListView.builder(
      itemCount: packages.length,
      itemBuilder: (context, index) {
        final package = packages[index];
        return ListTile(
          title: Text(package.name),
          subtitle: Text(
            localizations.licensesPackageDetailText(package.entries.length),
          ),
          selected: package.name == selectedName,
          onTap: () => onTap(package),
        );
      },
    );
  }
}

class _LicenseDetailPage extends StatelessWidget {
  const _LicenseDetailPage({required this.package});

  final _LicensePackage package;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(package.name)),
      body: _LicenseDetails(package: package),
    );
  }
}

class _LicenseDetails extends StatelessWidget {
  const _LicenseDetails({required this.package});

  final _LicensePackage package;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(package.name, style: Theme.of(context).textTheme.titleLarge),
        Text(
          MaterialLocalizations.of(context)
              .licensesPackageDetailText(package.entries.length),
        ),
        for (final entry in package.entries) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Divider(),
          ),
          for (final paragraph in entry.paragraphs)
            Padding(
              padding: EdgeInsetsDirectional.only(
                top: paragraph.indent == LicenseParagraph.centeredIndent
                    ? 16
                    : 8,
                start: paragraph.indent == LicenseParagraph.centeredIndent
                    ? 0
                    : 16 * paragraph.indent,
              ),
              child: Text(
                paragraph.text,
                style: paragraph.indent == LicenseParagraph.centeredIndent
                    ? const TextStyle(fontWeight: FontWeight.bold)
                    : null,
                textAlign: paragraph.indent == LicenseParagraph.centeredIndent
                    ? TextAlign.center
                    : null,
              ),
            ),
        ],
      ],
    );
  }
}

class _LicensePackage {
  const _LicensePackage({required this.name, required this.entries});

  final String name;
  final List<_LicenseEntry> entries;
}

class _LicenseEntry {
  const _LicenseEntry(this.paragraphs);

  final List<LicenseParagraph> paragraphs;
}
