#import <Foundation/Foundation.h>


#define NOW_PLAYING_APP_CHANGED_SELECTOR @selector(nowPlayingAppChanged:)

#define kRoadRunnerRestoredMediaProcess "com.futur3sn0w.reroadrunner.restored-media-process"
#define kRoadRunnerSpringBoardRestarted "com.futur3sn0w.reroadrunner.springboard-restarted"


#ifdef __cplusplus
extern "C" {
#endif

BOOL isEnabled();

#ifdef __cplusplus
}
#endif
