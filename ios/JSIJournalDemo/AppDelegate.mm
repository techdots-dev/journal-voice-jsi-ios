#import "AppDelegate.h"
#import "AudioProcessor.h"

#import <React/RCTBundleURLProvider.h>
#import <ExpoModulesCore/EXModuleRegistryProvider.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  self.moduleName = @"JSIJournalDemo";
  // You can add your custom initial props in the dictionary below.
  // They will be passed down to the ViewController used by React Native.
  self.initialProps = @{};

  return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

- (NSArray<id<RCTBridgeModule>> *)extraModulesForBridge:(RCTBridge *)bridge
{
  // Get all extra modules from Expo
  NSArray<id<RCTBridgeModule>> *expoModules = [super extraModulesForBridge:bridge];
  
  // Add our custom module
  NSMutableArray<id<RCTBridgeModule>> *modules = [NSMutableArray arrayWithArray:expoModules];
  [modules addObject:[AudioProcessor new]];
  
  return modules;
}

- (NSURL *)sourceURLForBridge:(RCTBridge *)bridge
{
  return [self bundleURL];
}

- (NSURL *)bundleURL
{
#if DEBUG
  return [[RCTBundleURLProvider sharedSettings] jsBundleURLForBundleRoot:@"index"];
#else
  return [[NSBundle mainBundle] URLForResource:@"main" withExtension:@"jsbundle"];
#endif
}

@end
