# Word to PDF — lossless PNG page edition

This desktop utility reads Word documents from the `repository` folder, including nested subfolders. It renders each Word page to a lossless PNG image at 300 DPI, then builds a PDF containing one image per PDF page. After verification, the PDF replaces the original Word file.

## Requirements

- Windows
- Desktop Microsoft Word installed and activated (used for accurate Word layout and pagination)
- Python 3.10 or newer

Install Python dependencies:

```powershell
py -m pip install -r requirements.txt
```

## Folder layout

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

Run:

```powershell
py main.py
```

Click **Refresh folder**, then **Convert to image-based PDF**.

## Rendering pipeline

1. Microsoft Word opens each document read-only and exports a temporary layout file so Word itself determines pagination and layout.
2. PyMuPDF renders each page to an RGB PNG at 300 DPI. PNG encoding is lossless.
3. ReportLab embeds each PNG as a full-page image in the final PDF.
4. The final PDF is reopened and checked for matching page count and embedded page images.
5. Only after validation is the PDF moved into place and the Word source removed.

The temporary layout file is not the delivered output. The delivered PDF contains rasterized page images, not selectable text. Because pages are images, final PDFs can be large; 300 DPI is the current quality setting.

## Safety

- Existing PDFs are never overwritten; their source Word documents are skipped and retained.
- Source documents are opened read-only.
- A Word source is removed only after the final image-based PDF passes validation.
- Failed conversions leave the original Word document in place.
- Back up important files before batch conversion.
