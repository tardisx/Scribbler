//
//  LFWebService.m
//  Last.fm
//
//  Created by Matt Patenaude on 11/5/09.
//  Copyright 2009 {13bold}. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//  
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//  
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "LFWebService.h"
#import "LFWebServiceDelegate.h"
#import "LFWebServicePrivate.h"
#import "LFTrack.h"
#import "LFRequest.h"
#import "LFRequestTypes.h"


@implementation LFWebService

#pragma mark Initializers
- (id)init
{
	if (self = [super init])
	{
		clientID = @"tst";
		requestQueue = [[NSMutableArray alloc] init];
		
		runningRequest = NO;
	}
	return self;
}
+ (id)sharedWebService
{
	static id __sharedLFWebService = nil;
	if (!__sharedLFWebService)
		__sharedLFWebService = [[self alloc] init];
	return __sharedLFWebService;
}

#pragma mark Deallocator
- (void)dealloc
{
	[APIKey release];
	[sharedSecret release];
	[clientID release];
	[sessionKey release];
	[currentTrack release];
	[requestQueue release];
	[super dealloc];
}

#pragma mark Properties
@synthesize delegate;
@synthesize APIKey;
@synthesize sharedSecret;
@synthesize clientID;
@synthesize sessionKey;
@synthesize sessionUser;
@synthesize currentTrack;

#pragma mark Session methods
- (void)establishNewSession
{
	if (pendingToken)
	{
		[pendingToken release];
		pendingToken = nil;
	}
	
	LFRequest *theRequest = [LFGetTokenRequest request];
	[requestQueue insertObject:theRequest atIndex:0];
	[self dispatchNextRequestIfPossible];
}
- (void)finishSessionAuthorization
{
	if (!pendingToken)
	{
		NSLog(@"Last.fm.framework: warning, session authorization was not pending");
		return;
	}
	
	LFGetSessionRequest *theRequest = [LFGetSessionRequest request];
	[theRequest setToken:pendingToken];
	[requestQueue insertObject:theRequest atIndex:0];
	[self dispatchNextRequestIfPossible];
}

#pragma mark Track methods
- (void)startPlayingTrack:(LFTrack *)theTrack
{
}
- (void)scrobbleTrackIfNecessary:(LFTrack *)theTrack
{
}
- (void)loveTrack:(LFTrack *)theTrack
{
	LFRequest *theRequest = [LFLoveRequest requestWithTrack:theTrack];
	[requestQueue addObject:theRequest];
	[self dispatchNextRequestIfPossible];
}
- (void)banTrack:(LFTrack *)theTrack
{
	LFRequest *theRequest = [LFBanRequest requestWithTrack:theTrack];
	[requestQueue addObject:theRequest];
	[self dispatchNextRequestIfPossible];
}

#pragma mark Web service methods
- (void)dispatchNextRequestIfPossible
{
	if (!runningRequest && [requestQueue count] > 0)
	{
		LFRequest *nextRequest = [requestQueue objectAtIndex:0];
		
		if (([nextRequest requestType] != LFRequestGetToken && [nextRequest requestType] != LFRequestGetSession) && sessionKey == nil)
			return;
		
		runningRequest = YES;
		[nextRequest setDelegate:self];
		[nextRequest dispatch];
	}
}

#pragma mark Request callback methods
- (void)requestSucceeded:(LFRequest *)theRequest
{
	runningRequest = NO;
	BOOL shouldProceed = NO;
	
	LFRequestType r = [theRequest requestType];
	if (r == LFRequestNowPlaying)
	{
	}
	else if (r == LFRequestScrobble)
	{
	}
	else if (r == LFRequestLove)
	{
	}
	else if (r == LFRequestBan)
	{
	}
	else if (r == LFRequestGetToken)
	{
		if (pendingToken)
		{
			[pendingToken release];
			pendingToken = nil;
		}
		
		pendingToken = [[(LFGetTokenRequest *)theRequest token] copy];
		
		NSURL *authURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://last.fm/api/auth?api_key=%@&token=%@", APIKey, pendingToken]];
		
		if (delegate && [delegate respondsToSelector:@selector(sessionNeedsAuthorizationViaURL:)])
			[delegate sessionNeedsAuthorizationViaURL:authURL];
		else
			[[NSWorkspace sharedWorkspace] openURL:authURL];
	}
	else if (r == LFRequestGetSession)
	{
		if (sessionUser)
		{
			[sessionUser release];
			sessionUser = nil;
		}
		sessionUser = [[(LFGetSessionRequest *)theRequest sessionUser] copy];
		
		if (sessionKey)
		{
			[sessionKey release];
			sessionKey = nil;
		}
		sessionKey = [[(LFGetSessionRequest *)theRequest sessionKey] copy];
		
		if (delegate && [delegate respondsToSelector:@selector(sessionStartedWithKey:user:)])
			[delegate sessionStartedWithKey:sessionKey user:sessionUser];
		
		shouldProceed = YES;
	}
	else
	{
		
	}
	
	[requestQueue removeObject:theRequest];
	if (shouldProceed)
		[self dispatchNextRequestIfPossible];
}
- (void)request:(LFRequest *)theRequest failedWithError:(NSError *)theError
{
	runningRequest = NO;
	
	[theRequest setDelegate:nil];
	
	// if it's a "try again" type error, leave it in the queue, redispatch
	// if it's not a communication error, but it's a "this request will never work" error, remove, dispatch
	// if it's a communication error, leave it in the queue, but don't dispatch
	
	NSLog(@"%@", [theError description]);
}

@end
