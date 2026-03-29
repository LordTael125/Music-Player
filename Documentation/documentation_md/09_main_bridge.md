# Chapter 9 — main.cpp: Wiring Everything Together

`main.cpp` is the entry point of the application. It is intentionally short — its only job is to **create the backend objects, connect them to each other, expose them to QML, and launch the engine**.

## 9.1 The Full main.cpp Annotated

```cpp
#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "audio_engine.h"
#include "cover_art_provider.h"
#include "library_scanner.h"
#include "track_model.h"

#include <taglib/tdebuglistener.h>

// ─── Step 1: Silence TagLib's debug output ───────────────────────────────────
// TagLib prints diagnostic messages to the console. This custom listener
// swallows them so our terminal stays clean during development.
class SilentTagLibListener : public TagLib::DebugListener {
public:
    void printMessage(const TagLib::String &msg) override {
        // Intentionally empty — suppress all messages
    }
};

int main(int argc, char *argv[]) {
    // Register the silent listener before anything else runs
    static SilentTagLibListener silentListener;
    TagLib::setDebugListener(&silentListener);

    // ─── Step 2: High DPI support for Qt5 ───────────────────────────────────
    // Qt6 enables this automatically; Qt5 needs an explicit attribute.
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
#endif

    // ─── Step 3: Force the Material Dark theme ──────────────────────────────
    // These environment variables must be set BEFORE QApplication is created.
    // If set after, they have no effect because the style is loaded at startup.
    qputenv("QT_QUICK_CONTROLS_STYLE",              "Material");
    qputenv("QT_QUICK_CONTROLS_MATERIAL_THEME",     "Dark");
    qputenv("QT_QUICK_CONTROLS_MATERIAL_BACKGROUND", "#0a0a0c");
    qputenv("QT_QUICK_CONTROLS_MATERIAL_ACCENT",     "Purple");

    // ─── Step 4: Create the Qt application object ───────────────────────────
    // QApplication (not QCoreApplication) is needed for Qt Quick / GUI apps.
    QApplication app(argc, argv);

    // ─── Step 5: Register the Equalizer type with QML ───────────────────────
    // AudioEngine exposes an 'equalizer' property of type Equalizer*.
    // QML needs to know this type exists even though it can never CREATE one.
    // qmlRegisterUncreatableType tells QML: "this type exists, you can hold a
    // pointer to it and call its Q_INVOKABLE methods, but you cannot write
    // 'Equalizer { }' in QML".
    qmlRegisterUncreatableType<Equalizer>(
        "com.musicplayer", 1, 0,
        "Equalizer",
        "Equalizer cannot be created in QML"
    );

    // ─── Step 6: Create backend instances (on the stack — no new/delete) ────
    AudioEngine   audioEngine;
    LibraryScanner libraryScanner;
    TrackModel    trackModel;

    // ─── Step 7: Connect the scanner to the model ───────────────────────────
    // When scanning finishes and emits tracksAdded(vector),
    // trackModel automatically calls setTracks(vector) and updates QML.
    QObject::connect(&libraryScanner, &LibraryScanner::tracksAdded,
                     &trackModel,     &TrackModel::setTracks);

    // ─── Step 8: Create the QML engine ──────────────────────────────────────
    QQmlApplicationEngine engine;

    // Register the image provider for album art
    // After this, QML Image sources like "image://musiccover/path/to/song.mp3"
    // will automatically call CoverArtProvider::requestImage()
    engine.addImageProvider(QLatin1String("musiccover"), new CoverArtProvider);

    // ─── Step 9: Expose backend objects to QML ──────────────────────────────
    // These names become global JavaScript identifiers in ALL QML files.
    // QML can call methods: audioEngine.play()
    // QML can read properties: audioEngine.isPlaying
    // QML can connect to signals: Connections { target: audioEngine ... }
    engine.rootContext()->setContextProperty("audioEngine",    &audioEngine);
    engine.rootContext()->setContextProperty("libraryScanner", &libraryScanner);
    engine.rootContext()->setContextProperty("trackModel",     &trackModel);

    // ─── Step 10: Load the root QML file ────────────────────────────────────
    const QUrl url(QStringLiteral("qrc:/qml/main.qml"));

    // Connect objectCreated to detect if loading failed (e.g., QML parse error)
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreated, &app,
        [url](QObject *obj, const QUrl &objUrl) {
            if (!obj && url == objUrl)
                QCoreApplication::exit(-1);   // QML failed to load — exit
        },
        Qt::QueuedConnection
    );
    engine.load(url);   // Starts QML parsing and instantiation

    // ─── Step 11: Run the event loop ────────────────────────────────────────
    // app.exec() blocks here until the user closes the window.
    // All signals, slots, timers, and the 250ms progress timer run within this loop.
    return app.exec();
}
```

---

## 9.2 Why Stack Allocation?

```cpp
AudioEngine   audioEngine;     // Stack
LibraryScanner libraryScanner; // Stack
TrackModel    trackModel;      // Stack
```

All three backend objects are created on the stack (no `new`). This means:
- When `main()` returns, they are automatically destroyed in reverse order
- miniaudio and SQLite are properly cleaned up in destructors
- No risk of memory leaks

If they were heap-allocated (`new AudioEngine()`), we'd need `delete` or a smart pointer.

---

## 9.3 The Signal Connection in main.cpp

```cpp
QObject::connect(&libraryScanner, &LibraryScanner::tracksAdded,
                 &trackModel,     &TrackModel::setTracks);
```

This is the **only** inter-object connection made in `main.cpp`. Both objects are completely ignorant of each other — `LibraryScanner` doesn't `#include "track_model.h"` and vice versa. The coupling is established here, at the composition root.

This is the **dependency injection** / **Hollywood principle**: "Don't call us. We'll call you." The scanner just emits — it doesn't care who listens.

---

## 9.4 Context Properties vs. qmlRegisterType

There are two ways to expose C++ to QML:

| Method | What It Does | Example |
|--------|-------------|---------|
| `setContextProperty` | Exposes a **single instance** as a global name | `audioEngine.play()` |
| `qmlRegisterType` | Lets QML **create new instances** of a type | `MyType { }` in QML |
| `qmlRegisterUncreatableType` | Lets QML **hold a pointer** to a type but not create one | Used for `Equalizer*` |

We use `setContextProperty` for all three backend objects because there should be exactly **one** audio engine and **one** track model. QML doesn't need to create its own — it uses the single shared instance.

---

## 9.5 qputenv — Theme Configuration

```cpp
qputenv("QT_QUICK_CONTROLS_STYLE",              "Material");
qputenv("QT_QUICK_CONTROLS_MATERIAL_THEME",     "Dark");
qputenv("QT_QUICK_CONTROLS_MATERIAL_BACKGROUND", "#0a0a0c");
qputenv("QT_QUICK_CONTROLS_MATERIAL_ACCENT",     "Purple");
```

These **must** be set before `QApplication` is constructed. The Qt Quick Controls style system reads them during initialization. Setting them afterward has no effect.

Without these, if the user's OS is set to a Light theme, Qt would override the app's dark appearance. The `Dark` override ensures consistent appearance regardless of system theme.
