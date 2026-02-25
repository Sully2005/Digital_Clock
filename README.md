# 8051 Digital Piano Alarm Clock

A hardware-software integration project using the **8051 Microcontroller** to create a multi-functional digital clock with real-time piano synthesis.

## Technical Specifications
* **Microcontroller:** 8051 (Interrupt-driven timing).
* **Display:** 16x2 LCD interface for real-time clock and UI menus.
* **Audio Output:** PWM-modulated signal to a speaker for alarm and musical tones.
* **Inputs:** Tactile switches for time adjustment, alarm configuration, and "Piano Mode."
* **Visual Indicators:** LED strobe synchronized with active alarm states.

## Core Functionality
* **Timekeeping:** Managed via hardware timers and Interrupt Service Routines (ISRs) for high precision.
* **Alarm System:** User-defined alarm thresholds with a dedicated "Snooze" interrupt and flashing LED alert.
* **Piano Mode:** Frequency-mapping system converting button inputs into musical notes via variable PWM frequencies.
