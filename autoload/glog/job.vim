let s:save_cpo = &cpoptions
set cpoptions&vim

"---------------------------------------------------------------
" s:wrap_cmd
"---------------------------------------------------------------
function! s:wrap_cmd(cmd) abort
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

	return cmd
endfunction

"---------------------------------------------------------------
" glog#job#start_job
"---------------------------------------------------------------
function! glog#job#start_job(cmd, opts, cwd, callback_stdout, callback_exit)
	if has('nvim')
		let job = jobstart(a:cmd, extend(a:opts, {
					\ 'cwd'      : a:cwd,
					\ 'on_stdout': function(a:callback_stdout),
					\ 'on_exit'  : function(a:callback_exit),
					\ }))
	else
		let opts = {
					\ 'cwd'    : a:cwd,
					\ 'in_io'  : 'null',
					\ 'out_cb' : function(a:callback_stdout, a:opts),
					\ 'exit_cb': function(a:callback_exit, a:opts),
					\ }
		let job = job_start(s:wrap_cmd(a:cmd), opts)
	endif

	return job
endfunction

"---------------------------------------------------------------
" ジョブ出力を行単位に追加
"---------------------------------------------------------------
function! s:append_job_output(lines, pending, text) abort
	let chunks = split(a:pending[0] . a:text, '\n', 1)
	let a:pending[0] = remove(chunks, -1)
	call extend(a:lines, map(chunks, 'substitute(v:val, "\\r$", "", "")'))
endfunction

"---------------------------------------------------------------
" glog#job#start_job_wait (ジョブの終了を待つ)
"---------------------------------------------------------------
function! glog#job#start_job_wait(cmd, cwd)
	let pending = ['']
	let exit  = []
	let lines = []
	let job = 0
	if has('nvim')
		let s:append_output = { j, data, event ->
				\ !empty(data) ? s:append_job_output(lines, pending,
				\ 		join(data, "\n")) : 0 }
		let job = jobstart(s:wrap_cmd(a:cmd), {
					\ 'cwd': a:cwd,
					\ 'on_stdout': s:append_output,
					\ 'on_stderr': s:append_output })
		let exit = jobwait([job])
	else
		let opts = {
					\ 'cwd'     : a:cwd,
					\ 'in_io'   : 'null',
					\ 'out_cb'  : { j, str -> s:append_job_output(lines, pending, str . "\n") },
					\ 'err_cb'  : { j, str -> s:append_job_output(lines, pending, str . "\n") },
					\ 'exit_cb' : { j, code -> add(exit, code) }}
		let job = job_start(s:wrap_cmd(a:cmd), opts)

		" ジョブの終了を待つ
		call ch_close_in(job)
		while ch_status(job) !~# '^closed$\|^fail$' || job_status(job) ==# 'run'
			sleep 1m
		endwhile
	endif
	if !empty(pending[0])
		call add(lines, pending[0])
	endif

	return [lines, exit[0]]
endfunction

"-------------------------------------------------------
" glog#job#stop_job
"-------------------------------------------------------
function! glog#job#stop_job(job) abort
	if has('nvim')
		if a:job
			silent! call jobstop(a:job)
		endif
	else
		if type(a:job) != type(0)
			silent! call job_stop(a:job)
		endif
	endif
endfunction

"-------------------------------------------------------
" glog#job#stop_job
"-------------------------------------------------------
function! glog#job#exe_job(cmd, cwd) abort
	let save_cwd = getcwd()
	execute 'lcd ' . a:cwd
	try
		let result = systemlist(a:cmd, ' ')
	finally
		execute 'lcd ' . fnameescape(save_cwd)
	endtry
	return [result, v:shell_error]
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
