" vim:foldmethod=marker:fen:
scriptencoding utf-8

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}


" Default values of global variables. "{{{
if g:__openbrowser_platform.cygwin
    function! s:get_default_open_commands()
        return ['cygstart']
    endfunction
    function! s:get_default_open_rules()
        return {'cygstart': '{browser} {shellescape(uri)}'}
    endfunction
elseif g:__openbrowser_platform.macunix
    function! s:get_default_open_commands()
        return ['open']
    endfunction
    function! s:get_default_open_rules()
        return {'open': '{browser} {shellescape(uri)}'}
    endfunction
elseif g:__openbrowser_platform.mswin
    function! s:get_default_open_commands()
        return ['cmd.exe']
    endfunction
    function! s:get_default_open_rules()
        " NOTE: On MS Windows, 'start' command is not executable.
        " NOTE: If &shellslash == 1,
        " `shellescape(uri)` uses single quotes not double quote.
        return {'cmd.exe': 'cmd /c start "openbrowser.vim" "{uri}"'}
    endfunction
elseif g:__openbrowser_platform.unix
    function! s:get_default_open_commands()
        return ['xdg-open', 'x-www-browser', 'firefox', 'w3m']
    endfunction
    function! s:get_default_open_rules()
        return {
        \   'xdg-open':      '{browser} {shellescape(uri)}',
        \   'x-www-browser': '{browser} {shellescape(uri)}',
        \   'firefox':       '{browser} {shellescape(uri)}',
        \   'w3m':           '{browser} {shellescape(uri)}',
        \}
    endfunction
endif

unlet g:__openbrowser_platform
" }}}

" Global Variables {{{
if !exists('g:openbrowser_open_commands')
    let g:openbrowser_open_commands = s:get_default_open_commands()
endif
if !exists('g:openbrowser_open_rules')
    let g:openbrowser_open_rules = s:get_default_open_rules()
endif
if !exists('g:openbrowser_fix_schemes')
    let g:openbrowser_fix_schemes = {'ttp': 'http'}
endif
if !exists('g:openbrowser_fix_hosts')
    let g:openbrowser_fix_hosts = {}
endif
if !exists('g:openbrowser_fix_paths')
    let g:openbrowser_fix_paths = {}
endif
if exists('g:openbrowser_isfname')
    " Backward compatibility.
    let g:openbrowser_iskeyword = g:openbrowser_isfname
endif
if !exists('g:openbrowser_iskeyword')
    " Getting only URI from <cfile>.
    let g:openbrowser_iskeyword = join(
    \   range(char2nr('A'), char2nr('Z'))
    \   + range(char2nr('a'), char2nr('z'))
    \   + range(char2nr('0'), char2nr('9'))
    \   + [
    \   '_',
    \   ':',
    \   '/',
    \   '.',
    \   '-',
    \   '+',
    \   '%',
    \   '#',
    \   '?',
    \   '&',
    \   '=',
    \   ';',
    \   '@',
    \   '$',
    \   ',',
    \   '[',
    \   ']',
    \   '!',
    \   "'",
    \   "(",
    \   ")",
    \   "*",
    \   "~",
    \], ',')
endif
if !exists('g:openbrowser_default_search')
    let g:openbrowser_default_search = 'google'
endif

let s:default = {
\   'google': 'http://google.com/search?q={query}',
\   'yahoo': 'http://search.yahoo.com/search?p={query}',
\}
if exists('g:openbrowser_search_engines')
    call extend(g:openbrowser_search_engines, s:default, 'keep')
else
    let g:openbrowser_search_engines = s:default
endif
unlet s:default

if !exists('g:openbrowser_open_filepath_in_vim')
    let g:openbrowser_open_filepath_in_vim = 1
endif
if !exists('g:openbrowser_open_vim_command')
    let g:openbrowser_open_vim_command = 'vsplit'
endif
" }}}


" Functions {{{

function! openbrowser#open(uri) "{{{
    if a:uri =~# '^\s*$'
        return
    endif

    if g:openbrowser_open_filepath_in_vim && s:seems_path(a:uri)
        execute g:openbrowser_open_vim_command a:uri
        return
    endif

    let uri = s:convert_uri(a:uri)
    redraw
    echo "opening '" . uri . "' ..."

    for browser in g:openbrowser_open_commands
        if !executable(browser)
            continue
        endif

        if !has_key(g:openbrowser_open_rules, browser)
            continue
        endif

        call system(s:expand_keyword(g:openbrowser_open_rules[browser], {'browser': browser, 'uri': uri}))

        let success = 0
        if v:shell_error ==# success
            redraw
            echo "opening '" . uri . "' ... done! (" . browser . ")"
            return
        endif
    endfor

    echohl WarningMsg
    redraw
    echomsg "open-browser doesn't know how to open '" . uri . "'."
    echohl None
endfunction "}}}

function! openbrowser#search(query, ...) "{{{
    let engine = a:0 ? a:1 : g:openbrowser_default_search
    if !has_key(g:openbrowser_search_engines, engine)
        echohl WarningMsg
        echomsg "Unknown search engine '" . engine . "'."
        echohl None
        return
    endif

    call openbrowser#open(
    \   s:expand_keyword(g:openbrowser_search_engines[engine], {'query': urilib#uri_escape(a:query)})
    \)
endfunction "}}}

function! openbrowser#_cmd_open_browser_search(args) "{{{
    let NONE = -1
    let engine = NONE
    let args = substitute(a:args, '^\s\+', '', '')

    if args =~# '^-\w\+\s\+'
        let m = matchlist(args, '^-\(\w\+\)\s\+\(.*\)')
        if empty(m)
        endif
        let [engine, args] = m[1:2]
    endif

    call call('OpenBrowserSearch', [args] + (engine ==# NONE ? [] : [engine]))
endfunction "}}}

function! openbrowser#_cmd_complete_open_browser_search(ArgLead, CmdLine, CursorPos) "{{{
    let r = '^\s*OpenBrowserSearch\s\+'
    if a:CmdLine !~# r
        return
    endif
    let cmdline = substitute(a:CmdLine, r, '', '')

    let engine_options = map(keys(g:openbrowser_search_engines), '"-" . v:val')
    if cmdline == ''
        return engine_options
    endif

    if type(a:ArgLead) == type(0) || a:ArgLead == ''
        return []
    endif
    for option in engine_options
        if stridx(option, a:ArgLead) == 0
            return [option]
        endif
    endfor

    " TODO
    return []
endfunction "}}}

function! openbrowser#_keymapping_open(mode) "{{{
    if a:mode ==# 'n'
        return openbrowser#open(s:get_url_on_cursor())
    else
        return openbrowser#open(s:get_selected_text())
    endif
endfunction "}}}

function! s:seems_path(path) "{{{
    return
    \   stridx(a:path, 'file://') ==# 0
    \   || getftype(a:path) =~# '^\(file\|dir\|link\)$'
endfunction "}}}

function! s:seems_uri(uri) "{{{
    return urilib#like_uri(a:uri)
endfunction "}}}

function! s:convert_uri(uri) "{{{
    if s:seems_path(a:uri)
        " a:uri is File path. Converts a:uri to `file://` URI.
        if stridx(a:uri, 'file://') ==# 0
            return a:uri
        endif
        let save_shellslash = &shellslash
        let &l:shellslash = 1
        try
            return 'file:///' . fnamemodify(a:uri, ':p')
        finally
            let &l:shellslash = save_shellslash
        endtry
    endif

    if s:seems_uri(a:uri)
        let obj = urilib#new_from_uri_like_string(a:uri)
        call obj.scheme(get(g:openbrowser_fix_schemes, obj.scheme(), obj.scheme()))
        call obj.host  (get(g:openbrowser_fix_hosts, obj.host(), obj.host()))
        call obj.path  (get(g:openbrowser_fix_paths, obj.path(), obj.path()))
        return obj.to_string()
    endif

    " Neither
    " - File path
    " - |urilib| has been installed and |urilib| determine a:uri is URI

    " ...But openbrowser should try to open!
    " Because a:uri might be URI like "file://...".
    " In this case, this is not file path and
    " |urilib| might not have been installed :(.
    return a:uri
endfunction "}}}

" Get selected text in visual mode.
function! s:get_selected_text() "{{{
    let save_z = getreg('z', 1)
    let save_z_type = getregtype('z')

    try
        normal! gv"zy
        return @z
    finally
        call setreg('z', save_z, save_z_type)
    endtry
endfunction "}}}

function! s:get_url_on_cursor() "{{{
    let save_iskeyword = &iskeyword
    let &l:iskeyword = g:openbrowser_iskeyword
    try
        return expand('<cword>')
    finally
        let &l:iskeyword = save_iskeyword
    endtry
endfunction "}}}

" This function is from quickrun.vim (http://github.com/thinca/vim-quickrun)
" Original function is `s:Runner.expand()`.
"
" Expand the keyword.
" - @register @{register}
" - &option &{option}
" - $ENV_NAME ${ENV_NAME}
" - {expr}
" Escape by \ if you does not want to expand.
function! s:expand_keyword(str, options)  " {{{
  if type(a:str) != type('')
    return ''
  endif
  let i = 0
  let rest = a:str
  let result = ''

  " Assign these variables for eval().
  for [name, val] in items(a:options)
      " unlockvar l:
      " let l:[name] = val
      execute 'let' name '=' string(val)
  endfor

  while 1
    let f = match(rest, '\\\?[@&${]')
    if f < 0
      let result .= rest
      break
    endif

    if f != 0
      let result .= rest[: f - 1]
      let rest = rest[f :]
    endif

    if rest[0] == '\'
      let result .= rest[1]
      let rest = rest[2 :]
    else
      if rest =~ '^[@&$]{'
        let rest = rest[1] . rest[0] . rest[2 :]
      endif
      if rest[0] == '@'
        let e = 2
        let expr = rest[0 : 1]
      elseif rest =~ '^[&$]'
        let e = matchend(rest, '.\w\+')
        let expr = rest[: e - 1]
      else  " rest =~ '^{'
        let e = matchend(rest, '\\\@<!}')
        let expr = substitute(rest[1 : e - 2], '\\}', '}', 'g')
      endif
      let result .= eval(expr)
      let rest = rest[e :]
    endif
  endwhile
  return result
endfunction "}}}

" }}}


" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
