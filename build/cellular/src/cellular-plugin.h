/* m52xq (убунтутач24/003): "Cellular" page of Lomiri System Settings for ModemManager / NetworkManager (the Ubuntu Touch one is
 * built on ofono and is not in lomiri-system-settings 1.5.0); the shade opens settings:///system/cellular. Template: plugins/example. */
#ifndef SYSTEM_SETTINGS_CELLULAR_PLUGIN_H
#define SYSTEM_SETTINGS_CELLULAR_PLUGIN_H

#include <QObject>
#include <LomiriSystemSettings/PluginInterface>

class CellularPlugin: public QObject, public LomiriSystemSettings::PluginInterface
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "com.lomiri.SystemSettings.PluginInterface")
    Q_INTERFACES(LomiriSystemSettings::PluginInterface)

public:
    CellularPlugin();

    LomiriSystemSettings::ItemBase *createItem(const QVariantMap &staticData, QObject *parent = 0);
};

#endif
