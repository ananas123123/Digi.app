#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QCoreApplication>
#include <QFile>
#include <QDateTime>
#include <QMutex>
#include <QMutexLocker>
#include <QTextStream>

#include "app/AppServices.h"
#include "documents/DocumentService.h"

namespace {
QMutex logMutex;

void writeRuntimeLog(QtMsgType type, const QMessageLogContext &context, const QString &message)
{
    QMutexLocker locker(&logMutex);
    QFile file(QCoreApplication::applicationDirPath() + "/digi-runtime.log");
    if (!file.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text))
        return;

    QTextStream out(&file);
    const char *level = "INFO";
    switch (type) {
    case QtDebugMsg: level = "DEBUG"; break;
    case QtInfoMsg: level = "INFO"; break;
    case QtWarningMsg: level = "WARNING"; break;
    case QtCriticalMsg: level = "CRITICAL"; break;
    case QtFatalMsg: level = "FATAL"; break;
    }
    out << QDateTime::currentDateTime().toString(Qt::ISODateWithMs)
        << " [" << level << "] "
        << message;
    if (context.file)
        out << " (" << context.file << ":" << context.line << ")";
    out << Qt::endl;
}
}

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    qInstallMessageHandler(writeRuntimeLog);
    QCoreApplication::setApplicationName("Digi");
    QCoreApplication::setOrganizationName("Digi");

    AppServices appServices;
    DocumentService documentService;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("appServices", &appServices);
    engine.rootContext()->setContextProperty("documentService", &documentService);

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(EXIT_FAILURE); },
        Qt::QueuedConnection);

    engine.loadFromModule("Digi", "Main");
    return app.exec();
}
