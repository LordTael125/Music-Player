# Chapter 7 — The Equalizer: Presets and QSettings

## 7.1 What is a Graphic Equalizer?

A **10-band graphic equalizer** lets users boost or cut 10 specific frequency bands:

| Band | Frequency | What it affects |
|------|-----------|-----------------|
| 1 | 31 Hz | Sub-bass (rumble, kick drum body) |
| 2 | 62 Hz | Bass (bass guitar, bass drum) |
| 3 | 125 Hz | Upper bass / low midrange (warmth) |
| 4 | 250 Hz | Low midrange (body of vocals) |
| 5 | 500 Hz | Midrange (nasal quality) |
| 6 | 1000 Hz | Upper midrange (presence) |
| 7 | 2000 Hz | High midrange (edge/bite) |
| 8 | 4000 Hz | Presence (clarity, articulation) |
| 9 | 8000 Hz | High frequency (air, brightness) |
| 10 | 16000 Hz | Ultra-high (shimmer, sizzle) |

Each band's gain can be adjusted from **-12 dB** (quieter) to **+12 dB** (louder) in that frequency range.

---

## 7.2 The Equalizer Class

```cpp
// include/equalizer.h
class Equalizer : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool enabled READ isEnabled WRITE setEnabled NOTIFY enabledChanged)

public:
    explicit Equalizer(QObject *parent = nullptr);

    bool isEnabled() const;

    Q_INVOKABLE int          bandCount() const;           // Returns 10
    Q_INVOKABLE float        bandGain(int index) const;   // -12.0 to +12.0 dB
    Q_INVOKABLE float        bandFrequency(int index) const; // e.g., 31.25 Hz

    Q_INVOKABLE QStringList  getPresetNames() const;
    Q_INVOKABLE bool         isCustomPreset(const QString &name) const;
    Q_INVOKABLE void         saveCustomPreset(const QString &name);
    Q_INVOKABLE void         loadPreset(const QString &name);
    Q_INVOKABLE void         deleteCustomPreset(const QString &name);

public slots:
    void setEnabled(bool enabled);
    void setBandGain(int index, float gainDb);

signals:
    void enabledChanged(bool enabled);
    void bandGainChanged(int index, float gainDb);

private:
    bool           m_enabled{false};
    QVector<float> m_frequencies;   // [31.25, 62.5, 125.0, ..., 16000.0]
    QVector<float> m_gains;         // [0.0, 0.0, 0.0, ..., 0.0] — all flat initially
};
```

---

## 7.3 Initialization

```cpp
Equalizer::Equalizer(QObject *parent) : QObject(parent), m_enabled(false) {
    // Standard ISO 1/3-octave equalizer center frequencies (starting at 31.25 Hz)
    m_frequencies = {31.25f, 62.5f, 125.0f, 250.0f, 500.0f,
                     1000.0f, 2000.0f, 4000.0f, 8000.0f, 16000.0f};
    m_gains.fill(0.0f, m_frequencies.size()); // All bands start at 0 dB (flat)
}
```

---

## 7.4 Band Gain: Read and Write

```cpp
float Equalizer::bandGain(int index) const {
    if (index >= 0 && index < m_gains.size())
        return m_gains[index];
    return 0.0f;
}

void Equalizer::setBandGain(int index, float gainDb) {
    // Clamp to -12 to +12 dB range — hard limit
    float clampedGain = fmaxf(-12.0f, fminf(12.0f, gainDb));

    if (index >= 0 && index < m_gains.size()) {
        if (m_gains[index] != clampedGain) {   // Only emit if actually changed
            m_gains[index] = clampedGain;
            emit bandGainChanged(index, clampedGain);  // AudioEngine catches this
        }
    }
}
```

`fmaxf` and `fminf` are C standard library `<math.h>` functions for `float` clamping:
```
fminf(12.0f, 15.0f) → 12.0f   (clip to max)
fmaxf(-12.0f, -20.0f) → -12.0f (clip to min)
```

---

## 7.5 Factory Presets

Built-in presets are defined as a static function (not a member variable) to avoid initialization order issues:

```cpp
static QMap<QString, QVector<float>> getFactoryPresets() {
    QMap<QString, QVector<float>> presets;
    //                              31  62  125 250 500 1k  2k  4k  8k  16k
    presets["Flat"]         = {  0,  0,  0,  0,  0,  0,  0,  0,  0,  0 };
    presets["Acoustic"]     = {  5,  5,  4,  1,  1,  1,  3,  4,  3,  2 };
    presets["Bass Booster"] = {  6,  5,  4,  2,  1,  0,  0,  0,  0,  0 };
    presets["Classical"]    = {  5,  4,  3,  2, -1, -1,  0,  2,  3,  4 };
    presets["Dance"]        = {  4,  6,  5,  0,  2,  3,  5,  4,  3,  0 };
    presets["Electronic"]   = {  4,  3,  1, -2, -3,  1,  3,  5,  4,  5 };
    presets["Pop"]          = { -1, -1,  0,  2,  4,  4,  2,  0, -1, -2 };
    presets["Rock"]         = {  5,  4,  3,  1, -1, -1,  1,  2,  3,  4 };
    return presets;
}
```

`QMap<K, V>` is Qt's sorted associative container (like `std::map`). Keys are sorted alphabetically, so `getPresetNames()` returns a naturally sorted list.

---

## 7.6 Custom Presets with QSettings

`QSettings` is Qt's cross-platform way to store user preferences. On Linux it writes INI files to `~/.config/ModernMusicPlayer/EqualizerPresets.ini`. On Windows it uses the registry.

### Saving a Custom Preset

```cpp
void Equalizer::saveCustomPreset(const QString &name) {
    if (name.isEmpty() || getFactoryPresets().contains(name))
        return;  // Can't overwrite factory presets

    QSettings settings("ModernMusicPlayer", "EqualizerPresets");
    settings.beginGroup(name);          // Creates a [name] section in the INI
    settings.beginWriteArray("bands");  // Creates an indexed list
    for (int i = 0; i < m_gains.size(); ++i) {
        settings.setArrayIndex(i);
        settings.setValue("gain", m_gains[i]);
    }
    settings.endArray();
    settings.endGroup();
}
```

The resulting INI file looks like:
```ini
[MyPreset]
bands\size=10
bands\1\gain=6
bands\2\gain=4
...
```

### Loading a Preset (Factory or Custom)

```cpp
void Equalizer::loadPreset(const QString &name) {
    // Check factory presets first
    auto factory = getFactoryPresets();
    if (factory.contains(name)) {
        const auto &gains = factory[name];
        for (int i = 0; i < gains.size() && i < m_gains.size(); ++i) {
            setBandGain(i, gains[i]);   // Each call emits bandGainChanged → AudioEngine updates
        }
        return;
    }

    // Otherwise load from QSettings (user-saved)
    QSettings settings("ModernMusicPlayer", "EqualizerPresets");
    if (settings.childGroups().contains(name)) {
        settings.beginGroup(name);
        int size = settings.beginReadArray("bands");
        for (int i = 0; i < size && i < m_gains.size(); ++i) {
            settings.setArrayIndex(i);
            float gain = settings.value("gain").toFloat();
            setBandGain(i, gain);
        }
        settings.endArray();
        settings.endGroup();
    }
}
```

### Deleting a Custom Preset

```cpp
void Equalizer::deleteCustomPreset(const QString &name) {
    if (!isCustomPreset(name)) return;  // Safety: can't delete factory presets

    QSettings settings("ModernMusicPlayer", "EqualizerPresets");
    settings.beginGroup(name);
    settings.remove("");   // Empty string = remove everything under this group
    settings.endGroup();
}
```

---

## 7.7 Getting All Preset Names (Factory + Custom)

```cpp
QStringList Equalizer::getPresetNames() const {
    QStringList names = getFactoryPresets().keys();   // ["Acoustic", "Bass Booster", ...]

    QSettings settings("ModernMusicPlayer", "EqualizerPresets");
    names.append(settings.childGroups());             // Add custom preset names

    names.removeDuplicates();  // Safety: no duplicates
    names.sort();              // Alphabetical order

    return names;
}
```

In QML, this method is called to populate the preset dropdown:
```qml
ComboBox {
    model: audioEngine.equalizer.getPresetNames()
    onActivated: audioEngine.equalizer.loadPreset(currentText)
}
```

---

## 7.8 The Enable/Disable Toggle

When the user turns the EQ on or off:
```cpp
void Equalizer::setEnabled(bool enabled) {
    if (m_enabled != enabled) {
        m_enabled = enabled;
        emit enabledChanged(m_enabled);
    }
}
```

`AudioEngine::onEqualizerEnabledChanged` catches this and re-applies all bands:
```cpp
void AudioEngine::onEqualizerEnabledChanged(bool enabled) {
    for (int i = 0; i < 10; ++i) {
        onEqualizerBandGainChanged(i, m_equalizer->bandGain(i));
        // This function reads m_equalizer->isEnabled() to decide whether to
        // apply the stored gain or force 0 dB
    }
}
```

If EQ is disabled, `actualGain = 0.0f` regardless of stored values — the filter is flat.
