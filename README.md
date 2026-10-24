# Speak-Read-Write-Listening-Stata

Experimental user-written extensions for reading, speaking, listening, and
writing with Stata. Version **0.2.0** adds **PNG message exchange between two
independent Stata sessions**, including requests, computed replies, and errors.
Tested with **Stata/MP 16.1 on macOS (Apple Silicon)** only.

| Area | Available |
| --- | --- |
| Reading | `pngread`: import supported PNG pixels using Stata/Mata only |
| Writing and exchange | `pngmessage`: write and read grayscale message PNGs; respond to `PING`, `SUM`, and `NOBS` |
| Speaking | Optional example using the macOS `say` service |
| Listening | Planned; no microphone capture or speech recognition command is included |

This is a research prototype, not an official Stata product or an SSC package.
The PNG exchange uses Stata/Mata only and requires no Python, shell command,
external image library, or AI service. The two processes share PNG files,
not their datasets, macros, or original message text files.

## Installation

Download and extract the repository ZIP, or clone it. In **each Stata session**,
substitute your local path:

```stata
cd "/your/path/Speak-Read-Write-Listening-Stata"
adopath ++ "`c(pwd)'/ado"
cd "examples"
help pngmessage
```

The GitHub `pngread` package installs both commands:

```stata
local source "https://raw.githubusercontent.com/renegade68/Speak-Read-Write-Listening-Stata/main"
net install pngread, from("`source'") replace
net get pngread, from("`source'")
```

`net install` installs commands, help, and the original Hello PNG. `net get`
downloads the example do-files and license to the current folder. Use an empty
scratch folder, or add `replace` to `net get` only when you intend to overwrite
previously downloaded examples.

## Two Stata sessions exchanging PNGs

Open two independent Stata sessions and complete installation in each. Choose
one **new shared-folder path**; its parent folder must already exist. The demo
creates the folder and preserves each session's current data.

Start **session B** first:

```stata
do pngmessage_demo.do B "/your/path/exchange_01"
```

Within 60 seconds, run in **session A**:

```stata
do pngmessage_demo.do A "/your/path/exchange_01"
```

Both must use the same path. The example exchanges five requests and replies:

| Request from A | Reply from B |
| --- | --- |
| `PING 417` | `PONG 417` |
| `SUM 2 3` | `RESULT 5` |
| `SUM 10 -4` | `RESULT 6` |
| `NOBS` | `NOBS n`, where n is B's observation count |
| `SUM 2 banana` | `ERROR SUM_REQUIRES_TWO_NUMBERS` |

Every reply carries the request identifier. The folder contains ten PNGs;
there are no communication text sidecars. Existing outputs are refused, so
choose a new folder for each run. B's `NOBS` answer is zero if its dataset is
empty. A and B retain their own data and estimation results.

For a single exchange, use these commands in order in a shared working folder:

```stata
* Session A: encode a request as grayscale tiles.
pngmessage send using "request_900.png", id(900) text("SUM 7 8")

* Session B: decode, calculate, and encode the reply.
pngmessage respond using "request_900.png", saving("reply_900.png") id(900)

* Session A: decode the reply and check which request it belongs to.
pngmessage read using "reply_900.png", id(900)
```

Expected final output: `reply id=900: RESULT 15`.
Use `wait(30)` on `read` or `respond` when its input may arrive later.
Returned values include `r(id)`, `r(type)`, and `r(text)`; an application error
has `r(type)=="error"` even though the PNG was successfully read.

## What is encoded in the picture?

The **SPM1** message format assigns one byte to a constant-gray 8 by 8 tile,
arranges 32 tiles per row, and includes a format identifier, request ID,
request/reply/error kind, payload length, UTF-8 text, and CRC-32. PNG files
are written directly in Mata, avoiding graphics-export color transformations.
The receiver checks all pixels in each tile and verifies the message contents.
See `help pngmessage` for the complete byte layout and limits.

The current request handlers implement a small, explicit protocol. They do
not understand general questions or execute received Stata commands. This
is an encoding and request/reply experiment, not OCR or an inherent Stata
mapping from arbitrary colors to letters.

Messages contain 1 to 1024 UTF-8 bytes, without NUL bytes. A short Korean PING
was verified; this does not establish correct pronunciation or comprehensive
multilingual support. The message layout differs from the earlier Hello PNG.

## Original color-to-text-to-speech example

The original graph-based example is still included:

![Grayscale tiles encoding Hello, Stata!](examples/hello_stata.png)

```stata
do read_hello_stata.do
```

Expected text: **Hello, Stata!**. This example replaces data in memory and
writes `hello_stata_decoded.txt`. On **macOS**, speak that recovered file with:

```stata
shell /usr/bin/say -f "hello_stata_decoded.txt"
```

To recreate the original 624 by 160 picture, run `do make_hello_stata.do`,
then `clear all` and `do read_hello_stata.do`. Each original tile is 48 pixels
wide and stores one ASCII byte as RGB=(b,b,b). The reader example prefers a
local `hello_stata.png` to the installed copy. Unlike the two-session commands,
these original examples replace data. Graph-export behavior on other systems
remains unverified.

## General PNG pixel reader

```stata
pngread using "your_image.png", clear
return list
list x y red green blue alpha in 1/10
```

Each observation is a pixel. Coordinates are zero-based from the top-left;
RGBA values range from 0 to 255. The `clear` option authorizes replacing the
current dataset; decoding errors leave it unchanged. Supported input is
**8-bit, noninterlaced PNG**: grayscale, RGB, indexed, grayscale with alpha,
and RGBA. See `help pngread` for details.

## Limits and validation

- Use original PNG files, without resizing, screenshots, or color adjustment.
  Printed-image reading and Statalist upload/download pixel preservation are
  not validated.
- `pngread` rejects 1/2/4/16-bit PNG, Adam7 interlacing, and APNG. Input is
  limited to 16 MiB and decompressed scanlines to 8 MiB; RAM use is higher.
  It returns raw samples without ICC/gamma conversion or alpha compositing.
- `pngmessage` expects its own SPM1 layout, one writer per path, and a local
  shared folder. It is not a network transport, persistent queue, or
  exactly-once service. Existing output paths are refused, but identifiers
  are not globally deduplicated. Checksums do not authenticate the sender.
- Other OS/Stata versions and cloud/network shared folders remain untested.
  Optional speech uses macOS; the package does not implement speech recognition.

Local validation covered the PNG reader's five row filters, three DEFLATE block
types, five supported color types, transparency, and corrupt files, including
eight external PngSuite images. Message checks covered all 256 gray-byte values,
maximum-length messages, UTF-8, identifiers, errors, incomplete writes, timeouts,
and preservation of data and estimation results. An independent Pillow decoder
verified the generated PNGs during development; it is **not a runtime dependency**.

Two independently launched Stata processes exchanged five requests and replies
using only ten PNGs. A retained 11 observations, B retained 7, and A received
`NOBS 7`. The original greeting example also remains available. Report your OS,
Stata version, exact command, and error message when sharing a result.

## Development direction, sources, and license

Next experiments include a reusable speech command, more analysis-result
requests, and a clear distinction between OS dictation and programmatic speech
recognition. Conversational AI and microphone recognition are not implemented.

Only user commands, help, examples, and installation/citation/license metadata
are distributed. Development logs, generated exchanges, validation fixtures,
audio outputs, manuscripts, and research notes remain local.

The original PNG reader and writer use these specifications:

- [W3C PNG specification](https://www.w3.org/TR/png-3/)
- [RFC 1950: zlib](https://www.rfc-editor.org/rfc/rfc1950.txt)
- [RFC 1951: DEFLATE](https://www.rfc-editor.org/rfc/rfc1951.txt)
- [Stata: Mata `ascii()` and `char()`](https://www.stata.com/manuals/m-5ascii.pdf)

[PngSuite in libpng](https://github.com/pnggroup/libpng/tree/libpng16/contrib/pngsuite)
was used for local reader validation. Those images and libpng source are not
redistributed; their notices remain with the local test material.

Copyright © 2026 Choonjoo Lee, Korea National Defense University.
Licensed under the [Academic Free License 3.0](LICENSE).
For research use, cite this repository and the version or commit used;
see [CITATION.cff](CITATION.cff).
