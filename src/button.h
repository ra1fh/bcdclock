; Copyright (c) 2013 Ralf Horstmann <ralf@ackstorm.de> -*- mode: asm -*-
; 
; Permission to use, copy, modify, and distribute this software for any
; purpose with or without fee is hereby granted, provided that the above
; copyright notice and this permission notice appear in all copies.
; 
; THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
; WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
; MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
; ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
; WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
; ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
; OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

		EXTERN button_fsm_sample_R
		EXTERN button_fsm_tick_R

#define	BUTTON_IDLE		0
#define	BUTTON_DOWN		1
#define	BUTTON_UP		2

#define button_fsm_result reg_a

button_fsm_jump_vectors	MACRO

button_fsm_sample
		pagesel	button_fsm_sample_R
		goto 	button_fsm_sample_R
button_fsm_tick
		pagesel	button_fsm_tick_R
		goto 	button_fsm_tick_R
		
		ENDM
