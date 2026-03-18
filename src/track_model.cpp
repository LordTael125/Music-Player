#include "track_model.h"
#include <QDir>
#include <QFileInfo>
#include <QSet>
#include <algorithm>

TrackModel::TrackModel(QObject *parent) : QAbstractListModel(parent) {}

int TrackModel::rowCount(const QModelIndex &parent) const {
  if (parent.isValid())
    return 0;
  return m_displayIndices.count();
}

QVariant TrackModel::data(const QModelIndex &index, int role) const {
  if (!index.isValid() || index.row() >= m_displayIndices.count())
    return QVariant();

  int actualIndex = m_displayIndices[index.row()];
  const Track &track = m_allTracks[actualIndex];

  switch (role) {
  case TitleRole:
    return track.title;
  case ArtistRole:
    return track.artist;
  case AlbumRole:
    return track.album;
  case GenreRole:
    return track.genre;
  case DurationRole:
    return track.duration;
  case FilePathRole:
    return track.filePath;
  case HasCoverArtRole:
    return track.hasCoverArt;
  }

  return QVariant();
}

QHash<int, QByteArray> TrackModel::roleNames() const {
  QHash<int, QByteArray> roles;
  roles[TitleRole] = "title";
  roles[ArtistRole] = "artist";
  roles[AlbumRole] = "album";
  roles[GenreRole] = "genre";
  roles[DurationRole] = "duration";
  roles[FilePathRole] = "filePath";
  roles[HasCoverArtRole] = "hasCoverArt";
  return roles;
}

QVariantMap TrackModel::get(int row) const {
  QVariantMap map;
  QModelIndex idx = index(row, 0);
  if (!idx.isValid())
    return map;

  QHash<int, QByteArray> roles = roleNames();
  for (auto it = roles.begin(); it != roles.end(); ++it) {
    map.insert(QString::fromUtf8(it.value()), data(idx, it.key()));
  }
  return map;
}

QVariantMap TrackModel::getTrackByPath(const QString &filePath) const {
  QVariantMap map;
  for (const auto &track : m_allTracks) {
    if (track.filePath == filePath) {
      map.insert("title", track.title);
      map.insert("artist", track.artist);
      map.insert("album", track.album);
      map.insert("genre", track.genre);
      map.insert("duration", track.duration);
      map.insert("filePath", track.filePath);
      map.insert("hasCoverArt", track.hasCoverArt);
      return map;
    }
  }
  return map;
}


void TrackModel::setTracks(const QVector<Track> &tracks) {
  beginResetModel();
  m_allTracks = tracks;

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

  m_displayIndices.clear();
  for (int i = 0; i < m_allTracks.size(); ++i) {
    m_displayIndices.append(i);
  }
  endResetModel();
}

void TrackModel::addTracks(const QVector<Track> &tracks) {
  if (tracks.isEmpty())
    return;

  beginInsertRows(QModelIndex(), m_displayIndices.count(),
                  m_displayIndices.count() + tracks.size() - 1);
  int startIndex = m_allTracks.size();
  m_allTracks.append(tracks);
  for (int i = 0; i < tracks.size(); ++i) {
    m_displayIndices.append(startIndex + i);
  }
  endInsertRows();
}

void TrackModel::updateDisplayIndices(
    std::function<bool(const Track &)> predicate) {
  beginResetModel();
  m_displayIndices.clear();
  for (int i = 0; i < m_allTracks.size(); ++i) {
    if (predicate(m_allTracks[i])) {
      m_displayIndices.append(i);
    }
  }
  endResetModel();
}

void TrackModel::filterAll() {
  updateDisplayIndices([](const Track &) { return true; });
}

void TrackModel::filterByArtist(const QString &artist) {
  updateDisplayIndices([artist](const Track &t) { return t.artist == artist; });
}

void TrackModel::filterByAlbum(const QString &album) {
  updateDisplayIndices([album](const Track &t) { return t.album == album; });
}

QVariantList TrackModel::getArtistTiles() const {
  QVariantList list;
  QSet<QString> seenArtists;
  for (const auto &t : qAsConst(m_allTracks)) {
    if (t.artist.isEmpty() || seenArtists.contains(t.artist))
      continue;
    seenArtists.insert(t.artist);
    QVariantMap map;
    map["name"] = t.artist;
    map["hasCoverArt"] = t.hasCoverArt;
    map["filePath"] = t.filePath; // Serve up an initial track's cover
    list.append(map);
  }
  return list;
}

QVariantList TrackModel::getAlbumTiles() const {
  QVariantList list;
  QSet<QString> seenAlbums;
  for (const auto &t : qAsConst(m_allTracks)) {
    if (t.album.isEmpty() || seenAlbums.contains(t.album))
      continue;
    seenAlbums.insert(t.album);
    QVariantMap map;
    map["name"] = t.album;
    map["artist"] = t.artist;
    map["hasCoverArt"] = t.hasCoverArt;
    map["filePath"] = t.filePath;
    list.append(map);
  }
  return list;
}

void TrackModel::filterByFolder(const QString &folder) {
  beginResetModel();
  m_displayIndices.clear();

  for (int i = 0; i < m_allTracks.size(); ++i) {
    if (QFileInfo(m_allTracks[i].filePath).absolutePath() == folder) {
      m_displayIndices.append(i);
    }
  }

  // Sort by track number exclusively to group Various Artists by original CD
  // placement
  std::sort(m_displayIndices.begin(), m_displayIndices.end(),
            [this](int a, int b) {
              const Track &ta = m_allTracks[a];
              const Track &tb = m_allTracks[b];
              if (ta.trackNumber != tb.trackNumber)
                return ta.trackNumber < tb.trackNumber;
              return ta.title < tb.title;
            });

  endResetModel();
}

QVariantList TrackModel::getFolderTiles() const {
  QVariantList list;
  QSet<QString> seenFolders;
  for (const auto &t : qAsConst(m_allTracks)) {
    QFileInfo fi(t.filePath);
    QString folderPath = fi.absolutePath();
    if (seenFolders.contains(folderPath))
      continue;
    seenFolders.insert(folderPath);
    QVariantMap map;
    map["name"] = fi.dir().dirName();
    map["path"] = folderPath;
    map["hasCoverArt"] = t.hasCoverArt;
    map["filePath"] = t.filePath;
    list.append(map);
  }
  return list;
}

QString TrackModel::getCommonRootPath() const {
  if (m_allTracks.isEmpty())
    return QString();

  QStringList commonParts =
      m_allTracks[0].filePath.split('/', Qt::SkipEmptyParts);
  if (!commonParts.isEmpty())
    commonParts.removeLast(); // remove filename

  for (int i = 1; i < m_allTracks.size(); ++i) {
    QStringList parts = m_allTracks[i].filePath.split('/', Qt::SkipEmptyParts);
    if (!parts.isEmpty())
      parts.removeLast();

    int minLen = std::min(commonParts.size(), parts.size());
    int matchLen = 0;
    while (matchLen < minLen && commonParts[matchLen] == parts[matchLen]) {
      matchLen++;
    }
    while (commonParts.size() > matchLen) {
      commonParts.removeLast();
    }
  }

  if (commonParts.isEmpty()) {
    return "/";
  }
  return "/" + commonParts.join('/') + "/";
}

QVariantList TrackModel::getCollectionTiles() const {
  QVariantList list;
  QSet<QString> seenCollections;
  QString commonRoot = getCommonRootPath();

  for (const auto &t : qAsConst(m_allTracks)) {
    QString relPath = t.filePath;
    if (relPath.startsWith(commonRoot)) {
      relPath = relPath.mid(commonRoot.length());
    } else if (relPath.startsWith("/")) {
      relPath = relPath.mid(1); // fallback
    }

    QString collectionName = relPath.section('/', 0, 0);
    if (collectionName.isEmpty())
      continue;

    if (collectionName.endsWith(".mp3", Qt::CaseInsensitive) ||
        collectionName.endsWith(".flac", Qt::CaseInsensitive) ||
        collectionName.endsWith(".m4a", Qt::CaseInsensitive) ||
        collectionName.endsWith(".wav", Qt::CaseInsensitive)) {
      collectionName = "Root Audio Files";
    }

    if (seenCollections.contains(collectionName))
      continue;
    seenCollections.insert(collectionName);

    QVariantMap map;
    map["name"] = collectionName;
    map["hasCoverArt"] = t.hasCoverArt;
    map["filePath"] = t.filePath;
    list.append(map);
  }
  return list;
}

void TrackModel::filterByCollection(const QString &collection) {
  QString commonRoot = getCommonRootPath();

  beginResetModel();
  m_displayIndices.clear();

  for (int i = 0; i < m_allTracks.size(); ++i) {
    const Track &t = m_allTracks[i];
    QString relPath = t.filePath;
    if (relPath.startsWith(commonRoot)) {
      relPath = relPath.mid(commonRoot.length());
    } else if (relPath.startsWith("/")) {
      relPath = relPath.mid(1);
    }

    QString collectionName = relPath.section('/', 0, 0);
    if (collectionName.endsWith(".mp3", Qt::CaseInsensitive) ||
        collectionName.endsWith(".flac", Qt::CaseInsensitive) ||
        collectionName.endsWith(".m4a", Qt::CaseInsensitive) ||
        collectionName.endsWith(".wav", Qt::CaseInsensitive)) {
      collectionName = "Root Audio Files";
    }

    if (collectionName == collection) {
      m_displayIndices.append(i);
    }
  }

  // Sort globally by absolute Path (SubDirectory chaining) then by native
  // TrackNumber
  std::sort(m_displayIndices.begin(), m_displayIndices.end(),
            [this](int a, int b) {
              const Track &ta = m_allTracks[a];
              const Track &tb = m_allTracks[b];
              QFileInfo fiA(ta.filePath);
              QFileInfo fiB(tb.filePath);
              QString dirA = fiA.absolutePath();
              QString dirB = fiB.absolutePath();
              if (dirA == dirB) {
                if (ta.trackNumber != tb.trackNumber)
                  return ta.trackNumber < tb.trackNumber;
                return ta.title < tb.title;
              }
              return dirA < dirB;
            });

  endResetModel();
}
