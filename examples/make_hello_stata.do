* Copyright (c) 2026 Choonjoo Lee. Licensed under AFL-3.0; see repository LICENSE.
* Run in a scratch folder; replaces data in memory and hello_stata.png.
version 16.1
clear
local text "Hello, Stata!"
generate int byte_value = .
mata: b=ascii(st_local("text")); st_addobs(cols(b)); st_store(.,"byte_value",b')
generate x = _n - .5
generate lo = 0
generate hi = 1
local n = _N
local plots
forvalues i = 1/`n' {
    local b = byte_value[`i']
    local plots `plots' (rbar lo hi x if _n==`i', barwidth(1) ///
        fcolor("`b' `b' `b'") fintensity(100) lcolor(none))
}
twoway `plots', legend(off) xlabel(none) ylabel(none) ///
    xscale(off range(0 `n')) yscale(off range(0 1)) ///
    plotregion(margin(zero) lcolor(none)) ///
    graphregion(color(white) margin(zero) lcolor(none)) ///
    scheme(s2color) xsize(12) ysize(2) name(hello_stata, replace)
graph export "hello_stata.png", width(`=48*`n'') height(160) replace
