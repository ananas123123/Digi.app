# Word to PDF

A small Windows-friendly Python desktop utility for converting Word documents throughout a folder tree.

## What it does

- Drag and drop a folder into the window, or select one with **Choose folder**.
- Recursively finds Word documents in that folder and all subfolders.
- Converts supported `.doc`, `.docx`, `.docm`, `.dot`, `.dotx`, and `.dotm` files to PDF.
- Saves each PDF in the same directory with the same base filename.
- After a successful conversion, removes the original Word file, so the PDF takes its place.
- Preserves the existing folder structure.
- Does not overwrite an existing PDF; it skips that source and keeps the Word file.
- Shows progress and a conversion log. Asks for confirmation before replacing source files.

## Requirements

- Python 3.10 or newer
- [LibreOffice](https://www.libreoffice.org/download/download-libreoffice/) installed
- Python dependency in `requirements.txt`

## Run on Windows

1. Install Python and LibreOffice.
2. Open a terminal in this folder.
3. Install the Python dependency:

   ```powershell
   py -m pip install -r requirements.txt
   ```

4. Start the app:

   ```powershell
   py main.py
   ```

The app looks for LibreOffice's `soffice.exe` on PATH and in the usual Program Files locations.

## Safety behaviour

A source Word file is removed only after LibreOffice produces a non-empty PDF and that PDF has been staged beside the source. If a PDF with the same name already exists, the converter leaves both files untouched and reports the skip. Keep a backup of important files before batch conversion.
