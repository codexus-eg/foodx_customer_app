حزمة تصميم فودكس VIP لتطبيق الزبون

الملفات داخل هذه الحزمة:
1) lib/main.dart
   نسخة معدلة من تطبيق الزبون بألوان الشعار الأصفر/الأبيض/الكحلي، مع شعار فودكس داخل السبلاتش وتسجيل الدخول والهيدر.

2) assets/images/foodx_logo.png
   شعار فودكس الكامل لاستخدامه داخل الواجهات.

3) assets/images/foodx_icon.png
   أيقونة مبسطة من الشعار لاستخدامها داخل التطبيق.

4) android/app/src/main/res/mipmap-*/ic_launcher.png
   أيقونات أندرويد الجاهزة لاستبدال أيقونة التطبيق على الهاتف.

مهم جداً:
بعد نسخ الملفات إلى مشروع Flutter، افتح pubspec.yaml وتأكد من إضافة:

flutter:
  uses-material-design: true
  assets:
    - assets/images/foodx_logo.png
    - assets/images/foodx_icon.png

إذا كان عندك assets موجودة سابقاً، فقط أضف السطرين تحت assets.

بعدها نفذ:
cd C:\xampp\htdocs\foodx_customer_app
flutter clean
flutter pub get
flutter run -d 5T5HDAOB85EQW8LZ
