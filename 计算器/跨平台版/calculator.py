import math
import operator
from pathlib import Path
import subprocess
import sys
import tkinter as tk

OPERATIONS = {"+": operator.add, "−": operator.sub, "×": operator.mul, "÷": operator.truediv}
KEYS = {"-": "−", "*": "×", "/": "÷", "Return": "=", "KP_Enter": "=",
        "Escape": "清空", "BackSpace": "⌫"}


THEMES = {
    "暖浅绿": ("#d7e9cd", "#faf4e3", "#edf1df", "#fffbed", "#bed9a8", "#e0edd3", "#829b73"),
    "雾霾蓝": ("#d6e7f5", "#f0f6fb", "#e7eff7", "#f7fbff", "#afcde6", "#deebf7", "#839fb8"),
    "暖杏色": ("#f5dac4", "#fff5e6", "#f6e7db", "#fff9ef", "#edbd97", "#f8e2d0", "#b18b6d"),
    "淡紫色": ("#e6dcf5", "#fbf4fc", "#f0e8f6", "#fdf9ff", "#d4bce9", "#ede0f7", "#a78cb8"),
}
PREFERENCES = Path.home() / ".calculator-desktop-theme"


def play_click():
    sound = str(Path(__file__).with_name("click.wav").resolve())
    try:
        if sys.platform == "win32":
            import winsound
            winsound.PlaySound(sound, winsound.SND_FILENAME | winsound.SND_ASYNC)
        elif sys.platform == "darwin":
            subprocess.Popen(["/usr/bin/afplay", sound], stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL)
    except (OSError, RuntimeError):
        pass


class MechanicalKey(tk.Canvas):
    def __init__(self, parent, key, color, command):
        super().__init__(parent, width=1, height=1, background="#edf1df", highlightthickness=0)
        self.key = key
        self.color = color
        self.base_color = "#829b73"
        self.command = command
        self.pressed = False
        self.bind("<Configure>", self.draw_key)
        self.bind("<ButtonPress-1>", self.push)
        self.bind("<ButtonRelease-1>", self.release)

    def draw_key(self, event=None):
        self.delete("all")
        width, height = self.winfo_width(), self.winfo_height()
        offset = 3 if self.pressed else 0
        self.create_rectangle(1, 4, width - 2, height - 2, fill=self.base_color, outline="")
        self.create_rectangle(1, 1 + offset, width - 2, height - 5 + offset,
                              fill=self.color, outline="#bdcbb0")
        self.create_text(width / 2, (height - 4) / 2 + offset, text=self.key,
                         fill="#304631", font=("TkDefaultFont", 16))

    def push(self, event):
        self.pressed = True
        self.draw_key()
        play_click()

    def release(self, event):
        self.pressed = False
        self.draw_key()
        if 0 <= event.x < self.winfo_width() and 0 <= event.y < self.winfo_height():
            self.command(self.key)


class Calculator:
    def __init__(self):
        self.value = "0"
        self.left = 0
        self.pending = None
        self.fresh = True
        self.error = ""

    def press(self, key):
        if key == "清空" or (self.error and key == "⌫"):
            self.__init__()
        elif key in "0123456789." and len(key) == 1:
            if self.error:
                self.__init__()
            if self.fresh:
                self.value = "0"
            self.fresh = False
            if key == ".":
                if "." not in self.value:
                    self.value += "."
            elif len(self.value) < 15:
                self.value = key if self.value == "0" else self.value + key
        elif key == "⌫" and not self.fresh:
            self.value = self.value[:-1] or "0"
        elif key in OPERATIONS and not self.error:
            if self.pending and not self.fresh:
                self.evaluate()
            if not self.error:
                self.left = float(self.value)
                self.pending = key
                self.fresh = True
        elif key == "=" and self.pending and not self.fresh:
            self.evaluate()

    def evaluate(self):
        try:
            result = OPERATIONS[self.pending](self.left, float(self.value))
            if math.isfinite(result):
                self.value = format(result, ".15g") if result else "0"
            else:
                self.error = "结果超出范围"
        except ZeroDivisionError:
            self.error = "除数不能为 0"
        self.pending = None
        self.fresh = True


def main():
    root = tk.Tk()
    root.title("计算器 1.0.3")
    root.minsize(340, 434)
    calculator = Calculator()
    background = tk.Canvas(root, highlightthickness=0)
    background.pack(fill="both", expand=True)
    panel = tk.Frame(background, bg="#edf1df", padx=12, pady=12)
    panel_id = background.create_window(0, 0, window=panel, anchor="nw")
    operation = tk.StringVar()
    display = tk.StringVar(value="0")

    selected = tk.StringVar(value="暖浅绿")
    try:
        saved = PREFERENCES.read_text(encoding="utf-8").strip()
        if saved in THEMES:
            selected.set(saved)
    except OSError:
        pass
    menu = tk.Menubutton(panel, text="设置 ▾", takefocus=True, padx=7)
    options = tk.Menu(menu, tearoff=False)
    menu.configure(menu=options)
    menu.grid(row=0, column=0, sticky="w", padx=3, pady=(0, 6))

    def resize(event=None):
        width, height = background.winfo_width(), background.winfo_height()
        start, end, *_ = THEMES[selected.get()]
        colors = [tuple(int(color[i:i + 2], 16) for i in (1, 3, 5)) for color in (start, end)]
        background.delete("gradient")
        for index in range(64):
            fraction = index / 63
            color = tuple(round(a + (b - a) * fraction)
                          for a, b in zip(*colors))
            background.create_rectangle(0, index * height / 64, width,
                                        (index + 1) * height / 64,
                                        outline="", fill="#%02x%02x%02x" % color, tags="gradient")
        background.tag_lower("gradient")
        background.coords(panel_id, 12, 12)
        background.itemconfigure(panel_id, width=max(1, width - 24), height=max(1, height - 24))

    def press(key):
        calculator.press(key)
        display.set(calculator.error or calculator.value)
        operation.set(f"{calculator.left:.15g} {calculator.pending}" if calculator.pending else "")

    def key_pressed(event):
        key = KEYS.get(event.keysym, KEYS.get(event.char, event.char))
        if key and (key in OPERATIONS or key in "0123456789.=" or key in ("清空", "⌫")):
            press(key)
            return "break"

    for column in range(4):
        panel.columnconfigure(column, weight=1, uniform="keys")
    for row in range(3, 8):
        panel.rowconfigure(row, weight=1, uniform="keys")
    for row, variable, size in ((1, operation, 12), (2, display, 22)):
        tk.Label(panel, textvariable=variable, anchor="e", padx=10, bg="#fffbed",
                 fg="#304631", font=("TkDefaultFont", size)).grid(
                     row=row, column=0, columnspan=4, sticky="ew", padx=3)

    rows = [("清空", "⌫", "÷"), ("7", "8", "9", "×"), ("4", "5", "6", "−"),
            ("1", "2", "3", "+"), ("0", ".", "=")]
    for row, keys in enumerate(rows, start=3):
        column = 0
        for key in keys:
            span = 2 if key in ("清空", "0") else 1
            color = "#bed9a8" if key == "=" else "#e0edd3" if key in OPERATIONS else "#fffdf5"
            button = MechanicalKey(panel, key, color, press)
            button.grid(row=row, column=column, columnspan=span, sticky="nsew", padx=3, pady=3)
            column += span
    def apply_theme():
        _, _, surface, screen, equal, operation_key, base = THEMES[selected.get()]
        panel.configure(bg=surface)
        menu.configure(bg=surface, fg="#304631")
        for widget in panel.winfo_children():
            if isinstance(widget, MechanicalKey):
                widget.configure(bg=surface)
                widget.base_color = base
                widget.color = equal if widget.key == "=" else operation_key if widget.key in OPERATIONS else "#fffdf5"
                widget.draw_key()
            elif isinstance(widget, tk.Label):
                widget.configure(bg=screen)
        resize()

    def choose_theme():
        apply_theme()
        try:
            PREFERENCES.write_text(selected.get(), encoding="utf-8")
        except OSError:
            pass

    for name in THEMES:
        options.add_radiobutton(label=name, variable=selected, value=name, command=choose_theme)
    apply_theme()
    background.bind("<Configure>", resize)
    root.bind("<KeyPress>", key_pressed)
    root.mainloop()


if __name__ == "__main__":
    main()
