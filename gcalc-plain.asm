; base from Mora/Rodriguez WORK
format PE64 GUI 5.0
entry start

include 'win64a.inc'

section '.text' code readable executable

;;;
; Draws the console log
;
; params:
;   x - The x coordinate of the lower left position of the log text
;   y - The y coordinate of the lower left position of the log text
;;;
proc AppDrawConsoleLog, x:DWORD, y:DWORD
        local i:DWORD, string:QWORD
    mov [x], ecx
    mov [y], edx
        ; i := ArrayListSize(log_input) - 1
        fastcall ArrayListSize, [_gr_log_input]
        dec eax
        mov [i], eax
.console_loop:
        ; if (i >= 0)
        mov eax, [i]
        cmp eax, 0
        jl .end_console_loop
        ; if (y >= 0)
        mov eax, [y]
        cmp eax, 0
        jl .end_console_loop
        ; x = margin_x
        xor eax, eax
        mov al, [_gr_margin_left]
        mov [x], eax
        fastcall ArrayListGet, [_gr_log_output], [i]
    mov [string], rax
    fastcall StringCountChar, rax, 10 ; count the number of LF characters (new lines)
    inc eax
    shl eax, 4 ; rax *= 4
    sub [y], eax
        fastcall DrawPixelText, [x], [y], [string], [_gr_col_muted]
    sub [y], 16
        fastcall DrawPixelText, [x], [y], _gr_str_console_start, [_gr_col_text]
        add [x], 16
        fastcall ArrayListGet, [_gr_log_input], [i]
        fastcall DrawPixelText, [x], [y], rax, [_gr_col_text]
        dec [i]
        jmp .console_loop
.end_console_loop:
    ret
endp

;;;
; This method is called when the app inits. It is the main method
;;;
proc AppInit
    fastcall ConsoleInit
    fastcall ParserInit
    ; Add specific GUI commands
    fastcall ArrayListPush, [_lg_commands_list], _gr_str_cmd_exit
    fastcall ArrayListPush, [_lg_commands_handlers], DoExit
    fastcall ArrayListPush, [_lg_commands_list], _gr_str_cmd_help
    fastcall ArrayListPush, [_lg_commands_handlers], DoHelp
    fastcall ArrayListPush, [_lg_commands_list], _gr_str_cmd_man
    fastcall ArrayListPush, [_lg_commands_handlers], DoMan
    fastcall ArrayListPush, [_lg_commands_list], _gr_str_cmd_clear
    fastcall ArrayListPush, [_lg_commands_handlers], DoClear
    fastcall ArrayListPush, [_lg_commands_list], _gr_str_cmd_zoomplus
    fastcall ArrayListPush, [_lg_commands_handlers], DoZoomPlus
    fastcall ArrayListPush, [_lg_commands_list], _gr_str_cmd_zoomminus
    fastcall ArrayListPush, [_lg_commands_handlers], DoZoomMinus
        ret
endp

proc AppLogOffsetIncrement, offset:DWORD
    add [_gr_log_offset], ecx
    ret
endp

proc AppLogOffsetReset
    mov [_gr_log_offset], 0
    ret
endp

;;;
; This method is called once per frame. It should update the content of the screen
;;;
proc AppUpdate
        local x: DWORD, y: DWORD, len: DWORD, height:DWORD
        ; clear background colour
        fastcall DrawClear, [_gr_col_background]
        ; height = 16 - margin_y - margin_y
        xor eax, eax
        mov al, [_gr_margin_bottom]
        shl eax, 1
        add al, 16
        mov [height], eax
        ; y = app_height - height - margin_y + log_offset
        xor eax, eax
        mov eax, [_gr_app_height]
        sub eax, [height]
        xor edx, edx
        mov dl, [_gr_margin_bottom]
        sub eax, edx
        add eax, [_gr_log_offset]
        mov [y], eax
        ; x = margin_x
        xor eax, eax
        mov al, [_gr_margin_left]
        mov [x], eax
        fastcall AppDrawConsoleLog, [x], [y]
        ; y = APP_HEIGHT - height
        xor ecx, ecx
        mov eax, [_gr_app_height]
        sub eax, [height]
        mov [y], eax
        fastcall DrawRectangle, 0, [y], [_gr_app_width], [height], [_gr_col_dark_background]
        ; x = margin_x
        xor eax, eax
        mov al, [_gr_margin_left]
        mov [x], eax
        ; y -= margin_bottom * 2
        xor eax, eax
        mov al, [_gr_margin_bottom]
        add [y], eax
        fastcall AppDrawInputLine, [x], [y]
        fastcall ArrayListSize, [_gr_log_input]
        cmp eax, 0
        jg .dont_draw_logo
        fastcall AppDrawLogo
.dont_draw_logo:
    ret
endp

proc AppDrawInputLine, x:DWORD, y:DWORD
    mov [x], ecx
    mov [y], edx
        ; draw the ">> " string at the start of the input line
        fastcall DrawPixelText, [x], [y], _gr_str_console_start, [_gr_col_primary]
        add [x], 16
        ; Draw the user input
        fastcall DrawPixelText, [x], [y], _gr_input_buffer, [_gr_col_text]
        ; if current second is odd, don't draw the cursor
        invoke GetSystemTime, _gr_system_time
        mov ax, [_gr_system_time.wSecond]
        test ax, 1
        jne .odd_second
        ; x := x + strlen(input_buffer) * 8
        invoke strlen, _gr_input_buffer
        shl eax, 3
        add [x], eax
        ; Draw the carret
        fastcall DrawPixelText, [x], [y], _gr_str_console_cursor, [_gr_col_primary]
.odd_second:
    ret
endp

proc AppDrawLogo
        local x:DWORD, y:DWORD, scale:DWORD
        mov [scale], 4
        ; x = (APP_WIDTH - logo_w * scale) / 2
        mov eax, [_gr_logo_w]
        imul [scale]
        mov edx, eax
        mov eax, [_gr_app_width]
        sub eax, edx
        shr eax, 1
        mov [x], eax
        ; y = APP_HEIGHT / 4
        mov eax, [_gr_app_height]
        shr eax, 2
        mov [y], eax
        fastcall DrawBufferScaled, _gr_logo_data, [_gr_logo_w], [_gr_logo_h], [x], [y], [scale], [scale]
        ; x = (APP_WIDTH - strlen(str_title) * 8) / 2
        invoke strlen, _gr_str_title
        shl eax, 3
        mov edx, eax
        mov eax, [_gr_app_width]
        sub eax, edx
        shr eax, 1
        mov [x], eax
        ; y = y + logo_h * scale + 20
        xor edx, edx
        mov eax, [_gr_logo_h]
        imul [scale]
        add eax, 20
        add [y], eax
        fastcall DrawPixelTextOutline, [x], [y], _gr_str_title, [_gr_col_title], [_gr_col_secondary]
        add [y], 23
        ; x = (APP_WIDTH - strlen(_gr_str_subtitle) * 8) / 2
        invoke strlen, _gr_str_subtitle
        shl eax, 3
        mov edx, eax
        mov eax, [_gr_app_width]
        sub eax, edx
        shr eax, 1
        mov [x], eax
        fastcall DrawPixelText, [x], [y], _gr_str_subtitle, [_gr_col_muted]
    ret
endp

proc AppRecalculateWindowSize
        ; Get client area size
        invoke GetClientRect, [_gr_whandle], _gr_client_rect
        mov eax, [_gr_client_rect.right]
        mov [_gr_win_width], eax
        mov eax, [_gr_client_rect.bottom]
        mov [_gr_win_height], eax
        xor edx, edx
        ; app_width = win_width / pixel_scale_x
        mov eax, [_gr_win_width]
        cdq
        idiv [_gr_pixel_scale_x]
        mov [_gr_app_width], eax
        ; app_height = win_height / pixel_scale_y
        mov eax, [_gr_win_height]
        cdq
        idiv [_gr_pixel_scale_y]
        mov [_gr_app_height], eax
        ; Initialize bmi
        mov [_gr_bmi.biSize],sizeof.BITMAPINFOHEADER
        mov [_gr_bmi.biPlanes],1
        mov [_gr_bmi.biBitCount],32
        mov [_gr_bmi.biCompression],BI_RGB
        mov ecx, [_gr_win_width]
        mov [_gr_bmi.biWidth],ecx
        mov edx, [_gr_win_height]
        neg edx
        mov [_gr_bmi.biHeight],edx
        mov rax, [_gr_winbuffer]
        test rax, rax
        je .create_buffers
        fastcall BufferResize, [_gr_winbuffer], [_gr_win_width], [_gr_win_height]
        mov [_gr_winbuffer], rax
        fastcall BufferResize, [_gr_appbuffer], [_gr_app_width], [_gr_app_height]
        mov [_gr_appbuffer], rax
        jmp .finish
.create_buffers:
        fastcall BufferCreate, [_gr_win_width], [_gr_win_height]
        mov [_gr_winbuffer], rax
        fastcall BufferCreate, [_gr_app_width], [_gr_app_height]
        mov [_gr_appbuffer], rax
.finish:
        fastcall DrawSetTarget, [_gr_app_width], [_gr_app_height], [_gr_appbuffer]
        ret
endp

;;;
; Thread message Handling. Handles all the incoming window messages of the thread and dispatch them
; to the window. If the thread received an exit event, it closes the window.
;
; returns: (QWORD) 1 if all is ok. 0 if the app must be closed.
;;;
align 16
proc AppThreadProcessMessages
    ; while loop
.peekmessage:
    ;peek the next item in the thread message queue to check if there is any message to process
    invoke PeekMessage,_gr_msg,0,0,0,PM_NOREMOVE
    or      eax,eax
    jz      .return
    ; if there is a message, remove it from the queue
    invoke GetMessage,_gr_msg,0,0,0
    ; if the message is an WM_EXIT message, then exit the app
    or  eax,eax
    jz  .endapp
    ; if not, translate the virtual keys asociated to the message
    ; to real keys (in case the message is a keyboard input message)
    invoke TranslateMessage,_gr_msg
    ; And dispatch the message to the WindowProc
    invoke DispatchMessage,_gr_msg
    ; and repeat the while loop
    jmp .peekmessage
.return:
    xor rax, rax
    inc rax
    ret
.endapp:
    xor rax, rax
    ret
endp


proc ArrayListClear, list:QWORD
    mov DWORD[rcx+4], 0
    ret
endp

proc ArrayListCreate, initialsize: DWORD
    local list: QWORD
    mov [initialsize], ecx

    invoke malloc, 16
    mov [list], rax

    mov ecx, [initialsize]
    mov DWORD[rax + 0], ecx       ; allocsize
    mov DWORD[rax + 4], 0         ; size
    shl ecx, 3
    invoke malloc, ecx
    mov rcx, [list] 
    mov QWORD[rcx + 8], rax        ; list

    mov rax, rcx
    ret
endp

proc ArrayListFree, list: QWORD
    local list: QWORD
    mov [list], rcx
    mov rax, [rcx + 8]        ; list
    invoke free, rax
    invoke free, [list]
    ret
endp

proc ArrayListGet, list:QWORD, index:DWORD
    mov rax, QWORD[rcx+8]
    mov rax, QWORD[rax+rdx*8]
    ret
endp

proc ArrayListGetLast, list:QWORD
    xor rdx, rdx
    mov edx, DWORD[rcx+4]
    dec edx
    mov rax, QWORD[rcx+8]
    mov rax, QWORD[rax+rdx*8]
    ret
endp

proc ArrayListPop, list:QWORD
    xor rdx, rdx
    mov edx, DWORD[rcx+4]
    cmp edx, 0
    je .empty

    ; size -= 1
    dec edx                 
    mov DWORD[rcx + 4], edx
    ; return array[size]
    mov rax, QWORD[rcx+8]
    mov rax, QWORD[rax+rdx*8]
    ret

    .empty:
    xor eax, eax
    ret
endp

proc ArrayListPush, list:QWORD, value:QWORD
    mov [list], rcx
    mov [value], rdx
    
    mov eax, DWORD[rcx + 0]  ; allocsize
    mov edx, DWORD[rcx + 4]  ; size
    cmp edx, eax 
    jl .insert_item

    ; allocsize := allocsize * 2
    shl eax, 1 
    mov DWORD[rcx + 0], eax
    
    ; and allocate more memory
    ; array := realloc(array, allocsize * 8)
    shl eax, 3
    mov rdx, QWORD[rcx + 8]
    invoke realloc, rdx, eax
    mov rcx, [list]
    mov QWORD[rcx + 8], rax

    .insert_item:
    ; array[size] := value
    xor rdx, rdx
    mov edx, DWORD[rcx + 4]
    mov r9, [value]
    mov r8,  QWORD[rcx + 8]  ; array pointer
    mov QWORD[r8+rdx*8], r9
    ; size += 1
    inc edx                 
    mov DWORD[rcx + 4], edx
    ret
endp

proc ArrayListSize, list:QWORD
    xor rax, rax
    mov eax, DWORD[rcx+4]
    ret
endp

proc DoAdd uses r14
    fastcall ArrayListPop, [_lg_stack]
    mov r14, rax
    fastcall ArrayListPop, [_lg_stack]
    add r14, rax
    fastcall ArrayListPush, [_lg_stack], r14
    ret
endp

proc DoAnd uses r14
    fastcall ArrayListPop, [_lg_stack]
    mov r14, rax
    fastcall ArrayListPop, [_lg_stack]
    and r14, rax
    fastcall ArrayListPush, [_lg_stack], r14
    ret
endp

proc DoDivide uses r14
    ; RAX / R14 --> Stack[N-1]/Stack[N]
    fastcall ArrayListPop, [_lg_stack]
    mov r14, rax
    fastcall ArrayListPop, [_lg_stack]
    cqo
    idiv r14
    fastcall ArrayListPush, [_lg_stack], rax
    ret
endp

proc DoRemainder uses r14
    ; RAX / R14 --> Stack[N-1]/Stack[N]
    fastcall ArrayListPop, [_lg_stack]
    mov r14, rax
    fastcall ArrayListPop, [_lg_stack]
    idiv r14
    fastcall ArrayListPush, [_lg_stack], rdx
    ret
endp

proc DoMultiply uses r14
    fastcall ArrayListPop, [_lg_stack]
    mov r14, rax
    fastcall ArrayListPop, [_lg_stack]
    imul r14
    fastcall ArrayListPush, [_lg_stack], rax
    ret
endp

proc DoNeg
    fastcall ArrayListPop, [_lg_stack]
    neg rax
    fastcall ArrayListPush, [_lg_stack], rax
    ret
endp

proc DoNot
    fastcall ArrayListPop, [_lg_stack]
    not rax
    fastcall ArrayListPush, [_lg_stack], rax
    ret
endp

proc DoOr uses r14
    fastcall ArrayListPop, [_lg_stack]
    mov r14, rax
    fastcall ArrayListPop, [_lg_stack]
    or r14, rax
    fastcall ArrayListPush, [_lg_stack], r14
    ret
endp

proc DoPrint
    fastcall ArrayListSize, [_lg_stack]
    cmp eax, 0
    je .empty_stack
    fastcall ArrayListPop, [_lg_stack]
    fastcall PrintDecimal, rax
    fastcall ConsolePrintChar, 32
    ret
    .empty_stack:
    fastcall ConsolePrint, _gr_message_empty_stack
    ret
endp

proc DoPrintBin
    fastcall ArrayListSize, [_lg_stack]
    cmp eax, 0
    je .empty_stack
    fastcall ArrayListPop, [_lg_stack]
    fastcall PrintBinary, rax
    fastcall ConsolePrintChar, 98 ; 'b' character
    fastcall ConsolePrintChar, 32 ; space character
    ret
    .empty_stack:
    fastcall ConsolePrint, _gr_message_empty_stack
    ret
endp


proc DoPrintHex
    fastcall ArrayListSize, [_lg_stack]
    cmp eax, 0
    je .empty_stack
    fastcall ConsolePrintChar, 36 ; '$' character
    fastcall ArrayListPop, [_lg_stack]
    fastcall PrintHexa, rax
    fastcall ConsolePrintChar, 32 ; space character
    ret
    .empty_stack:
    fastcall ConsolePrint, _gr_message_empty_stack
    ret
endp

proc DoPrintStack
    local size:DWORD
    fastcall ArrayListSize, [_lg_stack]
    mov [size], eax
    cmp eax, 0
    je .empty_stack
    .while:
    cmp [size], 0
    jle .endwhile
    dec [size]
    fastcall ArrayListGet, [_lg_stack], [size]
    fastcall PrintDecimal, rax
    fastcall ConsolePrintChar, 10
    jmp .while
    .endwhile:
    ret
    .empty_stack:
    fastcall ConsolePrint, _gr_message_empty_stack
    ret
endp

proc DoSubstract uses r14
fastcall ArrayListPop, [_lg_stack]
    mov r14, rax
    fastcall ArrayListPop, [_lg_stack]
    sub r14, rax
    fastcall ArrayListPush, [_lg_stack], r14
    ret
endp

proc DoXor uses r14
    fastcall ArrayListPop, [_lg_stack]
    mov r14, rax
    fastcall ArrayListPop, [_lg_stack]
    xor r14, rax
    fastcall ArrayListPush, [_lg_stack], r14
    ret
endp


proc DoClear
    fastcall InputBufferClear
    fastcall OutputBufferClear
    fastcall ConsoleClear
    ret
endp

proc DoExit
    invoke      PostQuitMessage,0
    fastcall ConsolePrint, _gr_message_byebye
    ret
endp

proc DoHelp
    invoke ShellExecute, 0, 0, _gr_str_help_url, 0, 0, SW_SHOW
    fastcall ConsolePrint, _gr_message_showing_help
    ret
endp

proc DoMan
    fastcall ConsolePrint, _gr_message_mandata
    ret
endp

proc DoZoomMinus
    mov eax, [_gr_pixel_scale_x]
    cmp eax, [_gr_pixel_scale_min]
    jle .error
    dec [_gr_pixel_scale_x]
    dec [_gr_pixel_scale_y]
    fastcall AppRecalculateWindowSize
    ret
.error:
    fastcall ConsolePrint, _gr_message_minimum_zoom
    ret
endp

proc DoZoomPlus
    mov eax, [_gr_pixel_scale_x]
    cmp eax, [_gr_pixel_scale_max]
    jge .error
    inc [_gr_pixel_scale_x]
    inc [_gr_pixel_scale_y]
    fastcall AppRecalculateWindowSize
    ret
.error:
    fastcall ConsolePrint, _gr_message_maximum_zoom
    ret
endp


;;;
; Inits the console log system
;;;
proc ConsoleInit
    fastcall InputBufferClear
    fastcall OutputBufferClear
    ; Create two parallel lists for storing the input log and the output log
    fastcall ArrayListCreate, 16
    mov [_gr_log_input], rax
    fastcall ArrayListCreate, 16
    mov [_gr_log_output], rax
    ret
endp

;;;
; Clears all the console log
;;;
proc ConsoleClear
    local size:DWORD
    fastcall ArrayListSize, [_gr_log_input]
    mov [size], eax
    jmp .done
    .while:
    cmp [size], 0
    dec [size]
    fastcall ArrayListGet, [_gr_log_input], [size]
    invoke free, rax
    fastcall ArrayListGet, [_gr_log_output], [size]
    invoke free, rax
    jmp .while
.done:
    fastcall ArrayListClear, [_gr_log_input]
    fastcall ArrayListClear, [_gr_log_output]
    ret
endp

;;;
; Adds a command into the console log
;
; params:
;   str_input  - The input string (what the user typed)
;   str_output - The output string (The command response)
;;;
proc ConsoleAddCommand, str_input:QWORD, str_output:QWORD
    mov [str_input], rcx
    mov [str_output], rdx
    fastcall StringClone, [str_input]
    fastcall ArrayListPush, [_gr_log_input], rax
    fastcall StringClone, [str_output]
    fastcall ArrayListPush, [_gr_log_output], rax
    ret
endp

;;;
; Sends the content of the input and output buffer to the console log,
; clearing both buffers.
;;;
proc ConsoleFlushBuffers
    mov ax, [_gr_output_char_count]
    cmp ax, 0
    jne .input_buffer_has_content ; output buffer empty
    fastcall ConsolePrint, _gr_str_ok
.input_buffer_has_content:
    mov al, [_gr_input_char_count]
    cmp al, 0
    je .done ; input buffer empty
    fastcall ConsoleAddCommand, _gr_input_buffer, _gr_output_buffer
.done:
    fastcall InputBufferClear
    fastcall OutputBufferClear
    ret
endp

proc ConsoleInputHandle, input: QWORD
    fastcall AppLogOffsetReset
    fastcall ParserParseString, rcx
    fastcall ConsoleFlushBuffers
    ret
endp

;;;
; Prints the string on the console. The string will be appended to the current output string.
; It not be shown on screen until the command finishes its execution.
; 
; params:
;   string - The string to print
;;;
proc ConsolePrint, string:QWORD
    fastcall OutputBufferAddString, rcx
    ret
endp

;;;
; Prints the string on the console and starts a new line. 
; The string will be appended to the current output string.
; It not be shown on screen until the command finishes its execution.
; 
; params:
;   string - The string to print
;;;
proc ConsolePrintLine, string:QWORD
    fastcall OutputBufferAddString, rcx
    fastcall OutputBufferAddString, _gr_str_newline
    ret
endp

;;;
; Prints the character on the console. The character will be appended to the current output string.
; It not be shown on screen until the command finishes its execution.
;
; params:
;   char - The character to print
;;;
proc ConsolePrintChar, char:BYTE
    fastcall OutputBufferAddChar, cl
    ret
endp

;;;
; Prints _int as a binary number.
; User uses the '.b' command to print the stack's top as a binary number.
;;;
proc PrintBinary uses rax rdx rcx, _int:QWORD ; _int saved in rcx
     mov rax, -64        ; counter
     mov rbx, 1          ; bitmask
     shl rbx, 63
     xor rdx, rdx
.mainloop:
    test rcx, rbx ; Compares MSB with 1 
    jz .zero
    shl rcx, 1
    mov rdx, 49     ; Prints '1' = ascii 49
    jmp .eval
.zero:
    shl rcx, 1
    mov rdx, 48     ; Prints '0'  = ascii 48
.eval:
    push rcx rax rbx
    fastcall ConsolePrintChar, dl
    pop rbx rax rcx
    add rax, 1
    jnz .mainloop
.done:
    ret
endp

;;;
; Prints _int as a hexadecimal number.
; User uses the '.h' command to print the stack's top as a hexadecimal number.
;;;
proc PrintHexa uses rax rcx rdx r14 , _int:QWORD ; _int saved in rcx
    local _array:QWORD, _rem:QWORD, _num:QWORD, _i:WORD
    mov [_num], rcx
    fastcall ArrayListCreate, 10    ; Creates aux array
    mov [_array], rax
.mainloop:
    cmp [_num],0
    je .print
    ; _num = _num / 16
    ; _rem = _num % 16 
    mov rax, [_num]
    cqo
    mov r14, 16
    idiv r14
    mov [_num], rax
    mov [_rem], rdx
    ; if (_rem < 10) then
    cmp [_rem], 10
    jge .greater
    add [_rem], 48
    fastcall ArrayListPush, [_array], [_rem]
    jmp .mainloop
.greater:
    add [_rem], 55
    fastcall ArrayListPush, [_array], [_rem]
    jmp .mainloop
.print:
    fastcall ArrayListSize, [_array]
    cmp eax, 0
    je .done
    fastcall ArrayListPop, [_array]
    fastcall ConsolePrintChar, al
    jmp .print
.done:
    fastcall ArrayListFree, [_array]
    ret
endp


proc PrintDecimal, number:QWORD
    mov [number], rcx
    invoke sprintf, _lg_convert_decimal_buffer, _lg_convert_decimal_format, [number]
    fastcall ConsolePrint, _lg_convert_decimal_buffer
    ret
endp

;;;
; Converts _str from String to Decimal
; Used to cast Strings to Decimal
;;;
proc StringDecimalToInteger uses rbx, _str:QWORD ; _str saved in rcx
    mov [_str], rcx            ; The String   
    xor rax,rax                ; The output value
    xor r8,r8                  ; Current character
    xor rbx, rbx               ; Character Index
.mainloop:
    ; r8b := str[rbx]
    mov r8b, byte [rcx + rbx]   ; Gets a character from the string
    cmp r8b, 0
    je .done
    ; if (dl >= '0' && dl <= '9')
    cmp r8b, '0'
    jl .error
    cmp r8b, '9'
    jg .error
    sub r8b, '0'                ; Current Byte - ASCII 48 = Decimal Number
    ; rax := (rax * 10) + r8b
    imul rax, 10
    add rax, r8
    ; rbx += 1
    inc rbx
    jmp .mainloop
.done:
    ret
.error:
    fastcall ParserShowUnexpectedChar, r8b
    ret
endp

;;;
; Creates a new pixel colour buffer of the specified width and height
; You must free() the memory when you dont use the buffer anymore
;
; params:
;   width  - The width of the buffer
;   height - The height of the buffer
; 
; returns: (QWORD) A pointer to the created buffer
;;;
proc BufferCreate, width:DWORD, height:DWORD
    ; eax := width * height * 4
    mov eax, ecx
    mul edx
    shl eax, 4
    invoke malloc, eax
    cmp eax, 0
    je .error
    ret
.error:
    invoke      MessageBox,NULL,_gr_str_error,NULL,MB_ICONERROR+MB_OK
    ret
endp

;;;
; Resizes a buffer
; params:
;   buffer - The buffer to resize
;   width  - The width of the buffer
;   height - The height of the buffer
; 
; returns: (QWORD) A pointer to the new buffer
;;;
proc BufferResize, buffer:QWORD, width:DWORD, height:DWORD
    mov [buffer], rcx
    ; eax := width * height * 4
    xor rax, rax
    mov eax, edx
    mul r8d
    shl eax, 4
    invoke realloc, [buffer], eax
    cmp eax, 0
    je .error
    ret
.error:
    invoke      MessageBox,NULL,_gr_str_error,NULL,MB_ICONERROR+MB_OK
    ret
endp

;;;
; Draws the specified buffer on the current target buffer
; 
; params:
;   buffer       - The memory address of the first pixel data of the sprite
;   bufferwidth  - The width of the line
;   bufferheight - The height of the line
;   x            - The destination x position
;   y            - The destination y position
;;;
proc DrawBuffer, buffer:QWORD, bufferwidth:DWORD, bufferheight:DWORD, x:DWORD, y:DWORD
    local i:DWORD, j:DWORD, xstart:DWORD
    mov [buffer], rcx
    mov [bufferwidth], edx
    mov [bufferheight], r8d
    mov [x], r9d
    mov [xstart], r9d
    ; for (i = 0; i < bufferheight; i++)
    mov [i], 0
.for_i:
    mov eax, [i]
    cmp eax, [bufferheight]
    jnl .endfor_i
    mov r9d, [xstart]
    mov [x], r9d               ; x := xstart
    ; for (j = 0; j < bufferwidth; j++)
    mov [j], 0
.for_j:
    mov eax, [j]
    cmp eax, [bufferwidth]
    jnl .endfor_j
    mov rax, [buffer]
    fastcall DrawPixel, [x], [y], DWORD [rax]
    ; buffer += 4;
    mov rax, [buffer]
    add rax, 4
    mov [buffer], rax
    inc [x]
    inc [j]
    jmp .for_j
.endfor_j:
    inc [y]
    inc [i]
    jmp .for_i
.endfor_i:
    ret
endp

;;;
; Draws the specified buffer on the current target buffer scaling it
; 
; params: 
;   buffer       - The memory address of the first pixel data of the sprite
;   bufferwidth  - The width of the line
;   bufferheight - The height of the line
;   x            - The destination x position
;   y            - The destination y position
;   scalex       - The width of each pixel
;   scaley       - The height of each pixel
;;;
proc DrawBufferScaled, buffer:QWORD, bufferwidth:DWORD, bufferheight:DWORD, x:DWORD, y:DWORD, scalex:DWORD, scaley:DWORD
    local i:DWORD, j:DWORD, xstart:DWORD
    mov [buffer], rcx
    mov [bufferwidth], edx
    mov [bufferheight], r8d
    mov [x], r9d
    mov [xstart], r9d
    ; for (i = 0; i < bufferheight; i++)
    mov [i], 0
.for_i:
    mov eax, [i]
    cmp eax, [bufferheight]
    jnl .endfor_i
    mov r9d, [xstart]
    mov [x], r9d               ; x := xstart
    ; for (j = 0; j < bufferwidth; j++)
    mov [j], 0
.for_j:
    mov eax, [j]
    cmp eax, [bufferwidth]
    jnl .endfor_j
    mov rax, [buffer]
    fastcall DrawRectangle, [x], [y], [scalex], [scaley], QWORD [rax]
    ; buffer += 4;
    mov rax, [buffer]
    add rax, 4
    mov [buffer], rax
    mov eax, [scalex]
    add [x], eax
    inc [j]
    jmp .for_j
.endfor_j:
    mov eax, [scaley]
    add [y], eax
    inc [i]
    jmp .for_i
.endfor_i:
    ret
endp

;;;
; Clears all the screen using a colour
;
; params:
;       colour - The colour to clear the screen in format ($AARRGGBB). Eg: $ffff0000 for a red colour
;;;
proc DrawClear uses rbx rdi, colour: DWORD
        mov ebx, ecx                    ; rbx = colour
        ; calculates the total number of pixels (rax := w*h)
        mov rax, [_gr_draw_target_width]
        mul [_gr_draw_target_height]
        mov rdi, [_gr_draw_target_buff] ; the destination array (application surface)
        mov ecx,eax                     ; The number of pixels to fill (x * y)
        mov eax, ebx                    ; rax := colour
        rep stosd                       ; repeat for each pixel
        ret
endp

;;;
; Sets the drawing target surface used by all the other drawing functions
; 
; params:
;   width  - The width of the surface
;   height - The height of the surface
;   buffer - A pointer to the colour buffer array
;;;
proc DrawSetTarget, width:DWORD, height:DWORD, buffer:QWORD
    mov  [_gr_draw_target_width], rcx
    mov  [_gr_draw_target_height], rdx
    mov  [_gr_draw_target_buff], r8
    ret
endp


;;;
; Draws a pixel on the screen
; 
; params: 
;   x   - The x position 
;   y   - The y position
;   col - The colour to fill the pixel
;;;
proc DrawPixel uses rbx, x:DWORD, y:DWORD, colour:DWORD
    ; if (x >= dest_w) return;
    mov rax, [_gr_draw_target_width]
    cmp rcx, rax
    jge .return
    ; if (y >= dest_y) return;
    mov rbx, [_gr_draw_target_height]
    cmp rdx, rbx
    jge .return
    ; alphatest
    ; if (col.alpha == 0) return;
    mov ebx, r8d
    and ebx, $FF000000 ; get only the alpha value
    jz .return
    mul rdx
    add rax, rcx
    mov rbx, [_gr_draw_target_buff]
    mov dword[rbx+rax*4],r8d    ; puts col in SOURCE_BUFFER[eax]
.return:
    ret
endp

;;;
; Draws an ascii character on the screen using the default pixel font included
;
; params:
;   x      - The x position of the character
;   y      - The y position of the character
;   char   - The ascii character to draw
;   colour - The colour to use
;;;
proc DrawPixelChar uses r14, x: DWORD, y:DWORD, char:BYTE, colour: DWORD
    local pbuff:QWORD, i:BYTE, j:BYTE, xstart: DWORD
    mov [x], ecx
    mov [y], edx
    mov [char], r8b
    mov [colour], r9d
    mov [xstart], ecx
    ; The font is 1 bit per pixel
    ; width is 8, height is 16 (4 bytes)
    ; pbuff = font[character << 4]
    xor rcx, rcx
    mov cl, r8b
    mov rax, 16
    mul rcx
    add rax, font
    mov [pbuff], rax
    ; while (i < 16)
    mov [i], 0
    .while_i:
    mov al, [i]
    cmp al, 16
    jnl .end_while_i
    mov r14, [pbuff]
    ;x := xstart
    mov ecx, [xstart]
    mov [x], ecx
    mov [j], 7
    .while_j:
    mov al, [j]
    cmp al, 0
    jl .endwhile_j
    mov r15, [r14]
    mov cl, al
    shr r15, cl
    test r15, 1
    jz .skip_1
    fastcall DrawPixel, [x], [y], [colour]
    .skip_1:
    inc [x]
    dec [j]
    jmp .while_j
.endwhile_j:
    inc [y]
    inc [i]
    inc [pbuff]
    jmp .while_i
.end_while_i:
    ret
endp

;;;
; Draws a null terminated string on the screen using the default included pixel font.
; This function uses the LF (0xA) character as a line break
;
; params:
;   x      - The x position of the character
;   y      - The y position of the character
;   string - A pointer to the null terminated string to draw
;   colour - The colour to use
;;;
proc DrawPixelText, x:DWORD, y:DWORD, string:QWORD, colour:DWORD
    local i:DWORD, xstart: DWORD
    mov [x], ecx
    mov [xstart], ecx
    mov [y], edx
    mov [string], r8
    mov [colour], r9d
    mov [i], 0
.while:
    ; calculate eax = string[i]
    mov rcx, [string]
    add ecx, [i]
    mov al, [rcx]
    ; while eax != 0 (while is not a NULL character)
    test al, al
    jz .finish
    cmp al, 10 ; if it's a LF character
    je .linefeed
    cmp al, 13 ; if it's a CR character
    je .skipdraw
    fastcall DrawPixelChar, [x], [y], al, [colour]
.skipdraw:
    inc [i]
    add [x], 8
    jmp .while
.linefeed:
    inc [i]
    mov eax, [xstart]
    mov [x], eax
    add [y], 16
    jmp .while
.finish:
    ret
endp


proc DrawPixelTextOutline, x:DWORD, y:DWORD, string:QWORD, innercolour:DWORD, outlinecolour:DWORD
    mov [x], ecx
    mov [y], edx
    mov [string], r8
    mov [innercolour], r9d
    ; draw text outline
    dec [x]
    dec [y]
        fastcall DrawPixelText, [x], [y], [string], [outlinecolour]
    inc [y]
        fastcall DrawPixelText, [x], [y], [string], [outlinecolour]
    inc [y]
        fastcall DrawPixelText, [x], [y], [string], [outlinecolour]
    inc [x]
        fastcall DrawPixelText, [x], [y], [string], [outlinecolour]
    dec [y]
    dec [y]
        fastcall DrawPixelText, [x], [y], [string], [outlinecolour]
    inc [x]
        fastcall DrawPixelText, [x], [y], [string], [outlinecolour]
    inc [y]
        fastcall DrawPixelText, [x], [y], [string], [outlinecolour]
    inc [y]
        fastcall DrawPixelText, [x], [y], [string], [outlinecolour]
        ; draw text interior
    dec [x]
    dec [y]
        fastcall DrawPixelText, [x], [y], [string], [innercolour]
    ret
endp

;;;
; Draws an horizontal line
;
; params:
;   x     - The starting x position
;   y     - The starting y position
;   width - The width of the line
;   col   - The color to fill the line
;;;
proc DrawLineHorizontal, x:DWORD, y:DWORD, width:DWORD, colour:DWORD
    mov [x], ecx
    mov [y], edx
    mov [width], r8d
    mov [colour], r9d
    ; while (width != 0) then
    cmp r8, 0
    jz .endwhile
.while:
    fastcall DrawPixel, [x], [y], [colour]
    inc [x]
    dec [width]
    jnz .while
.endwhile:
    ret
endp

;;;
; Draws a rectangle filled with the specified colour
;
; Arguments: 
;   x      - The starting x position 
;   y      - The starting y position
;   width  - The width of the rectangle
;   height - The height of the rectangle
;   col    - The color to fill the rectangle
;;; 
proc DrawRectangle, x:DWORD, y:DWORD, width:DWORD, height:DWORD, colour:DWORD
    mov [x], ecx
    mov [y], edx
    mov [width], r8d
    mov [height], r9d
    ; while (height != 0)
    cmp [height], 0
    jz .endwhile
.while:
    fastcall   DrawLineHorizontal, [x], [y], [width], [colour]
    inc [y]
    dec [height]
    jnz .while
.endwhile:
    ret
endp

;;;
; Adds a character to the input buffer
;
; params
;   char - The character to add
;;;
proc InputBufferAddChar, char:BYTE
    ; if (char_count = 254) then return
    mov dl, [_gr_input_char_count]
    cmp dl, 254
    je .finish
    ; buffer[char_count] = char;
    mov dl, [_gr_input_char_count]
    mov rax, _gr_input_buffer
    add al, dl
    mov BYTE[rax], cl
    ; char_count += 1
    inc [_gr_input_char_count]
    inc rax
    ; buffer[char_count] = NULL;
    ; This ensures the string always terminates with NULL
    mov BYTE[rax], 0
.finish:
    ret
endp

;;;
; Removes the last character in the input buffer
;;;
proc InputBufferRemoveChar
    ; if (char_count = 0) then return
    mov dl, [_gr_input_char_count]
    cmp dl, 0
    je .finish
    ; char_count -= 1
    dec [_gr_input_char_count]
        dec dl
    ; buffer[char_count] = NULL;
    ; This ensures the string always terminates with NULL
    mov rax, _gr_input_buffer
    add al, dl
    mov BYTE[rax], 0
.finish:
    ret
endp

;;;
; Clear all characters from the input buffer
;;;
proc InputBufferClear
    mov [_gr_input_buffer], 0       ; puts NULL at the first character in the buffer
    mov [_gr_input_char_count], 0   ; resets the character count
    ret
endp

proc InputOnChar, char:WORD
    cmp cl, 0 ; NULL (0x00) = Backspace character
    je .done
    cmp cl, 8 ; BS (0x08) = Backspace character
    je .backspace
    cmp cl, 10 ; LF (0x0A) = Line feed character
    je .linefeed
    cmp cl, 13 ; CR (0x0D) = Carriage return
    je .linefeed
    fastcall InputBufferAddChar, cl
    ret
.backspace:
    fastcall InputBufferRemoveChar
    ret
.linefeed: ; enter key
    fastcall ConsoleInputHandle, _gr_input_buffer
    ret
.done:
    ret
endp

;;;
; Handles the keyboard input for the input field.
;
; params:
;   keycode - The windows virtual key code for the key that was pressed
;;;
proc InputOnKeyDown, keycode:QWORD
    ; Complete list of keycodes: https://docs.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes
    mov [keycode], rcx
.non_numpad:
    ; switch
    cmp rcx, VK_PRIOR
    je .vkprior
    cmp rcx, VK_NEXT
    je .vknext
    cmp rcx, VK_END
    je .vkend
    jmp .finish
.vkprior: ; Page up
    fastcall AppLogOffsetIncrement, 8
    jmp .finish
.vknext: ; Page down
    fastcall AppLogOffsetIncrement, -8
    jmp .finish
.vkend: ; END key
    fastcall AppLogOffsetReset
    jmp .finish
.finish:
    ; do nothing
    ret
endp

proc InputOnMouseWheel, delta:WORD
    xor eax, eax
    mov ax, cx
    cwd
    mov cx, 120
    idiv cx
    cwde
    shl eax, 4
    fastcall AppLogOffsetIncrement, eax
    ret
endp

;;;
; Add the given string to the output buffer
;
; params:
;   string - The string to add to the output buffer
;;;
proc OutputBufferAddString, string:QWORD
    mov [string], rcx
    mov rax, _gr_output_buffer
    add ax, [_gr_output_char_count]
    invoke strcpy, rax, [string]
    invoke strlen, rax
    add ax, [_gr_output_char_count]
    mov [_gr_output_char_count], ax
    ret
endp

;;;
; Add the given ascii character to the output buffer
;
; params:
;   char - The character to add to the output buffer
;;;
proc OutputBufferAddChar, char:BYTE
    ; buffer[char_count] = char;
    mov dx, [_gr_output_char_count]
    mov rax, _gr_output_buffer
    add ax, dx
    mov BYTE[rax], cl
    ; char_count += 1
    inc [_gr_output_char_count]
    inc rax
    ; buffer[char_count] = NULL;
    ; This ensures the string always terminates with NULL
    mov BYTE[rax], 0
    ret
endp

;;;
; Clear all characters from the output buffer
;;;
proc OutputBufferClear
    mov [_gr_output_buffer], 0       ; puts NULL at the first character in the buffer
    mov [_gr_output_char_count], 0   ; resets the character count
    ret
endp

proc ParserCommandAddChar, character
    mov rdx, [_lg_buffer_length]
    mov byte[_lg_buffer_str + rdx], cl
    inc [_lg_buffer_length]
    ret
endp

;;;
; Process the contents of the command buffer and executes the asociated command
; If the buffer is empty, this function does nothing
;;;
proc ParserCommandFinish
    ; if (buffi != 0)
    mov rdx, [_lg_buffer_length]
    cmp rdx, 0
    jz .done
    ; buff[buffi] = 0;
    mov byte[_lg_buffer_str + rdx], 0
    ; buffi = 0
    mov [_lg_buffer_length], 0
    fastcall ParserCommandProcess, _lg_buffer_str
    .done:
    ret
endp

;;;
; Process a new string instruction. 
; The available recognized string commands are:
; "+", "-", "*", "/", "%", "or", "and", "xor", "not", "neg" (case insensitive)
; any other string will be parsed as an integer and pushed onto the stack.
;;;
proc ParserCommandProcess, string
    local i:DWORD, size:DWORD, lowercase_string:QWORD
    mov [string], rcx
    mov [i], 0
    fastcall StringClone, [string]
    mov [lowercase_string], rax
    fastcall StringToLower, [lowercase_string]
    fastcall ArrayListSize,[_lg_commands_list]
    mov [size], eax   

    .while: 
    mov eax, [i]
    cmp eax, [size]
    jge .not_found 

    fastcall ArrayListGet,[_lg_commands_list], [i]
    invoke strcmp, rax, [lowercase_string]

    cmp rax, 0
    jne .not_equals

    fastcall ArrayListGet,[_lg_commands_handlers], [i]

    ; execute handler
    call rax
    jmp .done

    .not_equals:
    inc [i]
    jmp .while

    jmp .done

    .not_found:
    mov rax, [lowercase_string]
    mov al, BYTE[rax]
    cmp al, '0'
    jl .is_not_number
    cmp al, '9'
    jg .is_not_number

    fastcall StringDecimalToInteger, [string]
    fastcall ArrayListPush, [_lg_stack], rax
    jmp .done
    
    .is_not_number:
    fastcall ConsolePrint, _gr_message_unknown
    fastcall ConsolePrint, [string]
    fastcall ConsolePrint, _gr_message_type_help

    .done:
    invoke free, [lowercase_string]
    ret
endp

proc ParserInit
    ; The stack used by the calculator
    fastcall ArrayListCreate, 20
    mov [_lg_stack], rax
    ; Create two parallel lists
    fastcall ArrayListCreate, 15
    mov [_lg_commands_list], rax
    fastcall ArrayListCreate, 15
    mov [_lg_commands_handlers], rax
    fastcall ArrayListPush, [_lg_commands_list], _lg_command_add
    fastcall ArrayListPush, [_lg_commands_handlers], DoAdd
    fastcall ArrayListPush, [_lg_commands_list], _lg_command_substract
    fastcall ArrayListPush, [_lg_commands_handlers], DoSubstract
    fastcall ArrayListPush, [_lg_commands_list], _lg_command_multiply
    fastcall ArrayListPush, [_lg_commands_handlers], DoMultiply
    fastcall ArrayListPush, [_lg_commands_list], _lg_command_divide
    fastcall ArrayListPush, [_lg_commands_handlers], DoDivide
    fastcall ArrayListPush, [_lg_commands_list], _lg_command_remainder
    fastcall ArrayListPush, [_lg_commands_handlers], DoRemainder
    fastcall ArrayListPush, [_lg_commands_list], _lg_command_or
    fastcall ArrayListPush, [_lg_commands_handlers], DoOr
    fastcall ArrayListPush, [_lg_commands_list], _lg_command_and
    fastcall ArrayListPush, [_lg_commands_handlers], DoAnd
    fastcall ArrayListPush, [_lg_commands_list], _lg_command_xor
    fastcall ArrayListPush, [_lg_commands_handlers], DoXor
    fastcall ArrayListPush, [_lg_commands_list], _lg_command_not
    fastcall ArrayListPush, [_lg_commands_handlers], DoNot
    fastcall ArrayListPush, [_lg_commands_list], _lg_command_neg
    fastcall ArrayListPush, [_lg_commands_handlers], DoNeg
    fastcall ArrayListPush, [_lg_commands_list], _lg_command_print
    fastcall ArrayListPush, [_lg_commands_handlers], DoPrint
    fastcall ArrayListPush, [_lg_commands_list], _lg_command_print_hex
    fastcall ArrayListPush, [_lg_commands_handlers], DoPrintHex
    fastcall ArrayListPush, [_lg_commands_list], _lg_command_print_bin
    fastcall ArrayListPush, [_lg_commands_handlers], DoPrintBin
    fastcall ArrayListPush, [_lg_commands_list], _lg_command_print_stack
    fastcall ArrayListPush, [_lg_commands_handlers], DoPrintStack
    ret
endp

;                       ### Parses a String ###
;------------------------------------------------------------------------
; Used to parse Strings.
; Pseudocode: https://repl.it/repls/OutrageousHeftyPhases
;------------------------------------------------------------------------

proc ParserParseString uses rbx, _str:QWORD ; _str saved in rcx
    local _i:QWORD
    mov [_str], rcx            ; The String
    mov [_i], 0                ;  Character index
    ; r8b := str[0]
    mov rcx, [_str]
    mov r8b, byte [rcx]
    .main_loop:
    ; while (cc != 0)
    cmp r8b, 0
    jz .end_main_loop
    ; if (cc != 32)
    cmp r8b, 32
    je .is_space
    fastcall ParserCommandAddChar, r8b
    jmp .buffer_is_empty
    .is_space:
    fastcall ParserCommandFinish
    .buffer_is_empty:
    ; cc = str[++i];
    mov rdx, [_i]
    inc rdx
    mov rcx, [_str]
    mov r8b, byte [rcx + rdx]
    mov [_i], rdx
    jmp .main_loop
    .end_main_loop:
    fastcall ParserCommandFinish
    .done:
    ret
endp

proc ParserShowUnexpectedChar, char:BYTE
    mov [char], cl
    fastcall ConsolePrint, _gr_message_unexpected
    fastcall ConsolePrintChar, [char]
    fastcall ConsolePrint, _gr_message_at_input_string
    ret
endp

;;;
; Allocates memory for a string an returns a pointer to the new duplicated string
; You must free() the allocated memory when you don't use the string anymore
;
; param:
;   string - A pointer to the string to duplicate
;
; returns: (QWORD) A pointer to the new string
;;;
proc StringClone, string:QWORD
    local newstring:QWORD
    mov [string], rcx

    ; newstring := malloc(strlen(string) + 1)
    invoke strlen, rcx
    inc rax
    invoke malloc, rax
    mov [newstring], rax
    ; strcpy(newstring, string)
    invoke strcpy, rax, [string]
    ; return string;
    mov rax, [newstring]
    ret
endp

;;;
; Count the number of ocurrences of the given character in the string 
;
; params:
;   string - The string
;   char   - The character to count the ocurrences
;
; returns: (QWORD) The number of ocurrences
;;;
proc StringCountChar, string:QWORD, char:BYTE
    xor rax, rax ; number of ocurrences
.while:
    mov r8b, BYTE[rcx]
    cmp r8b, 0
    je .done
    inc rcx
    cmp r8b, dl
    jne .while
    inc rax
    jmp .while
.done:
    ret
endp

;;;
; Converts the given ascii string to lowercase. Warning: The original string is modified
;
; params:
;   string - The string to convert
;
; Returns: (QWORD) A pointer to the same string
;;;
proc StringToLower, string:QWORD
    xor rax, rax ; i = 0
.mainloop:
    mov dl, BYTE [rax + rcx]
    cmp dl, 0
    je .done
    cmp dl, 65
    jl .endif
    cmp dl, 90
    jg .endif
    add dl, 32
    mov BYTE [rax + rcx], dl
.endif:
    inc rax
    jmp .mainloop
.done:
    mov rax, rcx
    ret
endp

;;;
; Sends the win buffer to the window device context
; It effectively draws the the content of the buffer on the window
;;;
proc WindowSurfaceFlush
    invoke SetDIBitsToDevice, \
                [_gr_dc], \               ; Device context
                0,0, \                    ; Destination Position (x, y)
                [_gr_win_width],  \       ; Width
                [_gr_win_height], \       ; Width
                0,0, \                    ; The (x,y) coordinate of the lower-left corner of the image.
                0, \                      ; First scan line index
                [_gr_win_height], \       ; Number of scan lines
                [_gr_winbuffer], \        ; The colour data buffer
                _gr_bmi, \                ; A pointer to the BITMAPINFO structure
                0                         ; Colour type
    ret
endp

;;;
; Creates the main window.
;
; params:
;   width  - The initial width of the window
;   height - The initial height of the window
;   title  - A pointer to a null terminated string with the title of the window
;
; returns: (QWORD) The window handle or 0 if fails
;;;
proc WindowCreate, width:QWORD, height:QWORD, title:QWORD
        mov [width], rcx
    mov [height], rdx
    mov [title], r8
    mov [_gr_wc.cbSize],sizeof.WNDCLASSEX               ; The struct size
    mov [_gr_wc.style],0                                ; Window Classs style
    mov [_gr_wc.lpfnWndProc],WindowProc                 ; procedure to be called by windows to handle events
    mov [_gr_wc.cbClsExtra],0                           ; The number of extra bytes to allocate following the window-class structure
    mov [_gr_wc.cbWndExtra],0                           ; The number of extra bytes to allocate following the window instance
    mov [_gr_wc.hInstance],NULL                         ; The hInstance windows instance handler
    mov [_gr_wc.hIcon],NULL                             ; The default icon
    mov [_gr_wc.hCursor],NULL                           ; The default cursor
    mov [_gr_wc.hbrBackground],COLOR_BTNFACE+1          ; Window class background
    mov dword [_gr_wc.lpszMenuName],NULL                ; Window class menu name
    mov dword [_gr_wc.lpszClassName],_gr_str_class      ; Window class name
        mov     [_gr_wc.hIconSm],NULL                           ; The default icon small
    invoke      GetModuleHandle,0
        mov     [_gr_wc.hInstance],rax
    ; Load the default icon (hIcon and hIconSm)
        invoke  LoadIcon,[_gr_wc.hInstance],2
        mov     [_gr_wc.hIcon],rax
        mov     [_gr_wc.hIconSm],rax
    ; Load the default arrow cursor (hCursor)
        invoke  LoadCursor,0,IDC_ARROW
        mov     [_gr_wc.hCursor],rax
        ; Register the window class
        invoke  RegisterClassEx,_gr_wc
        test    rax,rax
        jz      .error
    ; Create the main window
        invoke  CreateWindowEx, \
        0, \                                                ; Optional window styles
        _gr_str_class, \                                    ; Window class name
        [title], \                                          ; Window title
        WS_VISIBLE+WS_DLGFRAME+WS_SYSMENU+WS_MAXIMIZEBOX+WS_SIZEBOX, \     ; Window style
        CW_USEDEFAULT, \                                    ; Position x
        CW_USEDEFAULT, \                                    ; Position y
        [width], \                                          ; Size width
        [height], \                                         ; Size height
        NULL, \                                             ; Parent window
        NULL, \                                             ; Menu
        [_gr_wc.hInstance], \                               ; Instance handle
        NULL                                                ; Additional application data
        or    rax,rax
        jz      .error
    ; return the window context if all ok
    ret
.error:
    ; return 0 if fails
    xor rax, rax
    ret
endp

;;;
; The WindowProc callback. It is called by the windows api to handle window events
;
; params:
;     hwnd   - The window handler
;     wmsg   - The message
;     wparam - The w param of the message (depends of the message type)
;     lparam - The l param of the message (depends of the message type)
;
; returns: LRESULT - It varies depending on the type of the message
;;;
proc WindowProc uses rbx rsi rdi, hwnd,wmsg,wparam,lparam
        ; compare the wmsg (edx) against each posible event type
        cmp         edx,WM_DESTROY
        je          .wmdestroy
        cmp     edx,WM_MOUSEMOVE
        je      .wmmousemove
        ; cmp     edx,WM_LBUTTONUP
        ; je      .wmmouseev
        ; cmp     edx,WM_MBUTTONUP
        ; je      .wmmouseev
        ; cmp     edx,WM_RBUTTONUP
        ; je      .wmmouseev
        ; cmp     edx,WM_LBUTTONDOWN
        ; je      .wmmouseev
        ; cmp     edx,WM_MBUTTONDOWN
        ; je      .wmmouseev
        ; cmp     edx,WM_RBUTTONDOWN
        ; je      .wmmouseev
        ; cmp     edx,WM_KEYUP
        ; je      .wmkeyup
        cmp     edx,WM_KEYDOWN
        je      .wmkeydown
        cmp     edx,WM_CHAR
        je      .wmchar
        cmp     edx,WM_MOUSEWHEEL
        je      .wmmousewheel
        ;cmp     edx,WM_EXITSIZEMOVE
        ;je      .wmexitsizemove
        cmp     edx,WM_SIZE
        je      .wmexitsizemove
.defwndproc:
        ; if noone of the event types match, pass the event handling to the OS
        invoke  DefWindowProc,rcx,rdx,r8,r9
        ret
.wmmousemove:
        ; transform the coordinate to x and y coordinate
        xor rax, rax
        xor rbx, rbx
        mov eax, r9d ; dword[lparam]
        mov ebx,eax
        shr eax,16
        and ebx,$ffff
        mov [_gr_mouse_x],rbx
        mov [_gr_mouse_y],rax
        ret
.wmdestroy:
        invoke  PostQuitMessage,0
        xor     eax,eax
        ret
.wmchar:
        fastcall InputOnChar, r8
        xor eax, eax
        ret
.wmkeydown:
        fastcall InputOnKeyDown, r8
        xor eax, eax
        ret
.wmmousewheel:
        shr r8, 16
        and r8, $ffff
        fastcall InputOnMouseWheel, r8
        xor eax, eax
        ret
.wmexitsizemove:
        fastcall AppRecalculateWindowSize
        xor eax, eax
        ret
.finish:
        ret
endp

;////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////
start:
        sub     rsp,8           ; Make stack dqword aligned
        fastcall WindowCreate, 800, 600, _gr_str_window_title
        or rax, rax
        jz .error
        mov [_gr_whandle], rax  ; save the whandle
        ; Gets the device context fot that window
        invoke GetDC,[_gr_whandle]
        mov [_gr_dc],rax
        fastcall AppRecalculateWindowSize
        invoke ShowWindow,[_gr_whandle],SW_NORMAL
        ;invoke UpdateWindow,[_gr_whandle]
    ; call the app init function
        fastcall AppInit
        ; Thread Main loop
.mainloop:
    ; Process all the incoming messages
    ; if the thread receives an exit message, this method returns 0
        fastcall AppThreadProcessMessages
        or rax, rax
        je .exitapp
    ; set the draw target to the app buffer
        fastcall DrawSetTarget, [_gr_app_width], [_gr_app_height], [_gr_appbuffer]
    ; call the app update function
        fastcall AppUpdate
    ; copy the app buffer to the win buffer and sends its content to the window
        fastcall DrawSetTarget, [_gr_win_width], [_gr_win_height], [_gr_winbuffer]
        fastcall DrawBufferScaled, [_gr_appbuffer], [_gr_app_width], [_gr_app_height], 0, 0, [_gr_pixel_scale_x], [_gr_pixel_scale_y]
        fastcall WindowSurfaceFlush
        jmp .mainloop
.error:
        invoke MessageBox,NULL,_gr_str_error,NULL,MB_ICONERROR+MB_OK
        invoke DestroyWindow,[_gr_whandle]
        invoke ExitProcess,[_gr_msg.wParam]
        ret
.exitapp:
        invoke ReleaseDC,[_gr_whandle],[_gr_dc]
        invoke DestroyWindow,[_gr_whandle]
        invoke ExitProcess,[_gr_msg.wParam]
        ret

;////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////
section '.data' data readable writeable

; Console
_gr_log_input      dq ?  ; A pointer to an ArrayList
_gr_log_output     dq ?  ; A pointer to an ArrayList

_gr_str_newline    db 10,0 ; LF + NULL
_gr_str_ok         db "ok", 0

; The active drawing target surface
_gr_draw_target_buff    dq 0   ; colour buffer (pointer)
_gr_draw_target_width   dq 0   ; width
_gr_draw_target_height  dq 0   ; height

font db \    ;;;;; See the font in https://playcode.io/400738
        $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, \
        $00, $00, $7E, $85, $B5, $81, $81, $BD, $99, $81, $81, $7E, $00, $00, $00, $00, \
        $00, $00, $7E, $FF, $DB, $FF, $FF, $C3, $E7, $FF, $FF, $7E, $00, $00, $00, $00, \
        $00, $00, $00, $00, $6C, $FE, $FE, $FE, $FE, $7C, $38, $10, $00, $00, $00, $00, \
        $00, $00, $00, $00, $10, $38, $7C, $FE, $7C, $38, $10, $00, $00, $00, $00, $00, \
        $00, $00, $00, $18, $3C, $3C, $E7, $E7, $E7, $18, $18, $3C, $00, $00, $00, $00, \
        $00, $00, $00, $18, $3C, $7E, $FF, $FF, $7E, $18, $18, $3C, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $00, $18, $3C, $3C, $18, $00, $00, $00, $00, $00, $00, \
        $FF, $FF, $FF, $FF, $FF, $FF, $E7, $C3, $C3, $E7, $FF, $FF, $FF, $FF, $FF, $FF, \
        $00, $00, $00, $00, $00, $3C, $66, $42, $42, $66, $3C, $00, $00, $00, $00, $00, \
        $FF, $FF, $FF, $FF, $FF, $C3, $99, $BD, $BD, $99, $C3, $FF, $FF, $FF, $FF, $FF, \
        $00, $00, $1E, $0E, $1A, $32, $78, $CC, $CC, $CC, $CC, $78, $00, $00, $00, $00, \
        $00, $00, $3C, $66, $66, $66, $66, $3C, $18, $7E, $18, $18, $00, $00, $00, $00, \
        $00, $00, $3F, $33, $3F, $30, $30, $30, $30, $70, $F0, $E0, $00, $00, $00, $00, \
        $00, $00, $7F, $67, $7F, $63, $63, $63, $63, $67, $E7, $E6, $C0, $00, $00, $00, \
        $00, $00, $00, $18, $18, $DB, $3C, $E7, $3C, $DB, $18, $18, $00, $00, $00, $00, \
        $00, $80, $C0, $E0, $F0, $F8, $FE, $F8, $F0, $E0, $C0, $80, $00, $00, $00, $00, \
        $00, $02, $06, $0E, $1E, $3E, $FE, $3E, $1E, $0E, $06, $02, $00, $00, $00, $00, \
        $00, $00, $18, $3C, $7E, $18, $18, $18, $7E, $3C, $18, $00, $00, $00, $00, $00, \
        $00, $00, $66, $66, $66, $66, $66, $66, $66, $00, $66, $66, $00, $00, $00, $00, \
        $00, $00, $7F, $DB, $DB, $DB, $7B, $1B, $1B, $1B, $1B, $1B, $00, $00, $00, $00, \
        $00, $7C, $C6, $60, $38, $6C, $CE, $C6, $6C, $38, $0C, $C6, $7C, $00, $00, $00, \
        $00, $00, $00, $00, $00, $00, $00, $00, $FE, $FE, $FE, $FE, $00, $00, $00, $00, \
        $00, $00, $18, $3C, $7E, $18, $18, $18, $7E, $3C, $18, $7E, $00, $00, $00, $00, \
        $00, $00, $18, $3C, $7E, $18, $18, $18, $18, $18, $18, $18, $00, $00, $00, $00, \
        $00, $00, $18, $18, $18, $18, $18, $18, $18, $7E, $3C, $18, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $18, $0C, $FE, $0C, $18, $00, $00, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $30, $60, $FE, $60, $30, $00, $00, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $00, $C0, $C0, $C0, $FE, $00, $00, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $24, $66, $FF, $66, $24, $00, $00, $00, $00, $00, $00, \
        $00, $00, $00, $00, $10, $38, $38, $7C, $7C, $FE, $FE, $00, $00, $00, $00, $00, \
        $00, $00, $00, $00, $FE, $FE, $7C, $7C, $38, $38, $10, $00, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, \
        $00, $00, $18, $3C, $3C, $3C, $18, $18, $18, $00, $18, $18, $00, $00, $00, $00, \
        $00, $66, $66, $66, $24, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, \
        $00, $00, $00, $6C, $6C, $FE, $6C, $6C, $6C, $FE, $6C, $6C, $00, $00, $00, $00, \
        $18, $18, $7C, $C6, $C2, $C0, $7C, $06, $06, $86, $C6, $7C, $18, $18, $00, $00, \
        $00, $00, $00, $00, $C2, $C6, $0C, $18, $30, $60, $C6, $86, $00, $00, $00, $00, \
        $00, $00, $38, $6C, $6C, $38, $76, $DC, $CC, $CC, $CC, $76, $00, $00, $00, $00, \
        $00, $30, $30, $30, $60, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, \
        $00, $00, $0C, $18, $30, $30, $30, $30, $30, $30, $18, $0C, $00, $00, $00, $00, \
        $00, $00, $30, $18, $0C, $0C, $0C, $0C, $0C, $0C, $18, $30, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $66, $3C, $FF, $3C, $66, $00, $00, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $18, $18, $7E, $18, $18, $00, $00, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $00, $00, $00, $00, $18, $18, $18, $30, $00, $00, $00, \
        $00, $00, $00, $00, $00, $00, $00, $FE, $00, $00, $00, $00, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $18, $18, $00, $00, $00, $00, \
        $00, $00, $00, $00, $02, $06, $0C, $18, $30, $60, $C0, $80, $00, $00, $00, $00, \
        $00, $00, $3C, $66, $C3, $C3, $DB, $DB, $C3, $C3, $66, $3C, $00, $00, $00, $00, \
        $00, $00, $18, $38, $78, $18, $18, $18, $18, $18, $18, $7E, $00, $00, $00, $00, \
        $00, $00, $7C, $C6, $06, $0C, $18, $30, $60, $C0, $C6, $FE, $00, $00, $00, $00, \
        $00, $00, $7C, $C6, $06, $06, $3C, $06, $06, $06, $C6, $7C, $00, $00, $00, $00, \
        $00, $00, $0C, $1C, $3C, $6C, $CC, $FE, $0C, $0C, $0C, $1E, $00, $00, $00, $00, \
        $00, $00, $FE, $C0, $C0, $C0, $FC, $06, $06, $06, $C6, $7C, $00, $00, $00, $00, \
        $00, $00, $38, $60, $C0, $C0, $FC, $C6, $C6, $C6, $C6, $7C, $00, $00, $00, $00, \
        $00, $00, $FE, $C6, $06, $06, $0C, $18, $30, $30, $30, $30, $00, $00, $00, $00, \
        $00, $00, $7C, $C6, $C6, $C6, $7C, $C6, $C6, $C6, $C6, $7C, $00, $00, $00, $00, \
        $00, $00, $7C, $C6, $C6, $C6, $7E, $06, $06, $06, $0C, $78, $00, $00, $00, $00, \
        $00, $00, $00, $00, $18, $18, $00, $00, $00, $18, $18, $00, $00, $00, $00, $00, \
        $00, $00, $00, $00, $18, $18, $00, $00, $00, $18, $18, $30, $00, $00, $00, $00, \
        $00, $00, $00, $06, $0C, $18, $30, $60, $30, $18, $0C, $06, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $7E, $00, $00, $7E, $00, $00, $00, $00, $00, $00, $00, \
        $00, $00, $00, $60, $30, $18, $0C, $06, $0C, $18, $30, $60, $00, $00, $00, $00, \
        $00, $00, $7C, $C6, $C6, $0C, $18, $18, $18, $00, $18, $18, $00, $00, $00, $00, \
        $00, $00, $00, $7C, $C6, $C6, $DE, $DE, $DE, $DC, $C0, $7C, $00, $00, $00, $00, \
        $00, $00, $10, $38, $6C, $C6, $C6, $FE, $C6, $C6, $C6, $C6, $00, $00, $00, $00, \
        $00, $00, $FC, $66, $66, $66, $7C, $66, $66, $66, $66, $FC, $00, $00, $00, $00, \
        $00, $00, $3C, $66, $C2, $C0, $C0, $C0, $C0, $C2, $66, $3C, $00, $00, $00, $00, \
        $00, $00, $F8, $6C, $66, $66, $66, $66, $66, $6E, $6C, $F8, $00, $00, $00, $00, \
        $00, $00, $FE, $66, $62, $68, $78, $68, $60, $62, $66, $FE, $00, $00, $00, $00, \
        $00, $00, $FE, $66, $62, $68, $78, $68, $60, $60, $60, $F0, $00, $00, $00, $00, \
        $00, $00, $3C, $66, $C2, $C0, $C0, $DE, $C6, $C6, $66, $3A, $00, $00, $00, $00, \
        $00, $00, $C6, $C6, $C6, $C6, $FE, $C6, $C6, $C6, $C6, $C6, $00, $00, $00, $00, \
        $00, $00, $3C, $18, $18, $18, $18, $18, $18, $18, $18, $3C, $00, $00, $00, $00, \
        $00, $00, $1E, $0C, $0C, $0C, $0C, $0C, $CC, $CC, $CC, $78, $00, $00, $00, $00, \
        $00, $00, $E6, $66, $66, $6C, $78, $78, $6C, $66, $66, $E6, $00, $00, $00, $00, \
        $00, $00, $F0, $60, $60, $60, $60, $60, $60, $62, $66, $FE, $00, $00, $00, $00, \
        $00, $00, $C3, $E7, $FF, $FF, $DB, $C3, $C3, $C3, $C3, $C3, $00, $00, $00, $00, \
        $00, $00, $C6, $E6, $F6, $FE, $DE, $CE, $C6, $C6, $C6, $C6, $00, $00, $00, $00, \
        $00, $00, $7C, $C6, $C6, $CE, $C6, $C6, $C6, $C6, $C6, $7C, $00, $00, $00, $00, \
        $00, $00, $FC, $66, $66, $66, $7C, $60, $60, $60, $60, $F0, $00, $00, $00, $00, \
        $00, $00, $7C, $C6, $C6, $CE, $C6, $C6, $C6, $D6, $DE, $7C, $0C, $0E, $00, $00, \
        $00, $00, $FC, $66, $66, $66, $7C, $6C, $66, $66, $66, $E6, $00, $00, $00, $00, \
        $00, $00, $7C, $C6, $C6, $60, $38, $0C, $06, $C6, $C6, $7C, $00, $00, $00, $00, \
        $00, $00, $FF, $DB, $99, $18, $18, $18, $18, $18, $18, $3C, $00, $00, $00, $00, \
        $00, $00, $C6, $C6, $C6, $C6, $C6, $C6, $C6, $C6, $C6, $7C, $00, $00, $00, $00, \
        $00, $00, $C3, $C3, $C3, $C3, $C3, $C3, $C3, $66, $3C, $18, $00, $00, $00, $00, \
        $00, $00, $C3, $C3, $C3, $C3, $C3, $DB, $DB, $FF, $66, $66, $00, $00, $00, $00, \
        $00, $00, $C3, $C3, $66, $3C, $18, $18, $3C, $66, $C3, $C3, $00, $00, $00, $00, \
        $00, $00, $C3, $C3, $C3, $66, $3C, $18, $18, $18, $18, $3C, $00, $00, $00, $00, \
        $00, $00, $FF, $C3, $86, $0C, $18, $30, $60, $C1, $C3, $FF, $00, $00, $00, $00, \
        $00, $00, $3C, $30, $30, $30, $30, $30, $30, $30, $30, $3C, $00, $00, $00, $00, \
        $00, $00, $00, $80, $C0, $E0, $70, $38, $1C, $0E, $06, $02, $00, $00, $00, $00, \
        $00, $00, $3C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $3C, $00, $00, $00, $00, \
        $10, $38, $6C, $C6, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $FF, $00, $00, \
        $30, $30, $18, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $78, $0C, $7C, $CC, $CC, $CC, $76, $00, $00, $00, $00, \
        $00, $00, $E0, $60, $60, $78, $6C, $66, $66, $66, $66, $7C, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $7C, $C6, $C0, $C0, $C0, $C6, $7C, $00, $00, $00, $00, \
        $00, $00, $1C, $0C, $0C, $3C, $6C, $CC, $CC, $CC, $CC, $76, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $7C, $C6, $FE, $C0, $C0, $C6, $7C, $00, $00, $00, $00, \
        $00, $00, $38, $6C, $64, $60, $F0, $60, $60, $60, $60, $F0, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $76, $CC, $CC, $CC, $CC, $CC, $7C, $0C, $CC, $78, $00, \
        $00, $00, $E0, $60, $60, $6C, $76, $66, $66, $66, $66, $E6, $00, $00, $00, $00, \
        $00, $00, $18, $18, $00, $38, $18, $18, $18, $18, $18, $3C, $00, $00, $00, $00, \
        $00, $00, $06, $06, $00, $0E, $06, $06, $06, $06, $06, $06, $66, $66, $3C, $00, \
        $00, $00, $E0, $60, $60, $66, $6C, $78, $78, $6C, $66, $E6, $00, $00, $00, $00, \
        $00, $00, $38, $18, $18, $18, $18, $18, $18, $18, $18, $3C, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $E6, $FF, $DB, $DB, $DB, $DB, $DB, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $DC, $66, $66, $66, $66, $66, $66, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $7C, $C6, $C6, $C6, $C6, $C6, $7C, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $DC, $66, $66, $66, $66, $66, $7C, $60, $60, $F0, $00, \
        $00, $00, $00, $00, $00, $76, $CC, $CC, $CC, $CC, $CC, $7C, $0C, $0C, $1E, $00, \
        $00, $00, $00, $00, $00, $DC, $76, $66, $60, $60, $60, $F0, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $7C, $C6, $60, $38, $0C, $C6, $7C, $00, $00, $00, $00, \
        $00, $00, $10, $30, $30, $FC, $30, $30, $30, $30, $36, $1C, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $CC, $CC, $CC, $CC, $CC, $CC, $76, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $C3, $C3, $C3, $C3, $66, $3C, $18, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $C3, $C3, $C3, $DB, $DB, $FF, $66, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $C3, $66, $3C, $18, $3C, $66, $C3, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $C6, $C6, $C6, $C6, $C6, $C6, $7E, $06, $0C, $F8, $00, \
        $00, $00, $00, $00, $00, $FE, $CC, $18, $30, $60, $C6, $FE, $00, $00, $00, $00, \
        $00, $00, $0E, $18, $18, $18, $70, $18, $18, $18, $18, $0E, $00, $00, $00, $00, \
        $00, $00, $18, $18, $18, $18, $00, $18, $18, $18, $18, $18, $00, $00, $00, $00, \
        $00, $00, $70, $18, $18, $18, $0E, $18, $18, $18, $18, $70, $00, $00, $00, $00, \
        $00, $00, $76, $DC, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, \
        $00, $00, $00, $00, $10, $38, $6C, $C6, $C6, $CE, $FE, $00, $00, $00, $00, $00, \
        $00, $00, $3C, $66, $C2, $C0, $C0, $C0, $C2, $66, $3C, $0C, $06, $7C, $00, $00, \
        $00, $00, $CC, $00, $00, $CC, $CC, $CC, $CC, $CC, $CC, $76, $00, $00, $00, $00, \
        $00, $0C, $18, $30, $00, $7C, $C6, $FE, $C0, $C0, $C6, $7C, $00, $00, $00, $00, \
        $00, $10, $38, $6C, $00, $78, $0C, $7C, $CC, $CC, $CC, $76, $00, $00, $00, $00, \
        $00, $00, $CC, $00, $00, $78, $0C, $7C, $CC, $CC, $CC, $76, $00, $00, $00, $00, \
        $00, $60, $30, $18, $00, $78, $0C, $7C, $CC, $CC, $CC, $76, $00, $00, $00, $00, \
        $00, $38, $6C, $38, $00, $78, $0C, $7C, $CC, $CC, $CC, $76, $00, $00, $00, $00, \
        $00, $00, $00, $00, $3C, $66, $60, $60, $66, $3C, $0C, $06, $3C, $00, $00, $00, \
        $00, $10, $38, $6C, $00, $7C, $C6, $FE, $C0, $C0, $C6, $7C, $00, $00, $00, $00, \
        $00, $00, $C6, $00, $00, $7C, $C6, $FE, $C0, $C0, $C6, $7C, $00, $00, $00, $00, \
        $00, $60, $30, $18, $00, $7C, $C6, $FE, $C0, $C0, $C6, $7C, $00, $00, $00, $00, \
        $00, $00, $66, $00, $00, $38, $18, $18, $18, $18, $18, $3C, $00, $00, $00, $00, \
        $00, $18, $3C, $66, $00, $38, $18, $18, $18, $18, $18, $3C, $00, $00, $00, $00, \
        $00, $60, $30, $18, $00, $38, $18, $18, $18, $18, $18, $3C, $00, $00, $00, $00, \
        $00, $C6, $00, $10, $38, $6C, $C6, $C6, $FE, $C6, $C6, $C6, $00, $00, $00, $00, \
        $38, $6C, $38, $00, $38, $6C, $C6, $C6, $FE, $C6, $C6, $C6, $00, $00, $00, $00, \
        $18, $30, $60, $00, $FE, $66, $60, $7C, $60, $60, $66, $FE, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $6E, $3B, $1B, $7E, $D8, $DC, $77, $00, $00, $00, $00, \
        $00, $00, $3E, $6C, $CC, $CC, $FE, $CC, $CC, $CC, $CC, $CE, $00, $00, $00, $00, \
        $00, $10, $38, $6C, $00, $7C, $C6, $C6, $C6, $C6, $C6, $7C, $00, $00, $00, $00, \
        $00, $00, $C6, $00, $00, $7C, $C6, $C6, $C6, $C6, $C6, $7C, $00, $00, $00, $00, \
        $00, $60, $30, $18, $00, $7C, $C6, $C6, $C6, $C6, $C6, $7C, $00, $00, $00, $00, \
        $00, $30, $78, $CC, $00, $CC, $CC, $CC, $CC, $CC, $CC, $76, $00, $00, $00, $00, \
        $00, $60, $30, $18, $00, $CC, $CC, $CC, $CC, $CC, $CC, $76, $00, $00, $00, $00, \
        $00, $00, $C6, $00, $00, $C6, $C6, $C6, $C6, $C6, $C6, $7E, $06, $0C, $78, $00, \
        $00, $C6, $00, $7C, $C6, $C6, $C6, $C6, $C6, $C6, $C6, $7C, $00, $00, $00, $00, \
        $00, $C6, $00, $C6, $C6, $C6, $C6, $C6, $C6, $C6, $C6, $7C, $00, $00, $00, $00, \
        $00, $18, $18, $7E, $C3, $C0, $C0, $C0, $C3, $7E, $18, $18, $00, $00, $00, $00, \
        $00, $38, $6C, $64, $60, $F0, $60, $60, $60, $60, $E6, $FC, $00, $00, $00, $00, \
        $00, $00, $C3, $66, $3C, $18, $FF, $18, $FF, $18, $18, $18, $00, $00, $00, $00, \
        $00, $FC, $76, $66, $7C, $62, $66, $6F, $66, $66, $66, $F3, $00, $00, $00, $00, \
        $00, $0E, $1B, $18, $18, $18, $7E, $18, $18, $18, $18, $18, $D8, $70, $00, $00, \
        $00, $18, $30, $60, $00, $78, $0C, $7C, $CC, $CC, $CC, $76, $00, $00, $00, $00, \
        $00, $0C, $18, $30, $00, $38, $18, $18, $18, $18, $18, $3C, $00, $00, $00, $00, \
        $00, $18, $30, $60, $00, $7C, $C6, $C6, $C6, $C6, $C6, $7C, $00, $00, $00, $00, \
        $00, $18, $30, $60, $00, $CC, $CC, $CC, $CC, $CC, $CC, $76, $00, $00, $00, $00, \
        $00, $00, $76, $DC, $00, $DC, $66, $66, $66, $66, $66, $66, $00, $00, $00, $00, \
        $76, $DC, $00, $C6, $E6, $F6, $FE, $DE, $CE, $C6, $C6, $C6, $00, $00, $00, $00, \
        $00, $3C, $6C, $6C, $3E, $00, $7E, $00, $00, $00, $00, $00, $00, $00, $00, $00, \
        $00, $38, $6C, $6C, $38, $00, $7C, $00, $00, $00, $00, $00, $00, $00, $00, $00, \
        $00, $00, $30, $30, $00, $30, $30, $60, $C0, $C6, $C6, $7C, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $00, $FE, $C0, $C0, $C0, $C0, $00, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $00, $FE, $06, $06, $06, $06, $00, $00, $00, $00, $00, \
        $00, $C0, $C0, $C2, $C6, $CC, $18, $30, $60, $CE, $9B, $06, $0C, $1F, $00, $00, \
        $00, $C0, $C0, $C2, $C6, $CC, $18, $30, $66, $CE, $96, $3E, $06, $06, $00, $00, \
        $00, $00, $18, $18, $00, $18, $18, $18, $3C, $3C, $3C, $18, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $36, $6C, $D8, $6C, $36, $00, $00, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $D8, $6C, $36, $6C, $D8, $00, $00, $00, $00, $00, $00, \
        $11, $44, $11, $44, $11, $44, $11, $44, $11, $44, $11, $44, $11, $44, $11, $44, \
        $55, $AA, $55, $AA, $55, $AA, $55, $AA, $55, $AA, $55, $AA, $55, $AA, $55, $AA, \
        $DD, $77, $DD, $77, $DD, $77, $DD, $77, $DD, $77, $DD, $77, $DD, $77, $DD, $77, \
        $18, $18, $18, $18, $18, $18, $18, $18, $18, $18, $18, $18, $18, $18, $18, $18, \
        $18, $18, $18, $18, $18, $18, $18, $F8, $18, $18, $18, $18, $18, $18, $18, $18, \
        $18, $18, $18, $18, $18, $F8, $18, $F8, $18, $18, $18, $18, $18, $18, $18, $18, \
        $36, $36, $36, $36, $36, $36, $36, $F6, $36, $36, $36, $36, $36, $36, $36, $36, \
        $00, $00, $00, $00, $00, $00, $00, $FE, $36, $36, $36, $36, $36, $36, $36, $36, \
        $00, $00, $00, $00, $00, $F8, $18, $F8, $18, $18, $18, $18, $18, $18, $18, $18, \
        $36, $36, $36, $36, $36, $F6, $06, $F6, $36, $36, $36, $36, $36, $36, $36, $36, \
        $36, $36, $36, $36, $36, $36, $36, $36, $36, $36, $36, $36, $36, $36, $36, $36, \
        $00, $00, $00, $00, $00, $FE, $06, $F6, $36, $36, $36, $36, $36, $36, $36, $36, \
        $36, $36, $36, $36, $36, $F6, $06, $FE, $00, $00, $00, $00, $00, $00, $00, $00, \
        $36, $36, $36, $36, $36, $36, $36, $FE, $00, $00, $00, $00, $00, $00, $00, $00, \
        $18, $18, $18, $18, $18, $F8, $18, $F8, $00, $00, $00, $00, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $00, $00, $F8, $18, $18, $18, $18, $18, $18, $18, $18, \
        $18, $18, $18, $18, $18, $18, $18, $1F, $00, $00, $00, $00, $00, $00, $00, $00, \
        $18, $18, $18, $18, $18, $18, $18, $FF, $00, $00, $00, $00, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $00, $00, $FF, $18, $18, $18, $18, $18, $18, $18, $18, \
        $18, $18, $18, $18, $18, $18, $18, $1F, $18, $18, $18, $18, $18, $18, $18, $18, \
        $00, $00, $00, $00, $00, $00, $00, $FF, $00, $00, $00, $00, $00, $00, $00, $00, \
        $18, $18, $18, $18, $18, $18, $18, $FF, $18, $18, $18, $18, $18, $18, $18, $18, \
        $18, $18, $18, $18, $18, $1F, $18, $1F, $18, $18, $18, $18, $18, $18, $18, $18, \
        $36, $36, $36, $36, $36, $36, $36, $37, $36, $36, $36, $36, $36, $36, $36, $36, \
        $36, $36, $36, $36, $36, $37, $30, $3F, $00, $00, $00, $00, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $3F, $30, $37, $36, $36, $36, $36, $36, $36, $36, $36, \
        $36, $36, $36, $36, $36, $F7, $00, $FF, $00, $00, $00, $00, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $FF, $00, $F7, $36, $36, $36, $36, $36, $36, $36, $36, \
        $36, $36, $36, $36, $36, $37, $30, $37, $36, $36, $36, $36, $36, $36, $36, $36, \
        $00, $00, $00, $00, $00, $FF, $00, $FF, $00, $00, $00, $00, $00, $00, $00, $00, \
        $36, $36, $36, $36, $36, $F7, $00, $F7, $36, $36, $36, $36, $36, $36, $36, $36, \
        $18, $18, $18, $18, $18, $FF, $00, $FF, $00, $00, $00, $00, $00, $00, $00, $00, \
        $36, $36, $36, $36, $36, $36, $36, $FF, $00, $00, $00, $00, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $FF, $00, $FF, $18, $18, $18, $18, $18, $18, $18, $18, \
        $00, $00, $00, $00, $00, $00, $00, $FF, $36, $36, $36, $36, $36, $36, $36, $36, \
        $36, $36, $36, $36, $36, $36, $36, $3F, $00, $00, $00, $00, $00, $00, $00, $00, \
        $18, $18, $18, $18, $18, $1F, $18, $1F, $00, $00, $00, $00, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $1F, $18, $1F, $18, $18, $18, $18, $18, $18, $18, $18, \
        $00, $00, $00, $00, $00, $00, $00, $3F, $36, $36, $36, $36, $36, $36, $36, $36, \
        $36, $36, $36, $36, $36, $36, $36, $FF, $36, $36, $36, $36, $36, $36, $36, $36, \
        $18, $18, $18, $18, $18, $FF, $18, $FF, $18, $18, $18, $18, $18, $18, $18, $18, \
        $18, $18, $18, $18, $18, $18, $18, $F8, $00, $00, $00, $00, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $00, $00, $1F, $18, $18, $18, $18, $18, $18, $18, $18, \
        $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, \
        $00, $00, $00, $00, $00, $00, $00, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, \
        $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0, \
        $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, \
        $FF, $FF, $FF, $FF, $FF, $FF, $FF, $00, $00, $00, $00, $00, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $76, $DC, $D8, $D8, $D8, $DC, $76, $00, $00, $00, $00, \
        $00, $00, $78, $CC, $CC, $CC, $D8, $CC, $C6, $C6, $C6, $CC, $00, $00, $00, $00, \
        $00, $00, $FE, $C6, $C6, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $00, $00, $00, $00, \
        $00, $00, $00, $00, $FE, $6C, $6C, $6C, $6C, $6C, $6C, $6C, $00, $00, $00, $00, \
        $00, $00, $00, $FE, $C6, $60, $30, $18, $30, $60, $C6, $FE, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $7E, $D8, $D8, $D8, $D8, $D8, $70, $00, $00, $00, $00, \
        $00, $00, $00, $00, $66, $66, $66, $66, $66, $7C, $60, $60, $C0, $00, $00, $00, \
        $00, $00, $00, $00, $76, $DC, $18, $18, $18, $18, $18, $18, $00, $00, $00, $00, \
        $00, $00, $00, $7E, $18, $3C, $66, $66, $66, $3C, $18, $7E, $00, $00, $00, $00, \
        $00, $00, $00, $38, $6C, $C6, $C6, $FE, $C6, $C6, $6C, $38, $00, $00, $00, $00, \
        $00, $00, $38, $6C, $C6, $C6, $C6, $6C, $6C, $6C, $6C, $EE, $00, $00, $00, $00, \
        $00, $00, $1E, $30, $18, $0C, $3E, $66, $66, $66, $66, $3C, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $7E, $DB, $DB, $DB, $7E, $00, $00, $00, $00, $00, $00, \
        $00, $00, $00, $03, $06, $7E, $DB, $DB, $F3, $7E, $60, $C0, $00, $00, $00, $00, \
        $00, $00, $1C, $30, $60, $60, $7C, $60, $60, $60, $30, $1C, $00, $00, $00, $00, \
        $00, $00, $00, $7C, $C6, $C6, $C6, $C6, $C6, $C6, $C6, $C6, $00, $00, $00, $00, \
        $00, $00, $00, $00, $FE, $00, $00, $FE, $00, $00, $FE, $00, $00, $00, $00, $00, \
        $00, $00, $00, $00, $18, $18, $7E, $18, $18, $00, $00, $FF, $00, $00, $00, $00, \
        $00, $00, $00, $30, $18, $0C, $06, $0C, $18, $30, $00, $7E, $00, $00, $00, $00, \
        $00, $00, $00, $0C, $18, $30, $60, $30, $18, $0C, $00, $7E, $00, $00, $00, $00, \
        $00, $00, $0E, $1B, $1B, $18, $18, $18, $18, $18, $18, $18, $18, $18, $18, $18, \
        $18, $18, $18, $18, $18, $18, $18, $18, $D8, $D8, $D8, $70, $00, $00, $00, $00, \
        $00, $00, $00, $00, $18, $18, $00, $7E, $00, $18, $18, $00, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $76, $DC, $00, $76, $DC, $00, $00, $00, $00, $00, $00, \
        $00, $38, $6C, $6C, $38, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $00, $00, $18, $18, $00, $00, $00, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $00, $00, $00, $18, $00, $00, $00, $00, $00, $00, $00, \
        $00, $0F, $0C, $0C, $0C, $0C, $0C, $EC, $6C, $6C, $3C, $1C, $00, $00, $00, $00, \
        $00, $D8, $6C, $6C, $6C, $6C, $6C, $00, $00, $00, $00, $00, $00, $00, $00, $00, \
        $00, $70, $D8, $30, $60, $C8, $F8, $00, $00, $00, $00, $00, $00, $00, $00, $00, \
        $00, $00, $00, $00, $7C, $7C, $7C, $7C, $7C, $7C, $7C, $00, $00, $00, $00, $00, \
        $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00


; Input
_gr_input_buffer       rb 256                       ; Max input = 255
_gr_input_char_count   db 0                         ; Current character count

; Output
_gr_output_buffer      rb 65535                     ; Max output = 65535
_gr_output_char_count  dw 0                         ; Current character count

; Strings
_lg_command_add              db "+",0
_lg_command_substract        db "-",0
_lg_command_multiply         db "*",0
_lg_command_divide           db "/",0
_lg_command_remainder        db "%",0
_lg_command_or               db "or",0
_lg_command_and              db "and",0
_lg_command_xor              db "xor",0
_lg_command_not              db "not",0
_lg_command_neg              db "neg",0
_lg_command_print            db ".",0
_lg_command_print_hex        db ".h",0
_lg_command_print_bin        db ".b",0
_lg_command_print_stack      db "s.",0

_lg_commands_list     dq 0 ; List with all available commands strings
_lg_commands_handlers dq 0 ; List with the handlers asociated to each command

; String buffer used to store the numbers while parsing
_lg_buffer_str     rb 256
_lg_buffer_length  dq 0

; Stack used by the calculator
_lg_stack dq 0

; Window
_gr_str_class      TCHAR 'CALCWIN64',0              ; class name
_gr_wc             WNDCLASSEX                       ; class
_gr_whandle        dq ?                             ; handle
_gr_dc             dq ?                             ; device context
_gr_bmi            BITMAPINFOHEADER                 ; bitmap info header
_gr_msg            MSG                              ; the message to process in the message queue
_gr_client_rect    RECT                             ; The client rect area

_lg_convert_decimal_buffer rb 255
_lg_convert_decimal_format db "%d",0

; strings
_gr_str_window_title      TCHAR 'Postfix calculator. Type ',34, 'help', 34, ' or ', 34, 'man', 34, ' to see all commands.', 0
_gr_str_title             TCHAR 'Postfix calculator', 0
_gr_str_subtitle          TCHAR 'Type ',34,'help',34, ' to open the manual', 0
_gr_str_error             TCHAR 'Startup failed.',0
_gr_str_resiconname       TCHAR 'main_icon',0
_gr_str_console_start     TCHAR 175,32,0
_gr_str_console_cursor    TCHAR 219,0

_gr_str_help_url              TCHAR 'https://github.com/jhm-ciberman/calculator-asm/blob/master/README.md',0
_gr_message_showing_help      TCHAR 'Opening help in default web browser',0
_gr_message_unknown           TCHAR 'Unknown command ', 34, 0
_gr_message_type_help         TCHAR 34, '. ',10,'Type help or man to see all commands',0
_gr_message_byebye            TCHAR 'Bye bye! ',1,0
_gr_message_unexpected        TCHAR 'Error: Unexpected character ', 34, 0
_gr_message_at_input_string   TCHAR 34, ' at input string.', 0
_gr_message_empty_stack       TCHAR '[Empty stack]', 0
_gr_message_maximum_zoom      TCHAR 'Maximum zoom level reached.', 0
_gr_message_minimum_zoom      TCHAR 'Minimum zoom level reached.', 0

_gr_message_mandata           TCHAR 'man'
db 0 ;NULL at the end of the mandata

_gr_str_cmd_clear         TCHAR 'clear',0
_gr_str_cmd_exit          TCHAR 'exit',0
_gr_str_cmd_help          TCHAR 'help',0
_gr_str_cmd_man           TCHAR 'man',0
_gr_str_cmd_zoomplus      TCHAR 'zoom+',0
_gr_str_cmd_zoomminus     TCHAR 'zoom-',0

; colours
_gr_col_primary            dd $ffff2222
_gr_col_secondary          dd $ff2074b0
_gr_col_title              dd $ffffffff
_gr_col_text               dd $ffc0c0c0
_gr_col_muted              dd $ff808080
_gr_col_background         dd $ff222222
_gr_col_dark_background    dd $ff151515

; Scale
_gr_win_width         dd 0  ; The width of the client area of the window
_gr_win_height        dd 0  ; The height of the client area of the window
_gr_pixel_scale_x     dd 2
_gr_pixel_scale_y     dd 2
_gr_pixel_scale_min   dd 1
_gr_pixel_scale_max   dd 5
_gr_app_width         dd 0  ; The width of the app virtual buffer
_gr_app_height        dd 0  ; The height of the app virtual buffer

; Layout
_gr_margin_bottom     db 5
_gr_margin_left       db 5
_gr_log_offset        dd 0

; Mouse coordinate (relative to the upper left corner of the window)
_gr_mouse_x        dq 0
_gr_mouse_y        dq 0

_gr_winbuffer      dq 0  ; A pointer to the main window real framebuffer (real window size)
_gr_appbuffer      dq 0  ; A pointer to the application virtual framebuffer (smaller)

; System time
_gr_system_time    SYSTEMTIME                       ; The current system time

_gr_logo_w     dd 16
_gr_logo_h     dd 16
_gr_logo_data  dd 0

section '.idata' import data readable writeable

library kernel32,'KERNEL32.DLL',\
        user32,'USER32.DLL', \
        gdi,'GDI32.DLL', \
        shell32,'SHELL32.DLL', \
        msvcrt, "MSVCRT.DLL"

include 'api\kernel32.inc'
include 'api\user32.inc'
        import gdi,SetDIBitsToDevice,'SetDIBitsToDevice'
        import shell32,ShellExecute, 'ShellExecuteA'
        import msvcrt,strlen, 'strlen', \
                malloc, 'malloc', \
                realloc, 'realloc', \
                strcpy, 'strcpy', \
                free, 'free', \
                strcmp, 'strcmp', \
                sprintf, 'sprintf'

section '.rsrc' resource data readable
    directory RT_ICON, icons, RT_GROUP_ICON, group_icons
        resource icons, 1, LANG_NEUTRAL, icon_data
        resource group_icons, 2, LANG_NEUTRAL, main_icon
        icon main_icon, icon_data, 'r3icol.ico'
