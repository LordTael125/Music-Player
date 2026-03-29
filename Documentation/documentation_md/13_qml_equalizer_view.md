# Chapter 13 — EqualizerView.qml and NowPlayingView.qml

## 13.1 EqualizerView.qml

The Equalizer view is hosted in a `Popup` in `main.qml`. It provides:
- 10 vertical sliders (one per EQ band)
- Band frequency labels
- Gain readout per band (e.g., "+6 dB")
- An Enable/Disable toggle switch
- A preset combo box (loads factory + custom presets)
- Save/Delete custom preset controls

### Architecture

The EQ view communicates entirely through the `audioEngine.equalizer` object (a C++ `Equalizer*` exposed as `CONSTANT` Q_PROPERTY):

```qml
// EqualizerView.qml structure
Item {
    // Access the equalizer via the audioEngine context property
    property var eq: audioEngine.equalizer   // Shorthand alias

    // Enable switch
    Switch {
        checked: eq.enabled
        onToggled: eq.enabled = checked   // Calls Equalizer::setEnabled via Q_PROPERTY WRITE
    }

    // Preset selector
    ComboBox {
        id: presetBox
        model: eq.getPresetNames()    // Q_INVOKABLE — returns QStringList → JS array
        onActivated: eq.loadPreset(currentText)  // Q_INVOKABLE call directly from QML
    }

    // Save custom preset
    TextField {
        id: presetNameField
        placeholderText: "Save as..."
    }
    Button {
        text: "Save"
        onClicked: {
            if (presetNameField.text.length > 0) {
                eq.saveCustomPreset(presetNameField.text)  // Q_INVOKABLE
                presetBox.model = eq.getPresetNames()      // Refresh dropdown
            }
        }
    }

    // 10 band sliders (Repeater builds 10 columns)
    Repeater {
        model: 10    // 10 iterations
        delegate: Column {
            // Band label (31Hz, 62Hz, etc.)
            Text {
                text: {
                    var freq = eq.bandFrequency(index)   // Q_INVOKABLE
                    return freq >= 1000 ? (freq/1000).toFixed(0) + "k" : freq.toFixed(0)
                }
                color: "#aaa"
            }

            // Gain readout text (+6dB, -3dB, etc.)
            Text {
                text: {
                    var g = eq.bandGain(index)   // Q_INVOKABLE — reads current gain
                    return (g >= 0 ? "+" : "") + g.toFixed(1) + " dB"
                }
                color: "white"
            }

            // Vertical slider for this band
            Slider {
                orientation: Qt.Vertical
                from: -12.0; to: 12.0    // Signal range: -12dB to +12dB
                value: eq.bandGain(index) // Initial value from C++

                onMoved: {
                    eq.setBandGain(index, value)  // Public slot — triggers bandGainChanged signal
                    // bandGainChanged → AudioEngine::onEqualizerBandGainChanged
                    // → ma_peak_node_reinit → instant EQ change in audio pipeline
                }
            }
        }
    }
}
```

### Data Flow for Moving an EQ Slider

```
User drags slider for 1kHz band
         ↓
  Slider.onMoved fires in QML
         ↓
  eq.setBandGain(5, newValue) — calls Equalizer::setBandGain(5, newValue)
         ↓ (C++ Equalizer)
  m_gains[5] = clampedValue
  emit bandGainChanged(5, clampedValue)
         ↓ (signal-slot connection in AudioEngine constructor)
  AudioEngine::onEqualizerBandGainChanged(5, newValue)
         ↓
  ma_peak_node_reinit(&m_eqNodes[5], newConfig)
         ↓
  miniaudio applies new filter coefficients to the audio stream instantly
```

---

## 13.2 NowPlayingView.qml

This is a full-screen overlay (shown when you click the expand button in the playback bar). It provides a cinematic "Now Playing" experience:

```qml
// NowPlayingView.qml structure
Item {
    // Large blurred background using the album art
    Image {
        anchors.fill: parent
        source: window.currentPlayingPath !== "" ?
                "image://musiccover/" + window.currentPlayingPath : ""
        fillMode: Image.PreserveAspectCrop
        layer.enabled: true
        layer.effect: FastBlur { radius: 64 }   // Frosted glass blur effect
        opacity: 0.4
    }

    Column {
        // Large album art, centered
        Rectangle {
            width: 300; height: 300
            radius: 12
            Image {
                source: window.currentPlayingPath !== "" ?
                        "image://musiccover/" + window.currentPlayingPath : ""
                fillMode: Image.PreserveAspectCrop
            }
        }

        // Song title and artist
        Text { text: window.currentPlayingTitle;  font.pixelSize: 36; color: "white" }
        Text { text: window.currentPlayingArtist; font.pixelSize: 20; color: "#aaa" }

        // Progress slider
        Row {
            Text { text: formatTime(audioEngine.position); color: "white" }
            Slider {
                from: 0; to: audioEngine.duration
                value: audioEngine.position
                onMoved: audioEngine.position = value
            }
            Text { text: formatTime(audioEngine.duration); color: "white" }
        }

        // Playback controls (same as bottom bar)
        Row {
            RoundButton { onClicked: playTrackAtIndex(currentQueueIndex - 1) }
            RoundButton {
                icon.source: audioEngine.isPlaying ? "pause.svg" : "play.svg"
                onClicked: audioEngine.isPlaying ? audioEngine.pause() : audioEngine.play()
            }
            RoundButton { onClicked: playTrackAtIndex(currentQueueIndex + 1) }
        }

        // Repeat toggle
        ToolButton {
            icon.source: window.repeatMode ? "repeat_on.svg" : "repeat.svg"
            onClicked: window.repeatMode = !window.repeatMode
        }
    }
}
```

Key concept: `NowPlayingView` reads from `window.currentPlayingTitle`, `window.currentPlayingArtist`, and `window.currentPlayingPath` — all declared in `main.qml` (the root). Any child QML file can access the root by its `id: window`.

---

## 13.3 The `Connections` Pattern — Updating the EQ Sliders

When the user selects a preset like "Rock", `Equalizer::loadPreset("Rock")` calls `setBandGain(i, value)` for all 10 bands. Each call emits `bandGainChanged`. The QML sliders need to reflect these changes.

The cleanest way is to bind the slider `value` to `eq.bandGain(index)`:

```qml
Slider {
    value: eq.bandGain(index)   // This is a binding — updates whenever bandGain changes
    onMoved: eq.setBandGain(index, value)
}
```

BUT: When the user drags the slider, `value` changes and triggers `onMoved` → `setBandGain` → `bandGainChanged` → `value` tries to update again (circular). Qt handles this correctly — it only updates if the new value differs from the current, breaking the cycle.

---

## 13.4 Avoiding Binding Loops

A **binding loop** would be:
```qml
// DANGEROUS
width: parent.width   // width = parent.width
// Then somewhere else:
// parent.width: child.width ← circular!
```

Qt detects these at runtime and prints a warning. In the Equalizer, the pattern `value: eq.bandGain(index)` is safe because:
1. `onMoved` only fires when the **user** drags (not on programmatic value changes)
2. `setBandGain` only emits if the value actually changed (the `!=` check in C++)
