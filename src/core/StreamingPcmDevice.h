#pragma once

#include <QIODevice>
#include <QByteArray>
#include <QMutex>

// Thread-safe QIODevice that bridges TTS synthesis (producer) and QAudioSink (consumer).
// The TTS worker thread appends PCM chunks via appendAudio(); QAudioSink pulls from
// readData() on the main thread. This creates a seamless, gap-free audio stream.
class StreamingPcmDevice : public QIODevice {
    Q_OBJECT

public:
    explicit StreamingPcmDevice(QObject *parent = nullptr);

    // Thread-safe: called from TTS worker to append synthesized PCM.
    void appendAudio(const QByteArray &pcm);

    // Signal that no more audio will be appended (generation complete).
    void finish();

    // Returns true when finish() was called and all audio has been read.
    bool isFullyConsumed() const;

    // Reset for reuse in a new generation.
    void resetStream();

    // QIODevice interface
    qint64 readData(char *data, qint64 maxSize) override;
    qint64 writeData(const char *data, qint64 maxSize) override;
    qint64 bytesAvailable() const override;
    bool isSequential() const override { return true; }

signals:
    // Emitted when all audio has been read after finish() was called.
    void fullyConsumed();

private:
    mutable QMutex m_mutex;
    QByteArray m_buffer;
    qint64 m_readPos = 0;
    bool m_finished = false;
};
