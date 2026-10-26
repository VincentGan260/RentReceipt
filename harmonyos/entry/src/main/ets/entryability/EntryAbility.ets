import { UIAbility, Configuration } from '@kit.AbilityKit';
import { Appearance } from '../data/Appearance';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { StoreSession } from '../data/StoreSession';

export default class EntryAbility extends UIAbility {
  onWindowStageCreate(windowStage: window.WindowStage): void {
    this.loadPage(windowStage).catch(() => {
      hilog.error(0x0000, 'RentReceipt', '应用初始化失败');
    });
  }

  private async loadPage(windowStage: window.WindowStage): Promise<void> {
    await Promise.all([
      StoreSession.open(this.context.filesDir),
      Appearance.open(this.context).catch(() => { hilog.warn(0x0000, 'RentReceipt', '外观设置读取失败'); })
    ]);
    const mainWindow = await windowStage.getMainWindow();
    Appearance.bindWindow(mainWindow, this.context.config.colorMode);
    try {
      windowStage.loadContent('pages/Index', (error) => {
        if (error.code) {
          hilog.error(0x0000, 'RentReceipt', '页面加载失败：%{public}d', error.code);
        }
      });
    } catch {
      hilog.error(0x0000, 'RentReceipt', '页面加载异常');
    }
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    Appearance.syncSystemBars(newConfig.colorMode ?? this.context.config.colorMode);
  }

  onForeground(): void { Appearance.syncSystemBars(this.context.config.colorMode); }

  onWindowStageDestroy(): void { Appearance.unbindWindow(); }

  onBackground(): void {
    StoreSession.store?.flush().catch(() => {
      hilog.error(0x0000, 'RentReceipt', '本地数据保存失败');
    });
  }
}
