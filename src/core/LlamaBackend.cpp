#include "LlamaBackend.h"

#include <QDebug>
#include <QMetaObject>

LlamaBackend::LlamaBackend(QObject *parent)
    : QObject(nullptr)
{
    Q_UNUSED(parent)

#ifdef RESONALENS_HAS_LLAMA
    llama_backend_init();
#endif

    this->moveToThread(&m_workerThread);
    m_workerThread.start();
}

LlamaBackend::~LlamaBackend()
{
    // Must unload on worker thread, then stop it
    if (m_modelLoaded) {
        QMetaObject::invokeMethod(this, [this]() {
#ifdef RESONALENS_HAS_LLAMA
            if (m_context) { llama_free(m_context); m_context = nullptr; }
            if (m_model) { llama_model_free(m_model); m_model = nullptr; }
            m_vocab = nullptr;
#endif
            m_modelLoaded = false;
        }, Qt::BlockingQueuedConnection);
    }

    m_workerThread.quit();
    m_workerThread.wait();

#ifdef RESONALENS_HAS_LLAMA
    llama_backend_free();
#endif
}

void LlamaBackend::loadModel(const QString &ggufPath)
{
    // Dispatch to worker thread asynchronously — no UI freeze
    QMetaObject::invokeMethod(this, [this, ggufPath]() {
        doLoadModel(ggufPath);
    }, Qt::QueuedConnection);
}

void LlamaBackend::unloadModel()
{
    if (!m_modelLoaded)
        return;

    QMetaObject::invokeMethod(this, [this]() {
#ifdef RESONALENS_HAS_LLAMA
        if (m_context) { llama_free(m_context); m_context = nullptr; }
        if (m_model) { llama_model_free(m_model); m_model = nullptr; }
        m_vocab = nullptr;
#endif
        m_modelLoaded = false;
        emit modelUnloaded();
    }, Qt::QueuedConnection);
}

bool LlamaBackend::isModelLoaded() const
{
    return m_modelLoaded;
}

bool LlamaBackend::doLoadModel(const QString &ggufPath)
{
#ifdef RESONALENS_HAS_LLAMA
    // Unload previous if any
    if (m_context) { llama_free(m_context); m_context = nullptr; }
    if (m_model) { llama_model_free(m_model); m_model = nullptr; }
    m_vocab = nullptr;
    m_modelLoaded = false;

    qInfo() << "Loading GGUF model:" << ggufPath;

    llama_model_params mparams = llama_model_default_params();
    mparams.n_gpu_layers = 99;

    m_model = llama_model_load_from_file(ggufPath.toUtf8().constData(), mparams);
    if (!m_model) {
        qWarning() << "Failed to load model:" << ggufPath;
        emit errorOccurred("Failed to load model: " + ggufPath);
        return false;
    }

    m_vocab = llama_model_get_vocab(m_model);

    llama_context_params cparams = llama_context_default_params();
    // Cap context to 8192 on mobile to prevent OOM kills.
    // Gemma 4 reports 131072 training context which needs >8GB VRAM.
    static const int32_t kMaxMobileCtx = 4096;
    int32_t modelCtx = llama_model_n_ctx_train(m_model);
    if (modelCtx <= 0) modelCtx = kMaxMobileCtx;
    cparams.n_ctx = std::min(modelCtx, kMaxMobileCtx);
    cparams.n_batch = 512;
    qInfo() << "Context size:" << cparams.n_ctx << "(model trained:" << llama_model_n_ctx_train(m_model) << ")";

    m_context = llama_init_from_model(m_model, cparams);
    if (!m_context) {
        llama_model_free(m_model);
        m_model = nullptr;
        m_vocab = nullptr;
        emit errorOccurred("Failed to create context");
        return false;
    }

    m_modelLoaded = true;
    qInfo() << "Model loaded successfully";
    emit modelLoaded(ggufPath);
    return true;

#else
    Q_UNUSED(ggufPath)
    qWarning() << "llama.cpp not compiled in";
    m_modelLoaded = true;
    emit modelLoaded(ggufPath);
    return true;
#endif
}

void LlamaBackend::setGenerationParams(double temperature, double topP, int maxTokens)
{
    m_temperature = static_cast<float>(temperature);
    m_topP = static_cast<float>(topP);
    m_maxGenTokens = maxTokens;
}

void LlamaBackend::generate(const QString &prompt)
{
    m_stopRequested = false;
    QMetaObject::invokeMethod(this, [this, prompt]() {
        doGenerate(prompt);
    }, Qt::QueuedConnection);
}

void LlamaBackend::stop()
{
    m_stopRequested = true;
}

void LlamaBackend::doGenerate(const QString &prompt)
{
    if (!m_modelLoaded) {
        emit errorOccurred("No model loaded");
        emit generationComplete();
        return;
    }

#ifdef RESONALENS_HAS_LLAMA
    QByteArray promptBytes = prompt.toUtf8();
    const int maxInputTokens = promptBytes.size() + 256;

    std::vector<llama_token> tokens(maxInputTokens);
    int nTokens = llama_tokenize(m_vocab, promptBytes.constData(), promptBytes.size(),
                                  tokens.data(), maxInputTokens, true, true);

    if (nTokens < 0) {
        // Buffer too small, reallocate
        tokens.resize(-nTokens);
        nTokens = llama_tokenize(m_vocab, promptBytes.constData(), promptBytes.size(),
                                  tokens.data(), tokens.size(), true, true);
    }

    if (nTokens < 0) {
        emit errorOccurred("Failed to tokenize prompt");
        emit generationComplete();
        return;
    }
    tokens.resize(nTokens);

    // Clear memory
    llama_memory_clear(llama_get_memory(m_context), true);

    // Evaluate the prompt in batches
    const int batchSize = 512;
    for (int i = 0; i < nTokens; i += batchSize) {
        if (m_stopRequested) break;

        int n = std::min(batchSize, nTokens - i);
        llama_batch batch = llama_batch_get_one(tokens.data() + i, n);
        if (llama_decode(m_context, batch) != 0) {
            emit errorOccurred("Failed to evaluate prompt");
            emit generationComplete();
            return;
        }
    }

    if (m_stopRequested) {
        emit generationComplete();
        return;
    }

    // Set up sampler using settings from SettingsController
    llama_sampler_chain_params sparams = llama_sampler_chain_default_params();
    llama_sampler *sampler = llama_sampler_chain_init(sparams);
    llama_sampler_chain_add(sampler, llama_sampler_init_top_p(m_topP, 1));
    llama_sampler_chain_add(sampler, llama_sampler_init_temp(m_temperature));
    llama_sampler_chain_add(sampler, llama_sampler_init_dist(0));

    // Generate — with stuck-detection for Gemma 4 (<unused> token loop,
    // see ggml-org/llama.cpp#21516) and Qwen 3.5 freeze issues.
    const int maxGenTokens = m_maxGenTokens;
    char tokenBuf[256];

    llama_token prevToken = -1;
    int repeatCount = 0;
    int junkCount = 0;            // consecutive junk/empty tokens (no visible output)
    static const int kMaxRepeat = 8;  // same token 8× in a row → stuck
    static const int kMaxJunk = 32;   // 32 consecutive junk tokens → model is broken

    for (int i = 0; i < maxGenTokens; i++) {
        if (m_stopRequested)
            break;

        llama_token newToken = llama_sampler_sample(sampler, m_context, -1);

        if (llama_vocab_is_eog(m_vocab, newToken))
            break;

        // Detect stuck loops: same token repeated many times (Gemma 4 <unused> bug)
        if (newToken == prevToken) {
            if (++repeatCount >= kMaxRepeat) {
                qWarning() << "Generation stuck: token" << newToken
                           << "repeated" << repeatCount << "times, stopping";
                break;
            }
        } else {
            repeatCount = 0;
        }
        prevToken = newToken;

        // special=false: don't render special tokens as text
        int len = llama_token_to_piece(m_vocab, newToken, tokenBuf, sizeof(tokenBuf), 0, false);
        if (len > 0) {
            QString piece = QString::fromUtf8(tokenBuf, len);
            // Fallback EOG check for models where llama_vocab_is_eog misses (e.g. gemma4)
            if (piece == "<end_of_turn>" || piece == "<|eot_id|>" || piece == "<|end|>"
                    || piece == "<|im_end|>" || piece == "</s>")
                break;
            // Skip junk tokens that indicate the model is stuck (Gemma 4 Vulkan bug)
            if (piece.startsWith("<unused") || piece.startsWith("<reserved_special_token")) {
                if (++junkCount >= kMaxJunk) {
                    qWarning() << "Generation stuck:" << junkCount
                               << "consecutive junk tokens, stopping";
                    break;
                }
                continue;
            }
            junkCount = 0;  // reset on any real token
            emit tokenGenerated(piece);
        }

        llama_batch nextBatch = llama_batch_get_one(&newToken, 1);
        if (llama_decode(m_context, nextBatch) != 0) {
            emit errorOccurred("Decode error during generation");
            break;
        }
    }

    llama_sampler_free(sampler);

#else
    Q_UNUSED(prompt)
    QString stub = "llama.cpp is not compiled in. Enable RESONALENS_ENABLE_LLAMA in CMake.";
    QStringList words = stub.split(' ');
    for (const QString &w : words) {
        if (m_stopRequested) break;
        emit tokenGenerated(w + " ");
        QThread::msleep(50);
    }
#endif

    emit generationComplete();
}

QString LlamaBackend::generateSync(const QString &prompt, int maxTokens)
{
    QString result;
#ifdef RESONALENS_HAS_LLAMA
    if (!m_modelLoaded)
        return result;

    QByteArray promptBytes = prompt.toUtf8();
    const int maxInputTokens = promptBytes.size() + 256;

    std::vector<llama_token> tokens(maxInputTokens);
    int nTokens = llama_tokenize(m_vocab, promptBytes.constData(), promptBytes.size(),
                                  tokens.data(), maxInputTokens, true, true);
    if (nTokens < 0) {
        tokens.resize(-nTokens);
        nTokens = llama_tokenize(m_vocab, promptBytes.constData(), promptBytes.size(),
                                  tokens.data(), tokens.size(), true, true);
    }
    if (nTokens < 0)
        return result;
    tokens.resize(nTokens);

    llama_memory_clear(llama_get_memory(m_context), true);

    const int batchSize = 512;
    for (int i = 0; i < nTokens; i += batchSize) {
        int n = std::min(batchSize, nTokens - i);
        llama_batch batch = llama_batch_get_one(tokens.data() + i, n);
        if (llama_decode(m_context, batch) != 0)
            return result;
    }

    llama_sampler_chain_params sparams = llama_sampler_chain_default_params();
    llama_sampler *sampler = llama_sampler_chain_init(sparams);
    llama_sampler_chain_add(sampler, llama_sampler_init_top_p(m_topP, 1));
    llama_sampler_chain_add(sampler, llama_sampler_init_temp(m_temperature));
    llama_sampler_chain_add(sampler, llama_sampler_init_dist(0));

    char tokenBuf[256];
    llama_token prevToken = -1;
    int repeatCount = 0;
    for (int i = 0; i < maxTokens; i++) {
        llama_token newToken = llama_sampler_sample(sampler, m_context, -1);
        if (llama_vocab_is_eog(m_vocab, newToken))
            break;
        if (newToken == prevToken) {
            if (++repeatCount >= 8) break;  // stuck loop
        } else {
            repeatCount = 0;
        }
        prevToken = newToken;
        int len = llama_token_to_piece(m_vocab, newToken, tokenBuf, sizeof(tokenBuf), 0, false);
        if (len > 0) {
            QString piece = QString::fromUtf8(tokenBuf, len);
            if (piece == "<end_of_turn>" || piece == "<|eot_id|>" || piece == "<|end|>"
                    || piece == "<|im_end|>" || piece == "</s>")
                break;
            if (piece.startsWith("<unused") || piece.startsWith("<reserved_special_token"))
                continue;
            result += piece;
        }
        llama_batch nextBatch = llama_batch_get_one(&newToken, 1);
        if (llama_decode(m_context, nextBatch) != 0)
            break;
    }

    llama_sampler_free(sampler);
    llama_memory_clear(llama_get_memory(m_context), true);
#else
    Q_UNUSED(prompt); Q_UNUSED(maxTokens);
#endif
    return result;
}
