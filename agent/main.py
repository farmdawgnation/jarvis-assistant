import asyncio
import os

from dotenv import load_dotenv
from livekit import api

from wake import WakeWordListener

load_dotenv()

ROOM_NAME = "voice-agent-room"


async def trigger_agent_session():
    """Create a LiveKit room token and dispatch an agent job."""
    lk_api = api.LiveKitAPI(
        url=os.environ["LIVEKIT_URL"],
        api_key=os.environ["LIVEKIT_API_KEY"],
        api_secret=os.environ["LIVEKIT_API_SECRET"],
    )
    # Dispatch creates a room and signals the waiting agent worker to join
    await lk_api.agent_dispatch.create_dispatch(
        api.CreateAgentDispatchRequest(
            agent_name="voice-assistant",
            room=ROOM_NAME,
        )
    )


def main():
    listener = WakeWordListener()
    while True:
        listener.listen_for_wake_word()
        print("Triggering agent session...")
        asyncio.run(trigger_agent_session())


if __name__ == "__main__":
    main()
