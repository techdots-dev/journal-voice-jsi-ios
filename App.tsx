import React from 'react';
import { SafeAreaView } from 'react-native';
import AudioRecorder from './src/components/AudioRecorder';
function App(): React.JSX.Element {

  return (
    <SafeAreaView>
      <AudioRecorder />
    </SafeAreaView>
  );
}

export default App;
