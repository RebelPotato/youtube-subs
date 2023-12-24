# Youtube Subs

A simple script that pulls a video from youtube using [yt-dlp](https://github.com/yt-dlp/yt-dlp), transcripts it using [whisper.cpp](https://github.com/ggerganov/whisper.cpp), and outputs a subtitle file.

Warning: unstable. Read the code before you run it.

## Usage

Create a file named "config.json" in the same directory as the script with the following content:

```json
{
    "output": "/home/anon/output",
    "whisper": "/home/anon/whisper.cpp"
}
```

Then run

```shell
deno task start [URL]
```

Replace `[URL]` with the URL of the video you want to download.

## Configuration

The script can be configured using a `config.json` file.

### `output`

The path to the directory where the output should be saved.

### `whisper`

The path to the `whisper.cpp` executable.