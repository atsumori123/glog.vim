"===============================================================
" Original Work:
" Copylight (c) Marco Hinz
" Source: https://github.com/mhinz/vim-signify
"===============================================================

let s:sign_priority = exists('*sign_place') ? 'priority=10' : ''

"-------------------------------------------------------
" s:warning
"-------------------------------------------------------
function! s:warning(msg) abort
	echohl WarningMsg | echomsg a:msg | echohl None
endfunction

"-------------------------------------------------------
" s:escape
"-------------------------------------------------------
function! s:escape(path) abort
	if exists('+shellslash')
		let old_ssl = &shellslash
		if fnamemodify(&shell, ':t') == 'cmd.exe'
			set noshellslash
		else
			set shellslash
		endif
	endif

	let path = shellescape(a:path)

	if exists('old_ssl')
		let &shellslash = old_ssl
	endif

	return path
endfunction

"-------------------------------------------------------
" s:set_buflocal_autocmds
"-------------------------------------------------------
function! s:set_buflocal_autocmds(bufnr) abort
	augroup signify
		execute printf('autocmd! * <buffer=%d>', a:bufnr)

"		execute printf('autocmd BufEnter     <buffer=%d> call sign#start()', a:bufnr)
"		execute printf('autocmd WinEnter     <buffer=%d> call sign#start()', a:bufnr)
		execute printf('autocmd BufWritePost <buffer=%d> call sign#start()', a:bufnr)

		execute printf('autocmd CursorHold   <buffer=%d> call sign#start()', a:bufnr)
"		execute printf('autocmd CursorHoldI  <buffer=%d> call sign#start()', a:bufnr)
"		execute printf('autocmd FocusGained  <buffer=%d> SignifyRefresh', a:bufnr)
"		execute printf('autocmd CmdwinEnter <buffer=%d> let g:signify_cmdwin_active = 1', a:bufnr)
"		execute printf('autocmd CmdwinLeave <buffer=%d> let g:signify_cmdwin_active = 0', a:bufnr)
"		execute printf('autocmd ShellCmdPost <buffer=%d> call sign#start()', a:bufnr)

		" if exists('##VimResume')
		" 	execute printf('autocmd VimResume <buffer=%d> call sign#start()', a:bufnr)
		" endif
	augroup END
endfunction

"-------------------------------------------------------
" s:get_current_signs
"-------------------------------------------------------
function! s:get_current_signs(sy) abort
	let a:sy.internal = {}	" Signifyのサイン
	let a:sy.external = {}	" 他のプラグインのサイン

	let signlist = sign_getplaced(a:sy.buffer)[0].signs
	for sign in signlist
		if sign.name =~# '^Signify'
			" Handle ambiguous signs. Assume you have signs on line 3 and 4.
			" Removing line 3 would lead to the second sign to be shifted up
			" to line 3. Now there are still 2 signs, both one line 3.
			if has_key(a:sy.internal, sign.lnum)
				execute 'sign unplace' a:sy.internal[sign.lnum].id 'buffer='.a:sy.buffer
			endif
			let a:sy.internal[sign.lnum] = { 'type': sign.name, 'id': sign.id }
		else
			let a:sy.external[sign.lnum] = sign.id
		endif
	endfor
endfunction

"-------------------------------------------------------
" s:add_sign
"-------------------------------------------------------
function! s:add_sign(sy, line, type, ...) abort
	" サインを配置する行番号を変更一覧に追加する
	call add(a:sy.lines, a:line)

	" この行にサインが配置済みであることを記録する
	let a:sy.signtable[a:line] = 1

	" 同じ行にSignifyのサインがすでに存在するか確認する。
	if has_key(a:sy.internal, a:line)
		" 既存サインと新しいサインの種類が同じか確認する。
		if a:type == a:sy.internal[a:line].type
			" 同じ種類の場合は既存サインを維持して、そのIDを返す。
			return a:sy.internal[a:line].id
		else
			" 種類が異なる場合は既存サインのIDを再利用する。
			let id = a:sy.internal[a:line].id
		endif
	endif

	" 再利用する既存IDがなければ新しいIDを採番する
	if !exists('id')
		let id = a:sy.signid
		let a:sy.signid += 1
	endif

	" 削除サインの場合は表示内容とハイライトを定義する
	if a:type =~# 'SignifyDelete'
		execute printf('sign define %s text=%s texthl=SignifySignDelete linehl=%s %s',
					\ a:type,
					\ a:1,
					\ g:signify_line_highlight ? 'SignifyLineDelete' : '',
					\ glog#highlight#numhl())
	endif

	" 採番または再利用したIDでサインをバッファに配置する。
	execute printf('sign place %d line=%d name=%s %s buffer=%s',
				\ id,
				\ a:line,
				\ a:type,
				\ s:sign_priority,
				\ a:sy.buffer)

	return id
endfunction

"-------------------------------------------------------
" s:external_sign_present
"-------------------------------------------------------
function! s:external_sign_present(sy, line) abort
	" If sign priority is supported, so are multiple signs per line.
	" Therefore, we can report no external signs present and let
	" g:signify_priority control whether Sy's signs are shown.
	if !empty(s:sign_priority)
		return
	endif
	if has_key(a:sy.external, a:line)
		if has_key(a:sy.internal, a:line)
			" Remove Sy signs from lines with other signs.
			execute 'sign unplace' a:sy.internal[a:line].id 'buffer='.a:sy.buffer
		endif
		return 1
	endif
endfunction

"-------------------------------------------------------
" s:add_signs
"-------------------------------------------------------
function! s:add_signs(sy, ids, start, count, type) abort
	for lnum in range(a:start, a:start + a:count - 1, 1)
		if s:external_sign_present(a:sy, lnum) | continue | endif
		call add(a:ids, s:add_sign(a:sy, lnum, a:type))
	endfor
endfunction

"-------------------------------------------------------
" s:parse_hunk
" Parse a hunk as '@@ -273,3 +267,14' into [old_line, old_count, new_line, new_count]
"-------------------------------------------------------
function! s:parse_hunk(diffline) abort
	let tokens = matchlist(a:diffline, '^@@ -\v(\d+),?(\d*) \+(\d+),?(\d*)')
	return [
				\ str2nr(tokens[1]),
				\ empty(tokens[2]) ? 1 : str2nr(tokens[2]),
				\ str2nr(tokens[3]),
				\ empty(tokens[4]) ? 1 : str2nr(tokens[4])
				\ ]
endfunction

"-------------------------------------------------------
" s:process_diff
"-------------------------------------------------------
function! s:process_diff(sy, diff) abort
	let a:sy.signtable             = {}
	let a:sy.hunks                 = []

	call s:get_current_signs(a:sy)

	" チャンクヘッダーの見方
	" @@ -1,3 +1,3 @@
	"	-1,3 : 変更前のファイル
	"		-   : 変更前のファイルを指す
	"		1,3 : 1行目から始まって、合計3行分の範囲を指す
	"	+1,3 : 変更後のファイル
	"		+   : 変更後のファイルを指す
	"		1,3 : 1行目から始まって、合計3行分の範囲を指す
	for line in filter(a:diff, 'v:val =~ "^@@ "')
		" hunkは差分の @@ ... @@ で囲まれた「ひとまとまりの変更範囲」であり、複数行のhunkでは、各行にサインが置かれるため、ids も複数になる
		let a:sy.lines = []
		let ids        = []

		" チャンクヘッダーから変更範囲を取得する
		let [old_line, old_count, new_line, new_count] = s:parse_hunk(line)

		" 純粋な追加: @@ -5,0 +6,2 @@
		if old_count == 0 && new_count > 0
			call s:add_signs(a:sy, ids, new_line, new_count, 'SignifyAdd')

		" 純粋な削除: @@ -6,2 +5,0 @@
		elseif old_count > 0 && new_count == 0
			" 削除位置に他のプラグインによるサインがあるか確認し、存在する場合は処理を中断(continue)して既存のサインを上書きしない
			if s:external_sign_present(a:sy, new_line) | continue | endif
			" ファイルの先頭行が削除された場合、削除された行が存在しないため、代わりに新ファイルの1行目にサインを置く
			if new_line == 0
				call add(ids, s:add_sign(a:sy, 1, 'SignifyRemoveFirstLine'))
			else
				let text = old_count > 99 ? '_>' : old_count
				call add(ids, s:add_sign(a:sy, new_line, 'SignifyDelete'. old_count, text))
			endif

		" 純粋な変更
		elseif old_count > 0 && new_count > 0 && old_count == new_count
			call s:add_signs(a:sy, ids, new_line, new_count, 'SignifyChange')

		" 編集＋追加
		elseif old_count > 0 && new_count > 0 && old_count < new_count
			call s:add_signs(a:sy, ids, new_line, old_count, 'SignifyChange')
			call s:add_signs(a:sy, ids, new_line + old_count, new_count - old_count, 'SignifyAdd')

		" 一部の行を編集＋一部の行を削除(例えば5行あった部分が3行になった)
		elseif old_count > 0 && new_count > 0 && old_count > new_count
			let deleted_count = old_count - new_count

			" 削除された行は存在しないため、直前の行にサインを置く(先頭行よりも後ろ かつ 既にサインがないこと)
			let prev_line_available = new_line > 1 && !get(a:sy.signtable, new_line - 1, 0)
			if prev_line_available
				let text = old_count > 99 ? '_>' : old_count
				call add(ids, s:add_sign(a:sy, new_line - 1, 'SignifyDelete'. deleted_count, text))
			endif

			let offset = 0
			while offset < new_count
				let line    = new_line + offset
				if s:external_sign_present(a:sy, line) | continue | endif
				if !prev_line_available && offset == 0
					call add(ids, s:add_sign(a:sy, line, 'SignifyChangeDelete'))
				else
					call add(ids, s:add_sign(a:sy, line, 'SignifyChange'))
				endif
				let offset += 1
			endwhile
		endif

		if !empty(ids)
			call add(a:sy.hunks, {
						\ 'ids'  : ids,
						\ 'start': a:sy.lines[0],
						\ 'end'  : a:sy.lines[-1] })
		endif
	endfor

	" Remove obsoleted signs.
	for line in filter(keys(a:sy.internal), '!has_key(a:sy.signtable, v:val)')
		execute 'sign unplace' a:sy.internal[line].id 'buffer='.a:sy.buffer
	endfor
endfunction

"-------------------------------------------------------
" s:wrap_cmd
"-------------------------------------------------------
function! s:wrap_cmd(bufnr, cmd) abort
	if has('win32')
		if has('nvim')
			let cmd = &shell =~ '\v%(cmd|powershell|pwsh)' ? a:cmd : ['sh', '-c', a:cmd]
		else
			" ex: bash.exe -c (コマンド)
			" -c は「後ろに続く文字列をコマンドとして実行する」という意味
			if &shell =~ 'cmd'
				let cmd = join([&shell, &shellcmdflag, '(', a:cmd, ')'])
			elseif empty(&shellxquote)
				let cmd = join([&shell, &shellcmdflag, &shellquote, a:cmd, &shellquote])
			else
				let cmd = join([&shell, &shellcmdflag, &shellxquote, a:cmd, &shellxquote])
			endif
		endif
	else
		let cmd = ['sh', '-c', a:cmd]
	endif
	let options = {
				\ 'stdoutbuf': [''],
				\ 'bufnr': a:bufnr,
				\ }
	return [cmd, options]
endfunction

"-------------------------------------------------------
" s:write_buffer
"-------------------------------------------------------
function! s:write_buffer(bufnr, file)
	" オリジナルのバッファデータ取得
	let bufcontents = getbufline(a:bufnr, 1, '$')

	" 1行目が存在しないか
	if line2byte(1) == -1
		call writefile([], a:file)
		return
	endif

	" DOS形式の場合、一時ファイルの改行をオリジナルと同じにする。line\n→line\r\nに変換する。(LFをCRLFに変換)
	if getbufvar(a:bufnr, '&fileformat') ==# 'dos'
		call map(bufcontents, 'v:val."\r"')
	endif

	" ファイルエンコーディングと文字エンコーディングが異なる場合はファイルエンコーディングに変換
	let fenc = getbufvar(a:bufnr, '&fileencoding')
	let enc  = getbufvar(a:bufnr, '&encoding')
	if fenc !=# enc
		call map(bufcontents, 'iconv(v:val, "'.enc.'", "'.fenc.'")')
	endif

	" BOM(Byte Of Mark)
	if getbufvar(a:bufnr, '&bomb')
		let bufcontents[0]='﻿'.bufcontents[0]
	endif

  	" 差分を取るための一時ファイルに書き込む
	call writefile(bufcontents, a:file)
endfunction

"-------------------------------------------------------
" s:initialize_job
"-------------------------------------------------------
function! s:initialize_job(bufnr) abort
	return s:wrap_cmd(a:bufnr, 'git diff --no-color --no-ext-diff -U0 -- ' . getbufvar(a:bufnr, 'sy').info.file)
endfunction

"-------------------------------------------------------
" s:initialize_buffer_job
"-------------------------------------------------------
function! s:initialize_buffer_job(bufnr) abort
	" バッファデータの一時ファイルを作成
	let bufferfile = tempname()
	call s:write_buffer(a:bufnr, bufferfile)

	" commitバージョンの一時ファイル作成コマンド
	let basefile = tempname()
	let base_cmd = 'git show HEAD:./' . getbufvar(a:bufnr, 'sy').info.file . '>' . fnameescape(basefile) . ' && '

	" コマンド実行形式にする
	let diff_cmd = base_cmd . 'diff -U0 ' . fnameescape(basefile) . ' ' . fnameescape(bufferfile)
	let [cmd, options] = s:wrap_cmd(a:bufnr, diff_cmd)

	" 一時ファイルを記憶
	let options.tempfiles = [basefile, bufferfile]

	return [cmd, options]
endfunction

"-------------------------------------------------------
" s:get_diff
"-------------------------------------------------------
function! s:get_diff(bufnr) abort
	" 前回のジョブが起動中の場合は停止
	call glog#repo#stop_job(getbufvar(a:bufnr, 'sy_job_id'))

	if getbufvar(a:bufnr, '&modified')
		let [cmd, options] = s:initialize_buffer_job(a:bufnr)
		let options.difftool = 'diff'
	else
		let [cmd, options] = s:initialize_job(a:bufnr)
		let options.difftool = 'git'
	endif

	" 今回のジョブ世代番号(前回の世代+1)を取得&保存
	let s:job_gen = get(s:, 'job_gen', 0) + 1
	let options.job_gen = s:job_gen
	call setbufvar(a:bufnr, 'sy_job_gen', s:job_gen)

	" 差分取得のジョブを開始
	let job_id = glog#repo#start_job(cmd, options, getbufvar(a:bufnr, 'sy').info.dir)

	" 今回の新しいジョブIDを保存
	call setbufvar(a:bufnr, 'sy_job_id', job_id)
endfunction


"-------------------------------------------------------
" sign#start
"-------------------------------------------------------
function! sign#start(...) abort
	let bufnr = a:0 ? a:1 : bufnr('')
	let path = resolve(fnamemodify(bufname(bufnr), ':p'))

	if g:signify_locked | return | endif

	if has('vim_starting') | return | endif

	if getbufvar(bufnr, '&diff') || !filereadable(path) | return | endif

	let sy = getbufvar(bufnr, 'sy')
	if empty(sy)
		let new_sy = {
					\ 'buffer':		bufnr,
					\ 'hunks':		[],
					\ 'signid':		0x100,
					\ 'info':		{
					\    'dir':  fnamemodify(path, ':p:h'),
					\    'path': s:escape(path),
					\    'file': s:escape(fnamemodify(path, ':t'))
					\ }}
		call setbufvar(bufnr, 'sy', new_sy)
		call s:set_buflocal_autocmds(bufnr)
		call s:get_diff(bufnr)
	else
		" 実行中のジョブが存在するか確認
		" nvimのjobstart()は数値IDを返すが、vimのjob_start()はジョブオフジェクトを返すため以下の判定にする必要がある
		let job_id = getbufvar(sy.buffer, 'sy_job_id', 0)
		if type(job_id) != type(0) || job_id > 0
		else
			call s:get_diff(sy.buffer)
		endif
	endif
endfunction

"-------------------------------------------------------
" sign#stop
"-------------------------------------------------------
function! sign#stop(...) abort
	let bufnr = bufnr('')
	if empty(getbufvar(a:0 ? a:1 : bufnr, 'sy')) | return | endif
	call s:remove_all_signs(bufnr)
	execute printf('autocmd! signify * <buffer=%d>', bufnr)
	call setbufvar(bufnr, 'sy', {})
endfunction

"-------------------------------------------------------
" sign#toggle
"-------------------------------------------------------
function! sign#toggle() abort
	call call(empty(getbufvar(bufnr(''), 'sy')) ? 'sign#start' : 'sign#stop', [])
endfunction

"-------------------------------------------------------
" sign#jump_hunk
"-------------------------------------------------------
function! sign#jump_hunk(count, direction)
	let sy = getbufvar(bufnr(''), 'sy')
	if empty(sy) || empty(sy.hunks) | return | endif

	let lnum = line('.')
	if a:direction > 0
		let hunks = filter(copy(b:sy.hunks), 'v:val.start > lnum')
		let hunk  = get(hunks, a:count - 1, get(hunks, -1, {}))
	else
		let hunks = filter(copy(b:sy.hunks), 'v:val.start < lnum')
		let hunk  = get(hunks, 0 - a:count, get(hunks, 0, {}))
	endif

	if !empty(hunk)
		execute 'sign jump '. hunk.ids[0] .' buffer='. b:sy.buffer
	endif
endfunction

"-------------------------------------------------------
" sign#set_signs
"-------------------------------------------------------
function! sign#set_signs(sy, diff) abort
	" 差分が無い場合は全てのサインをクリア
	if empty(a:diff)
		call s:warning('No changes found.', 'git')
		call s:remove_all_signs(a:sy.buffer)
		return
	endif

	if get(g:, 'signify_line_highlight')
		call glog#highlight#line_enable()
	else
		call glog#highlight#line_disable()
	endif

	call s:process_diff(a:sy, a:diff)
endfunction

