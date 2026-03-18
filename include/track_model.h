#ifndef TRACK_MODEL_H
#define TRACK_MODEL_H

#include "track.h"
#include <QAbstractListModel>
#include <QVector>

class TrackModel : public QAbstractListModel {
  Q_OBJECT

public:
  enum TrackRoles {
    TitleRole = Qt::UserRole + 1,
    ArtistRole,
    AlbumRole,
    GenreRole,
    DurationRole,
    FilePathRole,
    HasCoverArtRole
  };

  explicit TrackModel(QObject *parent = nullptr);

  int rowCount(const QModelIndex &parent = QModelIndex()) const override;
  QVariant data(const QModelIndex &index,
                int role = Qt::DisplayRole) const override;
  QHash<int, QByteArray> roleNames() const override;

  Q_INVOKABLE QVariantMap get(int row) const;

  void setTracks(const QVector<Track> &tracks);
  void addTracks(const QVector<Track> &tracks);

public slots:
  void filterAll();
  void filterByArtist(const QString &artist);
  void filterByAlbum(const QString &album);
  void filterByFolder(const QString &folder);
  void filterByCollection(const QString &collection);

  // Provide unique lists for the Tile UI
  Q_INVOKABLE QVariantMap getTrackByPath(const QString &filePath) const;
  Q_INVOKABLE QVariantList getArtistTiles() const;
  Q_INVOKABLE QVariantList getAlbumTiles() const;

  Q_INVOKABLE QVariantList getFolderTiles() const;
  Q_INVOKABLE QVariantList getCollectionTiles() const;

private:
  QString getCommonRootPath() const;
  void updateDisplayIndices(std::function<bool(const Track &)> predicate);

  QVector<Track> m_allTracks;
  QVector<int> m_displayIndices;
};

#endif // TRACK_MODEL_H
