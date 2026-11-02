/* проверка: сколько EGL-конфигураций ES2 отдаёт платформа GBM (так её опрашивает Mir) и есть ли EGL_WL_bind_wayland_display */
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <gbm.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
int main(void) {
    int fd = open("/dev/dri/renderD128", O_RDWR | O_CLOEXEC);
    if (fd < 0) { perror("open renderD128"); return 2; }
    struct gbm_device *g = gbm_create_device(fd);
    PFNEGLGETPLATFORMDISPLAYEXTPROC gpd = (PFNEGLGETPLATFORMDISPLAYEXTPROC)eglGetProcAddress("eglGetPlatformDisplayEXT");
    EGLDisplay d = gpd(EGL_PLATFORM_GBM_KHR, g, NULL);
    EGLint maj, min;
    if (!eglInitialize(d, &maj, &min)) { printf("eglInitialize FAIL 0x%x\n", eglGetError()); return 3; }
    const char *ext = eglQueryString(d, EGL_EXTENSIONS);
    printf("EGL %d.%d vendor=%s\n", maj, min, eglQueryString(d, EGL_VENDOR));
    printf("WL_bind_wayland_display: %s\n", strstr(ext, "EGL_WL_bind_wayland_display") ? "ДА" : "нет");
    printf("KHR_platform_gbm: %s\n", strstr(ext, "EGL_KHR_platform_gbm") ? "ДА" : "нет");
    EGLint na[] = { EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT, EGL_SURFACE_TYPE, EGL_WINDOW_BIT, EGL_NONE };
    EGLConfig c[64]; EGLint n = 0;
    eglChooseConfig(d, na, c, 64, &n);
    printf("конфигов ES2+WINDOW: %d\n", n);
    return 0;
}
