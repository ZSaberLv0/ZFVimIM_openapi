
db source for [ZSaberLv0/ZFVimIM](https://github.com/ZSaberLv0/ZFVimIM),
using thirdparty's openapi


# Requirement

* `ZSaberLv0/ZFVimIM`, of course
* `ZSaberLv0/ZFVimJob`, and `ZFJobAvailable()` must return 1
    * a builtin fallback is also implemented, enable it by `let g:ZFVimIM_openapi_jobFallback = 1`,
        but it may cause lag if no `ZFJobAvailable()` support
* `wget` or `curl`


# How to use

```
Plug 'ZSaberLv0/ZFVimIM'
Plug 'ZSaberLv0/ZFVimJob' " ZFVimJob is required for this db repo
Plug 'ZSaberLv0/ZFVimIM_openapi'
```

once installed, input freely and see the changes


# Configs

* `let g:ZFVimIM_openapi_enable=1` :
    once installed, `wget` or `curl` would be invoked each time you input something,
    if you want to disable it temporarily,
    you may change this option
* `let g:ZFVimIM_openapi_word_type='sentence'` :
    within the IME popup, where to place the result,
    see also `ZFVimIM_complete()`
    * `sentence` : (default) placed at first of `sentence` type,
        which result to top of everything
    * `predict` : placed at first of `predict` type
    * `match` : placed accorrding to `g:ZFVimIM_crossDbPos`

# How it works

if you are interested on how to implement async mode of ZFVimIM's db,
here's a workflow of it

```
user input
    => ZFVimIM_complete()
        => start curl job
        => directly return empty result
    ...
    => curl job returned
        => save as cache
        => ZFVimIME_keymap_update_i() to re-trigger IME popup
        => ZFVimIM_complete()
            => matched from cache, return result
```

