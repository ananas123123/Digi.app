#include "SearchService.h"
#include "DropImportWorker.h"
#include "SearchWorker.h"

#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include <QFile>
#include <QTextStream>
#include <QDir>
#include <QDesktopServices>
#include <QUrl>
#include <QMetaObject>
#include <QSet>
#include <QVariant>

namespace {
QString normalizedPath(QString path)
{
    path = QDir::cleanPath(QDir::fromNativeSeparators(path));
#ifdef Q_OS_WIN
    path = path.toCaseFolded();
#endif
    return path;
}

bool pathIsInsideOrEqual(const QString &candidate, const QString &root)
{
    const QString normalizedCandidate = normalizedPath(candidate);
    const QString normalizedRoot = normalizedPath(root);
    return normalizedCandidate == normalizedRoot
        || normalizedCandidate.startsWith(normalizedRoot + QLatin1Char('/'));
}
}

SearchService::SearchService(QObject *parent)
    : QObject(parent)
{
    const QDir appDir(QCoreApplication::applicationDirPath());
    const QString adjacentDataRoot = QDir::cleanPath(appDir.filePath(QStringLiteral("../Lubis")));
    const QString dataRoot = QDir(adjacentDataRoot).exists()
        ? adjacentDataRoot
        : QDir::cleanPath(appDir.filePath(QStringLiteral("Lubis")));

    // Search and the custom explorer share this single root.
    m_searchRoot = QDir(dataRoot).filePath(QStringLiteral("search QR"));
    QDir().mkpath(m_searchRoot);
    QDir().mkpath(QDir(dataRoot).filePath(QStringLiteral("cache")));

    m_importWorker = new DropImportWorker;
    m_importWorker->moveToThread(&m_importThread);
    connect(&m_importThread, &QThread::finished,
            m_importWorker, &QObject::deleteLater);

    connect(m_importWorker, &DropImportWorker::progressChanged, this,
            [this](const QString &currentItem, qint64 copiedBytes, qint64 totalBytes,
                   int completedFiles, int totalFiles) {
        const QString status = currentItem.isEmpty()
            ? QStringLiteral("Preparing files…")
            : currentItem == QStringLiteral("Preparing files…")
                || currentItem == QStringLiteral("Finishing…")
                ? currentItem
                : QStringLiteral("Importing ") + currentItem + QStringLiteral("…");

        int percent = 0;
        if (totalBytes > 0) {
            const double fraction = static_cast<double>(copiedBytes)
                / static_cast<double>(totalBytes);
            percent = qBound(0, static_cast<int>(fraction * 100.0), 99);
        } else if (totalFiles > 0) {
            percent = qBound(0, completedFiles * 100 / totalFiles, 99);
        }

        bool changed = false;
        if (m_importStatus != status) {
            m_importStatus = status;
            changed = true;
        }
        if (m_importProgressPercent != percent) {
            m_importProgressPercent = percent;
            changed = true;
        }
        if (changed)
            emit importProgressChanged();
    }, Qt::QueuedConnection);

    connect(m_importWorker, &DropImportWorker::copyCompleted, this,
            [this](int importedCount, int failedCount, const QString &message) {
        m_importInProgress = false;
        m_importProgressPercent = 100;
        m_importStatus = message;
        emit importStateChanged();
        emit importProgressChanged();
        emit dropImportFinished(importedCount > 0 && failedCount == 0, message);
    }, Qt::QueuedConnection);

    m_importThread.start();

    m_searchWorker = new SearchWorker;
    m_searchWorker->moveToThread(&m_searchThread);
    connect(&m_searchThread, &QThread::finished,
            m_searchWorker, &QObject::deleteLater);
    connect(m_searchWorker, &SearchWorker::searchCompleted, this,
            [this](quint64 requestId, const QVariantList &results) {
        if (requestId != m_searchRequestId)
            return;

        m_searchResults = results;
        emit searchResultsChanged();

        if (m_searching) {
            m_searching = false;
            emit searchStateChanged();
        }
    }, Qt::QueuedConnection);
    m_searchThread.start();
}

SearchService::~SearchService()
{
    if (m_searchWorker)
        m_searchWorker->setLatestRequestId(++m_searchRequestId);
    m_searchThread.quit();
    m_searchThread.wait();

    m_importThread.quit();
    m_importThread.wait();
}

QString SearchService::searchRoot() const
{
    return QDir::cleanPath(m_searchRoot);
}

bool SearchService::importInProgress() const
{
    return m_importInProgress;
}

int SearchService::importProgressPercent() const
{
    return m_importProgressPercent;
}

QString SearchService::importStatus() const
{
    return m_importStatus;
}

bool SearchService::importDroppedUrls(const QVariantList &urls,
                                      const QString &destinationDirectory)
{
    if (m_importInProgress || urls.isEmpty())
        return false;

    const QString canonicalRoot = QFileInfo(m_searchRoot).canonicalFilePath();
    if (canonicalRoot.isEmpty())
        return false;

    const QString requestedDestination = destinationDirectory.trimmed().isEmpty()
        ? canonicalRoot : destinationDirectory;
    const QString canonicalDestination = QFileInfo(requestedDestination).canonicalFilePath();
    if (canonicalDestination.isEmpty()
        || !QFileInfo(canonicalDestination).isDir()
        || !pathIsInsideOrEqual(canonicalDestination, canonicalRoot)) {
        return false;
    }

    QStringList sourcePaths;
    QSet<QString> uniquePaths;
    for (const QVariant &urlValue : urls) {
        const QUrl url(urlValue.toString());
        if (!url.isLocalFile())
            continue;

        // Keep source filesystem checks in the worker thread. Resolving slow
        // removable/network paths here could stall the UI before progress appears.
        const QString sourcePath = QDir::cleanPath(
            QDir::fromNativeSeparators(url.toLocalFile()));
        if (sourcePath.isEmpty())
            continue;

        const QString key = normalizedPath(sourcePath);
        if (uniquePaths.contains(key))
            continue;

        uniquePaths.insert(key);
        sourcePaths.append(sourcePath);
    }

    if (sourcePaths.isEmpty())
        return false;

    m_importInProgress = true;
    m_importProgressPercent = 0;
    m_importStatus = QStringLiteral("Preparing files…");
    emit importStateChanged();
    emit importProgressChanged();

    const bool queued = QMetaObject::invokeMethod(
        m_importWorker,
        "copyItems",
        Qt::QueuedConnection,
        Q_ARG(QStringList, sourcePaths),
        Q_ARG(QString, canonicalDestination));
    if (!queued) {
        m_importInProgress = false;
        m_importProgressPercent = 0;
        m_importStatus = QStringLiteral("Could not start the import.");
        emit importStateChanged();
        emit importProgressChanged();
        return false;
    }
    return true;
}

QVariantList SearchService::searchResults() const
{
    return m_searchResults;
}

bool SearchService::searching() const
{
    return m_searching;
}

void SearchService::requestSearch(const QString &query, bool caseSensitive, bool includeHidden)
{
    const quint64 requestId = ++m_searchRequestId;
    m_searchWorker->setLatestRequestId(requestId);

    const QString needle = query.trimmed();
    if (!m_searchResults.isEmpty()) {
        m_searchResults.clear();
        emit searchResultsChanged();
    }

    if (needle.isEmpty()) {
        if (m_searching) {
            m_searching = false;
            emit searchStateChanged();
        }
        return;
    }

    if (!m_searching) {
        m_searching = true;
        emit searchStateChanged();
    }

    const bool queued = QMetaObject::invokeMethod(
        m_searchWorker,
        "performSearch",
        Qt::QueuedConnection,
        Q_ARG(quint64, requestId),
        Q_ARG(QString, m_searchRoot),
        Q_ARG(QString, needle),
        Q_ARG(bool, caseSensitive),
        Q_ARG(bool, includeHidden));

    if (!queued) {
        m_searchResults.clear();
        emit searchResultsChanged();
        if (m_searching) {
            m_searching = false;
            emit searchStateChanged();
        }
    }
}

QVariantList SearchService::listFolderContents(const QString &path) const
{
    QVariantList entries;
    const QString rootPath = QFileInfo(m_searchRoot).canonicalFilePath();
    const QString folderPath = QFileInfo(path).canonicalFilePath();
    if (rootPath.isEmpty() || folderPath.isEmpty())
        return entries;

    const QString relativePath = QDir(rootPath).relativeFilePath(folderPath);
    if (relativePath == QStringLiteral("..")
        || relativePath.startsWith(QStringLiteral("../"))
        || QFileInfo(relativePath).isAbsolute()
        || !QFileInfo(folderPath).isDir()) {
        return entries;
    }

    QDir folder(folderPath);
    const QFileInfoList children = folder.entryInfoList(
        QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Readable,
        QDir::DirsFirst | QDir::Name | QDir::IgnoreCase);
    for (const QFileInfo &info : children) {
        if (info.isHidden())
            continue;
        QVariantMap entry;
        entry.insert(QStringLiteral("name"), info.fileName());
        entry.insert(QStringLiteral("path"), QDir::toNativeSeparators(info.absoluteFilePath()));
        entry.insert(QStringLiteral("isFolder"), info.isDir());
        entries.append(entry);
    }
    return entries;
}

QString SearchService::previewFile(const QString &path) const
{
    const QString rootPath = QDir(m_searchRoot).canonicalPath();
    const QString filePath = QFileInfo(path).canonicalFilePath();
    if (rootPath.isEmpty() || filePath.isEmpty())
        return QStringLiteral("Preview unavailable.");

    const QString relativePath = QDir(rootPath).relativeFilePath(filePath);
    if (relativePath == QStringLiteral("..")
        || relativePath.startsWith(QStringLiteral("../"))
        || QFileInfo(relativePath).isAbsolute()) {
        return QStringLiteral("Preview unavailable.");
    }

    QFileInfo info(filePath);
    if (!info.isFile() || !info.isReadable())
        return QStringLiteral("Preview unavailable.");

    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return QStringLiteral("Preview unavailable.");

    QTextStream stream(&file);
    stream.setEncoding(QStringConverter::Utf8);
    QString contents = stream.readAll();
    constexpr qsizetype maxPreviewCharacters = 12000;
    if (contents.size() > maxPreviewCharacters)
        contents = contents.left(maxPreviewCharacters) + QStringLiteral("\\n\\n… Preview truncated.");
    return contents.isEmpty() ? QStringLiteral("This file is empty.") : contents;
}

bool SearchService::openFile(const QString &path) const
{
    const QString rootPath = QDir(m_searchRoot).canonicalPath();
    const QString filePath = QFileInfo(path).canonicalFilePath();
    if (rootPath.isEmpty() || filePath.isEmpty())
        return false;

    const QString relativePath = QDir(rootPath).relativeFilePath(filePath);
    if (relativePath == QStringLiteral("..")
        || relativePath.startsWith(QStringLiteral("../"))
        || QFileInfo(relativePath).isAbsolute()) {
        return false;
    }

    const QFileInfo info(filePath);
    if (!info.isFile() || !info.isReadable())
        return false;

    return QDesktopServices::openUrl(QUrl::fromLocalFile(filePath));
}
