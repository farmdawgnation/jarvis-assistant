import platform

import numpy as np
import pyaudio
from openwakeword.model import Model as WakeModel

CHUNK = 1280  # 80ms at 16kHz
RATE = 16000
FORMAT = pyaudio.paInt16
WAKE_WORD = "hey_jarvis"  # or train a custom model
THRESHOLD = 0.5


def _detect_inference_framework() -> str:
    """Detect the best available inference framework for openwakeword.

    TFLite is preferred because ONNX has known issues on macOS ARM64
    (produces near-zero scores). Falls back to ONNX if TFLite is unavailable.

    Returns:
        "tflite" or "onnx"
    """
    # Check for tflite-runtime (native package on Linux/Pi)
    try:
        import tflite_runtime  # noqa: F401

        return "tflite"
    except ImportError:
        pass

    # Check for tensorflow + shim (macOS ARM64 workaround)
    try:
        import tensorflow  # noqa: F401

        # Verify the shim is in place
        if platform.system() == "Darwin" and platform.machine() == "arm64":
            try:
                from tensorflow.lite.python.interpreter import Interpreter  # noqa: F401

                return "tflite"
            except ImportError:
                pass
    except ImportError:
        pass

    # Fall back to ONNX
    try:
        import onnxruntime  # noqa: F401

        return "onnx"
    except ImportError:
        pass

    raise RuntimeError(
        "No inference framework available. Install one of:\n"
        "  - tflite-runtime (Linux/Pi): pip install tflite-runtime\n"
        "  - tensorflow (macOS ARM64): pip install tensorflow\n"
        "  - onnxruntime: pip install onnxruntime"
    )


class WakeWordListener:
    def __init__(self):
        framework = _detect_inference_framework()
        print(f"Using inference framework: {framework}")
        self.model = WakeModel(
            wakeword_models=[WAKE_WORD],
            inference_framework=framework,
        )
        self.audio = pyaudio.PyAudio()

    def listen_for_wake_word(self) -> bool:
        """Block until wake word detected. Returns True."""
        stream = self.audio.open(
            format=FORMAT,
            channels=1,
            rate=RATE,
            input=True,
            frames_per_buffer=CHUNK,
        )
        print("Listening for wake word...")
        try:
            while True:
                data = stream.read(CHUNK, exception_on_overflow=False)
                arr = np.frombuffer(data, dtype=np.int16)
                volume = np.sqrt(np.mean(arr.astype(np.float32) ** 2))
                result = self.model.predict(arr)
                scores = result[0] if isinstance(result, tuple) else result
                for name, score in scores.items():
                    score_val = float(score)
                    if score_val > 0.01:  # Only print when there's actual signal
                        print(f"{name}: {score_val:.3f} (vol: {volume:.0f})")
                    if score_val > THRESHOLD:
                        print(f"\n✓ Wake word detected! ({name}: {score_val:.3f})")
                        return True
        finally:
            stream.stop_stream()
            stream.close()
