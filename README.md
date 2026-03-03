# Secure RV32I Core + Shadow-Stack GCC Plugin

This **ongoing** project is a secure RISC-V RV32I processor core that i will be continously adding security features to, so far i have only implemented shadow stack protection to prevent stack smashing. The core executes all **38 unprivileged RV32I instructions**, plus **two custom shadow-stack instructions**. On the software side, a **GCC RTL plugin** automatically instruments code so function call/return behavior is protected using the custom instructions.

---

## What’s in this repo

- **RV32I 5 stage pipelined core** (supports all 38 RV32I base integer instructions)
- **2 custom instructions** for hardware shadow stack protection
- **GCC RTL plugin** (`shadowstack_rtl_plugin.so`) to automatically insert the custom instructions
- **Bare-metal startup** (`start.S`) + **linker script** (`link.ld`)
- Flow to produce:
  - `prog.elf` (linked executable)
  - `test.hex` (instruction words for instruction memory)

---

## Core execution model (RV32I + 2 custom instructions)

### RV32I (38 instructions)

The core follows standard RV32I semantics:

- **Fetch** reads the instruction at the current `PC`.
- **Decode** generates control for ALU / branch / load-store / reg writeback.
- **Execute / Mem / WB** produce architectural effects (register writes, memory reads/writes, PC redirection for branches/jumps).

Important constraints for bring-up:

- The CPU begins execution at **`PC = 0x00000000`**
- Therefore the binary must be linked such that the entry code is located at **address 0**

---

### Custom shadow-stack instructions (2)

These instructions are implemented in **hardware (not emulated)** and protect the return address (`x1` / `ra`).

#### 1) `SSPUSH_RA`

Triggered at function-call boundaries (right before/after a call depending on your convention).

Hardware behavior:

- Pushes the current return address value (`x1`) into a protected shadow-stack structure
- Updates the internal shadow-stack pointer (SSP)

#### 2) `SSPOPCHK_RA`

Triggered at function-return boundaries (right before `ret`).

Hardware behavior:

- Pops the last stored return address from the shadow stack
- Compares it with current `x1`
- If mismatch → raises a **fault** (halt / trap / redirect to fault PC depending on your core design)

**Net effect:** even if the normal stack gets corrupted and a malicious value is written into `ra`, the return will be detected because hardware checks `ra` against the protected copy.

---

## GCC RTL Plugin (automatic instrumentation)

The RTL plugin `shadowstack_rtl_plugin.so` instruments compiled code to enforce shadow-stack integrity without manually editing C code.

At a high level, the plugin:

- Detects function call sites and inserts `SSPUSH_RA`
- Detects function returns and inserts `SSPOPCHK_RA` before the `ret` path

This division of labor is the core idea:

- **Compiler** decides *where* to enforce (calls/returns)
- **Hardware** enforces *securely* (shadow memory not directly writable like normal RAM)

---

## Build / Compile Steps

### 1) Compile C file with the GCC plugin

```bash
riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 \
  -ffreestanding -fno-builtin -nostdlib -nostartfiles -O0 \
  -fno-omit-frame-pointer -fno-optimize-sibling-calls \
  -fplugin=./shadowstack_rtl_plugin.so \
  -c test.c -o test.o
```
### Why these flags matter

- **`-march=rv32i -mabi=ilp32`**  
  Ensures the compiler generates only **RV32I base ISA** instructions (no compressed `C`, no multiply/divide `M`, no extensions).  
  This guarantees compatibility with the core, which implements exactly the 38 unprivileged RV32I instructions.

- **`-ffreestanding -nostdlib -nostartfiles -fno-builtin`**  
  Prevents the compiler from assuming a hosted environment (no libc, no default crt0, no implicit runtime).  
  This is required because the system is bare-metal and provides its own `_start`.

- **`-O0 -fno-omit-frame-pointer -fno-optimize-sibling-calls`**  
  Keeps the control-flow structure predictable.  
  Prevents tail-call optimization and frame-pointer elimination, which could otherwise alter call/return patterns and interfere with shadow-stack instrumentation.

- **`-fplugin=./shadowstack_rtl_plugin.so`**  
  Enables the GCC RTL plugin, which automatically inserts the custom shadow-stack instructions at function call and return sites.

---

## 2) Compile the startup assembly

```bash
riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 \
  -ffreestanding -fno-builtin -nostdlib -nostartfiles -O0 \
  -c start.S -o start.o
```

---

## 3) Link with the linker script (places `_start` at `PC = 0`)

```bash
riscv64-unknown-elf-ld -m elf32lriscv -T link.ld \
  start.o test.o -o prog.elf
```

This ensures the entry symbol `_start` is located at address `0x00000000`, matching the core’s reset PC.

---

## 4) Extract instruction words into a `.hex` file

```bash
riscv64-unknown-elf-objdump -d -M no-aliases,numeric prog.elf \
  | awk '/^[[:space:]]*[0-9a-f]+:/ {print $2}' > test.hex
```

This produces `test.hex` containing **one 32-bit instruction word per line (in hex)**, extracted from the disassembly.

---

## Instruction Memory Format Requirement

The instruction memory is driven by a **memread-style interface**:


So `test.hex` must look like:

```
<instr_word_0>
<instr_word_1>
<instr_word_2>
...
```

Each line corresponds to a 32-bit instruction, and the instruction memory indexes them sequentially:

```
 $readmemh("test.hex", instr_ram);
```


