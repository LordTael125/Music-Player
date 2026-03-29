# Chapter 8 — CoverArtProvider: On-Demand Album Art

## 8.1 The Problem

QML's `Image` element can display images from files or URLs. But album art is **embedded inside audio files** — it's not a separate `.jpg` on disk. We need a way for QML to request album art using a track's file path and get back a `QImage`.

Qt solves this with `QQuickImageProvider` — a class you register with the QML engine. When QML requests an image with the `image://` scheme, Qt routes the request to your provider.

---

## 8.2 How the URL Scheme Works

```qml
// In QML — request album art for a specific track:
Image {
    source: "image://musiccover/" + track.filePath
    //       ↑ scheme+id  ↑ provider name  ↑ the "id" passed to requestImage()
}
```

The URL `image://musiccover/home/user/music/song.mp3` tells Qt:
- Use the image provider registered as `"musiccover"`
- Pass `"/home/user/music/song.mp3"` as the `id` parameter

---

## 8.3 The CoverArtProvider Class

```cpp
// include/cover_art_provider.h
#include <QQuickImageProvider>
#include <QImage>

class CoverArtProvider : public QQuickImageProvider {
public:
    CoverArtProvider();
    QImage requestImage(const QString &id, QSize *size,
                        const QSize &requestedSize) override;
};
```

Note: `CoverArtProvider` does **not** inherit from `QObject`. It inherits from `QQuickImageProvider` instead. It therefore has **no signals or slots** and does not use `Q_OBJECT`.

---

## 8.4 Full Implementation

```cpp
CoverArtProvider::CoverArtProvider()
    : QQuickImageProvider(QQuickImageProvider::Image)  // We return QImage objects
{}

QImage CoverArtProvider::requestImage(const QString &id, QSize *size,
                                       const QSize &requestedSize)
{
    QString filePath = id;   // id is exactly the path after "image://musiccover/"
    QImage image;

    // Helper lambda: scale and report size before returning
    auto returnImage = [&]() {
        if (size) *size = image.size();
        if (requestedSize.width() > 0 && requestedSize.height() > 0) {
            image = image.scaled(requestedSize, Qt::KeepAspectRatio,
                                 Qt::SmoothTransformation);
        }
        return image;
    };

    // --- MP3: Read APIC (Attached Picture) frame from ID3v2 tag ---
    if (filePath.endsWith(".mp3", Qt::CaseInsensitive)) {
        TagLib::MPEG::File mpegFile(filePath.toUtf8().constData());
        if (mpegFile.hasID3v2Tag()) {
            TagLib::ID3v2::Tag *id3v2tag = mpegFile.ID3v2Tag();
            if (id3v2tag) {
                auto frameList = id3v2tag->frameListMap()["APIC"];
                if (!frameList.isEmpty()) {
                    auto frame = static_cast<TagLib::ID3v2::AttachedPictureFrame *>(
                        frameList.front());
                    // frame->picture() returns raw JPEG/PNG bytes
                    image.loadFromData(
                        (const uchar *)frame->picture().data(),
                        frame->picture().size()
                    );
                }
            }
        }
    }
    // --- FLAC: Read from FLAC picture list ---
    else if (filePath.endsWith(".flac", Qt::CaseInsensitive)) {
        TagLib::FLAC::File flacFile(filePath.toUtf8().constData());
        if (flacFile.isValid() && !flacFile.pictureList().isEmpty()) {
            auto picture = flacFile.pictureList().front();
            image.loadFromData(
                (const uchar *)picture->data().data(),
                picture->data().size()
            );
        }
    }
    // --- M4A: Read "covr" item from MP4 tag ---
    else if (filePath.endsWith(".m4a", Qt::CaseInsensitive)) {
        TagLib::MP4::File mp4File(filePath.toUtf8().constData());
        if (mp4File.isValid() && mp4File.tag()) {
            auto itemList = mp4File.tag()->itemMap();
            if (itemList.contains("covr")) {
                auto covrList = itemList["covr"].toCoverArtList();
                if (!covrList.isEmpty()) {
                    auto picture = covrList.front();
                    image.loadFromData(
                        (const uchar *)picture.data().data(),
                        picture.data().size()
                    );
                }
            }
        }
    }

    // Fallback: if no art found (or null image), return a dark placeholder
    if (image.isNull()) {
        image = QImage(200, 200, QImage::Format_RGB32);
        image.fill(QColor("#33333b"));  // dark neutral gray
    }

    return returnImage();
}
```

---

## 8.5 Registering the Provider in main.cpp

```cpp
QQmlApplicationEngine engine;
engine.addImageProvider(QLatin1String("musiccover"), new CoverArtProvider);
```

This registers the provider under the name `"musiccover"`, which matches the `image://musiccover/` URL scheme in QML. After this line, any QML `Image` with a matching source URL will automatically call `CoverArtProvider::requestImage()`.

---

## 8.6 Optimizing: sourceSize in QML

In the queue drawer and track list, album art is shown at small sizes (40×40 px). Without a `sourceSize`, Qt would load the full 500×500 JPEG and scale it in the GPU. With it:

```qml
Image {
    source: "image://musiccover/" + modelData.filePath
    Layout.preferredWidth: 40
    Layout.preferredHeight: 40
    fillMode: Image.PreserveAspectCrop
    asynchronous: true          // Load on background thread so list stays smooth
    sourceSize: Qt.size(100, 100) // Ask provider to pre-scale to 100x100
}
```

`sourceSize` is passed as `requestedSize` to `requestImage()`. The `returnImage` lambda scales the decoded image to this size before returning — saving GPU memory and improving render performance.
