#include "SearchService.h"

#include <QCoreApplication>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <QSet>
#include <QTextStream>

namespace {
const QSet<QString> searchableExtensions = {
    QStringLiteral("txt"), QStringLiteral("md"), QStringLiteral("csv"),
    QStringLiteral("json"), QStringLiteral("xml"), QStringLiteral("html"),
    QStringLiteral("htm"), QStringLiteral("qml"), QStringLiteral("cpp"),
    QStringLiteral("h"), QStringLiteral("py"), QStringLiteral("log")
};

constexpr qint64 maxIndexedFileBytes = 2 * 1024 * 1024;
constexpr int maxResults = 200;
constexpr int maxExcerptLength = 220;

QString makeExcerpt(const QString &text, qsizetype matchPosition, qsizetype queryLength)
{
    const qsizetype start = qMax<qsizetype>(0, matchPosition - 70);
    const qsizetype end = qMin<qsizetype>(text.size(), matchPosition + queryLength + 130);
    QString excerpt = text.mid(start, end - start).simplified();
    if (start > 0)
        excerpt.prepend(QStringLiteral("…"));
    if (end < text.size())
        excerpt.append(QStringLiteral("…"));
    if (excerpt.size() > maxExcerptLength)
        excerpt = excerpt.left(maxExcerptLength - 1) + QChar(0x2026);
    return excerpt;
}
}

SearchService::SearchService(QObject *parent)
    : QObject(parent),
      m_searchRoot(QDir(QCoreApplication::applicationDirPath())
                       .filePath(QStringLiteral("Digi/search QR")))
{
    QDir().mkpath(m_searchRoot);
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

    const QString needleFolded = needle.toCaseFolded();
    QDirIterator iterator(root.absolutePath(),
                          QDir::Files | QDir::Readable | QDir::NoDotAndDotDot,
                          QDirIterator::Subdirectories);

    while (iterator.hasNext() && results.size() < maxResults) {
        const QString path = iterator.next();
        const QFileInfo info(path);
        if (info.isHidden())
            continue;

        const QString name = info.fileName();
        bool matched = name.contains(needle, Qt::CaseInsensitive);
        QString excerpt;
        QString matchType = matched ? QStringLiteral("filename") : QString();

        if (!matched && searchableExtensions.contains(info.suffix().toCaseFolded())
            && info.size() <= maxIndexedFileBytes) {
            QFile file(path);
            if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
                QTextStream stream(&file);
                stream.setEncoding(QStringConverter::Utf8);
                const QString contents = stream.readAll();
                const qsizetype position = contents.toCaseFolded().indexOf(needleFolded);
                if (position >= 0) {
                    matched = true;
                    matchType = QStringLiteral("content");
                    excerpt = makeExcerpt(contents, position, needle.size());
                }
            }
        }

        if (!matched)
            continue;

        QVariantMap result;
        result.insert(QStringLiteral("name"), name);
        result.insert(QStringLiteral("path"), QDir::toNativeSeparators(info.absoluteFilePath()));
        result.insert(QStringLiteral("relativePath"), QDir::toNativeSeparators(root.relativeFilePath(path)));
        result.insert(QStringLiteral("matchType"), matchType);
        result.insert(QStringLiteral("excerpt"), excerpt);
        results.append(result);
    }

    return results;
}
