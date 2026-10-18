#include "StreamingPcmDevice.h"
#include <QMutexLocker>

StreamingPcmDevice::StreamingPcmDevice(QObject *parent)
    : QIODevice(parent)
{
}

void StreamingPcmDevice::appendAudio(const QByteArray &pcm)
{
    QMutexLocker lock(&m_mutex);
    m_buffer.append(pcm);
}

void StreamingPcmDevice::finish()
{
    QMutexLocker lock(&m_mutex);
    m_finished = true;
}

bool StreamingPcmDevice::isFullyConsumed() const
{
    QMutexLocker lock(&m_mutex);
    return m_finished && m_readPos >= m_buffer.size();
}

void StreamingPcmDevice::resetStream()
{
    QMutexLocker lock(&m_mutex);
    m_buffer.clear();
    m_readPos = 0;
    m_finished = false;
}

qint64 StreamingPcmDevice::readData(char *data, qint64 maxSize)
{
    QMutexLocker lock(&m_mutex);
    qint64 available = m_buffer.size() - m_readPos;
    if (available <= 0) {
        if (m_finished) {
            // Signal fully consumed outside the lock
            lock.unlock();
            emit fullyConsumed();
            return 0;  // EOF — no more data coming
        }
        return 0;  // No data yet, but more may arrive — QAudioSink will poll again
    }

    qint64 toRead = qMin(maxSize, available);
    memcpy(data, m_buffer.constData() + m_readPos, toRead);
    m_readPos += toRead;

    // Compact buffer periodically to avoid unbounded memory growth
    if (m_readPos > 256 * 1024) {
        m_buffer.remove(0, m_readPos);
        m_readPos = 0;
    }

    return toRead;
}

qint64 StreamingPcmDevice::writeData(const char *data, qint64 maxSize)
{
    // Not used directly — use appendAudio() instead
    Q_UNUSED(data)
    Q_UNUSED(maxSize)
    return -1;
}

qint64 StreamingPcmDevice::bytesAvailable() const
{
    QMutexLocker lock(&m_mutex);
    qint64 available = m_buffer.size() - m_readPos;
    return available + QIODevice::bytesAvailable();
}
