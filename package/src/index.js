import {NativeModules} from 'react-native';

const ImagePicker = NativeModules.ImagePickerModule;

export default ImagePicker;
export const openCamera = ImagePicker.openCamera;
export const openGallery = ImagePicker.openGallery;
