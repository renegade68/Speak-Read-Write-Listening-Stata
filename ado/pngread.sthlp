{smcl}
{* *! version 0.1.0 24oct2026}
{title:pngread — Experimental PNG pixel reader written in Stata/Mata}

{p 8 12 2}{cmd:pngread using} {it:filename.png} [{cmd:, clear}]

{title:Description}
{pstd}
Reads PNG pixels into a Stata dataset without Python, Java, plugins, shell
commands, or external image/ZIP programs. The reader implements zlib/DEFLATE
and PNG row-filter reversal in Mata. This is a research prototype tested with
Stata/MP 16.1 on macOS (Apple Silicon), not an official Stata command.

{title:Output}
{pstd}
One observation per pixel, ordered left to right then top to bottom.
{cmd:x} and {cmd:y} are zero-based coordinates from the top-left corner.
{cmd:red}, {cmd:green}, {cmd:blue}, and {cmd:alpha} range from 0 to 255.
Alpha is 255 for opaque pixels without transparency. Grayscale is replicated
across RGB channels; palette entries and tRNS transparency are expanded.

{pstd}
Samples are the decoded file values. No ICC/gamma conversion or alpha
compositing is performed; these values need not equal displayed sRGB colors.
The presence of iCCP and sRGB chunks is reported, not interpreted.

{title:Supported subset and limits}
{pstd}
Noninterlaced, 8-bit PNG color types 0, 2, 3, 4, and 6: grayscale, RGB,
indexed, grayscale with alpha, and RGBA. All five PNG row filters and stored,
fixed-Huffman, and dynamic-Huffman DEFLATE blocks are implemented.
Multiple consecutive IDAT chunks, including split zlib headers/trailers,
are supported. Chunk CRCs and the zlib Adler-32 checksum are checked.

{pstd}
1/2/4/16-bit PNGs, Adam7 interlacing, and APNG are rejected. In particular,
1-bit black-and-white PNG is not currently supported. Limits are 16 MiB of
input file bytes and 8 MiB of decompressed scanline bytes; Mata storage uses
more RAM than those byte counts. This is not a complete PNG conformance validator.

{title:Data in memory}
{pstd}
Specify {cmd:clear} to authorize replacing data. The input is decoded before
replacement; a file decoding error leaves existing data unchanged.

{title:Example}
{phang2}{cmd:. pngread using "hello.png", clear}
{phang2}{cmd:. list x y red green blue alpha in 1/10}

{pstd}
For the separate grey-byte-v1 demonstration only (48-pixel tiles, height 160):
{phang2}{cmd:. keep if y==80 & mod(x,48)==24}
{phang2}{cmd:. sort x}
{phang2}{cmd:. mata: char(st_data(.,"red")')}

{pstd}
The PNG reader itself has no color-to-letter mapping. The demonstration uses
RGB=(byte,byte,byte) and a known tile order, followed by Mata's UTF-8 byte
conversion. It does not perform OCR or infer text in arbitrary images.

{title:Stored results}
{pstd}
{cmd:r(width)}, {cmd:r(height)}, {cmd:r(bitdepth)}, {cmd:r(colortype)},
{cmd:r(has_icc)}, and {cmd:r(has_srgb)}.

{title:References}
{pstd}
For grayscale request/reply exchanges that preserve the current dataset,
see {help pngmessage}. Its SPM1 tile layout differs from the example above.

{pstd}{browse "https://www.w3.org/TR/png-3/":W3C PNG specification}
{pstd}{browse "https://www.rfc-editor.org/rfc/rfc1950.txt":RFC 1950: zlib}
{pstd}{browse "https://www.rfc-editor.org/rfc/rfc1951.txt":RFC 1951: DEFLATE}
{pstd}{browse "https://www.stata.com/manuals/m-5ascii.pdf":Mata ascii() and char()}

{title:Author and license}
{pstd}
Choonjoo Lee, Korea National Defense University. Copyright (c) 2026.
Licensed under the Academic Free License version 3.0 (AFL-3.0).
{pstd}
{browse "https://github.com/renegade68/Speak-Read-Write-Listening-Stata":Source, examples, and license}
