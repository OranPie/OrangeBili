#ifndef WATCH_DECODE_CORE_H
#define WATCH_DECODE_CORE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void *wdc_decoder_ref;

typedef struct wdc_frame {
    int width;
    int height;
    int bytes_per_row;
    uint8_t *rgba;
} wdc_frame;

// Open a decoder context for a local or remote URL.
wdc_decoder_ref wdc_decoder_open(const char *url_utf8);
wdc_decoder_ref wdc_decoder_open_with_options(
    const char *url_utf8,
    const char *user_agent_utf8,
    const char *referer_utf8,
    const char *cookie_utf8
);
wdc_decoder_ref wdc_decoder_open_with_headers(
    const char *url_utf8,
    const char *headers_blob_utf8
);

// Decode one frame at or after time_seconds, scaled to output size.
// Returns NULL if decode is unavailable at the requested time.
wdc_frame *wdc_decoder_decode_at_time(
    wdc_decoder_ref decoder,
    double time_seconds,
    int output_width,
    int output_height
);
wdc_frame *wdc_decoder_decode_next(
    wdc_decoder_ref decoder,
    int output_width,
    int output_height
);
wdc_frame *wdc_decoder_decode_until(
    wdc_decoder_ref decoder,
    double time_seconds,
    int output_width,
    int output_height
);
int wdc_decoder_seek_seconds(wdc_decoder_ref decoder, double time_seconds);
int wdc_decoder_get_last_error_code(wdc_decoder_ref decoder);
const char *wdc_decoder_get_last_error_message(wdc_decoder_ref decoder);

void wdc_decoder_close(wdc_decoder_ref decoder);

void wdc_free_frame(wdc_frame *frame);

#ifdef __cplusplus
}
#endif

#endif
