"""librosa-based audio classifier adapter.

Hornets beat their wings noticeably slower than honeybees, so the energy
distribution across the low-frequency band carries a usable signal.  This
adapter extracts MFCC + spectral features with librosa and feeds them to a
scikit-learn model loaded from ``AUDIO_MODEL_PATH``.

Everything here is optional.  librosa, scikit-learn and the model file may all
be absent; the factory then falls back to :class:`MockAudioClassifier` and the
backend starts normally.
"""

from __future__ import annotations

import io
import logging
from pathlib import Path
from typing import Any

from app.ai.audio import AudioClassifier, AudioResult
from app.config import Settings

logger = logging.getLogger(__name__)

#: Sample rate the features are extracted at.
SAMPLE_RATE = 22050
#: Number of MFCC coefficients; must match whatever the model was trained on.
N_MFCC = 20


class AudioModelUnavailable(RuntimeError):
    """Raised when the real audio classifier cannot be constructed."""


class LibrosaAudioClassifier(AudioClassifier):
    """Feature extraction with librosa + a trained scikit-learn classifier."""

    name = "librosa"

    def __init__(self, settings: Settings) -> None:
        model_path = settings.audio_model_path.strip()
        if not model_path:
            raise AudioModelUnavailable(
                "AUDIO_MODEL_MODE=librosa but AUDIO_MODEL_PATH is empty. "
                "Point it at a joblib-serialised scikit-learn classifier."
            )
        if not Path(model_path).exists():
            raise AudioModelUnavailable(f"Audio model file not found: {model_path}")

        try:
            import joblib  # noqa: PLC0415 - deliberately lazy
            import librosa  # noqa: PLC0415, F401 - imported to verify availability
        except ImportError as exc:  # pragma: no cover - depends on environment
            raise AudioModelUnavailable(
                "librosa/scikit-learn are not installed. "
                "Run: pip install -r requirements-ai.txt"
            ) from exc

        try:
            self._model = joblib.load(model_path)
        except Exception as exc:  # pragma: no cover - depends on model file
            raise AudioModelUnavailable(f"Could not load audio model: {exc}") from exc

        logger.info("librosa audio classifier ready (model=%s)", model_path)

    def classify(self, audio: bytes, hive_id: str | None = None) -> AudioResult:
        """Extract features and predict.

        A chunk that cannot be decoded yields probability 0 rather than an
        exception — a dropped chunk must not break monitoring.
        """
        features = self._extract_features(audio)
        if features is None:
            return AudioResult()

        try:
            if hasattr(self._model, "predict_proba"):
                proba = self._model.predict_proba([features])[0]
                # Convention: class 1 is "hornet present".
                probability = float(proba[1]) if len(proba) > 1 else float(proba[0])
            else:
                probability = float(self._model.predict([features])[0])
        except Exception as exc:  # pragma: no cover - depends on model
            logger.warning("Audio inference failed: %s", exc)
            return AudioResult()

        return AudioResult(hornet_probability=probability).clamped()

    @staticmethod
    def _extract_features(audio: bytes) -> list[float] | None:
        """MFCC means/stds plus spectral centroid and zero-crossing rate."""
        if not audio:
            return None
        try:
            import librosa  # noqa: PLC0415
            import numpy as np  # noqa: PLC0415
        except ImportError:  # pragma: no cover - depends on environment
            return None

        try:
            waveform, sample_rate = librosa.load(
                io.BytesIO(audio), sr=SAMPLE_RATE, mono=True
            )
        except Exception as exc:
            logger.warning("Could not decode audio chunk: %s", exc)
            return None

        if waveform.size == 0:
            return None

        mfcc = librosa.feature.mfcc(y=waveform, sr=sample_rate, n_mfcc=N_MFCC)
        centroid = librosa.feature.spectral_centroid(y=waveform, sr=sample_rate)
        zero_crossing = librosa.feature.zero_crossing_rate(y=waveform)

        features: list[float] = []
        features.extend(float(v) for v in np.mean(mfcc, axis=1))
        features.extend(float(v) for v in np.std(mfcc, axis=1))
        features.append(float(np.mean(centroid)))
        features.append(float(np.mean(zero_crossing)))
        return features


def describe_training_recipe() -> dict[str, Any]:
    """Metadata describing how to train a compatible model.

    Surfaced in the docs so whoever trains the real classifier knows exactly
    what feature vector this adapter will hand it at inference time.
    """
    return {
        "sample_rate": SAMPLE_RATE,
        "n_mfcc": N_MFCC,
        "feature_order": [
            f"mfcc_mean_{i}" for i in range(N_MFCC)
        ] + [
            f"mfcc_std_{i}" for i in range(N_MFCC)
        ] + ["spectral_centroid_mean", "zero_crossing_rate_mean"],
        "feature_length": N_MFCC * 2 + 2,
        "positive_class_index": 1,
        "serialisation": "joblib.dump(classifier, 'audio_model.joblib')",
    }
