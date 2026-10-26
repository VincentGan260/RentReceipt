import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { deviceInfo } from '@kit.BasicServicesKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
export class Appearance {
  static scale: number = 1;
  static animations: boolean = true;
  static mode: number = -1;
  private static settings?: preferences.Preferences;
  private static mainWindow?: window.Window;
  private static barUpdates: Promise<void> = Promise.resolve();

  static bindWindow(value: window.Window, colorMode?: ConfigurationConstant.ColorMode): void {
    Appearance.mainWindow = value;
    Appearance.syncSystemBars(colorMode);
  }

  static unbindWindow(): void { Appearance.mainWindow = undefined; }

  static syncSystemBars(colorMode?: ConfigurationConstant.ColorMode): void {
    const mainWindow = Appearance.mainWindow;
    const dark = Appearance.mode === 0 || (Appearance.mode === -1 &&
      colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
    AppStorage.setOrCreate('statusBarContentColor', dark ? '#FFFFFF' : '#000000');
    // HDS owns system bars during navigation and scrolling; use its declarative style.
    if (!mainWindow || deviceInfo.sdkApiVersion >= 23) { return; }
    Appearance.barUpdates = Appearance.barUpdates.then(async () => {
      if (Appearance.mainWindow !== mainWindow) { return; }
      await mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        statusBarContentColor: dark ? '#FFFFFF' : '#000000'
      });
    }).catch(() => { hilog.warn(0x0000, 'RentReceipt', '状态栏颜色同步失败'); });
  }
  static async open(context: common.UIAbilityContext): Promise<void> {
    if (!Appearance.settings) { Appearance.settings = await preferences.getPreferences(context,{name:'appearance'}); }
    const value = await Appearance.settings.get('colorMode',-1);
    Appearance.mode = value === 0 || value === 1 ? value as number : -1;
    const scale = await Appearance.settings.get('pageScale',1);
    Appearance.scale = typeof scale === 'number' && scale >= 1 && scale <= 1.2 ? scale : 1;
    Appearance.animations = (await Appearance.settings.get('animations',true)) !== false;
    AppStorage.setOrCreate('pageScale',Appearance.scale); AppStorage.setOrCreate('animations',Appearance.animations);
    Appearance.apply(context,Appearance.mode);
  }
  private static apply(context: common.UIAbilityContext,mode: number): void {
    context.getApplicationContext().setColorMode(mode === 0 ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK : mode === 1 ? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT : ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    Appearance.syncSystemBars(context.config.colorMode);
  }
  static async update(context: common.UIAbilityContext,mode: number, scale: number = Appearance.scale, animations: boolean = Appearance.animations): Promise<void> {
    if (!Appearance.settings) { await Appearance.open(context); }
    await Appearance.settings!.put('colorMode',mode);
    await Appearance.settings!.put('pageScale',scale); await Appearance.settings!.put('animations',animations);
    await Appearance.settings!.flush();
    Appearance.mode = mode; Appearance.scale = scale; Appearance.animations = animations;
    AppStorage.setOrCreate('pageScale',scale); AppStorage.setOrCreate('animations',animations); Appearance.apply(context,mode);
  }
}
