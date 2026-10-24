* Copyright (c) 2026 Choonjoo Lee. Licensed under AFL-3.0; see repository LICENSE.
* Install pngread; a local hello_stata.png takes priority over the installed PNG.
* Replaces data in memory and hello_stata_decoded.txt.
version 16.1
findfile hello_stata.png
pngread using "`r(fn)'", clear
assert r(width)==624 & r(height)==160
assert r(has_icc)==0 & r(has_srgb)==1
keep if y==80 & mod(x,48)==24
sort x
assert _N==13 & red==green & green==blue & alpha==255
mata: st_strscalar("decoded",char(st_data(.,"red")'))
display as result decoded
assert decoded=="Hello, Stata!"

* Save the recovered text, not the original input string, for optional speech.
tempname out
file open `out' using "hello_stata_decoded.txt", write text replace
file write `out' (decoded)
file close `out'
