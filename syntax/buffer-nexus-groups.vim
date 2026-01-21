" Vim syntax file for buffer-nexus groups
" Language: buffer-nexus-groups

if exists("b:current_syntax")
    finish
endif

syn match VBlEditComment /^#.*$/
syn match VBlEditGroupHeader /^\[Group\].*$/
syn match VBlEditBufId /^\s*buf:\d\+/
syn match VBlEditFlags /\s\+\[[^]]\+\]\s*$/
syn match VBlEditArrow /\s\+->\s*/
syn match VBlEditMovePath /^\s*\S\+\ze\s\+->/
syn match VBlEditMoveTarget /->\s\+\S\+$/ contains=VBlEditArrow

highlight default link VBlEditComment Comment
highlight default link VBlEditGroupHeader Title
highlight default link VBlEditBufId Identifier
highlight default link VBlEditFlags Type
highlight default link VBlEditArrow Operator
highlight default link VBlEditMovePath Directory
highlight default link VBlEditMoveTarget String

let b:current_syntax = "buffer-nexus-groups"
