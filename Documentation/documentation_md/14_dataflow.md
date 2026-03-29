# Chapter 14 — Complete System Dataflow

This chapter ties everything together with detailed data flow diagrams covering the three major user journeys.

---

## 14.1 Application Startup Flow

```
Program starts → main() runs
│
├─ [TagLib] Silence debug output
│
├─ [Qt] Set Material Dark theme env vars
│
├─ QApplication app constructed
│
├─ qmlRegisterUncreatableType<Equalizer>
│   → QML can now reference Equalizer* without creating instances
│
├─ AudioEngine audioEngine constructed
│   ├─ ma_engine_init() → opens system audio device (PulseAudio/WASAPI)
│   ├─ Equalizer *eq = new Equalizer(this)
│   ├─ 10 x ma_peak_node_init() → EQ filter chain created
│   ├─ ma_node_attach() × 10 → chain linked: sound→EQ0→EQ1→...→EQ9→speaker
│   └─ QTimer starts (250ms interval)
│
├─ LibraryScanner libraryScanner constructed
│   ├─ initializeDatabase() → opens/creates tracks.db SQLite file
│   └─ loadDatabase() → reads all rows, queues emit tracksAdded()
│
├─ TrackModel trackModel constructed
│
├─ connect(libraryScanner.tracksAdded → trackModel.setTracks)
│
├─ QQmlApplicationEngine engine constructed
│
├─ engine.addImageProvider("musiccover", new CoverArtProvider)
│
├─ engine.rootContext()->setContextProperty × 3
│   → "audioEngine", "libraryScanner", "trackModel" now in QML global scope
│
├─ engine.load("qrc:/qml/main.qml")
│   ├─ Qt parses main.qml, creates ApplicationWindow
│   ├─ ApplicationWindow creates LibraryView (embedded)
│   │   └─ LibraryView.StackView.initialItem = trackGridComponent
│   ├─ LibraryView trackGridComponent: model = trackModel (bound)
│   └─ QML engine completes
│
└─ app.exec() → Event loop begins
    │
    └─ QTimer fires (from loadDatabase's singleShot):
        tracksAdded(allTracks) → trackModel.setTracks(allTracks)
        → beginResetModel → endResetModel
        → LibraryView GridView refreshes (shows all cached tracks)
```

---

## 14.2 "Scan Directory" Flow

```
User: clicks hamburger menu → "Scan Directory"
│
├─ [QML] mainMenuPopup.close()
├─ [QML] folderDialog.open()
│
│  [User selects /home/user/music in the OS folder picker]
│
├─ [QML] folderDialog.onAccepted:
│       libraryScanner.scanDirectory(folderDialog.folder)
│                        ↓ (C++ slot called from QML)
│
├─ [C++] LibraryScanner::scanDirectory(path)
│   ├─ emit scanStarted()
│   │       ↓ [QML Connections.onScanStarted]
│   │       scanningPopup.open()  — shows spinner
│   │
│   └─ QtConcurrent::run([this, path]() {   // BACKGROUND THREAD
│           QDirIterator walks every subdir
│           │
│           For each .mp3/.flac/.wav/.m4a found:
│           │   TagLib::FileRef reads tags
│           │   Check cover art (format-specific code)
│           │   Build Track struct
│           │   newTracks.append(track)
│           │   filesProcessed++
│           │
│           │   if (filesProcessed % 10 == 0):
│           │       emit scanProgress(filesProcessed)
│           │               ↓ [QML Connections.onScanProgress]
│           │               scanningLabel.text = "Found N tracks..."
│           │
│           Write newTracks to tracks.db (SQLite transaction)
│           │
│           QMetaObject::invokeMethod(Qt::QueuedConnection):
│               → jumps back to main thread
│               loadDatabase()
│                   → reads all rows from DB
│                   → emit tracksAdded(allTracks)
│                           ↓ [connect in main.cpp]
│                   trackModel.setTracks(allTracks)
│                       beginResetModel
│                       sort by artist/album/disc/track
│                       rebuild displayIndices
│                       endResetModel
│                               ↓
│                   LibraryView GridView refreshes automatically
│               emit scanFinished(total)
│                       ↓ [QML Connections.onScanFinished]
│                   scanningPopup.close()
```

---

## 14.3 "Play a Song" Flow

```
User: clicks a track tile in LibraryView
│
├─ [QML] MouseArea.onClicked:
│       window.playTrackAtIndex(index, "All Tracks")
│
├─ [QML function] playTrackAtIndex(5, "All Tracks")
│   ├─ contextCategory is set → rebuild queue
│   │   for (i = 0..trackModel.rowCount()-1):
│   │       playbackQueue.push(trackModel.get(i))
│   │   currentQueueIndex = 5
│   │
│   ├─ var track = playbackQueue[5]
│   ├─ window.currentPlayingTitle  = track.title
│   ├─ window.currentPlayingArtist = track.artist
│   ├─ window.currentPlayingPath   = track.filePath
│   │       ↓ (all QML text bound to these auto-updates)
│   │
│   ├─ audioEngine.loadFile(track.filePath) — calls C++ slot
│   │       ↓ (AudioEngine::loadFile)
│   │       ma_sound_uninit (previous)
│   │       ma_sound_init_from_file (new file, ASYNC decode)
│   │       ma_node_attach(sound → eqNodes[0])
│   │       emit durationChanged(length)   → QML Slider.to updates
│   │       emit positionChanged(0)        → QML Slider.value resets
│   │
│   └─ audioEngine.play() — calls C++ slot
│           ↓ (AudioEngine::play)
│           ma_sound_start(&m_sound)
│           emit playingChanged(true)
│                   ↓ [Q_PROPERTY NOTIFY]
│           QML: audioEngine.isPlaying = true
│           Play/Pause button icon changes to "pause.svg"
│
│ [250ms timer fires repeatedly while playing]
│   AudioEngine timer callback:
│   ├─ ma_sound_at_end? → emit playbackFinished() → auto-advance
│   └─ isPlaying? → emit positionChanged(cursor)
│                           ↓ [Q_PROPERTY NOTIFY]
│               QML: Slider.value = audioEngine.position
│               QML: Time labels update
```

---

## 14.4 "Seek to Position" Flow

```
User: drags the progress slider to new position

[QML Slider.onMoved]
    audioEngine.position = value
         ↓ (Q_PROPERTY WRITE: calls setPosition)

[C++ AudioEngine::setPosition(newPos)]
    ma_engine_get_sample_rate → sampleRate
    targetFrame = newPos × sampleRate
    ma_sound_seek_to_pcm_frame(&m_sound, targetFrame)
    emit positionChanged(newPos)
         ↓ (Q_PROPERTY NOTIFY)
    [QML] Slider.value and time labels update to confirm the seek
```

---

## 14.5 "Change EQ Band" Flow

```
User: moves EQ slider for band 5 (1kHz)

[QML EqualizerView Slider.onMoved]
    eq.setBandGain(5, newValue)  — Q_INVOKABLE direct call
         ↓

[C++ Equalizer::setBandGain(5, newValue)]
    clampedValue = clamp(newValue, -12, 12)
    m_gains[5] = clampedValue
    emit bandGainChanged(5, clampedValue)
         ↓ (connect in AudioEngine constructor)

[C++ AudioEngine::onEqualizerBandGainChanged(5, clampedValue)]
    actualGain = eq->isEnabled() ? clampedValue : 0.0f
    ma_peak2_config cfg = ma_peak2_config_init(f32, ch, sr, actualGain, 1.414, 1000Hz)
    ma_peak_node_reinit(&m_eqNodes[5], &cfg)
         ↓
    Audio pipeline filter coefficients update instantly
    Users hears the frequency change in real time

[QML EqualizerView gain label]
    text: eq.bandGain(5)  → reads new value → shows "+3.0 dB"
    (updates because Slider.onMoved triggers re-read via binding)
```

---

## 14.6 Class Dependency Map

```
main.cpp
  ├── creates: AudioEngine
  │       owns: Equalizer (child QObject)
  │       uses: miniaudio (ma_engine, ma_sound, ma_peak_node[10])
  │       uses: QTimer (250ms heartbeat)
  │
  ├── creates: LibraryScanner
  │       uses: TagLib (reads tags)
  │       uses: QSqlDatabase (SQLite persistence)
  │       uses: QtConcurrent (background threads)
  │       uses: QDirIterator (filesystem walk)
  │
  ├── creates: TrackModel
  │       contains: QVector<Track> (all tracks in memory)
  │       contains: QVector<int> (display filter indices)
  │
  ├── connects: LibraryScanner.tracksAdded → TrackModel.setTracks
  │
  ├── exposes via setContextProperty:
  │       "audioEngine"    → AudioEngine*
  │       "libraryScanner" → LibraryScanner*
  │       "trackModel"     → TrackModel*
  │
  └── registers: CoverArtProvider under "musiccover"
                       uses: TagLib (reads embedded images)
                       uses: QImage (decodes JPEG/PNG bytes)
```
