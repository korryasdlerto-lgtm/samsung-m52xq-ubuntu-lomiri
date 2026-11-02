/* m52xq (убунтутач24/003): lomiri-location-service resolves the AppArmor profile of every client with libapparmor's
 * aa_gettaskcon(); the mainline kernel has no AppArmor ("Could not resolve PID .. to apparmor profile: No such file"), so
 * Qt apps (Pure Maps: QGeoPositionInfoSource "lomiri") never got a position. Preloaded into the service: every client
 * is "unconfined" (the permission manager is already in TRUST_STORE_PERMISSION_MANAGER_IS_RUNNING_UNDER_TESTING mode). */
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>

int aa_gettaskcon(pid_t target, char **label, char **mode)
{
	static const char s[] = "unconfined\0enforce";
	char *buf = malloc(sizeof s);
	if (!buf)
		return -1;
	memcpy(buf, s, sizeof s);
	*label = buf;
	if (mode)
		*mode = buf + sizeof "unconfined";
	return sizeof s - 1;
}
