/*---------------------------------------------------------------------------------------------------
 *
 * Copyright (c) Microsoft Corporation All rights reserved.
 *
 * MIT License:
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
 * associated documentation files (the  "Software"), to deal in the Software without restriction,
 * including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all copies or substantial
 * portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED ""AS IS"", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
 * NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 *
 * ------------------------------------------------------------------------------------------------*/

#import "AccelerometerViewController.h"


@interface AccelerometerViewController ()<MSBClientManagerDelegate,UITextViewDelegate,MFMessageComposeViewControllerDelegate,CLLocationManagerDelegate>
@property (nonatomic, weak) MSBClient *client;
@end

@implementation AccelerometerViewController
CLLocationManager *locationManager;
CLGeocoder *geocoder;
CLPlacemark *placemark;
bool responded=false;
bool alertShown = false;
NSString *contact = @"";


- (void)viewDidLoad
{
    [super viewDidLoad];
    // Setup View
    [self markSampleReadyAcc:NO];
    [self markSampleReadyHrt:NO];
    self.txtOutput.delegate = self;
    UIEdgeInsets insets = [self.txtOutput textContainerInset];
    insets.top = 20;
    insets.bottom = 20;
    [self.txtOutput setTextContainerInset:insets];
    
    // Setup Band
    [MSBClientManager sharedManager].delegate = self;
    NSArray	*clients = [[MSBClientManager sharedManager] attachedClients];
    self.client = [clients firstObject];
    if (self.client == nil)
    {
        [self output:@"Failed! No Bands attached."];
        return;
    }
    
    [[MSBClientManager sharedManager] connectClient:self.client];
    [self output:[NSString stringWithFormat:@"Please wait. Connecting to Band <%@>", self.client.name]];
    
    [_textButton setTitle:@"Text Emergency Contact" forState:UIControlStateNormal];
    _textButton.titleLabel.textAlignment = NSTextAlignmentCenter;
    _textButton.titleLabel.numberOfLines = 0;
    _textButton.titleLabel.lineBreakMode = UILineBreakModeWordWrap;
    
    // first check to see if the flag is set
//    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    
    [self performSelector:@selector(enterContact) withObject:nil afterDelay:2];
    
    [locationManager requestWhenInUseAuthorization];
    [locationManager requestAlwaysAuthorization];
    if ([CLLocationManager locationServicesEnabled]) {
        NSLog(@"Location services are enabled");
        locationManager = [[CLLocationManager alloc] init];
        locationManager.delegate = self;
        [locationManager startUpdatingLocation];
        } else {
            NSLog(@"Location services are not enabled");
        }
    
    geocoder = [[CLGeocoder alloc] init];
    
    
}

- (void)enterContact
{
    if (alertShown == false) {
        // show the alert
        UIAlertController *theAlert = [UIAlertController alertControllerWithTitle:@"Please enter an emergency contact" message:@"You do not have one saved" preferredStyle:UIAlertControllerStyleAlert];
        [theAlert addTextFieldWithConfigurationHandler:nil];
        
        
        
        UIAlertAction *actionOk = [UIAlertAction actionWithTitle:@"Ok"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * _Nonnull action) {
                                                             NSArray *txtFields = theAlert.textFields;
                                                             UITextField *txtField = [txtFields objectAtIndex:0];
                                                             contact = txtField.text;
                                                         }];
        [theAlert addAction:actionOk];
        [self presentViewController:theAlert animated: YES completion: nil];
        
        alertShown = true;
    }
}

-(void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations
{
    NSLog(@"hi");
    CLLocation *currentLocation = [locations objectAtIndex:([locations count]-1)];
    NSLog(@"didUpdateToLocation: %@", currentLocation);
    if (currentLocation != nil) {
        _longitudeLabel.text = [NSString stringWithFormat:@"%.8f", currentLocation.coordinate.longitude];
        _latitudeLabel.text = [NSString stringWithFormat:@"%.8f", currentLocation.coordinate.latitude];
    }
    
    // Reverse Geocoding
    NSLog(@"Resolving the Address");
    [geocoder reverseGeocodeLocation:currentLocation completionHandler:^(NSArray *placemarks, NSError *error) {
        NSLog(@"Found placemarks: %@, error: %@", placemarks, error);
        if (error == nil && [placemarks count] > 0) {
            placemark = [placemarks lastObject];
            _addressLabel.text = [NSString stringWithFormat:@"%@ %@\n%@ %@\n%@\n%@",
                                  placemark.subThoroughfare, placemark.thoroughfare,
                                  placemark.postalCode, placemark.locality,
                                  placemark.administrativeArea,
                                  placemark.country];
        } else {
            NSLog(@"%@", error.debugDescription);
        }
    } ];

}



-(IBAction)callPhone:(id)sender {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"tel:7746413690"]];
}
-(IBAction)callEmergCont:(id)sender {
    NSString *newTel = [NSString stringWithFormat:@"tel:%@", contact];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:newTel]];
}

- (IBAction)textEmergency:(id)sender {
    [self sendMessage:@"I need help immediately, at this location: 1500 Corporate Dr, Canonsburg, PA, 15317, United States"];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)sendMessage:(NSString *)message
{
    MFMessageComposeViewController *messageVC = [[MFMessageComposeViewController alloc] init];
    
    messageVC.body = [NSString stringWithFormat:@"%@", message];
    messageVC.recipients = @[contact];
    messageVC.messageComposeDelegate = self;
    
    [self presentViewController:messageVC animated:NO completion:NULL];
}

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller didFinishWithResult:(MessageComposeResult)result
{
    [self dismissModalViewControllerAnimated:YES];
    if (result == MessageComposeResultCancelled)
        NSLog(@"Message cancelled");
        else if (result == MessageComposeResultSent)
            NSLog(@"Message sent");
            else
                NSLog(@"Message failed");  
}

- (IBAction)getCurrentLocation:(id)sender {
    locationManager.delegate = self;
    locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    
    [locationManager startUpdatingLocation];
}

- (void)didTapStartAccelerometerButton:(id)sender
{
    [self markSampleReadyAcc:NO];
    [self output:@"Starting Accelerometer updates..."];
    __weak typeof(self) weakSelf = self;
    __block NSMutableArray *accels = [NSMutableArray array];
    __block typeof(int) i = 0;
    __block NSNumber *diff = [NSNumber numberWithDouble:1.0];
    __block NSNumber *max = [NSNumber numberWithDouble:0.0];
    
    void (^handler)(MSBSensorAccelerometerData *, NSError *) = ^(MSBSensorAccelerometerData *accelerometerData, NSError *error)
    {
        weakSelf.accelLabel.text = [NSString stringWithFormat:@"X = %5.2f Y = %5.2f Z = %5.2f",
                                    accelerometerData.x,
                                    accelerometerData.y,
                                    accelerometerData.z];
        
        double x = accelerometerData.x;
        double y = accelerometerData.y;
        double z = accelerometerData.z;

        double acc = sqrt(pow(x, 2.0)+pow(y, 2.0)+pow(z, 2.0));
        double theta = acos(acc);
        [accels addObject:[NSNumber numberWithDouble:acc]];
        i += 1;
        //Fall Detection
        if (i==40) {
            max = [accels valueForKeyPath:@"@max.doubleValue"];
            NSNumber *min = [accels valueForKeyPath:@"@min.doubleValue"];
            diff = [NSNumber numberWithDouble:([max doubleValue]-[min doubleValue])];
            
            i = 0;
            accels = [NSMutableArray array];
        }
        max = [accels valueForKeyPath:@"@max.doubleValue"];
        if ([diff doubleValue] < 0.4) {
            if (theta > 0.3) {
                if([max doubleValue] > 2) {
                    NSLog(@"true");
                    [self performSelector:@selector(checkIfResponded) withObject:nil afterDelay:10];
                    [self popAlert];
                    
                    
                }
            }
        }
        weakSelf.accelLabel.hidden = YES;
    };
    
    
    NSError *stateError;
    if (![self.client.sensorManager startAccelerometerUpdatesToQueue:nil errorRef:&stateError withHandler:handler])
    {
        [self sampleDidCompleteWithOutput:stateError.description];
        return;
    }
    
    //Stop Accel updates after 1000 seconds
    [self performSelector:@selector(stopAccelUpdates) withObject:0 afterDelay:1000];
}

- (void)checkIfResponded
{
    if (!responded){
        //call person
        [self callEmergCont:self];
    }
}

- (void)popAlert
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Do you need help?"
                                                                   message:@"We think that you may have fallen"
                                 preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *actionNo = [UIAlertAction actionWithTitle:@"No"
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction * _Nonnull action) {
                                                         responded=true;
                                                     }];
    UIAlertAction *actionYes = [UIAlertAction actionWithTitle:@"Yes"
                                                      style:UIAlertActionStyleDestructive
                                                    handler:^(UIAlertAction * _Nonnull action) {
                                                        [self callPhone:self];
                                                        [self textEmergency:self];
                                                        responded=true;
                                                    }];
    
    [alert addAction:actionYes];
    [alert addAction:actionNo];
    [self presentViewController:alert animated:YES completion:nil];
    
}

- (void)stopAccelUpdates
{
    [self.client.sensorManager stopAccelerometerUpdatesErrorRef:nil];
    [self sampleDidCompleteWithOutput:@"Accelerometer updates stopped..."];
}

- (void)didTapStartHRSensorButton:(id)sender
{
    [self markSampleReadyHrt:NO];
    if ([self.client.sensorManager heartRateUserConsent] == MSBUserConsentGranted)
    {
        [self startHearRateUpdates];
    }
    else
    {
        [self output:@"Requesting user consent for accessing HeartRate..."];
        __weak typeof(self) weakSelf = self;
        [self.client.sensorManager requestHRUserConsentWithCompletion:^(BOOL userConsent, NSError *error) {
            if (userConsent)
            {
                [weakSelf startHearRateUpdates];
            }
            else
            {
                [weakSelf sampleDidCompleteWithOutput:@"User consent declined."];
            }
        }];
    }
}

- (void)startHearRateUpdates
{
    [self output:@"Starting Heart Rate updates..."];
    
    __weak typeof(self) weakSelf = self;
    __block typeof(int) i =0;
    void (^handler)(MSBSensorHeartRateData *, NSError *) = ^(MSBSensorHeartRateData *heartRateData, NSError *error) {
        weakSelf.hrLabel.text = [NSString stringWithFormat:@"Heart Rate: %3u %@",
                                 (unsigned int)heartRateData.heartRate,
                                 heartRateData.quality == MSBSensorHeartRateQualityAcquiring ? @"Acquiring" : @"Locked"];
        NSLog(@"%@", weakSelf.hrLabel.text);
        weakSelf.heartLabel.text = [NSString stringWithFormat:@"%3u", (unsigned int)heartRateData.heartRate];
        weakSelf.hrLabel.hidden = YES;
        if (i == 100) {
            if ((unsigned int)heartRateData.heartRate < 40){
                
                [self sendMessage:@"Warning: Activity is low today."];
            }
            else if ((unsigned int)heartRateData.heartRate > 160) {
                [self sendMessage:@"Warning: Activity is high today."];
            }
            else {
                NSLog(@"average");
                [self sendMessage:@"Activity at normal level today."];
            }
            i = 0;
        }
        i++;
    };
    
    NSError *stateError;
    if (![self.client.sensorManager startHeartRateUpdatesToQueue:nil errorRef:&stateError withHandler:handler])
    {
        [self sampleDidCompleteWithOutput:stateError.description];
        return;
    }
    
    [self performSelector:@selector(stopHeartRateUpdates) withObject:nil afterDelay:1000];
}

- (void)stopHeartRateUpdates
{
    [self.client.sensorManager stopHeartRateUpdatesErrorRef:nil];
    [self sampleDidCompleteWithOutput:@"Heart Rate updates stopped..."];
}

#pragma mark - Helper methods

- (void)sampleDidCompleteWithOutput:(NSString *)output
{
    [self output:output];
    [self markSampleReadyAcc:YES];
    [self markSampleReadyHrt:YES];
}

- (void)markSampleReadyAcc:(BOOL)ready
{
    self.startAccelerometerButton.enabled = ready;
    self.startAccelerometerButton.alpha = ready ? 1.0 : 0.2;
}

- (void)markSampleReadyHrt:(BOOL)ready
{
    self.startHRSensorButton.enabled = ready;
    self.startHRSensorButton.alpha = ready ? 1.0 : 0.2;
}

- (void)output:(NSString *)message
{
    if (message)
    {
        NSLog(@"%@",message);
//        self.txtOutput.text = [NSString stringWithFormat:@"%@\n%@", self.txtOutput.text, message];
//        [self.txtOutput layoutIfNeeded];
//        if (self.txtOutput.text.length > 0)
//        {
//            [self.txtOutput scrollRangeToVisible:NSMakeRange(self.txtOutput.text.length - 1, 1)];
//        }
    }
}

#pragma mark - UITextViewDelegate

- (BOOL)textViewShouldBeginEditing:(UITextView *)textView
{
    return NO;
}

#pragma mark - MSBClientManagerDelegate

- (void)clientManager:(MSBClientManager *)clientManager clientDidConnect:(MSBClient *)client
{
    [self markSampleReadyAcc:YES];
    [self markSampleReadyHrt:YES];
    [self output:[NSString stringWithFormat:@"Band <%@> connected.", client.name]];
    [self didTapStartAccelerometerButton:self];
    [self didTapStartHRSensorButton:self];
}

- (void)clientManager:(MSBClientManager *)clientManager clientDidDisconnect:(MSBClient *)client
{
    [self markSampleReadyAcc:NO];
    [self markSampleReadyHrt:NO];
    [self output:[NSString stringWithFormat:@"Band <%@> disconnected.", client.name]];
}

- (void)clientManager:(MSBClientManager *)clientManager client:(MSBClient *)client didFailToConnectWithError:(NSError *)error
{
    [self output:[NSString stringWithFormat:@"Failed to connect to Band <%@>.", client.name]];
    [self output:error.description];
}

@end
