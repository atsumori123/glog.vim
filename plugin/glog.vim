if exists('g:loaded_glog')
	finish
endif
let g:loaded_glog = 1
let g:gsign_locked = 0

let s:save_cpo = &cpoptions
set cpoptions&vim

command! -nargs=* -bar Glog     call glog#log(<f-args>)
command! -nargs=0 -bar Gsign    call gsign#toggle()
command! -nargs=0 -bar GsignHi  call gsign#toggle_highlight()

augroup GlogSyntax
	autocmd!
	autocmd FileType gdiff		call glog#syntax#diff()
	autocmd FileType glog		call glog#syntax#log()
	autocmd FileType gstatus	call glog#syntax#status()
augroup END

augroup GsignAugroup
	autocmd!
	autocmd QuickFixCmdPre  *vimgrep* let g:gsign_locked = 1
	autocmd QuickFixCmdPost *vimgrep* let g:gsign_locked = 0
	autocmd BufNewFile,BufRead * nested call gsign#start(bufnr('')) |
augroup END

" hunk jumping
nnoremap <silent> <expr> <plug>(signify-next-hunk) &diff
			\ ? ']c'
			\ : ":\<c-u>call gsign#jump_hunk(v:count1, 1)\<cr>"
nnoremap <silent> <expr> <plug>(signify-prev-hunk) &diff
			\ ? '[c'
			\ : ":\<c-u>call gsign#jump_hunk(v:count1, -1)\<cr>"

if empty(maparg('<c-j>', 'n')) && !hasmapto('<plug>(signify-next-hunk)', 'n')
	nmap <c-j> <plug>(signify-next-hunk)
endif
if empty(maparg('<c-k>', 'n')) && !hasmapto('<plug>(signify-prev-hunk)', 'n')
	nmap <c-k> <plug>(signify-prev-hunk)
endif

" if has('gui_running') && has('win32') && argc()
" 	" Fix 'no signs at start' race.
" 	autocmd GUIEnter * redraw
" endif

let &cpoptions = s:save_cpo
unlet s:save_cpo
