; Debug call.  Ignored if DEBUG not defined
.macro dbgcall
    .if DEBUG
    call	@0
    .endif
.endm

.macro  dbgchar
    .if DEBUG
        push    r16
        ldi     r16, @0
        rcall   txser
        pop     r16
    .endif
.endm

; Load address in data space into Y register
.macro loadyd
    ldi	yh, high(@0)
    ldi yl, low(@0)
.endm

; Load address in data space into Z register
.macro loadzd
    ldi	zh, high(@0)
    ldi zl, low(@0)
.endm

; Load address in program space into Z register
.macro loadzp 
    ldi	zh, high(@0<<1)
    ldi zl, low(@0<<1)
.endm

; Define rectangle initializer
.macro  defvect
    .db @0, @1
.endmacro

; Define rectangle initializer
.macro  defrect
    .db @0, @1, @2, @3
.endmacro
