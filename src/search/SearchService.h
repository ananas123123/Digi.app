#pragma once

#include <QObject>
#include <QVariantList>
#include <QString>

class SearchService final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString searchRoot READ searchRoot CONSTANT)

public:
    explicit SearchService(QObject *parent = nullptr);

    QString searchRoot() const;

    Q_INVOKABLE QVariantList search(const QString &query) const;
    Q_INVOKABLE QString previewFile(const QString &path) const;
    Q_INVOKABLE bool openFile(const QString &path) const;

private:
    QString m_searchRoot;
};
