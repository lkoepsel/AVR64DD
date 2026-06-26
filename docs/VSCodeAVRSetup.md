# AVR Assembly in VS Code (Remote-SSH to a Raspberry Pi)

This page describes how to get **AVR assembly syntax highlighting**, **C/header
IntelliSense**, and a one-keystroke **syntax check** when editing this repo in
VS Code while connected to a Raspberry Pi over **Remote-SSH**.

The example programs are GNU-assembler `.S` files: they use the C preprocessor
(`#include <avr/io.h>`, `_SFR_IO_ADDR(...)`) and GAS directives (`.section`,
`.global`). That means the correct highlighter is a **GAS-flavored** one — most
"AVR assembler" extensions target the *Atmel/Microchip AVRASM* dialect and will
mishighlight these files.

> **Why "install on the remote"?** With Remote-SSH, the editor UI runs on your
> laptop but extensions that touch files (language support, IntelliSense) must
> be installed on the **VS Code Server running on the Pi**. The Extensions view
> shows a *"Install in SSH: \<host\>"* button for exactly this reason.

## 1. Install the extensions (on the remote)

1. Open the Extensions view: `Ctrl+Shift+X`.
2. If VS Code prompts *"This workspace has extension recommendations"*, click
   **Install**. Otherwise search for and install each onto the remote:
   - **AVR Support** (`rockcat.avr-support`) — GAS-flavored AVR assembly
     highlighting for `.S` files.
   - **C/C++** (`ms-vscode.cpptools`) — IntelliSense for the `*_asm.h` headers
     and any `.c` sources.
3. Reload the window (`Ctrl+Shift+P` → *Developer: Reload Window*).

### Extension vetting (why these are safe to install)

VS Code extensions are **not sandboxed** — they run as Node.js with your full
user privileges. So both recommendations were vetted before being listed here:

- **C/C++** (`ms-vscode.cpptools`) is **first-party Microsoft** — the most
  trustworthy tier on the Marketplace. It's also the more powerful of the two
  (it runs a language server and invokes your compiler), so first-party
  provenance matters here.
- **AVR Support** (`rockcat.avr-support`) — the `.vsix` for version **0.0.2**
  (Sept 2025) was downloaded from the Marketplace and unpacked for inspection on
  **2026-06-26**. Findings:
  - Publisher is **verified**; **MIT** licensed; source repo
    `github.com/rockcat/avr_code`; package is **signed** (VS Code verifies the
    signature at install).
  - It ships **5 files, ~2 KB** of content — no `node_modules`, no minified
    blobs.
  - It is a **pure TextMate grammar** extension. `extension.js` is an 11-line
    no-op stub, and `activationEvents` is empty, so it never even activates —
    the highlighting is 100% the declarative `avrasm.tmLanguage` grammar (data
    the editor interprets, not code that runs).
  - A token scan across every file (`child_process`, `exec`, `spawn`, `http`/
    `fetch`, `net`, `fs.write`, `eval`, `crypto`, `process.env`, …) returned
    **zero hits**. No network, no filesystem, no process execution.

  **Residual risk:** it's a small project (2 ratings), and a *future* update
  could add code that this audit didn't see. VS Code auto-updates extensions by
  default. To freeze the audited build, turn off *Auto Update* for this
  extension (gear icon) or right-click → *Install Specific Version* → `0.0.2`.

  To re-vet a future version yourself, unpack and scan the `.vsix`:

  ```sh
  # Get the package URL from the gallery query API, then:
  unzip -o avr-support.vsix -d /tmp/avr-ext
  grep -rinE "child_process|exec\(|spawn|http|fetch|net\.|fs\.(write|unlink)|eval\(|crypto" /tmp/avr-ext/extension/
  # A pure grammar extension produces no hits and bundles no node_modules.
  ```

## 2. Run the syntax check

There is no live, as-you-type linter for AVR assembly — the real check is
*"does it assemble"*. The supplied build task runs your existing `make compile`
on the example directory of the file you're editing and routes any
`avr-gcc`/`as` diagnostics into the **Problems** panel and inline.

- Open any `main.S` (or a `Library/*.S`) and press **`Ctrl+Shift+B`**.
- Errors appear underlined in the editor and listed in **Problems**
  (`Ctrl+Shift+M`).

## 3. Confirm the language association

The `.S → avr` association assumes `rockcat.avr-support` registers its language
id as `avr`. After installing, open a `.S` file and check the language
indicator in the status bar (bottom-right). If it does **not** show AVR/assembly,
click it → *Configure File Association for '.S'* → pick the AVR language, and
update the id in `.vscode/settings.json` to match.

## Notes & gotchas

- **`.vscode/` is git-ignored in this repo.** The four files below are personal,
  per-machine editor config. To share them with anyone cloning the repo, force-add:
  `git add -f .vscode/`.
- **The `defines` are hand-mirrored from `env.make`.** cpptools cannot read
  `env.make`, so if you change `F_CPU`/`USB_BAUD`/`SOFT_BAUD` there, update
  `c_cpp_properties.json` to match. Run `make env` to print the live values.
- **Toolchain path.** `compilerPath` assumes `/usr/bin/avr-gcc` (verified with
  avr-gcc 14.2.0). If `which avr-gcc` differs on your machine, edit it.

---

## File contents

Create these under `.vscode/` at the repo root.

### `.vscode/extensions.json`

```jsonc
{
  // Install these in the *remote* (Raspberry Pi) when prompted by VS Code.
  "recommendations": [
    "rockcat.avr-support",   // AVR assembly (.S) syntax highlighting
    "ms-vscode.cpptools"     // C/C++ IntelliSense for headers + Problems integration
  ]
}
```

### `.vscode/settings.json`

```jsonc
{
  // Treat uppercase .S (and .inc) as AVR assembly so the highlighter kicks in.
  "files.associations": {
    "*.S": "avr",
    "*.inc": "avr"
  }
}
```

### `.vscode/tasks.json`

```jsonc
{
  "version": "2.0.0",
  "tasks": [
    {
      // Builds the example directory of the file you're editing and surfaces
      // avr-gcc/as errors inline + in the Problems panel. This is your
      // "syntax check": run with Ctrl+Shift+B.
      "label": "AVR: build current example",
      "type": "shell",
      "command": "make compile",
      "options": { "cwd": "${fileDirname}" },
      "group": { "kind": "build", "isDefault": true },
      "presentation": { "reveal": "silent", "clear": true },
      "problemMatcher": {
        "base": "$gcc",
        "fileLocation": ["relative", "${fileDirname}"]
      }
    },
    {
      "label": "AVR: flash current example",
      "type": "shell",
      "command": "make flash",
      "options": { "cwd": "${fileDirname}" },
      "group": "build",
      "problemMatcher": {
        "base": "$gcc",
        "fileLocation": ["relative", "${fileDirname}"]
      }
    }
  ]
}
```

### `.vscode/c_cpp_properties.json`

```jsonc
{
  "version": 4,
  "configurations": [
    {
      "name": "AVR64DD32",
      // Point IntelliSense at avr-gcc so it auto-discovers <avr/io.h> and the
      // arch defines (__AVR_AVR64DD32__, register addresses, etc.).
      "compilerPath": "/usr/bin/avr-gcc",
      "compilerArgs": ["-mmcu=avr64dd32"],
      "includePath": [
        "${workspaceFolder}/Library",
        "${fileDirname}"
      ],
      // Mirror the -D flags the Makefile passes (see `make env`).
      "defines": [
        "F_CPU=4000000UL",
        "USB_BAUD=250000UL",
        "SOFT_BAUD=9600UL"
      ],
      "cStandard": "c99",
      "intelliSenseMode": "linux-gcc-x64"
    }
  ]
}
```
