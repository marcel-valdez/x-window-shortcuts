#!/usr/bin/env python3

import argparse
import gi
import signal
import sys

gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, GdkX11, cairo, GLib
from Xlib import display

# Constants for border
BORDER_WIDTH = 10
BORDER_COLOR = (0.1, 0.1, 0.6, 0.85)  # Blue 85% opaqueness

class TransparentBorder(Gtk.Window):
    def __init__(self, x, y, width, height):
        Gtk.Window.__init__(self, type=Gtk.WindowType.TOPLEVEL)
        self.set_app_paintable(True)
        self.set_decorated(False)
        self.set_accept_focus(False)
        self.set_skip_taskbar_hint(True)
        self.set_skip_pager_hint(True)
        self.set_keep_above(True)
        self.set_resizable(False)
        self.set_default_size(width, height)
        self.move(x, y)
        self.set_visual(self.get_screen().get_rgba_visual())
        self.set_opacity(0.75)
        self.connect("draw", self.on_draw)
        self.show_all()

    def on_draw(self, widget, cr):
        # Clear background (fully transparent)
        cr.set_source_rgba(0, 0, 0, 0)
        cr.set_operator(cairo.Operator.SOURCE)
        cr.paint()

        # Draw rectangle border
        cr.set_source_rgba(*BORDER_COLOR)
        cr.set_line_width(BORDER_WIDTH)
        cr.rectangle(BORDER_WIDTH / 2, BORDER_WIDTH / 2,
                     self.get_allocated_width() - BORDER_WIDTH,
                     self.get_allocated_height() - BORDER_WIDTH)
        cr.stroke()


class Rectangle:
    def __init__(self, x: int, y: int, width: int, height: int):
        self.__x = x
        self.__y = y
        self.__width = width
        self.__height = height

    @property
    def x(self) -> int:
        return self.__x

    @property
    def y(self) -> int:
        return self.__y

    @property
    def width(self) -> int:
        return self.__width

    @property
    def height(self) -> int:
        return self.__height


def get_window_rectangle(window_id_str: str) -> Rectangle:
    # Remove '0x' prefix if present and parse as int
    window_id = int(window_id_str, 16)
    # Connect to X server
    d = display.Display()
    root = d.screen().root
    # Create a window object
    window = d.create_resource_object('window', window_id)
    # Translate window position to root window coordinates
    geometry = window.get_geometry()
    x = geometry.x
    y = geometry.y
    width = geometry.width
    height = geometry.height
    # Some windows are relative to parent; get absolute position
    try:
        parent = window
        while True:
            parent = parent.query_tree().parent
            if parent.id == root.id:
                break
            geom = parent.get_geometry()
            x += geom.x
            y += geom.y
    except Exception:
        # Some windows may not have a valid parent tree
        pass

    return Rectangle(x, y, width, height)


def draw_border(geometry: Rectangle) -> TransparentBorder:
    win = TransparentBorder(geometry.x, geometry.y, geometry.width, geometry.height)
    win.connect("destroy", Gtk.main_quit)

    #d = display.Display()
    #root = d.screen().root
    #win_xid = win.get_window().get_xid()
    #d.shape_mask(win_xid, X.ShapeInput, 0, 0, 0)
    #d.sync()
    return win

def on_timeout():
    Gtk.main_quit()
    return False

def signal_handler(sig, frame):
    Gtk.main_quit()
    sys.exit(0)

if __name__ == "__main__":
    parser = argparse.ArgumentParser("Draw border around window")
    parser.add_argument("--window_id", "-w",
                        help="ID of window to draw border around.",
                        type=str,
                        required=True)
    args = parser.parse_args()

    window_rect = get_window_rectangle(args.window_id)
    border_win = draw_border(window_rect)

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    GLib.timeout_add_seconds(5, on_timeout)
    Gtk.main()
    # TODO: Instead of creating a new window each time selections are made,
    # we should resize the pre-existing window and move it.
    # On fzf start: initialize the draw border process (if not already running)
    # On change: issue the new window id to the process
    # On fzf exit: kill the process.
    # The process itself should clear the border it currently has drawn if
    # no new geometry is provided within 5 seconds.
