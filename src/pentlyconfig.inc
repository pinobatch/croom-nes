; Configuration settings for Pently

; Master switch for build supporting only sound effects
PENTLY_USE_MUSIC = 1

; Music engine features that not all projects will need
; Disable to save ROM and RAM space
PENTLY_USE_VIBRATO = 0
PENTLY_USE_PORTAMENTO = 0
PENTLY_USE_303_PORTAMENTO = 0

PENTLY_USE_ARPEGGIO = 0
PENTLY_USE_ATTACK_PHASE = 0
PENTLY_USE_ATTACK_TRACK = 0

PENTLY_USE_CHANNEL_VOLUME = 0
PENTLY_USE_VARMIX = 0

; Features that affect policy more than ROM space, such as
; sound effect interruption
PENTLY_USE_SQUARE_POOLING = 1
PENTLY_USE_MUSIC_IF_LOUDER = 1
PENTLY_USE_PAL_ADJUST = 0
PENTLY_USE_TRIANGLE_DUTY_FIX = 1

; Utilities used when syncing animation to the audio.
; Disable to save ROM and RAM space
PENTLY_USE_BPMMATH = 0
PENTLY_USE_ROW_CALLBACK = 0
PENTLY_USE_VIS = 0
PENTLY_USE_REHEARSAL = 0

; Ensure more even tempo by rounding to the nearest beat
; after certain musical events
; Nonzero to round at loop point
PENTLY_USE_TEMPO_ROUNDING_SEGNO = 0
; Negative to disable, or 0, 4, 8, 12, 16 to round when a pattern is
; started on pulse 1, pulse 2, triangle, noise, or dpcm
PENTLY_USE_TEMPO_ROUNDING_PLAY_CH = -1
; Nonzero to round at each beat
PENTLY_USE_TEMPO_ROUNDING_BEAT = 0

; Should sound effects be selectable in the NSF?
PENTLY_USE_NSF_SOUND_FX = 1

; Write track titles and other metadata?
PENTLY_USE_NSF2 = 1

; 0-127; higher means quieter tri/noise
PENTLY_INITIAL_4011 = 32

; Five bytes of scratch space on zero page that need not be preserved
; across calls.  This needs to be either an = or an .importzp

pently_zptemp = $0000
; .importzp pently_zptemp

.define PENTLY_CODE "PENTLYCODE"
.define PENTLY_RODATA "PENTLYDATA"
