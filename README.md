# Image Picker for React Native

This package provides a React Native package for picking images from the device's gallery or camera. It supports both Android and iOS platforms.

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
pod 'SDWebImage', :modular_headers => true
pod 'SDWebImageWebPCoder', :modular_headers => true
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
# react-native-image-picker-next
