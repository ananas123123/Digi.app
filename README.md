# Word to PDF — repository-folder edition

This version always processes the folder named `repository` beside `main.py`. You do not need to drag a folder into the app or choose one in the interface.

## Folder layout

Keep the app files together and place your documents inside `repository`:

```text
file-converter/
├── main.py
├── requirements.txt
├── README.md
└── repository/
    ├── Essay.docx
    └── School/
        └── Notes.docx
```

After conversion, the structure becomes:

```text
repository/
├── Essay.pdf
└── School/
    └── Notes.pdf
```

The converter searches `repository` recursively, so subfolders are included.

## Requirements

- Python 3.10 or newer
- LibreOffice installed: https://www.libreoffice.org/download/download-libreoffice/

## Run on Windows

From the folder containing `main.py`:

```powershell
py -m pip install -r requirements.txt
py main.py
```

Put Word files into `repository`, click **Refresh folder**, then click **Convert to PDF**.

Supported extensions: `.doc`, `.docx`, `.docm`, `.dot`, `.dotx`, and `.dotm`.

## Replacement and safety

- Each PDF is created beside its source, preserving the folder layout and base filename.
- The source Word file is removed only after a non-empty PDF has been created and placed successfully.
- If the matching PDF already exists, that document is skipped and the Word file is retained.
- The app asks for confirmation before starting. Keep a backup of important files before batch conversion.
