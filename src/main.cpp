#include <QGuiApplication>
#include <QQuickWindow>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QCoreApplication>
#include <QFile>
#include <QDateTime>
#include <QMutex>
#include <QMutexLocker>
#include <QTextStream>
#include <cstdio>

#include "app/AppServices.h"
#include "documents/DocumentService.h"
#include "search/SearchService.h"

namespace {
QMutex logMutex;

void writeRuntimeLog(QtMsgType type, const QMessageLogContext &context, const QString &message)
{
    QMutexLocker locker(&logMutex);
    const char *level = "INFO";
    switch (type) {
    case QtDebugMsg: level = "DEBUG"; break;
    case QtInfoMsg: level = "INFO"; break;
    case QtWarningMsg: level = "WARNING"; break;
    case QtCriticalMsg: level = "CRITICAL"; break;
    case QtFatalMsg: level = "FATAL"; break;
    }

    const QByteArray consoleMessage = message.toLocal8Bit();
    std::fprintf(stderr, "[%s] %s", level, consoleMessage.constData());
    if (context.file)
        std::fprintf(stderr, " (%s:%d)", context.file, context.line);
    std::fprintf(stderr, "\n");
    std::fflush(stderr);

    QFile file(QCoreApplication::applicationDirPath() + "/lubis-runtime.log");
    if (!file.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text))
        return;

    QTextStream out(&file);
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
    QQuickWindow::setTextRenderType(QQuickWindow::NativeTextRendering);
    qInstallMessageHandler(writeRuntimeLog);
    QCoreApplication::setApplicationName("Lubis");
    QCoreApplication::setOrganizationName("Lubis");

    AppServices appServices;
    DocumentService documentService;
    SearchService searchService;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("appServices", &appServices);
    engine.rootContext()->setContextProperty("documentService", &documentService);
    engine.rootContext()->setContextProperty("searchService", &searchService);

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(EXIT_FAILURE); },
        Qt::QueuedConnection);

    engine.loadFromModule("Lubis", "Main");
    return app.exec();
}
