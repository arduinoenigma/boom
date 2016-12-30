;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; tft.asm
;
; TFT color display interface routines
;
; Dec 20, 2016 - Jim Shortz (hackaday.io/jimshortz)
;
; Based on Seed Studio TFT library - https://github.com/Seeed-Studio/TFT_Touch_Shield_V1
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; TFT Pins
; Port B
.equ	TFT_CS	=	2
.equ	TFT_RS	=	3
.equ	TFT_WR	=	4
.equ	TFT_RD	=	5

; TFT Registers
.equ	TFT_ENTRY =		0x03
.equ	TFT_SETY =		0x20	; Intentionally flipped to use in landscape mode
.equ	TFT_SETX =		0x21
.equ	TFT_WRD	 =		0x22

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; send_cd
;
; Sends a command and word of data to the TFT module
;
; Inputs:
;	r22			-	Command to send
;	r24, r25	-   Word to send (low, high)
;
; Affects: r18
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
send_cd:
    push	r24
    push	r25
    rcall	send_command
    pop		r23
    pop		r22
    rjmp	send_data
    
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; send_command
;
; Sends a command to the TFT module
;
; Inputs:
;	r22		- Command to send
;
; Affects: r18, r23
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
send_command:
    ldi		r18, (1<<TFT_RD)
    clr		r23
    rjmp	send_core

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; send_data
;
; Sends a word of data to the TFT module
;
; Inputs:
;	r22, r23	- Word to send (low, high)
;
; Affects: r18
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
send_data:
    ldi	r18, (1<<TFT_RS) | (1<<TFT_RD)

send_core:
    push	r22
    out		PORTB, r18
    
    ; Send high byte
    mov		r22, r23
    rcall	send_byte

    ; Strobe WR line
    sbi PORTB, TFT_WR
    cbi PORTB, TFT_WR

    ; Send low byte
    pop		r22
    rcall	send_byte

    ; WR_HIGH;
    sbi PORTB, TFT_WR

    ; CS_HIGH;
    sbi PORTB, TFT_CS
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; send_byte
;
; Sends a byte to the TFT module.  Internal method, to be used
; by send_command and send_data only.
;
; Inputs:
;	r22			-	 Byte to send
;
; Affects: r18, r23
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
send_byte:
    ; Shift r22 left 2 bits
    clr		r23
    lsl		r22
    rol		r23
    lsl		r22
    rol		r23

    ; PORTD |= lower 6 bits (r22)
    in		r18, PORTD
    andi	r18, 0b00000011
    or		r18, r22
    out		PORTD, r18

    ; PORTB |= upper 2 bits (r23)
    in		r18, PORTB
    andi	r18, 0b11111100
    or		r18, r23
    out		PORTB, r18

    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; tft_init
;
; Initializes the TFT display module
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
tft_init:
    ; Set up pins
    ldi		r22, (1<<TFT_CS) | (1<<TFT_RD) | (1<< TFT_WR) | (1 << TFT_RS) | 0x3
    out		DDRB, r22
    ldi		r22, 0b11111100
    out		DDRD, r22
    ldi		r22, (1<<TFT_CS) | (1<<TFT_RD) | (1<< TFT_WR) | (1 << TFT_RS)
    out		PORTB, r22
    clr		r22
    out		PORTD, r22
    
    ; Loop through the initialization commands stored in table
    loadzp	tftinit_cmds
tftinit1:
    lpm		r22, z+			; Command
    cpi		r22, 0x00		; End of table?
    breq	tftinit9

    ; Ordinary command
    rcall	send_command
    lpm		r23, z+
    lpm		r22, z+
    rcall	send_data
    rjmp	tftinit1

    ; End of table reached
tftinit9:
    ret

    ; Commands to initialize the TFT display
    ; Format: cmd, hibyte, lobyte
tftinit_cmds:
    .db \
    0x1, 0x1, 0x0, \
    0x60, 0xA7, 0x0, \
    0x61, 0x0, 0x1, \
    0x10, 0x14, 0xE0, \
    0x7, 0x1, 0x33, \
    0x0	; End


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; tft_horiz
;
; Changes the TFT module to auto-increment in the horizontal direction.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
tft_horiz:
    ldi		r22, TFT_ENTRY
    ldi		r24, 0x38
    ldi		r25, 0x50
    rjmp	send_cd

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; tft_vert
;
; Changes the TFT module to auto-increment in the vertical direction.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
tft_vert:
    ldi		r22, TFT_ENTRY
    ldi		r24, 0x30
    ldi		r25, 0x50
    rjmp	send_cd

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; erase_rect
;
; Draw a black rectangle
;
; Inputs:
;	Y - Pointer to rectangle structure
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
erase_rect:
    ldi     r26, low(SKY_COLOR)
    ldi     r27, high(SKY_COLOR)
    ; Fall through

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; draw_rect
;
; Draw a filled rectangle
;
; Inputs:
;	Y -         Pointer to rectangle structure
;   r26, r27 -  Color
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
draw_rect:
    ; r2 <- height remaining
    ldd		r2, y+RECT_HEIGHT_L
    rcall	tft_horiz

draw_rect1:
    ; Position cursor, X=left
    ldi		r22, TFT_SETX
    ld		r24, y
    ldd		r25, y+RECT_LEFT_H
    rcall	send_cd

    ; Y = top+height remaining-1
    ldi		r22, TFT_SETY
    ldd		r24, y+RECT_TOP_L
    add		r24, r2
    clr     r25
    rcall	send_cd
    
    ; Draw RECT_WIDTH pixels
    ldd     r16, y+RECT_WIDTH_L
    rcall   draw_line

    ; Decrement height remaining
    dec		r2
    brpl	draw_rect1

    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; draw_rects
;
; Draws a series of rectanges
;
; Inputs:
;	Y -	        Pointer to array of rects
;	r19	-	    Number of rects to draw
;   r26, r27 -  Color
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
draw_rects:
    push	r19
    rcall	draw_rect
    pop		r19
    adiw	y, RECT_SIZE
    dec		r19
    brne	draw_rects
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; draw_cursor
;
; Draws the cursor
;
; Inputs:
;   Y -         Pointer to position vector
;	r26,r27     Color
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

draw_cursor:
    ldi		r22, TFT_SETX
    ldd		r24, y+0
    ldd		r25, y+1
    rcall	send_cd
    ldi		r22, TFT_SETY
    ldd		r24, y+2
    ldd		r25, y+3
    sbiw    r24, low(CURSOR_HEIGHT/2)
    rcall	send_cd

    rcall	tft_vert
    ldi     r16, CURSOR_HEIGHT
    rcall   draw_line

    ldi		r22, TFT_SETX
    ldd		r24, y+0		
    ldd		r25, y+1
    sbiw    r24, low(CURSOR_WIDTH/2)
    rcall	send_cd

    ldi		r22, TFT_SETY
    ldd		r24, y+2
    ldd		r25, y+3
    rcall	send_cd

    rcall	tft_horiz
    ldi     r16, CURSOR_WIDTH
    rjmp    draw_line

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; draw_line
;
; Draws a run of pixels.
;
; Preconditions:
;   Call tft_vert or tft_horiz to set direction.
;   Call move_xy to set origin
;   Send TFT_WRD command (draw_line1 only)
;
; Inputs:
;   r16 -       Length of line
;   r26, r27 -  Color
;
; Affects: r18, r22, r23
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
draw_line:
    ldi		r22, TFT_WRD
    rcall	send_command
draw_line1:
    mov     r22, r26
    mov     r23, r27
    rcall	send_data
    dec		r16
    brne	draw_line1
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; move_xy
;
; Sets screen position to vector.
;
; Inputs:
;	Y - pointer to vector in screen coordinates
;
; Affects: Many
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
move_xy:
    ldi		r22, TFT_SETX
    ld		r24, y
    ldd		r25, y+1
    rcall	send_cd

    ldi		r22, TFT_SETY
    ldd		r24, y+2
    ldd		r25, y+3
    rcall	send_cd
    ret
           
draw_point:
    rcall   move_xy        
    ldi		r22, TFT_WRD
    ldi		r24, low(CURSOR_COLOR)
    ldi		r25, high(CURSOR_COLOR)
    rjmp	send_cd

.if DEBUG
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; erase_screen
;
; Used to clear screen (debug mode only).
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
erase_screen:
    loadyd  zero_vec
    rcall   move_xy

    rcall   tft_vert
    ldi     r22, TFT_WRD
    rcall   send_command

    ldi     r29, 2
t1:
    ldi     r30, 160
t2:
    ldi     r16, 240
t3:
    clr     r22
    clr     r23
    rcall   send_data
    dec     r16
    brne    t3
    dec     r30
    brne    t2
    dec     r29
    brne    t1
    ret

.endif