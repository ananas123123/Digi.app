#pragma once

#include <QObject>
#include <QVariantList>

class SearchService final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString searchRoot READ searchRoot CONSTANT)

public:
    explicit SearchService(QObject *parent = nullptr);

    QString searchRoot() const;

    Q_INVOKABLE QVariantList search(const QString &query) const;

private:
    QString m_searchRoot;
};
