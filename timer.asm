; ISR_example.asm: a) Increments/decrements a BCD variable every half second using
; an ISR for timer 2; b) Generates a 2kHz square wave at pin P1.7 using
; an ISR for timer 0; and c) in the 'main' loop it displays the variable
; incremented/decremented using the ISR for timer 2 on the LCD. Also resets it to
; zero if the 'CLEAR' push button connected to P1.5 is pressed.
$NOLIST
$MODN76E003
$LIST
; N76E003 pinout:
; -------
; PWM2/IC6/T0/AIN4/P0.5 -|1 20|- P0.4/AIN5/STADC/PWM3/IC3
; TXD/AIN3/P0.6 -|2 19|- P0.3/PWM5/IC5/AIN6
; RXD/AIN2/P0.7 -|3 18|- P0.2/ICPCK/OCDCK/RXD_1/[SCL]
; RST/P2.0 -|4 17|- P0.1/PWM4/IC4/MISO
; INT0/OSCIN/AIN1/P3.0 -|5 16|- P0.0/PWM3/IC3/MOSI/T1
; INT1/AIN0/P1.7 -|6 15|- P1.0/PWM2/IC2/SPCLK
; GND -|7 14|- P1.1/PWM1/IC1/AIN7/CLO
;[SDA]/TXD_1/ICPDA/OCDDA/P1.6 -|8 13|- P1.2/PWM0/IC0
; VDD -|9 12|- P1.3/SCL/[STADC]
; PWM5/IC7/SS/P1.5 -|10 11|- P1.4/SDA/FB/PWM1
; -------
;
CLK EQU 16600000 ; Microcontroller system frequency in Hz
TIMER0_RATE EQU 4096 ; 2048Hz squarewave (peak amplitude of CEM-1203 speaker)
TIMER0_RELOAD EQU ((65536-(CLK/TIMER0_RATE)))
TIMER2_RATE EQU 1000 ; 1000Hz, for a timer tick of 1ms
TIMER2_RELOAD EQU ((65536-(CLK/TIMER2_RATE)))
NOTE_C5 EQU (65536 - (CLK/(523*2))); Do 
NOTE_D5 EQU (65536 - (CLK/(587*2))); Re
NOTE_E5 EQU (65536 - (CLK/(659*2))); Mi
NOTE_F5 EQU (65536 - (CLK/(698*2))) ; Fa
NOTE_G5 EQU (65536 - (CLK/(784*2))); So
HOUR_BUTTON equ P1.5
SET_TIME_MODE equ P1.6
SOUND_OUT equ P1.7
MINUTE_BUTTON equ P3.0
SECOND_BUTTON equ P1.2
SET_ALARM_MODE equ P1.1
PIANO_BUTTON equ P1.0
ALARM_LED equ P0.4
; Reset vector
org 0x0000
ljmp main
; External interrupt 0 vector (not used in this code)
org 0x0003
reti
; Timer/Counter 0 overflow interrupt vector
org 0x000B
ljmp Timer0_ISR
; External interrupt 1 vector (not used in this code)
org 0x0013
reti
; Timer/Counter 1 overflow interrupt vector (not used in this code)
org 0x001B
reti
; Serial port receive/transmit interrupt vector (not used in this code)
org 0x0023
reti
; Timer/Counter 2 overflow interrupt vector
org 0x002B
ljmp Timer2_ISR
; In the 8051 we can define direct access variables starting at location 0x30 up to
;location 0x7F
dseg at 0x30
Count1ms: ds 2 ; Used to determine when half second has passed
BCD_counter: ds 1
minutes_counter: ds 1
hour_counter: ds 1
AM_check: ds 1
Alarm_hour: ds 1
Alarm_minutes: ds 1
Alarm_Am_check: ds 1
Alarm_off_flag: ds 1
current_note_h: ds 1
current_note_l: ds 1

 ; The BCD counter incrememted in the ISR and displayed in the
;main loop
; In the 8051 we have variables that are 1-bit in size. We can use the setb, clr,
;jb, and jnb
; instructions with these variables. This is how you define a 1-bit variable:
bseg
half_seconds_flag: dbit 1 ; Set to one in the ISR every time 500 ms had passed
cseg
; These 'equ' must match the hardware wiring
LCD_RS equ P1.3
;LCD_RW equ PX.X ; Not used in this code, connect the pin to GND
LCD_E equ P1.4
LCD_D4 equ P0.0
LCD_D5 equ P0.1
LCD_D6 equ P0.2
LCD_D7 equ P0.3
$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$LIST
; 1234567890123456 <- This helps determine the location of the counter
Initial_Message: db 'Time:    :  :', 0
Bottom_Message: db 'Alarm:   :', 0
Piano_Message: db '-- PIANO MODE --', 0
Blank_Line: db ' ', 0
;---------------------------------;
; Routine to initialize the ISR ;
; for timer 0 ;
;---------------------------------;
Timer0_Init:
orl CKCON, #0b00001000 ; Input for timer 0 is sysclk/1
mov a, TMOD
anl a, #0xf0 ; 11110000 Clear the bits for timer 0
orl a, #0x01 ; 00000001 Configure timer 0 as 16-timer
mov TMOD, a
mov current_note_h, #high(TIMER0_RELOAD)
mov current_note_l, #low(TIMER0_RELOAD)
mov TH0, current_note_h
mov TL0, current_note_l
; Enable the timer and interrupts
setb ET0 ; Enable timer 0 interrupt
clr TR0 ; Start timer 0
ret
;---------------------------------;
; ISR for timer 0. Set to execute;
; every 1/4096Hz to generate a ;
; 2048 Hz wave at pin SOUND_OUT ;
;---------------------------------;
Timer0_ISR:
;clr TF0 ; According to the data sheet this is done for us already.
; Timer 0 doesn't have 16-bit auto-reload, so
clr TR0
mov TH0, current_note_h
mov TL0, current_note_l
setb TR0
cpl SOUND_OUT ; Connect speaker the pin assigned to 'SOUND_OUT'!
reti
;---------------------------------;
; Routine to initialize the ISR ;
; for timer 2 ;
;---------------------------------;
Timer2_Init:
mov T2CON, #0 ; Stop timer/counter. Autoreload mode.
mov TH2, #high(TIMER2_RELOAD)
mov TL2, #low(TIMER2_RELOAD)
; Set the reload value
orl T2MOD, #0x80 ; Enable timer 2 autoreload
mov RCMP2H, #high(TIMER2_RELOAD)
mov RCMP2L, #low(TIMER2_RELOAD)
; Init One millisecond interrupt counter. It is a 16-bit variable made with two 8-bit parts
clr a
mov Count1ms+0, a
mov Count1ms+1, a
; Enable the timer and interrupts
orl EIE, #0x80 ; Enable timer 2 interrupt ET2=1
setb TR2 ; Enable timer 2
ret
;---------------------------------;
; ISR for timer 2 ;
;---------------------------------;
Timer2_ISR:
clr TF2 ; Timer 2 doesn't clear TF2 automatically. Do it in the ISR. It is bit addressable.
;cpl P0.4 ; To check the interrupt rate with oscilloscope. It must be precisely a 1 ms pulse.
; The two registers used in the ISR must be saved in the stack
push acc
push psw
; Increment the 16-bit one mili second counter
inc Count1ms+0 ; Increment the low 8-bits first
mov a, Count1ms+0 ; If the low 8-bits overflow, then increment high 8-bits
jnz Inc_Done
inc Count1ms+1

Inc_Done:
; Check if half second has passed
mov a, Count1ms+0
cjne a, #low(1000), check_led_flash ; Warning: this instruction changes the carry flag!
mov a, Count1ms+1
cjne a, #high(1000), check_led_flash
; 1000 milliseconds have passed. Set a flag so the main program knows
setb half_seconds_flag ; Let the main program know half second had passed
 ; Enable/disable timer/counter 0. This line creates a beep-silence-
;beep-silence sound.
; Reset to zero the milli-seconds counter, it is a 16-bit variable
clr a
mov Count1ms+0, a
mov Count1ms+1, a
; Increment the BCD counter
mov a, BCD_counter
add a, #0x01
sjmp Timer2_ISR_da

check_led_flash:
mov a, Alarm_off_flag
cjne a, #0x01, skip_led

mov a, Count1ms+0
cjne a, #low(500), skip_led
mov a, Count1ms+1
cjne a, #high(500), skip_led

cpl ALARM_LED


skip_led:
sjmp Timer2_ISR_done

Timer2_ISR_da:
da a ; Decimal adjust instruction. Check datasheet for more details!
mov BCD_counter, a

mov a, BCD_counter
cjne a, #0x60, Timer2_ISR_done
mov BCD_counter, #0
mov a, minutes_counter
add a, #0x01
da a
mov minutes_counter, a
mov a, minutes_counter

cjne a, #0x60, Timer2_ISR_done
mov BCD_counter, #0
mov minutes_counter, #0
mov a, hour_counter
add a, #0x01
da a
mov hour_counter, a

; Check if hour reached 13, reset to 1

cjne a, #0x12, check_reset_13
lcall toggle_Am1
sjmp Timer2_ISR_done


check_reset_13:
cjne a, #0x13, Timer2_ISR_done
mov hour_counter, #0x01
sjmp Timer2_ISR_done

toggle_AM1:
push acc
mov a, AM_check
cjne a, #'A', set_A1
mov AM_check, #'P'
sjmp toggle_finish1

set_A1:
mov AM_check, #'A'
toggle_finish1:
pop acc
ret


Timer2_ISR_done:
pop psw
pop acc
reti
;---------------------------------;
; Main program. Includes hardware ;
; initialization and 'forever' ;
; loop. ;
;---------------------------------;

main:
; Initialization
mov SP, #0x7F
mov P0M1, #0x00
mov P0M2, #0x00
mov P1M1, #0x00
mov P1M2, #0x00
mov P3M2, #0x00
mov P3M2, #0x00
lcall Timer0_Init
lcall Timer2_Init
setb EA ; Enable Global interrupts
lcall LCD_4BIT
; For convenience a few handy macros are included in 'LCD_4bit.inc':
Set_Cursor(1, 1)
Send_Constant_String(#Initial_Message)
Set_Cursor(2,1)
Send_Constant_String(#Bottom_Message)
setb half_seconds_flag
mov BCD_counter, #0x00
; initialise hours and minutes: 
mov minutes_counter, #0x59
mov hour_counter, #0x11
mov AM_check, #'A'
mov Alarm_hour, #0x09
mov Alarm_minutes, #0x30

mov Alarm_AM_check, #'A'
mov Alarm_off_flag, #0x00
mov current_note_h, #high(TIMER0_RELOAD)
mov current_note_l, #low(TIMER0_RELOAD)

; After initialization the program stays in this 'forever' loop





loop:


jnb PIANO_BUTTON, check_piano_press
sjmp clock_logic

check_piano_press:
Wait_Milli_Seconds(#50)
jb PIANO_BUTTON, clock_logic
jnb PIANO_BUTTON, $
ljmp piano_start

clock_logic:
lcall Alarm_Check
mov a, Alarm_off_flag
cjne a, #0x01, check_modes
jnb SET_ALARM_MODE, silence_alarm
sjmp check_modes

silence_alarm:
lcall Alarm_off
mov Alarm_off_flag, #0x02
jnb SET_ALARM_MODE, $
sjmp loop

check_modes:
jnb SET_TIME_MODE, check_set_button
jnb SET_ALARM_MODE, check_alarm_button
ljmp loop_a


Alarm_Check:
mov a, Alarm_off_flag
cjne a, #0x02, check_normally


mov a, hour_counter
cjne a, Alarm_hour, reset_ready

mov a, minutes_counter
cjne a, Alarm_minutes, reset_ready
ret

reset_ready:
mov Alarm_off_flag, #0x00
ret

check_normally:
mov a, Alarm_off_flag
jz perform_check
ret

perform_check:

mov a, minutes_counter
cjne a, Alarm_minutes, Alarm_off_forcefully
mov a, hour_counter
cjne a, Alarm_hour, Alarm_off_forcefully

mov a, AM_check
   
cjne a, Alarm_AM_check, Alarm_off_forcefully


setb TR0
setb ALARM_LED
mov Alarm_off_flag, #0x01
ret

Alarm_off_forcefully:
lcall Alarm_off
mov Alarm_off_flag, #0x00
ret

Alarm_off:
clr TR0
clr SOUND_OUT
clr ALARM_LED
ret


check_alarm_button:
Wait_Milli_Seconds(#50)
jnb SET_ALARM_MODE, alarm_set
ljmp loop_a

check_set_button: 
Wait_Milli_Seconds(#50)
jnb SET_TIME_MODE, time_set
ljmp loop_a

alarm_set:
jnb SET_ALARM_MODE, $
Wait_Milli_Seconds(#50)

alarm_mode:
lcall update_display
lcall Alarm_off
jb SET_ALARM_MODE, check_alarm_buttons

Wait_Milli_Seconds(#50)
jb SET_ALARM_MODE, check_alarm_buttons
jnb SET_ALARM_MODE, $
Wait_Milli_Seconds(#50)
ljmp finish_alarm_wait

check_alarm_buttons:
jb HOUR_BUTTON, check_min_alarm_btn   
Wait_Milli_Seconds(#50)         
jb HOUR_BUTTON, check_min_alarm_btn   
lcall Increment_alarm_hour            
ljmp alarm_set


check_min_alarm_btn:
    
jb MINUTE_BUTTON, alarm_mode     
Wait_Milli_Seconds(#50)         
jb MINUTE_BUTTON, alarm_mode     
lcall Increment_Alarm_Minutes         
ljmp alarm_mode

time_set:
jnb SET_TIME_MODE, $
Wait_Milli_Seconds(#50)
clr TR2 



Set_mode:
lcall update_display
lcall Alarm_off
jb SET_TIME_MODE, check_buttons

Wait_Milli_Seconds(#50)
jb SET_TIME_MODE, check_buttons
jnb SET_TIME_MODE, $
Wait_Milli_Seconds(#50)
ljmp finish_setting_wait


check_buttons:
   
jb HOUR_BUTTON, check_min_btn   
Wait_Milli_Seconds(#50)         
jb HOUR_BUTTON, check_min_btn   
lcall Increment_Hour            
sjmp Set_mode
                   
check_min_btn:
    
jb MINUTE_BUTTON, check_second_button      
Wait_Milli_Seconds(#50)         
jb MINUTE_BUTTON, check_second_button      
lcall Increment_Minutes         
ljmp Set_mode

check_second_button:
jb SECOND_BUTTON, Set_mode
Wait_Milli_Seconds(#50)
jb SECOND_BUTTON, Set_mode
lcall Increment_Seconds
sjmp Set_mode


Increment_alarm_hour:
mov a, Alarm_hour
add a, #0x01
da a

cjne a, #0x12, check_alarm_reset
lcall toggle_Alarm
sjmp store_alarm_hour

check_alarm_reset:
cjne a, #0x13, store_alarm_hour
mov a, #0x01

store_alarm_hour:
mov Alarm_hour, a
jnb HOUR_BUTTON, $
Wait_Milli_Seconds(#50)
ret

Increment_Alarm_Minutes:
mov a, Alarm_minutes
add a, #0x01
da a
cjne a, #0x60, store_alarm_minutes
mov a, #0x00

store_alarm_minutes:
mov Alarm_minutes, a
jnb MINUTE_BUTTON, $            
Wait_Milli_Seconds(#50)         
ret


Increment_Hour:
mov a, hour_counter
add a, #0x01
da a

cjne a, #0x12, check_reset
lcall toggle_AM
sjmp store_hour


check_reset:
cjne a, #0x13, store_hour
mov a, #0x01



store_hour:
mov hour_counter, a
jnb HOUR_BUTTON, $              
Wait_Milli_Seconds(#50)         
ret

Increment_Minutes:
mov a, minutes_counter
add a, #0x01
da a
cjne a, #0x60, store_min
mov a, #0x00

store_min:
mov minutes_counter, a
jnb MINUTE_BUTTON, $            
Wait_Milli_Seconds(#50)         
ret

Increment_Seconds:
mov a, BCD_counter
add a, #0x01
da a
cjne a, #0x60, store_second
mov a, #0x00

store_second:
mov BCD_counter, a
jnb SECOND_BUTTON, $
Wait_Milli_Seconds(#50)
ret

toggle_AM:
push acc
mov a, AM_check
cjne a, #'A', set_A
mov AM_check, #'P'
sjmp toggle_finish

set_A:
mov AM_check, #'A'

toggle_finish:
pop acc
ret


toggle_Alarm:
push acc
mov a, Alarm_AM_check
cjne a, #'A', set_A_AL
mov Alarm_AM_check, #'P'
sjmp toggle_finish_al

set_A_Al:
mov Alarm_AM_check, #'A'
toggle_finish_al:
pop acc
ret

finish_setting_wait:
setb TR2
ljmp loop

finish_alarm_wait:
ljmp loop

loop_a:
jnb half_seconds_flag, jump_loop
lcall update_display

jump_loop:
ljmp loop

piano_start:
lcall Alarm_off
lcall LCD_4BIT
Set_Cursor(1,1)
Send_Constant_String(#Piano_Message)
Set_Cursor(2,1)
Send_Constant_String(#Blank_Line)

piano_loop:
jb SET_TIME_MODE,check_key4
mov current_note_h, #high(NOTE_C5)
mov current_note_l, #low(NOTE_C5)
setb TR0
sjmp check_exit_piano

check_key4:
jb HOUR_BUTTON, check_key3
mov current_note_h, #high(NOTE_D5)
mov current_note_l, #low(NOTE_D5)
setb TR0
sjmp check_exit_piano

check_key3:
jb MINUTE_BUTTON, check_key2
mov current_note_h, #high(NOTE_E5)
mov current_note_l, #low(NOTE_E5)
setb TR0
sjmp check_exit_piano

check_key2:
jb SECOND_BUTTON, check_key1
mov current_note_h, #high(NOTE_F5)
mov current_note_l, #low(NOTE_F5)
setb TR0
sjmp check_exit_piano

check_key1:
jb SET_ALARM_MODE, no_key
mov current_note_h, #high(NOTE_G5)
mov current_note_l, #low(NOTE_G5)
setb TR0
sjmp check_exit_piano

no_key:
clr TR0
clr SOUND_OUT

check_exit_piano:
jb PIANO_BUTTON, piano_loop
Wait_Milli_Seconds(#50)
jb PIANO_BUTTON, piano_loop

jnb PIANO_BUTTON, $
Wait_Milli_Seconds(#50)

exit_piano:
lcall Alarm_off

mov current_note_h, #high(TIMER0_RELOAD)
mov current_note_l, #low(TIMER0_RELOAD)


Set_Cursor(1,1)
Send_Constant_String(#Initial_Message)
Set_Cursor(2,1)
Send_Constant_String(#Bottom_Message)
ljmp loop

update_display:
clr half_seconds_flag ; We clear this flag in the main loop, but it is set in the ISR for timer 2
Set_Cursor(1, 14) ; the place in the LCD where we want the BCD counter value
Display_BCD(BCD_counter) ; This macro is also in 'LCD_4bit.inc'
Set_Cursor(1,11)
Display_BCD(minutes_counter)
Set_Cursor(1,8)
Display_BCD(hour_counter)
Set_Cursor(1,16)
Display_char(AM_check)
Set_Cursor(2,8)
Display_BCD(Alarm_hour)
Set_Cursor(2,11)
Display_BCD(Alarm_minutes)
Set_Cursor(2,13)
Display_char(Alarm_AM_check)
ret
END