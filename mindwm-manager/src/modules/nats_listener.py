import asyncio
import nats
import json


class NATS_listener:
    def __init__(self, url, subject_in, subject_out, transformer=None):
        self.url = url
        self.subject_in = subject_in
        self.subject_out = subject_out
        self.transformer = transformer

    async def connect(self):
        self.nc = await nats.connect(self.url)

    async def listen(self):
        self.sub = await self.nc.subscribe(self.subject_in, cb=self.message_handler)

    async def message_handler(self, msg):
        data = json.loads(msg.data.decode())
        message = data['message']

        if self.transformer:
            res = self.transformer(bytes(message, encoding='utf-8'))
            payload = json.dumps({
                "message": res
            })
            await self.nc.publish(self.subject_out, str.encode(payload))
