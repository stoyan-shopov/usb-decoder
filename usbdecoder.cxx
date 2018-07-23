#include "usbdecoder.hxx"
#include "ui_usbdecoder.h"

MainWindow::MainWindow(QWidget *parent) :
	QMainWindow(parent),
	ui(new Ui::MainWindow)
{
	ui->setupUi(this);

	USBLogDecoder * decoder = new USBLogDecoder;
	decoder->moveToThread(& decoder_thread);
	connect(& decoder_thread, & QThread::finished, decoder, & QObject::deleteLater);
	connect(this, & MainWindow::runDecoder, decoder, & USBLogDecoder::runDecoder);
	connect(decoder, & USBLogDecoder::outputReady, this, & MainWindow::readyReadUsbLogSocket);
	decoder_thread.start();

	emit runDecoder("");

	connect(ui->pushButtonConnect, & QPushButton::clicked, [=] { });
	emit ui->pushButtonConnect->clicked();
}

MainWindow::~MainWindow()
{
	decoder_thread.terminate();
	decoder_thread.wait();
	delete ui;
}

void MainWindow::readyReadUsbLogSocket(const QString & output)
{
	ui->plainTextEdit->appendPlainText(output);
}

QString (*USBLogDecoder::decoders[255])(unsigned prefix_byte) =
{
		[0] = dummy,
		[1] = dummy,
		[2] = dummy,
		[3] = dummy,
		[4] = dummy,
		[5] = dummy,
		[6] = dummy,
		[7] = dummy,
		[8] = dummy,
		[9] = dummy,
		[10] = dummy,
		[11] = dummy,
		[12] = dummy,
		[13] = dummy,
		[14] = dummy,
		[15] = dummy,
		[16] = dummy,
		[17] = dummy,
		[18] = dummy,
		[19] = dummy,
		[20] = dummy,
		[21] = dummy,
		[22] = dummy,
		[23] = dummy,
		[24] = dummy,
		[25] = dummy,
		[26] = dummy,
		[27] = dummy,
		[28] = dummy,
		[29] = dummy,
		[30] = dummy,
		[31] = dummy,
		[32] = dummy,

		[OhciRevisionReg_log_prefix_read]		= dummy_register_io_packet,
		[OhciRevisionReg_log_prefix_write]		= dummy_register_io_packet,
		[OhciControlReg_log_prefix_read]		= dummy_register_io_packet,
		[OhciControlReg_log_prefix_write]		= dummy_register_io_packet,
		[OhciCommandStatusReg_log_prefix_read]		= dummy_register_io_packet,
		[OhciCommandStatusReg_log_prefix_write]		= dummy_register_io_packet,
		[OhciInterruptStatusReg_log_prefix_read]	= dummy_register_io_packet,
		[OhciInterruptStatusReg_log_prefix_write]	= dummy_register_io_packet,
		[OhciInterruptEnableReg_log_prefix_read]	= dummy_register_io_packet,
		[OhciInterruptEnableReg_log_prefix_write]	= dummy_register_io_packet,
		[OhciInterruptDisableReg_log_prefix_read]	= dummy_register_io_packet,
		[OhciInterruptDisableReg_log_prefix_write]	= dummy_register_io_packet,
		[OhciHCCAReg_log_prefix_read]			= dummy_register_io_packet,
		[OhciHCCAReg_log_prefix_write]			= dummy_register_io_packet,
		[OhciPeriodCurrentEDReg_log_prefix_read]	= dummy_register_io_packet,
		[OhciPeriodCurrentEDReg_log_prefix_write]	= dummy_register_io_packet,
		[OhciControlHeadEDReg_log_prefix_read]		= dummy_register_io_packet,
		[OhciControlHeadEDReg_log_prefix_write]		= dummy_register_io_packet,
		[OhciControlCurrentEDReg_log_prefix_read]	= dummy_register_io_packet,
		[OhciControlCurrentEDReg_log_prefix_write]	= dummy_register_io_packet,
		[OhciBulkHeadEDReg_log_prefix_read]		= dummy_register_io_packet,
		[OhciBulkHeadEDReg_log_prefix_write]		= dummy_register_io_packet,
		[OhciBulkCurrentEDReg_log_prefix_read]		= dummy_register_io_packet,
		[OhciBulkCurrentEDReg_log_prefix_write]		= dummy_register_io_packet,
		[OhciDoneHeadReg_log_prefix_read]		= dummy_register_io_packet,
		[OhciDoneHeadReg_log_prefix_write]		= dummy_register_io_packet,
		[OhciFmIntervalReg_log_prefix_read]		= dummy_register_io_packet,
		[OhciFmIntervalReg_log_prefix_write]		= dummy_register_io_packet,
		[OhciFmRemainingReg_log_prefix_read]		= dummy_register_io_packet,
		[OhciFmRemainingReg_log_prefix_write]		= dummy_register_io_packet,
		[OhciFmNumberReg_log_prefix_read]		= dummy_register_io_packet,
		[OhciFmNumberReg_log_prefix_write]		= dummy_register_io_packet,
		[OhciPeriodicStartReg_log_prefix_read]		= dummy_register_io_packet,
		[OhciPeriodicStartReg_log_prefix_write]		= dummy_register_io_packet,
		[OhciLSThresholdReg_log_prefix_read]		= dummy_register_io_packet,
		[OhciLSThresholdReg_log_prefix_write]		= dummy_register_io_packet,
		[OhciRhDescriptorAReg_log_prefix_read]		= dummy_register_io_packet,
		[OhciRhDescriptorAReg_log_prefix_write]		= dummy_register_io_packet,
		[OhciRhDescriptorBReg_log_prefix_read]		= dummy_register_io_packet,
		[OhciRhDescriptorBReg_log_prefix_write]		= dummy_register_io_packet,
		[OhciRhStatusReg_log_prefix_read]		= dummy_register_io_packet,
		[OhciRhStatusReg_log_prefix_write]		= dummy_register_io_packet,
		[OhciRhPortStatusReg_log_prefix_read]		= dummy_register_io_packet,
		[OhciRhPortStatusReg_log_prefix_write]		= dummy_register_io_packet,

		[0x4d]	= dummy,
		[0x4e]	= dummy,
		[0x4f]	= dummy,
		[0x50]	= dummy,
		[0x51]	= dummy,
		[0x52]	= dummy,
		[0x53]	= dummy,
		[0x54]	= dummy,
		[0x55]	= dummy,
		[0x56]	= dummy,
		[0x57]	= dummy,
		[0x58]	= dummy,
		[0x59]	= dummy,
		[0x5a]	= dummy,
		[0x5b]	= dummy,
		[0x5c]	= dummy,
		[0x5d]	= dummy,
		[0x5e]	= dummy,
		[0x5f]	= dummy,
		[0x60]	= dummy,
		[0x61]	= dummy,
		[0x62]	= dummy,
		[0x63]	= dummy,
		[0x64]	= dummy,
		[0x65]	= dummy,
		[0x66]	= dummy,
		[0x67]	= dummy,
		[0x68]	= dummy,
		[0x69]	= dummy,
		[0x6a]	= dummy,
		[0x6b]	= dummy,
		[0x6c]	= dummy,
		[0x6d]	= dummy,
		[0x6e]	= dummy,
		[0x6f]	= dummy,
		[0x70]	= dummy,
		[0x71]	= dummy,
		[0x72]	= dummy,
		[0x73]	= dummy,
		[0x74]	= dummy,
		[0x75]	= dummy,
		[0x76]	= dummy,
		[0x77]	= dummy,
		[0x78]	= dummy,
		[0x79]	= dummy,
		[0x7a]	= dummy,
		[0x7b]	= dummy,
		[0x7c]	= dummy,
		[0x7d]	= dummy,
		[0x7e]	= dummy,
		[0x7f]	= dummy,

		[TRANSFER_DESCRIPTOR_READY_LOG_PREFIX]		= log_transfer_descriptor,
};

QTcpSocket * USBLogDecoder::s;
QFile USBLogDecoder::f("usb-log-capture.out");

void USBLogDecoder::runDecoder(const QString &parameters)
{
	s = new QTcpSocket();
#if !RUN_CAPTURED_LOG
	while (1)
	{
		s->connectToHost("localhost", USB_LOG_TCP_PORT, QTcpSocket::ReadOnly);
		if (s->waitForConnected(1000))
			break;
	}
#endif
	emit outputReady("connected>>>");
	while (1)
	{
		int h = 0;
		if ((h = getByte()) == -1)
			break;
		if (decoders[h])
			emit outputReady(decoders[h](h));
		else
			emit outputReady(QString("UNDECODED PACKET: $%1").arg(h, 2, 16, QChar('0')));
	}
	emit outputReady("finished>>>");
}
