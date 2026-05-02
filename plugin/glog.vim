let s:save_cpo = &cpoptions
set cpoptions&vim

if exists('g:loaded_glog')
	finish
endif
let g:loaded_glog = 1

command! -bar -nargs=* Glog call glog#log(<f-args>)

augroup GlogSyntax
	autocmd!
	autocmd FileType gdiff call glog#syntax#diff()
	autocmd FileType glog call glog#syntax#log()
	autocmd FileType gstatus call glog#syntax#status()
augroup END

let &cpoptions = s:save_cpo
unlet s:save_cpo
