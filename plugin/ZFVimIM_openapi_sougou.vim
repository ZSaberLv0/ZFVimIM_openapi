
if !get(g:, 'ZFVimIM_openapi_sougou', 1)
    finish
endif

if 0
elseif executable('py3')
    let s:py = 'py3'
elseif executable('python3')
    let s:py = 'python3'
elseif executable('py')
    let s:py = 'py'
elseif executable('python')
    let s:py = 'python'
else
    let s:py = ''
endif

if s:py == ''
    finish
endif

let s:scriptPath = expand('<sfile>:p:h:h') . '/misc'
function! s:apiGetter(key, option)
    return printf('%s %s/sougou.py "%s"', s:py, s:scriptPath, a:key)
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

