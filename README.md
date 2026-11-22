# CHATE-MAHDI

نسخة مشابهة لإنستغرام (Flutter + NestJS) مع ميزة **التحديث الداخلي (In-App Update)**:
يتحقق التطبيق من آخر إصدار على GitHub Releases، ويعرض زر «تحديث»، ثم ينزّل الـ APK ويفتح
مثبّت أندرويد لتثبيته فوق النسخة المثبتة **مع الاحتفاظ بكل البيانات**.

ملحوظة تقنية: جميع مسارات الـ API تحت البادئة `api/` (مثال: `/api/auth/login`)، وملفات الرفع تُخدَّم من `/uploads/` في جذر الخادم.

## مركز التحديث المتطور (v2.0.0)

شاشة «مركز التحديث» الجديدة داخل التطبيق: تصميم تدرّجي متحرك، مقارنة الإصدار الحالي مع الأحدث، تنزيل بشريط تقدم دائري مع نسبة مئوية، إلغاء التنزيل، ثم فتح مثبِّت النظام تلقائياً — كل ذلك من داخل التطبيق.

## خادم مخصص لكل مستخدم
من خلال زر «الخادم الشخصي (متقدم)» في شاشة تسجيل الدخول أو إنشاء الحساب أو الإعدادات، يمكن لكل مستخدم توجيه التطبيق إلى خادمه الخاص المثبَّت عندك (مثال: `http://192.168.1.20:4000` للشبكة المحلية أو دومين عند تشغيل الخادم على VPS). عند تغيير الخادم يتم تسجيل الخروج تلقائياً حتى لا تختلط الحسابات بين خادم وآخر — كل خادم قاعدة بياناته مستقلة تماماً ولا تطابق بين المستخدمين.

## الروابط المهمة

| الغرض | الرابط |
|---|---|
| المستودع | https://github.com/m777m44/CHATE-MAHDI |
| آخر إصدار (Release) | https://github.com/m777m44/CHATE-MAHDI/releases/latest |
| تحميل APK مباشر | https://github.com/m777m44/CHATE-MAHDI/releases/latest/download/CHATE-MAHDI.apk |
| GitHub API لآخر إصدار (يستخدمه التطبيق) | https://api.github.com/repos/m777m44/CHATE-MAHDI/releases/latest |

- **Application ID ثابت:** `com.mahdim44.chatemahdi`
- **اسم ملف الـ APK في كل إصدار:** `CHATE-MAHDI.apk` (ونسخة احتياطية `app-release.apk` متوفرة مع كل إصدار لضمان عدم توقف أي رابط قديم)
- الإصدار الحالي: `2.0.0`، و `versionCode` يزيد تلقائياً مع كل بناء (`github.run_number`).

## التقنيات

- **mobile/** — Flutter + Dart، إدارة حالة Riverpod، شبكة Dio، Socket.io للزمن الحقيقي،
  Light/Dark Theme بستايل إنستغرام.
- **backend/** — NestJS (TypeScript) + Prisma + PostgreSQL + Socket.io + JWT (Access/Refresh)
  + Throttler (Rate limiting) + Helmet + bcryptjs، ورفع الملفات على القرص المحلي أو Cloudinary.

## تشغيل المشروع محلياً

### 1) الباك-إند

```bash
cd backend
cp .env.example .env         # عدّل أسرار JWT في الإنتاج
docker compose up -d         # يشغّل PostgreSQL 16
npm install
npm run prisma:generate
npm run db:push              # إنشاء الجداول
npm run db:seed              # حسابات تجريبية (اختياري) - كلمة المرور password123
npm run start:dev            # http://localhost:4000/api
```

### 2) تطبيق Flutter

```bash
cd mobile
flutter pub get
flutter run
```

- داخل محاكي أندرويد العنوان الافتراضي للـ API هو `http://10.0.2.2:4000/api`.
- يمكن تغيير عنوان الخادم من شاشة تسجيل الدخول (تبويب «عنوان الخادم») أو عبر
  `--dart-define=API_BASE_URL=https://your-domain/api`.
- كل بيانات التطبيق تُحفظ في SharedPreferences (الرموز والإعدادات).

## المتغيرات البيئية

كل المتغيرات موضحة في: `backend/.env.example` و `.env.example` (الجذر). الأهم:

- `DATABASE_URL` — اتصال PostgreSQL.
- `JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET` — أسرار طويلة وعشوائية في الإنتاج.
- `STORAGE_DRIVER=local|cloudinary` — تخزين محلي أو Cloudinary
  (`CLOUDINARY_CLOUD_NAME` / `CLOUDINARY_API_KEY` / `CLOUDINARY_API_SECRET`).
- `CORS_ORIGINS` — نطاقات مسموحة للـ CORS.

## التوقيع والـ Secrets (مهم للتحديث الداخلي)

كي يستطيع التحديث الجديد أن يُثبَّت فوق القديم، يجب أن يبقى **نفس الـ Keystore** و
**نفس Application ID** في كل الإصدارات. الـ Keystore محفوظ في GitHub Secrets:

| Secret | الوصف |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | محتوى `key.jks` بصيغة Base64 |
| `ANDROID_KEYSTORE_PASSWORD` | كلمة مرور المخزن |
| `ANDROID_KEY_ALIAS` | اسم المفتاح |
| `ANDROID_KEY_PASSWORD` | كلمة مرور المفتاح |

> ⚠️ لا تُعِد توليد الـ Keystore وإلا سيرفض أندرويد تثبيت أي تحديث فوق النسخ القديمة
> (Signature mismatch). احتفظ بنسخة احتياطية من قيم الـ Secrets في مكان آمن —
> قيم الـ Secrets في GitHub تُكتب فقط ولا تُقرأ مرة أخرى.

طريقة إعداد الـ Keystore محلياً (مرة واحدة فقط):

```bash
keytool -genkeypair -v -keystore key.jks -alias chatemahdi \
  -keyalg RSA -keysize 2048 -validity 10000
base64 -w0 key.jks > key.jks.b64
gh secret set ANDROID_KEYSTORE_BASE64 < key.jks.b64
gh secret set ANDROID_KEYSTORE_PASSWORD    # أدخل كلمة المرور
gh secret set ANDROID_KEY_ALIAS            # أدخل chatemahdi
gh secret set ANDROID_KEY_PASSWORD         # أدخل كلمة مرور المفتاح
```

التوقيع في `mobile/android/app/build.gradle` يقرأ من متغيرات البيئة:
`CM_KEYSTORE_PATH`, `CM_KEYSTORE_PASSWORD`, `CM_KEY_ALIAS`, `CM_KEY_PASSWORD`
(البناء المحلي بدون هذه المتغيرات يسقط تلقائياً إلى مفتاح debug للاختبار فقط).

> ℹ️ **وضع التوقيع المرحلي:** حتى تضبط الـ Secrets الأربعة، يقوم الـ CI تلقائياً بتوليد
> مفتاح مؤقت (بنمط مفتاح Android debug وهو غير سري — credentials عامة) ويحفظه في
> Actions cache ليبقى التوقيع ثابتاً بين الإصدارات(powerup التحديث الداخلي يعمل).
> بعد ضبط الـ Secrets، تتحول كل الإصدارات القادمة إلى مفتاحك الدائم — لاحظ أن أول
> تحديث بعد هذا التحويل قد يتطلب حذف النسخة القديمة بسبب تغيّر التوقيع، وهي حالة
> لمرة واحدة فقط.

## إصدار تحديث جديد (Releasing)

1. (مرة واحدة) اضبط الـ Keystore والـ Secrets كما في القسم السابق.
2. عدّل الإصدار في `mobile/pubspec.yaml`:
   ```yaml
   version: 1.1.0+2   # زد اسم الإصدار؛ versionCode الفعلي = github.run_number
   ```
3. ارفع إلى `main` (أو أنشئ tag مثل `v1.1.0`):
   ```bash
   git add -A && git commit -m "release v1.1.0" && git push
   ```
4. سيعمل `.github/workflows/android-release.yml` تلقائياً:
   - بناء APK موقّع release (بدون minify/shrink حفاظاً على سلامة التحديث الداخلي).
   - إنشاء Release (أو تحديث الملف بنفس الـ tag) ورفع الملف باسم `CHATE-MAHDI.apk` (و`app-release.apk` احتياطياً).
   - طباعة رقم الإصدار و versionCode في اللوق، والتحقق من رابط التحميل المباشر.
5. المستخدمون الذين عندهم الإصدار الأقدم سيرون: بانر «تحديث متوفر» في الإعدادات،
   نافذة مرة واحدة لكل إصدار، وزر «تحديث الآن» في شاشة «حول التطبيق».

## ميزة التحديث الداخلي (كيف تعمل)

1. التطبيق يستدعي `GET https://api.github.com/repos/m777m44/CHATE-MAHDI/releases/latest`
   (بدون أي توكن داخل التطبيق) ويقرأ `tag_name` و `assets[].name == "CHATE-MAHDI.apk"`
   مع `browser_download_url` و `published_at`.
2. مقارنة إصدار دلالية (semver) بين الإصدار الحالي (`package_info_plus`) والإصدار الأحدث.
3. عند وجود تحديث: التحقق من الاتصال، تنزيل الـ APK إلى مجلد الكاش عبر Dio مع شريط
   تقدم، ثم التحقق من صلاحية الملف (امتداد `.apk` وحجم أكبر من صفر).
4. صلاحية `REQUEST_INSTALL_PACKAGES` معلنة في الـ Manifest؛ وإن لم تكن ممنوحة يفتح
   التطبيق `Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES` مع package URI.
5. التثبيت عبر `FileProvider` + `Intent.ACTION_VIEW`
   (`application/vnd.android.package-archive`, `FLAG_GRANT_READ_URI_PERMISSION`,
   `FLAG_ACTIVITY_NEW_TASK`) — مثبّت النظام هو الذي يثبّت (لا تثبيت صامت).
6. التثبيت فوق النسخة المثبتة (نفس الـ applicationId + نفس التوقيع) يحتفظ بكل البيانات.

## ميزات التطبيق

- مصادقة كاملة (تسجيل/دخول/خروج + تحديث تلقائي للتوكن) والمعلومات محفوظة في الجلسة.
- منشورات: صور/فيديو، وصف مع # هاشتاغ، موقع، إعجاب (نقرة مزدوجة)، تعليقات، حفظ، مشاركة.
- Home Feed مع Pagination، و Reels بخلاصة عمودية مع تشغيل تلقائي وأزرار جانبية.
- قصص (Stories) لمدة 24 ساعة مع شريط تقدم، عدّاد مشاهدات وقائمة المشاهدين، ونص فوق الصورة.
- استكشاف (Explore) وبحث (مستخدمون/هاشتاغات/أماكن).
- رسائل مباشرة: نص/صورة/فيديو، مشاركة منشورات داخل المحادثة، مؤشر كتابة، إشعار قراءة،
  محادثات جماعية.
- إشعارات فورية (Socket.io) + صفحة نشاط (Activity).
- ملف شخصي مع شبكة صور، عدادات متابعة/متابَعين، خصوصية حساب عام/خاص وطلبات متابعة.
- Light/Dark Theme على نمط إنستغرام.

## الأمان

- كلمات المرور مشفرة bcrypt، تحقق مدخلات صارم (class-validator)، Rate limiting على
  مستوى الـ API، Helmet (رؤوس أمان) و CORS مضبوط، والصور تُضغط قبل الرفع
  (`imageQuality: 85`, `maxWidth: 1440`).

## هيكل المشروع

```
mobile/                      # تطبيق Flutter (Android)
  lib/core/                  # API client, sockets, session, theme, update service
  lib/features/              # شاشات التطبيق (auth, feed, stories, reels, dm, ...)
  android/                   # Manifest, FileProvider, MainActivity, signing
backend/                     # NestJS + Prisma + PostgreSQL + Socket.io
  prisma/                    # schema + seed
  src/                       # auth, users, posts, feed, stories, dm, notifications, ...
.github/workflows/           # android-release.yml — بناء ونشر APK موقّع
```

> ملاحظة هندسية: استُخدمت طبقة خدمات Dio مباشرة بدل Retrofit (توليد الكود) لتبسيط
> خط البناء وتقليل نقاط الفشل في CI — نفس النتيجة بمرونة أعلى وصيانة أسهل.
