import { TurboModule, TurboModuleRegistry } from 'react-native';

export interface Spec extends TurboModule {
  /**
   * Slow down audio at 0.75x and return output file URI
   */
  slowDown(inputUri: string): Promise<string>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('AudioProcessorTurbo');
