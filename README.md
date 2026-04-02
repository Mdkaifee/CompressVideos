# TestVideos

Drop raw challenge videos into `input/` and run:

```bash
./compress_videos.sh
```

Optimized files will be written to `output/`.

What the script does:
- converts videos to H.264 MP4
- keeps good visual quality with `CRF 22`
- caps resolution at `1280px` wide
- adds `+faststart` so playback begins sooner after upload
- prints before/after size and bitrate details

Supported input formats:
- `.mp4`
- `.mov`
- `.m4v`
- `.webm`

If you want custom folders, run:

```bash
./compress_videos.sh /path/to/input /path/to/output
```
# CompressVideos
