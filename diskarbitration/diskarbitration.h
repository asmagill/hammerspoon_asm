@import Cocoa ;
@import LuaSkin ;
@import DiskArbitration ;

#pragma once

extern DASessionRef arbitrationSession ;

extern int pushDADiskRef(lua_State *L, DADiskRef disk) ;
extern int luaopen_hs__asm_diskarbitration_disk(lua_State* L) ;
