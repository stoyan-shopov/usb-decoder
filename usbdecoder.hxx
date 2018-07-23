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

class USBLogDecoder : public QObject
{
	Q_OBJECT

	enum
	{
		USB_LOG_TCP_PORT	= 5555,
	};
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
	};

	static unsigned int getByte_socket(void) { uint8_t x; while (!s->bytesAvailable()) if (!s->waitForReadyRead(-1))
		{ qDebug() << "ERROR!!!"; return -1; }
if (s->read((char *) & x, 1) != 1) { qDebug() << "XXX"; return -1; } return x;
}

	static unsigned int getByte_captured_log(void)
	{
		char c;
		if (!f.isOpen())
			f.open(QFile::ReadOnly);
		if (!f.getChar(& c))
			return -1;
		return ((unsigned) c) & 0xff;
	}
	static unsigned int getByte(void) { return
#if RUN_CAPTURED_LOG
getByte_captured_log();
#else
getByte_socket();
#endif
}

	static uint32_t getU32(void) { return getByte() | (getByte() << 8) | (getByte() << 16) | (getByte() << 24); }
	static QString dummy(unsigned prefix_byte) { return QString("UNKNOWN PACKET: %1").arg(prefix_byte, 2, 16, QChar('0')); }
	static QString dummy_register_io_packet(unsigned prefix_byte) { getU32(); return QString("register access: %1").arg(prefix_byte, 2, 16, QChar('0')); }
	static QString log_transfer_descriptor(unsigned prefix_byte) { getU32(), getU32(), getU32(), getU32(); return QString("transfer descriptor ready"); }
	static QString (*decoders[255])(unsigned prefix_byte);

public slots:
	void runDecoder(const QString & parameters);

signals:
	void outputReady(const QString & output);
private:
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
	QThread decoder_thread;
	Ui::MainWindow *ui;
};

#endif // USBDECODER_HXX
