import { assert } from "https://deno.land/std@0.210.0/assert/assert.ts";
import { parseArgs } from "https://deno.land/std@0.210.0/cli/mod.ts";
import { join } from "https://deno.land/std@0.210.0/path/mod.ts";

type Config = {
  output: string;
  whisper: string;
};
async function parseConfig(raw: string): Promise<Config> {
  const b = JSON.parse(raw);
  assert(
    b.output != undefined && b.whisper != undefined,
    "Config file must contain output and whisper directories",
  );
  return {
    output: await Deno.realPath(b.output),
    whisper: await Deno.realPath(b.whisper),
  };
}
const config: Config = await parseConfig(
  Deno.readTextFileSync("./config.json"),
);

function outputPath(file: string): string {
  return join(config.output, file);
}

function whisperPath(file: string): string {
  return join(config.whisper, file);
}

function ydlOption(url: string): string[] {
  return [
    `-o`,
    `${outputPath("%(title)s.%(ext)s")}`,
    `--write-thumbnail`,
    `${url}`,
  ];
}

function videoPath(): string {
  console.log(config.output + "/");
  for (const file of Deno.readDirSync(config.output + "/")) {
    console.log(file.name);
    if (file.isFile && file.name.match(/(\.mp4|\.webm)$/)) {
      return outputPath(file.name);
    }
  }
  throw ("No supported video found.");
}

function ffmpegCommand(file: string): string[] {
  return [
    `-i`,
    `${file}`,
    `-ar`,
    "16000",
    `-ac`,
    "1",
    `-c:a`,
    `pcm_s16le`,
    `${outputPath("output.wav")}`,
  ];
}

function whisperCommand(): string[] {
  return [
    `-m`,
    `${whisperPath("models/ggml-large-v3-q5_0.bin")}`,
    `--output-srt`,
    `${outputPath("output.wav")}`,
  ];
}

async function runit(process: Deno.Command) {
  const child = process.spawn();
  const status = await child.status;
  assert(status.success);
}

async function makeSubs(url: string) {
  const ydl = new Deno.Command("yt-dlp", { args: ydlOption(url) });
  await runit(ydl);
  const ffmpeg = new Deno.Command("ffmpeg", {
    args: ffmpegCommand(videoPath()),
  });
  await runit(ffmpeg);
  const whisper = new Deno.Command(whisperPath("main"), {
    args: whisperCommand(),
  });
  await runit(whisper);
}

type Options = {
  _: string[];
};
function parseOptions(argv: { _: string[] }): Options {
  assert(argv._.length != 0, "URL required");
  return argv as Options;
}
const flags = parseOptions(parseArgs(Deno.args));
await makeSubs(flags._[0]);
