#ifndef USBDECODER_HXX
#define USBDECODER_HXX

#include <QMainWindow>
#include <QTcpSocket>
#include <QThread>

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
		OhciRevisionReg_log_prefix_read         = 0x21,
		OhciRevisionReg_log_prefix_write         = 0x22,
		OhciControlReg_log_prefix_read          = 0x23,
		OhciControlReg_log_prefix_write          = 0x24,
		OhciCommandStatusReg_log_prefix_read    = 0x24,
		OhciCommandStatusReg_log_prefix_write    = 0x25,
		OhciInterruptStatusReg_log_prefix_read  = 0x25,
		OhciInterruptStatusReg_log_prefix_write  = 0x26,
		OhciInterruptEnableReg_log_prefix_read  = 0x26,
		OhciInterruptEnableReg_log_prefix_write  = 0x27,
		OhciInterruptDisableReg_log_prefix_read = 0x27,
		OhciInterruptDisableReg_log_prefix_write = 0x28,

		OhciHCCAReg_log_prefix_read             = 0x27,
		OhciHCCAReg_log_prefix_write             = 0x28,
		OhciPeriodCurrentEDReg_log_prefix_read  = 0x29,
		OhciPeriodCurrentEDReg_log_prefix_write  = 0x2a,
		OhciControlHeadEDReg_log_prefix_read    = 0x2a,
		OhciControlHeadEDReg_log_prefix_write    = 0x2b,
		OhciControlCurrentEDReg_log_prefix_read = 0x2b,
		OhciControlCurrentEDReg_log_prefix_write = 0x2c,
		OhciBulkHeadEDReg_log_prefix_read       = 0x2c,
		OhciBulkHeadEDReg_log_prefix_write       = 0x2d,
		OhciBulkCurrentEDReg_log_prefix_read    = 0x2d,
		OhciBulkCurrentEDReg_log_prefix_write    = 0x2e,
		OhciDoneHeadReg_log_prefix_read         = 0x2e,
		OhciDoneHeadReg_log_prefix_write         = 0x2f,

		OhciFmIntervalReg_log_prefix_read       = 0x2e,
		OhciFmIntervalReg_log_prefix_write       = 0x2f,
		OhciFmRemainingReg_log_prefix_read      = 0x30,
		OhciFmRemainingReg_log_prefix_write      = 0x31,
		OhciFmNumberReg_log_prefix_read         = 0x31,
		OhciFmNumberReg_log_prefix_write         = 0x32,
		OhciPeriodicStartReg_log_prefix_read    = 0x32,
		OhciPeriodicStartReg_log_prefix_write    = 0x33,
		OhciLSThresholdReg_log_prefix_read      = 0x33,
		OhciLSThresholdReg_log_prefix_write      = 0x34,

		OhciRhDescriptorAReg_log_prefix_read    = 0x33,
		OhciRhDescriptorAReg_log_prefix_write    = 0x34,
		OhciRhDescriptorBReg_log_prefix_read    = 0x35,
		OhciRhDescriptorBReg_log_prefix_write    = 0x36,
		OhciRhStatusReg_log_prefix_read         = 0x36,
		OhciRhStatusReg_log_prefix_write         = 0x37,
		OhciRhPortStatusReg_log_prefix_read     = 0x37,
		OhciRhPortStatusReg_log_prefix_write     = 0x38,

		TRANSFER_DESCRIPTOR_READY_LOG_PREFIX	= 0x80,
	};

	static QString dummy(QTcpSocket & s) {}
	static QString (*decoders[255])(QTcpSocket &);

public slots:
	void runDecoder(const QString & parameters);

signals:
	void outputReady(const QString & output);
private:
	QTcpSocket * s;
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
