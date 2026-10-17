#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <unistd.h>
#include <drm.h>
#include <drm_mode.h>
#include <xf86drm.h>
#include <xf86drmMode.h>

static volatile sig_atomic_t child_pid;
static volatile sig_atomic_t stopping;

static void stop(int sig)
{
    stopping = sig;
    if (child_pid > 0)
        kill(child_pid, sig);
}

static uint32_t property(int fd, uint32_t id, uint32_t type,
                         const char *name, uint64_t *value)
{
    uint32_t result = 0;
    drmModeObjectProperties *props = drmModeObjectGetProperties(fd, id, type);
    if (!props)
        return 0;
    for (uint32_t i = 0; i < props->count_props; i++) {
        drmModePropertyRes *p = drmModeGetProperty(fd, props->props[i]);
        if (p && !strcmp(p->name, name)) {
            result = p->prop_id;
            *value = props->prop_values[i];
        }
        drmModeFreeProperty(p);
    }
    drmModeFreeObjectProperties(props);
    return result;
}

int main(int argc, char **argv)
{
    if (argc < 6 || strcmp(argv[4], "--")) {
        fprintf(stderr, "usage: %s WIDTH HEIGHT FPS -- COMMAND [ARGS...]\n", argv[0]);
        return 2;
    }
    int width = atoi(argv[1]), height = atoi(argv[2]), fps = atoi(argv[3]);
    int result = 1, fd = drmOpen("meson", NULL);
    uint32_t connector = 0, crtc = 0, plane = 0, alpha = 0, fb = 0;
    uint64_t saved_alpha = 0;
    int crtc_index = -1, activated = 0, alpha_changed = 0;
    char saved_axis[128] = {0};
    int axis_changed = 0;
    drmModeModeInfo mode = {0};
    struct drm_mode_create_dumb dumb = {0};
    if (fd < 0) {
        perror("open meson DRM");
        return 1;
    }
    if (fcntl(fd, F_SETFD, FD_CLOEXEC) < 0 || drmSetMaster(fd) < 0 ||
        drmSetClientCap(fd, DRM_CLIENT_CAP_UNIVERSAL_PLANES, 1) < 0) {
        perror("acquire DRM display");
        goto done;
    }
    drmModeRes *res = drmModeGetResources(fd);
    if (!res)
        goto done;
    for (int i = 0; i < res->count_connectors && !connector; i++) {
        drmModeConnector *c = drmModeGetConnector(fd, res->connectors[i]);
        if (!c)
            continue;
        if (c->connection == DRM_MODE_CONNECTED && c->connector_type == DRM_MODE_CONNECTOR_HDMIA) {
            for (int m = 0; m < c->count_modes && !connector; m++) {
                drmModeModeInfo *candidate = &c->modes[m];
                if (candidate->hdisplay != width || candidate->vdisplay != height ||
                    (int)candidate->vrefresh != fps || (candidate->flags & DRM_MODE_FLAG_INTERLACE))
                    continue;
                for (int e = 0; e < c->count_encoders && !connector; e++) {
                    drmModeEncoder *enc = drmModeGetEncoder(fd, c->encoders[e]);
                    if (!enc)
                        continue;
                    for (int k = 0; k < res->count_crtcs; k++) {
                        if (enc->possible_crtcs & (1u << k)) {
                            connector = c->connector_id;
                            crtc = res->crtcs[k];
                            crtc_index = k;
                            mode = *candidate;
                            break;
                        }
                    }
                    drmModeFreeEncoder(enc);
                }
            }
        }
        drmModeFreeConnector(c);
    }
    drmModeFreeResources(res);
    if (!connector) {
        fprintf(stderr, "No connected HDMI mode for %dx%d at %d Hz\n", width, height, fps);
        goto done;
    }
    drmModePlaneRes *planes = drmModeGetPlaneResources(fd);
    if (!planes)
        goto done;
    for (uint32_t i = 0; i < planes->count_planes && !plane; i++) {
        drmModePlane *p = drmModeGetPlane(fd, planes->planes[i]);
        uint64_t type = 0;
        if (p && (p->possible_crtcs & (1u << crtc_index)) &&
            property(fd, p->plane_id, DRM_MODE_OBJECT_PLANE, "type", &type) &&
            type == DRM_PLANE_TYPE_PRIMARY) {
            plane = p->plane_id;
            alpha = property(fd, plane, DRM_MODE_OBJECT_PLANE, "alpha", &saved_alpha);
        }
        drmModeFreePlane(p);
    }
    drmModeFreePlaneResources(planes);
    if (!plane || !alpha) {
        fprintf(stderr, "No primary plane with global alpha\n");
        goto done;
    }
    dumb.width = width;
    dumb.height = height;
    dumb.bpp = 32;
    if (ioctl(fd, DRM_IOCTL_MODE_CREATE_DUMB, &dumb) < 0 ||
        drmModeAddFB(fd, width, height, 24, 32, dumb.pitch, dumb.handle, &fb) < 0) {
        perror("allocate display framebuffer");
        goto done;
    }
    /* The native amvideo layer supplies the picture; OSD must be transparent. */
    if (drmModeObjectSetProperty(fd, plane, DRM_MODE_OBJECT_PLANE, alpha, 0) < 0) {
        perror("make OSD transparent");
        goto done;
    }
    alpha_changed = 1;
    if (drmModeSetCrtc(fd, crtc, fb, 0, 0, &connector, 1, &mode) < 0) {
        perror("activate HDMI");
        goto done;
    }
    activated = 1;
    /* Kodi may leave a cropped 4K rectangle even when the new mode is 1080p. */
    FILE *axis = fopen("/sys/class/video/axis", "r");
    if (!axis || !fgets(saved_axis, sizeof(saved_axis), axis)) {
        if (axis)
            fclose(axis);
        fprintf(stderr, "Cannot read Amlogic video axis\n");
        goto done;
    }
    fclose(axis);
    axis = fopen("/sys/class/video/axis", "w");
    if (!axis) {
        perror("open Amlogic video axis");
        goto done;
    }
    int written = fprintf(axis, "0 0 %d %d\n", width - 1, height - 1);
    int closed = fclose(axis);
    if (written < 0 || closed != 0) {
        perror("set Amlogic video axis");
        goto done;
    }
    axis_changed = 1;
    fprintf(stderr, "HDMI active: %s; starting %s\n", mode.name, argv[5]);
    struct sigaction action = {.sa_handler = stop};
    sigemptyset(&action.sa_mask);
    sigaction(SIGTERM, &action, NULL);
    sigaction(SIGINT, &action, NULL);
    sigaction(SIGHUP, &action, NULL);
    pid_t pid = fork();
    if (pid < 0) {
        perror("fork frontend");
        goto done;
    }
    if (pid == 0) {
        signal(SIGTERM, SIG_DFL);
        signal(SIGINT, SIG_DFL);
        signal(SIGHUP, SIG_DFL);
        execvp(argv[5], &argv[5]);
        perror("exec frontend");
        _exit(127);
    }
    child_pid = pid;
    if (stopping)
        kill(pid, stopping);
    int status;
    pid_t waited;
    do {
        waited = waitpid(pid, &status, 0);
    } while (waited < 0 && errno == EINTR);
    child_pid = 0;
    if (waited == pid)
        result = WIFEXITED(status) ? WEXITSTATUS(status) : 128 + WTERMSIG(status);
done:
    if (axis_changed) {
        FILE *restore = fopen("/sys/class/video/axis", "w");
        if (restore) {
            fputs(saved_axis, restore);
            fclose(restore);
        }
    }
    if (activated)
        drmModeSetCrtc(fd, crtc, 0, 0, 0, NULL, 0, NULL);
    /* Kodi does not initialize global alpha. Always hand it an opaque OSD,
     * including recovery from a previous interrupted transparent session. */
    if (alpha_changed)
        drmModeObjectSetProperty(fd, plane, DRM_MODE_OBJECT_PLANE, alpha, 65535);
    if (fb)
        drmModeRmFB(fd, fb);
    if (dumb.handle) {
        struct drm_mode_destroy_dumb destroy = {.handle = dumb.handle};
        ioctl(fd, DRM_IOCTL_MODE_DESTROY_DUMB, &destroy);
    }
    close(fd);
    return result;
}
