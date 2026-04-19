let s:save_cpo = &cpoptions
set cpoptions&vim

"---------------------------------------------------------------
" git log ハイライト
"---------------------------------------------------------------
function! syntax#DefineGitLogSyntax()
	" ハッシュ値
	syntax match GitLogHash /^\x\+/
	highlight GitLogHash ctermfg=187 guifg=#d7d7af cterm=none gui=none

	" 日付（YYYY-MM-DD）
	syntax match GitLogDate /\d\{4}-\d\{2}-\d\{2}/
	highlight GitLogDate ctermfg=151 guifg=#afd7af cterm=none gui=none
endfunction

"---------------------------------------------------------------
" diff ハイライト
"---------------------------------------------------------------
function! syntax#DefineGitHubDiffSyntax()
	" Hunk header @@ -1,3 +1,9 @@
	syntax match GitDiffHunk '^@@.*@@'
	highlight GitDiffHunk ctermfg=Magenta guifg=#87d7d7 cterm=none gui=none

	" diff --git a/... b/...
	syntax match GitDiffHeader '^diff --git .*'
	highlight GitDiffHeader ctermfg=Blue guifg=#87d7d7 cterm=none gui=none

	" index 行
	syntax match GitDiffIndex '^index .*'
	highlight GitDiffIndex ctermfg=Grey guifg=#808080 cterm=none gui=none

	" --- a/file
	syntax match GitDiffOldFile '^--- .*'
	highlight GitDiffOldFile ctermfg=Red guifg=#F08650 cterm=none gui=none

	" +++ b/file
	syntax match GitDiffNewFile '^+++ .*'
	highlight GitDiffNewFile ctermfg=Green guifg=#afd7af cterm=none gui=none

	" 削除行（GitHubの赤）
	syntax match GitDiffRemoved '^-.*'
	highlight GitDiffRemoved ctermfg=Red guifg=#F08650 cterm=none gui=none

	" 追加行（GitHubの緑）
	syntax match GitDiffAdded '^+.*'
	highlight GitDiffAdded ctermfg=Green guifg=#afd7af cterm=none gui=none
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
