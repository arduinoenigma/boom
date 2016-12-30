;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; touch.asm
;
; Touch screen interface routines.
;
; Dec 20, 2016 - Jim Shortz (hackaday.io/jimshortz)
;
; Based on Adafruit touch screen library - https://github.com/adafruit/Touch-Screen-Library
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Touch screen pins
.equ	XPLUS	= PORTC3
.equ	XMINUS	= PORTC1
.equ	YPLUS	= PORTC2
.equ	YMINUS	= PORTC0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; touch_read
;
; Reads the touch screen input
;
; Inputs:
;   Y - pointer to cursor position vector
;
; Outputs:
;   Z flag -	Set if pressed
;   Y = Y + 3
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
touch_read:
    ; This routine uses a table of parameters to read all 3 axes (x, y, z)
    loadzp	touch_tbl
    ldi		r16, touch_tbl_size

touch_read1:
    ; Push DDR, PORT, ADMUX values from table to hardware
    lpm		r0, Z+
    out		DDRC, r0
    lpm		r0, Z+
    out		PORTC, r0
    lpm		r0, Z+
    sts		ADMUX, r0

    ; Read two samples - abort if they don't match
    rcall	adc_read
    mov		r26, r2
    mov		r27, r3
    rcall	adc_read
    cp		r26, r2
    cpc		r27, r3
    brne	touch_read9

    ; Subtract offset from table
    lpm		r0, Z+
    clr		r1
    sub		r2, r0
    sbc		r3, r1

    ; Multiply by the numerator
    lpm		r18, Z+
    rcall	mul168u

    ; Divide by the denominator
    lpm		r18, Z+
    rcall	div168u
    st		y+, r0
    st		y+, r1

    ; More axes remaining?
    dec		r16
    brne	touch_read1

    ; Set Z flag if z' < 256 (screen was pressed)
    ld      r0, -y  ; touch_z + 1
    tst     r0

touch_read9:
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; adc_read
;
; Reads the on-chip A to D converter
;
; Inputs -
;   ADMUX   - Set to appropriate channel.
;   
; Outputs -
;   r2, r3  - Output value (0-1023)
;
; Affected -
;   r17
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
adc_read:
    ; Start A/D conversion
    ldi		r17, (1<<ADEN)|(1<<ADPS2)|(1<<ADPS1)|(1<<ADPS0)|(1<<ADSC)
    sts		ADCSRA, r17

   ; Wait for conversion to complete
adc_read1:
    lds		r17, ADCSRA
    sbrc	r17, ADSC
    rjmp	adc_read1

    ; Read value from ADC
    lds		r2, ADCL
    lds		r3, ADCH
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Data tables
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.equ	TOUCH_TBL_SIZE	= 3

touch_tbl:
    ; Format - DDR, PORTC, ADMUX, offset, numerator, denominator
    
    ; The X and Y values are carefully chosen such that 
    ; (adc_value - offset) * numerator / denominator will transform
    ; into the correct screen coordinates.
    
    ; These numbers are a bit different from those in the Adafruit library
    ; because 1) we have X and Y flipped for landscape mode and 2)
    ; Adafruit immediately subtracts the numbers from 1023 before mapping 
    ; them.  Also, we simplify the fractions to avoid 16-bit overflow.
    
    ; x' = (x-83)*320/(940-120) = (x-83)*16/41
    .db (1<<YPLUS) | (1<<YMINUS), (1<<YPLUS), XMINUS | (1 << REFS0), \
        83, 16, 41

    ; y' = (y-123)*240(940-140) = (y-123)*6/19
    .db (1<<XPLUS) | (1<<XMINUS), (1<<XPLUS), YPLUS | (1 << REFS0), \
        123, 6, 19

    ; z' = (z-182)*1/3
    ; These numbers transform z values < 950 to z' < 256.  This
    ; allows a super-cheap pressure threshold test.
    .db (1<<XPLUS) | (1<<YMINUS), 1<<YMINUS, YPLUS | (1 << REFS0), \
        182, 1, 3
