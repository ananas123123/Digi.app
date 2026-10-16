#pragma once

#include <QObject>
#include <QThread>
#include <QVariantList>
#include <QString>
#include <QStringList>

class DropImportWorker;
class SearchWorker;

class SearchService final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString searchRoot READ searchRoot CONSTANT)
    Q_PROPERTY(bool importInProgress READ importInProgress NOTIFY importStateChanged)
    Q_PROPERTY(int importProgressPercent READ importProgressPercent NOTIFY importProgressChanged)
    Q_PROPERTY(QString importStatus READ importStatus NOTIFY importProgressChanged)
    Q_PROPERTY(QVariantList searchResults READ searchResults NOTIFY searchResultsChanged)
    Q_PROPERTY(bool searching READ searching NOTIFY searchStateChanged)

public:
    explicit SearchService(QObject *parent = nullptr);
    ~SearchService() override;

    QString searchRoot() const;
    bool importInProgress() const;
    int importProgressPercent() const;
    QString importStatus() const;

    QVariantList searchResults() const;
    bool searching() const;
    Q_INVOKABLE void requestSearch(const QString &query,
                                  bool caseSensitive = false,
                                  bool includeHidden = false);
    Q_INVOKABLE QVariantList listFolderContents(const QString &path) const;
    Q_INVOKABLE QString previewFile(const QString &path) const;
    Q_INVOKABLE bool openFile(const QString &path) const;
    Q_INVOKABLE bool importDroppedUrls(const QVariantList &urls,
                                       const QString &destinationDirectory = QString());

signals:
    void importStateChanged();
    void importProgressChanged();
    void dropImportFinished(bool succeeded, const QString &message);
    void searchResultsChanged();
    void searchStateChanged();

private:
    QString m_searchRoot;
    QThread m_importThread;
    DropImportWorker *m_importWorker = nullptr;
    QThread m_searchThread;
    SearchWorker *m_searchWorker = nullptr;
    quint64 m_searchRequestId = 0;
    QVariantList m_searchResults;
    bool m_searching = false;
    bool m_importInProgress = false;
    int m_importProgressPercent = 0;
    QString m_importStatus;
};
