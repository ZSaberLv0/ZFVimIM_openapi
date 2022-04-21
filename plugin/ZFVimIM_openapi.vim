
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
        let g:ZFVimIM_openapi_http_exe = 'wget -qO - --timeout 20 -t 10'
    elseif executable('curl')
        let g:ZFVimIM_openapi_http_exe = 'curl -s'
    else
        let g:ZFVimIM_openapi_http_exe = ''
    endif
endif
if empty(g:ZFVimIM_openapi_http_exe) || !exists('*json_decode')
    finish
endif

" ============================================================
function! ZFVimIM_openapi_complete(key, option)
    if !get(g:, 'ZFVimIM_openapi_enable', 1)
        return []
    endif
    let s:keyLatest = a:key
    let ret = []
    for moduleName in keys(g:ZFVimIM_openapi)
        call s:updateWithCache(ret, moduleName, a:key, a:option)
    endfor
    return ret
endfunction

function! s:dbInit()
    if !exists('*ZFJobAvailable') || !ZFJobAvailable()
        return
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
    let jobId = ZFJobStart({
                \   'jobCmd' : Cmd,
                \   'onExit' : ZFJobFunc(function('s:updateOnFinish', [a:key, a:option, a:moduleName])),
                \ })
    let moduleState['updating'][a:key] = 1
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

    " update IME popup
    if a:key == s:keyLatest && pumvisible()
        call ZFVimIME_keymap_update_i()
    endif
endfunction

