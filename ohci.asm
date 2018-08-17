; Code for OHCI controllers.

; Standard driver stuff
format PE DLL native
entry start
__DEBUG__ equ 1
__DEBUG_LEVEL__ equ 1
section '.reloc' data readable discardable fixups
section '.text' code readable executable
include '../proc32.inc'
include '../struct.inc'
include '../macros.inc'
include '../fdo.inc'
include '../../kernel/trunk/bus/usb/common.inc'

; =============================================================================
; ================================= Constants =================================
; =============================================================================
; OHCI register declarations
; All of the registers should be read and written as Dwords.
; Partition 1. Control and Status registers.
OhciRevisionReg         = 0
OhciControlReg          = 4
OhciCommandStatusReg    = 8
OhciInterruptStatusReg  = 0Ch
OhciInterruptEnableReg  = 10h
OhciInterruptDisableReg = 14h
; Partition 2. Memory Pointer registers.
OhciHCCAReg             = 18h
OhciPeriodCurrentEDReg  = 1Ch
OhciControlHeadEDReg    = 20h
OhciControlCurrentEDReg = 24h
OhciBulkHeadEDReg       = 28h
OhciBulkCurrentEDReg    = 2Ch
OhciDoneHeadReg         = 30h
; Partition 3. Frame Counter registers.
OhciFmIntervalReg       = 34h
OhciFmRemainingReg      = 38h
OhciFmNumberReg         = 3Ch
OhciPeriodicStartReg    = 40h
OhciLSThresholdReg      = 44h
; Partition 4. Root Hub registers.
OhciRhDescriptorAReg    = 48h
OhciRhDescriptorBReg    = 4Ch
OhciRhStatusReg         = 50h
OhciRhPortStatusReg     = 54h



OhciRevisionReg_log_prefix_read			=	0x21
OhciRevisionReg_log_prefix_write		=	0x22
OhciControlReg_log_prefix_read			=	0x23
OhciControlReg_log_prefix_write			=	0x24
OhciCommandStatusReg_log_prefix_read		=	0x25
OhciCommandStatusReg_log_prefix_write		=	0x26	; xxx
OhciInterruptStatusReg_log_prefix_read		=	0x27
OhciInterruptStatusReg_log_prefix_write		=	0x28	; xxx
OhciInterruptEnableReg_log_prefix_read		=	0x29
OhciInterruptEnableReg_log_prefix_write		=	0x2a
OhciInterruptDisableReg_log_prefix_read		=	0x2b
OhciInterruptDisableReg_log_prefix_write	=	0x2c
OhciHCCAReg_log_prefix_read			=	0x2d
OhciHCCAReg_log_prefix_write			=	0x2e
OhciPeriodCurrentEDReg_log_prefix_read		=	0x2f
OhciPeriodCurrentEDReg_log_prefix_write		=	0x30
OhciControlHeadEDReg_log_prefix_read		=	0x31
OhciControlHeadEDReg_log_prefix_write		=	0x32
OhciControlCurrentEDReg_log_prefix_read		=	0x33
OhciControlCurrentEDReg_log_prefix_write	=	0x34
OhciBulkHeadEDReg_log_prefix_read		=	0x35
OhciBulkHeadEDReg_log_prefix_write		=	0x36
OhciBulkCurrentEDReg_log_prefix_read		=	0x37
OhciBulkCurrentEDReg_log_prefix_write		=	0x38
OhciDoneHeadReg_log_prefix_read			=	0x39
OhciDoneHeadReg_log_prefix_write		=	0x3a
OhciFmIntervalReg_log_prefix_read		=	0x3b
OhciFmIntervalReg_log_prefix_write		=	0x3c
OhciFmRemainingReg_log_prefix_read		=	0x3d
OhciFmRemainingReg_log_prefix_write		=	0x3e
OhciFmNumberReg_log_prefix_read			=	0x3f
OhciFmNumberReg_log_prefix_write		=	0x40
OhciPeriodicStartReg_log_prefix_read		=	0x41
OhciPeriodicStartReg_log_prefix_write		=	0x42
OhciLSThresholdReg_log_prefix_read		=	0x43
OhciLSThresholdReg_log_prefix_write		=	0x44
OhciRhDescriptorAReg_log_prefix_read		=	0x45
OhciRhDescriptorAReg_log_prefix_write		=	0x46
OhciRhDescriptorBReg_log_prefix_read		=	0x47
OhciRhDescriptorBReg_log_prefix_write		=	0x48
OhciRhStatusReg_log_prefix_read			=	0x49
OhciRhStatusReg_log_prefix_write		=	0x4a
OhciRhPortStatusReg_log_prefix_read		=	0x4b
OhciRhPortStatusReg_log_prefix_write		=	0x4c

TRANSFER_DESCRIPTOR_READY_LOG_PREFIX		=	0x80

INTERRUPT_ENTRY_LOG_PREFIX			=	0x81
INTERRUPT_EXIT_LOG_PREFIX			=	0x82
INTERRUPT_TRANSFER_DONE_LOG_PREFIX		=	0x83
INTERRUPT_START_OF_FRAME_LOG_PREFIX		=	0x84
INTERRUPT_ROOT_HUB_EVENT_PREFIX			=	0x85
HCCA_CONTENTS_LOG_PREFIX			=	0x86
OHCI_INIT_START_LOG_PREFIX			=	0x87
OHCI_INIT_END_LOG_PREFIX			=	0x88


; =============================================================================
; ================================ Structures =================================
; =============================================================================

; OHCI-specific part of a pipe descriptor.
; * This structure corresponds to the Endpoint Descriptor aka ED from the OHCI
;   specification.
; * The hardware requires 16-bytes alignment of the hardware part.
;   Since the allocator (usb_allocate_common) allocates memory sequentially
;   from page start (aligned on 0x1000 bytes), block size for the allocator
;   must be divisible by 16; usb1_allocate_endpoint ensures this.
struct ohci_pipe
; All addresses are physical.
Flags           dd      ?
; 1. Lower 7 bits (bits 0-6) are FunctionAddress. This is the USB address of
;    the function containing the endpoint that this ED controls.
; 2. Next 4 bits (bits 7-10) are EndpointNumber. This is the USB address of
;    the endpoint within the function.
; 3. Next 2 bits (bits 11-12) are Direction. This 2-bit field indicates the
;    direction of data flow: 1 = OUT, 2 = IN. If neither IN nor OUT is
;    specified, then the direction is determined from the PID field of the TD.
;    For CONTROL endpoints, the transfer direction is different
;    for different transfers, so the value of this field is 0
;    (3 would have the same effect) and the actual direction
;    of one transfer is encoded in the Transfer Descriptor.
; 4. Next bit (bit 13) is Speed bit. It indicates the speed of the endpoint:
;    full-speed (S = 0) or low-speed (S = 1).
; 5. Next bit (bit 14) is sKip bit. When this bit is set, the hardware
;    continues on to the next ED on the list without attempting access
;    to the TD queue or issuing any USB token for the endpoint.
;    Always cleared.
; 6. Next bit (bit 15) is Format bit. It must be 0 for Control, Bulk and
;    Interrupt endpoints and 1 for Isochronous endpoints.
; 7. Next 11 bits (bits 16-26) are MaximumPacketSize. This field indicates
;    the maximum number of bytes that can be sent to or received from the
;    endpoint in a single data packet.
TailP           dd      ?
; Physical address of the tail descriptor in the TD queue.
; The descriptor itself is not in the queue. See also HeadP.
HeadP           dd      ?
; 1. First bit (bit 0) is Halted bit. This bit is set by the hardware to
;    indicate that processing of the TD queue on the endpoint is halted.
; 2. Second bit (bit 1) is toggleCarry bit. Whenever a TD is retired, this
;    bit is written to contain the last data toggle value from the retired TD.
; 3. Next two bits (bits 2-3) are reserved and always zero.
; 4. With masked 4 lower bits, this is HeadP itself: physical address of the
;    head descriptor in the TD queue, that is, next TD to be processed for this
;    endpoint. Note that a TD must be 16-bytes aligned.
;    Empty queue is characterized by the condition HeadP == TailP.
NextED          dd      ?
; If nonzero, then this entry is a physical address of the next ED to be
; processed. See also the description before NextVirt field of the usb_pipe
; structure. Additionally to that description, the following is specific for
; the OHCI controller:
; * n=5, N=32, there are 32 "leaf" periodic lists.
; * The 1ms periodic list also serves Isochronous endpoints, which should be
;   in the end of the list.
; * There is no "next" list for Bulk and Control lists, they are processed
;   separately from others.
; * There is no "next" list for Periodic list for 1ms interval.
ends

;
; shopov - this is the endpoint descriptor (ED) data structure
;

; This structure describes the static head of every list of pipes.
; The hardware requires 16-bytes alignment of this structure.
; All instances of this structure are located sequentially in uhci_controller,
; uhci_controller is page-aligned, so it is sufficient to make this structure
; 16-bytes aligned and verify that the first instance is 16-bytes aligned
; inside uhci_controller.
struct ohci_static_ep
Flags           dd      ?
; Same as ohci_pipe.Flags.
; sKip bit is set, so the hardware ignores other fields except NextED.
                dd      ?
; Corresponds to ohci_pipe.TailP. Not used.
NextList        dd      ?
; Virtual address of the next list.
NextED          dd      ?
; Same as ohci_pipe.NextED.
SoftwarePart    rd      sizeof.usb_static_ep/4
; Software part, common for all controllers.
                dd      ?
; Padding for 16-bytes alignment.
ends

if sizeof.ohci_static_ep mod 16
.err ohci_static_ep must be 16-bytes aligned
end if

;
; shopov - this is the HCCA area data structure
;

; OHCI-specific part of controller data.
; * The structure describes the memory area used for controller data,
;   additionally to the registers of the controller.
; * The structure includes two parts, the hardware part and the software part.
; * The hardware part consists of first 256 bytes and corresponds to
;   the HCCA from OHCI specification.
; * The hardware requires 256-bytes alignment of the hardware part, so
;   the entire descriptor must be 256-bytes aligned.
;   This structure is allocated with kernel_alloc (see usb_init_controller),
;   this gives page-aligned data.
; * The controller is described by both ohci_controller and usb_controller
;   structures, for each controller there is one ohci_controller and one
;   usb_controller structure. These structures are located sequentially
;   in the memory: beginning from some page start, there is ohci_controller
;   structure - this enforces hardware alignment requirements - and then
;   usb_controller structure.
; * The code keeps pointer to usb_controller structure. The ohci_controller
;   structure is addressed as [ptr + ohci_controller.field - sizeof.ohci_controller].
struct ohci_controller
; ------------------------------ hardware fields ------------------------------
InterruptTable  rd      32
; Pointers to interrupt EDs. The hardware starts processing of periodic lists
; within the frame N from the ED pointed to by [InterruptTable+(N and 31)*4].
; See also the description of periodic lists inside ohci_pipe structure.
FrameNumber     dw      ?
; The current frame number. This field is written by hardware only.
; This field is read by ohci_process_deferred and ohci_irq to
; communicate when control/bulk processing needs to be temporarily
; stopped/restarted.
                dw      ?
; Padding. Written as zero at every update of FrameNumber.
DoneHead        dd      ?
; Physical pointer to the start of Done Queue.
; When the hardware updates this field, it sets bit 0 to one if there is
; unmasked interrupt pending.
                rb      120
; Reserved for the hardware.

;
; shopov - end of the HCCA area data structure
;

;
; shopov - this area is being referred to as the 'software (SW) area'
;

; ------------------------------ software fields ------------------------------
IntEDs          ohci_static_ep
                rb      62 * sizeof.ohci_static_ep
; Heads of 63 Periodic lists, see the description in usb_pipe.
ControlED       ohci_static_ep
; Head of Control list, see the description in usb_pipe.
BulkED          ohci_static_ep
; Head of Bulk list, see the description in usb_pipe.
MMIOBase        dd      ?
; Virtual address of memory-mapped area with OHCI registers OhciXxxReg.
PoweredUp       db      ?
; 1 in normal work, 0 during early phases of the initialization.
; This field is initialized to zero during memory allocation
; (see usb_init_controller), set to one by ohci_init when ports of the root hub
; are powered up, so connect/disconnect events can be handled.
                rb      3 ; alignment
DoneList        dd      ?
; List of descriptors which were processed by the controller and now need
; to be finalized.
DoneListEndPtr  dd      ?
; Pointer to dword which should receive a pointer to the next item in DoneList.
; If DoneList is empty, this is a pointer to DoneList itself;
; otherwise, this is a pointer to NextTD field of the last item in DoneList.
EhciCompanion   dd      ?
; Pointer to usb_controller for EHCI companion, if any, or NULL.
ends

if ohci_controller.IntEDs mod 16
.err Static endpoint descriptors must be 16-bytes aligned inside ohci_controller
end if

; OHCI general transfer descriptor.
; * The structure describes transfers to be performed on Control, Bulk or
;   Interrupt endpoints.
; * The structure includes two parts, the hardware part and the software part.
; * The hardware part consists of first 16 bytes and corresponds to
;   the General Transfer Descriptor aka general TD from OHCI specification.
; * The hardware requires 16-bytes alignment of the hardware part, so
;   the entire descriptor must be 16-bytes aligned. Since the allocator
;   (usb_allocate_common) allocates memory sequentially from page start
;   (aligned on 0x1000 bytes), block size for the allocator must be
;   divisible by 16; usb1_allocate_generic_td ensures this.
struct ohci_gtd
; ------------------------------ hardware fields ------------------------------
; All addresses in this part are physical.
Flags           dd      ?
; 1. Lower 18 bits (bits 0-17) are ignored and not modified by the hardware.
; 2. Next bit (bit 18) is bufferRounding bit. If this bit is 0, then the last
;    data packet must exactly fill the defined data buffer. If this bit is 1,
;    then the last data packet may be smaller than the defined buffer without
;    causing an error condition on the TD.
; 3. Next 2 bits (bits 19-20) are Direction field. This field indicates the
;    direction of data flow. If the Direction field in the ED is OUT or IN,
;    this field is ignored and the direction from the ED is used instead.
;    Otherwise, 0 = SETUP, 1 = OUT, 2 = IN, 3 is reserved.
; 4. Next 3 bits (bits 21-23) are DelayInterrupt field. This field contains
;    the interrupt delay count for this TD. When a TD is complete, the hardware
;    may wait up to DelayInterrupt frames before generating an interrupt.
;    If DelayInterrupt is 7 (maximum possible), then there is no interrupt
;    associated with completion of this TD.
; 5. Next 2 bits (bits 24-25) are DataToggle field. This field is used to
;    generate/compare the data PID value (DATA0 or DATA1). It is updated after
;    each successful transmission/reception of a data packet. The bit 25
;    is 0 when the data toggle value is acquired from the toggleCarry field in
;    the ED and 1 when the data toggle value is taken from the bit 24.
; 6. Next 2 bits (bits 26-27) are ErrorCount field. For each transmission
;    error, this value is incremented. If ErrorCount is 2 and another error
;    occurs, the TD is retired with error. When a transaction completes without
;    error, ErrorCount is reset to 0.
; 7. Upper 4 bits (bits 28-31) are ConditionCode field. This field contains
;    the status of the last attempted transaction, one of USB_STATUS_* values.
CurBufPtr       dd      ?
; Physical address of the next memory location that will be accessed for
; transfer to/from the endpoint. 0 means zero-length data packet or that all
; bytes have been transferred.
NextTD          dd      ?
; This field has different meanings depending on the status of the descriptor.
; When the descriptor is queued for processing, but not yet processed:
;   Physical address of the next TD for the endpoint.
; When the descriptor is processed by hardware, but not yet by software:
;   Physical address of the previous processed TD.
; When the descriptor is processed by the IRQ handler, but not yet completed:
;   Virtual pointer to the next processed TD.
BufEnd          dd      ?
; Physical address of the last byte in the buffer for this TD.
                dd      ?       ; padding to align with uhci_gtd
ends

; OHCI isochronous transfer descriptor.
; * The structure describes transfers to be performed on Isochronous endpoints.
; * The structure includes two parts, the hardware part and the software part.
; * The hardware part consists of first 32 bytes and corresponds to
;   the Isochronous Transfer Descriptor aka isochronous TD from OHCI
;   specification.
; * The hardware requires 32-bytes alignment of the hardware part, so
;   the entire descriptor must be 32-bytes aligned.
; * The isochronous endpoints are not supported yet, so only hardware part is
;   defined at the moment.
struct ohci_itd
StartingFrame   dw      ?
; This field contains the low order 16 bits of the frame number in which the
; first data packet of the Isochronous TD is to be sent.
Flags           dw      ?
; 1. Lower 5 bits (bits 0-4) are ignored and not modified by the hardware.
; 2. Next 3 bits (bits 5-7) are DelayInterrupt field.
; 3. Next 3 bits (bits 8-10) are FrameCount field. The TD describes
;    FrameCount+1 data packets.
; 4. Next bit (bit 11) is ignored and not modified by the hardware.
; 5. Upper 4 bits (bits 12-15) are ConditionCode field. This field contains
;    the completion code, one of USB_STATUS_* values, when the TD is moved to
;    the Done Queue.
BufPage0        dd      ?
; Lower 12 bits are ignored and not modified by the hardware.
; With masked 12 bits this field is the physical page containing all buffers.
NextTD          dd      ?
; Physical address of the next TD in the transfer queue.
BufEnd          dd      ?
; Physical address of the last byte in the buffer.
OffsetArray     rw      8
; Initialized by software, read by hardware: Offset for packet 0..7.
; Used to determine size and starting address of an isochronous data packet.
; Written by hardware, read by software: PacketStatusWord for packet 0..7.
; Contains completion code and, if applicable, size received for an isochronous
; data packet.
ends

; Description of OHCI-specific data and functions for
; controller-independent code.
; Implements the structure usb_hardware_func from hccommon.inc for OHCI.
iglobal
align 4
ohci_hardware_func:
        dd      USBHC_VERSION
        dd      'OHCI'
        dd      sizeof.ohci_controller
        dd      ohci_kickoff_bios
        dd      ohci_init
        dd      ohci_process_deferred
        dd      ohci_set_device_address
        dd      ohci_get_device_address
        dd      ohci_port_disable
        dd      ohci_new_port.reset
        dd      ohci_set_endpoint_packet_size
        dd      ohci_alloc_pipe
        dd      ohci_free_pipe
        dd      ohci_init_pipe
        dd      ohci_unlink_pipe
        dd      ohci_alloc_gtd
        dd      ohci_free_gtd
        dd      ohci_alloc_transfer
        dd      ohci_insert_transfer
        dd      ohci_new_device
        dd      ohci_disable_pipe
        dd      ohci_enable_pipe
ohci_name db    'OHCI',0
endg

; =============================================================================
; =================================== Code ====================================
; =============================================================================

UART1_PORT_BASE		= 0x3f8
UART1_RBR		= UART1_PORT_BASE + 0; /* byte access, receive buffer register, r/o access, DLAB bit - 0 */
UART1_THR		= UART1_PORT_BASE + 0; /* byte access, transmitter holding register, w/o access, DLAB bit - 0 */
UART1_DL		= UART1_PORT_BASE + 0; /* byte/word access, divisor latch register, r/w access, DLAB bit - 1 */
UART1_IER		= UART1_PORT_BASE + 1; /* byte access, interrupt enable register, r/w access, DLAB bit - 0 */
UART1_IIR		= UART1_PORT_BASE + 2; /* byte access, interrupt identification register, r/o access */
UART1_FCR		= UART1_PORT_BASE + 2; /* byte access, fifo control register, w/o access */
UART1_LCR		= UART1_PORT_BASE + 3; /* byte access, line control register, r/w access */
UART1_MCR		= UART1_PORT_BASE + 4; /* byte access, modem control register, r/w access */
UART1_LSR		= UART1_PORT_BASE + 5; /* byte access, line status register, r/w access */
UART1_MSR		= UART1_PORT_BASE + 6; /* byte access, modem status register, r/w access */



proc init_uart1

	;/* used this resource for serial port information:
	   ;http://www.sci.muni.cz/docs/pc/serport.txt
	 ;*/
	; /* make sure the maximum baud rate is selected */
	pusha

	;popa
	;ret


	mov	dx, UART1_LCR
	mov	al, 0x83; (/* dlab bit */ 0x80 + /* 8 bit words */ 3 + /* no parity, one stop bit */ 0)
	out	dx, al
	; /* set maximum baud rate */
	mov	dx, UART1_DL
	mov	al, 1
	out	dx, al
	; /* clear dlab bit for normal operation */
	mov	dx, UART1_LCR
	mov	al, 3; $(/* clear dlab bit */ 0x00 + /* 8 bit words */ 3 + /* no parity, one stop bit */ 0),	%al
	out	dx, al
	; /* disable all interrupts */
	mov	dx, UART1_IER
	mov	al, 0
	out	dx, al
	; /* disable irq in the modem control register */
	mov	dx, UART1_MCR
	mov	al, 0
	out	dx, al
	; /* disable fifos */
	mov	dx, UART1_FCR
	mov	al, 0
	out	dx, al

	;push	0x65
	;call	uart1_putchar

	popa

	ret
endp

proc uart1_putchar; a single parameter - byte to print
	push	edx
	push	eax
	; /* wait for transmitter holding register empty */
	mov	dx,	UART1_LSR
loop1:
	in	al, dx
	test	al, (1 shl 5)
	jz	loop1

	mov	eax, [esp + 12]
	mov	dx, UART1_THR
	out	dx, al

	pop	eax
	pop	edx
	ret	4
endp

proc uart1_dump_log_prefix
	jmp	uart1_putchar
endp

proc uart1_dump_roothub_port_access
; parameters:
; 0 - read, 1 - write
; index
; value
	pushf
	cli
	push	eax

	mov	eax,	[esp + 12]
	or	eax,	eax
	mov	eax,	0xffffff00 + OhciRhPortStatusReg_log_prefix_read
	jz	@f
	mov	eax,	0xffffff00 + OhciRhPortStatusReg_log_prefix_write

@@:	
	push	eax
	call	uart1_putchar

	mov	eax,	[esp + 16]
	push	eax
	call	uart1_putchar

	mov	eax,	[esp + 20]
	push	eax
	call	uart1_write_integer

	pop	eax
	popf
	ret	12
endp

proc uart1_write_integer; a single parameter - word to print
	
	push	eax

	mov	eax,	[esp + 8]
	;shr	eax,	8
	push	eax
	call	uart1_putchar

	mov	eax,	[esp + 8]
	shr	eax,	8
	push	eax
	call	uart1_putchar

	mov	eax,	[esp + 8]
	shr	eax,	16
	push	eax
	call	uart1_putchar

	mov	eax,	[esp + 8]
	shr	eax,	24
	push	eax
	call	uart1_putchar

	pop	eax
	ret	4
endp

proc uart1_dump_td
	; on entry:
	; eax - pointer to buffer data
	; ebx - size of buffer data
	; ecx - pointer to OHCI TD (hardware) data structure
        ;mov     [ecx+ohci_gtd.Flags-sizeof.ohci_gtd], eax
	pushf
	cli

	push	eax

	mov	eax,	0xffffff00 + TRANSFER_DESCRIPTOR_READY_LOG_PREFIX
	push	eax
	call	uart1_putchar

	; dump TD
	mov	eax,	[ecx - 5 * 4]
	push	eax
	call	uart1_write_integer

	mov	eax,	[ecx - 4 * 4]
	push	eax
	call	uart1_write_integer

	mov	eax,	[ecx - 3 * 4]
	push	eax
	call	uart1_write_integer

	mov	eax,	[ecx - 2 * 4]
	push	eax
	call	uart1_write_integer

	push	ebx
	call	uart1_write_integer

	; dump data
	push	ebx
	mov	eax,	[esp + 4]
	push	eax
	call	uart1_dump_mem

	pop	eax
	popf
	ret
endp


proc uart1_dump_mem
	; 2 params: buffer, length
	pushf
	cli
	push	eax
	push	ebx
	push	ecx

	mov	eax,	[esp + 20]
	mov	ebx,	[esp + 24]
	jmp	x1
@@:
	mov	cl,	[eax]
	push	ecx
	call	uart1_putchar
	inc	eax
	dec	ebx
x1:
	or	ebx,	ebx
	jnz	@b

	pop	ecx
	pop	ebx
	pop	eax
	popf
	ret	8
endp


proc uart1_dump_register_io

	pushf
	cli

	push	eax
	mov	eax,	[esp + 12]
	push	eax
	call	uart1_putchar

	mov	eax,	[esp + 16]
	push	eax
	call	uart1_write_integer
	pop	eax
	popf
	ret	8

endp

proc uart1_dump_port_status_register_io

	push	eax
	mov	eax,	[esp + 8]
	push	eax
	call	uart1_putchar

	mov	eax,	[esp + 12]
	push	eax
	call	uart1_write_integer
	pop	eax
	ret	8

endp

; Called once when driver is loading and once at shutdown.
; When loading, must initialize itself, register itself in the system
; and return eax = value obtained when registering.
proc start
virtual at esp
                dd      ? ; return address
.reason         dd      ? ; DRV_ENTRY or DRV_EXIT
.cmdline        dd      ? ; normally NULL
end virtual

        cmp     [.reason], DRV_ENTRY
        jnz     .nothing
	call	init_uart1
        mov     ecx, ohci_ep_mutex
        and     dword [ecx-4], 0
        invoke  MutexInit
        mov     ecx, ohci_gtd_mutex
        and     dword [ecx-4], 0
        invoke  MutexInit
        push    esi edi
        mov     esi, [USBHCFunc]
        mov     edi, usbhc_api
        movi    ecx, sizeof.usbhc_func/4
        rep movsd
        pop     edi esi
        invoke  RegUSBDriver, ohci_name, 0, ohci_hardware_func
.nothing:
        ret
endp

; Controller-specific initialization function.
; Called from usb_init_controller. Initializes the hardware and
; OHCI-specific parts of software structures.
; eax = pointer to ohci_controller to be initialized
; [ebp-4] = pcidevice

; shopov - seems that %eax points to the HCCA area

proc ohci_init
; inherit some variables from the parent (usb_init_controller)
.devfn   equ ebp - 4
.bus     equ ebp - 3
; 1. Store pointer to ohci_controller for further use.

	;push	eax
	;call	uart1_write_integer


push	0xffffff00 + OHCI_INIT_START_LOG_PREFIX
call	uart1_dump_log_prefix


        push    eax
        mov     edi, eax
	; shopov - %edi = HCCA address
; 2. Initialize hardware fields of ohci_controller.
; Namely, InterruptTable needs to be initialized with
; physical addresses of heads of first 32 Periodic lists.
; Note that all static heads fit in one page, so one call
; to get_pg_addr is sufficient.
if (ohci_controller.IntEDs / 0x1000) <> (ohci_controller.BulkED / 0x1000)
.err assertion failed
end if
if ohci_controller.IntEDs >= 0x1000
.err assertion failed
end if
        lea     esi, [eax+ohci_controller.IntEDs+32*sizeof.ohci_static_ep]
	; shopov - %esi points to after the first 32 EDs in the SW area; the total EDs there is 64
	; shopov - %edi points to the HCCA
	; shopov - %eax - physical address of first ED in the SW area
        invoke  GetPgAddr
        add     eax, ohci_controller.IntEDs
        movi    ecx, 32
        mov     edx, ecx
@@:
        stosd
        add     eax, sizeof.ohci_static_ep
        loop    @b
; 3. Initialize static heads ohci_controller.IntEDs, .ControlED, .BulkED.
; Use the loop over groups: first group consists of first 32 Periodic
; descriptors, next group consists of next 16 Periodic descriptors,
; ..., last group consists of the last Periodic descriptor.
; 3a. Prepare for the loop.
; make edi point to start of ohci_controller.IntEDs,
; other registers are already set.
; -128 fits in one byte, +128 does not fit.
        sub     edi, -128
; 3b. Loop over groups. On every iteration:
; edx = size of group, edi = pointer to the current group,
; esi = pointer to the next group, eax = physical address of the next group.
.init_static_eds:
; 3c. Get the size of the next group.
        shr     edx, 1
; 3d. Exit the loop if there is no next group.
        jz      .init_static_eds_done
; 3e. Initialize the first half of the current group.
; Advance edi to the second half.
        push    eax esi
        call    ohci_init_static_ep_group
        pop     esi eax
; 3f. Initialize the second half of the current group
; with the same values.
; Advance edi to the next group, esi/eax to the next of the next group.
        call    ohci_init_static_ep_group
        jmp     .init_static_eds
.init_static_eds_done:
; 3g. Initialize the head of the last Periodic list.
        xor     eax, eax
        xor     esi, esi
        call    ohci_init_static_endpoint
; 3i. Initialize the heads of Control and Bulk lists.
        call    ohci_init_static_endpoint
        call    ohci_init_static_endpoint
; 4. Create a virtual memory area to talk with the controller.
; 4a. Enable memory & bus master access.
        invoke  PciRead16, dword [.bus], dword [.devfn], 4
        or      al, 6
        invoke  PciWrite16, dword [.bus], dword [.devfn], 4, eax
; 4b. Read memory base address.
        invoke  PciRead32, dword [.bus], dword [.devfn], 10h
        and     al, not 0Fh
; 4c. Create mapping for physical memory. 256 bytes are sufficient.
        invoke  MapIoMem, eax, 100h, PG_SW+PG_NOCACHE
        test    eax, eax
        jz      .fail
        stosd   ; fill ohci_controller.MMIOBase
        xchg    eax, edi
; now edi = MMIOBase
; 5. Reset the controller if needed.
; 5a. Check operational state.
; 0 = reset, 1 = resume, 2 = operational, 3 = suspended


        mov     eax, [edi+OhciControlReg]

	push	eax
	push	0xffffff00 + OhciControlReg_log_prefix_read
	call	uart1_dump_register_io

        and     al, 3 shl 6
        cmp     al, 2 shl 6
        jz      .operational
; 5b. State is not operational, reset is needed.
.reset:
; 5c. Save FmInterval register.
        pushd   [edi+OhciFmIntervalReg]
; 5d. Issue software reset and wait up to 10ms, checking status every 1 ms.
        movi    ecx, 1
        movi    edx, 10
        mov     [edi+OhciCommandStatusReg], ecx

push	ecx
push	0xffffff00 + OhciCommandStatusReg_log_prefix_write
call	uart1_dump_register_io

@@:
        mov     esi, ecx
        invoke  Sleep

push	eax
mov	eax,	[edi+OhciCommandStatusReg]

        ;test    [edi+OhciCommandStatusReg], ecx

push	eax
push	0xffffff00 + OhciCommandStatusReg_log_prefix_read
call	uart1_dump_register_io
test	eax,	ecx
pop	eax

        jz      .resetdone
        dec     edx
        jnz     @b
        pop     eax
        dbgstr 'controller reset timeout'
        jmp     .fail_unmap
.resetdone:
; 5e. Restore FmInterval register.
        pop     eax
        mov     edx, eax
        and     edx, 3FFFh
        jz      .setfminterval
        cmp     dx, 2EDFh       ; default value?
        jnz     @f              ; assume that BIOS has configured the value
.setfminterval:
        mov     eax, 27792EDFh  ; default value
@@:
        mov     [edi+OhciFmIntervalReg], eax

push	eax
push	0xffffff00 + OhciFmIntervalReg_log_prefix_write
call	uart1_dump_register_io

; 5f. Set PeriodicStart to 90% of FmInterval.
        movzx   eax, ax
; Two following lines are equivalent to eax = floor(eax * 0.9)
; for any 0 <= eax < 1C71C71Dh, which of course is far from maximum 0FFFFh.
        mov     edx, 0E6666667h
        mul     edx
        mov     [edi+OhciPeriodicStartReg], edx

push	edx
push	0xffffff00 + OhciPeriodicStartReg_log_prefix_write
call	uart1_dump_register_io

.operational:
; 6. Setup controller registers.
        pop     esi     ; restore pointer to ohci_controller saved in step 1
; 6a. Physical address of HCCA.

; shopov - in %edi - base of ohci operational registers; in %esi - pointer to HCCA

        mov     eax, esi
        invoke  GetPgAddr
        mov     [edi+OhciHCCAReg], eax

push	eax
push	0xffffff00 + OhciHCCAReg_log_prefix_write
call	uart1_dump_register_io

push	eax
push	0xffffff00 + HCCA_CONTENTS_LOG_PREFIX
call	uart1_dump_log_prefix
mov	eax,	256
push	eax
push	esi
call	uart1_dump_mem
pop	eax


; shopov - in %eax - HCCA physical address

; 6b. Transition to operational state and clear all Enable bits.
        mov     cl, 2 shl 6
        mov     [edi+OhciControlReg], ecx

	push	ecx
	push	0xffffff00 + OhciControlReg_log_prefix_write
	call	uart1_dump_register_io

; 6c. Physical addresses of head of Control and Bulk lists.
if ohci_controller.BulkED >= 0x1000
.err assertion failed
end if
        add     eax, ohci_controller.ControlED
        mov     [edi+OhciControlHeadEDReg], eax

push	eax
push	0xffffff00 + OhciControlHeadEDReg_log_prefix_write
call	uart1_dump_register_io

        add     eax, ohci_controller.BulkED - ohci_controller.ControlED
        mov     [edi+OhciBulkHeadEDReg], eax

push	eax
push	0xffffff00 + OhciBulkHeadEDReg_log_prefix_write
call	uart1_dump_register_io

; 6d. Zero Head registers: there are no active Control and Bulk descriptors yet.
        xor     eax, eax
;       mov     [edi+OhciPeriodCurrentEDReg], eax
        mov     [edi+OhciControlCurrentEDReg], eax

push	eax
push	0xffffff00 + OhciControlCurrentEDReg_log_prefix_write
call	uart1_dump_register_io

        mov     [edi+OhciBulkCurrentEDReg], eax

push	eax
push	0xffffff00 + OhciBulkCurrentEDReg_log_prefix_write
call	uart1_dump_register_io

;       mov     [edi+OhciDoneHeadReg], eax
; 6e. Enable processing of all lists with control:bulk ratio = 1:1.
        mov     dword [edi+OhciControlReg], 10111100b

	push	eax
	mov	eax,	10111100b
	push	eax
	push	0xffffff00 + OhciControlReg_log_prefix_write
	call	uart1_dump_register_io
	pop	eax

; 7. Find the EHCI companion.
; Note: this assumes that EHCI is initialized before USB1 companions.


; shopov - !?!?!?

        add     esi, sizeof.ohci_controller
        mov     ebx, dword [.devfn]
        invoke  usbhc_api.usb_find_ehci_companion
        mov     [esi+ohci_controller.EhciCompanion-sizeof.ohci_controller], eax


; shopov - root hub setup

; 8. Get number of ports.
        mov     eax, [edi+OhciRhDescriptorAReg]

push	eax
push	0xffffff00 + OhciRhDescriptorAReg_log_prefix_read
call	uart1_dump_register_io

        and     eax, 0xF
        mov     [esi+usb_controller.NumPorts], eax
; 9. Initialize DoneListEndPtr to point to DoneList.
        lea     eax, [esi+ohci_controller.DoneList-sizeof.ohci_controller]
        mov     [esi+ohci_controller.DoneListEndPtr-sizeof.ohci_controller], eax
; 10. Hook interrupt.
        invoke  PciRead8, dword [.bus], dword [.devfn], 3Ch
; al = IRQ
        movzx   eax, al
        invoke  AttachIntHandler, eax, ohci_irq, esi
; 11. Enable controller interrupt on HcDoneHead writeback and RootHubStatusChange.
        mov     dword [edi+OhciInterruptEnableReg], 80000042h

push	eax
mov	eax,	80000042h
push	eax
push	0xffffff00 + OhciInterruptEnableReg_log_prefix_write
call	uart1_dump_register_io
pop	eax

        DEBUGF 1,'K : OHCI controller at %x:%x with %d ports initialized\n',[.bus]:2,[.devfn]:2,[esi+usb_controller.NumPorts]
; 12. Initialize ports of the controller.
; 12a. Initiate power up, disable all ports, clear all "changed" bits.
        mov     dword [edi+OhciRhStatusReg], 10000h     ; SetGlobalPower

push	eax
mov	eax,	10000h
push	eax
push	0xffffff00 + OhciRhStatusReg_log_prefix_write
call	uart1_dump_register_io
pop	eax

        xor     ecx, ecx
@@:
        mov     dword [edi+OhciRhPortStatusReg+ecx*4], 1F0101h  ; SetPortPower+ClearPortEnable+clear "changed" bits

push	eax
mov	eax,	1F0101h
push	eax
push	ecx
mov	eax,	1
push	eax
call	uart1_dump_roothub_port_access
pop	eax

        inc     ecx
        cmp     ecx, [esi+usb_controller.NumPorts]
        jb      @b
; 12b. Wait for power up.
; VirtualBox has AReg == 0, delay_ms doesn't like zero value; ignore zero delay
        push    esi
        mov     esi, [edi+OhciRhDescriptorAReg]

push	esi
push	0xffffff00 + OhciRhDescriptorAReg_log_prefix_read
call	uart1_dump_register_io

        shr     esi, 24
        add     esi, esi
        jz      @f
        invoke  Sleep
@@:
        pop     esi
; 12c. Ports are powered up; now it is ok to process connect/disconnect events.
        mov     [esi+ohci_controller.PoweredUp-sizeof.ohci_controller], 1
                ; IRQ handler doesn't accept connect/disconnect events before this point
; 12d. We could miss some events while waiting for powering up;
; scan all ports manually and check for connected devices.
        xor     ecx, ecx
.port_loop:

        ;test    dword [edi+OhciRhPortStatusReg+ecx*4], 1


push	eax

mov	eax,    dword [edi+OhciRhPortStatusReg+ecx*4]
push	eax

push	eax
push	ecx
mov	eax,	0
push	eax
call	uart1_dump_roothub_port_access
pop	eax
test	eax,	1
pop	eax



        jz      .next_port
; There is a connected device; mark the port as 'connected'
; and save the connected time.
; Note that ConnectedTime must be set before 'connected' mark,
; otherwise the code in ohci_process_deferred could use incorrect time.
        invoke  GetTimerTicks
        mov     [esi+usb_controller.ConnectedTime+ecx*4], eax
        lock bts [esi+usb_controller.NewConnected], ecx
.next_port:
        inc     ecx
        cmp     ecx, [esi+usb_controller.NumPorts]
        jb      .port_loop
; 13. Return pointer to usb_controller.
        xchg    eax, esi

push	0xffffff00 + OHCI_INIT_END_LOG_PREFIX
call	uart1_dump_log_prefix

        ret
.fail_unmap:
; On error after step 5, release the virtual memory area.
        invoke  FreeKernelSpace, edi
.fail:
; On error, free the ohci_controller structure and return zero.
; Note that the pointer was placed in the stack at step 1.
; Note also that there can be no errors after step 6,
; where that pointer is popped from the stack.
        pop     ecx
.nothing:
        xor     eax, eax

push	0xffffff00 + OHCI_INIT_END_LOG_PREFIX
call	uart1_dump_log_prefix

        ret
endp

; Helper procedure for step 3 of ohci_init.
; Initializes the static head of one list.
; eax = physical address of the "next" list, esi = pointer to the "next" list,
; edi = pointer to head to initialize.
; Advances edi to the next head, keeps eax/esi.
proc ohci_init_static_endpoint
        mov     byte [edi+ohci_static_ep.Flags+1], 1 shl (14 - 8)       ; sKip this endpoint
        mov     [edi+ohci_static_ep.NextED], eax
        mov     [edi+ohci_static_ep.NextList], esi
        add     edi, ohci_static_ep.SoftwarePart
        invoke  usbhc_api.usb_init_static_endpoint
        add     edi, sizeof.ohci_static_ep - ohci_static_ep.SoftwarePart
        ret
endp

; Helper procedure for step 3 of ohci_init.
; Initializes one half of group of static heads.
; edx = size of the next group = half of size of the group,
; edi = pointer to the group, eax = physical address of the next group,
; esi = pointer to the next group.
; Advances eax, esi, edi to next group, keeps edx.
proc ohci_init_static_ep_group
        push    edx
@@:
        call    ohci_init_static_endpoint
        add     eax, sizeof.ohci_static_ep
        add     esi, sizeof.ohci_static_ep
        dec     edx
        jnz     @b
        pop     edx
        ret
endp

; Controller-specific pre-initialization function: take ownership from BIOS.
; Some BIOSes, although not all of them, provide legacy emulation
; for USB keyboard and/or mice as PS/2-devices. In this case,
; we must notify the BIOS that we don't need that emulation and know how to
; deal with USB devices.
proc ohci_kickoff_bios
; 1. Get the physical address of MMIO registers.
        invoke  PciRead32, dword [esi+PCIDEV.bus], dword [esi+PCIDEV.devfn], 10h
        and     al, not 0Fh
; 2. Create mapping for physical memory. 256 bytes are sufficient.
        invoke  MapIoMem, eax, 100h, PG_SW+PG_NOCACHE
        test    eax, eax
        jz      .nothing
; 3. Some BIOSes enable controller interrupts as a result of giving
; controller away. At this point the system knows nothing about how to serve
; OHCI interrupts, so such an interrupt will send the system into an infinite
; loop handling the same IRQ again and again. Thus, we need to block OHCI
; interrupts. We can't do this at the controller level until step 5,
; because the controller is currently owned by BIOS, so we block all hardware
; interrupts on this processor until step 5.
        pushf
        cli
; 4. Take the ownership over the controller.
; 4a. Check whether BIOS handles this controller at all.
        mov     edx, 100h
        test    dword [eax+OhciControlReg], edx
        jz      .has_ownership
; 4b. Send "take ownership" command to the BIOS.
; (This should generate SMI, BIOS should release its ownership in SMI handler.)
        mov     dword [eax+OhciCommandStatusReg], 8

push	eax
mov	eax,	8
push	eax
push	0xffffff00 + OhciCommandStatusReg_log_prefix_write
call	uart1_dump_register_io
pop	eax

; 4c. Wait for result no more than 50 ms, checking for status every 1 ms.
        movi    ecx, 50
@@:
        test    dword [eax+OhciControlReg], edx
        jz      .has_ownership
        push    esi
        movi    esi, 1
        invoke  Sleep
        pop     esi
        loop    @b
        dbgstr 'warning: taking OHCI ownership from BIOS timeout'
.has_ownership:
; 5. Disable all controller interrupts until the system will be ready to
; process them.
        mov     dword [eax+OhciInterruptDisableReg], 0C000007Fh

push	eax
mov	eax,	0C000007Fh
push	eax
push	0xffffff00 + OhciInterruptDisableReg_log_prefix_write
call	uart1_dump_register_io
pop	eax

; 6. Now we can unblock interrupts in the processor.
        popf
; 7. Release memory mapping created in step 2 and return.
        invoke  FreeKernelSpace, eax
.nothing:
        ret
endp

;
; shopov - interrupt (irq) handler
;

; IRQ handler for OHCI controllers.
ohci_irq.noint:
; Not our interrupt: restore registers and return zero.
        xor     eax, eax
        pop     edi esi ebx


push	0xffffff00 + INTERRUPT_EXIT_LOG_PREFIX
call	uart1_dump_log_prefix


        ret

proc ohci_irq
        push    ebx esi edi     ; save used registers to be cdecl
virtual at esp
                rd      3       ; saved registers
                dd      ?       ; return address
.controller     dd      ?
end virtual

push	0xffffff00 + INTERRUPT_ENTRY_LOG_PREFIX
call	uart1_dump_log_prefix

; 1. ebx will hold whether some deferred processing is needed,
; that cannot be done from the interrupt handler. Initialize to zero.
        xor     ebx, ebx
; 2. Get the mask of events which should be processed.
        mov     esi, [.controller]
        mov     edi, [esi+ohci_controller.MMIOBase-sizeof.ohci_controller]
        mov     eax, [edi+OhciInterruptStatusReg]

push	eax
push	0xffffff00 + OhciInterruptStatusReg_log_prefix_read
call	uart1_dump_register_io

; 3. Check whether that interrupt has been generated by our controller.
; (One IRQ can be shared by several devices.)

        ;and     eax, [edi+OhciInterruptEnableReg]

push	ecx
mov	ecx,	[edi+OhciInterruptEnableReg]
push	ecx
push	0xffffff00 + OhciInterruptEnableReg_log_prefix_read
call	uart1_dump_register_io

and	eax,	ecx
pop	ecx




        jz      .noint
; 4. Get the physical pointer to the last processed descriptor.
; All processed descriptors form single-linked list from last to first
; with the help of NextTD field. The list is restarted every time when
; the controller writes to DoneHead, so grab the pointer now (before the next
; step) or it could be lost (the controller could write new value to DoneHead
; any time after WorkDone bit is cleared in OhciInterruptStatusReg).
        mov     ecx, [esi+ohci_controller.DoneHead-sizeof.ohci_controller]
        and     ecx, not 1
; 5. Clear the events we know of.
; Note that this should be done before processing of events:
; new events could arise while we are processing those, this way we won't lose
; them (the controller would generate another interrupt
; after completion of this one).
        mov     [edi+OhciInterruptStatusReg], eax

push	eax
push	0xffffff00 + OhciInterruptStatusReg_log_prefix_write
call	uart1_dump_register_io

; 6. Save the mask of events for further reference.
        push    eax
; 7. Handle 'transfer is done' events.
; 7a. Test whether there are such events.
        test    al, 2
        jz      .skip_donehead
; There are some 'transfer is done' events, processed descriptors are linked
; through physical addresses in the reverse order.
; We can't do much in an interrupt handler, since callbacks could require
; waiting for locks and that can't be done in an interrupt handler.
; However, we can't also just defer all work to the USB thread, since
; it is possible that previous lists are not yet processed and it is hard
; to store unlimited number of list heads. Thus, we reverse the current list,
; append it to end of the previous list (if there is one) and defer other
; processing to the USB thread; this way there always is no more than one list
; (possibly joined from several controller-reported lists).
; The list traversal requires converting physical addresses to virtual pointers,
; so we may as well store pointers instead of physical addresses.
; 7b. Prepare for the reversing loop.

push	0xffffff00 + INTERRUPT_TRANSFER_DONE_LOG_PREFIX
call	uart1_dump_log_prefix

        push    ebx
        xor     ebx, ebx
        test    ecx, ecx
        jz      .tddone
        mov     eax, [ohci_gtd_first_page]
        invoke  usbhc_api.usb_td_to_virt
        test    eax, eax
        jz      .tddone
        lea     edx, [eax+ohci_gtd.NextTD]
; 7c. Reverse the list, converting physical to virtual. On every iteration:
; ecx = physical address of the current item
; eax = virtual pointer to the current item
; edx = virtual pointer to the last item.NextTD (first in the reverse list)
; ebx = virtual pointer to the next item (previous in the reverse list)
.tdloop:
        mov     ecx, [eax+ohci_gtd.NextTD]
        mov     [eax+ohci_gtd.NextTD], ebx
        lea     ebx, [eax+sizeof.ohci_gtd]
        test    ecx, ecx
        jz      .tddone
        mov     eax, [ohci_gtd_first_page]
        invoke  usbhc_api.usb_td_to_virt
        test    eax, eax
        jnz     .tdloop
.tddone:
        mov     ecx, ebx
        pop     ebx
; 7d. The list is reversed,
; ecx = pointer to the first item, edx = pointer to the last item.NextTD.
; If the list is empty (unusual case), step 7 is done.
        test    ecx, ecx
        jz      .skip_donehead
; 7e. Otherwise, append this list to the end of previous one.
; Note that in theory the interrupt handler and the USB thread
; could execute in parallel.
.append_restart:
; Atomically get DoneListEndPtr in eax and set it to edx.
        mov     eax, [esi+ohci_controller.DoneListEndPtr-sizeof.ohci_controller]
        lock cmpxchg [esi+ohci_controller.DoneListEndPtr-sizeof.ohci_controller], edx
        jnz     .append_restart
; Store pointer to the new list.
; Note: we cannot perform any operations with [DoneListEndPtr]
; until we switch DoneListEndPtr to a new descriptor:
; it is possible that after first line of .append_restart loop
; ohci_process_deferred obtains the control, finishes processing
; of the old list, sets DoneListEndPtr to address of DoneList,
; frees all old descriptors, so eax would point to invalid location.
; This way, .append_restart loop would detect that DoneListEndPtr
; has changed, so eax needs to be re-read.
        mov     [eax], ecx
; 7f. Notify the USB thread that there is new work.
        inc     ebx
.skip_donehead:
; 8. Handle start-of-frame events.
; 8a. Test whether there are such events.
        test    byte [esp], 4
        jz      .skip_sof

push	0xffffff00 + INTERRUPT_START_OF_FRAME_LOG_PREFIX
call	uart1_dump_log_prefix

; We enable SOF interrupt only when some pipes are waiting after changes.
        spin_lock_irqsave [esi+usb_controller.WaitSpinlock]
; 8b. Make sure that there was at least one frame update
; since the request. If not, wait for the next SOF.
        movzx   eax, [esi+ohci_controller.FrameNumber-sizeof.ohci_controller]
        cmp     eax, [esi+usb_controller.StartWaitFrame]
        jz      .sof_unlock
; 8c. Copy WaitPipeRequest* to ReadyPipeHead*.
        mov     eax, [esi+usb_controller.WaitPipeRequestAsync]
        mov     [esi+usb_controller.ReadyPipeHeadAsync], eax
        mov     eax, [esi+usb_controller.WaitPipeRequestPeriodic]
        mov     [esi+usb_controller.ReadyPipeHeadPeriodic], eax
; 8d. It is possible that pipe change is due to removal and
; Control/BulkCurrentED registers still point to one of pipes to be removed.
; The code responsible for disconnect events has temporarily stopped
; Control/Bulk processing, so it is safe to clear Control/BulkCurrentED.
; After that, restart processing.
        xor     edx, edx
        mov     [edi+OhciControlCurrentEDReg], edx

push	edx
push	0xffffff00 + OhciControlCurrentEDReg_log_prefix_write
call	uart1_dump_register_io

        mov     [edi+OhciBulkCurrentEDReg], edx

push	edx
push	0xffffff00 + OhciBulkCurrentEDReg_log_prefix_write
call	uart1_dump_register_io

        mov     dword [edi+OhciCommandStatusReg], 6

push	eax
mov	eax,	6
push	eax
push	0xffffff00 + OhciCommandStatusReg_log_prefix_write
call	uart1_dump_register_io
pop	eax



push	eax
mov	eax,      dword [edi+OhciControlReg]
or	eax,	0x30

        ;or      dword [edi+OhciControlReg], 30h
        mov      dword [edi+OhciControlReg], eax

push	eax
push	0xffffff00 + OhciControlReg_log_prefix_write
call	uart1_dump_register_io
pop	eax




; 8e. Disable further interrupts on SOF.
; Note: OhciInterruptEnableReg/OhciInterruptDisableReg have unusual semantics.
        mov     dword [edi+OhciInterruptDisableReg], 4

push	eax
mov	eax,	4
push	eax
push	0xffffff00 + OhciInterruptDisableReg_log_prefix_write
call	uart1_dump_register_io
pop	eax

; Notify the USB thread that there is new work (with pipes from ReadyPipeHead*).
        inc     ebx
.sof_unlock:
        spin_unlock_irqrestore [esi+usb_controller.RemoveSpinlock]
.skip_sof:
; Handle roothub events.
; 9. Test whether there are such events.
        test    byte [esp], 40h
        jz      .skip_roothub

push	0xffffff00 + INTERRUPT_ROOT_HUB_EVENT_PREFIX
call	uart1_dump_log_prefix

; 10. Check the status of the roothub itself.
; 10a. Global overcurrent?


        ;test    dword [edi+OhciRhStatusReg], 2

push	eax
mov	eax,	dword [edi+OhciRhStatusReg]
push	eax
push	0xffffff00 + OhciRhStatusReg_log_prefix_read
call	uart1_dump_register_io
test	eax,	2
pop	eax

        jz      @f
; Note: this needs work.
        dbgstr 'global overcurrent'
@@:
; 10b. Clear roothub events.
        mov     dword [edi+OhciRhStatusReg], 80020000h

push	eax
mov	eax,	80020000h
push	eax
push	0xffffff00 + OhciRhStatusReg_log_prefix_write
call	uart1_dump_register_io
pop	eax

; 11. Check the status of individual ports.
; Look for connect/disconnect and reset events.
; 11a. Prepare for the loop: start from port 0.
        xor     ecx, ecx
.portloop:
; 11b. Get the port status and changes of it.
; Accumulate change information.
; Look to "11.12.3 Port Change Information Processing" of the USB2 spec.
        xor     eax, eax
.accloop:
        mov     edx, [edi+OhciRhPortStatusReg+ecx*4]


push	eax
push	edx
push	ecx
mov	eax,	0
push	eax
call	uart1_dump_roothub_port_access
pop	eax



        xor     ax, ax
        or      eax, edx
        test    edx, 1F0000h
        jz      .accdone
        mov     dword [edi+OhciRhPortStatusReg+ecx*4], 1F0000h


push	eax
mov	eax,	1F0000h
push	eax
push	ecx
mov	eax,	1
push	eax
call	uart1_dump_roothub_port_access
pop	eax


        jmp     .accloop
.accdone:
; debugging output, not needed for work
;       test    eax, 1F0000h
;       jz      @f
;       DEBUGF 1,'K : ohci %x status of port %d is %x\n',esi,ecx,eax
;@@:
; 11c. Ignore any events until all ports are powered up.
; They will be processed by ohci_init.
        cmp     [esi+ohci_controller.PoweredUp-sizeof.ohci_controller], 0
        jz      .nextport
; Handle changing of connection status.
        test    eax, 10000h
        jz      .nocsc
; There was a connect or disconnect event at this port.
; 11d. Disconnect the old device on this port, if any.
; if the port was resetting, indicate fail and signal
        cmp     cl, [esi+usb_controller.ResettingPort]
        jnz     @f
        mov     [esi+usb_controller.ResettingStatus], -1
        inc     ebx
@@:
        lock bts [esi+usb_controller.NewDisconnected], ecx
; notify the USB thread that new work is waiting
        inc     ebx
; 11e. Change connected status. For the connection event, also
; store the connection time; any further processing is permitted only
; after USB_CONNECT_DELAY ticks.
        test    al, 1
        jz      .disconnect
; Note: ConnectedTime must be stored before setting the 'connected' bit,
; otherwise ohci_process_deferred could use an old time.
        invoke  GetTimerTicks
        mov     [esi+usb_controller.ConnectedTime+ecx*4], eax
        lock bts [esi+usb_controller.NewConnected], ecx
        jmp     .nextport
.disconnect:
        lock btr [esi+usb_controller.NewConnected], ecx
        jmp     .nextport
.nocsc:
; 11f. Process 'reset done' events.
        test    eax, 100000h
        jz      .nextport
        test    al, 10h
        jnz     .nextport
        invoke  GetTimerTicks
        mov     [esi+usb_controller.ResetTime], eax
        mov     [esi+usb_controller.ResettingStatus], 2
        inc     ebx
.nextport:
; 11g. Continue the loop for the next port.
        inc     ecx
        cmp     ecx, [esi+usb_controller.NumPorts]
        jb      .portloop
.skip_roothub:
; 12. Restore the stack after step 6.
        pop     eax
; 13. Notify the USB thread if some deferred processing is required.
        invoke  usbhc_api.usb_wakeup_if_needed
; 14. Interrupt processed; return something non-zero.
        mov     al, 1
        pop     edi esi ebx     ; restore used registers to be stdcall


push	0xffffff00 + INTERRUPT_EXIT_LOG_PREFIX
call	uart1_dump_log_prefix

        ret
endp

; This procedure is called from usb_set_address_callback
; and stores USB device address in the ohci_pipe structure.
; in: esi -> usb_controller, ebx -> usb_pipe, cl = address
proc ohci_set_device_address
        mov     byte [ebx+ohci_pipe.Flags-sizeof.ohci_pipe], cl
; Wait until the hardware will forget the old value.
        jmp     [usbhc_api.usb_subscribe_control]
endp

; This procedure returns USB device address from the usb_pipe structure.
; in: esi -> usb_controller, ebx -> usb_pipe
; out: eax = endpoint address
proc ohci_get_device_address
        mov     eax, [ebx+ohci_pipe.Flags-sizeof.ohci_pipe]
        and     eax, 7Fh
        ret
endp

; This procedure is called from usb_set_address_callback
; if the device does not accept SET_ADDRESS command and needs
; to be disabled at the port level.
; in: esi -> usb_controller, ecx = port
proc ohci_port_disable
        mov     edx, [esi+ohci_controller.MMIOBase-sizeof.ohci_controller]
        mov     dword [edx+OhciRhPortStatusReg+ecx*4], 1


push	eax
mov	eax,	1
push	eax
push	ecx
mov	eax,	1
push	eax
call	uart1_dump_roothub_port_access
pop	eax



        ret
endp

; This procedure is called from usb_get_descr8_callback when
; the packet size for zero endpoint becomes known and
; stores the packet size in ohci_pipe structure.
; in: esi -> usb_controller, ebx -> usb_pipe, ecx = packet size
proc ohci_set_endpoint_packet_size
        mov     byte [ebx+ohci_pipe.Flags+2-sizeof.ohci_pipe], cl
; Wait until the hardware will forget the old value.
        jmp     [usbhc_api.usb_subscribe_control]
endp

; This procedure is called from API usb_open_pipe and processes
; the controller-specific part of this API. See docs.
; in: edi -> usb_pipe for target, ecx -> usb_pipe for config pipe,
; esi -> usb_controller, eax -> usb_gtd for the first TD,
; [ebp+12] = endpoint, [ebp+16] = maxpacket, [ebp+20] = type
proc ohci_init_pipe
virtual at ebp-12
.speed          db      ?
                rb      3
.bandwidth      dd      ?
.target         dd      ?
                rd      2
.config_pipe    dd      ?
.endpoint       dd      ?
.maxpacket      dd      ?
.type           dd      ?
.interval       dd      ?
end virtual
; 1. Initialize the queue of transfer descriptors: empty.
        sub     eax, sizeof.ohci_gtd
        invoke  GetPhysAddr
        mov     [edi+ohci_pipe.TailP-sizeof.ohci_pipe], eax
        mov     [edi+ohci_pipe.HeadP-sizeof.ohci_pipe], eax
; 2. Generate ohci_pipe.Flags, see the description in ohci_pipe.
        mov     eax, [ecx+ohci_pipe.Flags-sizeof.ohci_pipe]
        and     eax, 0x207F     ; keep Speed bit and FunctionAddress
        mov     edx, [.endpoint]
        and     edx, 15
        shl     edx, 7
        or      eax, edx
        mov     [edi+ohci_pipe.Flags-sizeof.ohci_pipe], eax
        bt      eax, 13
        setc    [.speed]
        mov     eax, [.maxpacket]
        mov     word [edi+ohci_pipe.Flags+2-sizeof.ohci_pipe], ax
        cmp     [.type], CONTROL_PIPE
        jz      @f
        test    byte [.endpoint], 80h
        setnz   al
        inc     eax
        shl     al, 3
        or      byte [edi+ohci_pipe.Flags+1-sizeof.ohci_pipe], al
@@:
; 3. Insert the new pipe to the corresponding list of endpoints.
; 3a. Use Control list for control pipes, Bulk list for bulk pipes.
        lea     edx, [esi+ohci_controller.ControlED.SoftwarePart-sizeof.ohci_controller]
        cmp     [.type], BULK_PIPE
        jb      .insert ; control pipe
        lea     edx, [esi+ohci_controller.BulkED.SoftwarePart-sizeof.ohci_controller]
        jz      .insert ; bulk pipe
.interrupt_pipe:
; 3b. For interrupt pipes, let the scheduler select the appropriate list
; based on the current bandwidth distribution and the requested bandwidth.
; This could fail if the requested bandwidth is not available;
; if so, return an error.
        lea     edx, [esi + ohci_controller.IntEDs - sizeof.ohci_controller]
        lea     eax, [esi + ohci_controller.IntEDs + 32*sizeof.ohci_static_ep - sizeof.ohci_controller]
        movi    ecx, 64
        call    usb1_select_interrupt_list
        test    edx, edx
        jz      .return0
; 3c. Insert endpoint at edi to the head of list in edx.
; Inserting to tail would work as well,
; but let's be consistent with other controllers.
.insert:
        mov     [edi+usb_pipe.BaseList], edx
        mov     ecx, [edx+usb_pipe.NextVirt]
        mov     [edi+usb_pipe.NextVirt], ecx
        mov     [edi+usb_pipe.PrevVirt], edx
        mov     [ecx+usb_pipe.PrevVirt], edi
        mov     [edx+usb_pipe.NextVirt], edi
        mov     ecx, [edx+ohci_pipe.NextED-sizeof.ohci_pipe]
        mov     [edi+ohci_pipe.NextED-sizeof.ohci_pipe], ecx
        lea     eax, [edi-sizeof.ohci_pipe]
        invoke  GetPhysAddr
        mov     [edx+ohci_pipe.NextED-sizeof.ohci_pipe], eax
; 4. Return something non-zero.
        ret
.return0:
        xor     eax, eax
        ret
endp

; This function is called from ohci_process_deferred when
; a new device was connected at least USB_CONNECT_DELAY ticks
; and therefore is ready to be configured.
; ecx = port, esi -> usb_controller
proc ohci_new_port
; test whether we are configuring another port
; if so, postpone configuring and return
        bts     [esi+usb_controller.PendingPorts], ecx
        cmp     [esi+usb_controller.ResettingPort], -1
        jnz     .nothing
        btr     [esi+usb_controller.PendingPorts], ecx
; fall through to ohci_new_port.reset

; This function is called from usb_test_pending_port.
; It starts reset signalling for the port. Note that in USB first stages
; of configuration can not be done for several ports in parallel.
.reset:
; reset port
        and     [esi+usb_controller.ResettingHub], 0
        mov     [esi+usb_controller.ResettingPort], cl
; Note: setting status must be the last action:
; it is possible that the device has been disconnected
; after timeout of USB_CONNECT_DELAY but before call to ohci_new_port.
; In this case, ohci_irq would not set reset status to 'failed',
; because ohci_irq would not know that this port is to be reset.
; However, the hardware would generate another interrupt
; in a response to reset a disconnected port, and this time
; ohci_irq knows that it needs to generate 'reset failed' event
; (because ResettingPort is now filled).
        push    edi
        mov     edi, [esi+ohci_controller.MMIOBase-sizeof.ohci_controller]
        mov     dword [edi+OhciRhPortStatusReg+ecx*4], 10h

push	eax
mov	eax,	10h
push	eax
push	ecx
mov	eax,	1
push	eax
call	uart1_dump_roothub_port_access
pop	eax


        pop     edi
.nothing:
        ret
endp

; This procedure is called from the several places in main USB code
; and allocates required packets for the given transfer.
; ebx = pipe, other parameters are passed through the stack:
; buffer,size = data to transfer
; flags = same as in usb_open_pipe: bit 0 = allow short transfer, other bits reserved
; td = pointer to the current end-of-queue descriptor
; direction =
;   0000b for normal transfers,
;   1000b for control SETUP transfer,
;   1101b for control OUT transfer,
;   1110b for control IN transfer
; returns eax = pointer to the new end-of-queue descriptor
; (not included in the queue itself) or 0 on error
proc ohci_alloc_transfer stdcall uses edi, \
        buffer:dword, size:dword, flags:dword, td:dword, direction:dword
locals
origTD          dd      ?
packetSize      dd      ?       ; must be the last variable, see usb_init_transfer
endl
; 1. Save original value of td:
; it will be useful for rollback if something would fail.
        mov     eax, [td]
        mov     [origTD], eax
; One transfer descriptor can describe up to two pages.
; In the worst case (when the buffer is something*1000h+0FFFh)
; this corresponds to 1001h bytes. If the requested size is
; greater, we should split the transfer into several descriptors.
; Boundaries to split must be multiples of endpoint transfer size
; to avoid short packets except in the end of the transfer.
        cmp     [size], 1001h
        jbe     .lastpacket
; 2. While the remaining data cannot fit in one packet,
; allocate full-sized descriptors.
; 2a. Calculate size of one descriptor: must be a multiple of transfer size
; and must be not greater than 1001h.
        movzx   ecx, word [ebx+ohci_pipe.Flags+2-sizeof.ohci_pipe]
        mov     eax, 1001h
        xor     edx, edx
        mov     edi, eax
        div     ecx
        sub     edi, edx
; 2b. Allocate in loop.
        mov     [packetSize], edi
.fullpackets:
        call    ohci_alloc_packet
        test    eax, eax
        jz      .fail

	push	eax
	push	ebx
	mov	eax,	[buffer]
	mov	ebx,	[size]
	call	uart1_dump_td
	pop	ebx
	pop	eax

        mov     [td], eax
        add     [buffer], edi
        sub     [size], edi

        cmp     [size], 1001h
        ja      .fullpackets
; 3. The remaining data can fit in one descriptor;
; allocate the last descriptor with size = size of remaining data.
.lastpacket:
        mov     eax, [size]
        mov     [packetSize], eax
        call    ohci_alloc_packet
        test    eax, eax
        jz      .fail
; 4. Enable an immediate interrupt on completion of the last packet.
        and     byte [ecx+ohci_gtd.Flags+2-sizeof.ohci_gtd], not (7 shl (21-16))
; 5. If a short transfer is ok for a caller, set the corresponding bit in
; the last descriptor, but not in others.
; Note: even if the caller says that short transfers are ok,
; all packets except the last one are marked as 'must be complete':
; if one of them will be short, the software intervention is needed
; to skip remaining packets; ohci_process_finalized_td will handle this
; transparently to the caller.
        test    [flags], 1
        jz      @f
        or      byte [ecx+ohci_gtd.Flags+2-sizeof.ohci_gtd], 1 shl (18-16)
@@:
	
	push	eax
	push	ebx
	mov	eax,	[buffer]
	mov	ebx,	[size]
	call	uart1_dump_td
	pop	ebx
	pop	eax

        ret
.fail:
        mov     edi, ohci_hardware_func
        mov     eax, [td]
        invoke  usbhc_api.usb_undo_tds, [origTD]
        xor     eax, eax
        ret
endp

; Helper procedure for ohci_alloc_transfer.
; Allocates and initializes one transfer descriptor.
; ebx = pipe, other parameters are passed through the stack;
; fills the current last descriptor and
; returns eax = next descriptor (not filled).
proc ohci_alloc_packet
; inherit some variables from the parent ohci_alloc_transfer
virtual at ebp-8
.origTD         dd      ?
.packetSize     dd      ?
                rd      2
.buffer         dd      ?
.transferSize   dd      ?
.Flags          dd      ?
.td             dd      ?
.direction      dd      ?
end virtual
; 1. Allocate the next TD.
        call    ohci_alloc_gtd
        test    eax, eax
        jz      .nothing
; 2. Initialize controller-independent parts of both TDs.
        push    eax
        invoke  usbhc_api.usb_init_transfer

; !!!!!!! shopov: here, %ecx points to the software (controller-independent) part of the transfer descriptor (TD)

        pop     eax
; 3. Save the returned value (next descriptor).
        push    eax
; 4. Store the physical address of the next descriptor.
        sub     eax, sizeof.ohci_gtd
        invoke  GetPhysAddr
        mov     [ecx+ohci_gtd.NextTD-sizeof.ohci_gtd], eax
; 5. For zero-length transfers, store zero in both fields for buffer addresses.
; Otherwise, fill them with real values.
        xor     eax, eax
        mov     [ecx+ohci_gtd.CurBufPtr-sizeof.ohci_gtd], eax
        mov     [ecx+ohci_gtd.BufEnd-sizeof.ohci_gtd], eax
        cmp     [.packetSize], eax
        jz      @f
        mov     eax, [.buffer]
        invoke  GetPhysAddr
        mov     [ecx+ohci_gtd.CurBufPtr-sizeof.ohci_gtd], eax
        mov     eax, [.buffer]
        add     eax, [.packetSize]
        dec     eax
        invoke  GetPhysAddr
        mov     [ecx+ohci_gtd.BufEnd-sizeof.ohci_gtd], eax
@@:
; 6. Generate Flags field:
; - set bufferRounding (bit 18) to zero = disallow short transfers;
;   for the last transfer in a row, ohci_alloc_transfer would set the real value;
; - set Direction (bits 19-20) to lower 2 bits of [.direction];
; - set DelayInterrupt (bits 21-23) to 7 = do not generate interrupt;
;   for the last transfer in a row, ohci_alloc_transfer would set the real value;
; - set DataToggle (bits 24-25) to next 2 bits of [.direction];
; - set ConditionCode (bits 28-31) to 1111b as a indicator that there was no
;   attempts to perform this transfer yet;
; - zero all other bits.
        mov     eax, [.direction]
        mov     edx, eax
        and     eax, 3
        shl     eax, 19
        and     edx, (3 shl 2)
        shl     edx, 24 - 2
        lea     eax, [eax + edx + (7 shl 21) + (15 shl 28)]
        mov     [ecx+ohci_gtd.Flags-sizeof.ohci_gtd], eax

	;call	uart1_dump_td

; 7. Restore the returned value saved in step 3.
        pop     eax
.nothing:
        ret
endp

; This procedure is called from the several places in main USB code
; and activates the transfer which was previously allocated by
; ohci_alloc_transfer.
; ecx -> last descriptor for the transfer, ebx -> usb_pipe
proc ohci_insert_transfer
; 1. Advance the queue of transfer descriptors.
        mov     eax, [ecx+ohci_gtd.NextTD-sizeof.ohci_gtd]
        mov     [ebx+ohci_pipe.TailP-sizeof.ohci_pipe], eax
; 2. For control and bulk pipes, notify the controller that
; there is new work in control/bulk queue respectively.
ohci_notify_new_work:
        mov     edx, [ebx+usb_pipe.Controller]
        mov     edx, [edx+ohci_controller.MMIOBase-sizeof.ohci_controller]
        cmp     [ebx+usb_pipe.Type], CONTROL_PIPE
        jz      .control
        cmp     [ebx+usb_pipe.Type], BULK_PIPE
        jnz     .nothing
.bulk:
        mov     dword [edx+OhciCommandStatusReg], 4

push	eax
mov	eax,	4
push	eax
push	0xffffff00 + OhciCommandStatusReg_log_prefix_write
call	uart1_dump_register_io
pop	eax

        jmp     .nothing
.control:
        mov     dword [edx+OhciCommandStatusReg], 2

push	eax
mov	eax,	2
push	eax
push	0xffffff00 + OhciCommandStatusReg_log_prefix_write
call	uart1_dump_register_io
pop	eax

.nothing:
        ret
endp

; This function is called from ohci_process_deferred when
; a new device has been reset and needs to be configured.
proc ohci_port_after_reset
; 1. Get the status.
; If reset has been failed (device disconnected during reset),
; continue to next device (if there is one).
        xor     eax, eax
        xchg    al, [esi+usb_controller.ResettingStatus]
        test    al, al
        jns     @f
        jmp     [usbhc_api.usb_test_pending_port]
@@:
; If the controller has disabled the port (e.g. overcurrent),
; continue to next device (if there is one).
        movzx   ecx, [esi+usb_controller.ResettingPort]
        mov     eax, [edi+OhciRhPortStatusReg+ecx*4]



push	eax
push	eax
push	ecx
mov	eax,	0
push	eax
call	uart1_dump_roothub_port_access
pop	eax



        test    al, 2
        jnz     @f
        DEBUGF 1,'K : USB port disabled after reset, status=%x\n',eax
        jmp     [usbhc_api.usb_test_pending_port]
@@:
        push    ecx
; 2. Get LowSpeed bit to bit 0 of eax and call the worker procedure
; to notify the protocol layer about new OHCI device.
        mov     eax, [edi+OhciRhPortStatusReg+ecx*4]



push	eax
push	eax
push	ecx
mov	eax,	0
push	eax
call	uart1_dump_roothub_port_access
pop	eax


        DEBUGF 1,'K : port_after_reset, status of port %d is %x\n',ecx,eax
        shr     eax, 9
        call    ohci_new_device
        pop     ecx
; 3. If something at the protocol layer has failed
; (no memory, no bus address), disable the port and stop the initialization.
        test    eax, eax
        jnz     .nothing
.disable_exit:
        mov     dword [edi+OhciRhPortStatusReg+ecx*4], 1

push	eax
mov	eax,	1
push	eax
push	ecx
mov	eax,	1
push	eax
call	uart1_dump_roothub_port_access
pop	eax


        jmp     [usbhc_api.usb_test_pending_port]
.nothing:
        ret
endp

; This procedure is called from uhci_port_init and from hub support code
; when a new device is connected and has been reset.
; It calls usb_new_device at the protocol layer with correct parameters.
; in: esi -> usb_controller, eax = speed;
; OHCI is USB1 device, so only low bit of eax (LowSpeed) is used.
proc ohci_new_device
; 1. Clear all bits of speed except bit 0.
        and     eax, 1
; 2. Store the speed for the protocol layer.
        mov     [esi+usb_controller.ResettingSpeed], al
; 3. Create pseudo-pipe in the stack.
; See ohci_init_pipe: only .Controller and .Flags fields are used.
        shl     eax, 13
        push    esi     ; .Controller
        mov     ecx, esp
        sub     esp, 12 ; ignored fields
        push    eax     ; .Flags
; 4. Notify the protocol layer.
        invoke  usbhc_api.usb_new_device
; 5. Cleanup the stack after step 3 and return.
        add     esp, 20
        ret
endp

; This procedure is called in the USB thread from usb_thread_proc,
; processes regular actions and those actions which can't be safely done
; from interrupt handler.
; Returns maximal time delta before the next call.
proc ohci_process_deferred
        push    ebx edi         ; save used registers to be stdcall
; 1. Initialize the return value.
        push    -1
; 2. Process disconnect events.
; Capture NewConnected mask in the state before disconnect processing;
; IRQ handler could asynchronously signal disconnect+connect event,
; connect events should be handled after disconnect events.
        push    [esi+usb_controller.NewConnected]
        invoke  usbhc_api.usb_disconnect_stage2
; 3. Check for connected devices.
; If there is a connected device which was connected less than
; USB_CONNECT_DELAY ticks ago, plan to wake up when the delay will be over.
; Otherwise, call ohci_new_port.
        mov     edi, [esi+ohci_controller.MMIOBase-sizeof.ohci_controller]
        xor     ecx, ecx
        cmp     [esp], ecx
        jz      .skip_newconnected
.portloop:
        bt      [esp], ecx
        jnc     .noconnect
; If this port is shared with the EHCI companion and we see the connect event,
; then the device is USB1 dropped by EHCI,
; so EHCI has already waited for debounce delay, we can proceed immediately.
        cmp     [esi+ohci_controller.EhciCompanion-sizeof.ohci_controller], 0
        jz      .portloop.test_time
        dbgstr 'port is shared with EHCI, skipping initial debounce'
        jmp     .connected
.portloop.test_time:
        invoke  GetTimerTicks
        sub     eax, [esi+usb_controller.ConnectedTime+ecx*4]
        sub     eax, USB_CONNECT_DELAY
        jge     .connected
        neg     eax
        cmp     [esp+4], eax
        jb      .nextport
        mov     [esp+4], eax
        jmp     .nextport
.connected:
        lock btr [esi+usb_controller.NewConnected], ecx
        jnc     .nextport
        call    ohci_new_port
.noconnect:
.nextport:
        inc     ecx
        cmp     ecx, [esi+usb_controller.NumPorts]
        jb      .portloop
.skip_newconnected:
        pop     eax
; 4. Check for end of reset signalling. If so, call ohci_port_after_reset.
        cmp     [esi+usb_controller.ResettingStatus], 2
        jnz     .no_reset_recovery
        invoke  GetTimerTicks
        sub     eax, [esi+usb_controller.ResetTime]
        sub     eax, USB_RESET_RECOVERY_TIME
        jge     .reset_done
        neg     eax
        cmp     [esp], eax
        jb      .skip_roothub
        mov     [esp], eax
        jmp     .skip_roothub
.no_reset_recovery:
        cmp     [esi+usb_controller.ResettingStatus], 0
        jz      .skip_roothub
.reset_done:
        call    ohci_port_after_reset
.skip_roothub:
; 5. Finalize transfers processed by hardware.
; It is better to perform this step after processing disconnect events,
; although not strictly obligatory. This way, an active transfer aborted
; due to disconnect would be handled with more specific USB_STATUS_CLOSED,
; not USB_STATUS_NORESPONSE.
; Loop over all items in DoneList, call ohci_process_finalized_td for each.
        xor     ebx, ebx
        xchg    ebx, [esi+ohci_controller.DoneList-sizeof.ohci_controller]
.tdloop:
        test    ebx, ebx
        jz      .tddone
        call    ohci_process_finalized_td
        jmp     .tdloop
.tddone:
; 6. Process wait-done notifications, test for new wait requests.
; Note: that must be done after steps 2 and 5 which could create new requests.
; 6a. Call the worker function from main USB code.
        invoke  usbhc_api.usb_process_wait_lists
; 6b. If no new requests, skip the rest of this step.
        test    eax, eax
        jz      @f
; 6c. OHCI is not allowed to cache anything; we don't know what is
; processed right now, but we can be sure that the controller will not
; use any removed structure starting from the next frame.
; Schedule SOF event.
        spin_lock_irq [esi+usb_controller.RemoveSpinlock]
        mov     eax, [esi+usb_controller.WaitPipeListAsync]
        mov     [esi+usb_controller.WaitPipeRequestAsync], eax
        mov     eax, [esi+usb_controller.WaitPipeListPeriodic]
        mov     [esi+usb_controller.WaitPipeRequestPeriodic], eax
; temporarily stop bulk and interrupt processing;
; this is required for handler of SOF event

push	eax
mov	eax,     dword [edi+OhciControlReg]
and	eax,     not	0x30

	;and     dword [edi+OhciControlReg], not 30h
	mov     dword [edi+OhciControlReg], eax

push	eax
push	0xffffff00 + OhciControlReg_log_prefix_write
call	uart1_dump_register_io
pop	eax


; remember the frame number when processing has been stopped
; (needs to be done after stopping)
        movzx   eax, [esi+ohci_controller.FrameNumber-sizeof.ohci_controller]
        mov     [esi+usb_controller.StartWaitFrame], eax
; make sure that the next SOF will happen after the request
        mov     dword [edi+OhciInterruptStatusReg], 4

push	eax
mov	eax,	4
push	eax
push	0xffffff00 + OhciInterruptStatusReg_log_prefix_write
call	uart1_dump_register_io
pop	eax

; enable interrupt on SOF
; Note: OhciInterruptEnableReg/OhciInterruptDisableReg have unusual semantics,
; so there should be 'mov' here, not 'or'
        mov     dword [edi+OhciInterruptEnableReg], 4

push	eax
mov	eax,	4
push	eax
push	0xffffff00 + OhciInterruptEnableReg_log_prefix_write
call	uart1_dump_register_io
pop	eax

        spin_unlock_irq [esi+usb_controller.RemoveSpinlock]
@@:
; 7. Restore the return value and return.
        pop     eax
        pop     edi ebx         ; restore used registers to be stdcall
        ret
endp

; Helper procedure for ohci_process_deferred. Processes one completed TD.
; in: esi -> usb_controller, ebx -> usb_gtd, out: ebx -> next usb_gtd.
proc ohci_process_finalized_td
;       DEBUGF 1,'K : processing %x\n',ebx
; 1. Check whether the pipe has been closed, either due to API call or due to
; disconnect; if so, the callback will be called by usb_pipe_closed with
; correct status, so go to step 6 with ebx = 0 (do not free the TD).
        mov     edx, [ebx+usb_gtd.Pipe]
        test    [edx+usb_pipe.Flags], USB_FLAG_CLOSED
        jz      @f
        lea     eax, [ebx+ohci_gtd.NextTD-sizeof.ohci_gtd]
        xor     ebx, ebx
        jmp     .next_td2
@@:
; 2. Remove the descriptor from the descriptors queue.
        invoke  usbhc_api.usb_unlink_td
; 3. Get number of bytes that remain to be transferred.
; If CurBufPtr is zero, everything was transferred.
        xor     edx, edx
        cmp     [ebx+ohci_gtd.CurBufPtr-sizeof.ohci_gtd], edx
        jz      .gotlen
; Otherwise, the remaining length is
; (BufEnd and 0xFFF) - (CurBufPtr and 0xFFF) + 1,
; plus 0x1000 if BufEnd and CurBufPtr are in different pages.
        mov     edx, [ebx+ohci_gtd.BufEnd-sizeof.ohci_gtd]
        mov     eax, [ebx+ohci_gtd.CurBufPtr-sizeof.ohci_gtd]
        mov     ecx, edx
        and     edx, 0xFFF
        inc     edx
        xor     ecx, eax
        and     ecx, -0x1000
        jz      @f
        add     edx, 0x1000
@@:
        and     eax, 0xFFF
        sub     edx, eax
.gotlen:
; The actual length is Length - (remaining length).
        sub     edx, [ebx+usb_gtd.Length]
        neg     edx
; 4. Check for error. If so, go to 7.
        push    ebx
        mov     ecx, [ebx+ohci_gtd.Flags-sizeof.ohci_gtd]
        shr     ecx, 28
        jnz     .error
.notify:
; 5. Successful completion.
        invoke  usbhc_api.usb_process_gtd
.next_td:
; 6. Free the current descriptor and advance to the next item.
; If the current item is the last in the list,
; set DoneListEndPtr to pointer to DoneList.
        cmp     ebx, [esp]
        jz      @f
        stdcall ohci_free_gtd, ebx
@@:
        pop     ebx
        lea     eax, [ebx+ohci_gtd.NextTD-sizeof.ohci_gtd]
.next_td2:
        push    ebx
        mov     ebx, eax
        lea     edx, [esi+ohci_controller.DoneList-sizeof.ohci_controller]
        xor     ecx, ecx        ; no next item
        lock cmpxchg [esi+ohci_controller.DoneListEndPtr-sizeof.ohci_controller], edx
        jz      .last
; The current item is not the last.
; It is possible, although very rare, that ohci_irq has already advanced
; DoneListEndPtr, but not yet written NextTD. Wait until NextTD is nonzero.
@@:
        mov     ecx, [ebx]
        test    ecx, ecx
        jz      @b
.last:
        pop     ebx
; ecx = the next item
        push    ecx
; Free the current item, set ebx to the next item, continue to 5a.
        test    ebx, ebx
        jz      @f
        stdcall ohci_free_gtd, ebx
@@:
        pop     ebx
        ret
.error:
; 7. There was an error while processing this descriptor.
; The hardware has stopped processing the queue.
; 7a. Save status and length.
        push    ecx
        push    edx
;       DEBUGF 1,'K : TD failed:\n'
;       DEBUGF 1,'K : %x %x %x %x\n',[ebx-sizeof.ohci_gtd],[ebx-sizeof.ohci_gtd+4],[ebx-sizeof.ohci_gtd+8],[ebx-sizeof.ohci_gtd+12]
;       DEBUGF 1,'K : %x %x %x %x\n',[ebx-sizeof.ohci_gtd+16],[ebx-sizeof.ohci_gtd+20],[ebx-sizeof.ohci_gtd+24],[ebx-sizeof.ohci_gtd+28]
;       mov     eax, [ebx+usb_gtd.Pipe]
;       DEBUGF 1,'K : pipe: %x %x %x %x\n',[eax-sizeof.ohci_pipe],[eax-sizeof.ohci_pipe+4],[eax-sizeof.ohci_pipe+8],[eax-sizeof.ohci_pipe+12]
; 7b. Traverse the list of descriptors looking for the final packet
; for this transfer.
; Free and unlink non-final descriptors, except the current one.
; Final descriptor will be freed in step 6.
        invoke  usbhc_api.usb_is_final_packet
        jnc     .found_final
        mov     ebx, [ebx+usb_gtd.NextVirt]
virtual at esp
.length         dd      ?
.error_code     dd      ?
.current_item   dd      ?
end virtual
.look_final:
        invoke  usbhc_api.usb_unlink_td
        invoke  usbhc_api.usb_is_final_packet
        jnc     .found_final
        push    [ebx+usb_gtd.NextVirt]
        stdcall ohci_free_gtd, ebx
        pop     ebx
        jmp     .look_final
.found_final:
; 7c. If error code is USB_STATUS_UNDERRUN and the last TD allows short packets,
; it is not an error.
; Note: all TDs except the last one in any transfer stage are marked
; as short-packet-is-error to stop controller from further processing
; of that stage; we need to restart processing from a TD following the last.
; After that, go to step 5 with eax = 0 (no error).
        cmp     dword [.error_code], USB_STATUS_UNDERRUN
        jnz     .no_underrun
        test    byte [ebx+ohci_gtd.Flags+2-sizeof.ohci_gtd], 1 shl (18-16)
        jz      .no_underrun
        and     dword [.error_code], 0
        mov     ecx, [ebx+usb_gtd.Pipe]
        mov     edx, [ecx+ohci_pipe.HeadP-sizeof.ohci_pipe]
        and     edx, 2
.advance_queue:
        mov     eax, [ebx+usb_gtd.NextVirt]
        sub     eax, sizeof.ohci_gtd
        invoke  GetPhysAddr
        or      eax, edx
        mov     [ecx+ohci_pipe.HeadP-sizeof.ohci_pipe], eax
        push    ebx
        mov     ebx, ecx
        call    ohci_notify_new_work
        pop     ebx
        pop     edx ecx
        jmp     .notify
; 7d. Abort the entire transfer.
; There are two cases: either there is only one transfer stage
; (everything except control transfers), then ebx points to the last TD and
; all previous TD were unlinked and dismissed (if possible),
; or there are several stages (a control transfer) and ebx points to the last
; TD of Data or Status stage (usb_is_final_packet does not stop in Setup stage,
; because Setup stage can not produce short packets); for Data stage, we need
; to unlink and free (if possible) one more TD and advance ebx to the next one.
.no_underrun:
        cmp     [ebx+usb_gtd.Callback], 0
        jnz     .halted
        cmp     ebx, [.current_item]
        push    [ebx+usb_gtd.NextVirt]
        jz      @f
        stdcall ohci_free_gtd, ebx
@@:
        pop     ebx
        invoke  usbhc_api.usb_unlink_td
.halted:
; 7e. For bulk/interrupt transfers we have no choice but halt the queue,
; the driver should intercede (through some API which is not written yet).
; Control pipes normally recover at the next SETUP transaction (first stage
; of any control transfer), so we hope on the best and just advance the queue
; to the next transfer. (According to the standard, "A control pipe may also
; support functional stall as well, but this is not recommended.").
; Advance the transfer queue to the next descriptor.
        mov     ecx, [ebx+usb_gtd.Pipe]
        mov     edx, [ecx+ohci_pipe.HeadP-sizeof.ohci_pipe]
        and     edx, 2  ; keep toggleCarry bit
        cmp     [ecx+usb_pipe.Type], CONTROL_PIPE
        jz      @f
        inc     edx     ; set Halted bit
@@:
        jmp     .advance_queue
endp

; This procedure is called when a pipe is closing (either due to API call
; or due to disconnect); it unlinks the pipe from the corresponding list.
; esi -> usb_controller, ebx -> usb_pipe
proc ohci_unlink_pipe
        cmp     [ebx+usb_pipe.Type], INTERRUPT_PIPE
        jnz     @f
        mov     eax, [ebx+ohci_pipe.Flags-sizeof.ohci_pipe]
        bt      eax, 13
        setc    cl
        bt      eax, 12
        setc    ch
        shr     eax, 16
        stdcall usb1_interrupt_list_unlink, eax, ecx
@@:
        ret
endp

; This procedure temporarily removes the given pipe from hardware queue,
; keeping it in software lists.
; esi -> usb_controller, ebx -> usb_pipe
proc ohci_disable_pipe
        mov     eax, [ebx+ohci_pipe.NextED-sizeof.ohci_pipe]
        mov     edx, [ebx+usb_pipe.PrevVirt]
        mov     [edx+ohci_pipe.NextED-sizeof.ohci_pipe], eax
        ret
endp

; This procedure reinserts the given pipe from hardware queue
; after ehci_disable_pipe, with clearing transfer queue.
; esi -> usb_controller, ebx -> usb_pipe
; edx -> current descriptor, eax -> new last descriptor
proc ohci_enable_pipe
        sub     eax, sizeof.ohci_gtd
        invoke  GetPhysAddr
        mov     edx, [ebx+ohci_pipe.HeadP-sizeof.ohci_pipe]
        and     edx, 2
        or      eax, edx
        mov     [ebx+ohci_pipe.HeadP-sizeof.ohci_pipe], eax
        lea     eax, [ebx-sizeof.ohci_pipe]
        invoke  GetPhysAddr
        mov     edx, [ebx+usb_pipe.PrevVirt]
        mov     ecx, [edx+ohci_pipe.NextED-sizeof.ohci_pipe]
        mov     [ebx+ohci_pipe.NextED-sizeof.ohci_pipe], ecx
        mov     [edx+ohci_pipe.NextED-sizeof.ohci_pipe], eax
        ret
endp

; Allocates one endpoint structure for OHCI.
; Returns pointer to software part (usb_pipe) in eax.
proc ohci_alloc_pipe
        push    ebx
        mov     ebx, ohci_ep_mutex
        invoke  usbhc_api.usb_allocate_common, (sizeof.ohci_pipe + sizeof.usb_pipe + 0Fh) and not 0Fh
        test    eax, eax
        jz      @f
        add     eax, sizeof.ohci_pipe
@@:
        pop     ebx
        ret
endp

; Free one endpoint structure for OHCI.
; Stdcall with one argument, pointer to software part (usb_pipe).
proc ohci_free_pipe
        sub     dword [esp+4], sizeof.ohci_pipe
        jmp     [usbhc_api.usb_free_common]
endp

; Allocates one general transfer descriptor structure for OHCI.
; Returns pointer to software part (usb_gtd) in eax.
proc ohci_alloc_gtd
        push    ebx
        mov     ebx, ohci_gtd_mutex
        invoke  usbhc_api.usb_allocate_common, (sizeof.ohci_gtd + sizeof.usb_gtd + 0Fh) and not 0Fh
        test    eax, eax
        jz      @f
        add     eax, sizeof.ohci_gtd
@@:
        pop     ebx
        ret
endp

; Free one general transfer descriptor structure for OHCI.
; Stdcall with one argument, pointer to software part (usb_gtd).
proc ohci_free_gtd
        sub     dword [esp+4], sizeof.ohci_gtd
        jmp     [usbhc_api.usb_free_common]
endp

include 'usb1_scheduler.inc'
define_controller_name ohci

section '.data' readable writable
include '../peimport.inc'
include_debug_strings
IncludeIGlobals
IncludeUGlobals
align 4
usbhc_api usbhc_func
ohci_ep_first_page      dd      ?
ohci_ep_mutex           MUTEX
ohci_gtd_first_page     dd      ?
ohci_gtd_mutex          MUTEX
