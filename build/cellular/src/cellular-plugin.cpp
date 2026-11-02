#include "cellular-plugin.h"

#include <QString>
#include <LomiriSystemSettings/ItemBase>

using namespace LomiriSystemSettings;

class CellularItem: public ItemBase
{
    Q_OBJECT

public:
    explicit CellularItem(const QVariantMap &staticData, QObject *parent = 0): ItemBase(staticData, parent) {}
    virtual ~CellularItem() {}

    virtual QQmlComponent *pageComponent(QQmlEngine *engine, QObject *parent = 0)
    {
        QString qmlPath = QString("file://%1/cellular/PageComponent.qml").arg(PLUGIN_QML_DIR);
        return new QQmlComponent(engine, QUrl(qmlPath), parent);
    }
};

CellularPlugin::CellularPlugin(): QObject() {}

ItemBase *CellularPlugin::createItem(const QVariantMap &staticData, QObject *parent)
{
    return new CellularItem(staticData, parent);
}

#include "cellular-plugin.moc"
