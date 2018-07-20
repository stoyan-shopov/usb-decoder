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

QString (*USBLogDecoder::decoders[255])(QTcpSocket &) =
{
	[0] = 0,
	[1] = dummy,
};

void USBLogDecoder::runDecoder(const QString &parameters)
{
	s = new QTcpSocket();
	while (1)
	{
		s->connectToHost("localhost", USB_LOG_TCP_PORT, QTcpSocket::ReadOnly);
		if (s->waitForConnected(1000))
			break;
	}
	emit outputReady("connected>>>\n");
}
