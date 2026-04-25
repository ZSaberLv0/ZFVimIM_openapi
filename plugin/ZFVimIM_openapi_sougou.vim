
if !get(g:, 'ZFVimIM_openapi_sougou', 1)
    finish
endif

let s:scriptPath = expand('<sfile>:p:h:h') . '/misc'
function! s:apiGetter(key, option)
    if empty(g:ZFVimIM_openapi_py)
        return ''
    endif
    return printf('%s "%s" "%s"', g:ZFVimIM_openapi_py, CygpathFix_absPath(printf("%s/sougou.py", s:scriptPath)), a:key)
endfunction

" output: plain result text
function! s:outputParser(key, option, outputList)
    if empty(a:outputList)
        return []
    endif
    return [{
                \   'len' : len(a:key),
                \   'key' : a:key,
                \   'word' : a:outputList[0],
                \   'type' : get(g:, 'ZFVimIM_openapi_word_type', 'match'),
                \ }]
endfunction

if !exists('g:ZFVimIM_openapi')
    let g:ZFVimIM_openapi = {}
endif
let g:ZFVimIM_openapi['sougou'] = {
            \   'apiGetter' : function('s:apiGetter'),
            \   'outputParser' : function('s:outputParser'),
            \ }

