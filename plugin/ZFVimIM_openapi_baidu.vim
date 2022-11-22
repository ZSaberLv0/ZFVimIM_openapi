
if !get(g:, 'ZFVimIM_openapi_baidu', 1)
    finish
endif

function! s:apiGetter(key, option)
    if empty(g:ZFVimIM_openapi_http_exe) || !ZFVimIM_json_available()
        return ''
    endif
    return g:ZFVimIM_openapi_http_exe . ' "http://olime.baidu.com/py?rn=0&pn=20&py=' . a:key . '"'
endfunction

" {"0":[[["我的",4,{"pinyin":"wo'de","type":"IMEDICT"}]]],"1":"wo'de","result":[null]}
function! s:outputParser(key, option, outputList)
    let output = join(a:outputList, '')
    let output = substitute(output, '[\r\n]', '', 'g')
    if empty(output)
        return []
    endif
    try
        let data = ZFVimIM_json_decode(output)
    catch
        return []
    endtry
    let dataArr = get(get(get(data, '0', []), 0, []), 0, [])
    let word = get(dataArr, 0, '')
    let key = substitute(get(get(dataArr, 2, {}), 'pinyin', ''), "'", '', 'g')
    if empty(key) || empty(word)
        return []
    endif
    return [{
                \   'len' : len(a:key),
                \   'key' : a:key,
                \   'word' : word,
                \   'type' : get(g:, 'ZFVimIM_openapi_word_type', 'match'),
                \ }]
endfunction

if !exists('g:ZFVimIM_openapi')
    let g:ZFVimIM_openapi = {}
endif
let g:ZFVimIM_openapi['baidu'] = {
            \   'apiGetter' : function('s:apiGetter'),
            \   'outputParser' : function('s:outputParser'),
            \ }

