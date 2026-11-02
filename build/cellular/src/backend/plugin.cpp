#include "plugin.h"
#include "mobile.h"
#include <QtQml>

void BackendPlugin::registerTypes(const char *uri)
{
    Q_ASSERT(uri == QLatin1String("Lomiri.SystemSettings.M52xqCellular"));
    qmlRegisterType<M52xqMobile>(uri, 1, 0, "M52xqMobile");
}
