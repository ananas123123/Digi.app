#include "AppServices.h"

AppServices::AppServices(QObject *parent) : QObject(parent) {}
QString AppServices::applicationName() const { return QStringLiteral("Digi"); }
QString AppServices::version() const { return QStringLiteral("0.1.0-dev"); }
