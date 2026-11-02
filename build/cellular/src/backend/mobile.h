/* m52xq: backend of the Cellular page: ModemManager (mmcli), NetworkManager (nmcli), /usr/local/sbin/m52xq-sim-mode.
 * Everything blocking is short (a few ms - 2 s); changes are started detached. */
#ifndef M52XQ_MOBILE_H
#define M52XQ_MOBILE_H

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

class M52xqMobile : public QObject
{
    Q_OBJECT

public:
    explicit M52xqMobile(QObject *parent = nullptr);

    /* { mode: "dsds"|"sim1"|"sim2", dataSim: 1|2, flight: bool, connection: name, dataOn: bool, roaming: bool, apn: string } */
    Q_INVOKABLE QVariantMap status() const;
    /* [ { slot: 1|2, operator: string, state: string, signal: int, tech: string } ], by slot */
    Q_INVOKABLE QVariantList sims() const;

    Q_INVOKABLE void setDataEnabled(bool on);
    Q_INVOKABLE void setDataSim(int sim);
    Q_INVOKABLE void setRoaming(bool on);
    Q_INVOKABLE bool setApn(const QString &apn);

private:
    static QString run(const QString &program, const QStringList &args, int timeoutMs = 3000);
    QString gsmConnection(bool *active) const;
};

#endif
