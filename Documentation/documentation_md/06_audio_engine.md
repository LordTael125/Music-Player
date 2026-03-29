# Chapter 6 — AudioEngine: Playing Sound with miniaudio

## 6.1 What is miniaudio?

**miniaudio** is a single-header C audio library (`third_party/miniaudio.h`). It handles:
- Audio device discovery and opening
- Audio format conversion (PCM, floating point, etc.)
- Loading and decoding audio files (mp3, flac, wav, ogg, etc.)
- A **node graph** for audio processing (equalizer, effects, mixing)
- Cross-platform: works on Linux (PulseAudio/ALSA), Windows (WASAPI), macOS (CoreAudio)

Because it's a **header-only** library, you include it in exactly **one** `.cpp` file with an implementation macro:

```cpp
// ONLY in audio_engine.cpp — defines all miniaudio function bodies
#define MINIAUDIO_IMPLEMENTATION
#include "audio_engine.h"   // which in turn includes miniaudio.h
```

All other files that use miniaudio types just `#include "audio_engine.h"` without the macro.

---

## 6.2 The AudioEngine Class Interface

```cpp
// include/audio_engine.h
class AudioEngine : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool  isPlaying READ isPlaying NOTIFY playingChanged)
    Q_PROPERTY(float position  READ position  WRITE setPosition NOTIFY positionChanged)
    Q_PROPERTY(float duration  READ duration            NOTIFY durationChanged)
    Q_PROPERTY(float volume    READ volume    WRITE setVolume    NOTIFY volumeChanged)
    Q_PROPERTY(Equalizer* equalizer READ equalizer CONSTANT)

public:
    explicit AudioEngine(QObject *parent = nullptr);
    ~AudioEngine() override;

    bool  isPlaying() const;
    float position() const;   // seconds since start
    float duration() const;   // total track length in seconds
    float volume()   const;   // 0.0 = silent, 1.0 = full
    Equalizer *equalizer() const { return m_equalizer; }

public slots:
    void loadFile(const QString &filePath);
    void play();
    void pause();
    void stop();
    void setPosition(float pos);
    void setVolume(float vol);

signals:
    void playingChanged(bool isPlaying);
    void positionChanged(float position);
    void durationChanged(float duration);
    void volumeChanged(float volume);
    void playbackFinished();
    void errorOccurred(const QString &message);

private:
    ma_engine     m_engine;          // The miniaudio engine (device + graph)
    ma_sound      m_sound;           // The currently loaded audio file
    bool          m_isInitialized{false};
    bool          m_soundLoaded{false};
    float         m_volume{1.0f};
    Equalizer    *m_equalizer{nullptr};
    ma_peak_node  m_eqNodes[10];     // 10 equalizer filter nodes
    QTimer        m_progressTimer;   // Fires every 250ms to update position
};
```

---

## 6.3 Initialization: Building the Audio Pipeline

The constructor sets up the entire audio processing chain:

```cpp
AudioEngine::AudioEngine(QObject *parent)
    : QObject(parent), m_equalizer(new Equalizer(this))
{
    // Step 1: Initialize the miniaudio engine (opens the audio device)
    ma_result result = ma_engine_init(nullptr, &m_engine);
    if (result != MA_SUCCESS) {
        qWarning() << "Failed to initialize miniaudio engine.";
        return;
    }
    m_isInitialized = true;

    // Step 2: Connect Equalizer signals so we can react to EQ changes
    connect(m_equalizer, &Equalizer::enabledChanged,  this, &AudioEngine::onEqualizerEnabledChanged);
    connect(m_equalizer, &Equalizer::bandGainChanged,  this, &AudioEngine::onEqualizerBandGainChanged);

    // Step 3: Set up the 250ms progress timer
    connect(&m_progressTimer, &QTimer::timeout, this, [this]() {
        if (m_soundLoaded) {
            if (ma_sound_at_end(&m_sound)) {
                stop();
                emit playbackFinished();   // Auto-advance to next track
            } else if (isPlaying()) {
                emit positionChanged(position()); // Update progress bar
            }
        }
    });
    m_progressTimer.start(250);

    // Step 4: Build the 10-band EQ filter node chain
    ma_node_graph *pGraph    = ma_engine_get_node_graph(&m_engine);
    ma_uint32 channels       = ma_engine_get_channels(&m_engine);   // Usually 2 (stereo)
    ma_uint32 sampleRate     = ma_engine_get_sample_rate(&m_engine); // e.g., 44100 or 48000

    for (int i = 0; i < 10; ++i) {
        float freq = m_equalizer->bandFrequency(i);  // 31Hz, 62Hz, 125Hz, ..., 16kHz
        ma_peak_node_config config =
            ma_peak_node_config_init(channels, sampleRate, 0.0, 1.414, freq);
            //                        channels  sampleRate  gainDb  Q-factor  centerFreq
        ma_peak_node_init(pGraph, &config, nullptr, &m_eqNodes[i]);

        // Chain: connect output of node[i-1] into input of node[i]
        if (i > 0) {
            ma_node_attach_output_bus(&m_eqNodes[i-1], 0, &m_eqNodes[i], 0);
        }
    }

    // Connect last EQ node → speaker endpoint
    ma_node_attach_output_bus(&m_eqNodes[9], 0, ma_engine_get_endpoint(&m_engine), 0);
}
```

### The Audio Node Graph Visualized

```
Sound Source (ma_sound)
        │
        ▼
  [EQ Node: 31 Hz]        ← Peak filter at 31 Hz, gain = 0 dB initially
        │
        ▼
  [EQ Node: 62 Hz]
        │
        ▼
  [EQ Node: 125 Hz]
        │
       ...
        ▼
  [EQ Node: 16,000 Hz]
        │
        ▼
  Engine Endpoint (speakers / audio device)
```

Each `ma_peak_node` is a **peaking EQ filter** — it can boost or cut a narrow band of frequencies. The "Q-factor" (1.414 ≈ √2) controls how wide the boost/cut is.

---

## 6.4 Loading a File

```cpp
void AudioEngine::loadFile(const QString &filePath) {
    if (!m_isInitialized) return;

    // Unload any previously loaded sound
    if (m_soundLoaded) {
        ma_sound_uninit(&m_sound);
        m_soundLoaded = false;
    }

    // Load the new file (decoded = decompressed to raw PCM in memory, ASYNC = non-blocking)
    ma_result result = ma_sound_init_from_file(
        &m_engine,
        filePath.toUtf8().constData(),       // C string path
        MA_SOUND_FLAG_DECODE | MA_SOUND_FLAG_ASYNC,
        nullptr, nullptr,
        &m_sound
    );

    if (result != MA_SUCCESS) {
        emit errorOccurred("Failed to load audio file: " + filePath);
        return;
    }

    // Redirect the sound's output to the EQ chain instead of directly to speakers
    ma_node_attach_output_bus(&m_sound, 0, &m_eqNodes[0], 0);

    m_soundLoaded = true;
    ma_sound_set_volume(&m_sound, m_volume);  // Apply current volume

    float len = 0.0f;
    ma_sound_get_length_in_seconds(&m_sound, &len);
    emit durationChanged(len);   // Tell QML the total length
    emit positionChanged(0.0f);  // Reset progress bar
}
```

**`MA_SOUND_FLAG_DECODE`**: Pre-decodes the entire audio file to raw PCM. This avoids stuttering — decoding on-the-fly while playing can cause gaps.

**`MA_SOUND_FLAG_ASYNC`**: The file loading starts on a background thread immediately. The sound won't be ready instantly, but the UI thread isn't blocked.

---

## 6.5 Play, Pause, Stop

```cpp
void AudioEngine::play() {
    if (!m_soundLoaded) return;
    ma_sound_start(&m_sound);       // Begin audio output
    emit playingChanged(true);      // Update the Play/Pause button icon in QML
}

void AudioEngine::pause() {
    if (!m_soundLoaded) return;
    ma_sound_stop(&m_sound);        // Pause (keeps position)
    emit playingChanged(false);
}

void AudioEngine::stop() {
    if (m_soundLoaded) {
        ma_sound_stop(&m_sound);
        ma_sound_seek_to_pcm_frame(&m_sound, 0);  // Rewind to beginning
        emit playingChanged(false);
    }
    emit positionChanged(0.0f);     // Reset progress bar to 0
}
```

---

## 6.6 Seeking — Jumping to a Position

```cpp
void AudioEngine::setPosition(float pos) {
    if (!m_soundLoaded) return;
    if (pos < 0.0f) pos = 0.0f;

    float len = duration();
    if (len > 0.0f && pos >= len) {
        emit playbackFinished();  // Seeked past the end — treat as finished
        return;
    }

    // Convert seconds → PCM frame number
    // PCM frame = one sample per channel. At 44100 Hz, 1 second = 44100 frames.
    ma_uint32 sampleRate = ma_engine_get_sample_rate(&m_engine);
    ma_uint64 targetFrame = static_cast<ma_uint64>(pos * sampleRate);
    ma_sound_seek_to_pcm_frame(&m_sound, targetFrame);
    emit positionChanged(pos);
}
```

### Why PCM Frames?

miniaudio works in **PCM frames** (Pulse Code Modulation samples), not seconds. To seek to 30 seconds into a 44100 Hz song:
```
targetFrame = 30 * 44100 = 1,323,000
```

---

## 6.7 Querying State

```cpp
bool AudioEngine::isPlaying() const {
    if (!m_soundLoaded) return false;
    return ma_sound_is_playing(&m_sound);  // Ask miniaudio directly
}

float AudioEngine::position() const {
    if (!m_soundLoaded) return 0.0f;
    float cursor = 0.0f;
    ma_sound_get_cursor_in_seconds(&m_sound, &cursor);
    return cursor;
}

float AudioEngine::duration() const {
    if (!m_soundLoaded) return 0.0f;
    float len = 0.0f;
    ma_sound_get_length_in_seconds(&m_sound, &len);
    return len;
}

float AudioEngine::volume() const { return m_volume; }
```

---

## 6.8 Applying EQ Changes Dynamically

When the user moves an EQ slider, `Equalizer::setBandGain(index, gainDb)` is called, which emits `bandGainChanged`. `AudioEngine` catches this:

```cpp
void AudioEngine::onEqualizerBandGainChanged(int index, float gainDb) {
    if (index < 0 || index >= 10) return;

    ma_uint32 channels   = ma_engine_get_channels(&m_engine);
    ma_uint32 sampleRate = ma_engine_get_sample_rate(&m_engine);
    float freq           = m_equalizer->bandFrequency(index);

    // If EQ is globally disabled, apply 0 dB gain (flat response) regardless
    float actualGain = m_equalizer->isEnabled() ? gainDb : 0.0f;

    // Reinitialize the specific peak node with the new gain
    ma_peak2_config config = ma_peak2_config_init(
        ma_format_f32, channels, sampleRate, actualGain, 1.414, freq
    );
    ma_peak_node_reinit((const ma_peak_config *)&config, &m_eqNodes[index]);
}
```

`ma_peak_node_reinit` rebuilds the filter coefficients on-the-fly. The audio pipeline adjusts **instantly without any clicking or popping** because miniaudio smoothly transitions the coefficients.

---

## 6.9 Cleanup

```cpp
AudioEngine::~AudioEngine() {
    if (m_soundLoaded) {
        ma_sound_uninit(&m_sound);     // Release audio file resources
    }
    if (m_isInitialized) {
        ma_engine_uninit(&m_engine);   // Close audio device
    }
}
```

Always clean up in reverse order of initialization. The `ma_peak_node` instances are attached to the node graph, which is part of `m_engine`, so they are cleaned up when `ma_engine_uninit` is called.
