#!/usr/bin/env python3
import asyncio
import json
from pprint import pprint
from decouple import config
from cleaner import Sanitizer
from listener import NATS_listener
from tmux import Tmux_manager
from pipe_listener import PipeListener
from text_processor import TextProcessor
from ai_processor import AiProcessor


async def main():
#    print(f"MindWM Manager")
    env = {
        "OPENAI_API_KEY": config("OPENAI_API_KEY"),
        "OPENAI_API_BASE": config("OPENAI_API_BASE"),
#            "MINDWM_VECTOR_UDP_HOST": config("MINDWM_CLIENT_VECTOR_UDP_HOST", default="127.0.0.1"),
#            "MINDWM_VECTOR_UDP_PORT": config("MINDWM_CLIENT_VECTOR_UDP_PORT"),
#            "MINDWM_NATS_HOST": config("MINDWM_CLIENT_NATS_HOST", default="127.0.0.1"),
#            "MINDWM_NATS_PORT": config("MINDWM_CLIENT_NATS_PORT", default=4222, cast=int),
#            "MINDWM_NATS_USER": config("MINDWM_CLIENT_NATS_USER", default="root"),
#            "MINDWM_NATS_PASS": config("MINDWM_CLIENT_NATS_PASS", default="r00tpass"),
#            "MINDWM_CLIENT_IN": config("MINDWM_CLIENT_NATS_SUBJECT_WORDS_IN"),
#            "MINDWM_CLIENT_OUT": config("MINDWM_CLIENT_NATS_SUBJECT_WORDS_OUT"),
#            "MINDWM_NATS_SUBJECT_FEEDBACK": config("MINDWM_CLIENT_NATS_SUBJECT_FEEDBACK"),
#            "MINDWM_TMUX": config("MINDWM_TMUX"),
#            "MINDWM_BACK_NATS_HOST": config("MINDWM_BACK_NATS_HOST", default="127.0.0.1"),
#            "MINDWM_BACK_NATS_PORT": config("MINDWM_BACK_NATS_PORT", default=4222, cast=int),
#            "MINDWM_BACK_NATS_USER": config("MINDWM_BACK_NATS_USER", default="root"),
#            "MINDWM_BACK_NATS_PASS": config("MINDWM_BACK_NATS_PASS", default="r00tpass"),
#            "MINDWM_BACK_NATS_SUBJECT_WORDS_IN": config("MINDWM_BACK_NATS_SUBJECT_WORDS_IN"),
            }
#
#    # TODO: need to validate MINDWM_TMUX value and describe what's wrong
#    tmux_socket = env['MINDWM_TMUX'].split(',')[0]

    text_processor = TextProcessor()
    ai_processor = AiProcessor(env)
    await text_processor.init()
    await ai_processor.init()

    async def cb_print(payload):
        data = json.loads(payload)
        inp = data['input']
        if len(inp) > 2:
            # try to expand short commands to it full form
            full_cmd = await ai_processor.cmd_short_to_full(data['input'])
        else:
            full_cmd = inp

        try:
            res_ = await text_processor.parse(cmd=full_cmd, output=data['output'])
            res = payload['json']
        except NotImplementedError:
            res = payload

        result = json.loads(res)
        result['full_cmd'] = full_cmd
        #pprint(res, width=200)
        #print(f"full_cmd: {full_cmd}")
        #print(f"type: {type(res)}")
        print(f"result: {result}")

    pipe_listener = PipeListener('/home/pion/work/dev/mindwm-playground/langchain/my_pipe', cb=cb_print)

    await pipe_listener.init()
    await pipe_listener.loop()

#    sanitizer = Sanitizer()
#    tmux = Tmux_manager(config=env, socket_path=tmux_socket)

#    nats_listener = NATS_listener(
#            url = f"nats://{env['MINDWM_NATS_USER']}:{env['MINDWM_NATS_PASS']}@{env['MINDWM_NATS_HOST']}:{env['MINDWM_NATS_PORT']}",
#            subject_in = f"{env['MINDWM_CLIENT_IN']}",
#            subject_out = f"{env['MINDWM_CLIENT_OUT']}",
#            transformer = sanitizer.feed_word
#            )
#    await nats_listener.connect()
#    await nats_listener.listen()
#    await tmux.init()


    while True:
        print("tick")
        await asyncio.sleep(1)

if __name__ == "__main__":
    asyncio.run(main())
