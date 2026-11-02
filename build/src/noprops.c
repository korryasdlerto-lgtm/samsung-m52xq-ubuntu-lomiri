/* LD_PRELOAD-заглушка: libdeviceinfo (Halium::usable) спрашивает свойства Android через libhybris,
   а linker libhybris на мейнлайне не грузится (static TLS) и вызывает exit(1). Отвечаем «свойств нет». */
#include <string.h>
#include <stdlib.h>
int property_get(const char *key, char *value, const char *default_value) {
    if (default_value) { strncpy(value, default_value, 91); value[91] = 0; return (int)strlen(value); }
    value[0] = 0; return 0;
}
int property_set(const char *key, const char *value) { return -1; }
int property_get_int32(const char *key, int dflt) { return dflt; }
