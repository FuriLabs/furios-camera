/*
 * Copyright 2020 Axel Waggershauser
 * Copyright 2024 Bardia Moshiri
 */
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include <ReadBarcode.h>

#include <QImage>
#include <QDebug>
#include <QMetaType>
#include <QScopeGuard>
#include <QQmlEngine>
#include <QRect>
#include <QSize>
#include <QMetaObject>
#include <QPointer>
#include <algorithm>
#include <numeric>
#include <atomic>
#include <climits>
#include <vector>

#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
#include <QAbstractVideoFilter>
#include <QVideoFrame>
#include <QAbstractVideoBuffer>
#else
#include <QVideoFrame>
#include <QVideoSink>
#endif

#include <QElapsedTimer>
#include <QTimer>
#include <QtConcurrent/QtConcurrent>

namespace ZXingQt {

Q_NAMESPACE

enum class BarcodeFormat
{
	None            = 0,         ///< Used as a return value if no valid barcode has been detected
	Aztec           = (1 << 0),  ///< Aztec
	Codabar         = (1 << 1),  ///< Codabar
	Code39          = (1 << 2),  ///< Code39
	Code93          = (1 << 3),  ///< Code93
	Code128         = (1 << 4),  ///< Code128
	DataBar         = (1 << 5),  ///< GS1 DataBar, formerly known as RSS 14
	DataBarExpanded = (1 << 6),  ///< GS1 DataBar Expanded, formerly known as RSS EXPANDED
	DataMatrix      = (1 << 7),  ///< DataMatrix
	EAN8            = (1 << 8),  ///< EAN-8
	EAN13           = (1 << 9),  ///< EAN-13
	ITF             = (1 << 10), ///< ITF (Interleaved Two of Five)
	MaxiCode        = (1 << 11), ///< MaxiCode
	PDF417          = (1 << 12), ///< PDF417 or
	QRCode          = (1 << 13), ///< QR Code
	UPCA            = (1 << 14), ///< UPC-A
	UPCE            = (1 << 15), ///< UPC-E
	MicroQRCode     = (1 << 16), ///< Micro QR Code
	RMQRCode        = (1 << 17), ///< Rectangular Micro QR Code

	LinearCodes = Codabar | Code39 | Code93 | Code128 | EAN8 | EAN13 | ITF | DataBar | DataBarExpanded | UPCA | UPCE,
	MatrixCodes = Aztec | DataMatrix | MaxiCode | PDF417 | QRCode | MicroQRCode | RMQRCode,
};

enum class ContentType { Text, Binary, Mixed, GS1, ISO15434, UnknownECI };

using ZXing::ReaderOptions;
using ZXing::Binarizer;
using ZXing::BarcodeFormats;

Q_ENUM_NS(BarcodeFormat)
Q_ENUM_NS(ContentType)

template<typename T, typename = decltype(ZXing::ToString(T()))>
QDebug operator<<(QDebug dbg, const T& v)
{
	return dbg.noquote() << QString::fromStdString(ToString(v));
}

class Position : public ZXing::Quadrilateral<QPoint>
{
	Q_GADGET

	Q_PROPERTY(QPoint topLeft READ topLeft)
	Q_PROPERTY(QPoint topRight READ topRight)
	Q_PROPERTY(QPoint bottomRight READ bottomRight)
	Q_PROPERTY(QPoint bottomLeft READ bottomLeft)

	using Base = ZXing::Quadrilateral<QPoint>;

public:
	using Base::Base;
};

class Result : private ZXing::Barcode
{
	friend class BarcodeReader;
	Q_GADGET

	Q_PROPERTY(BarcodeFormat format READ format)
	Q_PROPERTY(QString formatName READ formatName)
	Q_PROPERTY(QString text READ text)
	Q_PROPERTY(QByteArray bytes READ bytes)
	Q_PROPERTY(bool isValid READ isValid)
	Q_PROPERTY(ContentType contentType READ contentType)
	Q_PROPERTY(Position position READ position)

	QString _text;
	QByteArray _bytes;

protected:
	Position _position;

public:
	Result() = default; // required for qmetatype machinery

	explicit Result(ZXing::Barcode&& r) : ZXing::Barcode(std::move(r))
	{
		_text = QString::fromStdString(ZXing::Barcode::text());

		const auto b = ZXing::Barcode::bytes();
		_bytes = QByteArray(reinterpret_cast<const char*>(b.data()), static_cast<int>(b.size()));

		auto& pos = ZXing::Barcode::position();
		auto qp = [&pos](int i) { return QPoint(pos[i].x, pos[i].y); };
		_position = {qp(0), qp(1), qp(2), qp(3)};
	}

	using ZXing::Barcode::isValid;

	BarcodeFormat format() const { return static_cast<BarcodeFormat>(ZXing::Barcode::format()); }
	ContentType contentType() const { return static_cast<ContentType>(ZXing::Barcode::contentType()); }
	QString formatName() const { return QString::fromStdString(ZXing::ToString(ZXing::Barcode::format())); }
	const QString& text() const { return _text; }
	const QByteArray& bytes() const { return _bytes; }
	const Position& position() const { return _position; }

	// For debugging/development
	int runTime = 0;
	Q_PROPERTY(int runTime MEMBER runTime)
};

inline QList<Result> QListResults(ZXing::Barcodes&& zxres)
{
	QList<Result> res;
	res.reserve(static_cast<int>(zxres.size()));
	for (auto&& r : zxres)
		res.push_back(Result(std::move(r)));
	return res;
}

inline QList<Result> ReadBarcodes(const QImage& img, const ReaderOptions& opts = {})
{
	using namespace ZXing;

	auto ImgFmtFromQImg = [](const QImage& img) {
		switch (img.format()) {
		case QImage::Format_ARGB32:
		case QImage::Format_RGB32:
#if Q_BYTE_ORDER == Q_LITTLE_ENDIAN
			return ImageFormat::BGRA;
#else
			return ImageFormat::ARGB;
#endif
		case QImage::Format_RGB888:
			return ImageFormat::RGB;

#if QT_VERSION >= QT_VERSION_CHECK(5, 5, 0)
		case QImage::Format_RGBX8888:
		case QImage::Format_RGBA8888:
			return ImageFormat::RGBA;
#endif

#if QT_VERSION >= QT_VERSION_CHECK(5, 13, 0)
		case QImage::Format_Grayscale8:
			return ImageFormat::Lum;
#endif
		default:
			return ImageFormat::None;
		}
	};

	auto exec = [&](const QImage& input) {
		return QListResults(ZXing::ReadBarcodes(
			{input.constBits(), input.width(), input.height(), ImgFmtFromQImg(input), static_cast<int>(input.bytesPerLine())},
			opts));
	};

	if (ImgFmtFromQImg(img) != ImageFormat::None)
		return exec(img);

#if QT_VERSION >= QT_VERSION_CHECK(5, 13, 0)
	return exec(img.convertToFormat(QImage::Format_Grayscale8));
#else
	return exec(img.convertToFormat(QImage::Format_RGB32));
#endif
}

inline Result ReadBarcode(const QImage& img, const ReaderOptions& opts = {})
{
	auto res = ReadBarcodes(img, ReaderOptions(opts).setMaxNumberOfSymbols(1));
	return !res.isEmpty() ? res.takeFirst() : Result();
}

inline QList<Result> ReadBarcodes(const QVideoFrame& frame, const ReaderOptions& opts = {})
{
	using namespace ZXing;

	ImageFormat fmt = ImageFormat::None;
	int pixStride = 0;
	int pixOffset = 0;

#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
#define FORMAT(F5, F6) QVideoFrame::Format_##F5
#define FIRST_PLANE
#else
#define FORMAT(F5, F6) QVideoFrameFormat::Format_##F6
#define FIRST_PLANE 0
#endif

	switch (frame.pixelFormat()) {
	case FORMAT(ARGB32, ARGB8888):
	case FORMAT(ARGB32_Premultiplied, ARGB8888_Premultiplied):
	case FORMAT(RGB32, XRGB8888):
#if Q_BYTE_ORDER == Q_LITTLE_ENDIAN
		fmt = ImageFormat::BGRA;
#else
		fmt = ImageFormat::ARGB;
#endif
		break;

	case FORMAT(BGRA32, BGRA8888):
	case FORMAT(BGRA32_Premultiplied, BGRA8888_Premultiplied):
	case FORMAT(BGR32, BGRX8888):
#if Q_BYTE_ORDER == Q_LITTLE_ENDIAN
		fmt = ImageFormat::RGBA;
#else
		fmt = ImageFormat::ABGR;
#endif
		break;

#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
	case QVideoFrame::Format_RGB24:
		fmt = ImageFormat::RGB;
		break;
	case QVideoFrame::Format_BGR24:
		fmt = ImageFormat::BGR;
		break;
	case QVideoFrame::Format_YUV444:
		fmt = ImageFormat::Lum;
		pixStride = 3;
		break;
#else
	case QVideoFrameFormat::Format_P010:
	case QVideoFrameFormat::Format_P016:
		fmt = ImageFormat::Lum;
		pixStride = 1;
		break;
#endif

	case FORMAT(AYUV444, AYUV):
	case FORMAT(AYUV444_Premultiplied, AYUV_Premultiplied):
#if Q_BYTE_ORDER == Q_LITTLE_ENDIAN
		fmt = ImageFormat::Lum;
		pixStride = 4;
		pixOffset = 3;
#else
		fmt = ImageFormat::Lum;
		pixStride = 4;
		pixOffset = 2;
#endif
		break;

	case FORMAT(YUV420P, YUV420P):
	case FORMAT(NV12, NV12):
	case FORMAT(NV21, NV21):
	case FORMAT(IMC1, IMC1):
	case FORMAT(IMC2, IMC2):
	case FORMAT(IMC3, IMC3):
	case FORMAT(IMC4, IMC4):
	case FORMAT(YV12, YV12):
		fmt = ImageFormat::Lum;
		break;

	case FORMAT(UYVY, UYVY):
		fmt = ImageFormat::Lum;
		pixStride = 2;
		pixOffset = 1;
		break;

	case FORMAT(YUYV, YUYV):
		fmt = ImageFormat::Lum;
		pixStride = 2;
		break;

	case FORMAT(Y8, Y8):
		fmt = ImageFormat::Lum;
		break;

	case FORMAT(Y16, Y16):
		fmt = ImageFormat::Lum;
		pixStride = 2;
		pixOffset = 1;
		break;

#if (QT_VERSION >= QT_VERSION_CHECK(5, 13, 0))
	case FORMAT(ABGR32, ABGR8888):
#if Q_BYTE_ORDER == Q_LITTLE_ENDIAN
		fmt = ImageFormat::RGBA;
#else
		fmt = ImageFormat::XBGR;
#endif
		break;
#endif

#if (QT_VERSION >= QT_VERSION_CHECK(5, 14, 0))
	case FORMAT(YUV422P, YUV422P):
		fmt = ImageFormat::Lum;
		break;
#endif

	default:
		break;
	}

	if (fmt != ImageFormat::None) {
		auto img = frame; // shallow copy just get access to non-const map() function
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
		if (!img.isValid() || !img.map(QAbstractVideoBuffer::ReadOnly)) {
#else
		if (!img.isValid() || !img.map(QVideoFrame::ReadOnly)) {
#endif
			qWarning() << "invalid QVideoFrame: could not map memory";
			return {};
		}

		QScopeGuard unmap([&] { img.unmap(); });

		return QListResults(ZXing::ReadBarcodes(
			{img.bits(FIRST_PLANE) + pixOffset, img.width(), img.height(), fmt, img.bytesPerLine(FIRST_PLANE), pixStride},
			opts));
	} else {
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
		if (QVideoFrame::imageFormatFromPixelFormat(frame.pixelFormat()) == QImage::Format_Invalid) {
			qWarning() << "unsupported QVideoFrame::pixelFormat";
			return {};
		}
		auto qimg = frame.image();
#else
		auto qimg = frame.toImage();
#endif
		if (qimg.format() != QImage::Format_Invalid)
			return ReadBarcodes(qimg, opts);

		qWarning() << "failed to convert QVideoFrame to QImage";
		return {};
	}
}

inline Result ReadBarcode(const QVideoFrame& frame, const ReaderOptions& opts = {})
{
	auto res = ReadBarcodes(frame, ReaderOptions(opts).setMaxNumberOfSymbols(1));
	return !res.isEmpty() ? res.takeFirst() : Result();
}

#define ZQ_PROPERTY(Type, name, setter) \
public: \
	Q_PROPERTY(Type name READ name WRITE setter NOTIFY name##Changed) \
	Type name() const noexcept { return ReaderOptions::name(); } \
	Q_SLOT void setter(const Type& newVal) \
	{ \
		if (name() != newVal) { \
			ReaderOptions::setter(newVal); \
			emit name##Changed(); \
		} \
	} \
	Q_SIGNAL void name##Changed();

// Minimal Qt wrapper to keep the QML/video filter integration used by the app.
class BarcodeReader :
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
		public QAbstractVideoFilter,
#else
		public QObject,
#endif
		private ReaderOptions
{
	Q_OBJECT

public:
	Q_PROPERTY(int formats READ formats WRITE setFormats NOTIFY formatsChanged)
	int formats() const noexcept
	{
		return _formats;
	}
	Q_SLOT void setFormats(const int& newVal)
	{
		if (_formats == newVal)
			return;

		std::vector<ZXing::BarcodeFormat> fmts;

		if (newVal & static_cast<int>(ZXingQt::BarcodeFormat::Aztec))
			fmts.push_back(ZXing::BarcodeFormat::Aztec);
		if (newVal & static_cast<int>(ZXingQt::BarcodeFormat::Codabar))
			fmts.push_back(ZXing::BarcodeFormat::Codabar);
		if (newVal & static_cast<int>(ZXingQt::BarcodeFormat::Code39))
			fmts.push_back(ZXing::BarcodeFormat::Code39);
		if (newVal & static_cast<int>(ZXingQt::BarcodeFormat::Code93))
			fmts.push_back(ZXing::BarcodeFormat::Code93);
		if (newVal & static_cast<int>(ZXingQt::BarcodeFormat::Code128))
			fmts.push_back(ZXing::BarcodeFormat::Code128);
		if (newVal & static_cast<int>(ZXingQt::BarcodeFormat::DataBar))
			fmts.push_back(ZXing::BarcodeFormat::DataBar);
		if (newVal & static_cast<int>(ZXingQt::BarcodeFormat::DataBarExpanded))
			fmts.push_back(ZXing::BarcodeFormat::DataBarExpanded);
		if (newVal & static_cast<int>(ZXingQt::BarcodeFormat::DataMatrix))
			fmts.push_back(ZXing::BarcodeFormat::DataMatrix);
		if (newVal & static_cast<int>(ZXingQt::BarcodeFormat::EAN8))
			fmts.push_back(ZXing::BarcodeFormat::EAN8);
		if (newVal & static_cast<int>(ZXingQt::BarcodeFormat::EAN13))
			fmts.push_back(ZXing::BarcodeFormat::EAN13);
		if (newVal & static_cast<int>(ZXingQt::BarcodeFormat::ITF))
			fmts.push_back(ZXing::BarcodeFormat::ITF);
		if (newVal & static_cast<int>(ZXingQt::BarcodeFormat::MaxiCode))
			fmts.push_back(ZXing::BarcodeFormat::MaxiCode);
		if (newVal & static_cast<int>(ZXingQt::BarcodeFormat::PDF417))
			fmts.push_back(ZXing::BarcodeFormat::PDF417);
		if (newVal & static_cast<int>(ZXingQt::BarcodeFormat::QRCode))
			fmts.push_back(ZXing::BarcodeFormat::QRCode);
		if (newVal & static_cast<int>(ZXingQt::BarcodeFormat::UPCA))
			fmts.push_back(ZXing::BarcodeFormat::UPCA);
		if (newVal & static_cast<int>(ZXingQt::BarcodeFormat::UPCE))
			fmts.push_back(ZXing::BarcodeFormat::UPCE);
		if (newVal & static_cast<int>(ZXingQt::BarcodeFormat::MicroQRCode))
			fmts.push_back(ZXing::BarcodeFormat::MicroQRCode);
		if (newVal & static_cast<int>(ZXingQt::BarcodeFormat::RMQRCode))
			fmts.push_back(ZXing::BarcodeFormat::RMQRCode);

		_formats = newVal;
		ReaderOptions::setFormats(ZXing::BarcodeFormats(std::move(fmts)));
		emit formatsChanged();
	}
	Q_SIGNAL void formatsChanged();

	ZQ_PROPERTY(bool, tryHarder, setTryHarder)
	ZQ_PROPERTY(bool, tryRotate, setTryRotate)
	ZQ_PROPERTY(bool, tryInvert, setTryInvert)
	ZQ_PROPERTY(bool, tryDownscale, setTryDownscale)
	ZQ_PROPERTY(bool, isPure, setIsPure)
	ZQ_PROPERTY(bool, returnErrors, setReturnErrors)

private:
	int _formats = 0;
	std::atomic_bool _busy {false};
	int _sleepTime = 200;
	QRect _cropRect;

	void processInternal(QImage image, ReaderOptions opts, QRect cropRectSnapshot)
	{
		Result res = ReadBarcode(image, opts);

		if (!cropRectSnapshot.isNull()) {
			for (int i = 0; i < 4; ++i)
				res._position[i] += cropRectSnapshot.topLeft();
		}

		QPointer<BarcodeReader> self(this);
		QMetaObject::invokeMethod(this, [self, res]() mutable {
			if (!self)
				return;
			self->handleScanResult(std::move(res));
		}, Qt::QueuedConnection);
	}

	void handleScanResult(Result res)
	{
		emit newResult(res);

		if (res.isValid()) {
			// We have a code! Sample more often and only around the area where we found the code
			// so the animation looks nice

			// Calculate a box that fits all 4 points, then pad it some
			QPoint topLeft(INT_MAX, INT_MAX);
			QPoint bottomRight(INT_MIN, INT_MIN);

			for (int i = 0; i < 4; ++i) {
				const QPoint p = res.position()[i];
				topLeft.setX(std::min(topLeft.x(), p.x()));
				topLeft.setY(std::min(topLeft.y(), p.y()));
				bottomRight.setX(std::max(bottomRight.x(), p.x()));
				bottomRight.setY(std::max(bottomRight.y(), p.y()));
			}

			_cropRect = QRect(topLeft, bottomRight).normalized();

			const int w = std::max(500, std::min(_cropRect.width() * 2, _cropRect.width() + 200));
			const int h = std::max(500, std::min(_cropRect.height() * 2, _cropRect.height() + 200));

			_cropRect.moveTopLeft(_cropRect.topLeft() - (QPoint(w, h) - QPoint(_cropRect.width(), _cropRect.height())) / 2);
			_cropRect.setSize(QSize(w, h));

			// Wake from our slumber
			if (_sleepTime != 20) {
				_sleepTime = 20;
			}
		} else {
			_sleepTime = 200;
			_cropRect = QRect();
			emit noResult();
		}

		_busy = false;

#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
		setActive(true);
#endif
	}

public:
	explicit BarcodeReader(QObject* parent = nullptr)
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
		: QAbstractVideoFilter(parent)
#else
		: QObject(parent)
#endif
	{
	}

signals:
	void newResult(ZXingQt::Result result);
	void noResult();

public slots:
	void process(const QVideoFrame& frame)
	{
		if (!frame.isValid())
			return;

		bool expected = false;
		if (!_busy.compare_exchange_strong(expected, true))
			return;

#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
		// Disable ourselves for a bit -- we don't need to sample at full throttle
		setActive(false);
		QTimer::singleShot(_sleepTime, this, [this] {
			if (!_busy.load())
				setActive(true);
		});
#endif

		// Sadly have to grab the image data here because we need the GL context to be current
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
		QImage img = frame.image();
#else
		QImage img = frame.toImage();
#endif

		if (img.isNull()) {
			_busy = false;
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
			setActive(true);
#endif
			return;
		}

		const QRect boundedCrop = _cropRect.intersected(img.rect());
		if (!boundedCrop.isNull())
			img = img.copy(boundedCrop);

		const ReaderOptions opts(*this);
		QtConcurrent::run([this, img, opts, boundedCrop]() mutable {
			processInternal(img, opts, boundedCrop);
		});
	}

	void process(const QImage& image)
	{
		if (image.isNull())
			return;

		bool expected = false;
		if (!_busy.compare_exchange_strong(expected, true))
			return;

		QImage img = image;
		const QRect boundedCrop = _cropRect.intersected(img.rect());
		if (!boundedCrop.isNull())
			img = img.copy(boundedCrop);

		const ReaderOptions opts(*this);
		QtConcurrent::run([this, img, opts, boundedCrop]() mutable {
			processInternal(img, opts, boundedCrop);
		});
	}

#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
public:
	QVideoFilterRunnable *createFilterRunnable() override;
#else
private:
	QVideoSink *_sink = nullptr;

public:
	void setVideoSink(QVideoSink* sink)
	{
		if (_sink == sink)
			return;

		if (_sink)
			disconnect(_sink, nullptr, this, nullptr);

		_sink = sink;

		if (_sink)
			connect(_sink, &QVideoSink::videoFrameChanged, this, &BarcodeReader::process);
	}

	Q_PROPERTY(QVideoSink* videoSink WRITE setVideoSink)
#endif
};

#undef ZQ_PROPERTY

#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
class VideoFilterRunnable : public QVideoFilterRunnable
{
	BarcodeReader* _filter = nullptr;

public:
	explicit VideoFilterRunnable(BarcodeReader* filter) : _filter(filter) {}

	QVideoFrame run(QVideoFrame* input, const QVideoSurfaceFormat& /*surfaceFormat*/, RunFlags /*flags*/) override
	{
		if (input)
			_filter->process(*input);
		return input ? *input : QVideoFrame();
	}
};

inline QVideoFilterRunnable* BarcodeReader::createFilterRunnable()
{
	return new VideoFilterRunnable(this);
}
#endif

} // namespace ZXingQt

Q_DECLARE_METATYPE(ZXingQt::Position)
Q_DECLARE_METATYPE(ZXingQt::Result)

namespace ZXingQt {

inline void registerQmlAndMetaTypes()
{
	qRegisterMetaType<ZXingQt::BarcodeFormat>("BarcodeFormat");
	qRegisterMetaType<ZXingQt::ContentType>("ContentType");

	// supposedly the Q_DECLARE_METATYPE should be used with the overload without a custom name
	// but then the qml side complains about "unregistered type"
	qRegisterMetaType<ZXingQt::Position>("Position");
	qRegisterMetaType<ZXingQt::Result>("Result");

	qmlRegisterUncreatableMetaObject(
		ZXingQt::staticMetaObject, "ZXing", 1, 0, "ZXing", "Access to enums & flags only");
	qmlRegisterType<ZXingQt::BarcodeReader>("ZXing", 1, 0, "BarcodeReader");
}

} // namespace ZXingQt
