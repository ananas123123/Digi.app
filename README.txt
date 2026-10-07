DIGI SEARCH ENGINE 1.17.7.5

This is the Digi Search Engine with an integrated stylus-first Digi Notes workspace.

SEARCH
- No results are shown until you type a search.
- Search results appear as rounded cards with bold filenames.
- The directory text is intentionally subdued.
- Every result has an arrow. Expand it to reveal the directory and full path.
- The result cards resize with the window.
- ExamPro / PMT filtering is automatic from the folder path.
- Normal search keeps the existing indexed search path.
- Fuzzy search allows approximate matches.
- PDF / Word filtering, status, due dates, tags, sorting and recent searches remain available.

DIGI NOTES
- Pen tool.
- Eraser tool.
- Stylus barrel/right button acts as an eraser.
- Marker tool.
- Highlighter tool.
- Colour picker.
- Adjustable pen size.
- Zoom controls and Ctrl+wheel zoom.
- Two-finger pinch zoom on supported touch hardware.
- Finger touch does not draw.
- The page expands automatically when you write near an edge.
- Create notebooks.
- Create nested sub-page folders inside notebooks.
- Add, rename, delete and reorder pages.
- Insert images.
- Insert text.
- Each page is an individual PNG file under A Level Papers\Digi Notes, so it can be backed up independently.

FOLDER LAYOUT
A Level Papers/
  VERSION 1.17.7.5 — VERSION-FOLDER SELF-ORGANISATION BUG FIX
- If Digi Search Engine.exe is moved outside its current version folder and launched, Digi now creates the current version folder beside the EXE.
- The version folder contains Search Repository, Incoming, and Cache.
- Digi then moves and relaunches the EXE from that version folder.
- Normal launches from the correct version folder do not perform relocation work.
- The 3-second branded splash delay and all application functionality are retained.

Digi Search Engine/
  Biology/
  Chemistry/
  Psychology/
  Incoming/
  Digi Notes/   (created automatically)

STARTUP / BUILD PERFORMANCE 1.17.7.5
- The EXE is placed directly in its final version folder during build.
- Normal launches from that correct version folder perform no relocation work.
- If the EXE is moved elsewhere and launched, Digi creates the current version folder beside it, creates Search Repository, Incoming and Cache, then moves and relaunches the EXE there.
- Stale Sentence Transformers packaging was removed from the build; semantic search remains fully removed from the application.
- The 3-second branded splash delay is intentionally retained.

BUILDING THE EXE
1. Run build.bat.
2. The executable is:
   dist\Digi Search Engine.exe
3. The build automatically installs the resulting EXE into the final Digi SE version folder.
4. If the EXE is manually moved elsewhere, launching it will recreate the current version folder beside the EXE and self-organise it back into the correct structure.


PDF <-> WORD CONVERSION
-----------------------
PDF -> Word is intentionally IMAGE-BASED:
- Every PDF page is rendered as a PNG image.
- The PNGs are embedded directly into the DOCX.
- No OCR or text reflow is performed.
- PNG is lossless, so there is no JPEG-style quality loss.
- Word is instructed not to recompress the pictures.
- When a Digi-created page-image DOCX is converted back to PDF, Digi extracts
  those original PNG page images and rebuilds the PDF directly. It does not
  pass them through Word/LibreOffice, avoiding lossy recompression.


FOLDER BROWSER FILE MANAGEMENT (1.17.3.5)
- Right-click a folder in the Folder Browser to open the management menu.
- Create folders inside the selected folder.
- Create blank Word .docx, legacy Word .doc, and PDF files.
- Delete folders recursively after confirmation.
- Changes are reflected in the browser immediately and the search index is refreshed in the background.
- Legacy .doc creation requires Microsoft Word to be installed on Windows.


INSPECTION UPDATE 1.17.3.5
- Index scan database writes are batched to reduce UI-thread overhead.
- No user-facing feature was removed.


CONVERSION SOURCE RETENTION (1.17.3.5)
- PDF -> Word and Word -> PDF conversions ask whether the original file should be retained.
- Choosing No removes the original only after successful conversion.
- Failed conversions never remove the original.


1.17.3.5 BUG FIX
- Fixed selected-file controls for filesystem-first folder browsing when a file is not yet indexed.




INCOMING WORKFLOW (1.17.3.5)
Save a modified supported file into Incoming with the same filename and extension. Digi automatically routes it to the matching repository file and replaces the old version. Ambiguous destinations are presented for selection.


INCOMING ORIGIN MEMORY (1.17.3.5)
When a repository file is opened, Digi remembers its exact path for the current session.
A modified copy saved to Incoming with the same filename and extension is automatically
returned to that exact original path, preventing replacement of an identical file in another folder.


INCOMING SOURCE IDENTITY + GEEK CONSOLE (1.17.3.5)
Digi temporarily records the exact repository path, original filename and extension
when a repository file is opened. A modified copy saved into Incoming may use a
different temporary filename; Digi restores the original filename and directory
before replacing the original. More -> Incoming Geek Console shows the live source
association and session event log and can save it as a TXT file.


RESULT DISPLAY (1.17.3.5)
Search result filenames are shown without their file extensions. PDF filenames use a subtle light red tint and Word filenames use a subtle light blue tint.
