Early stages of a spotlight query module for Hammerspoon

* MDQueryItem needs to be a userdata to increase responsiveness of callback userInfo field and keep slower queries limited to actually desired information
* need to figure out why even in non-sandboxed mode can't access NSURL for files... may require entitlement/folder authorization support
