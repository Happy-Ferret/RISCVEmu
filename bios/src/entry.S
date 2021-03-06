.macro store_registers
	sw x1, 4(sp)
	sw x3, 12(sp)
	sw x4, 16(sp)
	sw x5, 20(sp)
	sw x6, 24(sp)
	sw x7, 28(sp)
	sw x8, 32(sp)
	sw x9, 36(sp)
	sw x10, 40(sp)
	sw x11, 44(sp)
	sw x12, 48(sp)
	sw x13, 52(sp)
	sw x14, 56(sp)
	sw x15, 60(sp)
	sw x16, 64(sp)
	sw x17, 68(sp)
	sw x18, 72(sp)
	sw x19, 76(sp)
	sw x20, 80(sp)
	sw x21, 84(sp)
	sw x22, 88(sp)
	sw x23, 92(sp)
	sw x24, 96(sp)
	sw x25, 100(sp)
	sw x26, 104(sp)
	sw x27, 108(sp)
	sw x28, 112(sp)
	sw x29, 116(sp)
	sw x30, 120(sp)
	sw x31, 124(sp)
.endm

.macro restore_registers
	lw x1, 4(sp)
	lw x3, 12(sp)
	lw x4, 16(sp)
	lw x5, 20(sp)
	lw x6, 24(sp)
	lw x7, 28(sp)
	lw x8, 32(sp)
	lw x9, 36(sp)
	lw x10, 40(sp)
	lw x11, 44(sp)
	lw x12, 48(sp)
	lw x13, 52(sp)
	lw x14, 56(sp)
	lw x15, 60(sp)
	lw x16, 64(sp)
	lw x17, 68(sp)
	lw x18, 72(sp)
	lw x19, 76(sp)
	lw x20, 80(sp)
	lw x21, 84(sp)
	lw x22, 88(sp)
	lw x23, 92(sp)
	lw x24, 96(sp)
	lw x25, 100(sp)
	lw x26, 104(sp)
	lw x27, 108(sp)
	lw x28, 112(sp)
	lw x29, 116(sp)
	lw x30, 120(sp)
	lw x31, 124(sp)
.endm

	.section .text.init,"ax",@progbits
	.globl _start
_start:
	j reset

trap_vector:
	j trap

reset:
	# initialize all registers
	li ra, 0;            # return address
	la sp, __stack_top;  # stack
	li gp, 0;            # global pointer (unused)
	li tp, 0;
	li t0, 0;
	li t1, 0;
	li t2, 0;
	li s0, 0;
	li s1, 0;
	li a0, 0;
	li a1, 0;
	li a2, 0;
	li a3, 0;
	li a4, 0;
	li a5, 0;
	li a6, 0;
	li a7, 0;
	li s2, 0;
	li s3, 0;
	li s4, 0;
	li s5, 0;
	li s6, 0;
	li s7, 0;
	li s8, 0;
	li s9, 0;
	li s10, 0;
	li s11, 0;
	li t3, 0;
	li t4, 0;
	li t5, 0;
	li t6, 0;

	# initialize CSRs
	la t0, trap;
	csrw mtvec, t0;
	li t0, 0x00001800;
	csrw mstatus, t0; # MPP = 3, MPRV = 0, all interrupts disabled
	csrw mideleg, x0;
	csrw medeleg, x0;
	csrw mie, x0;
	csrw mscratch, x0;

	# copy initial values of initialized data from ROM to RAM
	la a0, __data_start;
	la a1, __data_load_start;
	la a2, __data_size;
	jal kmemcpy;

	# zero-initialize .bss
	la a0, __bss_start;
	li a1, 0;
	la a2, __bss_size;
	jal kmemset;

	# continue initialization in C
	j _init;

# TODO: There's definitely something wrong with the code below and how frames are handled
# in case of U->M traps and M->M traps but I'm too tired to figure it out atm :(
# Both versions (trap and trap_from_machine_mode) do almost the same things but there's no
# space left to keep extra flags in order to merge the 2 versions.
trap:
	csrrw sp, mscratch, sp;
	beqz sp, trap_from_machine_mode;

	addi sp, sp, -128;   # allocate stack memory for 32 registers
	store_registers;     # save all registers (except x0 and sp)

	# store caller's sp at slot #2
	csrr t0, mscratch;
	sw t0, 8(sp);

	# call trapHandler(cause, epc, regs)
	csrr a0, mcause;
	csrr a1, mepc;
	mv a2, sp;
	jal trapHandler;
	csrw mepc, a0;       # trapHandler's retval is the new PC

	restore_registers;   # restore all registers (except x0 and sp)
	addi sp, sp, 128;    # free allocated stack memory
	csrrw sp, mscratch, sp; # restore caller's sp
	mret                 # return to the code which caused the trap

trap_from_machine_mode:
	csrr sp, mscratch;   # restore M-mode stack pointer

	addi sp, sp, -128;   # allocate stack memory for 32 registers
	store_registers;     # save all registers (except x0 and sp)

	# store caller's sp at slot #2
	csrr t0, mscratch;
	sw t0, 8(sp);

	csrw mscratch, x0;   # Reset mscratch to be able to handle traps from traps.

	# call trapHandler(cause, epc, regs)
	csrr a0, mcause;
	csrr a1, mepc;
	mv a2, sp;
	jal trapHandler;
	csrw mepc, a0;       # trapHandler's retval is the new PC

	restore_registers;   # restore all registers (except x0 and sp)
	addi sp, sp, 128;    # free allocated stack memory
	lw sp, -120(sp);     # restore caller's sp
	mret                 # return to the code which caused the trap

# _switchToUMode(pageTable, entryPoint, stackPtr, frame);
	.globl _switchToUMode
_switchToUMode:
	# store all registers into the array pointed by a3 (frame arg)
	sw x1, 4(a3)
	sw x2, 8(a3)
	sw x3, 12(a3)
	sw x4, 16(a3)
	sw x5, 20(a3)
	sw x6, 24(a3)
	sw x7, 28(a3)
	sw x8, 32(a3)
	sw x9, 36(a3)
	sw x10, 40(a3)
	sw x11, 44(a3)
	sw x12, 48(a3)
	sw x13, 52(a3)
	sw x14, 56(a3)
	sw x15, 60(a3)
	sw x16, 64(a3)
	sw x17, 68(a3)
	sw x18, 72(a3)
	sw x19, 76(a3)
	sw x20, 80(a3)
	sw x21, 84(a3)
	sw x22, 88(a3)
	sw x23, 92(a3)
	sw x24, 96(a3)
	sw x25, 100(a3)
	sw x26, 104(a3)
	sw x27, 108(a3)
	sw x28, 112(a3)
	sw x29, 116(a3)
	sw x30, 120(a3)
	sw x31, 124(a3)

	# In order to transition to U-mode we have to:
	# 1. Store current M-mode stack pointer in mscratch (used by the trap handler)
	csrw mscratch, sp;

	# 2. Set the new stack pointer.
	mv sp, a2;
	
	# 3. Set satp CSR to point to the page table for this process.
	srli a0, a0, 12; # page table ptr to page table number
	li t0, 0x80000000; # satp MODE bit = 1 (== enable virtual to physical translation)
	or a0, a0, t0;
	csrw 0x180, a0;

	sfence.vma;

	# 4. Set MPP bits in mstatus CSR to 0 (U-mode)
	li t0, 0x00001800;
	csrc mstatus, t0;

	# 5. Set mepc CSR to the entry point of the loaded executable.
	csrw mepc, a1;

	# 6. Execute mret, which will "return" to previous mode (MPP in mstatus) at address mepc.
	mret

# _switchToMMode(frame)
	.globl _switchToMMode
_switchToMMode:
	# restore all registers from the array pointed by a0 (frame arg)
	lw x1, 4(a0)
	lw x2, 8(a0)
	lw x3, 12(a0)
	lw x4, 16(a0)
	lw x5, 20(a0)
	lw x6, 24(a0)
	lw x7, 28(a0)
	lw x8, 32(a0)
	lw x9, 36(a0)
#	lw x10, 40(a0) # Don't restore a0 just yet
	lw x11, 44(a0)
	lw x12, 48(a0)
	lw x13, 52(a0)
	lw x14, 56(a0)
	lw x15, 60(a0)
	lw x16, 64(a0)
	lw x17, 68(a0)
	lw x18, 72(a0)
	lw x19, 76(a0)
	lw x20, 80(a0)
	lw x21, 84(a0)
	lw x22, 88(a0)
	lw x23, 92(a0)
	lw x24, 96(a0)
	lw x25, 100(a0)
	lw x26, 104(a0)
	lw x27, 108(a0)
	lw x28, 112(a0)
	lw x29, 116(a0)
	lw x30, 120(a0)
	lw x31, 124(a0)
	lw x10, 40(a0)

	csrw 0x180, x0;       # clear satp.

	li t0, 0x00001800; 
	csrs mstatus, t0;     # set MPP in mstatus to 3 (M-mode)

	ret;                  # regular ret will do because ra is set to the correct address.
