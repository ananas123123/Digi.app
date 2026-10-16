#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>
#include <atomic>

class SearchWorker final : public QObject
{
    Q_OBJECT

public:
    explicit SearchWorker(QObject *parent = nullptr);

    // Safe to update from the UI thread: the worker checks this between files
    // so that new queries cancel obsolete work promptly.
    void setLatestRequestId(quint64 requestId);

public slots:
    void performSearch(quint64 requestId,
                       const QString &rootPath,
                       const QString &query,
                       bool caseSensitive,
                       bool includeHidden);

signals:
    void searchCompleted(quint64 requestId, QVariantList results);

private:
    std::atomic<quint64> m_latestRequestId { 0 };
};
