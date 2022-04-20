" Copyright (c) 2022, Soul Inc
" Author: Hongbo Liu <lhbf@qq.com>
" Date  : 2022-04-20 20:56:56

let s:double_chars_map = {
      \ "ah": "ang",
      \ "eg": "eng",
      \ "aa": "a",
      \ "ee": "e",
      \ "oo": "o",
      \ "bo": "bo",
      \ "fo": "fo",
      \ "mo": "mo",
      \ "po": "po",
      \ "wo": "wo",
      \ "yo": "yo",
      \ "io": "chuo",
      \ "uo": "shuo",
      \ "vo": "zhuo",
      \ "co": "cuo",
      \ "do": "duo",
      \ "go": "guo",
      \ "ho": "huo",
      \ "ko": "kuo",
      \ "lo": "luo",
      \ "no": "nuo",
      \ "ro": "ruo",
      \ "so": "suo",
      \ "to": "tuo",
      \ "zo": "zuo",
      \ "is": "chong",
      \ "vs": "zhong",
      \ "cs": "cong",
      \ "ds": "dong",
      \ "gs": "gong",
      \ "hs": "hong",
      \ "js": "jiong",
      \ "ks": "kong",
      \ "ls": "long",
      \ "ns": "nong",
      \ "qs": "qiong",
      \ "rs": "rong",
      \ "ss": "song",
      \ "ts": "tong",
      \ "xs": "xiong",
      \ "ys": "yong",
      \ "zs": "zong",
      \ "bk": "bing",
      \ "dk": "ding",
      \ "jk": "jing",
      \ "lk": "ling",
      \ "mk": "ming",
      \ "nk": "ning",
      \ "pk": "ping",
      \ "qk": "qing",
      \ "tk": "ting",
      \ "xk": "xing",
      \ "yk": "ying",
      \ "gk": "guai",
      \ "hk": "huai",
      \ "kk": "kuai",
      \ "uk": "shuai",
      \ "vk": "zhuai",
      \ "ik": "chuai",
      \ "jl": "jiang",
      \ "ll": "liang",
      \ "nl": "niang",
      \ "ql": "qiang",
      \ "xl": "xiang",
      \ "gl": "guang",
      \ "hl": "huang",
      \ "kl": "kuang",
      \ "il": "chuang",
      \ "ul": "shuang",
      \ "vl": "zhuang",
      \ "dx": "dia",
      \ "jx": "jia",
      \ "lx": "lia",
      \ "qx": "qia",
      \ "xx": "xia",
      \ "gx": "gua",
      \ "hx": "hua",
      \ "kx": "kua",
      \ "ux": "shua",
      \ "vx": "zhua",
      \ "cv": "cui",
      \ "dv": "dui",
      \ "gv": "gui",
      \ "hv": "hui",
      \ "kv": "kui",
      \ "rv": "rui",
      \ "sv": "sui",
      \ "tv": "tui",
      \ "zv": "zui",
      \ "vv": "zhui",
      \ "iv": "chui",
      \ "uv": "shui",
      \ }

let s:yunmu_dict = {
      \ "q": "iu",
      \ "w": "ei",
      \ "e": "e",
      \ "r": "uan",
      \ "t": "ue",
      \ "y": "un",
      \ "u": "u",
      \ "i": "i",
      \ "p": "ie",
      \ "a": "a",
      \ "d": "ai",
      \ "f": "en",
      \ "g": "eng",
      \ "h": "ang",
      \ "j": "an",
      \ "z": "ou",
      \ "c": "ao",
      \ "b": "in",
      \ "n": "iao",
      \ "m": "ian",
      \ }

let s:shengmu_dict = {
      \ 'i': 'ch',
      \ 'u': 'sh',
      \ 'v': 'zh',
      \ }

function! xiaohe#chars_to_pinyin(str)
  if has_key(s:double_chars_map, a:str)
    return s:double_chars_map[a:str]
  endif

  let l:shengmu = get(s:shengmu_dict, a:str[0], a:str[0])
  let l:yunmu = get(s:yunmu_dict, a:str[1], a:str[1])

  let l:res = l:shengmu . l:yunmu

  return l:res
endfunction

function! xiaohe#line_to_pinyin(line)
  let l:size = len(a:line)

  let l:res = ''
  let l:idx = 0
  while l:idx + 1 < l:size
    let l:pinyin = xiaohe#chars_to_pinyin(a:line[idx:idx+1])
    let l:res .= l:pinyin

    let l:idx += 2
  endwhile

  if l:size % 2
    let l:last_ch = a:line[idx]
    let l:res .= get(s:shengmu_dict, l:last_ch, l:last_ch)
  endif

  return l:res
endfunction
