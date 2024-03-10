from libtmux import Server
from time import sleep

class Tmux_manager:
    def __init__(self, config, socket_path=None, socket_name=None):
        def wrap(**kwargs):
            return Server(**{k:v for k,v in kwargs.items() if v is not None})
        self.config = config
        self.tmux = wrap(socket_path=socket_path, socket_name=socket_name)


    async def init(self):
        print(f"Tmux reset: {self.tmux}")
        self.session = self.tmux.sessions[0]
        self.session.rename_session("MindWM")
        await self.reset()
        await self.mk_layout()
        print(f"Tmux sessions: {self.tmux.sessions}")

    async def set_pane_title(self, pane, title):
        # FIXME: without switching the active window
        # keys will be sent into current pane instead of target pane
        # but this is true only when external variable used in string template
        # i.e. `pane.send_keys("echo hello")` works as expected
        old_window = self.session.active_window
        old_pane = old_window.active_pane
        pane.window.select()
        pane.select()
        pane.send_keys(r"printf '\033]2;%s\033\\' '" + title + "'")
        old_window.select()
        old_pane.select()

    async def mk_layout(self):
        self.ui_window = self.session.new_window()
        self.ui_window.rename_window("Terminal")
        self.service_window = self.session.new_window()
        self.service_window.rename_window("Service")

        self.terminal_pane = self.ui_window.panes[0]
        self.feedback_pane = self.terminal_pane.split_window()
        await self.set_pane_title(self.terminal_pane, "terminal")
        await self.set_pane_title(self.feedback_pane, "feedback")
        self.terminal_pane.clear()
        self.feedback_pane.clear()


    async def reset(self):
        windows = self.session.windows
        windows[0].rename_window("Manager")
        panes = windows[0].panes
        for p in panes[1:]:
            p.kill()

        for w in windows[1:]:
            w.kill()


    async def session_by_name(self, name):
        pass
