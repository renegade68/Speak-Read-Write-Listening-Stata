{smcl}
{* *! version 0.2.0 24oct2026}
{title:pngmessage — Exchange short requests and replies as grayscale PNGs}

{p 8 12 2}{cmd:pngmessage send using} {it:request.png}{cmd:, id(}{it:#}{cmd:) text("}{it:request}{cmd:")}
{p 8 12 2}{cmd:pngmessage respond using} {it:request.png}{cmd:, saving("}{it:reply.png}{cmd:")} [{cmd:id(}{it:#}{cmd:)} {cmd:wait(}{it:seconds}{cmd:)}]
{p 8 12 2}{cmd:pngmessage read using} {it:message.png} [{cmd:, id(}{it:#}{cmd:)} {cmd:wait(}{it:seconds}{cmd:)}]

{title:Description}
{pstd}
Experimental file-based message exchange between independent Stata processes.
Mata writes an 8-bit grayscale PNG directly and uses the accompanying
{help pngread} decoder to read its pixels. No graph export, Python, shell,
external image program, AI service, or text sidecar is used for the exchange.
This is a defined message protocol, not OCR or natural-language understanding.
Tested with Stata/MP 16.1 on macOS (Apple Silicon) only.

{pstd}
These commands leave the current dataset and estimation results unchanged.
They replace {cmd:r()} results. The reader works in Mata arrays and does not
import pixels into the current dataset. Existing output files are never
overwritten; choose new paths for a new exchange.

{title:Options and returned results}
{pstd}
{cmd:id()} is required for {cmd:send}: an integer from 1 to 2147483647.
On {cmd:read} or {cmd:respond}, it optionally checks the expected identifier.
A reply carries the request identifier. Omitted {cmd:id()} (internally zero)
on a reader accepts any valid identifier; use an explicit identifier to
check which request a reply belongs to.

{pstd}
{cmd:text()} supplies 1 to 1024 UTF-8 bytes, excluding NUL bytes. This is a byte
limit, not a character limit. {cmd:saving()} names the new reply PNG.
{cmd:wait()} is an integer from 0 to 60 seconds, default 0. A positive value
polls approximately every 100 ms for a missing or incompletely decoded PNG,
with an approximate wall-clock deadline. A complete but invalid message or
unexpected identifier fails immediately. A persistently corrupt PNG times out.

{pstd}
Stored results are {cmd:r(id)}, {cmd:r(kind)} (1=request, 2=reply, 3=error),
{cmd:r(bytes)}, {cmd:r(width)}, {cmd:r(height)}, {cmd:r(type)}, {cmd:r(text)},
and {cmd:r(file)}. {cmd:respond} returns the reply's values. An application
error is a successfully received message with {cmd:r(type)=="error"}; check
that value as well as the command's return code.

{title:Implemented requests}
{pstd}
Request keywords are case-sensitive. Space-separated tokens are used.

{p 4 20 2}{cmd:PING} [{it:words}] {space 2} Returns {cmd:PONG} followed by the words;
whitespace between words is normalized.
{p 4 20 2}{cmd:SUM} {it:a b} {space 2} Returns {cmd:RESULT} followed by the sum of two
finite numeric literals. Expressions such as {cmd:2+3} and missing values are
not numeric literals. Results use up to 15 significant decimal digits.
{p 4 20 2}{cmd:NOBS} {space 2} Returns {cmd:NOBS} and the responding session's current
observation count, including zero for an empty dataset.

{pstd}
Other requests return {cmd:ERROR UNKNOWN_REQUEST}; invalid {cmd:SUM} input
returns {cmd:ERROR SUM_REQUIRES_TWO_NUMBERS}. A whitespace-only request returns
{cmd:ERROR EMPTY_REQUEST}. Received text is handled as data and is never
executed as Stata or shell code.

{title:One exchange}
{pstd}In session A:
{phang2}{cmd:. pngmessage send using "request_417.png", id(417) text("PING 417")}
{pstd}In session B, working in the same shared folder:
{phang2}{cmd:. pngmessage respond using "request_417.png", saving("reply_417.png") id(417) wait(30)}
{pstd}Back in session A:
{phang2}{cmd:. pngmessage read using "reply_417.png", id(417) wait(30)}
{phang2}{cmd:reply id=417: PONG 417}

{pstd}
For five automatic exchanges, run {cmd:pngmessage_demo.do} with role B in one
session and role A in the other; supply the same new shared-folder path.
Start A within 60 seconds of B. Both sessions must have the package installed.
See the repository README for the exact commands.

{title:SPM1 image format}
{pstd}
This project's format uses 8x8 constant-gray tiles, 32 tiles across, read
left to right and top to bottom. Each tile stores one byte directly as its
gray value. PNG width is 256; height is a multiple of 8, at most 264.
The PNG is color type 0, 8-bit, noninterlaced; the writer uses filter 0 and
stored DEFLATE blocks without color-profile metadata.

{pstd}
The tile bytes are: ASCII {cmd:SPM1} (4 bytes), identifier (4), message kind (1),
UTF-8 payload byte count (2), payload (1..1024), and CRC-32 of the preceding
header and payload (4). Multibyte integers are big-endian. Remaining tiles
are zero padding, and image height must be the minimum needed. The receiver
checks all 64 pixels in every tile, the layout, length, padding, UTF-8 validity,
message CRC, and the PNG/zlib checks performed by {cmd:pngread}.

{pstd}
This layout differs from the earlier 48-pixel-wide Hello, Stata! demonstration.
Use {cmd:pngmessage read} only for SPM1 images. The general {cmd:pngread} command
can inspect the pixels of either example.

{title:Scope and limitations}
{pstd}
Use original PNG files in a local shared folder. Screenshots, resizing,
printing, color adjustment, cloud synchronization, and network filesystems
have not been validated. No internet transport or microphone recognition is
included. Checksums detect accidental changes; they do not authenticate a
sender or encrypt the message.

{pstd}
Use one writer per path. Refusing an existing output prevents a second reply
at that path, but there is no persistent deduplication by identifier, locking,
automatic retransmission, or exactly-once service. {cmd:read} may reread a file.
The caller chooses paths, identifiers, and retry policy. An interrupted write
may leave an incomplete file; waiting readers reject it and eventually time
out. Use a new path after a failed exchange.

{pstd}
Typical return codes: 198 for invalid options, 602 for an existing output,
459 for an unexpected identifier, 498 for an invalid message or timeout,
and 601/3498 for a missing/undecodable PNG without waiting.

{title:Author, sources, and license}
{pstd}
Choonjoo Lee, Korea National Defense University. Copyright (c) 2026.
Licensed under the Academic Free License version 3.0 (AFL-3.0).
{pstd}{browse "https://github.com/renegade68/Speak-Read-Write-Listening-Stata":Source, examples, and license}
{pstd}{browse "https://www.w3.org/TR/png-3/":W3C PNG specification}
{pstd}{browse "https://www.rfc-editor.org/rfc/rfc1950.txt":RFC 1950: zlib}
{pstd}{browse "https://www.rfc-editor.org/rfc/rfc1951.txt":RFC 1951: DEFLATE}
