import asyncio
import aiofiles
import os
import pyte
import json
import time
from pprint import pprint

class PipeListener:
    def __init__(self, pipe_path, cb=None, cb_word=None, cb_line=None):
        self.rows = 1
        self.cols = 220
        self.pipe_path = pipe_path
        self.callback = cb
        self.cb_word = cb_word
        self.cb_line = cb_line

    async def init(self):
        self.screen = pyte.Screen(self.cols, self.rows)
        self.stream = pyte.ByteStream(self.screen)
        if not os.path.exists(self.pipe_path):
            os.mkfifo(self.pipe_path)

    def sanitize(self, chunk_raw):
        self.screen.reset()
        self.stream.feed(bytes(chunk_raw, encoding='utf-8'))
        return self.screen.display[0]

    async def loop(self):
        async with aiofiles.open(self.pipe_path, mode='rb') as f:
            user_input = False
            is_prompt = False
            word_buf = ""
            cmd_line = ""
            output = ""

            async for l in f:
            #while True:
                # TODO: starting state should be `waiting for prompt`
            #    l = await f.readline()
                if not l:
                    break

                try:
                    _t, d, chunk_raw = json.loads(l)
                except Exception as e:
                    print(f"cannot parse {l} as json")
       
                lines_raw = chunk_raw.split('\r\n')
                try:
                    lines = list(map(self.sanitize, lines_raw))
                except TypeError as e:
                    print(f"failed to sanitize stream: {e}")
                    user_input = False
                    is_prompt = False
                    cmd_line = ""
                    output = ""
                    continue

                #pprint(f"{d}: {user_input}: {chunk_raw}", width=200)
                last_line = (lines[-1:][0]).strip()
                #pprint(last_line, width=200)
       
                if d == 'o' and (last_line.endswith("$") or last_line.endswith("❯") or last_line.endswith("➜")):
                    input_final = self.sanitize(cmd_line).strip()
                    if self.cb_word:
                        await self.cb_word(last_line)

                    if self.cb_line:
                        await self.cb_line(last_line)

                    payload = {
                        "ps1": last_line,
                        "input": input_final,
                        "output": output
                    }
                    output = ""
                    cmd_line = ""
                    if self.callback:
                        await self.callback(json.dumps(payload))

                    continue
       
                if d == 'o' and user_input:
                    if chunk_raw in [' ', '\t', '\r', '\n']:
                        if word_buf and self.cb_word:
                            await self.cb_word(word_buf)
                            word_buf = ""
                    else:
                        word_buf += chunk_raw.strip()

                    cmd_line += chunk_raw
                elif d == 'o':
                    stripped = list(map(str.strip, lines))
                    output += '\n'.join(stripped)
                    if self.cb_line:
                        for l in stripped:
                            if l:
                                await self.cb_line(l)
       
                if d == 'i' and not user_input:
                    user_input = True
                elif d == 'i' and chunk_raw == "\u0003":
                    user_input = False
                    cmd_line = ""
                    pprint("user command canceled")
                elif d == 'i' and chunk_raw == '\r':
                    if self.cb_line:
                        if word_buf and self.cb_word:
                            await self.cb_word(word_buf)
                            word_buf = ""

                        await self.cb_line(cmd_line)

                    user_input = False
