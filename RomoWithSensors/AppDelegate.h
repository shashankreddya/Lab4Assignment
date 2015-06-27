//
//  AppDelegate.h
//  HelloRomo
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import <CoreMotion/CoreMotion.h>

@class ViewController;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;


@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@property (strong, nonatomic, readonly) CMMotionManager *sharedManager;


@property (strong, nonatomic) ViewController *viewController;


- (void)saveContext;
- (NSURL *)applicationDocumentsDirectory;

@end








