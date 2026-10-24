# Speak-Read-Write-Listening-Stata

Experimental user-written extensions for reading, speaking, listening, and
writing with Stata. The first working example reads a PNG into pixel data,
recovers **Hello, Stata!** from grayscale tiles, writes the recovered text to
a file, and optionally speaks it using macOS.

Version **0.1.0** is a research prototype, tested with **Stata/MP 16.1 on macOS
(Apple Silicon)**. It is not an official Stata product or an SSC package.

| Area | Available in this version |
| --- | --- |
| Reading | `pngread`: import supported PNG pixels using Stata/Mata only |
| Writing | Example: create a grayscale PNG; save recovered text to a file |
| Speaking | Optional example using the macOS `say` service |
| Listening | Planned; no microphone capture or speech recognition command is included |

## Install and try the example

Download the repository ZIP and extract it, or clone it. In Stata, substitute
your local path below. Use a scratch session: the example replaces data in
memory and writes `hello_stata_decoded.txt` in the current folder.

```stata
cd "/your/path/Speak-Read-Write-Listening-Stata"
adopath ++ "`c(pwd)'/ado"
cd "examples"
which pngread
help pngread
do read_hello_stata.do
```

Expected text:

```text
Hello, Stata!
```

The example checks the PNG dimensions, color metadata, the 13 selected pixel
values, and the recovered greeting. To hear the recovered text on **macOS**:

```stata
shell /usr/bin/say -f "hello_stata_decoded.txt"
```

To generate the input PNG yourself, run the following in the examples folder.
This replaces `hello_stata.png`. A fresh Stata/Mata state separates generation
from reading:

```stata
do make_hello_stata.do
clear all
do read_hello_stata.do
```

PNG export behavior may differ on other platforms or Stata versions. If a
check fails, report it rather than removing the assertion; start by testing
the supplied original PNG.

### Short installation for a publicly accessible repository

The following unauthenticated commands require the repository to be public.
For a private repository, use an authorized local checkout and the instructions
above. Run in an empty scratch folder. `net install` installs the command,
help, and example PNG; `net get` downloads the example do-files and license
to the current folder. The reader example finds either a local PNG or the
installed copy, with a local `hello_stata.png` taking priority.

```stata
local source "https://raw.githubusercontent.com/renegade68/Speak-Read-Write-Listening-Stata/main"
net install pngread, from("`source'")
net get pngread, from("`source'")
do read_hello_stata.do
```

For an update, add `replace` to the `net install` command. Add `replace` to
`net get` only when you intend to overwrite previously downloaded examples.

## What the picture means

![Grayscale tiles encoding Hello, Stata!](examples/hello_stata.png)

This demonstration assigns each UTF-8 byte `b` the color `RGB=(b,b,b)`, places
the bytes left to right in 48-pixel-wide tiles, and exports a 624 by 160 PNG.
The reader samples the tile centers at `y=80`, with `x` equal to 24, 72, and so
on. Mata's `char()` converts those bytes back to text. The greeting uses only
ASCII characters, which have the same byte values in UTF-8.

This is an explicit encoding experiment, not OCR or a built-in Stata rule
that assigns letters to colors. `pngread` itself only imports pixels. Arbitrary
photographs, screenshots, or grayscale pictures do not imply this message.
Use the original PNG without resizing, recoloring, or taking a screenshot;
these operations can change the encoded bytes. This example does not establish
general multilingual round-trip support.

## Use the PNG reader independently

```stata
pngread using "your_image.png", clear
return list
list x y red green blue alpha in 1/10
```

Each observation is a pixel. Coordinates are zero-based from the top-left
corner; `red`, `green`, `blue`, and `alpha` range from 0 to 255. Pixels appear
left to right, then top to bottom. The `clear` option authorizes replacing the
current dataset. A decoding error leaves the existing data unchanged.

Supported input is **8-bit, noninterlaced PNG**: grayscale, RGB, indexed color,
grayscale with alpha, and RGBA (color types 0, 2, 3, 4, 6). Palette entries and
PNG transparency are expanded to RGBA. The command returns `r(width)`,
`r(height)`, `r(bitdepth)`, `r(colortype)`, `r(has_icc)`, and `r(has_srgb)`.
See `help pngread` for details.

Current limits:

- 1-, 2-, 4-, and 16-bit PNG, Adam7 interlacing, and APNG are not supported.
  This includes 1-bit black-and-white PNG.
- Input files are limited to 16 MiB and decompressed scanlines to 8 MiB.
  Actual memory use is higher because Mata stores numeric arrays.
- Values are decoded file samples; ICC/gamma conversion and alpha compositing
  are not performed. Raw samples may differ from displayed colors.
- Chunk CRC and zlib Adler-32 checks are included, but this is not a complete
  PNG conformance validator.
- Other operating systems and Stata versions have not been validated.
- PNG decoding needs no Python, Java, plugin, shell command, or external image
  library. Speech uses an operating-system service and is currently macOS only.

## Validation and feedback

Local checks covered all five PNG row filters, the three DEFLATE block types,
all five supported PNG color types, transparency, split IDAT data, and checksum
or truncation failures. Eight external PngSuite images were used alongside
small controlled fixtures. The supplied example recovered all 13 greeting
bytes; an additional check examined a 5 by 5 patch inside every tile. Speech
synthesis from the recovered file produced an audio file. These checks do not
establish pronunciation quality or compatibility with every PNG encoder.

Please report your operating system, Stata version, exact command, and error
message when sharing a result. For a pixel-reading issue, include a small
non-sensitive PNG that reproduces it. Whether a Statalist upload/download
preserves the example pixels remains a separate test.

## Next experiments

The research direction is to connect reliable file input, text output, and
operating-system speech services with small, reproducible Stata examples.
Planned work includes a reusable speech command, multilingual text and prosody
checks, and a clear distinction between OS dictation and programmatic speech
recognition. Speech recognition, conversational control, and AI integration
are not implemented in this version.

## Files, sources, and license

The user distribution contains the command and help in `ado/`, runnable
examples and their PNG input in `examples/`, and installation/citation/license
metadata. Development logs, generated audio, test fixtures, manuscripts, and
research notes remain outside this repository.

The reader is an original implementation based on these format specifications:

- [W3C PNG specification](https://www.w3.org/TR/png-3/)
- [RFC 1950: zlib](https://www.rfc-editor.org/rfc/rfc1950.txt)
- [RFC 1951: DEFLATE](https://www.rfc-editor.org/rfc/rfc1951.txt)
- [Stata: Mata `ascii()` and `char()`](https://www.stata.com/manuals/m-5ascii.pdf)

[PngSuite in the libpng repository](https://github.com/pnggroup/libpng/tree/libpng16/contrib/pngsuite)
was used for local validation. Those images and libpng source code are not
included in this distribution; their copyright and permission notice remain
with the local test material.

Copyright © 2026 Choonjoo Lee, Korea National Defense University.
Licensed under the [Academic Free License 3.0](LICENSE).
For research use, cite this repository and the version or commit used;
machine-readable citation information is in [CITATION.cff](CITATION.cff).
