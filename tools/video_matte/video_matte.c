// Removes the flat off-white background (and the floor grid and soft shadow)
// from a video frame: the background is flood-filled from the frame edges
// through pixels near the background colour, so it stops at the character's
// dark outlines and never eats white socks, soles or shirt stripes inside them.
//
// A second fill takes in the soft floor shadow (greyish, below floor_y), and
// enclosed pockets of background are cleared too: slivers between a stray
// strand of hair and the head, and the gap between the legs.
//
// Reads raw RGB24 frames until the end of input and writes RGBA frames, so it
// sits between two ffmpeg pipes (see tools/extract_stella_video.sh):
//
//   video_matte W H [fill_t] [min_area] [floor_y] < frames.rgb > frames.rgba
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int W, H;
static unsigned char *rgb;
static float br, bgc, bb;

static int dist(int i) {
	int dr = abs(rgb[i * 3] - (int)br), dg = abs(rgb[i * 3 + 1] - (int)bgc), db = abs(rgb[i * 3 + 2] - (int)bb);
	int m = dr > dg ? dr : dg;
	return m > db ? m : db;
}

static int fill_t, min_area, floor_y;
// VIDEO_MATTE_DEBUG=1: removed pockets are painted magenta instead of cleared.
static int debug;
static void matte_frame(FILE *out);

int main(int argc, char **argv) {
	if (argc < 3) {
		fprintf(stderr, "usage: video_matte W H [fill_t] [min_area] [floor_y]\n");
		return 2;
	}
	W = atoi(argv[1]);
	H = atoi(argv[2]);
	fill_t = argc > 3 ? atoi(argv[3]) : 36;
	min_area = argc > 4 ? atoi(argv[4]) : 400;
	floor_y = argc > 5 ? atoi(argv[5]) : H * 80 / 100;
	debug = getenv("VIDEO_MATTE_DEBUG") != NULL;
	size_t size = (size_t)W * H * 3;
	rgb = malloc(size);
	int frames = 0;
	while (fread(rgb, 1, size, stdin) == size) {
		matte_frame(stdout);
		frames++;
	}
	fprintf(stderr, "video_matte: %d frames\n", frames);
	return frames > 0 ? 0 : 1;
}

static void matte_frame(FILE *out_file) {
	int n = W * H;

	// Background colour: average of the top rows (always clear of the figure).
	double s[3] = {0};
	for (int i = 0; i < W * 8; i++) for (int c = 0; c < 3; c++) s[c] += rgb[i * 3 + c];
	br = s[0] / (W * 8); bgc = s[1] / (W * 8); bb = s[2] / (W * 8);

	unsigned char *bgm = calloc(n, 1); // 1 = background
	int *q = malloc(n * sizeof(int));
	int qh = 0, qt = 0;
	for (int x = 0; x < W; x++) for (int y = 0; y < H; y += H - 1) {
		int i = y * W + x;
		if (!bgm[i] && dist(i) < fill_t) { bgm[i] = 1; q[qt++] = i; }
	}
	for (int y = 0; y < H; y++) for (int x = 0; x < W; x += W - 1) {
		int i = y * W + x;
		if (!bgm[i] && dist(i) < fill_t) { bgm[i] = 1; q[qt++] = i; }
	}
	while (qh < qt) {
		int i = q[qh++], x = i % W, y = i / W;
		int nb[4] = {x > 0 ? i - 1 : -1, x < W - 1 ? i + 1 : -1, y > 0 ? i - W : -1, y < H - 1 ? i + W : -1};
		for (int k = 0; k < 4; k++) {
			int j = nb[k];
			if (j >= 0 && !bgm[j] && dist(j) < fill_t) { bgm[j] = 1; q[qt++] = j; }
		}
	}

	// The floor shadow: greyish, a little darker than the floor, below floor_y.
	qh = 0;
	for (int i = 0; i < n; i++) if (bgm[i] && i / W >= floor_y - 1) q[qh++] = i;
	qt = qh; qh = 0;
	while (qh < qt) {
		int i = q[qh++], x = i % W, y = i / W;
		int nb[4] = {x > 0 ? i - 1 : -1, x < W - 1 ? i + 1 : -1, y > 0 ? i - W : -1, y < H - 1 ? i + W : -1};
		for (int k = 0; k < 4; k++) {
			int j = nb[k];
			if (j < 0 || bgm[j] || j / W < floor_y) continue;
			int r = rgb[j * 3], g = rgb[j * 3 + 1], b = rgb[j * 3 + 2];
			int mx = r > g ? (r > b ? r : b) : (g > b ? g : b), mn = r < g ? (r < b ? r : b) : (g < b ? g : b);
			if (dist(j) < 75 && mx - mn < 36) { bgm[j] = 1; q[qt++] = j; }
		}
	}

	// Enclosed pockets of background colour: the gap between the legs, under an
	// arm, between a stray strand of hair and the head. Her own white parts (socks,
	// soles, laces, eye whites, shirt stripes, Lemon's pale fur) are shaded, so on
	// average further from the background colour, and the socks and soles touch her
	// red shoes or sit on the floor; the shirt's white stripes are edged by yellow.
	// Stripes are also thin. A pocket that's not thin or mostly edged by yellow goes
	// if it is:
	//   - nearly exactly the background colour (the gap between the legs);
	//   - large, close to it, clear of the shoes and not down among the soles
	//     unless very large (under an arm, between Stella and Lemon); socks touch
	//     the outside, so a pocket deep inside may be a little further off;
	//   - (thin or not) round her head, near the outside, not edged by skin: the
	//     pale rim the video draws round her hair, and slivers inside stray
	//     strands (eye whites are edged by skin; Lemon's fur is further off).
	unsigned char *near = calloc(n, 1); // within NEAR px of the outside background
	const int NEAR = 8;
	const int POCKET_T = 24; // light greys too: the soft edge of a line
	qh = qt = 0;
	for (int i = 0; i < n; i++) if (bgm[i]) { near[i] = 1; q[qt++] = i; }
	for (int step = 0; step < NEAR; step++) {
		int end = qt;
		while (qh < end) {
			int i = q[qh++], x = i % W, y = i / W;
			int nb[4] = {x > 0 ? i - 1 : -1, x < W - 1 ? i + 1 : -1, y > 0 ? i - W : -1, y < H - 1 ? i + W : -1};
			for (int k = 0; k < 4; k++) if (nb[k] >= 0 && !near[nb[k]]) { near[nb[k]] = 1; q[qt++] = nb[k]; }
		}
	}
	unsigned char *seen = calloc(n, 1);
	for (int i0 = 0; i0 < n; i0++) {
		if (bgm[i0] || seen[i0] || dist(i0) >= POCKET_T) continue;
		qh = qt = 0; q[qt++] = i0; seen[i0] = 1;
		int border = 0, yellow = 0, skin = 0, touches_outside = 0, touches_shoe = 0;
		int x0 = W, y0 = H, x1 = 0, y1 = 0;
		double mean = 0.0;
		while (qh < qt) {
			int i = q[qh++], x = i % W, y = i / W;
			if (near[i]) touches_outside = 1;
			if (x < x0) x0 = x;
			if (x > x1) x1 = x;
			if (y < y0) y0 = y;
			if (y > y1) y1 = y;
			mean += dist(i);
			int nb[4] = {x > 0 ? i - 1 : -1, x < W - 1 ? i + 1 : -1, y > 0 ? i - W : -1, y < H - 1 ? i + W : -1};
			for (int k = 0; k < 4; k++) {
				int j = nb[k];
				if (j < 0 || bgm[j] || seen[j]) continue;
				if (dist(j) < POCKET_T) { seen[j] = 1; q[qt++] = j; continue; }
				int r = rgb[j * 3], g = rgb[j * 3 + 1], b = rgb[j * 3 + 2];
				border++;
				if (r > 220 && g > 150 && g < 215 && b > 110 && b < 195 && r - g > 25) skin++;
				if (r > 140 && r - g > 60 && r - b > 60) touches_shoe = 1;
				if (r > 200 && g > 150 && r - b > 80) yellow++;
			}
		}
		mean /= qt;
		int thin = y1 - y0 < 11 || x1 - x0 < 5;
		int legs_gap = qt >= 100 && mean <= 5.0;
		int under_arm = qt >= 400 && !touches_shoe && (mean <= 8.5 || (mean <= 10.0 && !touches_outside))
				&& (y1 < H * 93 / 100 || qt >= 1000);
		int hair = qt >= 10 && y1 < H * 45 / 100 && touches_outside && mean <= 16.0 && skin * 10 < border * 3;
		if ((((legs_gap || under_arm) && !thin) || hair) && yellow * 2 < border)
			for (int k = 0; k < qt; k++) bgm[q[k]] = debug ? 2 : 1;
	}

	// Drop small leftover specks (compression noise, grid bits).
	int *comp = calloc(n, sizeof(int));
	int label = 0;
	for (int i0 = 0; i0 < n; i0++) {
		if (bgm[i0] || comp[i0]) continue;
		label++;
		qh = qt = 0; q[qt++] = i0; comp[i0] = label;
		while (qh < qt) {
			int i = q[qh++], x = i % W, y = i / W;
			for (int dy = -1; dy <= 1; dy++) for (int dx = -1; dx <= 1; dx++) {
				int xx = x + dx, yy = y + dy;
				if (xx < 0 || yy < 0 || xx >= W || yy >= H) continue;
				int j = yy * W + xx;
				if (!bgm[j] && !comp[j]) { comp[j] = label; q[qt++] = j; }
			}
		}
		if (qt < min_area) for (int k = 0; k < qt; k++) bgm[q[k]] = 1;
	}

	// Alpha: solid inside; on the edge (next to background) by how far the pixel
	// is from the background colour, with the background unmixed from its colour.
	unsigned char *out = malloc(n * 4);
	for (int i = 0; i < n; i++) {
		int x = i % W, y = i / W;
		if (bgm[i] == 2) { // A removed pocket, in debug mode.
			out[i * 4] = 255; out[i * 4 + 1] = 0; out[i * 4 + 2] = 255; out[i * 4 + 3] = 255;
			continue;
		}
		float a = 1.0f;
		if (bgm[i]) a = 0.0f;
		else {
			int edge = 0;
			for (int dy = -1; dy <= 1 && !edge; dy++) for (int dx = -1; dx <= 1; dx++) {
				int xx = x + dx, yy = y + dy;
				if (xx < 0 || yy < 0 || xx >= W || yy >= H || bgm[yy * W + xx]) { edge = 1; break; }
			}
			if (edge) {
				a = (dist(i) - 25) / 75.0f;
				if (a < 0.15f) a = 0.15f;
				if (a > 1.0f) a = 1.0f;
			}
		}
		float bgcol[3] = {br, bgc, bb};
		for (int c = 0; c < 3; c++) {
			float v = rgb[i * 3 + c];
			if (a > 0.0f && a < 1.0f) v = (v - (1.0f - a) * bgcol[c]) / a;
			if (v < 0) v = 0;
			if (v > 255) v = 255;
			out[i * 4 + c] = a > 0.0f ? (unsigned char)v : 0;
		}
		out[i * 4 + 3] = (unsigned char)(a * 255.0f + 0.5f);
	}
	fwrite(out, 1, (size_t)n * 4, out_file);
	free(bgm); free(q); free(near); free(seen); free(comp); free(out);
}
