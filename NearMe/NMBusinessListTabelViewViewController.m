//
//  NMBusinessListTabelViewViewController.m
//  NearMe
//
//  Created by Mike Jahn on 2/23/14.
//  Copyright (c) 2014 Mike Jahn. All rights reserved.
//

#import "NMBusinessListTabelViewViewController.h"
#import "NMBusinessListViewTableCell.h"
#import "NMAPIClient.h"
#import "NMBusinessReviewSearch.h"
#import "NMBusiness.h"
#import <AKLocationManager/AKLocationManager.h>
#import "NMMapView.h"
#import "NMBusinessDetailView.h"
#import "NMCategory.h"
#import <SVPullToRefresh/SVPullToRefresh.h>

@interface NMBusinessListTabelViewViewController ()

@property (strong, nonatomic) NSMutableArray *locations;
@property (strong, nonatomic) NSMutableArray *filteredLocations;
@property (strong, nonatomic) NMMapView *mapView;
@property (weak, nonatomic) IBOutlet UISearchBar *searchBar;

@end

@implementation NMBusinessListTabelViewViewController

- (id)init
{
    self = [super init];
    if (self) {
        self.locations = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.mapView = [[NMMapView alloc] init];
    [self.tableView setSeparatorInset:UIEdgeInsetsZero];
    [self setupLocationManager];
    [self setupPullToRefresh];
}

#pragma mark - setup methods
-(void)setupPullToRefresh
{
    __weak NMBusinessListTabelViewViewController *weakSelf = self;
    [self.tableView addPullToRefreshWithActionHandler:^{
        CLLocation *loc = [[CLLocation alloc] initWithLatitude:[AKLocationManager mostRecentCoordinate].latitude longitude:[AKLocationManager mostRecentCoordinate].longitude];
        [weakSelf loadData:loc];
    }];
}

-(void)setupLocationManager
{
    __weak NMBusinessListTabelViewViewController *weakSelf = self;
    [AKLocationManager startLocatingWithUpdateBlock:^(CLLocation *location){
        // location acquired
        [weakSelf.tableView.pullToRefreshView startAnimating];
        [self loadData:location];
        
    }failedBlock:^(NSError *error){
        NSLog(@"Could not get location... %@", error);
    }];
}

-(void)viewDidAppear:(BOOL)animated
{
    self.navigationController.navigationBar.topItem.title = @"Locations";
}


#pragma mark - Data loading methods
-(void)loadData:(CLLocation *)location
{
   // [self showActivityIndicator];
    __weak NMBusinessListTabelViewViewController *weakSelf = self;

    UIApplication* app = [UIApplication sharedApplication];
    app.networkActivityIndicatorVisible = YES;
    NMAPIClient *api = [[NMAPIClient alloc] init];
    void (^successBlock)(RKObjectRequestOperation *operation, RKMappingResult *mappingResult);
    successBlock = ^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult) {
      //  [self dismissActivityIndicator];
        app.networkActivityIndicatorVisible = NO;


        NMBusinessReviewSearch *search = mappingResult.array[0];

        
        
        NSArray *sortedArray;
        sortedArray = [search.businesses sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
            NSString *first = [(NMBusiness *)a distance];
            NSString *second = [(NMBusiness *)b distance];
            return [first compare:second];
        }];
        
        self.locations = [sortedArray mutableCopy];
        self.filteredLocations = [NSMutableArray arrayWithCapacity:[self.locations count]];
        
        
        NSLog(@"mappingResult: %@", search.businesses);

        [self.tableView reloadData];
        [weakSelf.tableView.pullToRefreshView stopAnimating];

    };
    void (^failureBlock)(RKObjectRequestOperation *operation, NSError *error);
    failureBlock = ^(RKObjectRequestOperation *operation, NSError *error) {
        app.networkActivityIndicatorVisible = NO;
        [weakSelf.tableView.pullToRefreshView stopAnimating];


        NSLog(@"ERROR: %@", error);
        NSLog(@"Response: %@", operation.HTTPRequestOperation.responseString);
    };
    [api getBusinesses:location withSuccessBLock:successBlock withFailureBlock:failureBlock];


}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 85;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (tableView == self.searchDisplayController.searchResultsTableView) {
        NSLog(@"Filtered Count: %lu", (unsigned long)self.filteredLocations.count);

        return [self.filteredLocations count];
    } else {
        NSLog(@"Un Count: %lu", (unsigned long)self.locations.count);

        return [self.locations count];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"BusinessCell";
    NMBusinessListViewTableCell *cell = [self.tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if ( cell == nil ) {
        cell = [[NMBusinessListViewTableCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    [self configureCell:cell atIndexPath:indexPath withTableView:tableView];
    return cell;
}

- (void)configureCell:(NMBusinessListViewTableCell *)cell atIndexPath:(NSIndexPath *)indexPath withTableView:(UITableView *)tableView
{
    NMBusiness *business = nil;
    
    if (tableView == self.searchDisplayController.searchResultsTableView) {
        business = [self.filteredLocations objectAtIndex:indexPath.row];
    } else {
        business = [self.locations objectAtIndex:indexPath.row];
    }
    
    NMCategory *category = [business.categories objectAtIndex:0];
    cell.category.text = category.name;
    cell.category.font = [UIFont fontWithName:@"OpenSans" size:13.0f];
    
    cell.name.text = business.name;
    cell.name.font = [UIFont fontWithName:@"OpenSans-Semibold" size:16.0f];
    
    
    NSString *shortDistanceString = [business.distance substringWithRange:NSMakeRange(0,3)];
    NSString *milesLabel = @" miles away";
    NSURL *url = [[NSURL alloc] initWithString:business.photo_url];
    [cell.imageThumbnail setImageWithURL:url];
    
    CALayer * l = [cell.imageThumbnail layer];
    [l setMasksToBounds:YES];
    [l setCornerRadius:3.0];
    [l setBorderWidth:1.0];
    [l setBorderColor:[[UIColor grayColor] CGColor]];
    
    
    [cell.distance setText:[NSString stringWithFormat:@"%@ %@",shortDistanceString, milesLabel]];
    cell.distance.font = [UIFont fontWithName:@"OpenSans" size:13.0f];
    
    BOOL boolValue = [business.is_closed boolValue];
    NSString *open = boolValue ? @"Closed" : @"Open";
    [cell.status setText:open];
    cell.status.font = [UIFont fontWithName:@"OpenSans" size:13.0f];
}

#pragma mark Content Filtering
-(void)filterContentForSearchText:(NSString*)searchText scope:(NSString*)scope {
    NSLog(@"Filter..");
    // Update the filtered array based on the search text and scope.
    // Remove all objects from the filtered search array
    [self.filteredLocations removeAllObjects];
    // Filter the array using NSPredicate
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.name contains[c] %@",searchText];
    self.filteredLocations = [NSMutableArray arrayWithArray:[self.locations filteredArrayUsingPredicate:predicate]];
    NSLog(@"Filtered Locations: %@",self.filteredLocations);
    [self.tableView reloadData];

}

#pragma mark - UISearchDisplayController Delegate Methods
-(BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString {
    NSLog(@"Search.");

    // Tells the table data source to reload when text changes
    [self filterContentForSearchText:searchString scope:
     [[self.searchDisplayController.searchBar scopeButtonTitles] objectAtIndex:[self.searchDisplayController.searchBar selectedScopeButtonIndex]]];
    // Return YES to cause the search result table view to be reloaded.
    return YES;
}

-(BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchScope:(NSInteger)searchOption {
    NSLog(@"Search.ReloadScope");

    // Tells the table data source to reload when scope bar selection changes
    [self filterContentForSearchText:self.searchDisplayController.searchBar.text scope:
     [[self.searchDisplayController.searchBar scopeButtonTitles] objectAtIndex:searchOption]];
    // Return YES to cause the search result table view to be reloaded.
    return YES;
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
}

#pragma mark - Storyboard methods
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    NSLog(@"prepare...");
    if([segue.destinationViewController isKindOfClass:[NMMapView class]]){
        NMMapView *mapViewController = (NMMapView *)segue.destinationViewController;
        [mapViewController setLocations:self.locations];
    } else {
        NSLog(@"table view sender...");
        NMBusinessDetailView *detailView = (NMBusinessDetailView *)segue.destinationViewController;
        NMBusiness *business = [self.locations objectAtIndex:[self.tableView indexPathForSelectedRow].row];
        [detailView setBusiness:business];
    }
}

@end
