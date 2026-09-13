let s:save_cpo = &cpoptions
set cpoptions&vim

"---------------------------------------------------------------
" git log ハイライト
"---------------------------------------------------------------
function! glog#syntax#log()
    " ハッシュ
	syntax match GitHash '^\v[0-9a-f]+'
    highlight GitHash ctermfg=151 guifg=#afd7af cterm=none gui=none

    " 日付（YYYY-MM-DD）
    syntax match GitDate '\v\|\s\zs\d{4}-\d{2}-\d{2}\ze\s\|'
    highlight GitDate ctermfg=187 guifg=#d7d7af cterm=none gui=none

	" ファイル状態 (M)
	syntax match GitStatM '^\s\+\zsM\ze\s'
    highlight GitStatM ctermfg=151 guifg=#afd7af cterm=none gui=none

	" ファイル状態 (M以外)
	syntax match GitStatO '^\s\+\zs[ADRUTC]\ze\s'
    highlight GitStatO ctermfg=209 guifg=#F08650 cterm=none gui=none

	" Auther
	syntax match GitAuther '.*|.*\s\zs\S\+$'
    highlight GitAuther ctermfg=243 guifg=#808080 cterm=italic gui=italic
endfunction

"---------------------------------------------------------------
" diff ハイライト
"---------------------------------------------------------------
function! glog#syntax#diff()
    " commit ハッシュ行（commit 行頭）
    syntax match GitDiffCommit '^commit \x\+'
    highlight GitDiffCommit ctermfg=Yellow guifg=#ffff87 cterm=none gui=none

    " Author 行
    syntax match GitDiffAuthor '^Author:.*'
    highlight GitDiffAuthor ctermfg=Cyan guifg=#87d7ff cterm=none gui=none

    " Date 行
    syntax match GitDiffDate '^Date:.*'
    highlight GitDiffDate ctermfg=Cyan guifg=#87d7ff cterm=none gui=none

    " Hunk header @@ -1,3 +1,9 @@
    syntax match GitDiffHunk '^@@.*@@'
    highlight GitDiffHunk ctermfg=Magenta guifg=#d7afd7 cterm=none gui=none

    " diff --git a/... b/...
    syntax match GitDiffHeader '^diff --git .*'
    highlight GitDiffHeader ctermfg=Blue guifg=#87d7d7 cterm=none gui=none

    " index 行
    syntax match GitDiffIndex '^index .*'
    highlight GitDiffIndex ctermfg=Grey guifg=#808080 cterm=none gui=none

    " new file mode / deleted file mode / mode change
    syntax match GitDiffFileMode '^new file mode \|^deleted file mode \|^old mode \|^new mode'
    highlight GitDiffFileMode ctermfg=Yellow guifg=#ffff87 cterm=none gui=none

    " rename from / rename to
    syntax match GitDiffRename '^rename from \|^rename to'
    highlight GitDiffRename ctermfg=Magenta guifg=#ff87ff cterm=none gui=none

    " similarity index / dissimilarity index
    syntax match GitDiffSimilarity '^similarity index \|^dissimilarity index'
    highlight GitDiffSimilarity ctermfg=DarkYellow guifg=#d7af00 cterm=none gui=none

    " Binary files
    syntax match GitDiffBinary '^Binary files.*'
    highlight GitDiffBinary ctermfg=LightGrey guifg=#d0d0d0 cterm=none gui=none

    " --- a/file
    syntax match GitDiffOldFile '^--- .*'
    highlight GitDiffOldFile ctermfg=209 guifg=#F08650 cterm=none gui=none

    " +++ b/file
    syntax match GitDiffNewFile '^+++ .*'
    highlight GitDiffNewFile ctermfg=Green guifg=#afd7af cterm=none gui=none

    " 削除行（GitHubの赤）
    syntax match GitDiffRemoved '^-.*'
    highlight GitDiffRemoved ctermfg=209 guifg=#F08650 cterm=none gui=none

    " 追加行（GitHubの緑）
    syntax match GitDiffAdded '^+.*'
    highlight GitDiffAdded ctermfg=Green guifg=#afd7af cterm=none gui=none
endfunction

"---------------------------------------------------------------
" git status ハイライト
"---------------------------------------------------------------
function! glog#syntax#status()
	" staging (M / A / D / R / ?)
    syntax match GitStaging '\%1c.'
	highlight GitStaging  ctermfg=Green guifg=#afd7af cterm=none gui=none

	" workings(M / A / D / R / ?)
    syntax match GitWorking '\%2c.'
	highlight GitWorking ctermfg=209 guifg=#F08650 cterm=none gui=none
endfunction

"-------------------------------------------------------
" glog#syntax#gsing_setup
"-------------------------------------------------------
function! glog#syntax#gsing_setup() abort
	highlight GsignSignAdd     ctermfg=255 guifg=#00A46e cterm=bold gui=bold
	highlight GsignSignDelete  ctermfg=203 guifg=#e27878 cterm=bold gui=bold
	highlight GsignSignChange  ctermfg=159 guifg=#0078d4 cterm=bold gui=bold
endfunction

"-------------------------------------------------------
" glog#syntax#gsign_line_enable
"-------------------------------------------------------
function! glog#syntax#gsign_line_highlight(on_off) abort
	let icon_dir = ''
	let rtp_list = split(&runtimepath, ',')
	for dir in rtp_list
		if dir =~# '/glog.vim'
			let icon_dir = dir . '/autoload/glog/icon'
			break
		endif
	endfor

    let icon_add    = icon_dir . '/add.xpm'
    let icon_change = icon_dir . '/change.xpm'
    let icon_delete = icon_dir . '/delete.xpm'

	if has('gui_running') && filereadable(icon_add)
        execute 'sign define GsignAdd    icon=' . fnameescape(icon_add)    . ' text=| texthl=GsignSignAdd    linehl=' . (a:on_off ? 'DiffAdd' : '')
        execute 'sign define GsignChange icon=' . fnameescape(icon_change) . ' text=| texthl=GsignSignChange linehl=' . (a:on_off ? 'DiffChange' : '')
        execute 'sign define GsignDelete icon=' . fnameescape(icon_delete) . ' text=| texthl=GsignSignDelete linehl=' . (a:on_off ? 'DiffDelete' : '')
    else
        execute 'sign define GsignAdd    text=| texthl=GsignSignAdd    linehl=' . (a:on_off ? 'DiffAdd'    : '')
        execute 'sign define GsignChange text=| texthl=GsignSignChange linehl=' . (a:on_off ? 'DiffChange' : '')
        execute 'sign define GsignDelete text=| texthl=GsignSignDelete linehl=' . (a:on_off ? 'DiffDelete' : '')
    endif
	let g:gsign_line_highlight = a:on_off
endfunction

call glog#syntax#gsing_setup()

let &cpoptions = s:save_cpo
unlet s:save_cpo
