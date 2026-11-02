#include "mobile.h"

#include <QProcess>
#include <QRegularExpression>
#include <QMap>

M52xqMobile::M52xqMobile(QObject *parent) : QObject(parent) {}

QString M52xqMobile::run(const QString &program, const QStringList &args, int timeoutMs)
{
    QProcess p;
    p.start(program, args);
    if (!p.waitForFinished(timeoutMs)) {
        p.kill();
        return QString();
    }
    return QString::fromUtf8(p.readAllStandardOutput());
}

QString M52xqMobile::gsmConnection(bool *active) const
{
    *active = false;
    const QStringList lines = run(QStringLiteral("nmcli"), { "-t", "-f", "NAME,TYPE,ACTIVE", "connection", "show" })
                                  .split(QLatin1Char('\n'));
    for (const QString &line : lines) {
        QString l = line;
        l.replace(QStringLiteral("\\:"), QString(QChar(0)));
        const QStringList f = l.split(QLatin1Char(':'));
        if (f.size() >= 3 && f[1] == QLatin1String("gsm")) {
            *active = (f[2] == QLatin1String("yes"));
            QString name = f[0];
            return name.replace(QChar(0), QLatin1Char(':'));
        }
    }
    return QString();
}

QVariantMap M52xqMobile::status() const
{
    QVariantMap m;
    const QStringList st = run(QStringLiteral("/usr/local/sbin/m52xq-sim-mode"), { "status" }).trimmed()
                               .split(QRegularExpression(QStringLiteral("\\s+")), Qt::SkipEmptyParts);
    m["mode"] = st.value(0, QStringLiteral("dsds"));
    m["dataSim"] = st.value(1, QStringLiteral("1")).toInt();
    m["flight"] = st.size() > 2;
    bool active = false;
    const QString conn = gsmConnection(&active);
    m["connection"] = conn;
    m["dataOn"] = active;
    if (!conn.isEmpty()) {
        const QStringList v = run(QStringLiteral("nmcli"), { "-g", "gsm.apn,gsm.home-only", "connection", "show", conn })
                                  .split(QLatin1Char('\n'));
        m["apn"] = v.value(0).trimmed();
        m["roaming"] = (v.value(1).trimmed() != QLatin1String("yes"));	/* home-only = no roaming */
    } else {
        m["apn"] = QString();
        m["roaming"] = false;
    }
    return m;
}

QVariantList M52xqMobile::sims() const
{
    QMap<int, QVariantMap> bySlot;
    const QStringList list = run(QStringLiteral("mmcli"), { "-L", "--output-keyvalue" }).split(QLatin1Char('\n'));
    int n = 0;
    for (const QString &l : list) {
        const int i = l.indexOf(QStringLiteral("/org/freedesktop/ModemManager1/Modem/"));
        if (i < 0)
            continue;
        QVariantMap sim;
        int slot = 100 + n++;
        const QString info = run(QStringLiteral("mmcli"), { "-m", l.mid(i).trimmed(), "--output-keyvalue" });
        for (const QString &kv : info.split(QLatin1Char('\n'))) {
            const QString key = kv.section(QLatin1Char(':'), 0, 0).trimmed();
            const QString value = kv.section(QLatin1Char(':'), 1).trimmed();
            if (value == QLatin1String("--"))
                continue;
            if (key == QLatin1String("modem.generic.primary-sim-slot") && value.toInt() > 0)
                slot = value.toInt();
            else if (key == QLatin1String("modem.3gpp.operator-name"))
                sim["operator"] = value;
            else if (key == QLatin1String("modem.generic.state"))
                sim["state"] = value;
            else if (key == QLatin1String("modem.generic.signal-quality.value"))
                sim["signal"] = value.toInt();
            else if (key == QLatin1String("modem.generic.access-technologies.value[1]"))
                sim["tech"] = value;
        }
        sim["slot"] = slot;
        bySlot.insert(slot, sim);
    }
    QVariantList out;
    for (const QVariantMap &s : bySlot)
        out.append(s);
    return out;
}

void M52xqMobile::setDataEnabled(bool on)
{
    bool active = false;
    const QString conn = gsmConnection(&active);
    if (conn.isEmpty())
        return;
    QProcess::startDetached(QStringLiteral("nmcli"), { "connection", on ? "up" : "down", conn });
}

void M52xqMobile::setDataSim(int sim)
{
    if (sim != 1 && sim != 2)
        return;
    /* polkit rule 50-m52xq-sim-mode.rules lets the active user start these units */
    QProcess::startDetached(QStringLiteral("systemctl"), { "start", "--no-block", QStringLiteral("m52xq-sim-mode@data%1.service").arg(sim) });
}

void M52xqMobile::setRoaming(bool on)
{
    bool active = false;
    const QString conn = gsmConnection(&active);
    if (conn.isEmpty())
        return;
    run(QStringLiteral("nmcli"), { "connection", "modify", conn, "gsm.home-only", on ? "no" : "yes" });
}

bool M52xqMobile::setApn(const QString &apn)
{
    bool active = false;
    const QString conn = gsmConnection(&active);
    if (conn.isEmpty())
        return false;
    QProcess p;
    p.start(QStringLiteral("nmcli"), { "connection", "modify", conn, "gsm.apn", apn });
    return p.waitForFinished(3000) && p.exitCode() == 0;
}
