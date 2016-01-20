//
//  main.m
//  HammerspoonService
//
//  Created by Aaron Magill on 1/17/16.
//  Copyright © 2016 Hammerspoon. All rights reserved.
//

#import <Cocoa/Cocoa.h>

int main(int argc, char *argv[]) {

    // Make sure Hammerspoon is running
    [[NSWorkspace sharedWorkspace] launchAppWithBundleIdentifier:@"org.hammerspoon.Hammerspoon"
                                                         options:NSWorkspaceLaunchWithoutActivation
                                  additionalEventParamDescriptor:nil
                                                launchIdentifier:NULL];

    return 0;
}
