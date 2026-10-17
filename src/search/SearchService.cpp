#include "SearchService.h"
#include "DropImportWorker.h"

#include <QCoreApplication>
#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QDir>
#include <QUrl>
#include <QMetaObject>
#include <QSet>
#include <QVariant>
#include <QVariantMap>
#include <algorithm>

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
    const QString localDataRoot = QDir::cleanPath(
        appDir.filePath(QStringLiteral("Lubis")));
    const QString adjacentDataRoot = QDir::cleanPath(
        appDir.filePath(QStringLiteral("../Lubis")));

    // Prefer data beside the executable only when its Search QR directory exists.
    // This prevents an unrelated neighbouring Lubis folder from shadowing the
    // project's actual data when launching an executable from the repository root.
    const bool localSearchRootExists =
        QDir(QDir(localDataRoot).filePath(QStringLiteral("search QR"))).exists();
    const bool adjacentSearchRootExists =
        QDir(QDir(adjacentDataRoot).filePath(QStringLiteral("search QR"))).exists();

    const QString dataRoot = localSearchRootExists
        ? localDataRoot
        : (adjacentSearchRootExists
               ? adjacentDataRoot
               : (QDir(localDataRoot).exists() ? localDataRoot : adjacentDataRoot));

    // Search and the custom explorer share this single root.
    m_searchRoot = QDir(dataRoot).filePath(QStringLiteral("search QR"));
    QDir().mkpath(m_searchRoot);
    qInfo().noquote() << "Lubis search root:" << QDir::cleanPath(m_searchRoot);
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

}

SearchService::~SearchService()
{
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

QVariantMap SearchService::startNameSearch(const QString &query)
{
    m_activeSearchQuery = query.trimmed();
    m_activeSearchRoot = QFileInfo(m_searchRoot).canonicalFilePath();
    m_searchIterator.reset();
    m_pendingSearchResult.clear();
    m_hasPendingSearchResult = false;

    if (m_activeSearchQuery.isEmpty()
        || m_activeSearchRoot.isEmpty()
        || !QFileInfo(m_activeSearchRoot).isDir()) {
        QVariantMap response;
        response.insert(QStringLiteral("results"), QVariantList{});
        response.insert(QStringLiteral("hasMore"), false);
        return response;
    }

    // Keep the iterator between requests. Each call processes only one batch,
    // instead of collecting and sorting the entire tree for every keystroke.
    m_searchIterator = std::make_unique<QDirIterator>(
        m_activeSearchRoot,
        QDir::Files | QDir::NoDotAndDotDot,
        QDirIterator::Subdirectories);

    return readNextSearchPage();
}

QVariantMap SearchService::nextNameSearchPage()
{
    return readNextSearchPage();
}

QVariantMap SearchService::readNextSearchPage()
{
    constexpr int resultsPerPage = 20;
    QVariantList results;

    const auto nextMatchingResult = [this](QVariantMap &result) -> bool {
        if (!m_searchIterator)
            return false;

        while (m_searchIterator->hasNext()) {
            const QString path = m_searchIterator->next();
            const QFileInfo info(path);
            if (info.isSymLink() || info.isHidden() || !info.isFile())
                continue;

            const QString name = info.fileName();
            if (!name.contains(m_activeSearchQuery, Qt::CaseInsensitive))
                continue;

            result.insert(QStringLiteral("name"), name);
            result.insert(QStringLiteral("path"),
                          QDir::toNativeSeparators(info.absoluteFilePath()));
            result.insert(QStringLiteral("relativePath"),
                          QDir::toNativeSeparators(
                              QDir(m_activeSearchRoot).relativeFilePath(path)));
            return true;
        }
        return false;
    };

    if (m_hasPendingSearchResult) {
        results.append(m_pendingSearchResult);
        m_pendingSearchResult.clear();
        m_hasPendingSearchResult = false;
    }

    while (results.size() < resultsPerPage) {
        QVariantMap match;
        if (!nextMatchingResult(match))
            break;
        results.append(match);
    }

    // Read ahead by only one matching file so the UI knows whether Next is
    // available. That file is cached and becomes the first result of the next page.
    bool hasMore = false;
    if (results.size() == resultsPerPage) {
        QVariantMap nextMatch;
        if (nextMatchingResult(nextMatch)) {
            m_pendingSearchResult = nextMatch;
            m_hasPendingSearchResult = true;
            hasMore = true;
        }
    }

    // Keep a small, independently sorted batch. Global sorting would require
    // scanning the whole tree before the first 20 results could be displayed.
    std::sort(results.begin(), results.end(),
              [](const QVariant &left, const QVariant &right) {
        return QString::compare(left.toMap().value(QStringLiteral("name")).toString(),
                                right.toMap().value(QStringLiteral("name")).toString(),
                                Qt::CaseInsensitive) < 0;
    });

    if (!hasMore)
        m_searchIterator.reset();

    QVariantMap response;
    response.insert(QStringLiteral("results"), results);
    response.insert(QStringLiteral("hasMore"), hasMore);
    return response;
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

