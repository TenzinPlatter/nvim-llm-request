" Load once
if exists('g:loaded_ai_request')
  finish
endif
let g:loaded_ai_request = 1

" Commands defined in Lua
command! -nargs=* AIRequest lua require('ai-request').request(<q-args>)
