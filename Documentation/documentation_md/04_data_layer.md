# Chapter 4 — The Data Layer: Track, TrackModel, QAbstractListModel

## 4.1 The `Track` Struct — The Atom of the Music Library

Everything in this app revolves around one simple plain-data struct:

```cpp
// include/track.h
#ifndef TRACK_H
#define TRACK_H

#include <QString>

struct Track {
    QString filePath;       // Absolute path: "/home/user/music/song.mp3"
    QString title;          // "Bohemian Rhapsody"
    QString artist;         // "Queen"
    QString album;          // "A Night at the Opera"
    QString genre;          // "Rock"
    int duration{0};        // Duration in seconds (e.g., 354)
    bool hasCoverArt{false};// Does the file have an embedded album image?
    int trackNumber{0};     // Track # on disc (1, 2, 3...)
    int discNumber{0};      // Disc number for multi-disc albums
};

#endif // TRACK_H
```

This is a **plain struct** — no QObject, no signals, no methods. It is a pure data container. The `{0}` and `{false}` are **in-class member initializers** (C++11), meaning the values default to zero/false if not set.

`QVector<Track>` is then the fundamental collection: the entire music library is a vector of these structs.

---

## 4.2 Why We Need a Custom Qt Model

QML's `ListView` and `Repeater` need data to come from a **Qt Model**. You can't just hand QML a raw `QVector<Track>` — it wouldn't know how to read from it.

Qt provides `QAbstractListModel` as the base class for list data models. You subclass it and override three methods, and QML can automatically bind to it.

---

## 4.3 TrackModel — The Full Class

### Header: `include/track_model.h`

```cpp
#include "track.h"
#include <QAbstractListModel>
#include <QVector>

class TrackModel : public QAbstractListModel {
    Q_OBJECT

public:
    // Step 1: Define "roles" — these are like column names in a table
    enum TrackRoles {
        TitleRole    = Qt::UserRole + 1,  // Qt::UserRole = 256, so TitleRole = 257
        ArtistRole,                        // 258
        AlbumRole,                         // 259
        GenreRole,                         // 260
        DurationRole,                      // 261
        FilePathRole,                      // 262
        HasCoverArtRole                    // 263
    };

    explicit TrackModel(QObject *parent = nullptr);

    // Step 2: Override the three mandatory virtual methods
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    // Step 3: Add useful extras
    Q_INVOKABLE QVariantMap get(int row) const;   // Get a whole row as a JS object
    void setTracks(const QVector<Track> &tracks); // Replace all tracks
    void addTracks(const QVector<Track> &tracks); // Append tracks

public slots:
    void filterAll();
    void filterByArtist(const QString &artist);
    void filterByAlbum(const QString &album);
    void filterByFolder(const QString &folder);
    void filterByCollection(const QString &collection);

    Q_INVOKABLE QVariantList getArtistTiles() const;
    Q_INVOKABLE QVariantList getAlbumTiles() const;
    Q_INVOKABLE QVariantList getFolderTiles() const;
    Q_INVOKABLE QVariantList getCollectionTiles() const;

private:
    QString getCommonRootPath() const;
    void updateDisplayIndices(std::function<bool(const Track &)> predicate);

    QVector<Track> m_allTracks;        // ALL tracks ever loaded
    QVector<int>   m_displayIndices;   // INDICES of tracks currently shown
};
```

### The Two-Array Design Explained

The key architectural decision is the separation of `m_allTracks` and `m_displayIndices`:

```
m_allTracks:       [ Track0, Track1, Track2, Track3, Track4 ]
                      idx=0   idx=1   idx=2   idx=3   idx=4

filterByArtist("Queen"):
m_displayIndices:  [ 1, 3 ]    ← only tracks at index 1 and 3 are "Queen"

QML sees a list of 2 items:
  - Row 0 → m_allTracks[1]
  - Row 1 → m_allTracks[3]
```

This design means **filtering is free** — we never copy or delete tracks, just change which indices are visible. The full library is always in memory.

---

## 4.4 Implementing the Three Mandatory Methods

### `rowCount` — How Many Rows?

```cpp
int TrackModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid())   // For a list (not tree), parent is always invalid
        return 0;
    return m_displayIndices.count();  // Only show filtered items
}
```

### `data` — What Is In Row N?

```cpp
QVariant TrackModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= m_displayIndices.count())
        return QVariant();  // Invalid row → return empty

    // Translate display index → actual track index
    int actualIndex = m_displayIndices[index.row()];
    const Track &track = m_allTracks[actualIndex];

    switch (role) {
    case TitleRole:      return track.title;
    case ArtistRole:     return track.artist;
    case AlbumRole:      return track.album;
    case GenreRole:      return track.genre;
    case DurationRole:   return track.duration;
    case FilePathRole:   return track.filePath;
    case HasCoverArtRole: return track.hasCoverArt;
    }

    return QVariant();
}
```

`QVariant` is Qt's universal value type — it can hold a string, int, bool, list, or map. QML knows how to automatically unpack them.

### `roleNames` — The Mapping from ID to Name

```cpp
QHash<int, QByteArray> TrackModel::roleNames() const {
    QHash<int, QByteArray> roles;
    roles[TitleRole]      = "title";
    roles[ArtistRole]     = "artist";
    roles[AlbumRole]      = "album";
    roles[GenreRole]      = "genre";
    roles[DurationRole]   = "duration";
    roles[FilePathRole]   = "filePath";
    roles[HasCoverArtRole] = "hasCoverArt";
    return roles;
}
```

This mapping is the bridge to QML. After this, in QML you can write:
```qml
ListView {
    model: trackModel    // the C++ TrackModel exposed via context property
    delegate: Text {
        text: title + " - " + artist   // "title" maps to TitleRole automatically
    }
}
```

---

## 4.5 Filtering — How It Works

```cpp
// Generic helper: takes a function that returns true/false for each track
void TrackModel::updateDisplayIndices(std::function<bool(const Track &)> predicate) {
    beginResetModel();           // Tell QML: "about to change everything"
    m_displayIndices.clear();
    for (int i = 0; i < m_allTracks.size(); ++i) {
        if (predicate(m_allTracks[i])) {
            m_displayIndices.append(i);
        }
    }
    endResetModel();             // Tell QML: "done, re-read everything"
}

// Show all tracks
void TrackModel::filterAll() {
    updateDisplayIndices([](const Track &) { return true; });
}

// Show only tracks by a specific artist
void TrackModel::filterByArtist(const QString &artist) {
    updateDisplayIndices([artist](const Track &t) { return t.artist == artist; });
}
```

`beginResetModel()` / `endResetModel()` are critical — they tell any attached QML `ListView` to stop reading data, wait for the update, then refresh itself. Without these, the UI would show stale or corrupt data.

---

## 4.6 The `get()` Method — Exporting a Full Row to QML

```cpp
QVariantMap TrackModel::get(int row) const {
    QVariantMap map;
    QModelIndex idx = index(row, 0);
    if (!idx.isValid()) return map;

    QHash<int, QByteArray> roles = roleNames();
    for (auto it = roles.begin(); it != roles.end(); ++it) {
        map.insert(QString::fromUtf8(it.value()), data(idx, it.key()));
    }
    return map;
}
```

This converts a row into a `QVariantMap`, which QML sees as a JavaScript object:
```qml
// In main.qml, building the playback queue:
for (var i = 0; i < trackModel.rowCount(); i++) {
    newQueue.push(trackModel.get(i));  // push JS objects into queue array
}
// Then access: queue[0].title, queue[0].filePath, queue[0].hasCoverArt
```

---

## 4.7 Sorting Logic in `setTracks`

When tracks are first loaded, they are sorted:

```cpp
std::sort(m_allTracks.begin(), m_allTracks.end(),
          [](const Track &a, const Track &b) {
              if (a.artist == b.artist) {
                  if (a.album == b.album) {
                      if (a.discNumber != b.discNumber)
                          return a.discNumber < b.discNumber;
                      if (a.trackNumber != b.trackNumber)
                          return a.trackNumber < b.trackNumber;
                      return a.title < b.title;
                  }
                  return a.album < b.album;
              }
              return a.artist < b.artist;
          });
```

Priority: **Artist → Album → Disc → Track Number → Title**. This ensures albums appear in the natural CD track order.

---

## 4.8 Tile Queries — Getting Unique Artists/Albums

The UI shows "Artist Tiles" (one tile per unique artist). `getArtistTiles()` produces this:

```cpp
QVariantList TrackModel::getArtistTiles() const {
    QVariantList list;
    QSet<QString> seenArtists;          // Set ensures uniqueness
    for (const auto &t : qAsConst(m_allTracks)) {
        if (t.artist.isEmpty() || seenArtists.contains(t.artist))
            continue;
        seenArtists.insert(t.artist);
        QVariantMap map;
        map["name"]       = t.artist;
        map["hasCoverArt"] = t.hasCoverArt;
        map["filePath"]   = t.filePath;  // Use this track's art to represent the artist
        list.append(map);
    }
    return list;
}
```

QML receives a JavaScript array of objects: `[ {name: "Queen", hasCoverArt: true, filePath: "..."}, ... ]`.
