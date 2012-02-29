/**
 * arch/arm/plat-omap/include/plat/mux_t1_rev_r03.h
 *
 * Copyright (C) 2010-2011, Samsung Electronics, Co., Ltd. All Rights Reserved.
 *  Written by System S/W Group, Open OS S/W R&D Team,
 *  Mobile Communication Division.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 */

/**
 * Project Name : OMAP-Samsung Linux Kernel for Android
 *
 * Project Description :
 *
 * Comments : tabstop = 8, shiftwidth = 8, noexpandtab
 */

/**
 * File Name : mux_t1_rev_r03.h
 *
 * File Description :
 *
 * Author : System Platform 2
 * Dept : System S/W Group (Open OS S/W R&D Team)
 * Created : 07/Mar/2011
 * Version : Baby-Raccoon
 */

#ifndef __MUX_T1_H__
#define __MUX_T1_H__


#define OMAP_GPIO_PS_VOUT			33
#define OMAP_GPIO_CP_USB_ON         34
#define OMAP_GPIO_MLCD_RST			35
#define OMAP_GPIO_PS_ON				37
#define OMAP_GPIO_LCD_EN			40
#define OMAP_GPIO_MPU3050_INT			45
#define OMAP_GPIO_UART_SEL          47
#define OMAP_GPIO_ACC_EN			59

#define OMAP_GPIO_WIFI_IRQ			61
#define OMAP_GPIO_WIFI_PMENA_GPIO		104
#define OMAP_GPIO_KXSD9_INT			122
#define OMAP_GPIO_AKM_INT			157
#define OMAP_GPIO_USB_OTG_ID		1
#define OMAP_GPIO_USB_OTG_EN         		171
#define OMAP_GPIO_USBSW_NINT			44
#define OMAP_GPIO_JIG_ON18			55


/* For Battery */
#define OMAP_GPIO_CHG_ING_N			11
#define OMAP_GPIO_TA_NCONNECTED	     		12
#define OMAP_GPIO_FUEL_ALERT            	44
#define OMAP_GPIO_FUEL_SCL              	61
#define OMAP_GPIO_FUEL_SDA              	62
#define OMAP_GPIO_CHG_EN			142
#define OMAP_GPIO_BAT_REMOVAL           	29   //GPIO_WK29

/* For MIPI HSI */
#define OMAP_GPIO_MIPI_HSI_CP_ON		36
#define OMAP_GPIO_MIPI_HSI_RESET_REQ_N		50
#define OMAP_GPIO_MIPI_HSI_PDA_ACTIVE		119
#define OMAP_GPIO_MIPI_HSI_PHONE_ACTIVE		120
#define OMAP_GPIO_MIPI_HSI_CP_RST		2	//wk2
#define OMAP_GPIO_MIPI_HSI_CP_DUMP_INT		56

#define OMAP_GPIO_JACK_NINT			121

/* For Audio */
#define OMAP_GPIO_MICBIAS_EN			48
#define OMAP_GPIO_EAR_MICBIAS_EN		49
#define OMAP_GPIO_EAR_SEND_END			4	
#define OMAP_GPIO_AUD_PWRON			127
#define OMAP_GPIO_SUB_MICBIAS_EN		177
#define OMAP_GPIO_DET_35			0	/* GPIO_WK0 */

#define OMAP_GPIO_FM_INT			40
#define OMAP_GPIO_FM_RST			42

/* For TSP */
#define OMAP_GPIO_TSP_EN			54
#define OMAP_GPIO_TSP_nINT			46

/* For touch key*/
#define OMAP_GPIO_TOUCH_INT			32
#define OMAP_GPIO_TOUCH_EN			101
#define OMAP_GPIO_TOUCH_LED_EN			102
#define OMAP_GPIO_AP_I2C_SCL			130
#define OMAP_GPIO_AP_I2C_SDA			131
#define OMAP_GPIO_3_TOUCH_SCL			139
#define OMAP_GPIO_3_TOUCH_SDA			140

/* For GPIO key */
#define OMAP_GPIO_KEY_PWRON			3
#define OMAP_GPIO_KEY_HOME			31
#define OMAP_GPIO_KEY_VOL_UP			30
#define OMAP_GPIO_KEY_VOL_DOWN			8

/*MHL Related GPIOs */
#ifdef CONFIG_VIDEO_MHL_V1
#define OMAP_GPIO_MHL_SEL          		53
#define OMAP_GPIO_MHL_RST           		60
#define OMAP_GPIO_MHL_WAKEUP    		64
#define OMAP_GPIO_MHL_SCL_18V   		99
#define OMAP_GPIO_MHL_SDA_18V   		98
#define OMAP_GPIO_MHL_INT          		175
#endif
#define OMAP_GPIO_HDMI_EN   			100


/* For GPS */
#define OMAP_GPIO_AP_AGPS_TSYNC			172
#define OMAP_GPIO_GPS_PWR_EN			173
#define OMAP_GPIO_GPS_nRST			178

/* For Vibetonz */
#define OMAP_GPIO_MOTOR_EN			95

/* For Bluetooth */
#define OMAP_GPIO_BT_nRST			82
#define OMAP_GPIO_BT_HOST_WAKE			83
#define OMAP_GPIO_BT_WAKE			93
#define OMAP_GPIO_BT_EN				103

/* For H/W Revision */
#define OMAP_GPIO_HW_REV0			76
#define OMAP_GPIO_HW_REV1			75
#define OMAP_GPIO_HW_REV2			74
#define OMAP_GPIO_HW_REV3			73

#endif /* __MUX_T1_H__ */

