import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import 'cloud_files_controller.dart';
import 'cloud_files_scope.dart';

/// The Cloud Files plugin: upload files to your sync server and get them back
/// on any device. Everything is end-to-end encrypted before upload, and every
/// byte counts against your account's storage quota.
class CloudFilesPage extends StatefulWidget {
  const CloudFilesPage({super.key});

  @override
  State<CloudFilesPage> createState() => _CloudFilesPageState();
}

class _CloudFilesPageState extends State<CloudFilesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) CloudFilesScope.of(context).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = CloudFilesScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: !controller.signedIn
                  ? const _SignedOut()
                  : _Body(controller: controller),
            ),
          ),
        );
      },
    );
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          LumaIconBadge(
              icon: Icons.cloud_off_rounded, color: luma.accent, size: 64),
          const SizedBox(height: 20),
          Text('Cloud Files needs sync',
              style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SizedBox(
            width: 420,
            child: Text(
              'Sign in to your sync server under Settings → Sync & account, '
              'then come back here to upload files. Files are encrypted on '
              'this device before upload — the server can never read them.',
              textAlign: TextAlign.center,
              style: TextStyle(color: luma.textMuted, fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller});
  final CloudFilesController controller;

  Future<void> _pickAndUpload(BuildContext context) async {
    final result = await FilePicker.pickFiles(allowMultiple: true);
    if (result == null) return;
    for (final f in result.files) {
      final path = f.path;
      if (path == null) continue;
      try {
        await controller.upload(path, f.name);
      } catch (e) {
        if (context.mounted) _snack(context, e.toString());
        break; // stop the batch on the first failure
      }
    }
  }

  Future<void> _download(BuildContext context, CloudFile file) async {
    final path = await FilePicker.saveFile(
      dialogTitle: 'Save ${file.name}',
      fileName: file.name,
    );
    if (path == null) return;
    try {
      await controller.download(file, path);
      if (context.mounted) _snack(context, 'Saved ${file.name}');
    } catch (e) {
      if (context.mounted) _snack(context, e.toString());
    }
  }

  Future<void> _confirmDelete(BuildContext context, CloudFile file) async {
    final luma = context.luma;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: luma.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: luma.border),
        ),
        title: Text('Delete file?', style: TextStyle(color: luma.textPrimary)),
        content: Text(
          'Remove "${file.name}" from the server? This frees up '
          '${CloudFilesController.formatBytes(file.size)} and cannot be undone.',
          style: TextStyle(color: luma.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: luma.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: Colors.red.shade400)),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await controller.delete(file);
    } catch (e) {
      if (context.mounted) _snack(context, e.toString());
    }
  }

  static void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---- Header: storage + upload -------------------------------------
        LumaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  LumaIconBadge(
                      icon: Icons.cloud_rounded, color: luma.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cloud Files',
                            style: TextStyle(
                                color: luma.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                        Text(
                          'Encrypted files on your server, on every device.',
                          style: TextStyle(
                              color: luma.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  LumaPrimaryButton(
                    label: 'Upload',
                    icon: Icons.upload_rounded,
                    onTap: controller.busy
                        ? null
                        : () => _pickAndUpload(context),
                  ),
                ],
              ),
              Divider(color: luma.border, height: 32),
              _StorageBar(controller: controller),
              if (controller.busy) ...[
                const SizedBox(height: 16),
                _TransferRow(controller: controller),
              ],
              if (controller.error != null) ...[
                const SizedBox(height: 12),
                Text(controller.error!,
                    style:
                        TextStyle(color: Colors.red.shade400, fontSize: 12)),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ---- File list -----------------------------------------------------
        if (controller.loading && controller.files.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Center(
              child: CircularProgressIndicator(color: luma.accent),
            ),
          )
        else if (controller.files.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: LumaEmptyState(
              icon: Icons.folder_open_rounded,
              title: 'No files yet',
              subtitle: 'Upload a file to keep it safe and synced.',
            ),
          )
        else
          LumaCard(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
            child: Column(
              children: [
                for (var i = 0; i < controller.files.length; i++) ...[
                  if (i > 0) Divider(color: luma.border, height: 1),
                  _FileRow(
                    file: controller.files[i],
                    enabled: !controller.busy,
                    onDownload: () => _download(context, controller.files[i]),
                    onDelete: () => _confirmDelete(context, controller.files[i]),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _StorageBar extends StatelessWidget {
  const _StorageBar({required this.controller});
  final CloudFilesController controller;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final used = controller.usedBytes;
    final quota = controller.quotaBytes;
    final fraction = quota == 0 ? 0.0 : (used / quota).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Storage used',
                style: TextStyle(
                    color: luma.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(
              '${CloudFilesController.formatBytes(used)} of '
              '${CloudFilesController.formatBytes(quota)}',
              style: TextStyle(color: luma.textMuted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor: luma.surfaceHover,
            valueColor: AlwaysStoppedAnimation(
                fraction > 0.9 ? Colors.red.shade400 : luma.accent),
          ),
        ),
        const SizedBox(height: 4),
        Text('${CloudFilesController.formatBytes(controller.freeBytes)} free',
            style: TextStyle(color: luma.textMuted, fontSize: 11)),
      ],
    );
  }
}

class _TransferRow extends StatelessWidget {
  const _TransferRow({required this.controller});
  final CloudFilesController controller;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final verb = controller.transfer == CloudTransferKind.uploading
        ? 'Uploading'
        : 'Downloading';
    final pct = (controller.progress * 100).clamp(0, 100).toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
                controller.transfer == CloudTransferKind.uploading
                    ? Icons.upload_rounded
                    : Icons.download_rounded,
                size: 16,
                color: luma.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text('$verb ${controller.transferName ?? ''}… $pct%',
                  style: TextStyle(color: luma.textSecondary, fontSize: 12),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: controller.progress == 0 ? null : controller.progress,
            minHeight: 6,
            backgroundColor: luma.surfaceHover,
            valueColor: AlwaysStoppedAnimation(luma.accent),
          ),
        ),
      ],
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.file,
    required this.enabled,
    required this.onDownload,
    required this.onDelete,
  });

  final CloudFile file;
  final bool enabled;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(_iconFor(file.name), color: luma.accent, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '${CloudFilesController.formatBytes(file.size)} · '
                  '${DateFormat('d MMM yyyy, HH:mm').format(file.uploadedAt)}',
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Download',
            onPressed: enabled ? onDownload : null,
            icon: Icon(Icons.download_rounded, color: luma.textSecondary),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: enabled ? onDelete : null,
            icon: Icon(Icons.delete_outline_rounded, color: luma.textSecondary),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'webp':
      case 'bmp':
        return Icons.image_rounded;
      case 'mp4':
      case 'mov':
      case 'mkv':
      case 'avi':
      case 'webm':
        return Icons.movie_rounded;
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'm4a':
      case 'ogg':
        return Icons.audiotrack_rounded;
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return Icons.folder_zip_rounded;
      case 'doc':
      case 'docx':
      case 'txt':
      case 'md':
      case 'rtf':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Icons.table_chart_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }
}
