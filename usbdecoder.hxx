#ifndef USBDECODER_HXX
#define USBDECODER_HXX

#include <QMainWindow>
#include <QTcpSocket>
#include <QThread>
#include <QFile>
#include <stdint.h>

namespace Ui {
class MainWindow;
}

enum
{
	USB_LOG_TCP_PORT	= 5555,
};

class USBLogDecoder : public QObject
{
	Q_OBJECT

	enum
	{
		OhciRevisionReg_log_prefix_read			=	0x21,
		OhciRevisionReg_log_prefix_write		=	0x22,
		OhciControlReg_log_prefix_read			=	0x23,
		OhciControlReg_log_prefix_write			=	0x24,
		OhciCommandStatusReg_log_prefix_read		=	0x25,
		OhciCommandStatusReg_log_prefix_write		=	0x26,
		OhciInterruptStatusReg_log_prefix_read		=	0x27,
		OhciInterruptStatusReg_log_prefix_write		=	0x28,
		OhciInterruptEnableReg_log_prefix_read		=	0x29,
		OhciInterruptEnableReg_log_prefix_write		=	0x2a,
		OhciInterruptDisableReg_log_prefix_read		=	0x2b,
		OhciInterruptDisableReg_log_prefix_write	=	0x2c,
		OhciHCCAReg_log_prefix_read			=	0x2d,
		OhciHCCAReg_log_prefix_write			=	0x2e,
		OhciPeriodCurrentEDReg_log_prefix_read		=	0x2f,
		OhciPeriodCurrentEDReg_log_prefix_write		=	0x30,
		OhciControlHeadEDReg_log_prefix_read		=	0x31,
		OhciControlHeadEDReg_log_prefix_write		=	0x32,
		OhciControlCurrentEDReg_log_prefix_read		=	0x33,
		OhciControlCurrentEDReg_log_prefix_write	=	0x34,
		OhciBulkHeadEDReg_log_prefix_read		=	0x35,
		OhciBulkHeadEDReg_log_prefix_write		=	0x36,
		OhciBulkCurrentEDReg_log_prefix_read		=	0x37,
		OhciBulkCurrentEDReg_log_prefix_write		=	0x38,
		OhciDoneHeadReg_log_prefix_read			=	0x39,
		OhciDoneHeadReg_log_prefix_write		=	0x3a,
		OhciFmIntervalReg_log_prefix_read		=	0x3b,
		OhciFmIntervalReg_log_prefix_write		=	0x3c,
		OhciFmRemainingReg_log_prefix_read		=	0x3d,
		OhciFmRemainingReg_log_prefix_write		=	0x3e,
		OhciFmNumberReg_log_prefix_read			=	0x3f,
		OhciFmNumberReg_log_prefix_write		=	0x40,
		OhciPeriodicStartReg_log_prefix_read		=	0x41,
		OhciPeriodicStartReg_log_prefix_write		=	0x42,
		OhciLSThresholdReg_log_prefix_read		=	0x43,
		OhciLSThresholdReg_log_prefix_write		=	0x44,
		OhciRhDescriptorAReg_log_prefix_read		=	0x45,
		OhciRhDescriptorAReg_log_prefix_write		=	0x46,
		OhciRhDescriptorBReg_log_prefix_read		=	0x47,
		OhciRhDescriptorBReg_log_prefix_write		=	0x48,
		OhciRhStatusReg_log_prefix_read			=	0x49,
		OhciRhStatusReg_log_prefix_write		=	0x4a,
		OhciRhPortStatusReg_log_prefix_read		=	0x4b,
		OhciRhPortStatusReg_log_prefix_write		=	0x4c,

		TRANSFER_DESCRIPTOR_READY_LOG_PREFIX		=	0x80,
		INTERRUPT_ENTRY_LOG_PREFIX			=	0x81,
		INTERRUPT_EXIT_LOG_PREFIX			=	0x82,
		INTERRUPT_TRANSFER_DONE_LOG_PREFIX		=	0x83,
		INTERRUPT_START_OF_FRAME_LOG_PREFIX		=	0x84,
		INTERRUPT_ROOT_HUB_EVENT_PREFIX			=	0x85,
		HCCA_CONTENTS_LOG_PREFIX			=	0x86,
		OHCI_INIT_START_LOG_PREFIX			=	0x87,
		OHCI_INIT_END_LOG_PREFIX			=	0x88,
	};

	/*
	 *
	 * register access decoding routines
	 *
	 */
	static QString OhciRhPortStatusReg_access(unsigned prefix_byte)
	{
		auto index = getByte();
		auto x = getU32();

		QString fc = QString("ohci HcRhPortStatus %1 cells + + ").arg(index);
		if (prefix_byte & 1) fc += "@ "; else fc = QString("$%1 ").arg(x, 8, 16, QChar('0')) + fc + "! ";
		fc += "\t\t\\ ";

		QString s(QString("$%1: ").arg(x, 8, 16, QChar('0')));
		/*
		s += "CCS (current connection status): "; if (x & (1 << 0)) s += "1; "; else s += "0; ";
		s += "PES (port enable status): "; if (x & (1 << 1)) s += "1; "; else s += "0; ";
		s += "PSS (port suspend status): "; if (x & (1 << 2)) s += "1; "; else s += "0; ";
		s += "POCI (port overcurrent indication): "; if (x & (1 << 3)) s += "1; "; else s += "0; ";
		s += "PRS (port reset status): "; if (x & (1 << 4)) s += "1; "; else s += "0; ";
		s += "PPS (port power status): "; if (x & (1 << 8)) s += "1; "; else s += "0; ";
		s += "LSDA (low speed device attached): "; if (x & (1 << 9)) s += "1; "; else s += "0; ";
		s += "CSC (connection status change): "; if (x & (1 << 16)) s += "1; "; else s += "0; ";
		s += "PESC (port enable status change): "; if (x & (1 << 17)) s += "1; "; else s += "0; ";
		s += "PSSC (port suspend status change): "; if (x & (1 << 18)) s += "1; "; else s += "0; ";
		s += "OCIC (overcurrent indication status change): "; if (x & (1 << 19)) s += "1; "; else s += "0; ";
		s += "PRSC (port reset status change): "; if (x & (1 << 20)) s += "1; "; else s += "0; ";
		*/
		s += "CCS: "; if (x & (1 << 0)) s += "1; "; else s += "0; ";
		s += "PES: "; if (x & (1 << 1)) s += "1; "; else s += "0; ";
		s += "PSS: "; if (x & (1 << 2)) s += "1; "; else s += "0; ";
		s += "POCI: "; if (x & (1 << 3)) s += "1; "; else s += "0; ";
		s += "PRS: "; if (x & (1 << 4)) s += "1; "; else s += "0; ";
		s += "PPS: "; if (x & (1 << 8)) s += "1; "; else s += "0; ";
		s += "LSDA: "; if (x & (1 << 9)) s += "1; "; else s += "0; ";
		s += "CSC: "; if (x & (1 << 16)) s += "1; "; else s += "0; ";
		s += "PESC: "; if (x & (1 << 17)) s += "1; "; else s += "0; ";
		s += "PSSC: "; if (x & (1 << 18)) s += "1; "; else s += "0; ";
		s += "OCIC: "; if (x & (1 << 19)) s += "1; "; else s += "0; ";
		s += "PRSC: "; if (x & (1 << 20)) s += "1; "; else s += "0; ";
		return fc + QString("Root hub port status access, index %1: ").arg(index) + ((prefix_byte & 1) ? "read " : "write ") + ": " + s;
	}

	static QString log_irq_entry(unsigned) { return "IRQ entry"; }
	static QString log_interrupt_transfer_done(unsigned) { return "interrupt transfer done"; }
	static QString log_root_hub_interrupt(unsigned) { return "root hub interrupt"; }
	static QString log_reg_access_OhciInterruptDisableReg(unsigned prefix_byte)
	{
		uint32_t x = getU32();

		QString fc = QString("ohci %1 + ").arg("HcInterruptDisable");
		if (prefix_byte & 1) fc += "@ "; else fc = QString("$%1 ").arg(x, 8, 16, QChar('0')) + fc + "! ";
		fc += "\t\t\\ ";

		QString s(QString("$%1: ").arg(x, 8, 16, QChar('0')));
		if (x & (1 << 0)) s += "SO - disable scheduling overrun interrupt; ";
		if (x & (1 << 1)) s += "WDH - disable DoneHead Writeback interrupt; ";
		if (x & (1 << 2)) s += "SF - disable start of frame interrupt; ";
		if (x & (1 << 3)) s += "RD - disable resume detect interrupt; ";
		if (x & (1 << 4)) s += "UE - disable unrecoverable error interrupt; ";
		if (x & (1 << 5)) s += "FNO - disable frame number overflow interrupt; ";
		if (x & (1 << 6)) s += "RHSC - disable root hub status change interrupt; ";
		if (x & (1 << 30)) s += "OC - disable ownership change interrupt; ";
		if (x & (1 << 31)) s += "MIE - MASTER INTERRUPT DISABLE; ";
		return fc + QString("HcInterruptDisable: ") + ((prefix_byte & 1) ? "read " : "write ") + ": " + s;
	}
	static QString log_reg_access_OhciControlReg(unsigned prefix_byte)
	{
		uint32_t x = getU32();
		QString s(QString("$%1: ").arg(x, 8, 16, QChar('0')));

		QString fc = QString("ohci %1 + ").arg("HcControl");
		if (prefix_byte & 1) fc += "@ "; else fc = QString("$%1 ").arg(x, 8, 16, QChar('0')) + fc + "! ";
		fc += "\t\t\\ ";

		s += QString("CBSR (control-to-bulk service ration): %1; ").arg(x & 3);
		s += "PLE: "; if (x & (1 << 2)) s += "periodic list enabled; "; else s += "periodic list disabled; ";
		s += "IE: "; if (x & (1 << 3)) s += "isochronous enable; "; else s += "isochronous disabled; ";
		s += "CLE: "; if (x & (1 << 4)) s += "control list enabled; "; else s += "control list disabled; ";
		s += "BLE: "; if (x & (1 << 5)) s += "bulk list enabled; "; else s += "bulk list disabled; ";
		s += "HCFS (host controller functional state): ";
		switch ((x >> 6) & 3)
		{
			case 0: s += "USBReset; "; break;
			case 1: s += "USBResume; "; break;
			case 2: s += "USBOperational; "; break;
			case 3: s += "USBSuspend; "; break;
		}
		s += "IR (interrupt routing): "; if (x & (1 << 8)) s += "SMM; "; else s += "none; ";
		s += "RWC (remote wakeup connected): "; if (x & (1 << 9)) s += "yes; "; else s += "no; ";
		s += "RWE (remote wakeup enable): "; if (x & (1 << 10)) s += "yes; "; else s += "no; ";
		return fc + QString("HcControl: ") + ((prefix_byte & 1) ? "read " : "write ") + ": " + s;
	}
	static QString log_reg_access_OhciCommandStatusReg(unsigned prefix_byte)
	{
		uint32_t x = getU32();
		QString s(QString("$%1: ").arg(x, 8, 16, QChar('0')));

		QString fc = QString("ohci %1 + ").arg("HcCommandStatus");
		if (prefix_byte & 1) fc += "@ "; else fc = QString("$%1 ").arg(x, 8, 16, QChar('0')) + fc + "! ";
		fc += "\t\t\\ ";

		s += "HCR (host controller reset): "; if (x & (1 << 0)) s += "RESET ON; "; else s += "0; ";
		s += "CLF (control list filled): "; if (x & (1 << 1)) s += "yes; "; else s += "no; ";
		s += "BLF (bulk list filled): "; if (x & (1 << 2)) s += "yes; "; else s += "no; ";
		s += "OCR (ownership change request): "; if (x & (1 << 3)) s += "yes; "; else s += "no; ";
		s += QString("SOC (scheduling overrun count): %1; ").arg((x >> 16) & 3);

		return fc + QString("HcCommandStatus: ") + ((prefix_byte & 1) ? "read " : "write ") + ": " + s;
	}

	static QString log_reg_access_OhciFmIntervalReg(unsigned prefix_byte)
	{
		uint32_t x = getU32();

		QString fc = QString("ohci %1 + ").arg("HcFmInterval");
		if (prefix_byte & 1) fc += "@ "; else fc = QString("$%1 ").arg(x, 8, 16, QChar('0')) + fc + "! ";
		fc += "\t\t\\ ";

		QString s(QString("$%1: ").arg(x, 8, 16, QChar('0')));
		s += QString("FI (frame interval): %1; ").arg(x & ((1 << 14) - 1));
		s += QString("FSMPS (largest data packet - bits): %1; ").arg((x >> 16) & ((1 << 15) - 1));
		s += "FIT (frame interval toggle): "; if (x & (1 << 31)) s += "1; "; else s += "0; ";
		return fc + QString("HcFmInterval: ") + ((prefix_byte & 1) ? "read " : "write ") + ": " + s;
	}
	static QString log_reg_access_OhciPeriodicStartReg(unsigned prefix_byte)
	{
		uint32_t x = getU32();

		QString fc = QString("ohci %1 + ").arg("HcPeriodicStart");
		if (prefix_byte & 1) fc += "@ "; else fc = QString("$%1 ").arg(x, 8, 16, QChar('0')) + fc + "! ";
		fc += "\t\t\\ ";

		QString s(QString("$%1: ").arg(x, 8, 16, QChar('0')));
		s += QString("PS (periodic start): %1; ").arg(x & ((1 << 14) - 1));
		return fc + QString("HcPeriodicStart: ") + ((prefix_byte & 1) ? "read " : "write ") + ": " + s;
	}
	static QString log_reg_access_OhciControlHeadEDReg(unsigned prefix_byte)
	{
		uint32_t x = getU32();

		QString fc = QString("ohci %1 + ").arg("HcControlHeadED");
		if (prefix_byte & 1) fc += "@ "; else fc = QString("$%1 ").arg(x, 8, 16, QChar('0')) + fc + "! ";
		fc += "\t\t\\ ";

		QString s(QString("$%1: ").arg(x, 8, 16, QChar('0')));
		return fc + QString("HcControlHeadED: ") + ((prefix_byte & 1) ? "read " : "write ") + ": " + s;
	}
	static QString log_reg_access_OhciControlCurrentEDReg(unsigned prefix_byte)
	{
		uint32_t x = getU32();

		QString fc = QString("ohci %1 + ").arg("HcControlCurrentED");
		if (prefix_byte & 1) fc += "@ "; else fc = QString("$%1 ").arg(x, 8, 16, QChar('0')) + fc + "! ";
		fc += "\t\t\\ ";

		QString s(QString("$%1: ").arg(x, 8, 16, QChar('0')));
		return fc + QString("HcControlCurrentED: ") + ((prefix_byte & 1) ? "read " : "write ") + ": " + s;
	}
	static QString log_reg_access_OhciBulkHeadEDReg(unsigned prefix_byte)
	{
		uint32_t x = getU32();

		QString fc = QString("ohci %1 + ").arg("HcBulkHeadED");
		if (prefix_byte & 1) fc += "@ "; else fc = QString("$%1 ").arg(x, 8, 16, QChar('0')) + fc + "! ";
		fc += "\t\t\\ ";

		QString s(QString("$%1: ").arg(x, 8, 16, QChar('0')));
		return fc + QString("HcBulkHeadED: ") + ((prefix_byte & 1) ? "read " : "write ") + ": " + s;
	}
	static QString log_reg_access_OhciBulkCurrentEDReg(unsigned prefix_byte)
	{
		uint32_t x = getU32();

		QString fc = QString("ohci %1 + ").arg("HcBulkCurrentED");
		if (prefix_byte & 1) fc += "@ "; else fc = QString("$%1 ").arg(x, 8, 16, QChar('0')) + fc + "! ";
		fc += "\t\t\\ ";

		QString s(QString("$%1: ").arg(x, 8, 16, QChar('0')));
		return fc + QString("HcBulkCurrentED: ") + ((prefix_byte & 1) ? "read " : "write ") + ": " + s;
	}
	static QString log_reg_access_OhciDoneHeadEDReg(unsigned prefix_byte)
	{
		uint32_t x = getU32();

		QString fc = QString("ohci %1 + ").arg("HcDoneHead");
		if (prefix_byte & 1) fc += "@ "; else fc = QString("$%1 ").arg(x, 8, 16, QChar('0')) + fc + "! ";
		fc += "\t\t\\ ";

		QString s(QString("$%1: ").arg(x, 8, 16, QChar('0')));
		return fc + QString("HcDoneHeadED: ") + ((prefix_byte & 1) ? "read " : "write ") + ": " + s;
	}
	static QString log_reg_access_OhciHCCAReg(unsigned prefix_byte)
	{
		uint32_t x = getU32();

		QString fc = QString("ohci %1 + ").arg("HcHCCA");
		if (prefix_byte & 1) fc += "@ "; else fc = QString("$%1 ").arg(x, 8, 16, QChar('0')) + fc + "! ";
		fc += "\t\t\\ ";

		QString s(QString("$%1: ").arg(x, 8, 16, QChar('0')));
		return fc + QString("HCCA: ") + ((prefix_byte & 1) ? "read " : "write ") + ": " + s;
	}
	static QString log_reg_access_OhciRhDescriptorAReg(unsigned prefix_byte)
	{
		uint32_t x = getU32();

		QString fc = QString("ohci %1 + ").arg("HcRhDescriptorA");
		if (prefix_byte & 1) fc += "@ "; else fc = QString("$%1 ").arg(x, 8, 16, QChar('0')) + fc + "! ";
		fc += "\t\t\\ ";

		QString s(QString("$%1: ").arg(x, 8, 16, QChar('0')));
		s += QString("NDP (number of downstream ports): %1; ").arg((x >> 0) & ((1 << 8) - 1));
		s += "PSM (power switching mode): "; if (x & (1 << 9)) s += "each port - individually; "; else s += "all ports - together; ";
		s += "NPS (no power switching): "; if (x & (1 << 9)) s += "ports are always powered when the HC is ON; "; else s += "ports are power switched; ";
		s += "DT (device type): "; if (x & (1 << 10)) s += "INVALID; "; else s += "hardwired to 0; ";
		s += "OCPM (overcurrent protection mode): "; if (x & (1 << 11)) s += "reported on a per-port basis; "; else s += "reported collectively; ";
		s += "NOCP (no overcurrent protection): "; if (x & (1 << 11)) s += "1; "; else s += "0; ";
		s += QString("POTPGT (power-on-to-power-good time; unit is *2 ms): %1; ").arg((x >> 24) & ((1 << 8) - 1));

		return fc + QString("HcRhDescriptorA: ") + ((prefix_byte & 1) ? "read " : "write ") + ": " + s;
	}
	static QString log_reg_access_OhciInterruptEnableReg(unsigned prefix_byte)
	{
		uint32_t x = getU32();

		QString fc = QString("ohci %1 + ").arg("HcInterruptEnable");
		if (prefix_byte & 1) fc += "@ "; else fc = QString("$%1 ").arg(x, 8, 16, QChar('0')) + fc + "! ";
		fc += "\t\t\\ ";

		QString s(QString("$%1: ").arg(x, 8, 16, QChar('0')));
		s += "SO (scheduling overrun): "; if (x & (1 << 0)) s += "ENABLE; "; else s += "no change; ";
		s += "WDH (HCDoneHead writeback): "; if (x & (1 << 1)) s += "ENABLE; "; else s += "no change; ";
		s += "SF (start of frame): "; if (x & (1 << 2)) s += "ENABLE; "; else s += "no change; ";
		s += "RD (resume detect): "; if (x & (1 << 3)) s += "ENABLE; "; else s += "no change; ";
		s += "UE (unrecoverable error): "; if (x & (1 << 4)) s += "ENABLE; "; else s += "no change; ";
		s += "FNO (frame number overflow): "; if (x & (1 << 5)) s += "ENABLE; "; else s += "no change; ";
		s += "RHSC (root hub status change): "; if (x & (1 << 6)) s += "ENABLE; "; else s += "no change; ";
		s += "OC (ownership change): "; if (x & (1 << 30)) s += "ENABLE; "; else s += "no change; ";
		s += "MIE (master interrupt enable): "; if (x & (1 << 31)) s += "ENABLE; "; else s += "no change; ";

		return fc + QString("HcInterruptEnable: ") + ((prefix_byte & 1) ? "read " : "write ") + ": " + s;
	}

	static QString log_reg_access_OhciRhStatusReg(unsigned prefix_byte)
	{
		uint32_t x = getU32();

		QString fc = QString("ohci %1 + ").arg("HcRhStatus");
		if (prefix_byte & 1) fc += "@ "; else fc = QString("$%1 ").arg(x, 8, 16, QChar('0')) + fc + "! ";
		fc += "\t\t\\ ";

		QString s(QString("$%1: ").arg(x, 8, 16, QChar('0')));
		s += "LPS (local power status): "; if (x & (1 << 0)) s += "1; "; else s += "0; ";
		s += "OCI (overcurrent indicator): "; if (x & (1 << 1)) s += "1; "; else s += "0; ";
		s += "DRWE (device remote wakeup enable): "; if (x & (1 << 15)) s += "1; "; else s += "0; ";
		s += "LPSC (local power status change): "; if (x & (1 << 16)) s += "1; "; else s += "0; ";
		s += "OCIC (overcurrent indicator change): "; if (x & (1 << 17)) s += "1; "; else s += "0; ";
		s += "CRWE (clear remote wakeup enable): "; if (x & (1 << 31)) s += "1; "; else s += "0; ";
		return fc + QString("HcRhStatus (see manual): ") + ((prefix_byte & 1) ? "read " : "write ") + ": " + s;
	}

	static QString log_reg_access_OhciInterruptStatusReg(unsigned prefix_byte)
	{
		uint32_t x = getU32();

		QString fc = QString("ohci %1 + ").arg("HcInterruptStatus");
		if (prefix_byte & 1) fc += "@ "; else fc = QString("$%1 ").arg(x, 8, 16, QChar('0')) + fc + "! ";
		fc += "\t\t\\ ";

		QString s(QString("$%1: ").arg(x, 8, 16, QChar('0')));
		s += "SO (scheduling overrun): "; if (x & (1 << 0)) s += "1; "; else s += "0; ";
		s += "WDH (HCDoneHead writeback): "; if (x & (1 << 1)) s += "1; "; else s += "0; ";
		s += "SF (start of frame): "; if (x & (1 << 2)) s += "1; "; else s += "0; ";
		s += "RD (resume detect): "; if (x & (1 << 3)) s += "1; "; else s += "0; ";
		s += "UE (unrecoverable error): "; if (x & (1 << 4)) s += "1; "; else s += "0; ";
		s += "FNO (frame number overflow): "; if (x & (1 << 5)) s += "1; "; else s += "0; ";
		s += "RHSC (root hub status change): "; if (x & (1 << 6)) s += "1; "; else s += "0; ";
		s += "OC (ownership change): "; if (x & (1 << 30)) s += "1; "; else s += "0; ";
		s += "MIE (master interrupt enable): "; if (x & (1 << 31)) s += "1; "; else s += "0; ";

		return fc + QString("HcInterruptStatus: ") + ((prefix_byte & 1) ? "read " : "write ") + ": " + s;
	}

	static QString log_reg_access_template(unsigned prefix_byte)
	{
		uint32_t x = getU32();
		QString s(QString("$%1: ").arg(x, 8, 16, QChar('0')));
		s += "FIELDNAME: "; if (x & (1 << 31)) s += "XXX; "; else s += "YYY; ";
		return QString("REGNAME: ") + ((prefix_byte & 1) ? "read " : "write ") + ": " + s;
	}

	static QString log_irq_exit(unsigned) { return "IRQ exit"; }
	static QString log_init_start(unsigned) { return "INIT start"; }
	static QString log_init_end(unsigned) { return "INIT end"; }

	static unsigned int getByte_socket(void) { uint8_t x; while (!s->bytesAvailable()) if (!s->waitForReadyRead(-1))
		{ qDebug() << "ERROR!!!"; return -1; }
if (s->read((char *) & x, 1) != 1) { qDebug() << "XXX"; return -1; } return x;
}

	static unsigned int getByte_captured_log(void)
	{
		char c;
		if (!f.isOpen())
			f.open(QFile::ReadOnly);
		if (f.read(& c, 1) != 1)
			return -1;
		return ((unsigned) c) & 0xff;
	}
	static unsigned int getByte(void) {
		if (!data.isEmpty())
			if (dataIndex >= data.size())
				return -1;
			else
				return data.at(dataIndex ++) & 0xff;
return
#if RUN_CAPTURED_LOG
getByte_captured_log();
#else
getByte_socket();
#endif
}

	static uint32_t getU32(void) { return getByte() | (getByte() << 8) | (getByte() << 16) | (getByte() << 24); }
	static QString dummy(unsigned prefix_byte) { return QString("UNKNOWN PACKET: %1").arg(prefix_byte, 2, 16, QChar('0')); }
	static QString dummy_register_io_packet(unsigned prefix_byte) { getU32(); return QString("register access: $%1").arg(prefix_byte, 2, 16, QChar('0')); }
	static QString dump_hcca(unsigned prefix_byte)
	{
		int i;
		for (i = 0; i < 256; getByte(), i ++);
		return QString("HCCA load");
	}
	static QString log_transfer_descriptor(unsigned prefix_byte)
{
	uint32_t td[4] = { getU32(), getU32(), getU32(), getU32(), };
	QString hwdesc("hardware descriptor fields: ");
	hwdesc += QString("flags: $%1; ").arg(td[0], 8, 16, QChar('0'));
	hwdesc += QString("CBP: $%1; ").arg(td[1], 8, 16, QChar('0'));
	hwdesc += QString("NextTD: $%1; ").arg(td[2], 8, 16, QChar('0'));
	hwdesc += QString("BE: $%1; ").arg(td[3], 8, 16, QChar('0'));
	int x = getU32(), i = x;
	QByteArray data;
	while (i --)
		data.append(getByte());
return QString("transfer descriptor ready:\n%1\n; #%2 bytes in transfer:\n").arg(hwdesc).arg(x) + data.toHex(); }
	static QString (*decoders[255])(unsigned prefix_byte);

public slots:
	void runDecoder(const QString & parameters);
	static QStringList decode(const QByteArray & logData);

signals:
	void outputReady(const QString & output);

public:
	USBLogDecoder(const QByteArray & logData) { data = logData, dataIndex = 0; }
	USBLogDecoder(void) {}
private:
	static QByteArray data;
	static int dataIndex;
	static QTcpSocket * s;
	static QFile f;
};

class MainWindow : public QMainWindow
{
	Q_OBJECT

public:
	explicit MainWindow(QWidget *parent = 0);
	~MainWindow();
signals:
	void runDecoder(const QString & parameters);
private slots:
	void readyReadUsbLogSocket(const QString & output);
private:
	QByteArray	usbLogData;
	QTcpSocket	s;
	QThread		decoder_thread;
	Ui::MainWindow	*ui;
};

#endif // USBDECODER_HXX
