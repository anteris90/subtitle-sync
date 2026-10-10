# Subtitle Sync

English | [Magyar](README.md)

A local Windows tool for synchronizing `.srt` subtitles and extracting subtitle tracks from MKV files. Your files are processed on your computer and are never uploaded.

## Run

Double-click `Inditas.bat`. The app opens in your default browser. Keep the local server window open while using the app; closing it stops the server.

Opening `index.html` directly supports basic SRT timing controls, but MKV extraction and local sync features require `Inditas.bat`.

## Extract subtitles from MKV

MKV extraction requires the free [MKVToolNix](https://mkvtoolnix.download/). Use **Install MKVToolNix automatically** or choose `mkvmerge.exe` with **Set MKVToolNix location**. The app also uses `mkvextract.exe` from the same folder and saves the tool location locally.

1. Click **Choose MKV** and select a video.
2. For a subtitle track, choose **Load as reference**, **Load as target**, or **Download SRT**. Downloading does not load or modify either subtitle.
3. Image-based tracks such as PGS/VobSub and ASS/SSA tracks may need to be converted to SRT separately before syncing.

## Reference-based AI sync

1. Load a correctly timed reference subtitle, such as English, in the **Reference subtitle** field.
2. Load the subtitle to correct, such as Hungarian, in **Subtitle to correct**.
3. On first use, click **Install local text model**. The app installs the Python packages and downloads the multilingual model (about 471 MB). This is a one-time download; alignment runs locally afterward.
4. Click **AI re-sync to reference**. The multilingual model matches the meaning of subtitle lines across languages and handles different cue segmentation. It updates the target preview and leaves the reference unchanged.
5. If there are too few confident text matches, try **Speech-pattern fallback**.
6. Review the beginning, middle, and end of the preview, then click **Save corrected SRT**.

The local model is `paraphrase-multilingual-MiniLM-L12-v2`. Subtitle text is not sent to an online service.

## Other sync options

**Video audio auto-sync** uses local `ffsubsync` and FFmpeg to align a subtitle to speech and silence in the selected MKV. Click **Install sync engine automatically** to install them, or configure `ffsubsync.exe` with **Set ffsubsync location**.

For manual adjustments, use **Global offset** or **Gradual timing correction**. Positive offsets move the target later; negative offsets move it earlier. The gradual correction uses two matching scene times as anchors.

## Notes

Different video releases can contain different recaps, edits, or scene timing. Cue numbers in the reference and target are independent and do not necessarily refer to the same scene. Always review the result before exporting.

Time values can be entered as `HH:MM:SS,mmm` or as seconds, for example `312.5`.