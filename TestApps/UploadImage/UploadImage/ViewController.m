//
//  ViewController.m
//  UploadImage
//
//  Created by Kian Davoudi-Rad on 2017-05-11.
//  Copyright © 2017 Kian Davoudi-Rad. All rights reserved.
//

#import "ViewController.h"
@import Firebase;

@interface ViewController ()
@property (nonatomic, strong) IBOutlet UIImageView* UiImagePickerView;
- (IBAction)takePhoto:  (UIButton *)sender;
- (IBAction)selectPhoto:(UIButton *)sender;
@property (weak, nonatomic) IBOutlet UITextField *statusTextView;

@property (strong, nonatomic) FIRStorageReference *storageRef;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.storageRef = [[FIRStorage storage] reference];

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = paths[0];
    NSString *filePath = [NSString stringWithFormat:@"file:%@/myimage.jpg", documentsDirectory];
    NSURL *fileURL = [NSURL URLWithString:filePath];
    NSString *storagePath = [[NSUserDefaults standardUserDefaults] objectForKey:@"storagePath"];

    // [START downloadimage]
    [[_storageRef child:storagePath]
     writeToFile:fileURL
     completion:^(NSURL * _Nullable URL, NSError * _Nullable error) {
         if (error) {
             NSLog(@"Error downloading: %@", error);
             _statusTextView.text = @"Download Failed";
             return;
         } else if (URL) {
             _statusTextView.text = @"Download Succeeded!";
             _UiImagePickerView.image = [UIImage imageWithContentsOfFile:URL.path];
         }
     }];
    // [END downloadimage]

}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (IBAction)takePhoto:  (UIButton *)sender{

 
 UIImagePickerController *picker = [[UIImagePickerController alloc] init];
 picker.delegate = self;
 picker.allowsEditing = YES;
 picker.sourceType = UIImagePickerControllerSourceTypeCamera;

 [self presentViewController:picker animated:YES completion:NULL];


}

- (IBAction)selectPhoto:(UIButton *)sender {


    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {

        UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"Error"
                                                              message:@"Device has no camera"
                                                             delegate:nil
                                                    cancelButtonTitle:@"OK"
                                                    otherButtonTitles: nil];

        [myAlertView show];

    }

    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.allowsEditing = NO;
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;

    [self presentViewController:picker animated:YES completion:NULL];


}

#pragma Delegate methods
// Cancell the image picker
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {

    [picker dismissViewControllerAnimated:YES completion:NULL];

}


- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {

    //UIImage *chosenImage = info[UIImagePickerControllerEditedImage];


   UIImage *chosenImage = info[UIImagePickerControllerOriginalImage];
    self.UiImagePickerView.image = chosenImage;
    [self uploadToGoogle:chosenImage];

    [picker dismissViewControllerAnimated:YES completion:NULL];

}


#pragma Google 

-(void) uploadToGoogle : (UIImage* )prtToImageData {

    // JPEG
    //NSData *imageData = UIImageJPEGRepresentation(prtToImageData, 0.5);
    // PNG
    NSData *imageData = UIImagePNGRepresentation(prtToImageData);
    // RAW
//    NSData *imageData = prtToImageData;



    //NSString *imagePath = [NSString stringWithFormat:@"%@/%lld.jpeg", [FIRAuth auth].currentUser.uid, (long long)([NSDate date].timeIntervalSince1970 * 1000.0)];
    //NSString *imagePath = [NSString stringWithFormat:@"%@/%lld.png", [FIRAuth auth].currentUser.uid, (long long)([NSDate date].timeIntervalSince1970 * 1000.0)];
      NSString *imagePath = [NSString stringWithFormat:@"%@/%lld.dng", [FIRAuth auth].currentUser.uid, (long long)([NSDate date].timeIntervalSince1970 * 1000.0)];



    FIRStorageMetadata *metadata = [FIRStorageMetadata new];
    //metadata.contentType = @"image/JPEG";
    metadata.contentType = @"image/dng";
    [[_storageRef child:imagePath] putData:imageData metadata:metadata
                                completion:^(FIRStorageMetadata * _Nullable metadata, NSError * _Nullable error) {
                                    if (error) {
                                        NSLog(@"Error uploading: %@", error);
                                        _statusTextView.text = @"Upload Failed";
                                      //  return;
                                    }
                                    [self uploadSuccess:metadata storagePath:imagePath];
                                }];

}

-(void)uploadFailed:(NSError*) error{
    NSLog(@"Error uploading: %@", error);

}

- (void)uploadSuccess:(FIRStorageMetadata *) metadata storagePath: (NSString *) storagePath {
    NSLog(@"Upload Succeeded!");
  //  NSLog( metadata.downloadURL.absoluteString);
    _statusTextView.text = metadata.downloadURL.absoluteString;
    [[NSUserDefaults standardUserDefaults] setObject:storagePath forKey:@"storagePath"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    //    _downloadPicButton.enabled = YES;
}


@end
