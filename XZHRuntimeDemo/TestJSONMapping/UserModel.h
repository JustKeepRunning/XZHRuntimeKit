//
//  UserModel.h
//  XZHRuntimeDemo
//
//  Created by fenqile on 16/10/31.
//  Copyright © 2016年 com.cn.fql. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface YYModelUserModel : NSObject
@property (nonatomic, strong) NSString *login;
@property (nonatomic, assign) UInt64 userID;
@property (nonatomic, strong) NSString *avatarURL;
@property (nonatomic, strong) NSString *gravatarID;
@property (nonatomic, strong) NSString *url;
@property (nonatomic, strong) NSString *htmlURL;
@property (nonatomic, strong) NSString *followersURL;
@property (nonatomic, strong) NSString *followingURL;
@property (nonatomic, strong) NSString *gistsURL;
@property (nonatomic, strong) NSString *starredURL;
@property (nonatomic, strong) NSString *subscriptionsURL;
@property (nonatomic, strong) NSString *organizationsURL;
@property (nonatomic, strong) NSString *reposURL;
@property (nonatomic, strong) NSString *eventsURL;
@property (nonatomic, strong) NSString *receivedEventsURL;
@property (nonatomic, strong) NSString *type;
@property (nonatomic, assign) BOOL siteAdmin;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *company;
@property (nonatomic, strong) NSString *blog;
@property (nonatomic, strong) NSString *location;
@property (nonatomic, strong) NSString *email;
@property (nonatomic, strong) NSString *hireable;
@property (nonatomic, strong) NSString *bio;
@property (nonatomic, assign) UInt32 publicRepos;
@property (nonatomic, assign) UInt32 publicGists;
@property (nonatomic, assign) UInt32 followers;
@property (nonatomic, assign) UInt32 following;
@property (nonatomic, strong) NSDate *createdAt;
@property (nonatomic, strong) NSDate *updatedAt;
@property (nonatomic, strong) NSValue *test;
@end


@interface XZHRuntimeUserModel : NSObject
@property (nonatomic, strong) NSString *login;
@property (nonatomic, assign) UInt64 userID;
@property (nonatomic, strong) NSString *avatarURL;
@property (nonatomic, strong) NSString *gravatarID;
@property (nonatomic, strong) NSString *url;
@property (nonatomic, strong) NSString *htmlURL;
@property (nonatomic, strong) NSString *followersURL;
@property (nonatomic, strong) NSString *followingURL;
@property (nonatomic, strong) NSString *gistsURL;
@property (nonatomic, strong) NSString *starredURL;
@property (nonatomic, strong) NSString *subscriptionsURL;
@property (nonatomic, strong) NSString *organizationsURL;
@property (nonatomic, strong) NSString *reposURL;
@property (nonatomic, strong) NSString *eventsURL;
@property (nonatomic, strong) NSString *receivedEventsURL;
@property (nonatomic, strong) NSString *type;
@property (nonatomic, assign) BOOL siteAdmin;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *company;
@property (nonatomic, strong) NSString *blog;
@property (nonatomic, strong) NSString *location;
@property (nonatomic, strong) NSString *email;
@property (nonatomic, strong) NSString *hireable;
@property (nonatomic, strong) NSString *bio;
@property (nonatomic, assign) UInt32 publicRepos;
@property (nonatomic, assign) UInt32 publicGists;
@property (nonatomic, assign) UInt32 followers;
@property (nonatomic, assign) UInt32 following;
@property (nonatomic, strong) NSDate *createdAt;
@property (nonatomic, strong) NSDate *updatedAt;
@property (nonatomic, strong) NSValue *test;
@end
