@import Cocoa;
#import "PreferencesModel.h"
#import "ServerClient.h"

@interface KarabinerCLI : NSObject

@property PreferencesModel* preferencesModel;
@property ServerClient* client;

- (void)main;

@end

@implementation KarabinerCLI

- (void)output:(NSString*)string {
  NSFileHandle* fh = [NSFileHandle fileHandleWithStandardOutput];
  [fh writeData:[string dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)usage {
  [self output:@"Usage:\n"];
  [self output:@"  Profile operations:\n"];
  [self output:@"    $ karabiner list\n"];
  [self output:@"    $ karabiner select INDEX (INDEX starts at 0)\n"];
  [self output:@"    $ karabiner select_by_name NAME\n"];
  [self output:@"    $ karabiner selected\n"];
  [self output:@"    $ karabiner append NAME\n"];
  [self output:@"    $ karabiner rename INDEX NEWNAME (INDEX starts at 0)\n"];
  [self output:@"    $ karabiner delete INDEX (INDEX starts at 0)\n"];
  [self output:@"  Settings:\n"];
  [self output:@"    $ karabiner set IDENTIFIER VALUE\n"];
  [self output:@"    $ karabiner enable IDENTIFIER (alias of set IDENTIFIER 1)\n"];
  [self output:@"    $ karabiner disable IDENTIFIER (alias of set IDENTIFIER 0)\n"];
  [self output:@"    $ karabiner toggle IDENTIFIER\n"];
  [self output:@"    $ karabiner changed\n"];
  [self output:@"  Others:\n"];
  [self output:@"    $ karabiner export\n"];
  [self output:@"    $ karabiner reloadxml\n"];
  [self output:@"    $ karabiner relaunch\n"];
  [self output:@"    $ karabiner be_careful_to_use__clear_all_values_by_name PROFILE_NAME\n"];
  [self output:@"\n"];
  [self output:@"Examples:\n"];
  [self output:@"  $ karabiner list\n"];
  [self output:@"  $ karabiner select 1\n"];
  [self output:@"  $ karabiner select_by_name NewItem\n"];
  [self output:@"  $ karabiner selected\n"];
  [self output:@"  $ karabiner append \"For external keyboard\"\n"];
  [self output:@"  $ karabiner rename 1 \"Empty Setting\"\n"];
  [self output:@"  $ karabiner delete 1\n"];
  [self output:@"\n"];
  [self output:@"  $ karabiner set repeat.wait 30\n"];
  [self output:@"  $ karabiner enable remap.shiftL2commandL\n"];
  [self output:@"  $ karabiner disable remap.shiftL2commandL\n"];
  [self output:@"  $ karabiner toggle remap.shiftL2commandL\n"];
  [self output:@"  $ karabiner changed\n"];
  [self output:@"\n"];
  [self output:@"  $ karabiner export\n"];
  [self output:@"  $ karabiner reloadxml\n"];
  [self output:@"  $ karabiner relaunch\n"];
  [self output:@"  $ karabiner be_careful_to_use__clear_all_values_by_name NewItem\n"];

  exit(2);
}

- (void)savePreferencesModel {
  [self.client savePreferencesModel:self.preferencesModel processIdentifier:[NSProcessInfo processInfo].processIdentifier];
}

- (void)select:(NSInteger)index {
  ProfileModel* profileModel = [self.preferencesModel profile:index];
  if (!profileModel) {
    [self output:[NSString stringWithFormat:@"The profile index (%d) is out of range.\n", (int)(index)]];
    exit(1);
  }

  self.preferencesModel.currentProfileIndex = index;
  [self savePreferencesModel];
  [self.client updateStatusBar];
}

- (void)main {
  NSArray* arguments = [[NSProcessInfo processInfo] arguments];

  if ([arguments count] == 1) {
    [self usage];

  } else {
    @try {
      self.client = [ServerClient new];
      self.preferencesModel = [self.client preferencesModel];

      NSString* command = arguments[1];

      /*  */ if ([command isEqualToString:@"list"]) {
        int index = 0;
        for (ProfileModel* profileModel in self.preferencesModel.profiles) {
          [self output:[NSString stringWithFormat:@"%d: %@\n", index, profileModel.name]];
          ++index;
        }

      } else if ([command isEqualToString:@"selected"]) {
        [self output:[NSString stringWithFormat:@"%d\n", (int)(self.preferencesModel.currentProfileIndex)]];

      } else if ([command isEqualToString:@"changed"]) {
        [self.preferencesModel clearNotSave];
        if (self.preferencesModel.currentProfile) {
          NSDictionary* values = self.preferencesModel.currentProfile.values;
          for (NSString* key in [[values allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]) {
            [self output:[NSString stringWithFormat:@"%@=%@\n", key, values[key]]];
          }
        }

      } else if ([command isEqualToString:@"reloadxml"]) {
        [self.client reloadXML];

      } else if ([command isEqualToString:@"export"]) {
        [self.preferencesModel clearNotSave];
        if (self.preferencesModel.currentProfile) {
          NSDictionary* values = self.preferencesModel.currentProfile.values;
          [self output:@"#!/bin/sh\n\n"];
          [self output:[NSString stringWithFormat:@"cli=%@\n\n", arguments[0]]];
          for (NSString* key in [[values allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]) {
            if (![key hasPrefix:@"notsave."]) {
              [self output:[NSString stringWithFormat:@"$cli set %@ %@\n", key, values[key]]];
              [self output:@"/bin/echo -n .\n"];
            }
          }
          [self output:@"/bin/echo\n"];
        }

      } else if ([command isEqualToString:@"relaunch"]) {
        [self.client relaunch];

      } else if ([command isEqualToString:@"select"]) {
        if ([arguments count] != 3) {
          [self usage];
        }
        NSString* value = arguments[2];
        [self select:[value integerValue]];

      } else if ([command isEqualToString:@"select_by_name"]) {
        if ([arguments count] != 3) {
          [self usage];
        }
        NSString* value = arguments[2];
        NSInteger index = [self.preferencesModel profileIndexByName:value];
        if (index >= 0) {
          [self select:index];
          return;
        }
        [self output:[NSString stringWithFormat:@"\"%@\" is not found.\n", value]];
        exit(1);

      } else if ([command isEqualToString:@"append"]) {
        if ([arguments count] != 3) {
          [self usage];
        }
        NSString* value = arguments[2];
        [self.preferencesModel addProfile:value];
        [self savePreferencesModel];
        [self.client updateStatusBar];

      } else if ([command isEqualToString:@"rename"]) {
        if ([arguments count] != 4) {
          [self usage];
        }
        NSString* index = arguments[2];
        NSString* value = arguments[3];

        [self.preferencesModel renameProfile:[index integerValue] name:value];
        [self savePreferencesModel];
        [self.client updateStatusBar];

      } else if ([command isEqualToString:@"delete"]) {
        if ([arguments count] != 3) {
          [self usage];
        }
        NSString* index = arguments[2];
        if (self.preferencesModel.currentProfileIndex == [index integerValue]) {
          [self output:@"You cannot delete the current profile.\n"];
          exit(1);
        } else {
          [self.preferencesModel deleteProfile:[index integerValue]];
          [self savePreferencesModel];
          [self.client updateStatusBar];
        }

      } else if ([command isEqualToString:@"set"]) {
        if ([arguments count] != 4) {
          [self usage];
        }
        NSString* identifier = arguments[2];
        NSString* value = arguments[3];
        if ([self.preferencesModel setValue:[value integerValue] forIdentifier:identifier]) {
          [self savePreferencesModel];
          [self.client updateKextValue:identifier];
        }

      } else if ([command isEqualToString:@"enable"]) {
        if ([arguments count] != 3) {
          [self usage];
        }
        NSString* value = arguments[2];
        if ([self.preferencesModel setValue:1 forIdentifier:value]) {
          [self savePreferencesModel];
          [self.client updateKextValue:value];
        }

      } else if ([command isEqualToString:@"disable"]) {
        if ([arguments count] != 3) {
          [self usage];
        }
        NSString* value = arguments[2];
        if ([self.preferencesModel setValue:0 forIdentifier:value]) {
          [self savePreferencesModel];
          [self.client updateKextValue:value];
        }

      } else if ([command isEqualToString:@"toggle"]) {
        if ([arguments count] != 3) {
          [self usage];
        }
        NSString* value = arguments[2];
        NSInteger current = [self.preferencesModel value:value];
        if ([self.preferencesModel setValue:(!current) forIdentifier:value]) {
          [self savePreferencesModel];
          [self.client updateKextValue:value];
        }

      } else if ([command isEqualToString:@"be_careful_to_use__clear_all_values_by_name"]) {
        if ([arguments count] != 3) {
          [self usage];
        }
        NSString* value = arguments[2];
        NSInteger profileIndex = [self.preferencesModel profileIndexByName:value];
        if (profileIndex >= 0) {
          [self.preferencesModel clearValues:profileIndex];
          [self savePreferencesModel];
          [self.client updateKextValues];
          return;
        }
        [self output:[NSString stringWithFormat:@"\"%@\" is not found.\n", value]];
        exit(1);

      } else {
        [self output:[NSString stringWithFormat:@"Unknown argument: %@\n", command]];
        exit(1);
      }
    }
    @catch (NSException* exception) {
      NSLog(@"%@", exception);
    }
  }
}

@end

int main(int argc, const char* argv[]) {
  @autoreleasepool {
    [[KarabinerCLI new] main];
  }
  return 0;
}
