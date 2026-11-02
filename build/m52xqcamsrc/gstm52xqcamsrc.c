/* M52XQ (убунтутач24/003): video source for QtMultimedia camerabin (lomiri-camera-app).
 * Qt reads QT_GSTREAMER_CAMERABIN_VIDEOSRC as a gst-launch description but splits it at '=' and ',' (its
 * "driver=element" syntax), so "libcamerasrc camera-name=..." cannot be given there and libcamerasrc opened just the
 * first libcamera camera. This bin holds a libcamerasrc whose camera comes from M52XQ_CAMERA (front / rear, read when
 * the element is created: camerabin creates a new one every time it builds its source), always as BGRx. */
#include <gst/gst.h>
#include <gst/video/video.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <linux/videodev2.h>

#define REAR_ID "/base/soc/cci@ac4a000/i2c-bus@0/camera@2d"	/* s5kgw3, main 64 MP */
#define FRONT_ID "/base/soc/cci@ac4b000/i2c-bus@0/camera@1a"	/* imx616 */


/* ---- software autofocus of the rear main camera (port of LensAutofocus of plasma-camera, m52xq r33) ----
 * Contrast search with the voice-coil lens (fp5529, V4L2 focus_absolute) on the frames that pass through this bin:
 * the sharpness of a square around the tapped point (or the middle) is measured on every frame. A tap is handed over
 * by the camera application as a file XDG_RUNTIME_DIR/m52xq-focus ("u v" in 0..1 of the frame). Frames of the photo
 * size (>= 3000 px wide) are not analysed: the lens just stays where the search ended. */
#define AF_INFINITY 335		/* factory calibration (EEPROM): 335 = infinity, 621 = macro */
#define AF_MACRO 621
#define AF_SETTLE 3
#define AF_START 345
#define AF_COARSE 50
#define AF_FINE 15
#define AF_FINE_SPAN 40
#define AF_LOW_RATIO 0.4
#define AF_LOW_FRAMES 45
#define AF_MEAN_CHANGE 0.6
enum { AF_OFF, AF_SETTLING, AF_SCANNING, AF_HOLDING };

typedef struct {
	int fd, state, pos, cur, best_pos, stage, falling, dir, fine, fine_from, fine_to, settle, low_frames, frame_no;
	double best_score, reference, ref_mean, roi_u, roi_v;
	char *tap_path;
} Af;

static int af_last_locked = -1;	/* survives the re-creation of the bin (camerabin builds a new source for every mode change) */

static int af_open_lens(void)
{
	for (int i = 0; i < 64; i++) {
		char path[96], name[64] = "";
		snprintf(path, sizeof(path), "/sys/class/video4linux/v4l-subdev%d/name", i);
		FILE *f = fopen(path, "r");
		if (!f)
			continue;
		if (fgets(name, sizeof(name), f) && !strncmp(name, "fp5529", 6)) {
			fclose(f);
			snprintf(path, sizeof(path), "/dev/v4l-subdev%d", i);
			int fd = open(path, O_RDWR | O_CLOEXEC);
			if (fd >= 0)
				g_message("m52xq-af: lens %s", path);
			return fd;
		}
		fclose(f);
	}
	return -1;
}

static void af_set_pos(Af *a, int pos)
{
	if (pos < 0) pos = 0;
	if (pos > 1023) pos = 1023;
	struct v4l2_control c = { V4L2_CID_FOCUS_ABSOLUTE, pos };
	if (ioctl(a->fd, VIDIOC_S_CTRL, &c) == 0)
		a->cur = pos;
}

static void af_move(Af *a, int pos)
{
	if (pos < AF_INFINITY) pos = AF_INFINITY;
	if (pos > AF_MACRO) pos = AF_MACRO;
	a->pos = pos;
	af_set_pos(a, pos);
	a->settle = AF_SETTLE;
	a->state = AF_SETTLING;
}

static void af_start(Af *a)
{
	a->fine = 0; a->stage = 0; a->falling = 0; a->dir = 1; a->best_score = 0; a->low_frames = 0;
	a->best_pos = af_last_locked >= 0 ? af_last_locked : AF_START;
	af_move(a, a->best_pos);
}

static void af_finish(Af *a, int pos)
{
	if (pos < AF_INFINITY) pos = AF_INFINITY;
	if (pos > AF_MACRO) pos = AF_MACRO;
	a->best_pos = pos; af_last_locked = pos;
	af_set_pos(a, pos);
	a->reference = 0; a->settle = AF_SETTLE; a->state = AF_HOLDING;
	g_message("m52xq-af: locked at %d", pos);
}

static void af_evaluate(Af *a, double score)
{
	if (!a->fine) {
		if (score > a->best_score) { a->best_score = score; a->best_pos = a->pos; a->falling = 0; }
		else if (score < a->best_score * 0.85) a->falling++;
		a->stage++;
		if (a->stage == 2 && a->dir > 0 && score < a->best_score * 0.95) {
			a->dir = -1; a->falling = 0;
			int np = a->best_pos - AF_COARSE; if (np < AF_INFINITY) np = AF_INFINITY;
			af_move(a, np);
			return;
		}
		int next = a->pos + AF_COARSE * a->dir;
		if (a->falling >= 2 || next > AF_MACRO || next < AF_INFINITY) {
			a->fine = 1;
			a->fine_from = a->best_pos - AF_FINE_SPAN < AF_INFINITY ? AF_INFINITY : a->best_pos - AF_FINE_SPAN;
			a->fine_to = a->best_pos + AF_FINE_SPAN > AF_MACRO ? AF_MACRO : a->best_pos + AF_FINE_SPAN;
			a->best_score = 0;
			af_move(a, a->fine_from);
			return;
		}
		af_move(a, next);
		return;
	}
	if (score > a->best_score) { a->best_score = score; a->best_pos = a->pos; }
	if (a->pos >= a->fine_to) { af_finish(a, a->best_pos); return; }
	int np = a->pos + AF_FINE; if (np > a->fine_to) np = a->fine_to;
	af_move(a, np);
}

/* gradient energy of 4x4 block averages of the green channel (BGRx: byte 1) in the region of interest */
static double af_sharpness(Af *a, const guint8 *data, int stride, int width, int height, double *mean)
{
	*mean = 0;
	if (width < 64 || height < 64)
		return 0;
	gboolean tapped = a->roi_u >= 0;
	int rw = (tapped ? width / 5 : width * 2 / 5) & ~3, rh = (tapped ? height / 5 : height * 2 / 5) & ~3;
	int x0 = tapped ? (int)(a->roi_u * width) - rw / 2 : (width - rw) / 2;
	int y0 = tapped ? (int)(a->roi_v * height) - rh / 2 : (height - rh) / 2;
	if (x0 < 0) x0 = 0;
	if (y0 < 0) y0 = 0;
	if (x0 > width - rw) x0 = width - rw;
	if (y0 > height - rh) y0 = height - rh;
	x0 &= ~3; y0 &= ~3;
	int bw = rw / 4, bh = rh / 4;
	float *blocks = g_malloc((gsize)bw * bh * sizeof(float));
	double sum = 0;
	for (int by = 0; by < bh; by++)
		for (int bx = 0; bx < bw; bx++) {
			int acc = 0;
			for (int j = 0; j < 4; j++) {
				const guint8 *line = data + (gsize)(y0 + by * 4 + j) * stride + (x0 + bx * 4) * 4 + 1;
				acc += line[0] + line[4] + line[8] + line[12];
			}
			blocks[by * bw + bx] = acc / 16.0f;
			sum += blocks[by * bw + bx];
		}
	double m = sum / ((double)bw * bh), energy = 0;
	for (int by = 0; by < bh - 1; by++)
		for (int bx = 0; bx < bw - 1; bx++) {
			double gx = blocks[by * bw + bx + 1] - blocks[by * bw + bx];
			double gy = blocks[(by + 1) * bw + bx] - blocks[by * bw + bx];
			energy += gx * gx + gy * gy;
		}
	g_free(blocks);
	*mean = m;
	return energy / ((double)bw * bh) / MAX(m * m, 1.0) * 1000.0;
}

static void af_process(Af *a, double score, double mean)
{
	if (a->settle > 0 && a->state != AF_SCANNING) {
		if (--a->settle > 0)
			return;
		if (a->state == AF_SETTLING)
			a->state = AF_SCANNING;
		/* this frame was taken after the settling time: measure it */
	}
	switch (a->state) {
	case AF_SCANNING:
		af_evaluate(a, score);
		break;
	case AF_HOLDING:
		if (a->reference <= 0) { a->reference = score; a->ref_mean = mean; a->low_frames = 0; break; }
		if (score < a->reference * AF_LOW_RATIO || fabs(mean - a->ref_mean) > a->ref_mean * AF_MEAN_CHANGE) {
			if (++a->low_frames >= AF_LOW_FRAMES) { g_message("m52xq-af: scene changed, searching again"); af_start(a); }
		} else
			a->low_frames = 0;
		break;
	default:
		break;
	}
}

static void af_check_tap(Af *a)
{
	gchar *txt = NULL;
	if (!g_file_get_contents(a->tap_path, &txt, NULL, NULL))
		return;
	double u = 0, v = 0;
	gboolean parsed = FALSE;
	if (txt) {
		/* g_ascii_strtod: the application runs in a locale with a decimal comma (ru_RU), sscanf would stop at "0." */
		char *e1 = NULL, *e2 = NULL;
		u = g_ascii_strtod(txt, &e1);
		if (e1 && e1 != txt) {
			v = g_ascii_strtod(e1, &e2);
			parsed = e2 && e2 != e1;
		}
	}
	/* the application creates the file first and writes into it a moment later: an empty / partial file is read again
	 * on the next check, never thrown away (that lost the tap) */
	if (parsed) {
		unlink(a->tap_path);
		a->roi_u = CLAMP(u, 0.0, 1.0);
		a->roi_v = CLAMP(v, 0.0, 1.0);
		g_message("m52xq-af: tap at %.3f %.3f", a->roi_u, a->roi_v);
		af_start(a);
	}
	g_free(txt);
}

static GstPadProbeReturn af_probe(GstPad *pad, GstPadProbeInfo *info, gpointer user_data)
{
	Af *a = user_data;
	GstBuffer *buf = GST_PAD_PROBE_INFO_BUFFER(info);
	if (!buf || a->state == AF_OFF)
		return GST_PAD_PROBE_OK;
	if ((a->frame_no++ % 3) == 0)
		af_check_tap(a);
	GstCaps *caps = gst_pad_get_current_caps(pad);
	if (!caps)
		return GST_PAD_PROBE_OK;
	GstVideoInfo vi;
	gboolean ok = gst_video_info_from_caps(&vi, caps);
	gst_caps_unref(caps);
	if (!ok || GST_VIDEO_INFO_FORMAT(&vi) != GST_VIDEO_FORMAT_BGRx)
		return GST_PAD_PROBE_OK;
	int w = GST_VIDEO_INFO_WIDTH(&vi), h = GST_VIDEO_INFO_HEIGHT(&vi);
	if (w >= 3000)	/* photo frames: the lens stays where it is */
		return GST_PAD_PROBE_OK;
	/* the lens is settling or the search waits for a frame: do not map every frame */
	if (a->settle > 1 && a->state == AF_SETTLING) {
		a->settle--;
		return GST_PAD_PROBE_OK;
	}
	GstMapInfo map;
	if (!gst_buffer_map(buf, &map, GST_MAP_READ))
		return GST_PAD_PROBE_OK;
	GstVideoMeta *vm = gst_buffer_get_video_meta(buf);
	int stride = vm ? vm->stride[0] : w * 4;
	if ((gsize)stride * h <= map.size) {
		double mean;
		double score = af_sharpness(a, map.data, stride, w, h, &mean);
		af_process(a, score, mean);
	}
	gst_buffer_unmap(buf, &map);
	return GST_PAD_PROBE_OK;
}

static void af_attach(GstPad *pad)
{
	Af *a = g_new0(Af, 1);
	a->roi_u = a->roi_v = -1;
	a->fd = af_open_lens();
	if (a->fd < 0) {
		g_free(a);
		return;
	}
	a->tap_path = g_build_filename(g_get_user_runtime_dir(), "m52xq-focus", NULL);
	unlink(a->tap_path);
	af_start(a);
	gst_pad_add_probe(pad, GST_PAD_PROBE_TYPE_BUFFER, af_probe, a, NULL);	/* the Af struct lives as long as the process */
}

typedef struct { GstBin parent; } M52xqCamSrc;
typedef struct { GstBinClass parent_class; } M52xqCamSrcClass;

G_DEFINE_TYPE(M52xqCamSrc, m52xq_cam_src, GST_TYPE_BIN)

static GstStaticPadTemplate src_template = GST_STATIC_PAD_TEMPLATE("src", GST_PAD_SRC, GST_PAD_ALWAYS, GST_STATIC_CAPS_ANY);

static void m52xq_cam_src_init(M52xqCamSrc *self)
{
	const char *which = g_getenv("M52XQ_CAMERA");
	GstElement *src = gst_element_factory_make("libcamerasrc", "libcamerasrc");
	if (!src) {
		g_warning("m52xqcamsrc: no libcamerasrc");
		return;
	}
	g_object_set(src, "camera-name", which && !strcmp(which, "front") ? FRONT_ID : REAR_ID, NULL);
	/* The software ISP gives the right colours only as XRGB8888 (GStreamer BGRx): for the photo sizes camerabin
	 * negotiated XBGR8888 and red / blue came out swapped (indoor light turned blue). Keep BGRx, converters after us
	 * do the rest. */
	GstElement *filter = gst_element_factory_make("capsfilter", "bgrx");
	GstCaps *caps = gst_caps_from_string("video/x-raw,format=BGRx");
	g_object_set(filter, "caps", caps, NULL);
	gst_caps_unref(caps);
	gst_bin_add_many(GST_BIN(self), src, filter, NULL);
	gst_element_link(src, filter);
	GstPad *target = gst_element_get_static_pad(filter, "src");
	if (!(which && !strcmp(which, "front")) && !g_getenv("M52XQ_NO_AF"))
		af_attach(target);
	GstPad *ghost = gst_ghost_pad_new_from_template("src", target, gst_static_pad_template_get(&src_template));
	gst_object_unref(target);
	gst_element_add_pad(GST_ELEMENT(self), ghost);
}

static void m52xq_cam_src_class_init(M52xqCamSrcClass *klass)
{
	GstElementClass *element_class = GST_ELEMENT_CLASS(klass);
	gst_element_class_add_static_pad_template(element_class, &src_template);
	gst_element_class_set_static_metadata(element_class, "M52XQ camera source", "Source/Video",
		"libcamerasrc with the camera from M52XQ_CAMERA (front/rear)", "m52xq");
}


/* ---- m52xqvenc: H.264 encoder element for camerabin/encodebin on the Venus hardware encoder (v4l2h264enc) ----
 * Venus on this phone works only with explicit settings: the defaults (profile High, level 1, no QP) kill the firmware ("VCODEC access
 * fault" / Err_Fatal, a reboot is needed). Proven settings (4K 28 fps from the camera, 1080p 95 fps, no firmware errors): profile
 * Baseline, level 5.1 and the fixed-QP mode (the rate control of Venus does not keep the bitrate): QP I/P from M52XQ_VENC_QP ("33,35",
 * about 40 Mbit/s in 4K). The module option m52xq_sec_persist=1 of venus_core (/etc/modprobe.d/m52xq-venus.conf) is required. The bin
 * converts any raw input to NV12 first. Registered with a high rank only when v4l2h264enc exists and M52XQ_NO_VENC is not set. */
typedef struct { GstBin parent; } M52xqVenc;
typedef struct { GstBinClass parent_class; } M52xqVencClass;
G_DEFINE_TYPE(M52xqVenc, m52xq_venc, GST_TYPE_BIN)

static GstStaticPadTemplate venc_sink_template = GST_STATIC_PAD_TEMPLATE("sink", GST_PAD_SINK, GST_PAD_ALWAYS, GST_STATIC_CAPS("video/x-raw"));
static GstStaticPadTemplate venc_src_template = GST_STATIC_PAD_TEMPLATE("src", GST_PAD_SRC, GST_PAD_ALWAYS, GST_STATIC_CAPS("video/x-h264"));

static void m52xq_venc_init(M52xqVenc *self)
{
	const char *qp = g_getenv("M52XQ_VENC_QP");
	int qi = 33, qpf = 35;
	if (qp)
		sscanf(qp, "%d,%d", &qi, &qpf);
	GstElement *conv = gst_element_factory_make("videoconvert", "venc-convert");
	GstElement *filter = gst_element_factory_make("capsfilter", "venc-nv12");
	GstElement *enc = gst_element_factory_make("v4l2h264enc", "venc-venus");
	if (!conv || !filter || !enc) {
		g_warning("m52xqvenc: videoconvert / capsfilter / v4l2h264enc missing");
		return;
	}
	GstCaps *caps = gst_caps_from_string("video/x-raw,format=NV12");
	g_object_set(filter, "caps", caps, NULL);
	gst_caps_unref(caps);
	char *ctl = g_strdup_printf("controls,h264_profile=0,h264_level=15,frame_level_rate_control_enable=0,"
		"h264_i_frame_qp_value=%d,h264_p_frame_qp_value=%d,h264_minimum_qp_value=%d,h264_maximum_qp_value=51", qi, qpf, qi);
	g_object_set(enc, "extra-controls", gst_structure_from_string(ctl, NULL), NULL);
	g_free(ctl);
	gst_bin_add_many(GST_BIN(self), conv, filter, enc, NULL);
	gst_element_link_many(conv, filter, enc, NULL);
	GstPad *sp = gst_element_get_static_pad(conv, "sink");
	GstPad *gs = gst_ghost_pad_new_from_template("sink", sp, gst_static_pad_template_get(&venc_sink_template));
	gst_object_unref(sp);
	gst_element_add_pad(GST_ELEMENT(self), gs);
	GstPad *tp = gst_element_get_static_pad(enc, "src");
	GstPad *gp = gst_ghost_pad_new_from_template("src", tp, gst_static_pad_template_get(&venc_src_template));
	gst_object_unref(tp);
	gst_element_add_pad(GST_ELEMENT(self), gp);
	g_message("m52xqvenc: Venus H.264, QP %d/%d", qi, qpf);
}

static void m52xq_venc_class_init(M52xqVencClass *klass)
{
	GstElementClass *ec = GST_ELEMENT_CLASS(klass);
	gst_element_class_add_static_pad_template(ec, &venc_sink_template);
	gst_element_class_add_static_pad_template(ec, &venc_src_template);
	gst_element_class_set_static_metadata(ec, "M52XQ Venus H.264 encoder", "Codec/Encoder/Video/Hardware",
		"H.264 on the Venus hardware encoder with the settings that work on this phone", "m52xq");
}

static gboolean plugin_init(GstPlugin *plugin)
{
	gboolean ok = gst_element_register(plugin, "m52xqcamsrc", GST_RANK_NONE, m52xq_cam_src_get_type());
	if (!g_getenv("M52XQ_NO_VENC") && access("/dev/video18", F_OK) == 0)
		ok &= gst_element_register(plugin, "m52xqvenc", GST_RANK_PRIMARY + 100, m52xq_venc_get_type());
	return ok;
}

#define PACKAGE "m52xqcamsrc"
GST_PLUGIN_DEFINE(GST_VERSION_MAJOR, GST_VERSION_MINOR, m52xqcamsrc, "M52XQ camera source", plugin_init, "1.0",
	"LGPL", PACKAGE, "https://postmarketos.org")
