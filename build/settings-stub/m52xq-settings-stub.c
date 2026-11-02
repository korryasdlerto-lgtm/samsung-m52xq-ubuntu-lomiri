/* lomiri-system-settings 1.5.0 (UBports 26.04): libLomiriBrightnessPanel.so ссылается на DeviceModel::slotAdapterPropertiesChanged
   (QString const&, QMap<QString,QVariant> const&, QStringList const&), но не определяет его -> "undefined symbol", страница «Яркость»
   не грузится. Пустая заглушка с тем же искажённым именем (Qt не нужен); подгружается только для Settings через LD_PRELOAD.
   Сборка: gcc -shared -fPIC -O2 -o libm52xq-settings-stub.so m52xq-settings-stub.c */
void m52xq_stub(void) __asm__("_ZN11DeviceModel28slotAdapterPropertiesChangedERK7QStringRK4QMapIS0_8QVariantERK11QStringList");
void m52xq_stub(void) {}
