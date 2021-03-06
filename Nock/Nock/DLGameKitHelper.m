#import "DLGameKitHelper.h"

NSString *const PresentAuthenticationViewController = @"present_authentication_view_controller";
NSString *const LeaderboardIPhone = @"iPhoneMax";
NSString *const LeaderboardIPad = @"iPadMax";
NSString *const LeaderboardTotal = @"playerTotal";


@implementation DLGameKitHelper

+ (instancetype)sharedGameKitHelper
{
    static DLGameKitHelper *sharedGameKitHelper;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedGameKitHelper = [[DLGameKitHelper alloc] init];
    });
    return sharedGameKitHelper;
}

- (id)init
{
    self = [super init];
    if (self) {
        _gameCenterEnabled = NO;
        
    }
    return self;
}

- (void)authenticateLocalPlayer
{
    //1
    _localPlayer = [GKLocalPlayer localPlayer];
    
    //2
    _localPlayer.authenticateHandler  =
    ^(UIViewController *viewController, NSError *error) {
        //3
        [[DLGameKitHelper sharedGameKitHelper] setLastError:error];
        
        if(viewController != nil) {
            //4
            [[DLGameKitHelper sharedGameKitHelper] setAuthenticationViewController:viewController];
        } else if([GKLocalPlayer localPlayer].isAuthenticated) {
            //5
            
            [DLGameKitHelper sharedGameKitHelper ].gameCenterEnabled = YES;
            GKLocalPlayer *player = [GKLocalPlayer localPlayer];
            [GameState shared].player = [[PlayerInfo alloc] initWithPlayerId:player.playerID name:player.alias highScore:0 totalScore:0 photo:nil];
            
            [[DLGameKitHelper sharedGameKitHelper]refreshGameStateScores];
        } else {
            //6
            [DLGameKitHelper sharedGameKitHelper].gameCenterEnabled = NO;
        }
    };
}

- (void)setAuthenticationViewController:(ViewController *)authenticationViewController
{
    if (authenticationViewController != nil) {
        _authenticationViewController = authenticationViewController;
        [[NSNotificationCenter defaultCenter]
         postNotificationName:PresentAuthenticationViewController
         object:self];
    }
}


-(void)refreshGameStateScores{
    
    GKLeaderboard *leaderboardRequest = [[GKLeaderboard alloc] init];
    leaderboardRequest.identifier = LeaderboardTotal;
    leaderboardRequest.playerScope = GKLeaderboardPlayerScopeFriendsOnly;
    leaderboardRequest.timeScope = GKLeaderboardTimeScopeAllTime;
    [leaderboardRequest loadScoresWithCompletionHandler:^(NSArray *scores, NSError *error) {
        if (error) {
            NSLog(@"%@", error);
        } else if (scores) {
            GKScore *localPlayerScore = leaderboardRequest.localPlayerScore;
            
            [GameState shared].player.totalScore =  [NSNumber numberWithLongLong:localPlayerScore.value].integerValue;
            NSMutableDictionary<NSString *, PlayerInfo *> *friends = [NSMutableDictionary dictionaryWithCapacity:[scores count]];
            
            [scores enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){
                GKScore *s = (GKScore *)obj;
                PlayerInfo *newFriend = [[PlayerInfo alloc ]initWithPlayerId:s.player.playerID name:s.player.alias highScore:(NSInteger)s.value totalScore:(NSInteger)s.value photo:nil];
                friends[s.player.playerID] = newFriend;
            }];
            
            [GameState shared].friends = friends;
            [GKPlayer loadPlayersForIdentifiers:[self->_playersTotalScores allKeys] withCompletionHandler:^(NSArray *players, NSError *error) {
                [players enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    GKPlayer *p = (GKPlayer *)obj;
                    PlayerInfo *currentPlayer = [GameState shared].friends[p.playerID];
                    [p loadPhotoForSize:GKPhotoSizeSmall withCompletionHandler:^(UIImage *photo, NSError *error) {
                        if (photo) {
                            currentPlayer.photo=photo;
                        }
                    }];//photo loaded
                }];//player set up
            }];
        }
    }];
   
    
    GKLeaderboard *leaderboardRequest2 = [[GKLeaderboard alloc] init];
    if (IPAD) {
        leaderboardRequest2.identifier = LeaderboardIPad;
    }else{
        leaderboardRequest2.identifier = LeaderboardIPhone;
    }
    leaderboardRequest2.playerScope = GKLeaderboardPlayerScopeFriendsOnly;
    leaderboardRequest2.timeScope = GKLeaderboardTimeScopeAllTime;
    [leaderboardRequest2 loadScoresWithCompletionHandler:^(NSArray *scores, NSError *error) {
        if (error) {
            //NSLog(@"%@", error);
        } else if (scores) {
            GKScore *localPlayerScore = leaderboardRequest2.localPlayerScore;
            [DLGameKitHelper sharedGameKitHelper].highScore = [NSNumber numberWithLongLong:localPlayerScore.value].integerValue;
            [scores enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){
                GKScore *s = (GKScore *)obj;
                [[GameState shared].friends[s.player.playerID] setHighScore:(NSInteger)s.value];
            }];
        }
    }];
}

- (void)setLastError:(NSError *)error
{
    _lastError = [error copy];
    if (_lastError) {
        //NSLog(@"GameKitHelper ERROR: %@",[[_lastError userInfo] description]);
    }
}

- (void) updateAndShowGameCenter
{
    [[DLGameKitHelper sharedGameKitHelper] persistScoreswithCompletionHandler:^(id ibject) {
        GKGameCenterViewController *gameCenterController = [[GKGameCenterViewController alloc] init];
        if (gameCenterController != nil)
        {
            gameCenterController.gameCenterDelegate = self;
            [self->_authenticationViewController presentViewController: gameCenterController animated: YES completion:nil];
        }
    }];
}

- (void)gameCenterViewControllerDidFinish:(GKGameCenterViewController *)gameCenterViewController
{
      [_authenticationViewController dismissViewControllerAnimated:YES completion:nil];
}

-(void) persistScoreswithCompletionHandler:(void (^)(id))block{
    
    GameState *gameState = [GameState shared];
    [gameState persist];
    
    GKScore *score = [GKScore alloc];
    
    if (IPAD){
        score = [score initWithLeaderboardIdentifier:LeaderboardIPad];
        
    
    }else{
        score = [score initWithLeaderboardIdentifier:LeaderboardIPhone];
        
    }
    score.value = gameState.player.highScore;
    GKScore *scoretotal = [[GKScore alloc] initWithLeaderboardIdentifier:LeaderboardTotal];
    scoretotal.value =  gameState.player.totalScore;
    
    [GKScore reportScores:@[score,scoretotal] withCompletionHandler:block];
}

@end
