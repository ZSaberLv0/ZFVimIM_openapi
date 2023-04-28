
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

if !exists('g:ZFVimIM_openapi_http_exe')
    if executable('wget')
        let g:ZFVimIM_openapi_http_exe = 'wget -q -O - --timeout 2 -t 1'
    elseif executable('curl')
        let g:ZFVimIM_openapi_http_exe = 'curl -s'
    else
        let g:ZFVimIM_openapi_http_exe = ''
    endif
endif
if empty(g:ZFVimIM_openapi_http_exe)
    finish
endif

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
"       'key' : 1,
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
    if get(moduleState['updating'], a:key, 0)
        return
    endif
    let moduleState['updating'][a:key] = 1

    let jobList = []
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
    call ZFGroupJobStart({
                \   'jobList' : jobList,
                \   'onExit' : ZFJobFunc(function('s:updatePopup'), [a:key, a:option, a:moduleName]),
                \ })
endfunction

function! s:updateOnFinish(key, option, moduleName, jobStatus, exitCode)
    let moduleState = get(s:state, a:moduleName, {})
    if empty(moduleState)
        return
    endif
    if exists("moduleState['updating'][a:key]")
        unlet moduleState['updating'][a:key]
    endif

    " parse result
    let result = ZFJobFuncCall(g:ZFVimIM_openapi[a:moduleName]['outputParser'], [a:key, a:option, a:jobStatus['jobOutput']])
    if empty(result)
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

