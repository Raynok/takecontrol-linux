/* xclip-get: read the X11 CLIPBOARD straight from its X owner (e.g. Wine), bypassing
   Hyprland's XWayland->Wayland transfer, which stalls on Wine-owned selections.
   usage: xclip-get --foreign   exit 0 if an X client other than the window manager owns it
          xclip-get --targets   print the offered targets
          xclip-get TARGET      write that target's data to stdout (INCR supported) */
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <stdio.h>
#include <string.h>
#include <poll.h>

static Display *d;
static Window w;

static int wait_event(int type, XEvent *e, int ms) {
  struct pollfd p = { ConnectionNumber(d), POLLIN, 0 };
  for (;;) {
    while (XPending(d)) {
      XNextEvent(d, e);
      if (e->type == type && (type != PropertyNotify || e->xproperty.state == PropertyNewValue)) return 1;
    }
    if (poll(&p, 1, ms) <= 0) return 0;
  }
}

int main(int argc, char **argv) {
  if (argc < 2 || !(d = XOpenDisplay(NULL))) return 2;
  Atom sel = XInternAtom(d, "CLIPBOARD", 0), prop = XInternAtom(d, "XCLIP_GET", 0);
  Atom incr = XInternAtom(d, "INCR", 0);
  Window owner = XGetSelectionOwner(d, sel);
  if (owner == None) return 1;

  if (!strcmp(argv[1], "--foreign")) {
    Atom check = XInternAtom(d, "_NET_SUPPORTING_WM_CHECK", 0), t; int f;
    unsigned long n, after; unsigned char *v = NULL; Window wm = 0;
    if (XGetWindowProperty(d, DefaultRootWindow(d), check, 0, 1, 0, XA_WINDOW, &t, &f, &n, &after, &v) == Success && n)
      wm = *(Window *)v;
    /* Same X client (resource id base) as the window manager means a Wayland app owns it. */
    return (owner >> 21) == (wm >> 21) ? 1 : 0;
  }

  int targets = !strcmp(argv[1], "--targets");
  Atom target = XInternAtom(d, targets ? "TARGETS" : argv[1], 0);
  w = XCreateSimpleWindow(d, DefaultRootWindow(d), 0, 0, 1, 1, 0, 0, 0);
  XSelectInput(d, w, PropertyChangeMask);
  XConvertSelection(d, sel, target, prop, w, CurrentTime);
  XFlush(d);

  XEvent e;
  if (!wait_event(SelectionNotify, &e, 2000) || e.xselection.property == None) return 1;

  Atom type; int fmt; unsigned long n, after; unsigned char *data;
  XGetWindowProperty(d, w, prop, 0, 0x1000000, True, AnyPropertyType, &type, &fmt, &n, &after, &data);
  if (targets) {
    for (unsigned long i = 0; i < n; i++) {
      char *name = XGetAtomName(d, ((Atom *)data)[i]);
      if (name) puts(name);
    }
    return 0;
  }
  if (type != incr) {
    fwrite(data, fmt / 8 == 4 ? sizeof(long) : fmt / 8, n, stdout);
    return 0;
  }
  XFree(data);
  XFlush(d);
  for (;;) { /* INCR: each new property value is a chunk; an empty one ends it. */
    if (!wait_event(PropertyNotify, &e, 2000)) return 1;
    XGetWindowProperty(d, w, prop, 0, 0x1000000, True, AnyPropertyType, &type, &fmt, &n, &after, &data);
    XFlush(d);
    if (n == 0) return 0;
    fwrite(data, fmt / 8, n, stdout);
    XFree(data);
  }
}
