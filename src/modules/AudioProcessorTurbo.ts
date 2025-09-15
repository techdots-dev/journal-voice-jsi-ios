import { TurboModule, TurboModuleRegistry } from 'react-native';

export interface Spec extends TurboModule {
  /**
   * Slows down the input audio file and writes to a new file.
   * @param inputUri - file:// URI of the input audio file
   * @returns file:// URI of the processed output
   */
  slowDown(inputUri: string): Promise<string>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('AudioProcessorTurbo');
