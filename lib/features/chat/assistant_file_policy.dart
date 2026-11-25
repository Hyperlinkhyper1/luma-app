/// Mirrored by server/lib/assistant_files.dart, which uses the account's plan.
bool assistantFilesAllowed(String? planId) =>
    planId == 'orbit' || planId == 'nova';

const assistantFilePlanMessage =
    'File uploads and artifact generation require Orbit or Nova.';

const assistantArtifactTypes = <String, String>{
  'txt': 'Plain text',
  'md': 'Markdown',
  'pdf': 'PDF document',
  'html': 'HTML page',
  'csv': 'CSV spreadsheet',
  'json': 'JSON data',
  'svg': 'SVG image',
  'docx': 'Word document',
  'pptx': 'PowerPoint deck',
  'xlsx': 'Excel workbook',
};

/// Built live, a section at a time, by the office tools rather than in one
/// create_artifact call.
const assistantOfficeArtifactTypes = {'docx', 'pptx', 'xlsx'};
