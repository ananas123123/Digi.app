#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QCoreApplication>

#include "app/AppServices.h"
#include "documents/DocumentService.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
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
