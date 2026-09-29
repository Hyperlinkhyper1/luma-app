import '../../../../../l10n/app_localizations.dart';
import '../text_library_repository.dart';

/// The whole library as the scene reads it: subjects in hall order, each with
/// its books.
Map<String, Object?> libraryMessage(LibrarySnapshot snapshot) => {
  'type': 'library',
  'subjects': [
    for (final subject in snapshot.subjects)
      {
        'id': subject.id,
        'name': subject.name,
        'color': subject.color.index,
        'books': [
          for (final text in snapshot.textsOf(subject.id))
            {
              'id': text.id,
              'title': text.title,
              'spine': text.spine,
              'cover': text.cover.index,
              'slot': text.slot,
              'body': text.body.encode(),
              'updated': text.updatedAt.millisecondsSinceEpoch,
            },
        ],
      },
  ],
};

/// Every string the scene shows, localised here so the page needs no
/// translations of its own. Placeholders are handed through as `{0}`, `{1}`
/// for the page to fill in.
Map<String, String> sceneStrings(L t) => {
  'loading': t.textLibraryMcLoading,
  'newCase': t.textLibraryMcNewCase,
  'newCaseTitle': t.textLibraryMcNewCaseTitle,
  'nameHint': t.textLibrarySubjectNameHint,
  'build': t.textLibraryMcBuild,
  'cancel': t.textLibraryCancel,
  'back': t.textLibraryBack,
  'emptySlot': t.textLibraryMcEmptySlot,
  'page': t.textLibraryMcPage('{0}', '{1}'),
  'shelfPage': t.textLibraryMcShelfPage('{0}', '{1}'),
  'books': t.textLibraryMcBooks('{0}'),
  'done': t.textLibraryMcDone,
  'sign': t.textLibraryMcSign,
  'signTitle': t.textLibraryMcSignTitle,
  'spine': t.textLibrarySpineLabel,
  'spineHint': t.textLibrarySpineHint,
  'cover': t.textLibraryCover,
  'signAndShelve': t.textLibraryMcSignAndShelve,
  'chooseSlot': t.textLibraryMcChooseSlot,
  'burn': t.textLibraryMcBurn,
  'burnConfirm': t.textLibraryMcBurnConfirm,
  'bold': t.textLibraryBold,
  'italic': t.textLibraryItalic,
  'underline': t.textLibraryUnderline,
  'strike': t.textLibraryStrike,
  'ink': t.textLibraryInk,
  'clear': t.textLibraryClearFormatting,
  'vanilla': t.textLibraryMcVanilla('{0}'),
  'builtIn': t.textLibraryMcBuiltIn,
  'download': t.textLibraryMcDownload,
  'downloadNote': t.textLibraryMcDownloadNote,
  'downloadFailed': t.textLibraryMcDownloadFailed,
  'quality': t.textLibraryMcQuality,
  'qualityLow': t.textLibraryMcQualityLow,
  'qualityHigh': t.textLibraryMcQualityHigh,
  'settings': t.textLibraryMcSettings,
  'emptyHall': t.textLibraryMcEmptyHall,
  'rename': t.textLibraryRename,
  'untitled': t.textLibraryMcUntitled,
  'writeHint': t.textLibraryMcWriteHint,
  'moveHint': t.textLibraryMcMoveHint,
  'saveFailed': t.textLibraryMcSaveFailed,
  'undo': t.textLibraryMcUndo,
  'redo': t.textLibraryMcRedo,
  'time': t.textLibraryMcTime,
  'timeCycle': t.textLibraryMcTimeCycle,
  'timeClock': t.textLibraryMcTimeClock,
  'timeDay': t.textLibraryMcTimeDay,
  'timeNight': t.textLibraryMcTimeNight,
  'walkHint': t.textLibraryMcWalkHint,
};
