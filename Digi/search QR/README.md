# Search QR

This directory is the local source area for Digi's Search tool.

## Search contract

- Search recursively through this directory and its subdirectories.
- Match the query against file names and supported text content.
- Treat matching as case-insensitive.
- Show results only from files inside this directory; do not search the rest of the computer.
- Skip cache data, hidden/system entries, and files that cannot be read safely.
- Do not modify, rename, move, or delete indexed files.
- Search must remain local; no content is uploaded or sent to an external service.

## Initial supported content

- File and folder names: all readable entries.
- Text content: `.txt`, `.md`, `.csv`, `.json`, `.xml`, `.html`, `.htm`, `.qml`, `.cpp`, `.h`, `.py`, and `.log`.
- Other formats can appear as filename results, but their internal content is not searched until a dedicated extractor is implemented.

## Implementation boundary

The QML Search page is presentation only. Filesystem traversal and content matching belong in a separate C++ service, not in QML. Search results should identify the matching file and a useful matching excerpt where text content is available.
