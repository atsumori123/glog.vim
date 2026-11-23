let s:save_cpo = &cpoptions
set cpoptions&vim

"---------------------------------------------------------------
" git log ハイライト
"---------------------------------------------------------------
function! glog#syntax#log()
    " ハッシュ
	syntax match GitHash '^\v[0-9a-f]+'
    highlight link GitHash diffAdded

    " 日付（YYYY-MM-DD）
    syntax match GitDate '\v\|\s\zs\d{4}-\d{2}-\d{2}\ze\s\|'
    highlight link GitDate Constant

	" ファイル状態 (M)
	syntax match GitStatM '^\s\+\zsM\ze\s'
    highlight link GitStatM diffAdded

	" ファイル状態 (M以外)
	syntax match GitStatO '^\s\+\zs[ADRUTC]\ze\s'
    highlight link GitStatO diffRemoved

	" Auther
	syntax match GitAuther '.*|.*\s\zs\S\+$'
    highlight link GitAuther Comment
endfunction

"---------------------------------------------------------------
" diff ハイライト
"---------------------------------------------------------------
function! glog#syntax#diff()
    " commit ハッシュ行（commit 行頭）
    syntax match GitDiffCommit '^commit \x\+'
    highlight link GitDiffCommit Title

    " Author 行
    syntax match GitDiffAuthor '^Author:.*'
    highlight link GitDiffAuthor Identifier

    " Date 行
    syntax match GitDiffDate '^Date:.*'
    highlight link GitDiffDate Identifier

    " Hunk header @@ -1,3 +1,9 @@
    syntax match GitDiffHunk '^@@.*@@'
    highlight link GitDiffHunk Statement

    " diff --git a/... b/...
    syntax match GitDiffHeader '^diff --git .*'
    highlight link GitDiffHeader Type

    " index 行
    syntax match GitDiffIndex '^index .*'
    highlight link GitDiffIndex Comment

    " new file mode / deleted file mode / mode change
    syntax match GitDiffFileMode '^new file mode \|^deleted file mode \|^old mode \|^new mode'
    highlight link GitDiffFileMode Title

    " rename from / rename to
    syntax match GitDiffRename '^rename from \|^rename to'
    highlight link GitDiffRename Constant

    " similarity index / dissimilarity index
    syntax match GitDiffSimilarity '^similarity index \|^dissimilarity index'
    highlight link GitDiffSimilarity Special

    " Binary files
    syntax match GitDiffBinary '^Binary files.*'
    highlight link GitDiffBinary Comment

    " --- a/file
    syntax match GitDiffOldFile '^--- .*'
    highlight link GitDiffOldFile diffRemoved

    " +++ b/file
    syntax match GitDiffNewFile '^+++ .*'
    highlight link GitDiffNewFile diffAdded

    " 削除行
    syntax match GitDiffRemoved '^-.*'
    highlight link GitDiffRemoved diffRemoved

    " 追加行
    syntax match GitDiffAdded '^+.*'
    highlight link GitDiffAdded diffAdded
endfunction

"---------------------------------------------------------------
" git status ハイライト
"---------------------------------------------------------------
function! glog#syntax#status()
	" staging (M / A / D / R / ?)
    syntax match GitStaging '\%1c.'
	highlight link GitStaging diffAdded

	" working(M / A / D / R / ?)
    syntax match GitWorking '\%2c.'
	highlight link GitWorking diffRemoved
endfunction

"-------------------------------------------------------
" glog#syntax#gsing_setup
"-------------------------------------------------------
function! glog#syntax#gsing_setup() abort
	highlight link GsignSignAdd GitGutterAdd
	highlight link GsignSignDelete GitGutterDelete
	highlight link GsignSignChange GitGutterChange
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
