Utilities for the BETS project
==============================

The `BtUtils` object is created only once for any widget that uses it and is stored in the common WG object. Through it, you can access additional named objects through a so-called Locator. Until you access it, the object doesn't exist, but when you do it for the first time, it is loaded and initialized.

Special object is the `BtUtils.Debug`, which is another Locator from the debug_utils directory, through which you can access number of utilities useful for debugging, such as the `Logger` object or the `dump` function.


Usage
-----

`BtUtils` need to be introduced into the scope of the widget by invoking the following command:

`local Utils = VFS.Include(LUAUI_DIRNAME .. "Widgets/BtUtils/root.lua", nil, VFS.RAW_FIRST)`

The assignment to the local Utils is not necessary, although it may be useful. Otherwise, there is a global BtUtils defined through which you can access it.

Beware, that you should not try to directly access WG.BtUtils without first invoking the initialization script, as you cannot count on there being another widget, that created the BtUtils first.

It is also recommended to localize any named object that you want to access into your own variable, such as:

`local Logger = Utils.Debug.Logger`
