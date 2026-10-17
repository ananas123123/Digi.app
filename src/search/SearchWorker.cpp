#include "SearchWorker.h"

#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QPdfDocument>
#include <QPdfSelection>
#include <QSet>
#include <QVariantMap>

namespace {
constexpr int maxResults = 200;
constexpr int maxFilesToInspect = 25000;
constexpr qint64 maxTextFileBytes = 2 * 1024 * 1024;
constexpr qint64 maxTotalTextBytes = 64 * 1024 * 1024;

const QSet<QString> searchableTextExtensions {
    QStringLiteral("txt"), QStringLiteral("md"), QStringLiteral("markdown"),
    QStringLiteral("csv"), QStringLiteral("tsv"), QStringLiteral("json"),
    QStringLiteral("xml"), QStringLiteral("html"), QStringLiteral("htm"),
    QStringLiteral("qml"), QStringLiteral("cpp"), QStringLiteral("c"),
    QStringLiteral("h"), QStringLiteral("hpp"), QStringLiteral("py"),
    QStringLiteral("js"), QStringLiteral("ts"), QStringLiteral("css"),
    QStringLiteral("ini"), QStringLiteral("log"), QStringLiteral("yaml"),
    QStringLiteral("yml"), QStringLiteral("toml"), QStringLiteral("rtf"),
    QStringLiteral("sql"), QStringLiteral("sh"), QStringLiteral("bat"),
    QStringLiteral("ps1"), QStringLiteral("cmake")
};

QString contentExcerpt(const QString &content, qsizetype position, qsizetype needleLength)
{
    const qsizetype start = qMax<qsizetype>(0, position - 55);
    const qsizetype excerptLimit = qMin<qsizetype>(
        300, qMax<qsizetype>(180, needleLength + 80));
    const qsizetype length = qMin<qsizetype>(excerptLimit, content.size() - start);
    QString excerpt = content.mid(start, length).simplified();
    if (start > 0)
        excerpt.prepend(QStringLiteral("…"));
    if (start + length < content.size())
        excerpt.append(QStringLiteral("…"));
    return excerpt;
}

bool findPdfContentMatch(const QFileInfo &info,
                         const QString &needle,
                         Qt::CaseSensitivity sensitivity,
                         qint64 &contentBytesRead,
                         QString &excerpt,
                         quint64 requestId,
                         const std::atomic<quint64> &latestRequestId)
{
    constexpr qint64 maxPdfFileBytes = 100 * 1024 * 1024;
    constexpr int maxPagesPerPdf = 1000;
    if (info.size() <= 0 || info.size() > maxPdfFileBytes
        || contentBytesRead >= maxTotalTextBytes) {
        return false;
    }

    QPdfDocument document;
    if (document.load(info.absoluteFilePath()) != QPdfDocument::Error::None)
        return false;

    const int pageCount = qMin(document.pageCount(), maxPagesPerPdf);
    for (int page = 0; page < pageCount; ++page) {
        if (latestRequestId.load(std::memory_order_relaxed) != requestId)
            return false;

        const QString pageText = document.getAllText(page).text();
        contentBytesRead += pageText.toUtf8().size();
        const qsizetype matchPosition = pageText.indexOf(needle, sensitivity);
        if (matchPosition >= 0) {
            excerpt = contentExcerpt(pageText, matchPosition, needle.size());
            return true;
        }

        if (contentBytesRead >= maxTotalTextBytes)
            break;
    }

    return false;
}
}

SearchWorker::SearchWorker(QObject *parent)
    : QObject(parent)
{
}

void SearchWorker::setLatestRequestId(quint64 requestId)
{
    m_latestRequestId.store(requestId, std::memory_order_relaxed);
}

void SearchWorker::performSearch(quint64 requestId,
                                 const QString &rootPath,
                                 const QString &query,
                                 bool caseSensitive,
                                 bool includeHidden)
{
    QVariantList results;
    const QString needle = query.trimmed();
    const QDir root(rootPath);
    if (needle.isEmpty() || !root.exists()
        || m_latestRequestId.load(std::memory_order_relaxed) != requestId) {
        emit searchCompleted(requestId, results);
        return;
    }

    QDir::Filters filters = QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot;
    if (includeHidden)
        filters |= QDir::Hidden | QDir::System;

    const Qt::CaseSensitivity sensitivity =
        caseSensitive ? Qt::CaseSensitive : Qt::CaseInsensitive;
    QDirIterator iterator(root.absolutePath(), filters, QDirIterator::Subdirectories);

    int inspectedFiles = 0;
    qint64 contentBytesRead = 0;
    while (iterator.hasNext() && results.size() < maxResults) {
        if (m_latestRequestId.load(std::memory_order_relaxed) != requestId)
            return;

        const QString path = iterator.next();
        const QFileInfo info(path);
        if ((!info.isDir() && !info.isFile()) || info.isSymLink()
            || (!includeHidden && info.isHidden()))
            continue;

        if (++inspectedFiles > maxFilesToInspect)
            break;

        const QString name = info.fileName();
        const bool isFolder = info.isDir();
        const bool nameMatches = name.contains(needle, sensitivity);
        QString excerpt;
        QString matchType;

        if (nameMatches) {
            matchType = isFolder
                ? QStringLiteral("folder") : QStringLiteral("filename");
        } else {
            // Folder names are searchable, but their descendants are examined
            // independently by QDirIterator; never try to read a directory as a file.
            if (isFolder)
                continue;

            const QString suffix = info.suffix().toLower();
            if (suffix == QStringLiteral("pdf")) {
                if (!findPdfContentMatch(info, needle, sensitivity, contentBytesRead,
                                         excerpt, requestId, m_latestRequestId)) {
                    continue;
                }
                matchType = QStringLiteral("content");
            } else {
                if (!searchableTextExtensions.contains(suffix)
                    || info.size() <= 0
                    || info.size() > maxTextFileBytes
                    || contentBytesRead + info.size() > maxTotalTextBytes) {
                    continue;
                }

                QFile file(path);
                if (!file.open(QIODevice::ReadOnly))
                    continue;

                const QByteArray bytes = file.read(maxTextFileBytes);
                contentBytesRead += bytes.size();
                if (bytes.isEmpty() && file.error() != QFile::NoError)
                    continue;

                const QString content = QString::fromUtf8(bytes);
                const qsizetype matchPosition = content.indexOf(needle, sensitivity);
                if (matchPosition < 0)
                    continue;

                matchType = QStringLiteral("content");
                excerpt = contentExcerpt(content, matchPosition, needle.size());
            }
        }

        QVariantMap result;
        result.insert(QStringLiteral("name"), name);
        result.insert(QStringLiteral("path"), QDir::toNativeSeparators(info.absoluteFilePath()));
        result.insert(QStringLiteral("relativePath"),
                      QDir::toNativeSeparators(root.relativeFilePath(path)));
        result.insert(QStringLiteral("matchType"), matchType);
        result.insert(QStringLiteral("excerpt"), excerpt);
        result.insert(QStringLiteral("isFolder"), isFolder);
        results.append(result);
    }

    if (m_latestRequestId.load(std::memory_order_relaxed) == requestId)
        emit searchCompleted(requestId, results);
}
