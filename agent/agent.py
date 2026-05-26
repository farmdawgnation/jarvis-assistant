import asyncio
from livekit import agents
from livekit.agents import AgentSession, Agent, RoomInputOptions
from livekit.plugins import openai, cartesia, silero


async def entrypoint(ctx: agents.JobContext):
    await ctx.connect()

    session = AgentSession(
        stt=cartesia.STT(model="ink-whisper"),
        llm=openai.LLM.with_ollama(
            model="gpt-oss:20b-cloud",
            base_url="https://ollama.com/v1",
        ),
        tts=cartesia.TTS(),
        vad=silero.VAD.load(),
    )

    await session.start(
        room=ctx.room,
        agent=Agent(
            instructions="You are a helpful voice assistant. Keep responses concise and conversational."
        ),
        room_input_options=RoomInputOptions(noise_cancellation=True),
    )


if __name__ == "__main__":
    agents.cli.run_app(agents.WorkerOptions(entrypoint_fnc=entrypoint))
