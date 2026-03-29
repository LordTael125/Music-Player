# Chapter 3 — Qt C++ Foundations

Before reading the individual class chapters, you must understand the four pillars of Qt programming that this project relies on heavily.

---

## 3.1 Pillar 1: QObject — The Base of Everything

Every meaningful class in this project inherits from `QObject`. This is not optional — `QObject` is what gives a class access to signals, slots, and properties.

```cpp
// A minimal QObject subclass
#include <QObject>

class MyClass : public QObject {
    Q_OBJECT   // MANDATORY macro — must be the first line inside the class
public:
    explicit MyClass(QObject *parent = nullptr);  // parent pointer: memory management
};
```

### The Parent-Child Memory Model
Qt uses a **parent-child ownership tree**. When a parent `QObject` is destroyed, it automatically destroys all its children:

```cpp
AudioEngine audioEngine;                    // parent = nullptr (stack-allocated)
Equalizer *eq = new Equalizer(&audioEngine); // eq's parent = &audioEngine
// When audioEngine is destroyed, eq is automatically deleted too
```

This means you rarely call `delete` manually in Qt code. **Always pass a parent** when heap-allocating a `QObject`.

---

## 3.2 Pillar 2: Signals and Slots

This is Qt's event system. It lets completely unrelated objects communicate **without knowing about each other directly**.

### Declaring Signals
```cpp
class AudioEngine : public QObject {
    Q_OBJECT
signals:
    void playingChanged(bool isPlaying);   // "something happened"
    void positionChanged(float position);   // "my state changed"
    void playbackFinished();               // "event occurred"
};
```
Signals are **declared** but **never defined** — Qt's `moc` tool generates the implementation automatically.

### Declaring Slots
```cpp
class TrackModel : public QAbstractListModel {
    Q_OBJECT
public slots:
    void setTracks(const QVector<Track> &tracks);   // can be connected to a signal
    void filterByArtist(const QString &artist);
};
```

### Connecting Them
```cpp
// In main.cpp:
QObject::connect(&libraryScanner, &LibraryScanner::tracksAdded,
                 &trackModel,     &TrackModel::setTracks);
```

Now whenever `libraryScanner` emits `tracksAdded(someVector)`, Qt automatically calls `trackModel.setTracks(someVector)`. The two objects don't know each other — they are loosely coupled.

### Emitting a Signal
```cpp
void AudioEngine::play() {
    ma_sound_start(&m_sound);
    emit playingChanged(true);  // "emit" keyword triggers all connected slots
}
```

### Thread Safety
Qt signals and slots are thread-safe when the objects involved live on different threads. Qt automatically queues the call across thread boundaries using `Qt::QueuedConnection`. This is used in `LibraryScanner` — scanning happens on a background thread, but `tracksAdded` is safely delivered to the main thread.

---

## 3.3 Pillar 3: Q_PROPERTY — The Bridge to QML

`Q_PROPERTY` is what makes a C++ class member accessible from QML as if it were a JavaScript property.

```cpp
class AudioEngine : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool  isPlaying READ isPlaying          NOTIFY playingChanged)
    Q_PROPERTY(float position  READ position  WRITE setPosition NOTIFY positionChanged)
    Q_PROPERTY(float volume    READ volume    WRITE setVolume    NOTIFY volumeChanged)
    Q_PROPERTY(float duration  READ duration            NOTIFY durationChanged)
    Q_PROPERTY(Equalizer* equalizer READ equalizer CONSTANT)
```

Each `Q_PROPERTY` declares:
- **Type** — `bool`, `float`, pointer, etc.
- **Name** — the name visible in QML (e.g., `audioEngine.isPlaying`)
- **READ** — which C++ getter to call
- **WRITE** *(optional)* — which C++ setter to call (makes it writable from QML)
- **NOTIFY** — which signal fires when the value changes (enables QML data binding)
- **CONSTANT** *(optional)* — no setter, no notify needed (value never changes)

In QML you can then write:
```qml
// Binding: this text updates automatically whenever positionChanged fires
Text { text: audioEngine.position.toFixed(1) + " sec" }

// Write through the WRITE setter
Slider { onMoved: audioEngine.position = value }

// Read a CONSTANT property
audioEngine.equalizer.bandGain(0)
```

---

## 3.4 Pillar 4: Q_INVOKABLE — Calling C++ Functions from QML

`Q_PROPERTY` lets QML read/write values. But sometimes QML needs to **call a function**:

```cpp
class Equalizer : public QObject {
    Q_OBJECT
public:
    Q_INVOKABLE int          bandCount() const;
    Q_INVOKABLE float        bandGain(int index) const;
    Q_INVOKABLE float        bandFrequency(int index) const;
    Q_INVOKABLE QStringList  getPresetNames() const;
    Q_INVOKABLE void         loadPreset(const QString &name);
    Q_INVOKABLE void         saveCustomPreset(const QString &name);
    Q_INVOKABLE void         deleteCustomPreset(const QString &name);
    Q_INVOKABLE bool         isCustomPreset(const QString &name) const;
};
```

Adding `Q_INVOKABLE` before a method makes it callable from QML:
```qml
// In EqualizerView.qml:
var freq = audioEngine.equalizer.bandFrequency(0)   // calls C++ directly
audioEngine.equalizer.loadPreset("Rock")
```

Public slots can also be called from QML without `Q_INVOKABLE`. `Q_INVOKABLE` is preferred for const functions or ones that don't need slot semantics.

---

## 3.5 QString — Qt's String Class

Qt programs almost never use `std::string`. They use `QString`:

```cpp
QString name = "Unknown Artist";
QString path = filePath.toUtf8();   // convert to UTF-8 QByteArray

// Concatenation
QString display = track.title + " - " + track.artist;

// Check contents
if (track.title.isEmpty()) { ... }
if (filePath.endsWith(".mp3", Qt::CaseInsensitive)) { ... }
if (filePath.startsWith("file://")) { ... }

// Convert between Qt and standard types
std::string std_str = qtString.toStdString();
QString fromStd = QString::fromStdString(std_str);
QString fromWide = QString::fromStdWString(wideStr);  // used for TagLib
```

---

## 3.6 QVector — Qt's Dynamic Array

Like `std::vector` but Qt-flavored:

```cpp
QVector<Track> m_allTracks;    // holds Track structs
QVector<int>   m_displayIndices; // integer indices into m_allTracks

m_allTracks.append(newTrack);
m_allTracks.size();            // number of elements
m_allTracks[i];                // element access (same as std::vector)
m_allTracks.clear();           // remove all

// Range-based for loop
for (const Track &t : qAsConst(m_allTracks)) {
    // qAsConst prevents detach (copy-on-write optimization)
}
```

---

## 3.7 Lambda Functions in Qt

Modern Qt (C++11 and above) uses lambdas extensively for one-off callbacks:

```cpp
// Timer callback
connect(&m_progressTimer, &QTimer::timeout, this, [this]() {
    if (m_soundLoaded && isPlaying()) {
        emit positionChanged(position());  // update QML every 250ms
    }
});

// QtConcurrent background task
QtConcurrent::run([this, path]() {
    // This runs on a background thread
    // "this" and "path" are captured by value/reference
    QDirIterator it(path, ...);
    ...
});
```

`[this, path]` is the **capture list** — variables from the outer scope that the lambda can use:
- `[this]` — capture the object pointer so you can call `emit`, access members
- `[=]` — capture everything by value (copy)
- `[&]` — capture everything by reference (dangerous if the lambda outlives the scope)
