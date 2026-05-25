import pyaudio
import numpy as np
from openwakeword.model import Model as WakeModel

CHUNK = 1280   # 80ms at 16kHz
RATE = 16000
FORMAT = pyaudio.paInt16
WAKE_WORD = "hey_jarvis"        # or train a custom model
THRESHOLD = 0.5


class WakeWordListener:
    def __init__(self):
        self.model = WakeModel(
            wakeword_models=[WAKE_WORD],
            inference_framework="onnx",
        )
        self.audio = pyaudio.PyAudio()

    def listen_for_wake_word(self) -> bool:
        """Block until wake word detected. Returns True."""
        stream = self.audio.open(
            format=FORMAT, channels=1, rate=RATE,
            input=True, frames_per_buffer=CHUNK,
        )
        print("Listening for wake word...")
        try:
            while True:
                data = stream.read(CHUNK, exception_on_overflow=False)
                arr = np.frombuffer(data, dtype=np.int16)
                scores = self.model.predict(arr)
                for name, score in scores.items():
                    if score > THRESHOLD:
                        print(f"Wake word detected! ({name}: {score:.2f})")
                        return True
        finally:
            stream.stop_stream()
            stream.close()
