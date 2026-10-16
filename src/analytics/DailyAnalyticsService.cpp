#include "DailyAnalyticsService.h"

#include <QCoreApplication>
#include <QDate>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QStandardPaths>
#include <QDebug>

DailyAnalyticsService::DailyAnalyticsService(QObject *parent)
    : QObject(parent)
{
    QString dataRoot = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation);
    if (dataRoot.isEmpty())
        dataRoot = QCoreApplication::applicationDirPath();

    // On Windows this normally resolves to %APPDATA%/Lubis/user-data/analytics/daily.
    m_storageDirectory = QDir(dataRoot).filePath(QStringLiteral("Lubis/user-data/analytics/daily"));

    if (!QDir().mkpath(m_storageDirectory))
        qWarning() << "Could not create Lubis daily analytics directory:" << m_storageDirectory;

    loadToday();
}

qint64 DailyAnalyticsService::focusedSecondsToday() const
{
    return m_focusedSecondsToday;
}

int DailyAnalyticsService::completedFocusSessionsToday() const
{
    return m_completedFocusSessionsToday;
}

QString DailyAnalyticsService::dailyFilePath() const
{
    return filePathForDate(QDate::currentDate());
}

void DailyAnalyticsService::addFocusedSeconds(qint64 seconds)
{
    if (seconds <= 0)
        return;

    if (!loadToday()) {
        qWarning() << "Could not load today's Lubis analytics data.";
        return;
    }

    m_focusedSecondsToday += seconds;
    if (!saveToday())
        qWarning() << "Could not save today's Lubis focus-time counter.";
    emit dailyStatsChanged();
}

void DailyAnalyticsService::recordFocusSessionCompleted()
{
    if (!loadToday()) {
        qWarning() << "Could not load today's Lubis analytics data.";
        return;
    }

    ++m_completedFocusSessionsToday;
    if (!saveToday())
        qWarning() << "Could not save today's completed-session counter.";
    emit dailyStatsChanged();
}

void DailyAnalyticsService::refreshToday()
{
    const QString previousDate = m_loadedDate;
    if (!loadToday()) {
        qWarning() << "Could not refresh today's Lubis analytics data.";
        return;
    }

    if (previousDate != m_loadedDate)
        emit dailyStatsChanged();
}

bool DailyAnalyticsService::loadToday()
{
    const QString today = QDate::currentDate().toString(Qt::ISODate);
    if (m_loadedDate == today)
        return true;

    m_loadedDate = today;
    m_focusedSecondsToday = 0;
    m_completedFocusSessionsToday = 0;

    const QString path = filePathForDate(QDate::currentDate());
    QFile file(path);
    if (!file.exists())
        return saveToday();

    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "Could not read Lubis daily analytics file:" << path << file.errorString();
        return false;
    }

    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(file.readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
        qWarning() << "Invalid Lubis daily analytics JSON:" << path << parseError.errorString();
        return false;
    }

    const QJsonObject object = document.object();
    if (object.value(QStringLiteral("date")).toString() != today) {
        qWarning() << "Date mismatch in Lubis daily analytics file:" << path;
        return false;
    }

    m_focusedSecondsToday = qMax<qint64>(0, qint64(object.value(QStringLiteral("focusedSeconds")).toDouble(0)));
    m_completedFocusSessionsToday = qMax(0, object.value(QStringLiteral("completedFocusSessions")).toInt(0));
    return true;
}

bool DailyAnalyticsService::saveToday() const
{
    QSaveFile file(filePathForDate(QDate::currentDate()));
    if (!file.open(QIODevice::WriteOnly)) {
        qWarning() << "Could not write Lubis daily analytics file:" << file.fileName() << file.errorString();
        return false;
    }

    QJsonObject object;
    object.insert(QStringLiteral("schemaVersion"), 1);
    object.insert(QStringLiteral("date"), QDate::currentDate().toString(Qt::ISODate));
    object.insert(QStringLiteral("focusedSeconds"), double(m_focusedSecondsToday));
    object.insert(QStringLiteral("completedFocusSessions"), m_completedFocusSessionsToday);
    object.insert(QStringLiteral("updatedAt"), QDateTime::currentDateTime().toString(Qt::ISODateWithMs));

    const QByteArray json = QJsonDocument(object).toJson(QJsonDocument::Indented);
    if (file.write(json) != json.size()) {
        qWarning() << "Could not write complete Lubis daily analytics file:" << file.fileName() << file.errorString();
        return false;
    }
    if (!file.commit()) {
        qWarning() << "Could not commit Lubis daily analytics file:" << file.fileName() << file.errorString();
        return false;
    }
    return true;
}

QString DailyAnalyticsService::filePathForDate(const QDate &date) const
{
    return QDir(m_storageDirectory).filePath(date.toString(Qt::ISODate) + QStringLiteral(".json"));
}
