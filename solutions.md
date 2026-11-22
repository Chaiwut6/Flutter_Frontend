# บันทึกแนวทางแก้ไขและการใช้ AI

## Part A — Tickets และ features

### RES-101 · ผลค้นหาไม่ตรงกับคำค้นล่าสุด

- **สาเหตุ:** ทุกครั้งที่พิมพ์ ตัว controller ส่ง request ใหม่ แต่ทุก response เขียนทับผลลัพธ์โดยไม่ตรวจว่าเป็นคำค้นล่าสุดหรือไม่ เมื่อ request ของคำสั้นกว่ากลับมาช้ากว่า จึงทับผลของคำค้นสุดท้าย
- **วิธีแก้และเหตุผล:** เพิ่มเลข generation ให้ request แต่ละครั้ง และนำผลมาใช้เฉพาะ generation ปัจจุบัน การล้างช่องค้นหาและการปิด controller ก็เพิ่ม generation เพื่อทำให้ request ที่ค้างอยู่หมดสิทธิ์เปลี่ยน UI วิธีนี้แก้ race condition โดยตรง แม้ request ก่อนหน้ายังยกเลิกที่เครือข่ายไม่ได้
- **ทางเลือกที่พิจารณาแต่ไม่เลือก:** debounce อย่างเดียว เพราะช่วยลดจำนวน request แต่ไม่ได้รับประกันลำดับ response; การยกเลิก request จะเหมาะถ้า repository/API รองรับ cancellation ซึ่งปัจจุบันไม่รองรับ
- **Edge cases:** ล้างช่องระหว่าง request ค้าง, response เก่ากลับมาทีหลัง และ error จาก request เก่า จะไม่ทำให้ state ของคำค้นล่าสุดเสียหาย ไม่ได้ยกเลิกงานเครือข่ายที่ส่งไปแล้วจริง ๆ

### RES-102 · `setState` หลังออกจาก My orders

- **สาเหตุ:** `PickupCountdown` สร้าง `Timer.periodic` ใน `initState` แต่ไม่ได้เก็บหรือยกเลิก timer เมื่อ `State` ถูก dispose; callback จึงเรียก `setState` บน widget ที่ถูกทำลายแล้ว
- **วิธีแก้และเหตุผล:** เก็บ `Timer` เป็น field และ cancel ใน `dispose()` ให้ timer มีอายุเท่ากับ widget
- **ทางเลือกที่พิจารณาแต่ไม่เลือก:** เช็ก `mounted` ก่อน `setState` เพราะช่วยป้องกัน exception แต่ปล่อย timer และ callback ที่ไม่จำเป็นให้ทำงานต่อ
- **Edge cases:** การออกจากหน้าก่อน tick แรกและ countdown หลายแถวที่มี timer แยกกัน การยกเลิกใน `dispose` ครอบคลุมแต่ละ instance; ไม่ได้หยุด timer เมื่อ pickup เริ่ม เพราะ widget ยังต้องแสดงสถานะ pickup ที่เปิดแล้ว

### RES-103 · request รายละเอียดดีลสะสมหลังปิดหน้า

- **สาเหตุ:** `ever(cartService.itemCount, ...)` คืน `Worker` แต่ controller ไม่เก็บไว้ `CartService` อยู่ตลอด session จึงยังถือ listener ของ controller หน้าดีลเก่า และทุกการเปลี่ยน cart ทำให้ทุก listener เรียก `GET /deals/:id`
- **วิธีแก้และเหตุผล:** เก็บ `Worker` และ dispose ใน `DealDetailsController.onClose()` ซึ่งเป็น lifecycle ของ GetX controller ที่ผูกกับ route
- **ทางเลือกที่พิจารณาแต่ไม่เลือก:** พึ่งให้ GetX dispose worker เอง เพราะ worker เป็น subscription แยกและไม่ได้ถูกยกเลิกอัตโนมัติ
- **Edge cases:** หลัง dispose แล้วจะไม่มี request ใหม่จาก cart listener เก่า แต่ request ที่เริ่มไปแล้วก่อนปิดหน้าไม่สามารถยกเลิกได้ด้วย `Worker.dispose()`; ไม่ได้เพิ่ม cancellation ให้ repository

### RES-104 · การ์ดซ้ำเมื่อ refresh ระหว่างโหลดหน้าถัดไป

- **สาเหตุ:** `loadMore` เพิ่ม `_page` ก่อน request สำเร็จ ขณะเดียวกัน refresh รีเซ็ต `_page` เป็น 1; response ของหน้าเก่ายัง append ได้ ทำให้รายการกับ cursor ไม่ตรงกันและโหลดหน้าเดิมซ้ำ
- **วิธีแก้และเหตุผล:** ใช้ generation ให้ refresh ใหม่ทำให้ผล pagination เก่าหมดสิทธิ์ append, กัน load-more ระหว่าง refresh และขยับ cursor เมื่อรับหน้าสำเร็จเท่านั้น พร้อมกรองดีลซ้ำด้วย id ก่อน append
- **ทางเลือกที่พิจารณาแต่ไม่เลือก:** ใช้ boolean lock อย่างเดียว เพราะ lock กัน request พร้อมกันได้ แต่ไม่บอกว่า response เก่าถูก refresh แทนที่แล้ว; การบังคับให้ refresh รอ pagination อาจทำให้ refresh ช้าโดยไม่จำเป็น
- **Edge cases:** refresh ซ้ำ, request หน้าถัดไปล้มเหลว และผลหน้าเก่ากลับมาหลัง refresh การเปลี่ยนแปลง catalog ระหว่างแบ่งหน้าอาจยังทำให้บางรายการตกหล่นได้; การแก้ระดับนั้นต้องใช้ cursor/consistency contract จาก API

### RES-106 · เวลา pickup และตัวกรอง “Pickup today” ผิด

- **สาเหตุ:** `DateTime.parse()` เก็บค่า ISO-8601 ที่ลงท้ายด้วย `Z` เป็น UTC แต่ label format ค่า UTC โดยตรง และ `isToday` เทียบเลขวัน UTC กับวัน local เพียงอย่างเดียว จึงเหลื่อมวันและอาจสับสนข้ามเดือน/ปี
- **วิธีแก้และเหตุผล:** แปลง start/end เป็น local time ตอนแสดง label และตรวจปี เดือน วันครบถ้วนจาก start local โดยยังเก็บ `start`/`end` เป็น UTC instants ตาม contract ของ API
- **ทางเลือกที่พิจารณาแต่ไม่เลือก:** บวกชั่วโมง UTC+7 เอง เพราะเป็นการ hard-code offset และไม่เหมาะหาก timezone ของผู้ใช้/ตลาดเปลี่ยน; เปลี่ยนค่า model ทั้งหมดเป็น local ก็ทำให้ความหมายของ instant ที่ API ส่งมาไม่ชัด
- **Edge cases:** เวลา UTC ที่ข้ามวันหรือข้ามเดือนถูกจัดการผ่าน `toLocal()` และเทียบ calendar date ครบ ส่วน timezone ของร้านที่ต่างจาก timezone ของเครื่องยังไม่ได้กำหนดเป็นนโยบายแยก หากรองรับหลายตลาดควรระบุ timezone ของตลาด/ร้านและใช้ timezone database

### F-1 · Live flash-sale countdowns

- **สาเหตุ:** flash rail แสดงข้อความคงที่ “Ends soon”; home card และหน้ารายละเอียดไม่มี countdown หรือ state หมดอายุที่เชื่อถือได้
- **วิธีแก้และเหตุผล:** เพิ่ม `FlashSaleCountdown` ซึ่งอัปเดต `ValueListenableBuilder` เฉพาะ Text; การ์ดอัปเดต state เพียงครั้งเดียวเมื่อหมดเวลา ส่วน `CartService` ตั้ง timer ต่อรายการในตะกร้า เอาดีลออกและแจ้ง snackbar แม้ผู้ใช้ไม่ได้อยู่หน้าดีล พร้อมตรวจป้องกันการเพิ่มดีลที่หมดอายุ
- **ทางเลือกที่พิจารณาแต่ไม่เลือก:** `setState` ที่ card ทุกวินาที เพราะทำให้ subtree ของการ์ด rebuild โดยไม่จำเป็น; ตรวจวันหมดอายุเฉพาะตอนกด Add อย่างเดียว เพราะไม่เอารายการที่อยู่ใน cart ออกโดยอัตโนมัติ
- **Edge cases:** ดีลหมดอายุก่อนเปิดหน้าจอ, เพิ่มซ้ำใน cart, ดีลเดียวปรากฏหลายตำแหน่ง และ timer ถูกยกเลิกเมื่อ cart item ถูกนำออก รองรับการตรวจ deadline ตอนกดเพิ่มแม้ timer UI ยังไม่ tick; timer ในแอปอาจทำงานช้าขณะระบบพักแอป จึงตรวจ deadline ซ้ำตอนเพิ่ม แต่การบังคับใช้ขั้นสุดท้ายบน server อยู่นอกขอบเขตนี้

### F-2 · Impression tracking

- **สาเหตุ:** เดิมไม่มีการตรวจเวลาที่การ์ดมองเห็น ไม่มีการ deduplicate impression ข้ามหน้าจอ และไม่มีการส่ง event แบบ batch
- **วิธีแก้และเหตุผล:** `DealImpressionTracker` เริ่มจับเวลาเมื่อเห็นการ์ดอย่างน้อย 50% และยกเลิกเมื่อหลุดเกณฑ์; ครบหนึ่งวินาทีจึงเรียก `AnalyticsService` ซึ่ง deduplicate ด้วย deal id ต่อ session และส่ง batch เมื่อครบ 10 events หรือครบ 15 วินาทีจาก event แรกที่ยังค้าง Events ถูกเพิ่มใน in-memory list ทันที จึงตรวจได้ใน Analytics debug ก่อนส่ง batch เสร็จ
- **ทางเลือกที่พิจารณาแต่ไม่เลือก:** บันทึก impression ตอน build หรือส่งทุก event ทันที เพราะ build ไม่ได้แปลว่าผู้ใช้เห็นการ์ด และการส่งแยกทีละรายการเพิ่ม request และลดประสิทธิภาพ
- **Edge cases:** การ scroll ออกก่อนครบหนึ่งวินาทียกเลิก timer; หากดีลเดียวปรากฏใน rail/feed/search จะนับครั้งแรกที่ผ่านเกณฑ์เท่านั้น ส่วน batch ที่ส่งไม่สำเร็จถูกนำกลับเข้าคิวและบันทึก error ไม่ได้เพิ่ม persistent queue สำหรับกรณีปิดแอป/ออฟไลน์

## บันทึกการใช้ AI

### เครื่องมือที่ใช้

- `rg`, `glob`, `view` และการอ่าน diff ใช้ค้นหา call sites, lifecycle, model, API contract และตรวจขอบเขตไฟล์
- `apply_patch` ใช้แก้ controller, model, widget, service และเพิ่ม regression tests
- `dart format` ใช้จัดรูปแบบ Dart; `dart analyze` ใช้ตรวจ type และ compile-time issues
- `flutter test` ใช้เรียก regression tests ในบางช่วง แต่หลายครั้งคำขอรันถูกปฏิเสธ จึงไม่อ้างว่าชุดทดสอบเหล่านั้นผ่าน
- `git status`/`git diff` ใช้ตรวจไฟล์เปลี่ยนและหลีกเลี่ยงไฟล์ที่ไม่เกี่ยวข้อง; `ask_user` ใช้ถามขอบเขตไฟล์เมื่อคำว่า “commit เฉพาะไฟล์นี้” ไม่ระบุไฟล์
- อ่าน `FakeApiService` เพื่อเข้าใจ API contract เท่านั้น ไม่ได้แก้ไฟล์ backend หรือ `assets/data/`

### ตัวอย่างคำแนะนำจาก AI ที่ผิดหรือชวนเข้าใจผิด

1. ในรอบแรกของ F-1 ผมยกเลิก timer เดิมใน `didUpdateWidget` แต่ลืมตั้ง field `_timer` กลับเป็น `null`; เมื่อ deadline เปลี่ยน การใช้ `_timer ??=` จึงไม่สร้าง timer ใหม่ ผมจับได้ตอนทบทวน lifecycle ก่อนสรุปงาน แล้วแก้ให้ cancel และ null field ก่อนเริ่ม countdown ใหม่
2. Regression test ของ F-1 รอบแรกส่ง `key` ให้ `_CountdownHarness` แต่ constructor ยังไม่ได้รับ `super.key` Analyzer แจ้ง `undefined_named_parameter`; ผมเพิ่ม `super.key` แล้วรัน analyzer ซ้ำจนเหลือเพียง info เรื่อง `material.dart` deprecated

## คำถามด้านการออกแบบ

### Q1: lifecycle ของ `GetxController` ต่างจาก widget `State` อย่างไร?

`GetxController` มี lifecycle ตามการลงทะเบียนและการผูกกับ route/DI เช่น `onInit()` และ `onClose()` ส่วน `State` มี lifecycle ตามการ mount/unmount ใน widget tree เช่น `initState()` และ `dispose()` การปิด widget ไม่ได้แปลว่า subscription ของ controller หรือ service ถูกยกเลิกเอง RES-103 เกิดจาก controller หน้าดีลสมัคร `ever()` กับ `CartService` ที่อยู่ทั้ง session แต่ไม่ dispose `Worker` ใน `onClose()`; RES-102 เป็นกรณีคู่กันที่ widget `State` สร้าง timer แต่ไม่ cancel ใน `dispose()`

### Q2: `Obx` ที่ครอบ subtree ใหญ่มีปัญหาเมื่อไร และควร scope อย่างไร?

เมื่อ observable ใดเปลี่ยน `Obx` จะ rebuild subtree ทั้งหมดที่อยู่ภายใน; หากครอบทั้ง card หรือ list การเปลี่ยนค่าถี่ ๆ อาจทำให้ layout และ build งานจำนวนมากซ้ำโดยไม่จำเป็น ควรวาง `Obx` ให้ใกล้ widget ที่แสดงค่านั้น เช่นครอบเฉพาะ badge/ปุ่มที่ขึ้นกับ Rx ส่วน countdown ใช้ notifier เฉพาะ Text เพื่อไม่ rebuild card หรือ list ทั้งก้อน

### Q3: จะทดสอบ RES-106 ก่อน release อย่างไร และต้องปรับโค้ดอะไร?

เพิ่ม model test ที่ใช้ instant UTC ซึ่งเมื่อแปลงเป็น timezone ที่ต้องการตรงกับช่วงท้องถิ่น 06:00–09:30 แล้วตรวจทั้ง `label` และ `isToday`; เพิ่มกรณีข้ามเที่ยงคืน/เดือนเพื่อจับการเทียบแค่เลขวันด้วย เพื่อให้ deterministic ควรแยกการอ่านเวลาปัจจุบันเป็น clock ที่ inject ได้ และแยก timezone ของตลาด/ร้านออกจาก `DateTime.now().toLocal()` ให้ทดสอบหรือกำหนดได้ชัดเจน หากผลิตภัณฑ์รับประกันตลาด Bangkok ให้ test ระบุ timezone นั้นโดยตรง แทนพึ่ง timezone ของเครื่องที่รัน test
