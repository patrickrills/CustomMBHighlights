//
//  ViewController.m
//  CustomMLBHighlights
//
//  Created by Patrick Rills on 3/19/16.
//  Copyright © 2016 BaseballHackDay. All rights reserved.
//

#import "FeedViewController.h"
#import "HighlightPackage.h"
#import "HighlightVideo.h"
#import "JankDataAccess.h"
#import "OptionsTableViewController.h"
#import "ApplicationUIContext.h"
#import "APIClient.h"
#import "APIRequest.h"
#import "SearchResponse.h"
#import "VideoPlayer.h"
@import AVKit;

@interface FeedViewController ()

@end

@implementation FeedViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"CellOld"];
    
    self.title = @"Feed";
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose target:self action:@selector(openOptions:)];
    self.navigationItem.rightBarButtonItems = [NSArray arrayWithObjects:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay target:self action:@selector(play:)], [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refresh:)], nil];
}

- (IBAction)openOptions:(id)sender
{
    OptionsTableViewController* opt = [[OptionsTableViewController alloc] initWithNibName:@"OptionsTableViewController" bundle:nil];
    [[ApplicationUIContext getInstance] openModal:opt];
}

- (IBAction)refresh:(id)sender
{
    //[JankDataAccess saveDefaultFavorites];
    [self getVideos];
//    self.packages = [JankDataAccess getFeed];
    [self.tableView reloadData];
}

- (IBAction)play:(id)sender
{
    if (self.package != nil && self.package.videos != nil && self.package.videos.count > 0)
    {
        VideoPlayer* player = [[VideoPlayer alloc] initWithPackage:self.package];
        [self presentViewController:player animated:YES completion:nil];
    }
}

- (void) addVideoFromMedia: (MediaContent *) media toSource: (FeedViewController *) me
{
    if (!me)
        return;

    HighlightVideo* video = [[HighlightVideo alloc] init];
    video.metaUrl = media.url;
    video.headline = media.title;
    video.duration = media.duration;
    video.bigBlurb = media.bigBlurb;
    video.dayCreated = media.date_added;
    if (media.thumbnails != nil && media.thumbnails.count > 0)
        video.thumbnailUrl = ((Thumbnail *)[media.thumbnails objectAtIndex:0]).src;

    [video initializeVideoURL:nil];

    [me.package.videos addObject:video];
}

- (void) getVideos
{
    self.package = [[HighlightPackage alloc] init];
    self.package.keywordsUsed = [NSMutableArray array];
    self.package.videos = [NSMutableArray array];
    
    NSArray<Favorite*>* favorites = [JankDataAccess getFavorites];
    
    if (favorites.count > 0)
        [[ApplicationUIContext getInstance] showLoadingPanel];
    
    for (Favorite* f in favorites)
    {
        [self.package.keywordsUsed addObject:f.name];

        __weak FeedViewController* weakSelf = self;
        
        [APIClient processRequest:[APIRequest requestForFavorite:f] completion:^(APIRequestResult result, NSMutableArray* objs) {
            if (result == Success)
            {
                if (objs != nil && objs.count > 0)
                {
                    SearchResponse* resp = (SearchResponse*)[objs objectAtIndex:0];
                    NSLog(@"%@ videos for %@", resp.total, resp.query);
                    
                    if (resp.mediaContent != nil && resp.mediaContent.count > 0)
                    {
                        if (f != nil)
                        {
                            switch (f.type)
                            {
                                case 1:
                                case 3:
                                {
                                    int max = 3;
                                    int added = 0;
                                    //For play types and teams, only take videos from today and yesterday (max of 3)
                                    for (MediaContent *media in resp.mediaContent)
                                    {
                                        if ([media isTodayOrYesterday] && added < max)
                                        {
                                            [weakSelf addVideoFromMedia:media toSource:weakSelf];
                                            added += 1;
                                        }
                                    }

                                    break;
                                }
                                case 2:
                                {
                                    int added = 0;

                                    //For players, take all videos from today and yesterday or last one
                                    for (MediaContent *media in resp.mediaContent)
                                    {
                                        if ([media isTodayOrYesterday] || added < 1)
                                        {
                                            [weakSelf addVideoFromMedia:media toSource:weakSelf];
                                            added += 1;
                                        }
                                    }
                                    break;
                                }
                                default:
                                    break;
                            }
                        }



                    }
                    
                }
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView reloadData];
                [[ApplicationUIContext getInstance] hideLoadingPanel];
            });
            
        }];
    }
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0)
    {
        if (self.package == nil)
            return 0;
        
        return self.package.videos.count;
    }
    else
    {
        return [JankDataAccess getFavorites].count;
    }
}

- (NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 0)
    {
        return @"Playlist";
    }
    else
    {
        return @"Keywords";
    }
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
    {
        UITableViewCell* cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"Cell"];
        
        HighlightVideo* video = [self.package.videos objectAtIndex:indexPath.row];
        
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
        cell.textLabel.text = video.headline;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ - %@", video.dayCreated, video.bigBlurb];
        cell.imageView.image = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:video.thumbnailUrl]]];
        return cell;
    }
    else
    {
        UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"CellOld"];
        Favorite* f = [[JankDataAccess getFavorites] objectAtIndex:indexPath.row];
        cell.textLabel.text = f.name;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
    {
        //Launch single video
        HighlightVideo* video = [self.package.videos objectAtIndex:indexPath.row];
        HighlightPackage* single = [[HighlightPackage alloc] initWithSingleVideo:video];
        VideoPlayer* player = [[VideoPlayer alloc] initWithPackage:single];
        [self presentViewController:player animated:YES completion:nil];
    }
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
