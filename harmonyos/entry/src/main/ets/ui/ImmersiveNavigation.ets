import { HdsNavigationTitleBarOptions, ScrollEffectType } from '@kit.UIDesignKit';
import { deviceInfo } from '@kit.BasicServicesKit';

// HDS immersive materials are available from HarmonyOS 6.1 (API 23).
export function supportsImmersiveNavigation(): boolean {
  return deviceInfo.sdkApiVersion >= 23;
}

// Material values 101 (IMMERSIVE) / 10 (ADAPTIVE) avoid loading the API 23-only
// material module on older systems. This builder is called only on API 23+.
// Keep the native material, with explicit light/dark button surfaces for HarmonyOS 6.1.
export function gradientTitleBar(title: ResourceStr, moreAction?: () => void, titleBuilder?: CustomBuilder): HdsNavigationTitleBarOptions {
  return {
    enableComponentSafeArea: true,
    style: {
      originalStyle: {
        backgroundStyle: { backgroundColor: Color.Transparent },
        contentStyle: {
          titleStyle: { mainTitleColor: $r('app.color.navigation_icon'), subTitleColor: $r('app.color.navigation_icon') },
          menuStyle: { backgroundColor: $r('app.color.surface'),
            iconColor: $r('app.color.navigation_icon'), textColor: $r('app.color.navigation_icon') },
          backIconStyle: { backgroundColor: $r('app.color.surface'), iconColor: $r('app.color.navigation_icon') }
        }
      },
      scrollEffectStyle: {
        backgroundStyle: { backgroundColor: Color.Transparent },
        contentStyle: {
          titleStyle: { mainTitleColor: $r('app.color.navigation_icon'), subTitleColor: $r('app.color.navigation_icon') },
          menuStyle: { backgroundColor: $r('app.color.surface'),
            iconColor: $r('app.color.navigation_icon'), textColor: $r('app.color.navigation_icon') },
          backIconStyle: { backgroundColor: $r('app.color.surface'), iconColor: $r('app.color.navigation_icon') }
        }
      },
      scrollEffectOpts: { enableScrollEffect: true, scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
      systemMaterialEffect: { materialType: 101,
        materialLevel: 10 }
    },
    content: {
      title: { mainTitle: title },
      stackBuilder: titleBuilder,
      menu: moreAction ? { value: [{ content: { label: '更多设置',
        icon: $r('sys.symbol.gearshape'), action: moreAction } }] } : undefined
    }
  };
}
