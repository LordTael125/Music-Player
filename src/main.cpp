#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlEngine>

#include "audio_engine.h"
#include "cover_art_provider.h"
#include "library_scanner.h"
#include "track_model.h"

// TagLib includes
#include <taglib/tdebuglistener.h>

class SilentTagLibListener : public TagLib::DebugListener {
public:
  void printMessage(const TagLib::String &msg) override {
    // Suppress TagLib debug and warning messages from polluting the console
  }
};

int main(int argc, char *argv[]) {
  // Silence TagLib
  static SilentTagLibListener silentListener;
  TagLib::setDebugListener(&silentListener);
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
  QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
#endif

  // Hardcode the QML Material Dark theme explicitly to prevent OS Light-theme
  // overrides
  qputenv("QT_QUICK_CONTROLS_STYLE", "Material");
  qputenv("QT_QUICK_CONTROLS_MATERIAL_THEME", "Dark");
  qputenv("QT_QUICK_CONTROLS_MATERIAL_BACKGROUND", "#0a0a0c");
  qputenv("QT_QUICK_CONTROLS_MATERIAL_ACCENT", "Purple");

  // Application metadata for QSettings
  QCoreApplication::setOrganizationName("LordTael");
  QCoreApplication::setOrganizationDomain("lordtael.com");
  QCoreApplication::setApplicationName("ModernMusicPlayer");

  QApplication app(argc, argv);

  // Register Equalizer structure for QML so it can interact with the pointer
  // correctly
  qmlRegisterUncreatableType<Equalizer>("com.musicplayer", 1, 0, "Equalizer",
                                        "Equalizer cannot be created in QML");

  // Core Backend instances
  AudioEngine audioEngine;
  LibraryScanner libraryScanner;
  TrackModel trackModel;

  // Connect scanner to model
  QObject::connect(&libraryScanner, &LibraryScanner::tracksAdded, &trackModel,
                   &TrackModel::setTracks);

  QQmlApplicationEngine engine;
  engine.addImageProvider(QLatin1String("musiccover"), new CoverArtProvider);

  // Provide these to QML
  engine.rootContext()->setContextProperty("audioEngine", &audioEngine);
  engine.rootContext()->setContextProperty("libraryScanner", &libraryScanner);
  engine.rootContext()->setContextProperty("trackModel", &trackModel);

  const QUrl url(QStringLiteral("qrc:/qml/main.qml"));
  QObject::connect(
      &engine, &QQmlApplicationEngine::objectCreated, &app,
      [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
          QCoreApplication::exit(-1);
      },
      Qt::QueuedConnection);
  engine.load(url);

  return app.exec();
}
