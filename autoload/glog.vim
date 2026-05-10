let s:save_cpo = &cpoptions
set cpoptions&vim

"---------------------------------------------------------------
" glog初期化
"---------------------------------------------------------------
function! s:glog_init(speify_file) abort
	let git_root = glog#git#get_git_root()
	if empty(git_root) | return 0 | endif

	let s:glog = {}
	let s:glog['GitRoot'] = git_root[0]
	let s:glog['ExeFile'] = glog#git#get_relative()[0] . expand('%:t')
	let s:glog['ExeWinnr'] = winnr()
	let s:glog['SpecifyFile'] = a:speify_file
	return 1
endfunction

"---------------------------------------------------------------
" 実行環境がcmd.exeか
"---------------------------------------------------------------
function! s:is_cmdexe()
	return has('win32') && $COMSPEC =~? 'cmd\.exe' && !has('gui_running') ? 1 : 0
endfunction

"---------------------------------------------------------------
" 情報取得
"---------------------------------------------------------------
function! s:get(key) abort
	return s:glog[a:key]
endfunction

"---------------------------------------------------------------
" エラー表示
"---------------------------------------------------------------
function! s:errmsg(msg) abort
	echo "\r"
	echohl Error | echomsg a:msg | echohl None
endfunction

"---------------------------------------------------------------
" ファイル名の抽出
"---------------------------------------------------------------
function! s:get_filepath_from_line() abort
	return matchstr(getline('.'), '\v\S+/\S+')
endfunction

"---------------------------------------------------------------
" ウィンドウ作成
"---------------------------------------------------------------
function! s:open_window(win_name, edit, data) abort
	let winnr = bufwinnr(a:win_name)

	if winnr != -1
		" 既にウィンドウがある場合は、ウィンドウに移って内容消去
		if winnr() != winnr
			execute winnr.'wincmd w'
		endif
		setlocal modifiable
		silent %d _
	else
		" ウィンドウが無い場合は作る
		execute 'silent! ' . a:edit . ' ' . a:win_name
		setlocal buftype=nofile bufhidden=wipe noswapfile
		setlocal nobuflisted
		setlocal nowrap
		setlocal bufhidden=delete
		setlocal winfixheight winfixwidth
	endif

	silent! 0put = a:data
	silent! $delete _
	normal! gg

	" 変更禁止
	setlocal nomodifiable
endfunction

"---------------------------------------------------------------
" 左右diff用ウィンドウ作成
"---------------------------------------------------------------
function! s:open_sidebyside(file, data) abort
	execute 'enew'
	setlocal noswapfile
	execute 'setlocal filetype=' . fnamemodify(a:file, ':e')
	setlocal buftype=nofile bufhidden=wipe

	" 対となるバッファ番号の初期化
	let b:glog_sidebyside_peer = -1

	" diffバッファ自動クローズを登録
	call s:setup_sidebyside_autocmd()

	" ショートカットキー
	nnoremap <buffer> <silent> q :close<CR>

	silent! 0put = a:data
	normal! gg

	" ステータス行をクリア
	redraw
	echo ""
endfunction

"---------------------------------------------------------------
" diffバッファクローズ用autocmd
"---------------------------------------------------------------
function! s:setup_sidebyside_autocmd() abort
	let grp = 'glog_sidebyside_' . bufnr('%')
	execute 'augroup ' . grp
	execute 'autocmd!'
	execute 'autocmd BufWipeout <buffer> call <SID>on_sidebyside_buffer_wipeout()'
	execute 'augroup END'
endfunction

"---------------------------------------------------------------
" diff用バッファを閉じたときのコールバック関数
"---------------------------------------------------------------
function! s:on_sidebyside_buffer_wipeout() abort
	" diffモード中だったら終了させておく
	if &diff | diffoff! | endif

	" 再帰的に閉じる処理が動作するのを防ぐ
	if exists('s:sidebyside_wipe') && s:sidebyside_wipe
		return
	endif

	" もう一方のバッファ番号を取得
	let peer = getbufvar(bufnr('%'), 'glog_sidebyside_peer', -1)
	if peer == -1 || !bufexists(peer)
		return
	endif

	" 再帰的に閉じる処理が動作しないようにフラグをオン
	let s:sidebyside_wipe = 1

	" もう一方のバッファを閉じる
	execute 'bwipeout! ' . peer

	unlet! s:sidebyside_wipe

	call s:close_diff()
endfunction

"---------------------------------------------------------------
" 互いのdiffバッファ番号をバッファ情報として記憶
"---------------------------------------------------------------
function! s:set_sidebyside_pair(left, right) abort
	call setbufvar(a:left, 'glog_sidebyside_peer', a:right)
	call setbufvar(a:right, 'glog_sidebyside_peer', a:left)
endfunction

"---------------------------------------------------------------
" 差分表示を閉じる
"---------------------------------------------------------------
function! s:close_diff() abort
	let winnr = bufwinnr('__glog__')
	if winnr != -1
		if winnr() != winnr
			execute winnr.'wincmd w'
		endif
	endif
endfunction

"---------------------------------------------------------------
" 左右対比差分の表示（親コミット vs 現在のコミット）
"---------------------------------------------------------------
function! s:diff_side_by_side(sha) abort
	let caret = s:is_cmdexe() ? '^^' : '^'
	let filename = s:get_filepath_from_line()

	" 実行元のウィンドウに移動
	execute s:get('ExeWinnr') . 'wincmd w'

	" 新しいタブで左右対比を開く
	tabnew

	" ===== 左ペイン：親コミット（1つ前のリビジョン） =====
	let result = glog#git#git_cmd(['git', '-C', s:get('GitRoot'), 'show', a:sha . caret.':' . filename])
	call s:open_sidebyside(filename, result)
	let left_bufnr = bufnr('%')
	diffthis
	execute 'file [' . a:sha[0:6] . '^] ' . fnamemodify(filename, ':t')

	" 画面を左右に分割
	bel vnew

	" ===== 右ペイン：現在のコミット =====
	let result = glog#git#git_cmd(['git', '-C', s:get('GitRoot'), 'show', a:sha . ':' . filename])
	call s:open_sidebyside(filename, result)
	let right_bufnr = bufnr('%')
	diffthis
	execute 'file [' . a:sha[0:6] . '] ' . fnamemodify(filename, ':t')

	call s:set_sidebyside_pair(left_bufnr, right_bufnr)

	" フォーカスを左ペインに戻す
	wincmd h
endfunction

"---------------------------------------------------------------
" 左右対比差分の表示（HEAD vs ワーキングディレクトリ）
"---------------------------------------------------------------
function! s:diff_side_by_side_head() abort
	let filename = s:get_filepath_from_line()
	if empty(filename) || !filereadable(s:get('GitRoot') . (has('unix') ? '/' : '\') . filename)
		call s:errmsg("No file selected")
		return
	endif

	" 実行元のウィンドウに移動
	execute s:get('ExeWinnr') . 'wincmd w'

	" 新しいタブで左右対比を開く
	tabnew

	" ===== 左ペイン：HEAD のバージョン =====
	let result = glog#git#git_cmd(['git', '-C', s:get('GitRoot'), 'show', 'HEAD:' . filename])
	call s:open_sidebyside(filename, result)
	let left_bufnr = bufnr('%')
	diffthis
	execute 'file [HEAD] ' . fnamemodify(filename, ':t')

	" 画面を左右に分割
	bel vnew

	" ===== 右ペイン：ワーキングディレクトリのバージョン =====
	let working_content = readfile(s:get('GitRoot') . '/' . filename)
	call s:open_sidebyside(filename, working_content)
	let right_bufnr = bufnr('%')
	diffthis
	execute 'file [WORKING] ' . fnamemodify(filename, ':t')

	call s:set_sidebyside_pair(left_bufnr, right_bufnr)

	" フォーカスを左ペインに戻す
	wincmd h
endfunction

"---------------------------------------------------------------
" コミット差分の表示
"---------------------------------------------------------------
function! s:show_diff() abort
	" 行頭のハッシュ値を取得
	let sha = matchstr(getline('.'), '^\v[0-9a-f]+')

	if !empty(sha)
		" カーソルがハッシュのところだったら、Unified形式のdiff
		if sha ==# '0000000'
			let lines = glog#git#git_cmd(['git', '-C', s:get('GitRoot'), 'diff'])
		else
			let lines = glog#git#git_cmd(['git', '-C', s:get('GitRoot'), 'show', sha])
		endif

		" glog起動ウィンドウに移動
		execute s:get('ExeWinnr') . 'wincmd w'

		enew
		setlocal noswapfile
		setlocal filetype=gdiff
		setlocal buftype=nofile

		" 描画
		silent! 0put = lines
		silent! $delete _
		normal! gg

		" 変更禁止
		setlocal nomodifiable

		" バッファ名を設定
		let name = sha ==# '0000000' ? 'WORKING' : sha[0:6]
		execute 'file [' . name . '] '

	else
		" カーソルが個々のファイルのところだったら、side by side形式のdiff
		let sha = s:get_hash(line('.'))
		if sha ==# '0000000'
			call s:diff_side_by_side_head()
		else
			call s:diff_side_by_side(sha)
		endif
	endif
endfunction

"---------------------------------------------------------------
" 指定リビジョンを表示
"---------------------------------------------------------------
function! s:show_revision()
	let sha = s:get_hash(line('.'))
	if empty(sha) || sha ==# '0000000' | return | endif

	let filename = s:get_filepath_from_line()
	if empty(filename) | return | endif

	" gitコマンドを実行
	let lines = glog#git#git_cmd(['git', '-C', s:get('GitRoot'), 'show', sha.':'.filename])

	" glog起動ウィンドウに移動
	execute s:get('ExeWinnr') . 'wincmd w'

	enew
	setlocal noswapfile
	setlocal buftype=nofile
	execute 'setlocal filetype=' . fnamemodify(filename, ':e')

	" 描画
	silent! 0put = lines
	silent! $delete _
	normal! gg

	" 変更禁止
	setlocal nomodifiable

	" バッファ名を設定
	execute 'file [' . sha[0:6] . '] ' . fnamemodify(filename, ':t')
endfunction

"---------------------------------------------------------------
" WORKINGの変更状況を取得
"---------------------------------------------------------------
function! s:get_status() abort
	let lines = glog#git#git_cmd(['git', '-C', s:get('GitRoot'), 'status', '-s', '-uno'])
	return empty(lines) ? [] :
			\ [{
			\ 'sha':  '0000000',
			\ 'date': strftime('%Y-%m-%d'),
			\ 'auther': '',
			\ 'log':  'WORKING',
			\ 'files': lines
			\ }]
endfunction

"---------------------------------------------------------------
" 履歴を取得
"---------------------------------------------------------------
function! s:get_git_history(lognum) abort
	" Gitコマンドの実行（ハッシュ、日付、ログ、ファイルステータスを取得）
	let cmd = ['git', '-C', s:get('GitRoot'), 'log',
				\ glog#git#is_bgjob() ? '--pretty=format:COMMIT:%h|%ad|%an|%s' : '--pretty=format:"COMMIT:%h|%ad|%an|%s"',
				\ glog#git#is_bgjob() ? '--date=format:%Y-%m-%d' : '--date=format:"%Y-%m-%d"',
				\ '--name-status']
	let cmd += s:get('SpecifyFile') ? ['--', s:get('ExeFile')] : []
	let cmd += a:lognum != -1 ? ['-n', a:lognum] : []

	let lines = glog#git#git_cmd(cmd)

	let history = []
	let current_entry = {}
	for line in lines
		if line =~# '^COMMIT:'
			" 新しいコミット行が見つかった場合、これまでのエントリを保存
			if !empty(current_entry)
				call add(history, current_entry)
			endif

			" コミット情報をパースして辞書を初期化
			let parts = split(line[7:], '|') " 'COMMIT:' を除いて分割
			let current_entry = {
				\ 'sha':  parts[0],
				\ 'date': parts[1],
				\ 'auther': parts[2],
				\ 'log':  parts[3],
				\ 'files': []
				\ }
		elseif line =~# '^\([MADRUTC]\)\s'
			" ファイル変更行（M, A, Dなどから始まる行）をリストに追加
			call add(current_entry.files, line)
		endif
	endfor

	" 最後のコミットを追加
	if !empty(current_entry)
		call add(history, current_entry)
	endif

	return history
endfunction

"---------------------------------------------------------------
" コミットファイルリストの取得
"---------------------------------------------------------------
function! s:get_commit_file(sha) abort
	for entry in b:GitHistory
		if entry.sha ==# a:sha
			return entry.files
		endif
	endfor
	return []
endfunction

"---------------------------------------------------------------
" ハッシュ値の取得
"---------------------------------------------------------------
function! s:get_hash(lnum) abort
	let i = a:lnum
	let sha = ''
	while i > 0 && empty(sha)
		let sha = matchstr(getline(i), '^\v[0-9a-f]+')
		let i -= 1
	endwhile
	return sha
endfunction

"---------------------------------------------------------------
" 折り畳み
"---------------------------------------------------------------
function! s:folding(lnum) abort
	let sha = matchstr(a:lnum, '^\v[0-9a-f]+')

	" 折り畳み開始位置
	let start = a:lnum
	if !empty(sha)
		while start > 1 && getline(start) =~# '^\s\+'
			let start -= 1
		endwhile
	endif
	let start += 1

	" 折り畳み終了位置
	let end = start
	while getline(end) =~# '^\s\+'
		let end += 1
	endwhile
	let end -= 1

	" 折り畳み開始から終了までを削除
	setlocal modifiable
	execute printf('silent %d,%ddelete _', start, end)
	normal! k
	setlocal nomodifiable
endfunction

"---------------------------------------------------------------
" コミット情報の表示/非表示
"---------------------------------------------------------------
function! s:toggle_commit_details(key) abort
	let line = getline('.')

	" 行頭のハッシュ値を取得
	let sha = matchstr(line, '^\v[0-9a-f]+')

	if !empty(sha)
		" カーソルがハッシュのところ
		if getline(line('.') + 1) =~# '^\s\+'
			" すでに展開されている場合は折り畳み
			let pos = s:folding(line('.')+1)

		elseif a:key ==# '-'
			" まだ展開されていない場合は履歴データからコミットファイルを取得して展開
			setlocal modifiable
			call append('.', map(copy(s:get_commit_file(sha)), '"  " . v:val'))
			setlocal nomodifiable
		endif

	else
		" カーソルが展開したところだったら折り畳み
		let pos = s:folding(line('.'))
	endif
endfunction

"---------------------------------------------------------------
" git log
"---------------------------------------------------------------
function! glog#log(...) abort
	" 引数取得
	let arg1 = get(a:000, 0, '')
	let arg2 = get(a:000, 1, '')
	let lognum = arg1 =~# '^-\?\d\+$' ? str2nr(arg1) : arg2 =~# '^-\?\d\+$' ? str2nr(arg2) : 20
	let spcify_file = arg1 ==# '.' ? 1 : arg2 ==# '.' ? 1 : 0

	" glog初期化
	if s:glog_init(spcify_file) == 0
		call s:errmsg("Out of git management")
		return
	endif

	" WORKKINGの変更状況とコミット履歴を取得
	let history = s:get_status() + s:get_git_history(lognum)
	if empty(history)
		call s:errmsg("No change. No commit history.")
		return
	endif

	" コミット履歴リストを作成(ハッシュ | yyyy-mm-dd | ログ)
	let output = map(copy(history), 'v:val.sha . " | " . v:val.date . " | " . v:val.log . " " . v:val.auther')

	" 出力用ウィンドウ作成&表示
	call s:open_window('__glog__', 'botright 10 split', output)
	setlocal filetype=glog

	" キーマップを定義
	nnoremap <buffer> <silent> q :close<CR>
	nnoremap <buffer> <silent> p :<C-u>call <SID>show_revision()<CR>
	nnoremap <buffer> <silent> <CR> :<C-u>call <SID>show_diff()<CR>
	nnoremap <buffer> <silent> l :<C-u>call <SID>toggle_commit_details('-')<CR>
	nnoremap <buffer> <silent> h :<C-u>call <SID>toggle_commit_details('+')<CR>

	" git履歴をバッファデータとして持つ
	let b:GitHistory = history
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
