let s:save_cpo = &cpoptions
set cpoptions&vim

"---------------------------------------------------------------
" glog#job#start_job
"---------------------------------------------------------------
function! s:vim_job_close(opts, callback, channel) abort
	let job = ch_getjob(a:channel)
	let exit = get(job_info(job), 'exitval', -1)
	call call(a:callback, [exit], a:opts)
endfunction

function! glog#job#start_job(cmd, opts, cwd, callback_stdout, callback_exit)
	let exit	= []
	let s:lines	= []
	let job		= 0

	if has('nvim')
		let opts = {
					\ 'cwd'			: a:cwd,
					\ 'stdin'		: 'null',
					\ 'on_stdout'	: { job_id, data, event -> call(a:callback_stdout, [job_id, data, event], a:opts) },
					\ 'on_stderr'	: { job_id, data, event -> call(a:callback_stdout, [job_id, data, event], a:opts) },
					\ 'on_exit'		: { job_id, code, event -> call(a:callback_exit, [job_id, code, event], a:opts) },
					\ }
		let job = jobstart(a:cmd, opts)
		let a:opts.job = job
	else
		let opts = {
					\ 'cwd'			: a:cwd,
					\ 'in_io'		: 'null',
					\ 'out_cb'		: { j, str -> add(a:opts.stdoutbuf, str) },
					\ 'err_cb'		: { j, str -> add(a:opts.stdoutbuf, str) },
					\ 'exit_cb'		: { j, code -> add(exit, code) },
					\ 'close_cb'	: function('s:vim_job_close', [a:opts, a:callback_exit]),
					\ }
		let job = job_start(a:cmd, opts)
		let a:opts.job = job
	endif

	return job
endfunction

"---------------------------------------------------------------
" glog#job#start_job_wait (ジョブの終了を待つ)
"---------------------------------------------------------------
function! glog#job#start_job_wait(cmd, cwd)
	let exit	= []
	let lines	= []

	if has('nvim')
		let opts = {
					\ 'cwd'				: a:cwd,
					\ 'stdin'			: 'null',
					\ 'stdout_buffered'	: v:true,
					\ 'stderr_buffered'	: v:true,
					\ 'on_stdout'		: { job_id, data, event -> extend(lines, data) },
					\ 'on_stderr'		: { job_id, data, event -> extend(lines, data) },
					\ }
		let job = jobstart(a:cmd, opts)
		let exit = jobwait([job])
	else
		let opts = {
					\ 'cwd'				: a:cwd,
					\ 'in_io'			: 'null',
					\ 'out_cb'			: { j, str -> add(lines, str) },
					\ 'err_cb'			: { j, str -> add(lines, str) },
					\ 'exit_cb'			: { j, code -> add(exit, code) }}
		let job = job_start(a:cmd, opts)

		" ジョブの終了を待つ
		call ch_close_in(job)
		while ch_status(job) !~# '^closed$\|^fail$' || job_status(job) ==# 'run'
			sleep 1m
		endwhile
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

let &cpoptions = s:save_cpo
unlet s:save_cpo
