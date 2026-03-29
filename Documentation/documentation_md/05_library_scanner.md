# Chapter 5 — LibraryScanner: Tags, Database, and Background Threads

## 5.1 What LibraryScanner Does

`LibraryScanner` is the engine that:
1. Walks a directory tree looking for audio files (`.mp3`, `.flac`, `.wav`, `.m4a`, `.aac`, `.ogg`)
2. Reads metadata (tags) from each file using **TagLib**
3. Checks if each file has embedded cover art
4. Saves everything to an **SQLite database** for persistence
5. Emits signals so the rest of the app knows the library has changed

It does all of this **on a background thread** using `QtConcurrent::run` so the UI never freezes.

---

## 5.2 TagLib — Reading Music Metadata

A music file like an `.mp3` contains two things:
- The **audio data** (the actual sound, compressed with MP3/AAC/FLAC codec)
- **Tags** (metadata): artist, title, album, genre, track number, cover art, etc.

**TagLib** is a C++ library that can read (and write) these tags across all formats.

### Basic TagLib Usage
```cpp
#include <taglib/fileref.h>
#include <taglib/tag.h>

TagLib::FileRef f("/path/to/song.mp3");

if (!f.isNull() && f.tag()) {
    TagLib::Tag *tag = f.tag();
    QString title  = QString::fromStdWString(tag->title().toWString());
    QString artist = QString::fromStdWString(tag->artist().toWString());
    QString album  = QString::fromStdWString(tag->album().toWString());
    QString genre  = QString::fromStdWString(tag->genre().toWString());
}

if (f.audioProperties()) {
    int durationSeconds = f.audioProperties()->lengthInSeconds();
}
```

`TagLib::String` uses a wide-character encoding internally. We convert through `toWString()` then `QString::fromStdWString()` to safely handle Unicode characters (é, ü, 中文, etc.).

### Reading Track/Disc Numbers via PropertyMap

The simple `tag->track()` method may not always work for all formats. The `PropertyMap` is more reliable:

```cpp
TagLib::PropertyMap properties = f.file()->properties();

if (properties.contains("TRACKNUMBER") && !properties["TRACKNUMBER"].isEmpty()) {
    track.trackNumber = properties["TRACKNUMBER"].front().toInt();
} else {
    track.trackNumber = tag->track();  // fallback
}

if (properties.contains("DISCNUMBER") && !properties["DISCNUMBER"].isEmpty()) {
    track.discNumber = properties["DISCNUMBER"].front().toInt();
}
```

### Checking for Cover Art (Format-Specific)

Cover art detection requires format-specific TagLib classes:

```cpp
// MP3: looks for APIC (Attached Picture) ID3v2 frame
if (filePath.endsWith(".mp3", Qt::CaseInsensitive)) {
    TagLib::MPEG::File mpegFile(filePath.toUtf8().constData());
    if (mpegFile.hasID3v2Tag()) {
        auto frameList = mpegFile.ID3v2Tag()->frameListMap()["APIC"];
        if (!frameList.isEmpty()) hasArt = true;
    }
}
// FLAC: has its own picture list
else if (filePath.endsWith(".flac", Qt::CaseInsensitive)) {
    TagLib::FLAC::File flacFile(filePath.toUtf8().constData());
    if (flacFile.isValid() && !flacFile.pictureList().isEmpty()) hasArt = true;
}
// M4A/AAC: uses "covr" item in the MP4 tag
else if (filePath.endsWith(".m4a", Qt::CaseInsensitive)) {
    TagLib::MP4::File mp4File(filePath.toUtf8().constData());
    if (mp4File.isValid() && mp4File.tag()) {
        if (mp4File.tag()->itemMap().contains("covr")) hasArt = true;
    }
}
```

---

## 5.3 SQLite via Qt Sql — The Persistent Library Database

Without a database, every time you launch the app it would have to re-scan all your music. The database lets us remember what we already scanned.

### Database Initialization

```cpp
void LibraryScanner::initializeDatabase() {
    // Find a writable location on this platform (Linux: ~/.local/share/AppName/)
    QString dataDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dataDir);   // Create the directory if it doesn't exist

    QSqlDatabase db = QSqlDatabase::addDatabase("QSQLITE");   // Use SQLite driver
    db.setDatabaseName(dataDir + "/tracks.db");               // File path for the .db file

    if (db.open()) {
        QSqlQuery query;
        // CREATE TABLE IF NOT EXISTS means this is safe to run on every launch
        query.exec(
            "CREATE TABLE IF NOT EXISTS tracks ("
            "id INTEGER PRIMARY KEY AUTOINCREMENT, "
            "title TEXT, artist TEXT, album TEXT, genre TEXT, "
            "duration INTEGER, filePath TEXT UNIQUE, "   // UNIQUE prevents duplicate paths
            "hasCoverArt INTEGER, trackNumber INTEGER, discNumber INTEGER)"
        );
        // Migration patches — safe to run even if column already exists
        query.exec("ALTER TABLE tracks ADD COLUMN trackNumber INTEGER DEFAULT 0");
        query.exec("ALTER TABLE tracks ADD COLUMN discNumber INTEGER DEFAULT 0");
    }
}
```

`QStandardPaths::AppDataLocation` returns the correct platform path:
- Linux: `~/.local/share/MusicPlayer/`
- Windows: `C:\Users\<user>\AppData\Roaming\MusicPlayer\`

### Loading the Database on Startup

```cpp
void LibraryScanner::loadDatabase() {
    QVector<Track> loadedTracks;
    QSqlQuery query("SELECT title, artist, album, genre, duration, filePath, "
                    "hasCoverArt, trackNumber, discNumber FROM tracks");

    while (query.next()) {          // Iterate over rows
        Track t;
        t.title      = query.value(0).toString();
        t.artist     = query.value(1).toString();
        // ... etc
        loadedTracks.append(t);
    }

    if (!loadedTracks.isEmpty()) {
        // QTimer::singleShot(0, ...) defers the emit to the next event loop iteration
        // Needed because this may be called from the constructor, before anyone
        // has connected to the signal yet
        QTimer::singleShot(0, this, [this, loadedTracks]() {
            emit tracksAdded(loadedTracks);
        });
    }
}
```

### Inserting Scanned Tracks with a Transaction

```cpp
db.transaction();     // Begin a batch — much faster than individual INSERTs
QSqlQuery insertQuery(db);
insertQuery.prepare(
    "INSERT OR REPLACE INTO tracks "
    "(title, artist, album, genre, duration, filePath, hasCoverArt, trackNumber, discNumber) "
    "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
);

for (const Track &t : newTracks) {
    insertQuery.bindValue(0, t.title);
    insertQuery.bindValue(1, t.artist);
    // ...
    insertQuery.bindValue(5, t.filePath);
    insertQuery.exec();
}
db.commit();   // Commit all at once — 10x - 100x faster than commit per row
```

`INSERT OR REPLACE` means: if a row with this `filePath` already exists (UNIQUE constraint), replace it. This makes re-scanning idempotent.

---

## 5.4 Background Threading with QtConcurrent

File scanning can take seconds for a large library. Blocking the main (UI) thread would freeze the window. `QtConcurrent::run` sends the work to a thread pool:

```cpp
void LibraryScanner::scanDirectory(const QString &directoryPath) {
    emit scanStarted();   // Tell the UI to show a progress spinner

    QtConcurrent::run([this, path]() {
        // ⚠️ This lambda runs on a BACKGROUND THREAD
        // Do NOT call Qt UI functions here
        // Do NOT emit signals directly to QML-bound slots across threads (safe here because Qt queues them)

        QDirIterator it(path,
                        QStringList() << "*.mp3" << "*.flac" << "*.wav" << "*.m4a" << "*.aac" << "*.ogg",
                        QDir::Files, QDirIterator::Subdirectories);  // Recursive!

        int filesProcessed = 0;
        QVector<Track> newTracks;

        while (it.hasNext()) {
            QString filePath = it.next();
            // ... read tags, detect art ...
            newTracks.append(track);
            filesProcessed++;

            if (filesProcessed % 10 == 0) {
                emit scanProgress(filesProcessed);  // Update progress counter in UI
            }
        }

        // Write to database (uses a separate DB connection named "scanner_conn")
        // ...

        // When done, jump BACK to the main thread to emit the final signal
        QMetaObject::invokeMethod(this, [this, filesProcessed]() {
            loadDatabase();                          // Reload the clean database
            emit scanFinished(filesProcessed);       // Tell UI we're done
        }, Qt::QueuedConnection);                    // QueuedConnection = cross-thread safe
    });
}
```

### Why a Separate Database Connection?

SQLite is not thread-safe by default. If the background thread used the same `QSqlDatabase` connection as the main thread, it could corrupt data. The solution:

```cpp
// On background thread: create a named connection just for this thread
QSqlDatabase db = QSqlDatabase::addDatabase("QSQLITE", "scanner_conn");
db.setDatabaseName(dataDir + "/tracks.db");
// ... use it ...

// After the background thread finishes with it:
QSqlDatabase::removeDatabase("scanner_conn");  // Clean up the named connection
```

---

## 5.5 The `QDirIterator` — Recursive File Walk

```cpp
QDirIterator it(
    path,                                           // Root directory
    QStringList() << "*.mp3" << "*.flac" << "*.wav" << "*.m4a" << "*.aac" << "*.ogg",  // Name filters
    QDir::Files,                                    // Only find regular files (not dirs)
    QDirIterator::Subdirectories                    // Recurse into sub-folders
);

while (it.hasNext()) {
    QString filePath = it.next();   // Gets next matching file's full path
    // process filePath...
}
```

---

## 5.6 Signal Flow of a Complete Scan

```
User clicks "Scan Directory" in UI
         ↓
  QML calls: libraryScanner.scanDirectory(folderPath)
         ↓
  LibraryScanner::scanDirectory() emits scanStarted()
         ↓ (QML shows spinner popup)
  QtConcurrent::run launches background thread
         ↓ (background thread)
  Every 10 files: emit scanProgress(count)
         ↓ (QML updates "Found N tracks..." label)
  All files processed, inserted into DB
         ↓
  QMetaObject::invokeMethod → back to main thread
         ↓
  loadDatabase() → emit tracksAdded(allTracks)
         ↓ (connected to TrackModel::setTracks)
  TrackModel updates, QML ListView refreshes
         ↓
  emit scanFinished(total)
         ↓ (QML closes spinner popup)
```
