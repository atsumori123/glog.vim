let s:save_cpo = &cpoptions
set cpoptions&vim

if exists('g:loaded_glog')
	finish
endif
let g:loaded_glog = 1

command! -bar -nargs=? Glog call glog#GitLog(<f-args>)

augroup GitDiffSyntax
	autocmd!
	autocmd FileType gitdiff call syntax#DefineGitHubDiffSyntax()
	autocmd FileType gitlog call syntax#DefineGitLogSyntax()
augroup END

let &cpoptions = s:save_cpo
unlet s:save_cpo
