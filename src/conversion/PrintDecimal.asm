proc PrintDecimal, number:QWORD
    mov [number], rcx
    invoke sprintf, _lg_convert_decimal_buffer, _lg_convert_decimal_format, [number]
    fastcall ConsolePrintLine, _lg_convert_decimal_buffer
    ret
endp