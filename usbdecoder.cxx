#include <QFileDialog>
#include "usbdecoder.hxx"
#include "ui_usbdecoder.h"

MainWindow::MainWindow(QWidget *parent) :
	QMainWindow(parent),
	ui(new Ui::MainWindow)
{
	ui->setupUi(this);

	/*
	USBLogDecoder * decoder = new USBLogDecoder;
	decoder->moveToThread(& decoder_thread);
	connect(& decoder_thread, & QThread::finished, decoder, & QObject::deleteLater);
	connect(this, & MainWindow::runDecoder, decoder, & USBLogDecoder::runDecoder);
	connect(decoder, & USBLogDecoder::outputReady, this, & MainWindow::readyReadUsbLogSocket);
	decoder_thread.start();
	*/

	emit runDecoder("");

	statusBar()->showMessage("connecting...");

	connect(& s, & QTcpSocket::connected, [=] { statusBar()->showMessage("connected"); });
	connect(& s, & QTcpSocket::disconnected, [=] { statusBar()->showMessage("disconnected"); });
	connect(& s, QOverload<QAbstractSocket::SocketError>::of(&QAbstractSocket::error),
		[=](QAbstractSocket::SocketError socketError){ statusBar()->showMessage("error!!!"); });
	connect(& s, & QTcpSocket::readyRead, [=] { usbLogData += s.readAll(); });

	s.connectToHost("localhost", USB_LOG_TCP_PORT);

	connect(ui->pushButtonConnect, & QPushButton::clicked,
		[=] { auto s = USBLogDecoder::decode(usbLogData);
		for (auto & l : s)
			ui->plainTextEdit->appendPlainText(l);
	});
	connect(ui->pushButtonDecodeFile, & QPushButton::clicked,
		[=] {
		auto f = QFileDialog::getOpenFileName();
		QFile x(f);
		if (!x.open(QFile::ReadOnly))
			return;
		auto s = USBLogDecoder::decode(x.readAll());
		for (auto & l : s)
			ui->plainTextEdit->appendPlainText(l);
	});
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
		[OhciControlReg_log_prefix_read]		= log_reg_access_OhciControlReg,
		[OhciControlReg_log_prefix_write]		= log_reg_access_OhciControlReg,
		[OhciCommandStatusReg_log_prefix_read]		= log_reg_access_OhciCommandStatusReg,
		[OhciCommandStatusReg_log_prefix_write]		= log_reg_access_OhciCommandStatusReg,
		[OhciInterruptStatusReg_log_prefix_read]	= log_reg_access_OhciInterruptStatusReg,
		[OhciInterruptStatusReg_log_prefix_write]	= log_reg_access_OhciInterruptStatusReg,
		[OhciInterruptEnableReg_log_prefix_read]	= log_reg_access_OhciInterruptEnableReg,
		[OhciInterruptEnableReg_log_prefix_write]	= log_reg_access_OhciInterruptEnableReg,
		[OhciInterruptDisableReg_log_prefix_read]	= log_reg_access_OhciInterruptDisableReg,
		[OhciInterruptDisableReg_log_prefix_write]	= log_reg_access_OhciInterruptDisableReg,
		[OhciHCCAReg_log_prefix_read]			= log_reg_access_OhciHCCAReg,
		[OhciHCCAReg_log_prefix_write]			= log_reg_access_OhciHCCAReg,
		[OhciPeriodCurrentEDReg_log_prefix_read]	= dummy_register_io_packet,
		[OhciPeriodCurrentEDReg_log_prefix_write]	= dummy_register_io_packet,
		[OhciControlHeadEDReg_log_prefix_read]		= log_reg_access_OhciControlHeadEDReg,
		[OhciControlHeadEDReg_log_prefix_write]		= log_reg_access_OhciControlHeadEDReg,
		[OhciControlCurrentEDReg_log_prefix_read]	= log_reg_access_OhciControlCurrentEDReg,
		[OhciControlCurrentEDReg_log_prefix_write]	= log_reg_access_OhciControlCurrentEDReg,
		[OhciBulkHeadEDReg_log_prefix_read]		= log_reg_access_OhciBulkHeadEDReg,
		[OhciBulkHeadEDReg_log_prefix_write]		= log_reg_access_OhciBulkHeadEDReg,
		[OhciBulkCurrentEDReg_log_prefix_read]		= log_reg_access_OhciBulkCurrentEDReg,
		[OhciBulkCurrentEDReg_log_prefix_write]		= log_reg_access_OhciBulkCurrentEDReg,
		[OhciDoneHeadReg_log_prefix_read]		= log_reg_access_OhciDoneHeadEDReg,
		[OhciDoneHeadReg_log_prefix_write]		= log_reg_access_OhciDoneHeadEDReg,
		[OhciFmIntervalReg_log_prefix_read]		= log_reg_access_OhciFmIntervalReg,
		[OhciFmIntervalReg_log_prefix_write]		= log_reg_access_OhciFmIntervalReg,
		[OhciFmRemainingReg_log_prefix_read]		= dummy_register_io_packet,
		[OhciFmRemainingReg_log_prefix_write]		= dummy_register_io_packet,
		[OhciFmNumberReg_log_prefix_read]		= dummy_register_io_packet,
		[OhciFmNumberReg_log_prefix_write]		= dummy_register_io_packet,
		[OhciPeriodicStartReg_log_prefix_read]		= log_reg_access_OhciPeriodicStartReg,
		[OhciPeriodicStartReg_log_prefix_write]		= log_reg_access_OhciPeriodicStartReg,
		[OhciLSThresholdReg_log_prefix_read]		= dummy_register_io_packet,
		[OhciLSThresholdReg_log_prefix_write]		= dummy_register_io_packet,
		[OhciRhDescriptorAReg_log_prefix_read]		= log_reg_access_OhciRhDescriptorAReg,
		[OhciRhDescriptorAReg_log_prefix_write]		= log_reg_access_OhciRhDescriptorAReg,
		[OhciRhDescriptorBReg_log_prefix_read]		= dummy_register_io_packet,
		[OhciRhDescriptorBReg_log_prefix_write]		= dummy_register_io_packet,
		[OhciRhStatusReg_log_prefix_read]		= log_reg_access_OhciRhStatusReg,
		[OhciRhStatusReg_log_prefix_write]		= log_reg_access_OhciRhStatusReg,
		[OhciRhPortStatusReg_log_prefix_read]		= OhciRhPortStatusReg_access,
		[OhciRhPortStatusReg_log_prefix_write]		= OhciRhPortStatusReg_access,

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

		[INTERRUPT_ENTRY_LOG_PREFIX]			=	log_irq_entry,
		[INTERRUPT_EXIT_LOG_PREFIX]			=	log_irq_exit,
		[INTERRUPT_TRANSFER_DONE_LOG_PREFIX]		=	log_interrupt_transfer_done,
		[INTERRUPT_START_OF_FRAME_LOG_PREFIX]		=	dummy,
		[INTERRUPT_ROOT_HUB_EVENT_PREFIX]		=	log_root_hub_interrupt,
		[HCCA_CONTENTS_LOG_PREFIX]			=	dump_hcca,
		[OHCI_INIT_START_LOG_PREFIX]			=	log_init_start,
		[OHCI_INIT_END_LOG_PREFIX]			=	log_init_end,
};

QTcpSocket * USBLogDecoder::s;
QByteArray USBLogDecoder::data;
int USBLogDecoder::dataIndex;
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

QStringList USBLogDecoder::decode(const QByteArray &logData)
{
QStringList packets;
int h;

	data = logData;
	dataIndex = 0;

	if (!data.isEmpty()) while ((h = getByte()) != -1)
	{
		if (decoders[h])
			packets << decoders[h](h);
		else
			packets << QString("UNDECODED PACKET: $%1").arg(h, 2, 16, QChar('0'));
	}
	return packets;
}
