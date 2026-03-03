/* link.ld */
ENTRY(_start)

MEMORY
{
  IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 64K
  DMEM (rwx) : ORIGIN = 0x00010000, LENGTH = 64K
}

SECTIONS
{
  . = ORIGIN(IMEM);

  .text : {
    KEEP(*(.text.start))    /* _start at address 0 */
    *(.text*)
    *(.rodata*)
  } > IMEM

  .data : {
    *(.data*)
  } > DMEM

  .bss : {
    *(.bss*)
    *(COMMON)
  } > DMEM

  /* Define stack top at end of DMEM */
  _stack_top = ORIGIN(DMEM) + LENGTH(DMEM);
}
