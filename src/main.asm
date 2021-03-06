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

;************************************************************************ 
;   Description:    BCDCLOCK                                            *     
;                                                                       * 
;   For Anelace Inc. BCD clock with 16F505                              *
;                                                                       * 
;************************************************************************ 
;   Pin assignments:                                                    * 
;       RB0 = 4051 PIN A                                                * 
;       RB1 = 4051 PIN B                                                * 
;       RB2 = 4051 PIN C / SW 3                                         * 
;       RB3 = 100 HZ net frequency pulse                                * 
;       RB4 = clock                                                     * 
;       RB5 = clock                                                     * 
;       RC0 = LED Matrix ROW 0                                          * 
;       RC1 = LED Matrix ROW 1                                          * 
;       RC2 = LED Matrix ROW 2                                          * 
;       RC3 = LED Matrix ROW 3                                          * 
;       RC4 = SW1                                                       * 
;       RC5 = SW2                                                       * 
;************************************************************************ 

		list        p=16f505           
		#include    <p16f505.inc>
		#include	"button.h"
		#include	"sub.h"

;****** CONFIGURATION ***************************************************
					; ext reset, no code protect, no watchdog 
		__CONFIG    _MCLRE_OFF & _CP_OFF & _WDT_OFF & _XT_OSC

;****** MACROS **********************************************************

;;; output ports
#define PORT_BIT_SW1		PORTC,5
#define PORT_BIT_SW2		PORTC,4
#define PORT_BIT_SW3		PORTB,2
#define PORT_BIT_CLOCK		PORTB,3

;;; bits in the input_flags register
;;; that contains the input state
#define SHADOW_BIT_SW1		input_flags,0
#define SHADOW_BIT_SW2		input_flags,1
#define SHADOW_BIT_SW3		input_flags,2
#define SHADOW_BIT_CLOCK	input_flags,3

;;; bitmask to get single input line from input_flags
#define SHADOW_MASK_SW1 	1 << 0
#define SHADOW_MASK_SW2 	1 << 1
#define SHADOW_MASK_SW3 	1 << 2

;;; column state used by the output state machines
;;; that display the columns of the clock
#define OUTPUT_STATE_COL1	0
#define OUTPUT_STATE_COL2	1
#define OUTPUT_STATE_COL3	2
#define OUTPUT_STATE_COL4	3
#define OUTPUT_STATE_COL5	4

;;; The OUTPUT_STATE_DUTY_BIT indicates overflow when cycling through
;;; through the brightness (duty cycle) setting. Bit 2 means
;;; when cycling through 000, 001, 010, 011 the next step (100)
;;; activates bit 2 and we reset to 000. The register is
;;; output_state_wait_duty. Don't confuse with output_state_wait_counter
#define OUTPUT_STATE_DUTY_BIT 2

;;; configuration bits for different clock modes:
;;; nosec: don't display seconds
;;; blink: a bit that is switched with 2HZ for blinking
;;;        in configuration mode
;;; 12hour: 12hour and 24hour configuration bit
#define	OUTPUT_STATE_CONF_NOSEC		0
#define OUTPUT_STATE_CONF_BLINK		1
#define OUTPUT_STATE_CONF_12HOUR	2

;;; Main state machine for clock operation
;;; clock: display clock
;;; brightness: configure brightness
;;; seconds: configure second display
;;; 12hour: configure 12hour 24hour mode
#define MODE_STATE_CLOCK 		0
#define MODE_STATE_BRIGHTNESS 	1
#define MODE_STATE_SECONDS 		2
#define MODE_STATE_12HOUR		3

;;; Events the main state machine reacts to
#define	MODE_EVENT_SW1			0
#define MODE_EVENT_SW2			1
#define MODE_EVENT_SW3			2

;;; Actions the main state machines fire when
;;; events or state changes happen
#define	MODE_ACTION_MINUTES		0
#define MODE_ACTION_HOURS		1
#define	MODE_ACTION_BRIGHTNESS	2
#define MODE_ACTION_SECONDS		3
#define	MODE_ACTION_12HOUR		4

;;; how many cycles to wait until input signal is considered stable
#define CLOCK_DEBOUNCE_COUNT .4

;;; divider to generate 1HZ from 100HZ mains frequency
#define CLOCK_TICK_COUNT_1HZ .100

;;; divider to generate 2HZ from 100HZ mains frequency
#define CLOCK_TICK_COUNT_2HZ .50
		
;***** VARIABLE DEFINITIONS *********************************************

		;; make symbols visible to other modules
		GLOBAL reg_a, reg_b, reg_c, reg_d

DATA_S	UDATA_SHR

;;; The following variables are used for passing parameters to
;;; functions and to pass return values back. Parameters and return
;;; values should start from reg_a to reg_d. These variables can also
;;; be used as internal scratch pad for functions. When calling
;;; a function, there is no guarantee that those variable stay
;;; unmodified.
reg_a			res	1
reg_b			res	1
reg_c			res	1
reg_d			res 1

;;; input line state shadow register
input_flags		res 1
;;; tick state register used for generating 100Hz clock
tick_state		res	1

;;; bank_0 is an ordenary label to be used in banksel
DATA_0	UDATA   0x10
bank_0

;;; counters representing the current time
clock_hour		res 1
clock_min		res 1
clock_sec		res 1
clock_milli		res 1

;;; shadow registers which contain the bit for the output port
;;; for a single column. reasoning behind these is that it's
;;; a bit more work to calculate these. and they change only
;;; maximum once per seconds. so caching saves some cycles
output_shadow_col_1 res 1
output_shadow_col_2 res 1
output_shadow_col_3 res 1
output_shadow_col_4 res 1
output_shadow_col_5 res 1

;;; the state register for displaying the columns
output_state	res 1

;;; the configuration and blink bits, see above
output_state_conf res 1

;;; duty cycle from 0-3 for the brightness
output_state_wait_duty   	res 1

;;; this counter counts the output cycles. only if is
;;; greater or equal the selected output_state_wait_duty,
;;; the output will get displayed
output_state_wait_counter	res 1

;;; main state machine register
mode_state		res 1
;;; action bitfield that are results from state transitions
;;; of the Main state machine
mode_state_actions res 1

DATA_1 UDATA	0x30
bank_1

;;; state machine registers for the button state
switch_state_1	res 2
switch_state_2	res 2
switch_state_3	res 2

;***** RC CALIBRATION ***************************************************
		
RCCAL   CODE    0x3FF		; processor reset vector
        res 1				; holds internal RC cal value, as a movlw k

;***** RESET VECTOR *****************************************************
		
RESET	CODE    0x000		; effective reset vector
		movwf   OSCCAL		; apply internal RC factory calibration

start	pagesel main_R
		goto	main_R

;***** JUMP VECTORS *****************************************************

;;; The target address of call instructions has to be within the lower 256
;;; byte of each 512 byte page as bit 8 is hardcoded to 0. For goto there
;;; is no such restriction. Therefore provide a number of function entry
;;; points here so that functions can be reached anywhere in memory.
;;;
;;; I believe there should be more pagesel statement in the main code
;;; section, since there is no guarantee that it ends up below 0x200.
;;; It does for me currently, and hence the code works, but it could
;;; easily break.
;;;
;;; For more info, see:
;;; http://www.talkingelectronics.com/projects/Elektor/Gooligum%20PIC%20Tutorials/PIC_Base_A_3.pdf

tick_sample
		pagesel tick_sample_R
		goto	tick_sample_R
clock_tick_seconds
		pagesel	clock_tick_seconds_R
		goto	clock_tick_seconds_R
clock_tick_minutes_manual
		pagesel	clock_tick_minutes_manual_R
		goto	clock_tick_minutes_manual_R
clock_tick_hours_manual
		pagesel	clock_tick_hours_manual_R
		goto	clock_tick_hours_manual_R
read_inputs
		pagesel	read_inputs_R
		goto	read_inputs_R
output_column_1
		pagesel	output_column_1_R
		goto	output_column_1_R
output_column_2
		pagesel	output_column_2_R
		goto	output_column_2_R
output_column_3
		pagesel	output_column_3_R
		goto	output_column_3_R
output_column_4
		pagesel	output_column_4_R
		goto	output_column_4_R
output_column_5
		pagesel	output_column_5_R
		goto	output_column_5_R
output_clear
		pagesel	output_clear_R
		goto	output_clear_R
		
output_set_duty_cycles
		pagesel	output_set_duty_cycles_R
		goto	output_set_duty_cycles_R
		
output_toggle_seconds
		pagesel	output_toggle_seconds_R
		goto	output_toggle_seconds_R

output_toggle_12hour
		pagesel	output_toggle_12hour_R
		goto	output_toggle_12hour_R

mode_state_switch_init
		pagesel	mode_state_switch_init_R
		goto	mode_state_switch_init_R
		
mode_state_switch_1
		pagesel	mode_state_switch_1_R
		goto	mode_state_switch_1_R

mode_state_switch_2
		pagesel	mode_state_switch_2_R
		goto	mode_state_switch_2_R

mode_state_switch_3
		pagesel mode_state_switch_3_R
		goto	mode_state_switch_3_R

get_zero_sixty
		pagesel	get_zero_sixty_R
		goto	get_zero_sixty_R

get_zero_twelve
		pagesel	get_zero_twelve_R
		goto	get_zero_twelve_R

;;; include jump tables from other modules. in this case they
;;; are defined as macro in the header file

;;;		button-fsm.asm
		button_fsm_jump_vectors

;;; 	bcdclock-sub.asm
		bcdclock_sub_jump_vectors

;***** BCD ENCODING TABLES **********************************************

;;; new code section, can be located anywhere in memory.
;;; that means we need to pagesel so that addwf works correctly.
JUMP	CODE

;;; bcd coding from 0-59 to low/high
;;;	W:   number to decode
;;; RET: number in BCD format
get_zero_sixty_R
		pagesel $
		addwf	PCL,f
		dt		0x00
		dt		0x01
		dt		0x02
		dt		0x03
		dt		0x04
		dt		0x05
		dt		0x06
		dt		0x07
		dt		0x08
		dt		0x09
		dt		0x10
		dt		0x11
		dt		0x12
		dt		0x13
		dt		0x14
		dt		0x15
		dt		0x16
		dt		0x17
		dt		0x18
		dt		0x19
		dt		0x20
		dt		0x21
		dt		0x22
		dt		0x23
		dt		0x24
		dt		0x25
		dt		0x26
		dt		0x27
		dt		0x28
		dt		0x29
		dt		0x30
		dt		0x31
		dt		0x32
		dt		0x33
		dt		0x34
		dt		0x35
		dt		0x36
		dt		0x37
		dt		0x38
		dt		0x39
		dt		0x40
		dt		0x41
		dt		0x42
		dt		0x43
		dt		0x44
		dt		0x45
		dt		0x46
		dt		0x47
		dt		0x48
		dt		0x49
		dt		0x50
		dt		0x51
		dt		0x52
		dt		0x53
		dt		0x54
		dt		0x55
		dt		0x56
		dt		0x57
		dt		0x58
		dt		0x59

;;; bcd coding from 0-23 for 12 hour clock
;;; please note the bcd values repeat
;;; W:   number to decode
;;; RET: bcd encoded value in 12 hour format
get_zero_twelve_R
		pagesel $
		addwf	PCL,f
		dt		0x12
		dt		0x01
		dt		0x02
		dt		0x03
		dt		0x04
		dt		0x05
		dt		0x06
		dt		0x07
		dt		0x08
		dt		0x09
		dt		0x10
		dt		0x11
		dt		0x12
		dt		0x01
		dt		0x02
		dt		0x03
		dt		0x04
		dt		0x05
		dt		0x06
		dt		0x07
		dt		0x08
		dt		0x09
		dt		0x10
		dt		0x11
		
MAIN	CODE
		
;************************************************************************
;***** SUB ROUTINES *****************************************************
;************************************************************************

;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; 	Output Routines
;;;
;;; select output column via port b and copy output shadow register
;;; to port c

output_column_1_R
		clrf	PORTC
		movlw	0x00
		movwf	PORTB
		movfw	output_shadow_col_1
		andlw	0x0f
		movwf	PORTC
		retlw	0

output_column_2_R
		clrf	PORTC
		movlw	0x01
		movwf	PORTB
		movfw	output_shadow_col_2
		andlw	0x0f
		movwf	PORTC
		retlw	0

output_column_3_R
		clrf	PORTC
		movlw	0x02
		movwf	PORTB
		movfw	output_shadow_col_3
		andlw	0x0f
		movwf	PORTC
		retlw	0

output_column_4_R
		clrf	PORTC
		movlw	0x03
		movwf	PORTB
		movfw	output_shadow_col_4
		andlw	0x0f
		movwf	PORTC
		retlw	0

output_column_5_R
		clrf	PORTC
		movlw	0x04
		movwf	PORTB
		movfw	output_shadow_col_5
		andlw	0x0f
		movwf	PORTC
		retlw	0

;;; clear output, all LEDs off
output_clear_R
		clrf	PORTC
		movlw	0x05
		movwf	PORTB
		retlw	0

;;; cycle through duty cycle setting from 0 to max duty bit
output_set_duty_cycles_R
		incf	output_state_wait_duty,f
		btfsc	output_state_wait_duty,OUTPUT_STATE_DUTY_BIT
		clrf	output_state_wait_duty
		retlw	0

;;; toggle the seconds bit in output state register
output_toggle_seconds_R
		movlw	1 << OUTPUT_STATE_CONF_NOSEC
		xorwf	output_state_conf,f
		retlw	0

;;; toggle 12 hour bit in output state register
output_toggle_12hour_R
		movlw	1 << OUTPUT_STATE_CONF_12HOUR
		xorwf	output_state_conf,f
		retlw	0
		
;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; 	Read inputs into shadow register
;;;
read_inputs_R
		;; switch dual use RB2 to input
		clrf	PORTB
		clrf	PORTC
		clrf	input_flags
		movlw   b'00111100'
		;;        x-------   unused
		;;        -x------   unused
		;;        --1-----   RB5 input
		;;        ---1----   RB4 input
		;;        ----1---   RB3 input
		;;        -----1--   RB2 input
		tris	PORTB

		;; read input lines into shadow register
		btfss	PORT_BIT_SW1
		bsf		SHADOW_BIT_SW1
		btfss	PORT_BIT_SW2
		bsf		SHADOW_BIT_SW2
		btfsc	PORT_BIT_SW3
		bsf		SHADOW_BIT_SW3
		btfsc	PORT_BIT_CLOCK
		bsf		SHADOW_BIT_CLOCK

		;; switch dual use RB2 back to output
		movlw	b'00111000'
		;;        x-------   unused
		;;        -x------   unused
		;;        --1-----   RB5 input
		;;        ---1----   RB4 input
		;;        ----1---   RB3 input
		;;        -----0--   RB2 output
		tris	PORTB
		
		clrf	PORTB
		retlw	0

;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; 	Generate 100HZ tick from the clock input
;;; 
tick_sample_R
		;; debounce clock line and return 1 on low-high change
		pagesel $
		btfss	SHADOW_BIT_CLOCK
		goto	tick_sample_off
tick_sample_on
		;; input line high: count up to debounce count
		;; if reached, return 1 once and set bit 7
		;; to remember the low-high change has been
		;; signalled to caller
		btfsc	tick_state,7
		retlw	0
		incf	tick_state,f
		movfw	tick_state
		xorlw	CLOCK_DEBOUNCE_COUNT
		btfss	STATUS,Z
		retlw	0
		bsf		tick_state,7
		retlw	1
tick_sample_off
		;; input line low: clear tick state
		clrf	tick_state
		retlw	0

;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Clock Tick. Count up clock_sec, clock_min, clock_hour register.
;;; Does clock counting and manual setting of hours and minutes.
;;; * input: none
;;; * output: none
;;; * local variables: reg_a
;;; 
;;; Entry point for manual minute setting. The difference is
;;; that when setting minutes manually, there should be no
;;; overflow to hourse, like a regular clock tick would do. So
;;; we record the the fact in bit 0 of reg_a and use the standard
;;; minute increasing function, that knows about this bit.
clock_tick_minutes_manual_R
		bcf		reg_a,0			; clear bit 0 of reg_a to indicate this
								; is manual
		goto	clock_tick_minutes

;;; Increment seconds counter, to be called every second
clock_tick_seconds_R
		bsf		reg_a,0			; set bit 0 of reg_a to indicate we're
								; called from timer input
		incf	clock_sec,f
		movfw	clock_sec
		;; if count == 60, fall through to increase minute
		;; and reset to 0
		xorlw	.60
		btfss	STATUS,Z
		retlw	1
	
clock_tick_minutes
		clrf	clock_sec
		incf	clock_min,f
		movfw	clock_min
		;; if count == 60, fall through to increase hours
		xorlw	.60
		btfss	STATUS,Z
		retlw	1

		;; reset minutes to 0. if this was manual setting,
		;; return. Otherwise fall through to inc hours
		clrf	clock_min
		btfss	reg_a,0			; cleared bit 0 indicates manual setting
		retlw	1

clock_tick_hours_manual_R
		;; entry point for manual hour setting but also fall through
		;; from minute overflow
		incf	clock_hour,f
		movfw	clock_hour
		;; if count == 24, reset to 0. Please not we do always
		;; 24 hour here and convert to 12 hour on output.
		xorlw	.24
		btfss	STATUS,Z
		retlw	1
		clrf	clock_hour		; clear all to zero, we're at 24:00
		retlw	1

;;;;;;; Configuration Mode ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; 
;;; Mode State Switch
;;; 
;;; Handle clock modes, especially configuration mode
;;; and clock mode.
;;; 
;;; - input:  none
;;; - output: W: action bit field
;;;
;;; reg_a is used to indicate the input event. There are
;;; multiple functions for various events that set a bit
;;; in reg_a and jump into mode_state_switch, which will
;;; then jump into the function reponsible for the current
;;; state
;;; 
;;; Depending on state and input event we do a state transition
;;; or return an action event 

mode_state_switch_init_R
		clrf	reg_a
		goto	mode_state_switch
		
mode_state_switch_1_R
		clrf	reg_a
		bsf		reg_a, MODE_EVENT_SW1
		goto	mode_state_switch

mode_state_switch_2_R
		clrf	reg_a
		bsf		reg_a, MODE_EVENT_SW2
		goto	mode_state_switch

mode_state_switch_3_R
		clrf	reg_a
		bsf		reg_a, MODE_EVENT_SW3
		goto	mode_state_switch

;;; jump to function for current state
;;; state might be on of the settings or
;;; the clock display mode. 
mode_state_switch
		bcf		STATUS,C
		btfsc	mode_state,MODE_STATE_CLOCK
		goto	mode_state_clock
		btfsc	mode_state,MODE_STATE_BRIGHTNESS
		goto	mode_state_brightness
		btfsc	mode_state,MODE_STATE_SECONDS
		goto	mode_state_seconds
		btfsc	mode_state,MODE_STATE_12HOUR
		goto	mode_state_12hour
		;; 		init
		bsf		mode_state,MODE_STATE_CLOCK
		goto	mode_state_switch

;;; 
;;; CLOCK STATE
;;; 
mode_state_clock
		btfsc	reg_a, MODE_EVENT_SW1
		goto	mode_state_clock_sw1
		btfsc	reg_a, MODE_EVENT_SW2
		goto	mode_state_clock_sw2
		btfsc	reg_a, MODE_EVENT_SW3
		goto	mode_state_clock_sw3
		;; 		fall through, return nothing
		goto	mode_state_ret_idle
		
mode_state_clock_sw1
		goto	mode_state_ret_minutes

mode_state_clock_sw2
		goto	mode_state_ret_hours
		
mode_state_clock_sw3
		clrf	mode_state
		bsf		mode_state,MODE_STATE_BRIGHTNESS
		goto	mode_state_ret_idle

;;;
;;; BRIGHTNESS SETTING STATE
;;; 
mode_state_brightness
		btfsc	reg_a, MODE_EVENT_SW1
		goto	mode_state_brightness_sw1
		btfsc	reg_a, MODE_EVENT_SW2
		goto	mode_state_brightness_sw2
		btfsc	reg_a, MODE_EVENT_SW3
		goto	mode_state_brightness_sw3
		;; 		fall through, return nothing
		goto	mode_state_ret_idle

mode_state_brightness_sw1
		clrf	mode_state
		bsf		mode_state,MODE_STATE_SECONDS
		goto	mode_state_ret_idle
		
mode_state_brightness_sw2
		goto	mode_state_ret_brightness
		
mode_state_brightness_sw3
		clrf	mode_state
		bsf		mode_state,MODE_STATE_CLOCK
		goto	mode_state_ret_idle

;;;
;;; SECONDS SETTING STATE - whether to display seconds
;;; 
mode_state_seconds
		btfsc	reg_a, MODE_EVENT_SW1
		goto	mode_state_seconds_sw1
		btfsc	reg_a, MODE_EVENT_SW2
		goto	mode_state_seconds_sw2
		btfsc	reg_a, MODE_EVENT_SW3
		goto	mode_state_seconds_sw3
		;; 		fall through, return nothing
		goto	mode_state_ret_idle

mode_state_seconds_sw1
		clrf	mode_state
		bsf		mode_state,MODE_STATE_12HOUR
		goto	mode_state_ret_idle
		
mode_state_seconds_sw2
		goto	mode_state_ret_seconds
		
mode_state_seconds_sw3
		clrf	mode_state
		bsf		mode_state,MODE_STATE_CLOCK
		goto	mode_state_ret_idle

;;;
;;; 12 HOUR SETTING STATE
;;; 
mode_state_12hour
		btfsc	reg_a, MODE_EVENT_SW1
		goto	mode_state_12hour_sw1
		btfsc	reg_a, MODE_EVENT_SW2
		goto	mode_state_12hour_sw2
		btfsc	reg_a, MODE_EVENT_SW3
		goto	mode_state_12hour_sw3
		;; 		fall through, return nothing
		goto	mode_state_ret_idle

mode_state_12hour_sw1
		clrf	mode_state
		bsf		mode_state,MODE_STATE_BRIGHTNESS
		goto	mode_state_ret_idle
		
mode_state_12hour_sw2
		goto	mode_state_ret_12hour
		
mode_state_12hour_sw3
		clrf	mode_state
		bsf		mode_state,MODE_STATE_CLOCK
		goto	mode_state_ret_idle

;;;
;;; Return Action bitmask
;;; 
mode_state_ret_idle
		retlw	0

mode_state_ret_minutes
		retlw	1<<MODE_ACTION_MINUTES

mode_state_ret_hours
		retlw	1<<MODE_ACTION_HOURS

mode_state_ret_brightness
		retlw	1<<MODE_ACTION_BRIGHTNESS

mode_state_ret_seconds
		retlw	1<<MODE_ACTION_SECONDS

mode_state_ret_12hour
		retlw	1<<MODE_ACTION_12HOUR

;;;;;;; Configuration Mode ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; 
;;; Mode State Switch
;;;
;;; - description: handle switch modes, especially configuration mode
;;;                and clock mode
;;; - input:  none
;;; - output: W: action bit field
;;;
		
;************************************************************************
;*****  MAIN PROGRAM ****************************************************
;************************************************************************

;;;;;;; Initialisation ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

		;; Option Register
		;; 0: PS0
		;; 1: PS1  Prescaler Rate Select
		;; 2: PS2  
		;; 3: PSA  Prescaler Assignment (1=WDT, 0=Timer0)
		;; 4: T0SE Timer0 edge detect
		;; 5: T0CS Timer0 clock source select (1=T0CKI, 0=Internal)
		;; 6: RBPU Pull up RB0, RB1, RB3, RB4 (1=Disabled, 0=Enabled)
		;; 7: RBWU Wake-up on Pin Change RB0, RB1, RB3, RB4 (1=Disabled, 0=Enabled)

		;; PS<0-2> = 111 := 1:256
		;; Prescaler assigned to Timer0
		;; Timer0 uses internal clock
main_R	movlw   b'11010111'
		;;        1-------   Wake up on pin change disables
		;;        -1------   Pull up disabled
		;;        --0-----   Timer0 internal clock
		;;        ---1----   Timer0 edge detect
		;;        ----0---   Prescaler assigned to Timer0 (PSA = 0)
		;;        -----111   Prescaler rate 1:256 
		option
		clrf	TMR0			; reset timer

		movlw   b'00110000'
		;;        --1-----   RC5 input
		;;        ---1----   RC4 input
		tris    PORTC
		
		movlw   b'00001000'
		;;        ----1---   RB3 input  
		tris	PORTB

		clrf	PORTB
		clrf	PORTC

		call	clear_file_registers
		pagesel	$
		banksel	bank_0

		call	mode_state_switch_init
		pagesel $

		movlw	.23
		movwf	clock_hour
		movlw	.39
		movwf	clock_min
		movlw	.59
		movwf	clock_sec
		
;;;;;;; Main Loop ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

		;;	 	timer0 loop, run loop every 0.256uS * 4 = 1.024ms
mainloop
		clrf	TMR0
wait_for_tmr0
		movfw	TMR0
		btfsc	STATUS,Z
		goto	wait_for_tmr0

		;;		input handling
		call	output_clear
		pagesel $
		call	read_inputs
		pagesel $

;;;;;;; Output state switch ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; TODO:
;;; Duty cycle handling shoud be an additional counting state
;;; In the output state switch. With the current implementation
;;; it seems the output state might be advanced two cycles and then
;;; paused two cycles, which is not intended

		;; 		Handle duty cycle
		incf	output_state_wait_counter,f
		btfsc	output_state_wait_counter,OUTPUT_STATE_DUTY_BIT
		clrf	output_state_wait_counter
		
		movf	output_state_wait_counter,w
		subwf	output_state_wait_duty,w
		;; 		C=1 => wait_counter is bigger than duty cycle => skip output state handling
		btfss	STATUS,C
		;; 		wait_counter is smaller than duty cycle => enter output state handling
		goto	output_state_out
		
output_state_switch
		bcf		STATUS,C
		btfsc	output_state,OUTPUT_STATE_COL1
		goto	output_state_col_1
		btfsc	output_state,OUTPUT_STATE_COL2
		goto	output_state_col_2
		btfsc	output_state,OUTPUT_STATE_COL3
		goto	output_state_col_3
		btfsc	output_state,OUTPUT_STATE_COL4
		goto	output_state_col_4
		btfsc	output_state,OUTPUT_STATE_COL5
		goto	output_state_col_5
		;; 		init
		clrf	output_state
		bsf		output_state,OUTPUT_STATE_COL1
		goto	output_state_switch

output_state_col_1
		rlf		output_state,f
		call	output_column_1
		pagesel	$
		goto	output_state_out
output_state_col_2
		rlf		output_state,f
		call	output_column_2
		pagesel	$
		goto	output_state_out
output_state_col_3
		rlf		output_state,f
		call	output_column_3
		pagesel	$
		goto	output_state_out
output_state_col_4
		rlf		output_state,f
		call	output_column_4
		pagesel	$
		goto	output_state_out
output_state_col_5
		clrf	output_state
		bsf		output_state,OUTPUT_STATE_COL1
		call	output_column_5
		pagesel	$
		goto	output_state_out

output_state_out

;;;;;;; Handle input lines while output is active ;;;;;;;;;;;;;;;;;;;;;;;;;

		clrf	mode_state_actions
switch_1
		;;		SWITCH 1
		movlw	switch_state_1
		movwf	FSR
		movf	input_flags,w
		andlw	SHADOW_MASK_SW1
		call	button_fsm_sample
		pagesel $
		btfss	button_fsm_result,BUTTON_DOWN
		goto	switch_2
		call	mode_state_switch_1
		pagesel	$
		iorwf	mode_state_actions,f

switch_2
		;; 		SWITCH 2
		movlw	switch_state_2
		movwf	FSR
		movf	input_flags,w
		andlw	SHADOW_MASK_SW2
		call	button_fsm_sample
		pagesel $
		btfss	button_fsm_result,BUTTON_DOWN
		goto	switch_3
		call	mode_state_switch_2
		pagesel	$
		iorwf	mode_state_actions,f

switch_3
		;; 		SWITCH 3
		movlw	switch_state_3
		movwf	FSR
		movf	input_flags,w
		andlw	SHADOW_MASK_SW3
		call	button_fsm_sample
		pagesel $
		btfss	button_fsm_result,BUTTON_DOWN
		goto	switch_handle_actions
		call	mode_state_switch_3
		pagesel	$
		iorwf	mode_state_actions,f

;;;;;;; Handle actions from mode state machine ;;;;;;;;;;;;;;;;;;;;;;;;;

switch_handle_actions
		;; Handle button events
		btfsc	mode_state_actions, MODE_ACTION_MINUTES
		call	clock_tick_minutes_manual
		pagesel $
		btfsc	mode_state_actions, MODE_ACTION_HOURS
		call	clock_tick_hours_manual
		pagesel	$
		btfsc	mode_state_actions, MODE_ACTION_BRIGHTNESS
		call	output_set_duty_cycles
		pagesel	$
		btfsc	mode_state_actions, MODE_ACTION_SECONDS
		call	output_toggle_seconds
		pagesel	$
		btfsc	mode_state_actions, MODE_ACTION_12HOUR
		call	output_toggle_12hour
		pagesel	$

;;;;;;;  100HZ tick handling ;;;:::;;;;;;;;;;;;;;;;;;;;;;
		
;;; Button state machines receive 100HZ tick events in
;;; order to implement autorepeat. So there are two places
;;; where action can be generated, either on state transition
;;; or by staying in a state for a certain amount of time.

		;;		Tick input
		call	tick_sample
		pagesel $
		iorlw	0x00
		btfsc	STATUS,Z
		goto	no_tick_update

		;;		100HZ updates
		
		;; 		switch 1
		movlw	switch_state_1
		movwf	FSR
		call	button_fsm_tick
		pagesel $
		btfsc	button_fsm_result,BUTTON_DOWN
		;;		TODO: calling clock_tick_minutes directly here seems
		;; 		wrong, since we don't consider mode state here
		call	clock_tick_minutes_manual
		pagesel $

		;; 		switch 2
		movlw	switch_state_2
		movwf	FSR
		call	button_fsm_tick
		pagesel	$
		btfsc	button_fsm_result,BUTTON_DOWN
		;;		TODO: calling clock_tick_minutes directly here seems
		;; 		wrong, since we don't consider mode state here
		call	clock_tick_hours_manual
		pagesel $

		;; 		Generate 2HZ and 1HZ from 100HZ input
		incf	clock_milli,f
		movfw	clock_milli
		xorlw	CLOCK_TICK_COUNT_2HZ
		btfsc	STATUS,Z
		bsf		output_state_conf, OUTPUT_STATE_CONF_BLINK
		movfw	clock_milli
		xorlw	CLOCK_TICK_COUNT_1HZ
		btfss	STATUS,Z
		goto	no_tick_update
		bcf		output_state_conf, OUTPUT_STATE_CONF_BLINK
		clrf	clock_milli

		;; 		1HZ receivers
		call	clock_tick_seconds
		pagesel	$
		
no_tick_update

;;;;;;; Update display shadow registers according to mode ;;;;;;;;;;;;;;;;;;;;;;;;;

		btfsc	mode_state, MODE_STATE_CLOCK
		goto	update_shadow_clock
		goto	update_shadow_settings

update_shadow_clock
		clrf	output_shadow_col_1
		clrf	output_shadow_col_2
		btfsc	output_state_conf, OUTPUT_STATE_CONF_NOSEC
		goto	update_shadow_clock_nosec
		movf	clock_sec,w
		call	get_zero_sixty
		pagesel	$
		movwf	output_shadow_col_1 	; note that output routines take care of masking the bits
		swapf	output_shadow_col_1,w	; move seconds into W with nibbles swapped
		movwf	output_shadow_col_2
		bcf		output_shadow_col_2,3
update_shadow_clock_nosec
		movf	clock_min,w
		call	get_zero_sixty
		pagesel	$
		movwf	output_shadow_col_3
		swapf	output_shadow_col_3,w
		movwf	output_shadow_col_4
		bcf		output_shadow_col_4,3
		;; 		hour
		btfsc	output_state_conf, OUTPUT_STATE_CONF_12HOUR
		goto	update_shadow_clock_12hour
		movf	clock_hour,w
		call	get_zero_sixty
		pagesel	$
		goto	output_shadow_clock_common
update_shadow_clock_12hour
		movf	clock_hour,w
		call	get_zero_twelve
		pagesel $
		;; 		fall through
output_shadow_clock_common
		movwf	output_shadow_col_5
		btfsc	output_shadow_col_5,4
		bsf		output_shadow_col_2,3
		btfsc	output_shadow_col_5,5
		bsf		output_shadow_col_4,3
		goto	mainloop

update_shadow_settings
		;; 		brightness
		clrf	output_shadow_col_1
		clrf	reg_a
		incf	output_state_wait_duty,w
		movwf	reg_a
update_shadow_settings_brightness_loop
		bsf		STATUS,C
		rlf		output_shadow_col_1,f
		decfsz	reg_a,f
		goto	update_shadow_settings_brightness_loop
		;;		nosec
		clrf	output_shadow_col_2
		bsf		output_shadow_col_2,0
		bcf		STATUS,C
		btfsc	output_state_conf, OUTPUT_STATE_CONF_NOSEC
		rlf		output_shadow_col_2,f
		;; 		12 hour
		clrf	output_shadow_col_3
		bsf		output_shadow_col_3,0
		bcf		STATUS,C
		btfsc	output_state_conf, OUTPUT_STATE_CONF_12HOUR
		rlf		output_shadow_col_3,f
		;; 		60 HZ
		clrf	output_shadow_col_4
		clrf	output_shadow_col_5

		;; 		blink active setting	
		btfss	output_state_conf, OUTPUT_STATE_CONF_BLINK
		goto	mainloop
		btfsc	mode_state, MODE_STATE_BRIGHTNESS
		clrf	output_shadow_col_1
		btfsc	mode_state, MODE_STATE_SECONDS
		clrf	output_shadow_col_2
		btfsc	mode_state, MODE_STATE_12HOUR
		clrf	output_shadow_col_3

		goto	mainloop

        END               
