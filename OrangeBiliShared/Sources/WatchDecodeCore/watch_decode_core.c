#include "watch_decode_core.h"

#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/avutil.h>
#include <libavutil/imgutils.h>
#include <libswscale/swscale.h>

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct wdc_decoder {
    AVFormatContext *format;
    AVCodecContext *codec;
    AVStream *video_stream;
    int video_stream_index;

    AVPacket *packet;
    AVFrame *frame;

    struct SwsContext *sws;
    enum AVPixelFormat sws_src_format;
    int sws_src_width;
    int sws_src_height;
    int sws_dst_width;
    int sws_dst_height;

    double last_time_seconds;
    int has_last_time;
    double stream_start_seconds;
    int has_stream_start;
    int last_error_code;
    char last_error_message[160];
};
typedef struct wdc_decoder wdc_decoder;

wdc_frame *wdc_decoder_decode_until(
    wdc_decoder_ref decoder_ref,
    double time_seconds,
    int output_width,
    int output_height
);

static int g_network_inited = 0;

static void wdc_apply_network_options(AVDictionary **opts) {
    if (!opts) return;
    // Real-device watch networks can be bursty; tune for reconnect resilience
    // while keeping startup reasonably fast.
    av_dict_set(opts, "reconnect", "1", 0);
    av_dict_set(opts, "reconnect_streamed", "1", 0);
    av_dict_set(opts, "reconnect_at_eof", "1", 0);
    av_dict_set(opts, "reconnect_on_http_error", "4xx,5xx", 0);
    av_dict_set(opts, "reconnect_delay_max", "3", 0);
    av_dict_set(opts, "rw_timeout", "12000000", 0); // 12s in microseconds
    av_dict_set(opts, "http_persistent", "1", 0);
    av_dict_set(opts, "multiple_requests", "1", 0);
    av_dict_set(opts, "tcp_nodelay", "1", 0);
    av_dict_set(opts, "probesize", "1048576", 0);
    av_dict_set(opts, "analyzeduration", "1000000", 0);
}

static void wdc_set_error(wdc_decoder *decoder, int code, const char *message) {
    if (!decoder) return;
    decoder->last_error_code = code;
    if (!message || !message[0]) {
        decoder->last_error_message[0] = '\0';
        return;
    }
    snprintf(decoder->last_error_message, sizeof(decoder->last_error_message), "%s", message);
}

static void wdc_set_error_ret(wdc_decoder *decoder, int code, const char *prefix) {
    if (!decoder) return;
    decoder->last_error_code = code;
    char errbuf[96] = {0};
    av_strerror(code, errbuf, sizeof(errbuf));
    if (prefix && prefix[0]) {
        snprintf(
            decoder->last_error_message,
            sizeof(decoder->last_error_message),
            "%s: %s",
            prefix,
            errbuf
        );
    } else {
        snprintf(decoder->last_error_message, sizeof(decoder->last_error_message), "%s", errbuf);
    }
}

static wdc_frame *wdc_alloc_frame(int width, int height) {
    if (width <= 0 || height <= 0) return NULL;

    wdc_frame *frame = (wdc_frame *)calloc(1, sizeof(wdc_frame));
    if (!frame) return NULL;

    frame->width = width;
    frame->height = height;
    frame->bytes_per_row = width * 4;

    size_t size = (size_t)frame->bytes_per_row * (size_t)height;
    frame->rgba = (uint8_t *)malloc(size);
    if (!frame->rgba) {
        free(frame);
        return NULL;
    }

    return frame;
}

static int wdc_seek_to_time(wdc_decoder *decoder, double time_seconds) {
    if (!decoder || !decoder->video_stream) return -1;

    if (time_seconds < 0) time_seconds = 0;

    int64_t ts = av_rescale_q(
        (int64_t)llround(time_seconds * AV_TIME_BASE),
        AV_TIME_BASE_Q,
        decoder->video_stream->time_base
    );

    int ret = av_seek_frame(decoder->format, decoder->video_stream_index, ts, AVSEEK_FLAG_BACKWARD);
    if (ret < 0) return ret;

    avcodec_flush_buffers(decoder->codec);
    return 0;
}

static double wdc_normalized_frame_time(wdc_decoder *decoder, int64_t pts, AVRational time_base) {
    double frame_time = pts * av_q2d(time_base);
    if (decoder && decoder->has_stream_start) {
        frame_time -= decoder->stream_start_seconds;
    }
    if (!isfinite(frame_time) || frame_time < 0) return 0;
    return frame_time;
}

static int wdc_ensure_sws(
    wdc_decoder *decoder,
    enum AVPixelFormat src_fmt,
    int src_w,
    int src_h,
    int dst_w,
    int dst_h
) {
    if (!decoder) return -1;

    if (decoder->sws &&
        decoder->sws_src_format == src_fmt &&
        decoder->sws_src_width == src_w &&
        decoder->sws_src_height == src_h &&
        decoder->sws_dst_width == dst_w &&
        decoder->sws_dst_height == dst_h) {
        return 0;
    }

    if (decoder->sws) {
        sws_freeContext(decoder->sws);
        decoder->sws = NULL;
    }

    decoder->sws = sws_getContext(
        src_w,
        src_h,
        src_fmt,
        dst_w,
        dst_h,
        AV_PIX_FMT_RGBA,
        SWS_FAST_BILINEAR,
        NULL,
        NULL,
        NULL
    );
    if (!decoder->sws) return -1;

    decoder->sws_src_format = src_fmt;
    decoder->sws_src_width = src_w;
    decoder->sws_src_height = src_h;
    decoder->sws_dst_width = dst_w;
    decoder->sws_dst_height = dst_h;
    return 0;
}

static wdc_frame *wdc_make_output_frame(
    wdc_decoder *decoder,
    AVFrame *src_frame,
    int output_width,
    int output_height
) {
    if (!decoder || !src_frame) return NULL;
    if (wdc_ensure_sws(
            decoder,
            decoder->codec->pix_fmt,
            decoder->codec->width,
            decoder->codec->height,
            output_width,
            output_height
        ) < 0) {
        wdc_set_error(decoder, -1, "sws init failed");
        return NULL;
    }

    wdc_frame *out = wdc_alloc_frame(output_width, output_height);
    if (!out) {
        wdc_set_error(decoder, -1, "alloc frame failed");
        return NULL;
    }

    uint8_t *dst_data[4] = {0};
    int dst_linesize[4] = {0};
    int ok = av_image_fill_arrays(
        dst_data,
        dst_linesize,
        out->rgba,
        AV_PIX_FMT_RGBA,
        out->width,
        out->height,
        1
    );
    if (ok < 0) {
        wdc_set_error_ret(decoder, ok, "fill arrays failed");
        wdc_free_frame(out);
        return NULL;
    }

    sws_scale(
        decoder->sws,
        (const uint8_t *const *)src_frame->data,
        src_frame->linesize,
        0,
        decoder->codec->height,
        dst_data,
        dst_linesize
    );
    return out;
}

wdc_decoder_ref wdc_decoder_open_with_options(
    const char *url_utf8,
    const char *user_agent_utf8,
    const char *referer_utf8,
    const char *cookie_utf8
) {
    if (!url_utf8 || !url_utf8[0]) return NULL;

    if (!g_network_inited) {
        avformat_network_init();
        g_network_inited = 1;
    }

    wdc_decoder *decoder = (wdc_decoder *)calloc(1, sizeof(wdc_decoder));
    if (!decoder) return NULL;
    wdc_set_error(decoder, 0, "");

    AVDictionary *opts = NULL;
    if (user_agent_utf8 && user_agent_utf8[0]) {
        av_dict_set(&opts, "user_agent", user_agent_utf8, 0);
    }
    if (referer_utf8 && referer_utf8[0]) {
        av_dict_set(&opts, "referer", referer_utf8, 0);
    }
    if (cookie_utf8 && cookie_utf8[0]) {
        av_dict_set(&opts, "cookies", cookie_utf8, 0);
    }
    wdc_apply_network_options(&opts);

    if (avformat_open_input(&decoder->format, url_utf8, NULL, &opts) < 0) {
        av_dict_free(&opts);
        wdc_decoder_close(decoder);
        return NULL;
    }
    av_dict_free(&opts);

    if (avformat_find_stream_info(decoder->format, NULL) < 0) {
        wdc_decoder_close(decoder);
        return NULL;
    }

    decoder->video_stream_index = av_find_best_stream(
        decoder->format,
        AVMEDIA_TYPE_VIDEO,
        -1,
        -1,
        NULL,
        0
    );
    if (decoder->video_stream_index < 0) {
        wdc_decoder_close(decoder);
        return NULL;
    }

    decoder->video_stream = decoder->format->streams[decoder->video_stream_index];
    if (decoder->video_stream->start_time != AV_NOPTS_VALUE) {
        decoder->stream_start_seconds = decoder->video_stream->start_time * av_q2d(decoder->video_stream->time_base);
        decoder->has_stream_start = 1;
    } else if (decoder->format->start_time != AV_NOPTS_VALUE) {
        decoder->stream_start_seconds = decoder->format->start_time / (double)AV_TIME_BASE;
        decoder->has_stream_start = 1;
    } else {
        decoder->stream_start_seconds = 0;
        decoder->has_stream_start = 0;
    }
    AVCodecParameters *params = decoder->video_stream->codecpar;
    const AVCodec *codec = avcodec_find_decoder(params->codec_id);
    if (!codec) {
        wdc_decoder_close(decoder);
        return NULL;
    }

    decoder->codec = avcodec_alloc_context3(codec);
    if (!decoder->codec) {
        wdc_decoder_close(decoder);
        return NULL;
    }

    if (avcodec_parameters_to_context(decoder->codec, params) < 0) {
        wdc_decoder_close(decoder);
        return NULL;
    }

    decoder->codec->thread_count = 1;

    if (avcodec_open2(decoder->codec, codec, NULL) < 0) {
        wdc_decoder_close(decoder);
        return NULL;
    }

    decoder->packet = av_packet_alloc();
    decoder->frame = av_frame_alloc();
    if (!decoder->packet || !decoder->frame) {
        wdc_decoder_close(decoder);
        return NULL;
    }

    decoder->last_time_seconds = 0;
    decoder->has_last_time = 0;

    return (wdc_decoder_ref)decoder;
}

wdc_decoder_ref wdc_decoder_open(const char *url_utf8) {
    return wdc_decoder_open_with_options(url_utf8, NULL, NULL, NULL);
}

wdc_decoder_ref wdc_decoder_open_with_headers(
    const char *url_utf8,
    const char *headers_blob_utf8
) {
    if (!url_utf8 || !url_utf8[0]) return NULL;

    if (!g_network_inited) {
        avformat_network_init();
        g_network_inited = 1;
    }

    wdc_decoder *decoder = (wdc_decoder *)calloc(1, sizeof(wdc_decoder));
    if (!decoder) return NULL;
    wdc_set_error(decoder, 0, "");

    AVDictionary *opts = NULL;
    if (headers_blob_utf8 && headers_blob_utf8[0]) {
        av_dict_set(&opts, "headers", headers_blob_utf8, 0);
    }
    wdc_apply_network_options(&opts);

    if (avformat_open_input(&decoder->format, url_utf8, NULL, &opts) < 0) {
        av_dict_free(&opts);
        wdc_decoder_close(decoder);
        return NULL;
    }
    av_dict_free(&opts);

    if (avformat_find_stream_info(decoder->format, NULL) < 0) {
        wdc_decoder_close(decoder);
        return NULL;
    }

    decoder->video_stream_index = av_find_best_stream(
        decoder->format,
        AVMEDIA_TYPE_VIDEO,
        -1,
        -1,
        NULL,
        0
    );
    if (decoder->video_stream_index < 0) {
        wdc_decoder_close(decoder);
        return NULL;
    }

    decoder->video_stream = decoder->format->streams[decoder->video_stream_index];
    if (decoder->video_stream->start_time != AV_NOPTS_VALUE) {
        decoder->stream_start_seconds = decoder->video_stream->start_time * av_q2d(decoder->video_stream->time_base);
        decoder->has_stream_start = 1;
    } else if (decoder->format->start_time != AV_NOPTS_VALUE) {
        decoder->stream_start_seconds = decoder->format->start_time / (double)AV_TIME_BASE;
        decoder->has_stream_start = 1;
    } else {
        decoder->stream_start_seconds = 0;
        decoder->has_stream_start = 0;
    }

    AVCodecParameters *params = decoder->video_stream->codecpar;
    const AVCodec *codec = avcodec_find_decoder(params->codec_id);
    if (!codec) {
        wdc_decoder_close(decoder);
        return NULL;
    }

    decoder->codec = avcodec_alloc_context3(codec);
    if (!decoder->codec) {
        wdc_decoder_close(decoder);
        return NULL;
    }

    if (avcodec_parameters_to_context(decoder->codec, params) < 0) {
        wdc_decoder_close(decoder);
        return NULL;
    }

    decoder->codec->thread_count = 1;

    if (avcodec_open2(decoder->codec, codec, NULL) < 0) {
        wdc_decoder_close(decoder);
        return NULL;
    }

    decoder->packet = av_packet_alloc();
    decoder->frame = av_frame_alloc();
    if (!decoder->packet || !decoder->frame) {
        wdc_decoder_close(decoder);
        return NULL;
    }

    decoder->last_time_seconds = 0;
    decoder->has_last_time = 0;
    return (wdc_decoder_ref)decoder;
}

wdc_frame *wdc_decoder_decode_at_time(
    wdc_decoder_ref decoder_ref,
    double time_seconds,
    int output_width,
    int output_height
) {
    return wdc_decoder_decode_until(decoder_ref, time_seconds, output_width, output_height);
}

wdc_frame *wdc_decoder_decode_next(
    wdc_decoder_ref decoder_ref,
    int output_width,
    int output_height
) {
    wdc_decoder *decoder = (wdc_decoder *)decoder_ref;
    if (!decoder || !decoder->codec || !decoder->video_stream) return NULL;
    if (output_width <= 0 || output_height <= 0) return NULL;
    wdc_set_error(decoder, 0, "");

    for (;;) {
        int read_ret = av_read_frame(decoder->format, decoder->packet);
        if (read_ret < 0) {
            if (read_ret == AVERROR_EOF) {
                wdc_set_error_ret(decoder, read_ret, "read frame");
            }
            if (read_ret != AVERROR_EOF) {
                wdc_set_error_ret(decoder, read_ret, "read frame");
            }
            return NULL;
        }

        if (decoder->packet->stream_index != decoder->video_stream_index) {
            av_packet_unref(decoder->packet);
            continue;
        }

        int send_ret = avcodec_send_packet(decoder->codec, decoder->packet);
        av_packet_unref(decoder->packet);
        if (send_ret < 0) {
            wdc_set_error_ret(decoder, send_ret, "send packet");
            continue;
        }

        for (;;) {
            int recv_ret = avcodec_receive_frame(decoder->codec, decoder->frame);
            if (recv_ret == AVERROR(EAGAIN)) {
                break;
            }
            if (recv_ret < 0) {
                wdc_set_error_ret(decoder, recv_ret, "receive frame");
                break;
            }

            int64_t pts = decoder->frame->best_effort_timestamp;
            if (pts == AV_NOPTS_VALUE) pts = decoder->frame->pts;
            if (pts == AV_NOPTS_VALUE) {
                av_frame_unref(decoder->frame);
                continue;
            }

            double frame_time = wdc_normalized_frame_time(decoder, pts, decoder->video_stream->time_base);
            wdc_frame *out = wdc_make_output_frame(decoder, decoder->frame, output_width, output_height);
            av_frame_unref(decoder->frame);
            if (!out) return NULL;
            decoder->has_last_time = 1;
            decoder->last_time_seconds = frame_time;
            return out;
        }
    }
}

wdc_frame *wdc_decoder_decode_until(
    wdc_decoder_ref decoder_ref,
    double time_seconds,
    int output_width,
    int output_height
) {
    wdc_decoder *decoder = (wdc_decoder *)decoder_ref;
    if (!decoder || !decoder->codec || !decoder->video_stream) return NULL;
    if (output_width <= 0 || output_height <= 0) return NULL;
    if (!isfinite(time_seconds) || time_seconds < 0) time_seconds = 0;
    wdc_set_error(decoder, 0, "");

    const double seek_gap_seconds = 2.0;
    if (!decoder->has_last_time ||
        time_seconds + 0.2 < decoder->last_time_seconds ||
        time_seconds - decoder->last_time_seconds > seek_gap_seconds) {
        int seek_ret = wdc_seek_to_time(decoder, time_seconds);
        if (seek_ret < 0) {
            wdc_set_error_ret(decoder, seek_ret, "seek");
            return NULL;
        }
    }

    const double epsilon = 0.004;
    for (;;) {
        wdc_frame *out = wdc_decoder_decode_next(decoder, output_width, output_height);
        if (!out) return NULL;
        if (decoder->last_time_seconds + epsilon >= time_seconds) {
            return out;
        }
        wdc_free_frame(out);
    }
}

int wdc_decoder_seek_seconds(wdc_decoder_ref decoder_ref, double time_seconds) {
    wdc_decoder *decoder = (wdc_decoder *)decoder_ref;
    if (!decoder) return -1;
    int ret = wdc_seek_to_time(decoder, time_seconds);
    if (ret < 0) {
        wdc_set_error_ret(decoder, ret, "seek");
    } else {
        decoder->has_last_time = 0;
        decoder->last_time_seconds = 0;
        wdc_set_error(decoder, 0, "");
    }
    return ret;
}

int wdc_decoder_get_last_error_code(wdc_decoder_ref decoder_ref) {
    wdc_decoder *decoder = (wdc_decoder *)decoder_ref;
    if (!decoder) return -1;
    return decoder->last_error_code;
}

const char *wdc_decoder_get_last_error_message(wdc_decoder_ref decoder_ref) {
    wdc_decoder *decoder = (wdc_decoder *)decoder_ref;
    if (!decoder) return "";
    return decoder->last_error_message;
}

void wdc_decoder_close(wdc_decoder_ref decoder_ref) {
    wdc_decoder *decoder = (wdc_decoder *)decoder_ref;
    if (!decoder) return;

    if (decoder->sws) sws_freeContext(decoder->sws);
    if (decoder->frame) av_frame_free(&decoder->frame);
    if (decoder->packet) av_packet_free(&decoder->packet);
    if (decoder->codec) avcodec_free_context(&decoder->codec);
    if (decoder->format) avformat_close_input(&decoder->format);

    free(decoder);
}

void wdc_free_frame(wdc_frame *frame) {
    if (!frame) return;
    if (frame->rgba) free(frame->rgba);
    free(frame);
}
