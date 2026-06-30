# المرحلة الثانية - إضافة الكوبون إلى تطبيق الزبون

هذه الملفات مبنية على `foodx_customer_app(1).zip`.

انسخ الملفات إلى:

```text
C:\xampp\htdocs\foodx_customer_app
```

الملفات التي ستستبدل:

```text
lib/main.dart
lib/services/api_service.dart
```

بعدها شغل:

```bat
cd C:\xampp\htdocs\foodx_customer_app
flutter clean
flutter pub get
flutter run -d 5T5HDAOB85EQW8LZ
```

ماذا تغير؟

- إضافة حقل كوبون داخل صفحة السلة.
- زر تطبيق/إزالة الكوبون.
- عرض خصم الكوبون.
- عرض خصم التوصيل إذا كان نوع الكوبون delivery.
- إرسال coupon_code عند إتمام الطلب.
- يعتمد على Backend المرحلة الأولى.
