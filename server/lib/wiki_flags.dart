import 'dart:io';

/// The wiki builder's flag files, and how this server drops them.
///
/// The wiki's builder container watches for these files at the root of the
/// wiki checkout and runs a build when one appears. luma-sync mounts that
/// checkout read-only, apart from the two folders the website editor writes
/// (see docker-compose.yml). The rest of the folder is the wiki stack
/// itself: its compose file, Dockerfile and build script, which the host
/// runs. A container that could write there could plant a compose file and
/// take over the host. So in that setup a flag goes onto the data volume
/// instead, and deploy-watcher.sh on the host moves it into the checkout.
enum WikiFlag {
  /// Publish: commit the sources, `astro build`, rsync into site/.
  build('.build-request', 'wiki-build.request'),

  /// Re-export the Fishing Waters fish library from GitHub, then build.
  fishRefresh('.fish-refresh-request', 'wiki-fish-refresh.request');

  const WikiFlag(this.wikiName, this.relayName);

  /// The file the builder watches, at the root of the wiki checkout.
  final String wikiName;

  /// The file on the data volume that deploy-watcher.sh moves to [wikiName].
  final String relayName;
}

/// Drops [flag] for the wiki builder: straight into [wikiDir] when that can
/// be written (a local run, or an older compose file that mounts the wiki
/// writable), otherwise onto [dataDir] for the host's deploy watcher to move
/// into place. False when neither could be written.
bool requestWikiFlag(
  WikiFlag flag, {
  required String wikiDir,
  required String dataDir,
  DateTime? now,
}) {
  final stamp = (now ?? DateTime.now()).toIso8601String();
  for (final path in [
    '$wikiDir/${flag.wikiName}',
    '$dataDir/${flag.relayName}',
  ]) {
    try {
      File(path).writeAsStringSync(stamp);
      return true;
    } on FileSystemException {
      continue;
    }
  }
  return false;
}

/// Whether [flag] is still waiting on the data volume for the host's deploy
/// watcher, which deletes it there once it has moved it into the checkout.
bool wikiFlagQueued(WikiFlag flag, {required String dataDir}) =>
    File('$dataDir/${flag.relayName}').existsSync();

/// Whether [flag] is waiting anywhere: still queued for the watcher, or in
/// the checkout where the builder deletes it when the build starts.
bool wikiFlagPending(
  WikiFlag flag, {
  required String wikiDir,
  required String dataDir,
}) =>
    File('$wikiDir/${flag.wikiName}').existsSync() ||
    wikiFlagQueued(flag, dataDir: dataDir);
