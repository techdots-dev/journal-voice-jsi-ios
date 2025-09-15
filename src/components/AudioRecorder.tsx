import React, { useState, useEffect } from 'react';
import { View, StyleSheet, TouchableOpacity, Text, NativeModules } from 'react-native';
import { Audio } from 'expo-av';
import * as FileSystem from 'expo-file-system';
import AudioProcessorTurbo from '../modules/AudioProcessorTurbo';

type RecordingStatus = 'idle' | 'recording' | 'recorded';

const AudioRecorder: React.FC = () => {
  const [recording, setRecording] = useState<Audio.Recording | null>(null);
  const [status, setStatus] = useState<RecordingStatus>('idle');
  const [audioData, setAudioData] = useState<string | null>(null);

  useEffect(() => {
    console.log('New Architecture enabled:',
      typeof global.__turboModuleProxy === 'function');
    return () => {
      // Clean up on unmount
      if (recording) {
        recording.stopAndUnloadAsync();
      }
    };
  }, [recording]);

  const startRecording = async () => {
    try {
      await Audio.requestPermissionsAsync();
      await Audio.setAudioModeAsync({
        allowsRecordingIOS: true,
        playsInSilentModeIOS: true,
      });

      const { recording: newRecording } = await Audio.Recording.createAsync(
        Audio.RecordingOptionsPresets.HIGH_QUALITY
      );

      setRecording(newRecording);
      setStatus('recording');
      setAudioData(null);
    } catch (err) {
      console.error('Failed to start recording', err);
    }
  };

  const stopRecording = async () => {
    if (!recording) {return;}

    try {
      await recording.stopAndUnloadAsync();
      await Audio.setAudioModeAsync({
        allowsRecordingIOS: true,
      });

      const uri = recording?.getURI();
      setAudioData(uri);
      setStatus('recorded');
      setRecording(null);
      // await playAudio(uri!);
    } catch (err) {
      console.error('Failed to stop recording', err);
    }
  };

  const playAudio = async (fileUri: string) => {
    try {
      // 1. Convert file:// URI to Content URI
      const contentUri = `${FileSystem.cacheDirectory}${fileUri.split('/').pop()}`;

      // 2. Copy file to Expo-managed location
      await FileSystem.copyAsync({
        from: fileUri,
        to: contentUri,
      });

      // 3. Play from Expo-managed URI
      const { sound } = await Audio.Sound.createAsync(
        { uri: contentUri },
        { shouldPlay: true }
      );

      sound.setOnPlaybackStatusUpdate(audioStatus => {
        if (audioStatus.didJustFinish) {
          sound.unloadAsync();
          // Clean up temporary file
          FileSystem.deleteAsync(contentUri, { idempotent: true });
        }
      });

      return sound;
    } catch (error) {
      console.error('Playback failed', error);
      throw error;
    }
  };

  const benchmark = async () => {
    // console.time('slowDown');
    // const resultLegacy = await NativeModules.AudioProcessor?.slowDown(audioData);
    // console.timeEnd('slowDown');
    // await playAudio(resultLegacy);
    // console.log(resultLegacy);

    // console.time('slowDown');
    // console.log('inside');
    // const resultLegacy = await AudioProcessorTurbo?.slowDown(audioData!);
    // // await playAudio(resultLegacy);
    // console.log(resultLegacy);
    AudioProcessorTurbo?.slowDown(audioData!)?.then((r) => {
      console.log('res   ', r);
    }).catch((e) => {
      console.log('ee   ', e);
    });
  };

  const resetRecording = () => {
    setStatus('idle');
    setAudioData(null);
  };

  return (
    <View style={styles.container}>
      {status === 'idle' && (
        <TouchableOpacity style={styles.button} onPress={startRecording}>
          <Text style={styles.buttonText}>Start Recording</Text>
        </TouchableOpacity>
      )}
      {status === 'recording' && (
        <TouchableOpacity style={[styles.button, styles.stopButton]} onPress={stopRecording}>
          <Text style={styles.buttonText}>Stop Recording</Text>
        </TouchableOpacity>
      )}

      {status === 'recorded' && (
        <View style={styles.recordedContainer}>
          <TouchableOpacity style={styles.button} onPress={benchmark}>
            <Text style={styles.buttonText}>Play Recording</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.resetButton} onPress={resetRecording}>
            <Text style={styles.resetButtonText}>Reset</Text>
          </TouchableOpacity>
        </View>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  button: {
    backgroundColor: '#007AFF',
    paddingHorizontal: 20,
    paddingVertical: 12,
    borderRadius: 5,
    marginTop: 60,
  },
  stopButton: {
    backgroundColor: '#FF3B30',
  },
  resetButton: {
    paddingHorizontal: 20,
    paddingVertical: 10,
    marginVertical: 5,
  },
  resetButtonText: {
    color: '#007AFF',
    textAlign: 'center',
  },
  buttonText: {
    color: 'white',
    textAlign: 'center',
    fontSize: 16,
  },
  recordedContainer: {
    alignItems: 'center',
  },
});

export default AudioRecorder;
