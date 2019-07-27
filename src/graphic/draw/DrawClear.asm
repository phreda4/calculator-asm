proc DrawClear uses rbx, rdi, colour
	mov ebx, ecx                    ; rbx = colour

	; calculates the total number of pixels (rax := w*h)
	mov rax, [_gr_draw_target_width]
	mul [_gr_draw_target_height]

	mov edi, dword[_gr_draw_target_buff] ; the destination array (application surface)
	mov ecx,eax                     ; The number of pixels to fill (x * y)
	mov eax, ebx                    ; rax := colour
	rep stosd                       ; repeat for each pixel
	ret
endp