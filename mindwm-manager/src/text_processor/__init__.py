import asyncio
import io
import os
import sys
import textfsm

class TextProcessor:
    templates = {
        "ifconfig": "unix_ifconfig"
    }
    def __init__(self):
        pass

    async def init(self):
        pass

    async def parse(self, cmd, output):
        print(f"parsing output of '{cmd}'")
        try:
            template = self.templates[cmd]
        except KeyError:
            raise NotImplementedError(f"{cmd} is not supported yet")

        #path = os.path.dirname(sys.modules[__name__].__file__)
        print(output)
        path = os.path.dirname(sys.modules[self.__class__.__module__].__file__)
        with open(f"{path}/templates/{template}.textfsm", "r") as f:
            parser = textfsm.TextFSM(io.StringIO(f.read()))
            return parser.ParseText(output)

