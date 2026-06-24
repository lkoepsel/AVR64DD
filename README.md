# Developing C and Assembly Language Code Using the AVR64DD 

Notes as to developing C and assembly code for the Microchip AVR64DD. 
![AVR64DD32_Curiosity_Nano](./AVR64DD32_Curiosity_Nano.pdf)

## AVR64DD32 Curiosity Nano — Quick Notes

A running scratchpad of board/chip gotchas worth remembering.

### TCA0 (Timer A) PWM output pins
TCA0's six waveform outputs (WO0–WO5) map to pins 0–5 of whichever port
`PORTMUX.TCAROUTEA` selects.

- **Default route is PORTA**, so WO0→PA0, WO1→PA1, WO2→PA2. But on the Nano,
  **PA0/PA1 carry the 24 MHz crystal and are disconnected from the edge
  connector by default** (to use them as GPIO: cut straps J214/J215 to free the
  crystal, then bridge solder points J207/J208). So **PA2 is the only directly
  usable default channel** — no board mods. (See `AVR64DD_examples/asm_blink_pwm`.)
- **Route TCA0 to PORTD** (`PORTMUX.TCAROUTEA`) to get **WO1/WO2/WO3 on
  PD1/PD2/PD3**, which are broken out on the header with no modifications —
  handy when you want multiple PWM channels.
- **LED0 is on PF5 = WO5**, which is reachable only via TCA0 **Split mode** +
  PORTMUX routing to PORTF (more involved than the default single-channel path).

Source: board pinout (`documentation/AVR64DD32_Curiosity_Nano.png`) and the
Curiosity Nano User Guide §4.2.4 (24 MHz crystal).

## Introduction
This repository provides example programs in [*C* (ANSI C99, AVR-LibC)](https://github.com/avrdudes/avr-libc) and [*AVR assembly language*](https://ww1.microchip.com/downloads/en/DeviceDoc/AVR-Instruction-Set-Manual-DS40002198A.pdf) for the Microchip **AVR64DD32**, targeting the [*AVR64DD32 Curiosity Nano*](./documentation/AVR64DD32CNANO-Prel-HW-UserGuide-DS50003323.pdf) evaluation board. The same examples apply to the closely related **AVR64DD28** with a one-line change in *env.make*. To use this framework you need a recent *GNU AVR* toolchain (*avr-gcc* / *avr-libc*) new enough to know the AVR-Dx parts; current packages on *Linux*, *macOS*, and *Windows* include them, so no separate device pack is required.

Example programs live under [**examples**](./AVR64DD_examples). Each subfolder is a *C*, *assembly*, or *mixed C/assembly* example. *C* and *mixed* examples use `main.c` as the principal program; *assembly* examples are named with an `asm_` prefix (e.g. `asm_blink`) and use `main.S`. A single root `Makefile` builds all three kinds — it auto-detects whether to link freestanding (*assembly*, no C runtime) or with the *C runtime*. The standard *make* targets (`make`, `make flash`, `make size`, …) work in every example folder.

The *Curiosity Nano* has an **on-board nEDBG debugger**, so you program and debug it over a single USB cable using the *UPDI* interface — **no external programmer and no bootloader are required**. The *env.make* file (copied from the *env.dev* template) selects this with `PROGRAMMER_TYPE = pkobn_updi`. For a bare **AVR64DD28** in a DIP socket you instead drive its *UPDI* pin with an [*Atmel-ICE*](https://www.microchip.com/en-us/development-tool/atatmel-ice) or [*Microchip SNAP*](https://www.microchip.com/en-us/development-tool/pg164100); *env.make* has a commented block for that.

For the best debugging experience on *Linux*, I strongly recommend [Bloom](https://bloom.oscillate.io/) together with [*avr-gdb*](https://www.sourceware.org/gdb/). Bloom acts as the GDB server to the Nano's on-board debugger, letting you load code and inspect the microcontroller's registers and memory; the repo's *bloom.yaml* is already configured for the *AVR64DD32 Curiosity Nano* over *UPDI*. On a desktop you can pair it with Bloom's graphical *Insight* inspector — see [Debugging the AVR64DD32 with Bloom and avr-gdb](#debugging-the-avr64dd32-with-bloom-and-avr-gdb) just below. For headless / SSH use (e.g. a Raspberry Pi dev host), use [**gdb-dashboard**](./docs/gdb-dashboard.md), a pure-terminal front-end.

## Debugging the AVR64DD32 with Bloom and avr-gdb

*Bloom* provides the GDB server for the *AVR64DD32 Curiosity Nano* over the
Nano's on-board *nEDBG* debugger (*UPDI*) — no external programmer. The repo's
**`bloom.yaml`** configures it and can open **Bloom Insight** (a Qt GUI) for
graphical register / peripheral / memory / GPIO inspection on a desktop. For
the actual debugging session, drive *avr-gdb*; headless setups use
[gdb-dashboard](./docs/gdb-dashboard.md) instead of Insight.

### What `bloom.yaml` does

```yaml
environments:
  default:
    shutdown_post_debug_session: false
    tool:
      name: "curiosity_nano"
    target:
      name: "avr64dd32"
      physical_interface: "updi"
      hardware_breakpoints: true
    server:
      name: "avr_gdb_rsp"
      ip_address: "127.0.0.1"
      port: 1442
```

- **`tool` / `target` / `physical_interface: updi`** — drive the on-board nEDBG
  over UPDI; no external programmer or bootloader.
- **`hardware_breakpoints: true`** — use the AVR64DD32's hardware breakpoints, so
  breakpoints work in Flash and assembly (e.g. `break *0` at the reset vector).
- **`server: avr_gdb_rsp` on `127.0.0.1:1442`** — the GDB RSP server that
  *avr-gdb* connects to.
- **`insight: activate_on_startup: true`** — **Bloom Insight**, the graphical
  front-end, opens automatically with the session, giving live register /
  peripheral / memory / GPIO views (desktop only — Insight is a Qt GUI and
  won't display over SSH; use gdb-dashboard there).
- **`shutdown_post_debug_session: false`** — Bloom keeps running after you quit
  *avr-gdb* (it returns to waiting for a connection), so you can re-launch
  *avr-gdb* without restarting Bloom. Press *Ctrl-C* in the Bloom terminal when
  you are truly done.

> **Headless / SSH (e.g. a Raspberry Pi dev host)?** Insight is a Qt GUI and
> can't display over SSH. Use [**gdb-dashboard**](./docs/gdb-dashboard.md)
> instead — a pure-terminal source / assembly / curated-register view for
> *avr-gdb*. The ready-made config is in [`docs/dashboard/`](./docs/dashboard).

### Debugging session

Start Bloom in an example directory, then launch *avr-gdb* — the
[gdb-dashboard setup](./docs/gdb-dashboard.md) auto-connects and flashes,
leaving you halted at the reset vector:

```bash
# terminal 1
cd AVR64DD_examples/asm_blink && bloom
# terminal 2
cd AVR64DD_examples/asm_blink && avr-gdb
```

See [docs/gdb-dashboard.md](./docs/gdb-dashboard.md) for the full headless
terminal workflow (curated registers, centered disassembly, `mon rr`/`mon wr`).

## Local Documentation (in the repo folder [documentation](./documentation))

### AVR64DD32 and Curiosity Nano Details
* [AVR64DD32/28 Datasheet](./documentation/AVR64DD32-28-Complete-DataSheet-DS40002315.pdf)
* [AVR Instruction Set](./documentation/AVR-InstructionSet-Manual-DS40002198.pdf)
* [AVR C Library User Manual](./documentation/avr-libc-user-manual-2.3.0.pdf)
* [Curiosity Nano pinout](./documentation/AVR64DD32_Curiosity_Nano.png)
* [Curiosity Nano DataSheet](./documentation/AVR64DD32CNANO-Prel-HW-UserGuide-DS50003323.pdf)

### Compilers, Debuggers
* [GNU gcc User Manual (C Compiler)](./documentation/gcc_15.pdf)
* [GNU gdb User Manual (Debugger)](./documentation/gdb_17.0.50.20250617-git.pdf)
* [GNU as User Manual (Assembler)](./gnu_as.pdf)

### Chip Programming
* [avrdude - AVR Downloader Uploader](./avrdude.pdf)
* [Atmel ICE User Guide](./Atmel-ICE_UserGuide.pdf)
* [Microchip SNAP User Guide](./SNAPUsersGuide.pdf)

### Tutorials
* [Beginners Introduction to the Assembly Language of AVR Microprocessors](./BeginnersIntroductiontotheAssemblyLanguageofAVRMicroprocessors)
* [AVR 14 Lectures](./AVR14Lectures.pdf)
* [AVR Assembler by example](./AVRAssemblerbyexample.pdf)
* [AVR Inline Assembly](./documentation/arduinoinlineassembly.pdf)

### Application Notes
* [Getting Started with the DD Family](./documentation/AN4875-Getting-Started-AVR-DD-Family-DS00004875.pdf)
* [Migration from megaAT](./documentation/Migration-from-megaAVR-to-AVR-DxMCU-Fam-DS00003731A.pdf)
* [Getting Started Writing C for AVR](./documentation/AVR1000b-Getting-Started-Writing-C-Code-for-AVR-DS90003262B.pdf)
* [AVR Efficient C Coding](./documentation/Atmel-AVR035-Efficient-C-Coding.pdf)
* [AVR Accessing the EEPROM](./AVR100_doc0932.pdf)

## Online Documentation

* [Microchip AVR64DD32](https://www.microchip.com/en-us/product/AVR64DD32)
* [*C* (ANSI C99) AVR-LibC](https://github.com/avrdudes/avr-libc)
* [GDB Online Manual](https://sourceware.org/gdb/current/onlinedocs/gdb.html/index.html#Top) 
* [Bloom Documentation](https://bloom.oscillate.io/docs/getting-started)
* [Bloom Target Information](https://bloom.oscillate.io/docs/target/avr64dd32)

## docs

### Table of Contents

#### [env_make.md](./docs/env_make.md)
The file env_make is used to customize the *make* process for *ATtiny* development. It is **required** in order for make to properly identify the parameters needed for compiling/linking/uploading executable code to an AVR microcontroller. **This file is not tracked by *git* and needs to be installed manually.** 

#### [vs_code.md](./docs/vs_code.md)
This page contains the files needed to be more efficient with *VS Code*. Install them in the *.vscode* folder of *ATtiny*. **They are not tracked by *git*.**

#### [git.md](./docs/git.md)
Notes on using *git*. I am neither an expert on *git* nor proficient in *git*. This page is primarily for myself, however, it has helped a few people.

#### [bloom and gdb.md](./docs/bloomandgdb.md)
Given the AVR64DD32 requires a hardware interface to load software, I recommend using *bloom* as the interface to avr-gdb. This provides loading and debugging capability, which is required to be successful. 

#### [gdb-dashboard.md](./docs/gdb-dashboard.md)
Headless terminal debugging for the AVR64DD32 with *gdb-dashboard* + *Bloom* — the SSH/Raspberry-Pi alternative to Bloom Insight. Curated AVR register view, centered disassembly, auto-connect. Config files in [`docs/dashboard/`](./docs/dashboard).

## Steps to Use
1. Install the AVR toolchain which consists of *avr-gcc*, *avr-gdb*, and *avrdude* as well as *make* and *git*. A **great** method is to use a [Raspberry Pi as your development platform.](./docs/RPi_build.md). If you wish to use *Windows* or *macOS*, some instruction is provided [here](https://www.wellys.com/posts/avr_c_setup/).
2. Clone this repository.
3. Open the *AVR64DD* folder and add an *env.make* file (*see below*) based on your programming board and system.
4. Navigate to *examples/blink* in your CLI and run:
	* *make* to compile, link and create an executable file
	* *make flash* to upload executable file to your board.
5. Look at the other examples to better understand how to use the code.

## Programming Summary
For this development, I used the *Microchip AVR64DD32 Curiosity Nano* along with *bloom* and *avr-gdb*. This combination, replaces the bootloader, provides significant debugging resources and is inexpensive ([*Microchip Curiosity Nano is $10*](https://www.microchipdirect.com/dev-tools/EV72Y42A?exact=true&allDevTools=true)).

## *avrdude* commands

#### simple *avrdude* terminal command to test connection on Curiosity Nano
```bash
avrdude -p 64dd32 -P usb -c pkobn_updi -t
```

* *?* for help
* *part* for confirming chip
* *parms* for showing target voltage
* *q* to quit

## Make Commands (requires ISP interface)

* **complete**: Cleans out all .o files and recompiles
* **size**: Shows the size of program and memory
* **flash**: Uploads program to *AVR64DD32*


## Helpful Files

### tasks.json for VS Code

```json
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "make",
            "detail": "Run make",
            "type": "shell",
            "command": "/usr/bin/make ${input:makeTarget}",
            "options": {
                "cwd": "${fileDirname}"
            },
            "presentation": {
                "reveal": "silent",
                "panel": "shared",
                "showReuseMessage": false,
                "clear": true

              },        
            "group": {
                "kind": "build",
                "isDefault": true
            }
        }
    ],
    "inputs": [
        {
            "type": "pickString",
            "id": "makeTarget",
            "description": "Select a make target",
            "options": [
                {   
                    "value": "flash",
                    "label": "compile and upload code (upload)"
                },
                {   
                    "value": "compile",
                    "label": "only compile code (verify)"
                },
                {   
                    "value": "clean",
                    "label": "remove non-source files"
                },
                {   
                    "value": "complete",
                    "label": "complete re-compile without upload"
                },
                {   
                    "value": "verbose",
                    "label": "verbose upload to debug serial connection"
                },
                {   
                    "value": "env",
                    "label": "print env variables being used"
                },
                {   
                    "value": "size",
                    "label": "print code sizes"
                },
                {   
                    "value": "help",
                    "label": "print make commands"
                }
            ],
            "default": " flash"
        }
    ]
}
```

## Using Bloom and avr-gdb
[Bloom and AVR64DD32](https://bloom.oscillate.io/docs/target/avr64dd32)

### .gdbinit - place in home folder

```
set confirm off
set pagination off
set history save on
set history size 10000
set history filename ~/.gdb_history

file main.elf
target remote :1442
load
set listsize 0
set tui compact-source on
tui focus cmd

define cll
make
load
l
end

define mrc
mon reset
continue
end

define td
tui disable
end

define te
tui enable
end
```

## bloom.yaml - place in home folder
```yaml
environments:
  default:
    shutdown_post_debug_session: true
    tool:
      name: "curiosity_nano"
    target:
      name: "avr64dd32"
      physical_interface: "updi"
      hardware_breakpoints: true
    server:
      name: "avr_gdb_rsp"
      ip_address: "127.0.0.1"
      port: 1442
    insight:
      activate_on_startup: true
```

### Steps

1. Copy *.gdbinit* in your home folder
2. Copy *bloom.yaml* file in your project folder root
3. Open two windows in your **CLI**
1. In first window:
```bash
cd ATtiny
bloom snap_13a
# bloom will initialize then wait for gdb server
```
2. In second window (remain in this window):
```
cd ATtiny/examples/blink
make complete
avr-gdb main.elf
```

### Typical gdb commands

Assuming you have setup ~/.gdbinit from above, once gdb has started, there will be two windows:
1. Top window is your main.c or main.S listing
2. Bottom window is the command window with the (gdb) prompt

At this point, the program has been loaded into the *AVR64DD32* and it is ready to run:

* `c` to run
* *Ctrl-c* to stop
* `mon reset` to reset PC to *0x0000*
* or shortcut `mrc` to reset PC and run
* `br lineno` to set a *breakpoint* on a line number
* `display variablename` to see a variable valuable every *breakpoint*
* `set variablename=n` to change a value of the *variablename*

* to use register commands below, turn off *tui* using `td`
* `mon lr` to list ALL registers
* `mon rr portb` to show contents of *PORTB*, *DDRB* and *PINB*
* `mon wr portb portb 07` to set lowest 3 bits to 1

* Edit your program and save it
* `cll` to compile, link and load the program


#### bloom and using register commands

*avr-gdb 16* has a bug when using the *TUI* and terminal color commands. It has been fixed in version 17. If required, use *td* to *disable the TUI* and *te* to *enable the TUI*. While the commands below have had the *TUI* disabled, this is no longer neccesary when using avr-gdb version 17.0+.

#### Example: Setting Pins
```bash
(gdb) mon wr portb portb 0
Writing value 0x00 (8-bit) to "PORTB" register, at address 0x00000038, via `data` address space...
Register written
(gdb) mon lr portb
---------- "PORTB" (`portb`) peripheral registers ----------

`portb`, `pinb`, "PINB", 0x00000036, 8-bit, "Input Pins, Port B"
`portb`, `ddrb`, "DDRB", 0x00000037, 8-bit, "Data Direction Register, Port B"
`portb`, `portb`, "PORTB", 0x00000038, 8-bit, "Data Register, Port B"

(gdb) mon rr portb
Reading "PORTB" peripheral registers...

`portb`, `pinb`, "PINB", 0x00000036, 8-bit | 0x20 (32, 0b00100000)
`portb`, `ddrb`, "DDRB", 0x00000037, 8-bit | 0x07 (7, 0b00000111)
`portb`, `portb`, "PORTB", 0x00000038, 8-bit | 0x00 (0, 0b00000000)

(gdb) mon wr portb portb 07
Writing value 0x07 (8-bit) to "PORTB" register, at address 0x00000038, via `data` address space...
Register written
```

#### Example: Setting PWM frequency
```bash
(gdb) mon lr tc0
---------- "TC0" (`tc0`) peripheral registers ----------

`tc0`, `gtccr`, "GTCCR", 0x00000048, 8-bit, "General Timer Conuter Register"
`tc0`, `ocr0b`, "OCR0B", 0x00000049, 8-bit, "Timer/Counter0 Output Compare Register"
`tc0`, `tccr0a`, "TCCR0A", 0x0000004F, 8-bit, "Timer/Counter Control Register A"
`tc0`, `tcnt0`, "TCNT0", 0x00000052, 8-bit, "Timer/Counter0"
`tc0`, `tccr0b`, "TCCR0B", 0x00000053, 8-bit, "Timer/Counter Control Register B"
`tc0`, `ocr0a`, "OCR0A", 0x00000056, 8-bit, "Timer/Counter0 Output Compare Register"
`tc0`, `tifr0`, "TIFR0", 0x00000058, 8-bit, "Timer/Counter0 Interrupt Flag register"
`tc0`, `timsk0`, "TIMSK0", 0x00000059, 8-bit, "Timer/Counter0 Interrupt Mask Register"

(gdb) mon wr tc0 ocr0a 90
Writing value 0x90 (8-bit) to "OCR0A" register, at address 0x00000056, via `data` address space...
Register written
```

## avr-gdb commands

### Basic Control Commands
- ```continue``` or ```c``` - Continue execution after a breakpoint
- ```step``` or ```s``` - Execute one line of code, stepping into functions
- ```next``` or ```n``` - Execute one line of code, stepping over functions
- ```finish``` - Run until current function returns

### Breakpoint Commands
- ```break main``` or ```b main``` - Set breakpoint at function main
- ```break 25``` - Set breakpoint at line 25 of current file
- ```break file.c:30``` - Set breakpoint at line 30 of file.c
- ```info breakpoints``` or ```i b``` - List all breakpoints
- ```delete 1``` - Delete breakpoint number 1
- ```disable 2``` - Temporarily disable breakpoint 2
- ```enable 2``` - Re-enable breakpoint 2

### Variable Inspection
- ```print variable``` or ```p variable``` - Print value of variable
- ```print/x variable``` - Print in hexadecimal format
- ```print/t variable``` - Print in binary format
- ```display variable``` - Automatically show variable value at each stop
- ```undisplay 1``` - Remove automatic display number 1
- ```info locals``` - Show all local variables
- ```info registers``` - Display all register values

### Watchpoint Commands
- ```watch variable``` - Break when variable value changes
- ```watch *0x20``` - Watch memory address 0x20
- ```rwatch variable``` - Break on read access to variable
- ```awatch variable``` - Break on any access (read or write)
- ```info watchpoints``` - List all watchpoints

### Stack and Memory Commands
- ```backtrace``` or ```bt``` - Show call stack
- ```frame 2``` - Select stack frame 2
- ```up``` - Move up one stack frame
- ```down``` - Move down one stack frame
- ```x/10xb 0x60``` - Examine 10 bytes in hex starting at 0x60
- ```x/5i $pc``` - Display 5 instructions starting at program counter

### Program Flow
- ```list``` or ```l``` - Show source code around current line
- ```list 20,30``` - Show lines 20-30
- ```disassemble``` - Show assembly of current function
- ```stepi``` or ```si``` - Execute one machine instruction
- ```nexti``` or ```ni``` - Execute one instruction (skip calls)

### Miscellaneous
- ```set var variable = 5``` - Change variable value to 5
- ```info functions``` - List all functions
- ```help command``` - Get help for specific command
- ```quit``` or ```q``` - Exit gdb

## tio setup

For the AVR64DD32 using hexadecimal data, use `tio cnh`, to see ASCII data, use `tio cna`

```
# default is for AVR_C Uno-type boards
[default]
baudrate = 250000
databits = 8
parity = none
stopbits = 1
local-echo = false
color = 11

[acm]
device = /dev/ttyACM0
color = 12

[usb]
device = /dev/ttyUSB0
color = 15

[usb-devices]
pattern = ^usb([0-9]*)
device = /dev/ttyUSB%m1
color = 14

# AVR64DD32 boards/circuits, hex output
[cnh]
device = /dev/ttyACM0
output-mode = hex
baudrate = 9600

# AVR64DD32 boards/circuits, ascii output
[cna]
device = /dev/ttyACM0
baudrate = 9600
```

## Sublime Text Requirements

### .clangd (macOS version)

```
# clangd configuration for the AVR / AVR64DD32 C examples (examples/*/main.c).
# macOS version
# clangd uses avr-gcc as the reference compiler to discover the AVR system
# headers automatically (no version-pinned paths to maintain). This requires
# clangd to be launched with --query-driver permitting avr-gcc 
CompileFlags:
  Compiler: /opt/homebrew/bin/avr-gcc
  Add:
    # Force C language. Without this, clangd treats standalone .h files
    # as Objective-C (its default guess for headers), then rejects
    # `-std=gnu99` with "invalid argument not allowed with ObjectiveC".
    - -xc
    - --target=avr
    - -mmcu=avr64dd32
    - -D__AVR_AVR64DD32__
    - -std=gnu99
    - -DF_CPU=4000000UL
    # Absolute path: clangd resolves relative -I entries against the source
    # file's directory, not against .clangd's directory, so a relative path
    # would only work for files at the repo root.
    - -I/Users/lkoepsel/Development/ATtiny/Library
    # AVR system headers (avr/io.h, avr/pgmspace.h, etc.). Listed explicitly
    # because --query-driver isn't reliable with Apple's clangd; this path is
    # version-pinned and will need updating after `brew upgrade avr-gcc@9`.
    - -isystem
    - /opt/homebrew/Cellar/avr-gcc@9/9.5.0/avr/include
 

# clangd's Include Cleaner flags #include lines it judges "unused" — it
# misfires on embedded headers included for side effects (e.g. <stdio.h>).
Diagnostics:
  UnusedIncludes: None
  MissingIncludes: None
```

### LSP-clangd settings (*both macOS and Linux*)

`Settings -> Package Settings -> LSP -> Servers -> LSP-clangd`

```
{
    // Whitelist avr-gcc so clangd can query it for system header paths.
    // Without this, the project's .clangd "Compiler: /usr/bin/avr-gcc"
    // line is silently ignored and <avr/io.h> can't be found.
      "command": [
          "${server_path}",
          "--background-index",
          "--header-insertion=never"
      ]
}
```
### Notes

1. LSP-clangd --query-driver: Sublime's LSP-clangd needs to be allowed to query avr-gcc. In LSP-clangd settings, add to
the clangd args:
"--query-driver=/opt/homebrew/bin/avr-gcc"
1. Without this, clangd ignores Compiler: for security reasons and falls back to its built-in clang paths — which don't know about AVR.
2. Homebrew cellar path is version-pinned. When avr-gcc@9 updates from 9.5.0, that explicit -I breaks. Prefer letting Compiler: /opt/homebrew/bin/avr-gcc + --query-driver find it automatically, and drop the -I/usr/avr/include line.


### .clangd (Linux version)

```
# clangd configuration for the AVR / AVR64DD32 C examples (examples/*/main.c).
# Linux version
# clangd uses avr-gcc as the reference compiler to discover the AVR system
# headers automatically (no version-pinned paths to maintain). This requires
# clangd to be launched with --query-driver permitting avr-gcc 
CompileFlags:
  Compiler: /usr/bin/avr-gcc
  Add:
    # Force C language. Without this, clangd treats standalone .h files
    # as Objective-C (its default guess for headers), then rejects
    # `-std=gnu99` with "invalid argument not allowed with ObjectiveC".
    - -xc
    - --target=avr
    - -mmcu=avr64dd32
    - -D__AVR_AVR64DD32__
    - -std=gnu99
    - -DF_CPU=1200000UL
    # Absolute path: clangd resolves relative -I entries against the source
    # file's directory, not against .clangd's directory, so a relative path
    # would only work for files at the repo root.
    - -I/home/lkoepsel/Documents/ATtiny/Library
    - -I/user/avr/include
 

# clangd's Include Cleaner flags #include lines it judges "unused" — it
# misfires on embedded headers included for side effects (e.g. <stdio.h>).
Diagnostics:
  UnusedIncludes: None
  MissingIncludes: None
```
