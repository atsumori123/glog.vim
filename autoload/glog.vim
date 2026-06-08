let s:save_cpo = &cpoptions
set cpoptions&vim

let s:glog_name = "__glog__"
let s:diff_buffers = []

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
	let s:glog['ExeBufnr'] = bufnr('%')
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
	return split(trim(getline('.')))[1]
endfunction

"---------------------------------------------------------------
" ファイルタイプの取得
"---------------------------------------------------------------
function! s:get_filetype(filepath)
	let ft = fnamemodify(a:filepath, ':e')
	return get({'h':'c', 'py':'python'}, ft, ft)
endfunction

"---------------------------------------------------------------
" 描画
"---------------------------------------------------------------
function! s:draw(lines) abort
	" 変更許可
	setlocal modifiable

	silent! 0put = a:lines
	silent! $delete _
	normal! gg

	" 変更禁止
	setlocal nomodifiable
endfunction

"---------------------------------------------------------------
" 重複しないバッファ名の取得
"---------------------------------------------------------------
function! s:get_unique_buffer_name(name) abort
	let bname = a:name
	for i in range(1, 1000)
		if !buflisted(bname) | break | endif
		let bname = printf('%s (%d)', a:name, i)
	endfor
	return bname
endfunction

"---------------------------------------------------------------
" ウィンドウ作成
"---------------------------------------------------------------
function! s:open_glog(lines) abort
	let glog_winnr = bufwinnr(s:glog_name)

	if glog_winnr != -1
		" 既にウィンドウがある場合は、ウィンドウに移って内容消去
		if winnr() != glog_winnr
			execute glog_winnr.'wincmd w'
		endif
		setlocal modifiable
		silent %d _
	else
		" ウィンドウが無い場合は作る
		execute 'silent! botright 10 split ' . s:glog_name
		execute 'silent resize 10'
		setlocal buftype=nofile bufhidden=wipe noswapfile
		setlocal nobuflisted
		setlocal nowrap
		setlocal bufhidden=delete
		setlocal winfixheight winfixwidth
		setlocal filetype=glog
	endif

	" 表示
	call s:draw(a:lines)

	" Glogクローズ時に発火
	augroup Glog
		autocmd! * <buffer>
		autocmd BufWinLeave <buffer> call <SID>diff_off(2)
	augroup END
endfunction

"---------------------------------------------------------------
" 左右diff用ウィンドウ作成
"---------------------------------------------------------------
function! s:open_sidebyside(file, lines) abort
	execute 'enew'
	setlocal noswapfile
	execute 'setlocal filetype=' . s:get_filetype(a:file)
	setlocal buftype=nofile
	call s:draw(a:lines)

	" ショートカットキー
	nnoremap <buffer> <silent> q :call <SID>diff_off(1)<CR>

	" ステータス行をクリア
	redraw | echo ""

	return bufnr('%')
endfunction

"---------------------------------------------------------------
" 左右対比差分の表示（親コミット vs 現在のコミット）
"---------------------------------------------------------------
function! s:diff_side_by_side(filename, sha) abort
	let caret = s:is_cmdexe() ? '^^' : '^'

	" 実行元のウィンドウに移動
	execute 'wincmd w'

	" 左ペイン：親コミット（1つ前のリビジョン）
	let result = glog#git#git_cmd(['git', '-C', s:get('GitRoot'), 'show', a:sha . caret.':' . a:filename])
	let bufnr = s:open_sidebyside(a:filename, result)
	call add(s:diff_buffers, bufnr)
	execute 'file [' . a:sha . '^] ' . fnamemodify(a:filename, ':t')
	diffthis

	" 画面を左右に分割
	bel vsplit

	" 右ペイン：現在のコミット
	let result = glog#git#git_cmd(['git', '-C', s:get('GitRoot'), 'show', a:sha . ':' . a:filename])
	let bufnr = s:open_sidebyside(a:filename, result)
	call add(s:diff_buffers, bufnr)
	execute 'file [' . a:sha . '] ' . fnamemodify(a:filename, ':t')
	diffthis

	" フォーカスを左ペインに戻す
	execute 'wincmd h'
endfunction

"---------------------------------------------------------------
" 左右対比差分の表示（HEAD vs ワーキングディレクトリ）
"---------------------------------------------------------------
function! s:diff_side_by_side_head(filename) abort
	" フルパスのファイル名
	let filepath = s:get('GitRoot') . (has('unix') ? '/' : '\') . a:filename

	" 選択項目のファイルが存在するかチェック
	if empty(a:filename) || !filereadable(filepath)
		call s:errmsg("No file selected")
		return
	endif

	" diff表示するウィンドウに移動
	execute 'wincmd w'

	" 左ペイン：HEAD のバージョン
	let result = glog#git#git_cmd(['git', '-C', s:get('GitRoot'), 'show', 'HEAD:' . a:filename])
	let bufnr = s:open_sidebyside(a:filename, result)
	call add(s:diff_buffers, bufnr)
	execute 'file [HEAD] ' . fnamemodify(a:filename, ':t')
	diffthis

	" 画面を左右に分割
	bel vsplit

	" 右ペイン：ワーキングディレクトリのバージョン
	if bufwinnr('^' . filepath . '$') != -1
		execute 'b' . bufnr(filepath)
	else
		execute "edit " . filepath
	endif
	diffthis

	" フォーカスを左ペインに戻す
	execute 'wincmd h'
endfunction

"---------------------------------------------------------------
" diff表示の終了
"---------------------------------------------------------------
function! s:diff_off(close) abort
	" diffモード終了
	windo diffoff

	" diff以外のバッファにスイッチさせる
	let glog_winnr = bufwinnr(s:glog_name)
	let wins = map(getwininfo(), { _, v -> v.winnr })
	call filter(wins, 'v:val != glog_winnr')
	execute (empty(wins) ? glog_winnr : wins[0]) . 'wincmd w'

	if a:close == 1
		execute 'wincmd c'
	endif

	" Glog起動時のバッファにスイッチ
	if buflisted(s:get('ExeBufnr'))
		execute 'b' . s:get('ExeBufnr')
	else
		enew
	endif

	" diffバッファを削除
	let del_buffers = join(filter(copy(s:diff_buffers), 'v:val != -1 && buflisted(v:val)'))
	if !empty(del_buffers) | execute 'bw! ' . del_buffers | endif
	let s:diff_buffers = []

	if a:close != 2
		" Glogにフォーカスを戻す
		execute bufwinnr(s:glog_name) . 'wincmd w' 
	endif
endfunction

"---------------------------------------------------------------
" コミット差分の表示
"---------------------------------------------------------------
function! s:show_diff() abort
	" 行頭のハッシュ値を取得
	let sha = matchstr(getline('.'), '^\v[0-9a-f]+')

	if !empty(sha)
		" カーソルがハッシュ値のところだったら、Unified形式のdiff
		if str2nr(sha) == 0
			let lines = glog#git#git_cmd(['git', '-C', s:get('GitRoot'), 'diff'])
		else
			let lines = glog#git#git_cmd(['git', '-C', s:get('GitRoot'), 'show', sha])
		endif

		" glog起動ウィンドウに移動
		execute s:get('ExeWinnr') . 'wincmd w'

		" 表示
		enew
		setlocal noswapfile
		setlocal filetype=gdiff
		setlocal buftype=nofile
		call s:draw(lines)
		execute 'file ' . s:get_unique_buffer_name('[' . (str2nr(sha) == 0 ? 'WORKING' : sha) . ']')

	else
		" quickfixウィンドウのクローズ
		cclose

		" diffモードを終了
		call s:diff_off(0)

		" Glog以外のウィンドウIDの一覧を取得
		let glog_winid = bufwinid(s:glog_name)
		let wins = map(getwininfo(), { _, v -> v.winid })
		call filter(wins, 'v:val != glog_winid')

		" 複数にウィンドウが分割されている場合は、1つを残して閉じる
		if len(wins) > 1
			for i in range(len(wins) - 1, 1, -1)
				call win_execute(wins[i], 'close')
			endfor
		endif

		" カーソルが個々のファイルのところだったら、side by side形式のdiff
		let filename = s:get_filepath_from_line()
		let sha = s:get_hash(line('.'))
		if str2nr(sha) == 0
			call s:diff_side_by_side_head(filename)
		else
			call s:diff_side_by_side(filename, sha)
		endif
	endif
endfunction

"---------------------------------------------------------------
" 指定リビジョンを表示
"---------------------------------------------------------------
function! s:show_revision()
	" ハッシュ値を取得
	let sha = s:get_hash(line('.'))
	if empty(sha) || str2nr(sha) == 0 | return | endif

	" 選択項目のファイル名を取得
	let filename = s:get_filepath_from_line()
	if empty(filename) | return | endif

	" gitコマンドを実行
	let lines = glog#git#git_cmd(['git', '-C', s:get('GitRoot'), 'show', sha.':'.filename])

	" glog起動ウィンドウに移動
	execute s:get('ExeWinnr') . 'wincmd w'

	" 表示
	enew
	setlocal noswapfile
	setlocal buftype=nofile
	execute 'setlocal filetype=' . s:get_filetype(filename)
	call s:draw(lines)
	execute 'file ' . s:get_unique_buffer_name('[' . sha . '] ' . fnamemodify(filename, ':t'))
endfunction

"---------------------------------------------------------------
" WORKINGの変更状況を取得
"---------------------------------------------------------------
function! s:get_status() abort
	let lines = glog#git#git_cmd(['git', '-C', s:get('GitRoot'), 'status', '-s', '-uno'])
	return empty(lines) ? [] :
			\ [{
			\ 'sha': '',
			\ 'date': strftime('%Y-%m-%d'),
			\ 'auther': '',
			\ 'log':  'WORKING',
			\ 'files': map(copy(lines), { _, val -> substitute(val, '^\s*', '', '') })
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

	" WORKINGのコミットIDを設定（長さは短縮版コミットIDの長さによる）
	if empty(history[0].sha)
		let history[0].sha = repeat("0", len(history[1].sha))
	endif

	" コミット履歴リストを作成(ハッシュ | yyyy-mm-dd | ログ)
	let output = map(copy(history), 'v:val.sha . " | " . v:val.date . " | " . v:val.log . " " . v:val.auther')

	" 出力用ウィンドウ作成&表示
	call s:open_glog(output)

	" キーマップを定義
	nnoremap <buffer> <silent> q :bd<CR>
	nnoremap <buffer> <silent> p :<C-u>call <SID>show_revision()<CR>
	nnoremap <buffer> <silent> <CR> :<C-u>call <SID>show_diff()<CR>
	nnoremap <buffer> <silent> l :<C-u>call <SID>toggle_commit_details('-')<CR>
	nnoremap <buffer> <silent> h :<C-u>call <SID>toggle_commit_details('+')<CR>

	" git履歴をバッファデータとして持つ
	let b:GitHistory = history
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
