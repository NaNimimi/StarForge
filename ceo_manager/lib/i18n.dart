import 'package:flutter/widgets.dart';
import 'settings.dart';

/// Tiny in-app translation table. Each value is `[uz, ru, en]` matching
/// [SfLang.index]. Demo *content* (names, money, AI quotes, message bodies) is
/// intentionally left in its original language — only the app chrome is
/// translated, which is what makes the language switch visibly work.
const Map<String, List<String>> _strings = {
  // ── Login ─────────────────────────────────────────────────────────────
  'brand_sub': ["O'quv markazi boshqaruvi", 'Управление учебным центром', 'Education center management'],
  'login_title': ['Hisobga kirish', 'Вход в систему', 'Sign in'],
  'login_sub': [
    'Konsolingizga kirish uchun login va parol',
    'Введите логин и пароль для входа',
    'Enter your login and password',
  ],
  'login_hint': ['Login', 'Логин', 'Login'],
  'pass_hint': ['Parol', 'Пароль', 'Password'],
  'sign_in': ['Kirish', 'Войти', 'Sign in'],
  'err_empty': ['Login va parolni kiriting', 'Введите логин и пароль', 'Enter login and password'],
  'err_wrong': ["Login yoki parol noto'g'ri", 'Неверный логин или пароль', 'Wrong login or password'],

  // ── Tabs ──────────────────────────────────────────────────────────────
  'tab_dash': ['Panel', 'Панель', 'Panel'],
  'tab_students': ["O'quvchi", 'Ученики', 'Students'],
  'tab_messages': ['Xabar', 'Чат', 'Chat'],
  'tab_ai': ['AI', 'AI', 'AI'],
  'tab_approvals': ['Tasdiq', 'Заявки', 'Approve'],
  'tab_anomalies': ['Signal', 'Сигналы', 'Signals'],
  'tab_cases': ['Holat', 'Дела', 'Cases'],
  'tab_profile': ['Profil', 'Профиль', 'Profile'],

  // ── Dashboard ─────────────────────────────────────────────────────────
  'greet_ceo': ['Boshqaruv', 'Руководство', 'Management'],
  'greet_manager': ['Filial paneli', 'Панель филиала', 'Branch panel'],
  'greet_audit': ['Audit paneli', 'Панель аудита', 'Audit panel'],
  'scope_all': ['Barcha filiallar', 'Все филиалы', 'All branches'],
  'scope_audit': ['Barcha filiallar · nazorat', 'Все филиалы · контроль', 'All branches · oversight'],
  'kpi_revenue': ['Oylik daromad', 'Доход за месяц', 'Monthly revenue'],
  'kpi_students': ["O'quvchilar", 'Ученики', 'Students'],
  'kpi_attendance': ['Davomat', 'Посещаемость', 'Attendance'],
  'kpi_debt': ['Qarzdorlik', 'Задолженность', 'Debt'],
  'card_revenue12': ['Daromad · 12 oy', 'Доход · 12 мес', 'Revenue · 12 mo'],
  'link_ledger': ['Kassa daftari', 'Кассовая книга', 'Cash ledger'],
  'card_branch_rank': ['Filiallar reytingi', 'Рейтинг филиалов', 'Branch ranking'],
  'link_all': ['Hammasi', 'Все', 'All'],
  'card_attendance_health': ['Davomat salomatligi', 'Состояние посещаемости', 'Attendance health'],
  'legend_good': ['Yaxshi', 'Хорошо', 'Good'],
  'legend_mid': ["O'rta", 'Средне', 'Medium'],
  'legend_low': ['Past', 'Низко', 'Low'],
  'card_approvals': ['Tasdiqlash', 'Заявки', 'Approvals'],
  'no_requests': [
    "Yangi so'rov yo'q — hammasi tasdiqlangan.",
    'Новых заявок нет — всё одобрено.',
    'No new requests — all approved.',
  ],

  // ── Audit dashboard ───────────────────────────────────────────────────
  'kpi_open_flags': ['Ochiq flaglar', 'Открытые флаги', 'Open flags'],
  'kpi_active_cases': ['Faol holatlar', 'Активные дела', 'Active cases'],
  'kpi_anomaly': ['Anomaliya', 'Аномалии', 'Anomaly'],
  'kpi_compliance': ['Muvofiqlik', 'Соответствие', 'Compliance'],
  'card_anomaly30': ['Anomaliya · 30 kun', 'Аномалии · 30 дней', 'Anomalies · 30 days'],
  'card_recent_flags': ["So'nggi flaglar", 'Последние флаги', 'Recent flags'],
  'card_branch_compliance': ['Filiallar muvofiqligi', 'Соответствие филиалов', 'Branch compliance'],

  // ── Screen headers ────────────────────────────────────────────────────
  'students_title': ["O'quvchilar", 'Ученики', 'Students'],
  'unit_student': ["o'quvchi", 'учеников', 'students'],
  'anomalies_title': ['Anomaliyalar', 'Аномалии', 'Anomalies'],
  'unit_open_signal': ['ochiq signal', 'открытых сигналов', 'open signals'],
  'approvals_title': ['Tasdiqlash', 'Заявки', 'Approvals'],
  'unit_request': ["so'rov", 'заявок', 'requests'],
  'branches_title': ['Filiallar', 'Филиалы', 'Branches'],
  'unit_branch': ['filial', 'филиалов', 'branches'],
  'cases_title': ['Holatlar', 'Дела', 'Cases'],
  'unit_active_case': ['faol holat', 'активных дел', 'active cases'],
  // Audit anomaly / case detail pages
  'anom_details': ["Ma'lumotlar", 'Детали', 'Details'],
  'anom_kind': ['Turi', 'Тип', 'Kind'],
  'anom_sev': ['Daraja', 'Уровень', 'Severity'],
  'anom_score': ['AI skor', 'AI скор', 'AI score'],
  'anom_detected': ['Aniqlangan', 'Обнаружено', 'Detected'],
  'anom_why': ['Nega belgilandi', 'Почему отмечено', 'Why flagged'],
  'anom_reco': ['Tavsiya', 'Рекомендация', 'Recommendation'],
  'case_status_label': ['Holat', 'Статус', 'Status'],
  'case_timeline': ['Tarix', 'Хронология', 'Timeline'],
  'case_change_status': ["Holatni o'zgartirish", 'Изменить статус', 'Change status'],
  'audit_search_hint': ['Qidirish · filial, tur…', 'Поиск · филиал, тип…', 'Search · branch, kind…'],
  'groups_title': ['Guruhlar', 'Группы', 'Groups'],
  'groups_search': ['Guruh · ustoz qidirish…', 'Поиск · группа, педагог…', 'Search · group, teacher…'],
  'unit_group': ['guruh', 'групп', 'groups'],
  'group_teacher': ['Ustoz', 'Педагог', 'Teacher'],
  'group_avg': ["O'rtacha davomat", 'Средняя посещ.', 'Avg attendance'],
  'messages_title': ['Xabarlar', 'Сообщения', 'Messages'],
  'messages_eyebrow': ['Aloqa markazi', 'Центр связи', 'Communication hub'],
  'ai_title': ['Strategik tahlil', 'Стратегический анализ', 'Strategic analysis'],
  'ai_eyebrow': ['AI yordamchi', 'AI помощник', 'AI assistant'],
  'ai_history': ['Suhbatlar', 'История чатов', 'Chats'],
  'ai_new_chat': ['Yangi suhbat', 'Новый чат', 'New chat'],
  'ai_empty_chat': ["Bo'sh suhbat", 'Пустой чат', 'Empty chat'],
  'profile_title': ['Profil', 'Профиль', 'Profile'],
  'unit_console': ['konsoli', 'консоль', 'console'],

  // ── Filters ───────────────────────────────────────────────────────────
  'f_all': ['Hammasi', 'Все', 'All'],
  'f_debtor': ['Qarzdor', 'Должники', 'Debtors'],
  'f_risky': ['Riskli', 'Риск', 'At risk'],
  'f_group': ['Guruh', 'Группа', 'Group'],
  'f_high': ['Yuqori', 'Высокие', 'High'],
  'f_attendance': ['Davomat', 'Посещ.', 'Attendance'],
  'f_card': ['Karta', 'Карта', 'Card'],
  'f_finance': ['Moliya', 'Финансы', 'Finance'],
  'f_all_branches': ['Barcha filial', 'Все филиалы', 'All branches'],
  'f_all_levels': ['Barcha daraja', 'Все уровни', 'All levels'],
  'f_paid': ["To'langan", 'Оплачено', 'Paid'],
  'f_partial': ['Qisman', 'Частично', 'Partial'],
  'filter_status': ["To'lov holati", 'Статус оплаты', 'Payment status'],
  'filter_call': ["Qo'ng'iroq", 'Звонок', 'Call'],
  'filter_branch': ['Filial', 'Филиал', 'Branch'],
  'filter_level': ['Daraja', 'Уровень', 'Level'],
  'students_search': ['Qidirish · ism, guruh…', 'Поиск · имя, группа…', 'Search · name, group…'],
  'f_open': ['Ochiq', 'Открыт', 'Open'],
  'f_review': ['Tekshir', 'Проверка', 'Review'],
  'f_closed': ['Yopilgan', 'Закрыт', 'Closed'],

  // ── Buttons / actions ─────────────────────────────────────────────────
  'btn_approve': ['Tasdiqlash', 'Одобрить', 'Approve'],
  'btn_reject': ['Rad', 'Отклонить', 'Reject'],
  'btn_save': ['Saqlash', 'Сохранить', 'Save'],
  'btn_switch_role': ['Rolni almashtirish', 'Сменить роль', 'Switch role'],
  'btn_logout': ['Chiqish', 'Выйти', 'Log out'],

  // ── Profile / settings rows ───────────────────────────────────────────
  'set_role': ['Rol va ruxsatlar', 'Роль и доступы', 'Role & permissions'],
  'set_currency': ['Valyuta', 'Валюта', 'Currency'],
  'set_lang': ['Til', 'Язык', 'Language'],
  'set_theme': ['Mavzu', 'Тема', 'Theme'],
  'set_notifs': ['Bildirishnomalar', 'Уведомления', 'Notifications'],
  'set_security': ['Xavfsizlik · 2FA', 'Безопасность · 2FA', 'Security · 2FA'],
  'theme_light': ["Yorug'", 'Светлая', 'Light'],
  'theme_dark': ['Qora', 'Тёмная', 'Dark'],
  'on': ['Yoniq', 'Вкл', 'On'],
  'enabled': ['Yoqilgan', 'Включено', 'Enabled'],
  'all_sections': ['Barcha bo‘limlar', 'Все разделы', 'All sections'],
  'all_sections_sub': [
    'Filiallar, xodimlar, moliya, audit…',
    'Филиалы, сотрудники, финансы, аудит…',
    'Branches, staff, finance, audit…',
  ],
  'all_modules': ['Barcha modullar', 'Все модули', 'All modules'],
  'all_modules_sub': [
    "Davomat, to'lovlar, imtihonlar, kamera…",
    'Посещаемость, оплаты, экзамены, камера…',
    'Attendance, payments, exams, camera…',
  ],
  'lang_uz': ["O'zbekcha", "Узбекский", 'Uzbek'],
  'lang_ru': ['Ruscha', 'Русский', 'Russian'],
  'lang_en': ['Inglizcha', 'Английский', 'English'],
  'lang_pick': ['Tilni tanlang', 'Выберите язык', 'Choose language'],
  'exit_confirm': [
    'Chiqish uchun yana bir marta bosing',
    'Нажмите ещё раз, чтобы выйти',
    'Press back again to exit',
  ],

  // ── Report screen ─────────────────────────────────────────────────────
  'report_title': ['Hisobot', 'Отчёт', 'Report'],
  'report_audit_title': ['Audit hisoboti', 'Аудит-отчёт', 'Audit report'],
  'report_period': ['May 2026 · oylik', 'Май 2026 · месяц', 'May 2026 · monthly'],
  'report_summary': ['Asosiy ko‘rsatkichlar', 'Ключевые показатели', 'Key metrics'],
  'report_finance': ['Moliyaviy holat', 'Финансовое состояние', 'Financial position'],
  'report_branches': ['Filiallar kesimi', 'По филиалам', 'By branch'],
  'report_compliance': ['Nazorat holati', 'Состояние контроля', 'Compliance status'],
  'report_export': ['PDF eksport', 'Экспорт PDF', 'Export PDF'],
  'report_exported': ['📄 Hisobot PDF tayyorlandi (demo)', '📄 Отчёт PDF готов (демо)', '📄 Report PDF ready (demo)'],
  'report_gen': ['Avtomatik tayyorlandi', 'Сформировано автоматически', 'Generated automatically'],

  // ── Create sheet ──────────────────────────────────────────────────────
  'create_branch': ['Yangi filial', 'Новый филиал', 'New branch'],
  'create_group': ['Yangi guruh', 'Новая группа', 'New group'],
  'create_case': ['Yangi holat', 'Новое дело', 'New case'],
  'create_name': ['Nomi', 'Название', 'Name'],
  'create_owner': ["Mas'ul", 'Ответственный', 'Owner'],
  'create_note': ['Izoh', 'Заметка', 'Note'],
  'create_submit': ['Yaratish', 'Создать', 'Create'],
  'create_cancel': ['Bekor qilish', 'Отмена', 'Cancel'],
  'create_done': ['✓ Yaratildi (demo)', '✓ Создано (демо)', '✓ Created (demo)'],
  'create_need_name': ['Nomini kiriting', 'Введите название', 'Enter a name'],

  // ── Settings page ─────────────────────────────────────────────────────
  'settings_title': ['Sozlamalar', 'Настройки', 'Settings'],
  'settings_eyebrow': ['Ilova sozlamalari', 'Настройки приложения', 'App preferences'],
  'appearance': ["Ko'rinish", 'Внешний вид', 'Appearance'],
  'language': ['Til', 'Язык', 'Language'],

  // ── Avatar picker ─────────────────────────────────────────────────────
  'avatar_title': ['Avatar', 'Аватар', 'Avatar'],
  'avatar_eyebrow': ['Rasmni tanlang', 'Выберите фото', 'Choose your photo'],
  'avatar_photos': ['Suratlar', 'Фотографии', 'Photos'],
  'avatar_colors': ['Belgilar', 'Значки', 'Badges'],
  'avatar_saved': ['Avatar yangilandi', 'Аватар обновлён', 'Avatar updated'],

  // ── Chat page ─────────────────────────────────────────────────────────
  'online': ['onlayn', 'онлайн', 'online'],
  'msg_hint': ['Xabar yozing…', 'Напишите сообщение…', 'Type a message…'],
  'ai_hint': ['Savol yozing…', 'Задайте вопрос…', 'Ask a question…'],

  // ── Notifications ─────────────────────────────────────────────────────
  'notifs_title': ['Bildirishnomalar', 'Уведомления', 'Notifications'],
  'notif_mark_read': ["Hammasini o'qilgan deb belgilash", 'Отметить всё прочитанным', 'Mark all as read'],
  'notif_all_read': ['✓ Bildirishnomalar tozalandi', '✓ Уведомления очищены', '✓ Notifications cleared'],
  'notif_new': ['yangi', 'новых', 'new'],
  'notif_today': ['Bugun', 'Сегодня', 'Today'],
  'notif_earlier': ['Avvalroq', 'Ранее', 'Earlier'],

  // ── Messages filters ──────────────────────────────────────────────────
  'f_direct': ['Shaxsiy', 'Личные', 'Direct'],
  'f_groups': ['Guruhlar', 'Группы', 'Groups'],
  'f_unread': ["O'qilmagan", 'Непрочит.', 'Unread'],
  'no_messages': ['Bu filtrda suhbat yo‘q', 'Нет чатов по этому фильтру', 'No chats in this filter'],
  'f_archive': ['Arxiv', 'Архив', 'Archive'],
  'msg_pinned': ['Mahkamlangan', 'Закреплённые', 'Pinned'],
  'msg_pin': ['Mahkamlash', 'Закрепить', 'Pin'],
  'msg_unpin': ['Mahkamlashni olish', 'Открепить', 'Unpin'],
  'msg_archive': ['Arxivlash', 'В архив', 'Archive'],
  'msg_unarchive': ['Arxivdan olish', 'Из архива', 'Unarchive'],
  'msg_mark_read': ["O'qilgan deb belgilash", 'Отметить прочитанным', 'Mark as read'],
  'msg_search': ['Suhbatlarni qidirish…', 'Поиск чатов…', 'Search chats…'],
  'pick_filter': ['Boshqa filtrni tanlang.', 'Выберите другой фильтр.', 'Try another filter.'],

  // ── Ledger entry detail ───────────────────────────────────────────────
  'tx_title': ['Harakat tafsiloti', 'Детали операции', 'Transaction details'],
  'tx_inflow': ['Kirim', 'Приход', 'Inflow'],
  'tx_outflow': ['Chiqim', 'Расход', 'Outflow'],
  'tx_type': ['Turi', 'Тип', 'Type'],
  'tx_channel': ['Kanal', 'Канал', 'Channel'],
  'tx_who': ['Tomon', 'Сторона', 'Party'],
  'tx_time': ['Vaqt', 'Время', 'Time'],
  'tx_id': ['Hujjat ID', 'ID документа', 'Document ID'],
  'tx_status': ['Holat', 'Статус', 'Status'],
  'tx_confirmed': ['Tasdiqlangan', 'Подтверждено', 'Confirmed'],
  'tx_immutable': [
    "Bu yozuv o'zgarmas — kassa daftarining bir qismi.",
    'Эта запись неизменна — часть кассовой книги.',
    'This record is immutable — part of the ledger.',
  ],

  // ── Student detail ────────────────────────────────────────────────────
  'stu_trend': ['Davomat tendensiyasi · 8 hafta', 'Тренд посещаемости · 8 нед', 'Attendance trend · 8 wks'],
  'stu_status': ['Holat', 'Статус', 'Status'],
  'stu_call': ['Ota-onaga qo‘ng‘iroq', 'Звонок родителю', 'Call parent'],
  'stu_remind': ['To‘lov eslatmasi', 'Напоминание об оплате', 'Payment reminder'],
  'stu_message': ['Xabar yuborish', 'Отправить сообщение', 'Send message'],
  'stat_attendance': ['Davomat', 'Посещаемость', 'Attendance'],
  'stat_debt': ['Qarzdorlik', 'Задолженность', 'Debt'],
  // Student full profile
  'stu_personal': ['Shaxsiy maʼlumotlar', 'Личные данные', 'Personal info'],
  'stu_fname': ['Ism', 'Имя', 'First name'],
  'stu_lname': ['Familiya', 'Фамилия', 'Surname'],
  'stu_level': ['Daraja', 'Уровень', 'Level'],
  'stu_age': ['Yosh', 'Возраст', 'Age'],
  'stu_id': ['ID raqami', 'ID номер', 'ID number'],
  'stu_group': ['Guruh', 'Группа', 'Group'],
  'stu_branch': ['Filial', 'Филиал', 'Branch'],
  'stu_enrolled': ['Qabul sanasi', 'Дата зачисления', 'Enrolled'],
  'stu_phone': ['Telefon', 'Телефон', 'Phone'],
  'stu_contacts': ['Aloqa', 'Контакты', 'Contacts'],
  'stu_parents': ['Ota-ona', 'Родители', 'Parents'],
  'stu_father': ['Ota', 'Отец', 'Father'],
  'stu_mother': ['Ona', 'Мать', 'Mother'],
  'stu_years': ['yosh', 'лет', 'yrs'],
  'stu_cabinet': ['Shaxsiy kabinet · xabar', 'Личный кабинет · сообщение', 'Personal cabinet · message'],
  'dm_hint': ['Xabar yozing…', 'Напишите сообщение…', 'Write a message…'],
  // Call status (green / amber / red by recency of last parent call)
  'call_recent': ["Yaqinda qo'ng'iroq", 'Звонок недавно', 'Called recently'],
  'call_mid': ['Ancha oldin', 'Звонили давно', 'A while ago'],
  'call_old': ["Juda ko'p oldin", 'Очень давно', 'Long ago'],
  'call_never_d': ['bugun', 'сегодня', 'today'],
  'call_days_ago': ['kun oldin', 'дн назад', 'd ago'],
  'call_last': ["Oxirgi qo'ng'iroq", 'Последний звонок', 'Last call'],
  // Edit profile
  'edit_profile': ['Profilni tahrirlash', 'Редактировать профиль', 'Edit profile'],
  'edit_jobtitle': ['Lavozim', 'Должность', 'Job title'],
  'change_photo': ["Rasmni o'zgartirish", 'Изменить фото', 'Change photo'],
  'save': ['Saqlash', 'Сохранить', 'Save'],
  'profile_saved': ['✓ Profil saqlandi', '✓ Профиль сохранён', '✓ Profile saved'],

  // ── Dashboard (web design) ────────────────────────────────────────────
  'dash_title_ceo': ['Boshqaruv paneli', 'Панель управления', 'Management panel'],
  'dash_title_manager': ['Filial paneli', 'Панель филиала', 'Branch panel'],
  'dash_eyebrow_ceo': ['Seshanba · 19 May 2026 · 4 filial', 'Вторник · 19 мая 2026 · 4 филиала', 'Tuesday · 19 May 2026 · 4 branches'],
  'dash_eyebrow_manager': ['Yunusobod filiali · 19 May 2026', 'Филиал Юнусабад · 19 мая 2026', 'Yunusobod branch · 19 May 2026'],
  'dash_sub_ceo': ['Barcha filiallar bo‘yicha jonli ko‘rsatkichlar', 'Живые показатели по всем филиалам', 'Live metrics across all branches'],
  'dash_sub_manager': ['512 o‘quvchi · 28 guruh · 16 xodim', '512 учеников · 28 групп · 16 сотрудников', '512 students · 28 groups · 16 staff'],
  'search_hint': ['Hamma narsa bo‘yicha izlash…', 'Поиск по всему…', 'Search everything…'],
  'btn_report': ['Hisobot', 'Отчёт', 'Report'],
  'btn_new_branch': ['Yangi filial', 'Новый филиал', 'New branch'],
  'btn_new_group': ['Yangi guruh', 'Новая группа', 'New group'],
  'btn_audit_report': ['Audit hisoboti', 'Аудит-отчёт', 'Audit report'],
  'btn_new_case': ['Yangi holat', 'Новое дело', 'New case'],
  'kpi_churn': ['Churn (ketish)', 'Churn (отток)', 'Churn'],
  'kpi_nps': ['NPS · qoniqish', 'NPS · удовл.', 'NPS · satisfaction'],
  'kpi_pending': ['Tasdiq kutmoqda', 'Ждут заявки', 'Pending'],
  'kpi_anom_score': ['Anomaliya skori', 'Скор аномалий', 'Anomaly score'],
  'kpi_checked': ['Tekshirilgan', 'Проверено', 'Checked'],
  'audit_eyebrow': ['Barcha filiallar · nazorat · 19 May 2026', 'Все филиалы · контроль · 19 мая 2026', 'All branches · oversight · 19 May 2026'],
  'audit_sub': ['Anomaliyalar, adolat va muvofiqlik monitoringi', 'Мониторинг аномалий, справедливости и соответствия', 'Anomaly, fairness & compliance monitoring'],
  'card_rev_dynamics': ['Daromad dinamikasi · 12 oy', 'Динамика дохода · 12 мес', 'Revenue dynamics · 12 mo'],
  'card_branch_rev': ['Filial daromadi · 12 oy', 'Доход филиала · 12 мес', 'Branch revenue · 12 mo'],
  'card_anom_signals': ['Anomaliya signallari · 30 kun', 'Сигналы аномалий · 30 дней', 'Anomaly signals · 30 days'],
  'card_pending_today': ['Bugungi tasdiqlash', 'Заявки на сегодня', 'Today’s approvals'],
  'card_case_status': ['Holatlar holati', 'Статус дел', 'Case status'],
  'seg_12mo': ['12 oy', '12 мес', '12 mo'],
  'seg_6mo': ['6 oy', '6 мес', '6 mo'],
  'seg_ytd': ['YTD', 'YTD', 'YTD'],
  'foot_forecast': ['Yillik prognoz', 'Годовой прогноз', 'Yearly forecast'],
  'foot_avg_check': ['O‘rtacha chek', 'Средний чек', 'Avg check'],
  'foot_pay_rate': ['To‘lov darajasi', 'Уровень оплат', 'Payment rate'],
  'legend_open_serious': ['Ochiq · jiddiy', 'Открыто · серьёзно', 'Open · serious'],
  'legend_reviewing': ['Tekshirilmoqda', 'На проверке', 'Reviewing'],
  'legend_closed': ['Yopilgan', 'Закрыто', 'Closed'],
  'unit_total': ['JAMI', 'ВСЕГО', 'TOTAL'],

  // ── Tweaks panel (design control) ─────────────────────────────────────
  'tweaks_title': ['Ko‘rinishni sozlash', 'Настройка вида', 'Customize look'],
  'tweaks_sub': ['Rang, zichlik, fon — jonli', 'Цвет, плотность, фон — вживую', 'Color, density, pattern — live'],
  'tw_palette': ['Rang mavzusi', 'Цветовая тема', 'Color theme'],
  'tw_theme': ['Rejim', 'Режим', 'Mode'],
  'tw_density': ['Zichlik', 'Плотность', 'Density'],
  'tw_dense_s': ['Ixcham', 'Плотно', 'Compact'],
  'tw_dense_m': ['O‘rta', 'Средне', 'Regular'],
  'tw_dense_l': ['Bo‘sh', 'Просторно', 'Comfy'],
  'tw_pattern': ['Fon naqshi', 'Фон', 'Pattern'],
  'pat_none': ['Yo‘q', 'Нет', 'None'],
  'pat_dots': ['Nuqta', 'Точки', 'Dots'],
  'pat_grid': ['To‘r', 'Сетка', 'Grid'],
  'pat_tile': ['Naqsh', 'Узор', 'Tile'],
  'pat_topo': ['Chiziq', 'Линии', 'Lines'],
  'tw_reset': ['Asliga qaytarish', 'Сбросить', 'Reset'],
  'tw_font': ['Shrift', 'Шрифт', 'Font'],
  'tw_layout': ['Layout', 'Макет', 'Layout'],
  'tw_menu_order': ['Bo‘limlar', 'Разделы', 'Sections'],
  'tw_done': ['Tayyor', 'Готово', 'Done'],
  'lay_sidebar': ['Sidebar', 'Боковая', 'Sidebar'],
  'lay_sidebar_d': ['Klassik chap panel', 'Классическая панель', 'Classic left panel'],
  'lay_rail': ['Rail', 'Лента', 'Rail'],
  'lay_rail_d': ['Ixcham ikonka', 'Узкие иконки', 'Compact icons'],
  'lay_topbar': ['Top nav', 'Верхняя', 'Top nav'],
  'lay_topbar_d': ['Yuqori panel', 'Верхняя панель', 'Top bar'],
  'lay_dock': ['Dock', 'Док', 'Dock'],
  'lay_dock_d': ['Suzuvchi dok', 'Плавающий док', 'Floating dock'],
  'lay_zen': ['Zen', 'Дзен', 'Zen'],
  'lay_zen_d': ['Minimal · yashirin', 'Минимал · скрытый', 'Minimal · hidden'],

  // ── Currency names (picker) ───────────────────────────────────────────
  'cur_uzs': ["So'm", 'Сум', "So'm"],
  'cur_usd': ['Dollar', 'Доллар', 'Dollar'],
  'cur_eur': ['Yevro', 'Евро', 'Euro'],
  'cur_rub': ['Rubl', 'Рубль', 'Ruble'],
  'currency_pick': ["Valyutani tanlang", 'Выберите валюту', 'Choose currency'],

  // ── Misc ──────────────────────────────────────────────────────────────
  'coming_soon': ['tez orada (demo)', 'скоро (демо)', 'coming soon (demo)'],
  'pill_high': ['Yuqori', 'Высокий', 'High'],
  'pill_mid': ["O'rta", 'Средний', 'Medium'],
};

/// Localised labels for the grouped navigation ("Barcha bo'limlar"). Keyed by
/// the canonical Uzbek string used in `menuFor`, so the menu translates with
/// the UI language. Falls back to the Uzbek label for anything unmapped.
const Map<String, List<String>> _menuLabels = {
  'Boshqaruv paneli': ['Boshqaruv paneli', 'Панель управления', 'Dashboard'],
  'Audit paneli': ['Audit paneli', 'Панель аудита', 'Audit panel'],
  'Filiallar': ['Filiallar', 'Филиалы', 'Branches'],
  'O‘quvchilar': ['O‘quvchilar', 'Ученики', 'Students'],
  'Guruhlar': ['Guruhlar', 'Группы', 'Groups'],
  'O‘qituvchilar': ['O‘qituvchilar', 'Учителя', 'Teachers'],
  'Xodimlar': ['Xodimlar', 'Сотрудники', 'Staff'],
  'Ota-onalar': ['Ota-onalar', 'Родители', 'Parents'],
  'Bo‘limlar': ['Bo‘limlar', 'Отделы', 'Departments'],
  'HR · Xodimlar': ['HR · Xodimlar', 'HR · Персонал', 'HR · Staff'],
  'Yig‘ilishlar': ['Yig‘ilishlar', 'Собрания', 'Meetings'],
  'To‘lovlar': ['To‘lovlar', 'Платежи', 'Payments'],
  'Oyliklar': ['Oyliklar', 'Зарплаты', 'Payroll'],
  'Xabarlar': ['Xabarlar', 'Сообщения', 'Messages'],
  'Suhbat nazorati': ['Suhbat nazorati', 'Контроль чатов', 'Chat oversight'],
  'AI tahlil': ['AI tahlil', 'AI-анализ', 'AI analysis'],
  'Ruxsatlar · RBAC': ['Ruxsatlar · RBAC', 'Доступы · RBAC', 'Permissions · RBAC'],
  'Lidlar · Qabul': ['Lidlar · Qabul', 'Лиды · Приём', 'Leads · Intake'],
  'Qabul · Test': ['Qabul · Test', 'Приём · Тест', 'Intake · Test'],
  'Tasdiqlash': ['Tasdiqlash', 'Подтверждение', 'Approvals'],
  'Jadval · Xonalar': ['Jadval · Xonalar', 'Расписание · Кабинеты', 'Schedule · Rooms'],
  'Anomaliyalar': ['Anomaliyalar', 'Аномалии', 'Anomalies'],
  'Karta adolati': ['Karta adolati', 'Справедливость карт', 'Card fairness'],
  'Moliyaviy tekshir': ['Moliyaviy tekshir', 'Финансовая проверка', 'Financial audit'],
  'Kirish jurnali': ['Kirish jurnali', 'Журнал входов', 'Access log'],
  'AI monitoring': ['AI monitoring', 'AI-мониторинг', 'AI monitoring'],
  'So‘rovnoma yaxlitligi': ['So‘rovnoma yaxlitligi', 'Целостность опросов', 'Survey integrity'],
  'Holatlar · Flaglar': ['Holatlar · Flaglar', 'Кейсы · Флаги', 'Cases · Flags'],
  'Sozlamalar': ['Sozlamalar', 'Настройки', 'Settings'],
};

const Map<String, List<String>> _groupLabels = {
  'Asosiy': ['Asosiy', 'Основное', 'Main'],
  'Odamlar': ['Odamlar', 'Люди', 'People'],
  'Tashkilot': ['Tashkilot', 'Организация', 'Organization'],
  'Moliya': ['Moliya', 'Финансы', 'Finance'],
  'Aloqa': ['Aloqa', 'Связь', 'Communication'],
  'Operatsiya': ['Operatsiya', 'Операции', 'Operations'],
  'Nazorat': ['Nazorat', 'Контроль', 'Oversight'],
  'Jurnal': ['Jurnal', 'Журнал', 'Logs'],
  'Boshqaruv': ['Boshqaruv', 'Управление', 'Management'],
  'Tizim': ['Tizim', 'Система', 'System'],
};

/// Translate a menu item label (from `menuFor`) to the current UI language.
String menuLabel(BuildContext context, String uzLabel) {
  final lang = SettingsScope.of(context).lang;
  return _menuLabels[uzLabel]?[lang.index] ?? uzLabel;
}

/// Translate a menu group title to the current UI language.
String grpLabel(BuildContext context, String uzTitle) {
  final lang = SettingsScope.of(context).lang;
  return _groupLabels[uzTitle]?[lang.index] ?? uzTitle;
}

/// Translate [key] for the current UI language. Falls back to the key itself
/// (which surfaces missing translations loudly during development).
String tr(BuildContext context, String key) {
  final lang = SettingsScope.of(context).lang;
  final row = _strings[key];
  if (row == null) return key;
  return row[lang.index];
}

/// Same as [tr] but without registering a dependency — for use where the
/// surrounding widget already rebuilds on settings change.
String trLang(SfLang lang, String key) => _strings[key]?[lang.index] ?? key;

/// Localised tab label for a tab [id]; falls back to [fallback] for unknown ids.
String tabLabel(BuildContext context, String id, String fallback) {
  const map = {
    'dash': 'tab_dash',
    'students': 'tab_students',
    'messages': 'tab_messages',
    'ai': 'tab_ai',
    'approvals': 'tab_approvals',
    'anomalies': 'tab_anomalies',
    'cases': 'tab_cases',
    'me': 'tab_profile',
  };
  final key = map[id];
  return key == null ? fallback : tr(context, key);
}

/// Human-readable language name in the current language (for the settings row).
String langName(BuildContext context, SfLang lang) =>
    tr(context, switch (lang) { SfLang.uz => 'lang_uz', SfLang.ru => 'lang_ru', SfLang.en => 'lang_en' });
