#!/usr/bin/env python3
import asyncio
from decouple import config
from cleaner import Sanitizer
from listener import NATS_listener
from tmux import Tmux_manager


async def main():
    print(f"MindWM Manager")
    MINDWM_NATS_HOST = config("MINDWM_CLIENT_NATS_HOST", default="127.0.0.1")
    MINDWM_NATS_PORT = config("MINDWM_CLIENT_NATS_PORT", default=4222, cast=int)
    MINDWM_NATS_USER = config("MINDWM_CLIENT_NATS_USER", default="root")
    MINDWM_NATS_PASS = config("MINDWM_CLIENT_NATS_PASS", default="r00tpass")
    MINDWM_CLIENT_IN = config("MINDWM_CLIENT_NATS_SUBJECT_WORDS_IN")
    MINDWM_CLIENT_OUT = config("MINDWM_CLIENT_NATS_SUBJECT_WORDS_OUT")
    MINDWM_TMUX = config("MINDWM_TMUX")

    # TODO: need to validate MINDWM_TMUX value and describe what's wrong
    tmux_socket = MINDWM_TMUX.split(',')[0]

    sanitizer = Sanitizer()
    tmux = Tmux_manager(config=config, socket_path=tmux_socket)

    nats_listener = NATS_listener(
            url = f"nats://{MINDWM_NATS_USER}:{MINDWM_NATS_PASS}@{MINDWM_NATS_HOST}:{MINDWM_NATS_PORT}",
            subject_in = f"{MINDWM_CLIENT_IN}",
            subject_out = f"{MINDWM_CLIENT_OUT}",
            transformer = sanitizer.feed_word
            )
    await nats_listener.connect()
    await nats_listener.listen()
    await tmux.init()


    while True:
        await asyncio.sleep(1)

if __name__ == "__main__":
    asyncio.run(main())
