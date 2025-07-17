#import <Foundation/Foundation.h>
#import <React/RCTBridgeModule.h>

#import <UIKit/UIKit.h>

@interface RCT_EXTERN_MODULE(ImagePickerModule, NSObject)

RCT_EXTERN_METHOD(openCamera:(NSDictionary *)options 
    withResolver:(RCTPromiseResolveBlock)resolve 
    withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(openGallery:(NSDictionary *)options 
    withResolver:(RCTPromiseResolveBlock)resolve 
    withRejecter:(RCTPromiseRejectBlock)reject)

@end
