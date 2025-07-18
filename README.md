# Image Picker for React Native

This package provides a React Native package for picking images from the device's gallery or camera. It supports both Android and iOS platforms.

## Screenshots 📸

<p align="left">
  <img width=200 title="Example" src="https://github.com/calico-games/react-native-image-picker-next/blob/main/screenshots/example.png">
  <img width=200 title="iOS" src="https://github.com/calico-games/react-native-image-picker-next/blob/main/screenshots/ios.png">
  <img width=200 title="Android" src="https://github.com/calico-games/react-native-image-picker-next/blob/main/screenshots/android.jpg">
  <img width=200 title="Circular Crop" src="https://github.com/calico-games/react-native-image-picker-next/blob/main/screenshots/circular.jpg">
</p>

### Features 🚀

* 🏎️ Native image picker supporting last APIs
* 🔍 Cropping (native for iOS & custom)
* ✅ WebP compression support
* 📷 Camera support
* 🆕 Support both old & new architecture

## Device Support 📱

| Platform         | Supported |
| ---------------- | --------- |
| iOS Device       | ✅        |
| iOS Simulator    | ✅        |
| Android Device   | ✅        |
| Android Emulator | ✅        |

## Installation 🚀

To install the package, run the following command:

```sh
npm install react-native-image-picker-next

or

yarn add react-native-image-picker-next
```

And finally, add this at the end of your `ios/Podfile`:

```ruby
# Add this at the end
pod 'libwebp', :modular_headers => true
pod 'TOCropViewController', :modular_headers => true
```

## Usage 😈

```tsx
import React, {JSX} from 'react';
import {Button, Text, View, Image} from 'react-native';
import ImagePicker from 'react-native-image-picker-next';

function App(): JSX.Element {
  const [photoURL, setPhotoURL] = React.useState<string | null>(null);

  const pickerOptions = {
    isCropping: true,
    width: 400,
    height: 400,
    compressionQuality: 0.8,
    useWebP: true,
    shouldResize: true,
    useFrontCamera: true,
    useNativeCropper: false,
    isCropCircular: false,
    isTemp: true,
  };

  const openPicker = async () => {
    try {
      const fileURL = await ImagePicker.openGallery(pickerOptions);

      if (fileURL) {
        setPhotoURL(fileURL);
        console.log('Selected Image URI: ', fileURL);
      } else {
        throw new Error('No File');
      }
    } catch (error: any) {
      if (error.code === 'PICKER_CANCELLED_ERROR') {
        return;
      }

      console.error('Error opening gallery: ', error);
    }
  };

  const openCamera = async () => {
    try {
      const fileURL = await ImagePicker.openCamera(pickerOptions);

      if (fileURL) {
        setPhotoURL(fileURL);
        console.log('Captured Image URI: ', fileURL);
      } else {
        throw new Error('No File');
      }
    } catch (error: any) {
      if (error.code === 'PICKER_CANCELLED_ERROR') {
        return;
      }

      console.error('Error opening camera: ', error);
    }
  };

  return (
    <View>
      <Button title="Pick an image" onPress={() => openPicker()} />
      <Button title="Open Camera" onPress={() => openCamera()} />
    </View>
  );
}

export default App;
```

## Options ⚙

| Property | Type | Default | Description |
| -------- | :---: | :---: | :---------- |
| isCropping | bool | false | Enable or disable cropping |
| width | number | 200 | Width of result image when used with `shouldResize` option |
| height | number | 200 | Height of result image when used with `shouldResize` option |
| compressionQuality | number | 0.5 | Compress image with quality (from 0 to 1, where 1 is best quality). |
| useWebP | bool | true | Whether to use WebP format for the image. |
| shouldResize | bool | true | Whether to resize the image to the specified height and width. |
| useFrontCamera | bool | true | Whether to default to the front camera when opened. Please note that not all Android devices handle this parameter |
| useNativeCropper | bool | false | Whether to use the native cropper provided by `UIImagePickerController`. If false, it will use a custom cropper (iOS only). |
| isCropCircular | bool | true | Whether to enable circular cropping. This will only work if `isCropping` is true. |
| isTemp | bool | false | Whether to save the image in a temporary directory. If true, the image will be saved in the temporary directory, otherwise it will be saved in the document directory. |

## Troubleshooting 🛠

If your app crashes when trying to open the camera on iOS, ensure that you have the necessary permission in your `Info.plist` file:

```xml
<key>NSCameraUsageDescription</key>
<string>Allow $(PRODUCT_NAME) to access your camera</string>
```

Note that you do not need to add the `NSPhotoLibraryUsageDescription` key to work, as it does not access the photo library directly and uses the native iOS image picker.

## License 📄

MIT License

## Acknowledgements 🙏

This projects would have been more difficult to build without the following libraries:

* [uCrop](https://github.com/Yalantis/uCrop) for cropping images on Android.
* [TOCropViewController](https://github.com/TimOliver/TOCropViewController) for cropping images on iOS.
* [SDWebImage & libWebP](https://github.com/SDWebImage/libwebp-Xcode) for WebP compression support on iOS.
