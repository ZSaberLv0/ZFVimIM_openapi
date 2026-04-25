
" {
"   'YourModuleName' : {
"     // (optional) whether enable
"     'enable' : 1,
"
"     // return the jobCmd
"     'apiGetter' : func(key, option),
"
"     // called when job finished,
"     // parse output and return results described in ZFVimIM_complete()
"     'outputParser' : func(key, option, outputList),
"   },
"   ...
" }
if !exists('g:ZFVimIM_openapi')
    let g:ZFVimIM_openapi = {}
endif

if !exists('g:ZFVimIM_openapi_limit_req')
    let g:ZFVimIM_openapi_limit_req = 150
endif

function! ZFVimIM_openapi_http_req_wget(params)
    let cmd = 'wget -q -O - --timeout 2 -t 1'
    for item in get(a:params, 'header', [])
        let cmd .= printf(' --header "%s"', substitute(item, '"', '\\"', 'g'))
    endfor
    if !empty(get(a:params, 'body', ''))
        let cmd .= printf(' --post-data "%s"', substitute(a:params['body'], '"', '\\"', 'g'))
    endif
    let cmd .= printf(' "%s"', a:params['url'])
    return cmd
endfunction

function! ZFVimIM_openapi_http_req_curl(params)
    let cmd = 'curl -s'
    if !empty(get(a:params, 'method', ''))
        let cmd .= ' -X ' . a:params['method']
    endif
    for item in get(a:params, 'header', [])
        let cmd .= printf(' -H "%s"', substitute(item, '"', '\\"', 'g'))
    endfor
    if !empty(get(a:params, 'body', ''))
        let cmd .= printf(' -d "%s"', substitute(a:params['body'], '"', '\\"', 'g'))
    endif
    let cmd .= ' '
    let cmd .= printf(' "%s"', a:params['url'])
    return cmd
endfunction

" params: {
"   'method' : 'POST/GET',
"   'url' : 'http://xxx',
"   'header' : ['xxx', ...],
"   'body' : 'xxx',
" }
" return: job cmd
if !exists('g:ZFVimIM_openapi_http_req')
    if 0
    elseif executable('wget')
        let g:ZFVimIM_openapi_http_req = 'ZFVimIM_openapi_http_req_wget'
    elseif executable('curl')
        let g:ZFVimIM_openapi_http_req = 'ZFVimIM_openapi_http_req_curl'
    else
        let g:ZFVimIM_openapi_http_req = ''
    endif
endif
if empty(g:ZFVimIM_openapi_http_req)
    finish
endif

" ============================================================
function! s:url_encode_char(str)
    let n = char2nr(a:str)
    if n <= 0x7F
        return printf('%%%02x', n)
    elseif n <= 0x07FF
        let c0 = or(and(n / 64, 0x1F), 0xC0)
        let c1 = or(and(n, 0x3F), 0x80)
        return printf('%%%02x%%%02x', c0, c1)
    elseif n <= 0xFFFF
        let c0 = or(and(n / 4096, 0x0F), 0xE0)
        let c1 = or(and(n / 64, 0x3F), 0x80)
        let c2 = or(and(n, 0x3F), 0x80)
        return printf('%%%02x%%%02x%%%02x', c0, c1, c2)
    endif
    return str
endfunction
function! s:url_encode(str)
    let str = a:str
    let str = substitute(str, '\([^A-Za-z0-9_.~-]\)', '\=s:url_encode_char(submatch(1))', 'g')
    return str
endfunction
function! ZFVimIM_openapi_http_url_gen(url, params)
    let url = a:url
    let token = stridx(url, '?') >= 0 ? '&' : '?'
    for key in keys(a:params)
        let url .= token . key . '=' . s:url_encode(a:params[key])
        let token = '&'
    endfor
    return url
endfunction

" ============================================================
if !exists('s:fallbackMode')
    let s:fallbackMode = 1
endif
function! ZFVimIM_openapi_complete(key, option)
    if !get(g:, 'ZFVimIM_openapi_enable', 1)
        return []
    endif
    let s:keyLatest = a:key
    let ret = []
    if s:fallbackMode
        for moduleName in keys(g:ZFVimIM_openapi)
            call s:fallback(ret, moduleName, a:key, a:option)
        endfor
    else
        for moduleName in keys(g:ZFVimIM_openapi)
            call s:updateWithCache(ret, moduleName, a:key, a:option)
        endfor
    endif
    return ret
endfunction

function! s:dbInit()
    if !ZFVimIM_json_available() || !(
                \   (exists('*ZFJobAvailable') && ZFJobAvailable())
                \   || get(g:, 'ZFVimIM_openapi_jobFallback', 0)
                \ )
        return
    endif
    if exists('*ZFJobAvailable') && (ZFJobAvailable() || has('timers'))
        let s:fallbackMode = 0
    else
        let s:fallbackMode = 1
    endif
    call ZFVimIM_dbInit({
                \   'name' : 'openapi',
                \   'priority' : 200,
                \   'switchable' : 0,
                \   'dbCallback' : function('ZFVimIM_openapi_complete'),
                \   'menuLabel' : '',
                \ })
endfunction
augroup ZFVimIM_openapi_augroup
    autocmd!
    autocmd User ZFVimIM_event_OnDbInit call s:dbInit()
augroup END

" ============================================================
" fallback impl, sync, may block
function! s:fallback(ret, moduleName, key, option)
    let module = g:ZFVimIM_openapi[a:moduleName]
    if !get(module, 'enable', 1)
        return
    endif
    let Cmd = ZFJobFuncCall(module['apiGetter'], [a:key, a:option])
    if empty(Cmd)
        return
    endif
    let output = split(system(Cmd), '[\r\n]')
    let result = ZFJobFuncCall(module['outputParser'], [a:key, a:option, output])
    call extend(a:ret, result)
endfunction

" ============================================================
" {
"   'ModuleName' : {
"     'updating' : {
"       '*' : jobId, // used if g:ZFVimIM_openapi_limit_req
"       'key' : jobId,
"     },
"     'cache' : {
"       'key' : [], // results
"     },
"     'cacheKey' : ['key'], // remember cache order
"   },
" }
if !exists('s:state')
    let s:state = {}
endif
let s:keyLatest = ''
function! s:updateWithCache(ret, moduleName, key, option)
    let module = g:ZFVimIM_openapi[a:moduleName]
    if !get(module, 'enable', 1)
        return
    endif
    let Cmd = ZFJobFuncCall(module['apiGetter'], [a:key, a:option])
    if empty(Cmd)
        return
    endif
    if !exists('s:state[a:moduleName]')
        let s:state[a:moduleName] = {
                    \   'updating' : {},
                    \   'cache' : {},
                    \   'cacheKey' : [],
                    \ }
    endif
    let moduleState = s:state[a:moduleName]
    let cache = get(moduleState['cache'], a:key, [])
    if !empty(cache)
        call extend(a:ret, cache)
        return
    endif
    if g:ZFVimIM_openapi_limit_req > 0
        if get(moduleState['updating'], '*', 0) > 0
            call ZFGroupJobStop(get(moduleState['updating'], '*', 0))
        endif
    else
        if get(moduleState['updating'], a:key, 0) > 0
            return
        endif
    endif

    let jobList = []
    if g:ZFVimIM_openapi_limit_req > 0
        call add(jobList, {
                    \   'jobCmd' : g:ZFVimIM_openapi_limit_req,
                    \ })
    endif
    if !ZFJobAvailable()
        " delay to reduce blink
        call add(jobList, {
                    \   'jobCmd' : 0,
                    \ })
    endif
    call add(jobList, {
                \   'jobCmd' : Cmd,
                \   'onExit' : ZFJobFunc(function('s:updateOnFinish'), [a:key, a:option, a:moduleName]),
                \ })
    if !ZFJobAvailable()
        " delay to make omni popup work
        call add(jobList, {
                    \   'jobCmd' : 0,
                    \ })
    endif
    let jobId = ZFGroupJobStart({
                \   'jobList' : jobList,
                \   'onExit' : ZFJobFunc(function('s:updatePopup'), [a:key, a:option, a:moduleName]),
                \ })
    if g:ZFVimIM_openapi_limit_req > 0
        let moduleState['updating']['*'] = jobId
    else
        let moduleState['updating'][a:key] = jobId
    endif
endfunction

function! s:updateOnFinish(key, option, moduleName, jobStatus, exitCode)
    let moduleState = get(s:state, a:moduleName, {})
    if empty(moduleState)
        let a:jobStatus['exitCode'] = 'invalid_state'
        return
    endif
    if exists("moduleState['updating']['*']")
        unlet moduleState['updating']['*']
    endif
    if exists("moduleState['updating'][a:key]")
        unlet moduleState['updating'][a:key]
    endif

    " parse result
    let result = ZFJobFuncCall(g:ZFVimIM_openapi[a:moduleName]['outputParser'], [a:key, a:option, a:jobStatus['jobOutput']])
    if empty(result)
        let a:jobStatus['exitCode'] = 'invalid_response'
        return
    endif

    " save cache
    let moduleState['cache'][a:key] = result
    call add(moduleState['cacheKey'], a:key)

    " limit cache size
    if len(moduleState['cacheKey']) >= 100
        for toRemove in remove(moduleState['cacheKey'], 0, 49)
            if exists("moduleState['cache'][toRemove]")
                unlet moduleState['cache'][toRemove]
            endif
        endfor
    endif
endfunction

function! s:updatePopup(key, option, moduleName, jobStatus, exitCode)
    if a:exitCode != '0'
        return
    endif
    " update IME popup
    if a:key == s:keyLatest
        call ZFVimIME_keymap_update_i()
    endif
endfunction

