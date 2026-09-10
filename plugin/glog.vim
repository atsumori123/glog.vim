if exists('g:loaded_glog')
	finish
endif
let g:loaded_glog = 1
let g:gsign_locked = 0

let s:save_cpo = &cpoptions
set cpoptions&vim

command! -bar -nargs=* Glog call glog#log(<f-args>)
command! -nargs=0 -bar GsignToggle          call gsign#toggle()
command! -nargs=0 -bar GsignToggleHighlight call glog#highlight#line_toggle()

augroup GlogSyntax
	autocmd!
	autocmd FileType gdiff		call glog#syntax#diff()
	autocmd FileType glog		call glog#syntax#log()
	autocmd FileType gstatus	call glog#syntax#status()
augroup END

" hunk jumping
nnoremap <silent> <expr> <plug>(signify-next-hunk) &diff
			\ ? ']c'
			\ : ":\<c-u>call sign#jump_hunk(v:count1, 1)\<cr>"
nnoremap <silent> <expr> <plug>(signify-prev-hunk) &diff
			\ ? '[c'
			\ : ":\<c-u>call gsign#jump_hunk(v:count1, -1)\<cr>"

if empty(maparg(']c', 'n')) && !hasmapto('<plug>(signify-next-hunk)', 'n')
	nmap ]c <plug>(signify-next-hunk)
	if empty(maparg(']C', 'n')) && !hasmapto('9999]c', 'n')
		nmap ]C 9999]c
	endif
endif
if empty(maparg('[c', 'n')) && !hasmapto('<plug>(signify-prev-hunk)', 'n')
	nmap [c <plug>(signify-prev-hunk)
	if empty(maparg('[C', 'n')) && !hasmapto('9999[c', 'n')
		nmap [C 9999[c
	end
endif

if has('gui_running') && has('win32') && argc()
	" Fix 'no signs at start' race.
	autocmd GUIEnter * redraw
endif

autocmd QuickFixCmdPre  *vimgrep* let g:gsign_locked = 1
autocmd QuickFixCmdPost *vimgrep* let g:gsign_locked = 0

autocmd BufNewFile,BufRead * nested
			\ if !get(g:, 'signify_disable_by_default') |
			\   call gsign#start(bufnr('')) |
			\ endif

let &cpoptions = s:save_cpo
unlet s:save_cpo
