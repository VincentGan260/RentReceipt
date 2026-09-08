# R8 / ProGuard 规则
#
# 本项目的金额计算、备份读写均通过显式字段访问完成，没有用到反射或
# Gson/Moshi 之类的序列化框架，因此不需要额外的 keep 规则。
# 若后续引入了反射、JNI 回调或序列化库，请在此补充对应规则。

# 保留 Kotlin 元数据，避免 Kotlin 反射相关能力被裁剪（Compose 编译器会用到）
-keepattributes RuntimeVisibleAnnotations,AnnotationDefault
-keep class kotlin.Metadata { *; }

# 保留数据类的无参构造信息与组件方法，便于调试栈信息可读
-keepclassmembers class com.vincent.rentreceipt.model.** {
    <init>(...);
}

# 打印被移除的成员，便于排查裁剪过度问题
-printusage build/outputs/proguard/release/unused.txt
