scriptencoding utf-8

let s:color_mode = get(g:, 'c98tabbar_color_mode', 'cterm')
let s:glyph_theme = get(g:, 'c98tabbar_theme', 'top')
let s:glyph_themes = {
	\ 'top': [['', '', 0], ['', '', 1]],
	\ 'mid': [['', '', 0], ['', '', 1]],
	\ 'bot': [['', '', 0], ['', '', 1]],
	\ }
if type(s:glyph_theme) == v:t_list
	let s:glyphs = s:glyph_theme
else
	let s:glyphs = get(s:glyph_themes, s:glyph_theme)
endif

let s:colors = {
	\ 'null': ['black', 'none', 0],
	\ 'inactive': ['darkgray', 'lightgray', 'black'],
	\ 'active': ['lightgray', 'darkgray', 0],
	\ 'inactive_mod': ['darkblue', 'lightblue', 'black'],
	\ 'active_mod': ['lightblue', 'darkblue', 0],
	\ 'inactive_ro': ['darkred', 'lightred', 'black'],
	\ 'active_ro': ['lightred', 'darkred', 0],
	\ }
let s:colors = extend(s:colors, get(g:, 'c98tabbar_colors', {}))

function! C98TabLine()
	let l:s = ''
	let l:lastColor = 'null'
	for l:i in range(tabpagenr('$'))
		let l:N = tabpagenr()
		let l:n = l:i+1

		let l:color = l:n==l:N ? 'active' : 'inactive'

		let l:any_mod = 0
		let l:all_ro = 1
		for l:bi in tabpagebuflist(l:n)
			if getbufvar(l:bi, '&modified')
				let l:any_mod = 1
			endif
			if getbufvar(l:bi, '&modifiable')
				let l:all_ro = 0
			endif
		endfor
		if l:any_mod
			let l:color .= '_mod'
		elseif l:all_ro
			let l:color .= '_ro'
		endif

		let l:s .= s:separator(l:n, l:lastColor, l:color)
		let l:s .= '%'.l:n.'T '.s:tab_label(l:n).' %T'

		let l:lastColor = l:color
	endfor
	let l:s .= s:separator(tabpagenr('$')+1, l:lastColor, 'null')

	if exists("g:c98tabbar_additional_callback")
		execute('let l:s .= '.g:c98tabbar_additional_callback.'()')
	else
		let l:s .= '%#TabLinenull'
	endif
	return l:s
endfunction

function! s:separator(n, lc, c)
	let l:N = tabpagenr()
	let l:glyph = gettabvar(a:n, 'focus_index', 0) < gettabvar(a:n-1, 'focus_index', 0)
	if a:n == 1 | let l:glyph = 0 | endif
	if a:n == tabpagenr('$')+1 | let l:glyph = 1 | endif
	let l:s = ''
	let l:s .= '%#TabLineSep'.(s:glyphs[l:glyph][2] ? a:c.a:lc : a:lc.a:c).'#'
	let l:s .= s:glyphs[l:glyph][a:lc==a:c]
	let l:s .= '%#TabLine'.a:c.'#'
	return l:s
endfunction

function! s:tab_current(n)
	let l:bufs = tabpagebuflist(a:n)
	let l:focused = l:bufs[tabpagewinnr(a:n) - 1]
	if s:is_normal(l:focused)
		return l:focused
	endif
	for l:i in range(len(l:bufs))
		if s:is_normal(l:bufs[l:i])
			return l:bufs[l:i]
			break
		endif
	endfor
	return l:focused
endfunction

function! s:is_normal(n)
	return getbufvar(a:n, '&modifiable') && getbufvar(a:n, '&buftype') ==# ''
endfunction

function! s:tab_label(n)
	let l:bufname = bufname(s:tab_current(a:n))

	if !len(l:bufname)
		return '…'
	else
		return s:relativize(l:bufname, getcwd())
	endif
endfunction

function! s:relativize(path, where)
python3 << EOF
import vim, os.path
def shorten(a):
	if "/" in a:
		a = a.split("/")
		return "/".join(b[:1] if b != ".." else b for b in a[:-1]) + "/" + a[-1]
	return a
path = vim.eval("fnamemodify(a:path, ':~')")
where = vim.eval("fnamemodify(a:where, ':~')")

rel = os.path.relpath(path, where)
roots = ["", os.path.expanduser("~/"), "/usr/share/", "/usr/lib/", "/usr/", "/etc/"]
if os.path.commonprefix([path, where]) in roots or rel.startswith("../../../../"):
	vim.command("return %r" % shorten(path))
else:
	vim.command("return %r" % shorten(rel))
EOF
endfunction

let s:focus_index = 0
augroup C98TabIndex
	au!
	au TabEnter * let t:focus_index = s:focus_index
	au TabEnter * let s:focus_index += 1
augroup END

function! s:init_colors()
	for l:a in keys(s:colors)
		for l:b in keys(s:colors)
			if s:colors[l:a][0] == s:colors[l:b][0]
				exec 'hi TabLineSep'.l:a.b.' '.s:color_mode.'bg='.s:colors[l:a][0].' '.s:color_mode.'fg='.s:colors[l:a][2]
			else
				exec 'hi TabLineSep'.l:a.b.' '.s:color_mode.'bg='.s:colors[l:a][0].' '.s:color_mode.'fg='.s:colors[l:b][0]
			endif
		endfor
		exec 'hi TabLine'.l:a.' '.s:color_mode.'bg='.s:colors[l:a][0].' '.s:color_mode.'fg='.s:colors[l:a][1]
	endfor
endfunction
augroup C98TabColor
	au!
	au ColorScheme * call s:init_colors()
augroup END

function! s:init()
	call s:init_colors()
	for l:n in range(tabpagenr('$'), 0, -1)
		call settabvar(l:n, 'focus_index', s:focus_index)
		let s:focus_index += 1
	endfor
	call settabvar(tabpagenr(), 'focus_index', s:focus_index)
	let s:focus_index += 1
endfunction
call s:init()
delf s:init

if exists("g:c98tabbar_redraw")
	function! C98TabBarRedraw(timer)
		let &ro=&ro
	endfunction
	let timer = timer_start(30000, 'C98TabBarRedraw', {"repeat": -1})
endif

set tabline=%!C98TabLine()
