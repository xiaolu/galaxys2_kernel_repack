/* linux/arch/arm/plat-s5p/include/plat/map-s5p.h
 *
 * Copyright (c) 2010 Samsung Electronics Co., Ltd.
 *		http://www.samsung.com/
 *
 * S5P - Memory map definitions
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
*/

#ifndef __ASM_PLAT_MAP_S5P_H
#define __ASM_PLAT_MAP_S5P_H __FILE__

#define S5P_VA_CHIPID		S3C_ADDR(0x00700000)
#define S5P_VA_GPIO		S3C_ADDR(0x00500000)
#define S5P_VA_GPIO2		S3C_ADDR(0x00510000)
#define S5P_VA_GPIO3		S3C_ADDR(0x00520000)
#define S5P_VA_SYSTIMER		S3C_ADDR(0x01200000)
#define S5P_VA_SROMC		S3C_ADDR(0x01100000)
#define S5P_VA_AUDSS		S3C_ADDR(0x01600000)

#ifdef CONFIG_S5PV310_FPGA
#define S5P_VA_TEMP		S3C_ADDR(0x01240000)
#endif
#define S5P_VA_SYSRAM		S3C_ADDR(0x01180000)
#define S5P_VA_RTC		S3C_ADDR(0x01700000)
#define S5P_VA_DMC0		S3C_ADDR(0x01800000)
#define S5P_VA_DMC1		S3C_ADDR(0x01900000)

#define S5P_VA_COMBINER_BASE	S3C_ADDR(0x00600000)
#define S5P_VA_COMBINER(x)	(S5P_VA_COMBINER_BASE + ((x) >> 2) * 0x10)
#define S5P_VA_EXTCOMBINER_BASE S3C_ADDR(0x02000000)
#define S5P_VA_EXTCOMBINER(x)	(S5P_VA_EXTCOMBINER_BASE + ((x) >> 2) * 0x10)


#define S5P_VA_COREPERI_BASE	S3C_ADDR(0x00800000)
#define S5P_VA_COREPERI(x)	(S5P_VA_COREPERI_BASE + (x))
#define S5P_VA_SCU		S5P_VA_COREPERI(0x0)
#define S5P_VA_GIC_CPU		S5P_VA_COREPERI(0x100)
#define S5P_VA_TWD		S5P_VA_COREPERI(0x600)
#define S5P_VA_GIC_DIST		S5P_VA_COREPERI(0x1000)

#define S5P_VA_EXTGIC_CPU	S3C_ADDR(0x02100000)
#define S5P_VA_EXTGIC_DIST	(S5P_VA_EXTGIC_CPU + 0x00100000)

#define S5P_VA_L2CC		S3C_ADDR(0x00900000)

#define S5P_VA_UART(x)		(S3C_VA_UART + ((x) * S3C_UART_OFFSET))
#define S5P_VA_UART0		S5P_VA_UART(0)
#define S5P_VA_UART1		S5P_VA_UART(1)
#define S5P_VA_UART2		S5P_VA_UART(2)
#define S5P_VA_UART3		S5P_VA_UART(3)
#define S5P_VA_UART4		S5P_VA_UART(4)
#define S5P_VA_UART5		S3C_VA_UART5

#ifndef S3C_UART_OFFSET
#define S3C_UART_OFFSET		(0x400)
#endif

#define VA_VIC(x)		(S3C_VA_IRQ + ((x) * 0x10000))
#define VA_VIC0			VA_VIC(0)
#define VA_VIC1			VA_VIC(1)
#define VA_VIC2			VA_VIC(2)
#define VA_VIC3			VA_VIC(3)

#define S5P_MMU_CTRL		(0x000)
#define S5P_MMU_CFG		(0x004)
#define S5P_MMU_STATUS		(0x008)
#define S5P_MMU_FLUSH		(0x00C)
#define S5P_MMU_FLUSH_ENTRY	(0x010)
#define S5P_PT_BASE_ADDR	(0x014)
#define S5P_INT_STATUS		(0x018)
#define S5P_INT_CLEAR		(0x01C)
#define S5P_INT_MASK		(0x020)
#define S5P_PAGE_FAULT_ADDR	(0x024)
#define S5P_AW_FAULT_ADDR	(0x028)
#define S5P_AR_FAULT_ADDR	(0x02C)
#define S5P_DEFAULT_SLAVE_ADDR	(0x030)
#define S5P_MMU_VERSION		(0x034)
#define S5P_TLB_READ            (0x038)
#define S5P_TLB_DATA            (0x03C)

#define S5P_PPC_PMNC            (0x800)
#define S5P_PPC_CNTENS          (0x810)
#define S5P_PPC_CNTENC          (0x820)
#define S5P_PPC_INTENS          (0x830)
#define S5P_PPC_INTENC          (0x840)
#define S5P_PPC_FLAG            (0x850)
#define S5P_PPC_CCNT            (0x900)
#define S5P_PPC_PMCNT0          (0x910)
#define S5P_PPC_PMCNT1          (0x920)
#define S5P_PPC_PMCNT2          (0x930)
#define S5P_PPC_PMCNT3          (0x940)

#endif /* __ASM_PLAT_MAP_S5P_H */
