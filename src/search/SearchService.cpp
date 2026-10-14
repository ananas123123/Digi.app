#include "SearchService.h"

#include <QCoreApplication>
#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QFile>
#include <QTextStream>
#include <QDir>
#include <QDesktopServices>
#include <QUrl>

namespace {
constexpr int maxResults = 200;
}

SearchService::SearchService(QObject *parent)
    : QObject(parent)
{
    const QDir appDir(QCoreApplication::applicationDirPath());
    const QString adjacentDataRoot = QDir::cleanPath(appDir.filePath(QStringLiteral("../Digi")));
    const QString dataRoot = QDir(adjacentDataRoot).exists()
        ? adjacentDataRoot
        : appDir.filePath(QStringLiteral("Digi"));

    m_searchRoot = QDir(dataRoot).filePath(QStringLiteral("search QR"));
    QDir().mkpath(m_searchRoot);
    QDir().mkpath(QDir(dataRoot).filePath(QStringLiteral("cache")));
}

QString SearchService::searchRoot() const
{
    return QDir::cleanPath(m_searchRoot);
}

QVariantList SearchService::search(const QString &query, bool folders) const
{
    QVariantList results;
    const QString needle = query.trimmed();
    if (needle.isEmpty())
        return results;

    const QDir root(m_searchRoot);
    if (!root.exists())
        return results;

    const QDir::Filters entryFilters = (folders ? QDir::Dirs : QDir::Files)
        | QDir::NoDotAndDotDot;
    QDirIterator iterator(root.absolutePath(),
                          entryFilters,
                          QDirIterator::Subdirectories);

    while (iterator.hasNext() && results.size() < maxResults) {
        const QString path = iterator.next();
        const QFileInfo info(path);
        if (info.isHidden() || (folders && !info.isDir()) || (!folders && !info.isFile()))
            continue;

        const QString name = info.fileName();
        if (!name.contains(needle, Qt::CaseInsensitive))
            continue;

        QVariantMap result;
        result.insert(QStringLiteral("name"), name);
        result.insert(QStringLiteral("path"), QDir::toNativeSeparators(info.absoluteFilePath()));
        result.insert(QStringLiteral("relativePath"), QDir::toNativeSeparators(root.relativeFilePath(path)));
        result.insert(QStringLiteral("matchType"), folders ? QStringLiteral("folder") : QStringLiteral("filename"));
        result.insert(QStringLiteral("excerpt"), QString());
        results.append(result);
    }

    return results;
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
