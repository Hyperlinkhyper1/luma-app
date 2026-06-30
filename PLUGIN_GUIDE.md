# Luma Plugin Guide

This guide explains how to create and register a new plugin for the Luma desktop app.

## Overview

Plugins in Luma are discovered via a remote registry but their implementation lives within the app's codebase. This allows the plugin catalog to be updated dynamically while keeping the core app logic clean.

## Step 1: Define Metadata

First, you need to add your plugin to the catalog.

### 1. Update the Registry
Add a new entry to `.\plugins\registry.json`. Use a unique `id`, a descriptive `name`, and an icon name from Material Icons.

```json
{
  "id": "your-plugin-id",
  "name": "Your Plugin Name",
  "description": "A short description of what your plugin does.",
  "icon": "extension",
  "category": "Utility",
  "version": "1.0.0"
}
```

### 2. Create the Manifest
Create a new directory `.\plugins\your-plugin-id\` and add a `manifest.json` file inside it. This should match the fields in the registry.

```json
{
  "id": "your-plugin-id",
  "name": "Your Plugin Name",
  "version": "1.0.0",
  "description": "A short description of what your plugin does.",
  "icon": "extension",
  "category": "Utility"
}
```

## Step 2: Implement the UI

All plugin code lives in `.\lib\features\plugins\installed\`.

1. Create a directory: `.\lib\features\plugins\installed\your_plugin_id\` (use underscores for the folder name if your ID has hyphens).
2. Create your main page widget, e.g., `your_plugin_id_page.dart`.

Example minimal implementation:

```dart
import 'package:flutter/material.dart';
import '../../../../app/widgets.dart';

class YourPluginPage extends StatelessWidget {
  const YourPluginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Hello from your new plugin!'),
    );
  }
}
```

## Step 3: Register the Plugin

Finally, you must tell the app how to display your plugin when it is opened.

1. Open `.\lib\app\app_shell.dart`.
2. Import your new page at the top of the file.
3. Find the `_pluginPageFor` static method and add your plugin ID to the switch statement:

```dart
static Widget _pluginPageFor(String pluginId) => switch (pluginId) {
      'qr-code-generator' => const QrCodeGeneratorPage(),
      'file-tree' => const FileTreePage(),
      'your-plugin-id' => const YourPluginPage(), // Add this line
      _ => const LumaEmptyState(
          icon: Icons.extension_off_rounded,
          title: 'Plugin unavailable',
        ),
    };
```

## Testing

1. Run the app: `flutter run -d windows`.
2. Navigate to the **Plugins** section.
3. You should see your plugin in the marketplace.
4. Click **Download** (this simulates an install by recording it in the local SQLite database).
5. Once "installed", your plugin icon will appear in the left navigation rail.
6. Click the icon to open your plugin page.
