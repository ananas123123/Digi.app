#include "SearchService.h"

#include <QCoreApplication>
#include <QDir>
#include <QDirIterator>
#include <QFileInfo>

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

QVariantList SearchService::search(const QString &query) const
{
    QVariantList results;
    const QString needle = query.trimmed();
    if (needle.isEmpty())
        return results;

    const QDir root(m_searchRoot);
    if (!root.exists())
        return results;

    QDirIterator iterator(root.absolutePath(),
                          QDir::Files | QDir::Readable | QDir::NoDotAndDotDot,
                          QDirIterator::Subdirectories);

    while (iterator.hasNext() && results.size() < maxResults) {
        const QString path = iterator.next();
        const QFileInfo info(path);
        if (info.isHidden())
            continue;

        const QString name = info.fileName();
        if (!name.contains(needle, Qt::CaseInsensitive))
            continue;

        QVariantMap result;
        result.insert(QStringLiteral("name"), name);
        result.insert(QStringLiteral("path"), QDir::toNativeSeparators(info.absoluteFilePath()));
        result.insert(QStringLiteral("relativePath"), QDir::toNativeSeparators(root.relativeFilePath(path)));
        result.insert(QStringLiteral("matchType"), QStringLiteral("filename"));
        result.insert(QStringLiteral("excerpt"), QString());
        results.append(result);
    }

    return results;
}
