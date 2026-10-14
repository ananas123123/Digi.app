# Digi Word-to-PDF

A Windows desktop utility that converts Word documents to PDFs while preserving the input folder structure.

## Build a standalone application

Requirements:
- Windows
- Python 3.10+
- Desktop Microsoft Word installed and activated
- Internet access during the first build to install PyInstaller and dependencies

1. Pull the latest `file-converter` branch.
2. Double-click `build_exe.bat`.
3. When the build finishes, open `dist\Digi Word to PDF\`.
4. Run `Digi Word to PDF.exe`.

Distribute or move the **entire** `Digi Word to PDF` folder, not only the EXE. The folder contains the executable's bundled runtime files.

## Where input files go

Put documents and any nested folders in:

```
dist/
└── Digi Word to PDF/
    ├── Digi Word to PDF.exe
    └── repository/
        ├── Essay.docx
        └── Chemistry/
            └── Topic 1/
                └── Notes.doc
```

The app always uses the `repository` folder next to the executable. It scans subfolders recursively.

## Output and folder structure

A document such as:

```
repository/Chemistry/Topic 1/Notes.docx
```

produces:

```
repository/Chemistry/Topic 1/Notes.pdf
```

Subfolders are preserved. The PDF is validated before Digi removes the Word source. If a PDF with the same name already exists, Digi skips that source and keeps the Word file. If conversion or source cleanup fails, the source is retained and the Activity log explains the failure.

## Important notes

- The executable is built in `--onedir` mode so its bundled components are kept alongside it. Keep the complete output folder together.
- Microsoft Word must be installed and activated on each computer that uses Word COM conversion. PyInstaller does not bundle Microsoft Word.
- LibreOffice can be used as a fallback only if it is separately installed and available on PATH.
- The build script creates the EXE on your computer; the GitHub branch contains the source and build script, not a prebuilt Windows binary.
