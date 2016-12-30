;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Debug routines
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ser_init
;
; Set up serial port.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
txinit:
    ; UBBR =  (F_CPU / 16 / BaudRate ) - 1 = 16000000/16/9600 - 1 = 103
    clr		r17
    ldi		r16, 103
    sts		UBRR0H, r17
    sts		UBRR0L, r16
    
    ; Single speed
    clr		r16
    sts		UCSR0A, r16

    ; Enable receiver and transmitter
    ldi		r16, (1<<RXEN0)|(1<<TXEN0)
    sts		UCSR0B,r16
    
    ; 8-N-1
    ldi		r16, (0<<USBS0)|(3<<UCSZ00)
    sts		UCSR0C,r16

    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; print_char
;
; Send a single character down the serial port.
;
; Inputs:
;   r16 -   Character to send
;
; Affected - r17
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
print_char:
    ; Wait for empty transmit buffer
    lds		r17, UCSR0A
    sbrs	r17, UDRE0
    rjmp	print_char

    ; Put data (r16) into buffer, sends the data
    sts		UDR0,r16
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; print_int
;
; Send a 16-bit signed integer down the serial port as decimal.
;
; Inputs:
;   r24, r25 -  Integer to send
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
print_int:
    tst		r25
    brpl	print_uint
    push	r16
    ldi		r16, '-'
    call	print_char
    pop		r16
    com		r24
    com		r25
    inc		r24
    brne	print_uint
    inc		r25
    ; Fall through

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; print_uint
;
; Send a 16-bit unsigned integer down the serial port as decimal.
;
; Inputs:
;   r24, r25 -  Integer to send
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
print_uint:
    push	r16
    push	r22
    push	r23
    push	r24
    push	r25
    push	zl
    push	zh
    loadzp	digits	; Powers of 10 table
txwrd1:
    lpm		r22, z+		; Load power of 10 into r22,r23
    lpm		r23, z+
    ldi		r16, '0'	; Current digit
txwrd2:
    sub		r24, r22	; Subtract power of 10
    sbc		r25, r23
    brcs	txwrd3
    inc		r16
    rjmp	txwrd2
txwrd3:
    add		r24, r22	; Went negative, add it back
    adc		r25, r23
    call	print_char
    cpi		r22, 10
    brne	txwrd1
    mov		r16, r24
    ori		r16, '0'
    call	print_char
    pop		zh
    pop		zl
    pop		r25
    pop		r24
    pop		r23
    pop		r22
    pop		r16
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; print_hex
;
; Sends a byte down the serial port formatted as hexidecimal.
;
; Inputs:
;   r16 - Byte to send
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
print_hex:
    push	r17
    push	r16
    swap	r16
    call	print_nib
    pop		r16
    push	r16
    call	print_nib
    pop		r16
    pop		r17
    ret

print_nib:
    andi	r16, 0xf
    cpi		r16, 0xa
    brlo	txnib1
    ldi		r17, 'a'-0xa
    rjmp	txnib2
txnib1:
    ldi		r17, '0'
txnib2:
    add		r16, r17
    rjmp	print_char

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; print_vec
;
; Prints a vector to the serial port as signed decimal x,y
;
; Inputs:
;   Y -     Pointer to vector
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;    
print_vec:
    push    r16
    push    r24
    push    r25
    ld      r24, y
    ldd     r25, y+1
    rcall   print_int
    ldi     r16, ','
    rcall   print_char
    ldd     r24, y+2
    ldd     r25, y+3
    rcall   print_int
    ldi     r16, ' '
    rcall   print_char
    pop     r25
    pop     r24
    pop     r16
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; print_all
;
; Prints the motion vectors for the current player.
; Format: acc.x,acc.y vel.x,vel.y pos.x,pos.y scn.x,scn.y
;
; Inputs:
;   yh      High byte of pointer to player structure.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;    
    ; Print all vectors (acc, vel, pos, scn)
print_all:
    push	yl
    ldi     yl, low(acc)
    rcall   print_vec
    ldi     yl, low(vel)
    rcall   print_vec
    ldi     yl, low(pos)
    rcall   print_vec
    ldi     yl, low(scn)
    rcall   print_vec
    rcall   crlf
    pop		yl
    ret

crlf:
    push	r16
    ldi		r16, '\r'
    rcall	print_char
    ldi		r16, '\n'
    rcall	print_char
    pop		r16
    ret

; Print word followed by space
printspc:
    push	r16
    rcall	print_int
    ldi		r16, ','
    rcall	print_char
    pop		r16
    ret

print_player:
    push    yl 
    push    r16
    ldi     yl, low(player1)
    ldi     r16, 4
print_player1:
    rcall   print_rect
    adiw    yl, RECT_SIZE
    dec     r16
    brne    print_player1
    rcall   crlf
    pop     r16
    pop     yl
    ret

print_rect:
    push    r24
    push    r25
    ldd		r24, y+RECT_LEFT_L
    ldd		r25, y+RECT_LEFT_H
    dbgcall	printspc

    ldd		r24, y+RECT_TOP_L
    ldd		r25, y+RECT_TOP_H
    dbgcall	printspc

    ldd		r24, y+RECT_WIDTH_L
    ldd		r25, y+RECT_WIDTH_H
    dbgcall	printspc

    ldd		r24, y+RECT_HEIGHT_L
    ldd		r25, y+RECT_HEIGHT_H
    dbgcall	printspc
    dbgcall	crlf
    pop     r25
    pop     r24
    ret

digits:
    .dw 10000
    .dw 1000
    .dw 100
    .dw 10

tests:
    ; Copy test data
    loadzp  test_data_rom
    loadyd  test_data
    ldi     r16, 128
    rcall   copyp
    
    rjmp    test_add_vec
    ; Test random number generator
test_rand:
    ldi     r16, 1
    sts     rseed, r16
test1:
    rcall   rand
    mov     r24,  r0
    clr     r25
    rcall   print_int
    rcall   crlf    
    cpi     r24, 1
    brne    test1

    ; Add vectors
test_add_vec:
    loadyd  test_vec1
    loadzd  test_vec2
    rcall   add_vec
    loadyd  test_vec1
    rcall   print_vec
    rcall   crlf
    loadyd  test_vec2
    rcall   print_vec
    rcall   crlf
            
test_remove_vec:
    loadyd  test_vec1
    loadzd  test_vec2
    rcall   subtract_vec
    loadyd  test_vec1
    rcall   print_vec
    rcall   crlf
    loadyd  test_vec2
    rcall   print_vec
    rcall   crlf

test_scale_vec:
    loadyd  vel
    loadzd  test_vec2
    rcall   scale_vec
    loadyd  vel
    rcall   print_vec
    rcall   crlf

    loadyd  vel
    loadzd  zero_vec
    rcall   scale_vec
    loadyd  vel
    rcall   print_vec
    rcall   crlf

test_descale_vec:
    loadyd  pos
    loadzd  test_vec1
    rcall   descale_vec
    loadyd  pos
    rcall   print_vec
    rcall   crlf
    
    loadyd  pos
    loadzd  zero_vec
    rcall   descale_vec
    loadyd  pos
    rcall   print_vec
    rcall   crlf
    
test_hit_test:
    ; TODO

    ; Clear screen
    rcall   erase_screen

test_draw_point:
    loadyd  test_vec2
    rcall   draw_point

test_draw_line:
    rcall   tft_vert
    loadyd  zero_vec
    rcall   move_xy

    ldi     r16, 240
    ldi     r26, low(PLAYER_1_COLOR)
    ldi     r27, high(PLAYER_1_COLOR)
    rcall   draw_line

    rcall   tft_horiz
    loadyd  test_vec2
    rcall   move_xy
    ldi     r16, 25
    ldi     r26, 0xff
    ldi     r27, 0xff
    rcall   draw_line

test_draw_cursor:
    loadyd  test_vec3
    ldi     r26, low(PLAYER_1_COLOR)
    ldi     r27, high(PLAYER_1_COLOR)
    rcall   draw_cursor

test_draw_rect:
    loadyd  test_rect1
    ldi     r26, low(PLAYER_1_COLOR)
    ldi     r27, high(PLAYER_1_COLOR)
    rcall   draw_rect

    loadyd  test_rect2
    ldi     r26, low(PLAYER_2_COLOR)
    ldi     r27, high(PLAYER_2_COLOR)
    rcall   draw_rect

done:
    rjmp    done

    .dseg
test_data:
zero_vec:   .byte   VECTOR_SIZE
test_vec1:  .byte   VECTOR_SIZE
test_vec2:  .byte   VECTOR_SIZE
test_vec3:  .byte   VECTOR_SIZE
test_rect1: .byte   RECT_SIZE
test_rect2: .byte   RECT_SIZE
left_half:  .byte   RECT_SIZE
right_half: .byte   RECT_SIZE

    .cseg

test_data_rom:
    .dw     1, 1            ; zero_vec
    .dw     1324, 510       ; test_vec1
    .dw     23, 122         ; test_vec2
    .dw     300, 150        ; test_vec3
    defrect 25, 45, 50, 75  ; test_rect1
    defrect 50, 60, 100, 25 ; test_rect2
    defrect 0, 0, SCREEN_WIDTH/2, SCREEN_HEIGHT ; left_half
    defrect SCREEN_WIDTH/2+1, 0, SCREEN_WIDTH/2, SCREEN_HEIGHT  ; right half
test_data_rom_end:
