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
    isTemp: false,
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
    <View style={{flex: 1, justifyContent: 'center', alignItems: 'center', backgroundColor: '#fff'}}>
      {photoURL && (
        <Image
          source={{uri: photoURL}}
          style={{width: 200, height: 200, marginVertical: 20}}
        />
      )}
      <Text style={{fontSize: 18, marginBottom: 20}}>
        {photoURL ? 'Current Image' : 'No Image Selected'}
      </Text>
      <Button
        title="Pick an image"
        onPress={() => openPicker()}
      />
      <View style={{height: 20}} />
      <Button
        title="Open Camera"
        onPress={() => openCamera()}
      />
    </View>
  );
}

export default App;
