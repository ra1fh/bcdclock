; Copyright (c) 2013 Ralf Horstmann <ralf@ackstorm.de>
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

;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; 	Input button state machine with typematic function
;;;
;;; 	Two events are handled:
;;;		- button state sample with button state in W
;;;		- timer tick with approx 100HZ
;;; 	- note that button input should be 0 == off and != 0 otherwise. If
;;;       hardware provides inverted value, that has to be normalized
;;; 	- if typematic is not desired: don't send timer tick events
;;;     - <statevar> and <countvar> has to be provided via FSR and initialized
;;;       outside
;;;
;;; 	The module requires two global scratch pad variables: reg_a, reg_b
;;;

list        p=16f505           
#include    <p16f505.inc>

#define	BUTTON_STATE_IDLE		0
#define	BUTTON_STATE_DEBOUNCE	1
#define	BUTTON_STATE_REPEAT_1	2
#define	BUTTON_STATE_REPEAT_2	3

#define	BUTTON_EVENT_SAMPLE		6
#define	BUTTON_EVENT_TICK		7
#define BUTTON_EVENT_ON			0

#define	BUTTON_DEBOUNCE_COUNT	.4
#define	BUTTON_REPEAT_COUNT_1	.100
#define	BUTTON_REPEAT_COUNT_2	.30

#define	BUTTON_IDLE				0
#define	BUTTON_DOWN				1
#define	BUTTON_UP				2

		GLOBAL	button_fsm_sample_R, button_fsm_tick_R
		EXTERN	reg_a, reg_b

#define	invar    reg_a
#define	statevar reg_b
#define countvar INDF
#define result   reg_a
		;; reg_a is used for both input and output
		
BUTTON	CODE
		
;;; 	button_fsm_sample_R
;;; 	* descripton:
;;; 	  pass button sample information to the state machine
;;; 	* input:
;;;       W:    button state (0 == off. everything else on)
;;; 	  FSR:  pointer to state variables
;;; 	* output:
;;; 	  reg_a:button event bitmask (BUTTON_IDLE, BUTTON_DOWN, BUTTON_UP)
;;;     * tempory variables used:
;;; 	  reg_a, reg_b

button_fsm_sample_R
		pagesel $
		;; normalize button state from (0 || >0) to 1 and 0 and store in reg_a
		;; please note 0 => off and != 0 => on.
		iorlw	0x00
		btfss	STATUS,Z
		movlw	.1
		movwf	invar
		bsf		invar, BUTTON_EVENT_SAMPLE
		goto	button_state_switch

;;; 	button_fsm_tick_R
;;; 	* descripton:
;;; 	  pass timer tick event to the button state machine. The
;;;       internal counters expect 100HZ ticks.
;;; 	* input:
;;; 	  FSR:  pointer to state variables
;;; 	* output:
;;; 	  reg_a:button event bitmask (BUTTON_IDLE, BUTTON_DOWN, BUTTON_UP)
;;;     * tempory variables used:
;;; 	  reg_a, reg_b

button_fsm_tick_R
		pagesel	$
		clrf	invar
		bsf		invar, BUTTON_EVENT_TICK
		;; fall through

button_state_switch
		movf	INDF,w			; FSR points to state, copy to w
		movwf	statevar		; copy W to local statevar
		incf	FSR,f			; point FSR to countvar
		bcf		STATUS,C
		
		btfsc	statevar,BUTTON_STATE_IDLE
		goto	button_fsm_idle
		btfsc	statevar,BUTTON_STATE_DEBOUNCE
		goto	button_fsm_debounce
		btfsc	statevar,BUTTON_STATE_REPEAT_1
		goto	button_fsm_repeat_1
		btfsc	statevar,BUTTON_STATE_REPEAT_2
		goto	button_fsm_repeat_2
		;; init
		bsf		statevar,BUTTON_STATE_IDLE
		;; falltrough
;;; IDLE
button_fsm_idle
		btfsc	invar, BUTTON_EVENT_TICK
		goto	button_fsm_ret_idle
		btfss	invar, BUTTON_EVENT_SAMPLE
		goto	button_fsm_ret_idle ; should not happen
		;; fall through
button_fsm_idle_sample
		btfss	invar, BUTTON_EVENT_ON
		goto	button_fsm_ret_idle
		;; fall through
		rlf		statevar,f		; -> BUTTON_STATE_DEBOUNCE
		movlw	BUTTON_DEBOUNCE_COUNT
		movwf	countvar
		goto	button_fsm_ret_idle

;;; DEBOUNCE
button_fsm_debounce
		btfsc	invar, BUTTON_EVENT_TICK
		goto	button_fsm_ret_idle
		btfss	invar, BUTTON_EVENT_SAMPLE
		goto	button_fsm_ret_idle ; should not happen
		;; fall through
button_fsm_debounce_sample
		btfsc	invar, BUTTON_EVENT_ON
		goto	button_fsm_debounce_sample_on
		goto	button_fsm_debounce_sample_off
button_fsm_debounce_sample_on
		decfsz	countvar, f
		goto 	button_fsm_ret_idle
		rlf		statevar,f		; -> BUTTON_STATE_REPEAT_1
		movlw	BUTTON_REPEAT_COUNT_1
		movwf	countvar
		goto	button_fsm_ret_down
button_fsm_debounce_sample_off
		clrf	statevar
		bsf		statevar,BUTTON_STATE_IDLE
		goto	button_fsm_ret_idle

;;; REPEAT 1
button_fsm_repeat_1
		btfsc	invar, BUTTON_EVENT_TICK
		goto	button_fsm_repeat_1_tick
		btfss	invar, BUTTON_EVENT_SAMPLE
		goto	button_fsm_ret_idle ; should not happen
		;; fall through
button_fsm_repeat_1_sample
		btfsc	invar, BUTTON_EVENT_ON
		goto	button_fsm_ret_idle ; sample on
		clrf	statevar
		bsf		statevar,BUTTON_STATE_IDLE
		goto	button_fsm_ret_up
button_fsm_repeat_1_tick
		decfsz	countvar,f
		goto	button_fsm_ret_idle
		rlf		statevar,f			; -> BUTTON_STATE_REPEAT_2
		movlw	BUTTON_REPEAT_COUNT_2
		movwf	countvar
		goto	button_fsm_ret_down

;;; REPEAT 2
button_fsm_repeat_2
		btfsc	invar, BUTTON_EVENT_TICK
		goto	button_fsm_repeat_2_tick
		btfss	invar, BUTTON_EVENT_SAMPLE
		goto	button_fsm_ret_idle ; should not happen
		;; fall through
button_fsm_repeat_2_sample
		btfsc	invar, BUTTON_EVENT_ON
		goto	button_fsm_ret_idle
		clrf	statevar
		bsf		statevar,BUTTON_STATE_IDLE
		goto	button_fsm_ret_up
button_fsm_repeat_2_tick
		decfsz	countvar,f
		goto	button_fsm_ret_idle
		movlw	BUTTON_REPEAT_COUNT_2
		movwf	countvar
		goto	button_fsm_ret_down

;;; RETURN
button_fsm_ret_up
		clrf	result
		bsf		result,BUTTON_UP
		goto	button_fsm_ret

button_fsm_ret_down
		clrf	result
		bsf		result,BUTTON_DOWN
		goto	button_fsm_ret

button_fsm_ret_idle
		clrf	result
		bsf		result,BUTTON_IDLE
		;; fallthrough

button_fsm_ret
		decf	FSR,f			; point FSR to statevar again
		movf	statevar,W		; copy state into W
		movwf	INDF			; copy state back to ext file register
		clrf	FSR				; make sure banksel bits get reset
								; in case state is higher bank
		retlw	0

		END
