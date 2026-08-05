// © 2024-2026 Charo Team. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
/// AppStrings — централизованный доступ ко всем строкам приложения.
///
/// Используется вместо slang/i18n JSON для прямого доступа в коде.
/// JSON-файлы в lib/i18n/ используются для динамической локализации.
class AppStrings {
  AppStrings._();

  static const String appName = "ЧАРО";
  static const String appTagline = "Быстрый. Приватный. Мощный.";

  // ─── Auth ────────────────────────────────────────────────
  static const String login = "Войти";
  static const String register = "Регистрация";
  static const String phone = "Телефон";
  static const String password = "Пароль";
  static const String confirmPassword = "Подтвердить пароль";
  static const String forgotPassword = "Забыли пароль?";
  static const String otpVerification = "Верификация OTP";
  static const String enterOtpCode = "Введите код из SMS";
  static const String resendCode = "Отправить снова";
  static const String welcome = "Добро пожаловать!";
  static const String loginSuccess = "Вы успешно вошли";
  static const String registrationSuccess = "Аккаунт создан";
  static const String accountDeleted = "Аккаунт удалён";

  // ─── Chat ────────────────────────────────────────────────
  static const String chats = "Чаты";
  static const String newChat = "Новый чат";
  static const String searchChats = "Поиск чатов";
  static const String noChats = "Нет чатов";
  static const String sendMessage = "Отправить";
  static const String reply = "Ответить";
  static const String forward = "Переслать";
  static const String edit = "Редактировать";
  static const String delete = "Удалить";
  static const String pin = "Закрепить";
  static const String unpin = "Открепить";
  static const String copy = "Копировать";
  static const String typing = "печатает…";
  static const String online = "в сети";
  static const String lastSeen = "был(а) в";
  static const String messageEncrypted = "🔐 Зашифровано";
  static const String voiceMessage = "🎤 Голосовое";
  static const String videoMessage = "📹 Видео";
  static const String fileAttached = "📎 Файл";

  // ─── Calls ────────────────────────────────────────────────
  static const String calls = "Звонки";
  static const String voiceCall = "Голосовой звонок";
  static const String videoCall = "Видеозвонок";
  static const String callEnded = "Звонок завершён";
  static const String callMissed = "Пропущенный звонок";
  static const String callIncoming = "Входящий звонок";
  static const String callOutgoing = "Исходящий звонок";
  static const String mute = "Микрофон";
  static const String camera = "Камера";
  static const String speaker = "Динамик";

  // ─── Settings ────────────────────────────────────────────
  static const String settings = "Настройки";
  static const String appearance = "Внешний вид";
  static const String notifications = "Уведомления";
  static const String privacy = "Приватность";
  static const String network = "Сеть";
  static const String storage = "Хранилище";
  static const String language = "Язык";
  static const String about = "О приложении";
  static const String energy = "Энергосбережение";
  static const String mediaQuality = "Качество медиа";
  static const String deleteAccount = "Удалить аккаунт";
  static const String darkTheme = "Тёмная тема";
  static const String lightTheme = "Светлая тема";
  static const String fontSize = "Размер шрифта";
  static const String chatBackground = "Обложка чата";

  // ─── Stickers ────────────────────────────────────────────
  static const String stickers = "Стикеры";
  static const String emoji = "Эмодзи";
  static const String gif = "GIF";
  static const String stickerImport = "Импорт стикеров";
  static const String fromTelegram = "Из Telegram";
  static const String fromVk = "Из VK";
  static const String fromWhatsapp = "Из WhatsApp";
  static const String fromViber = "Из Viber";

  // ─── Stories ────────────────────────────────────────────
  static const String stories = "Истории";
  static const String addStory = "Добавить историю";
  static const String viewStory = "Просмотр";

  // ─── Profile ────────────────────────────────────────────
  static const String profile = "Профиль";
  static const String username = "Имя пользователя";
  static const String displayName = "Отображаемое имя";
  static const String bio = "О себе";
  static const String avatar = "Аватар";
  static const String changeAvatar = "Изменить аватар";

  // ─── Errors ────────────────────────────────────────────
  static const String errorNetwork = "Ошибка сети";
  static const String errorAuth = "Ошибка авторизации";
  static const String errorEncryption = "Ошибка шифрования";
  static const String errorUnknown = "Неизвестная ошибка";
  static const String errorRateLimit = "Слишком много запросов";

  // ─── Accessibility ────────────────────────────────────
  static const String accessibility = "Специальные возможности";
  static const String accessibilityHighContrast = "Высокая контрастность";
  static const String accessibilityLargeText = "Увеличенный текст";
  static const String accessibilityScreenReader = "Экранный диктор";

  // ─── Privacy Policy ────────────────────────────────────
  static const String privacyPolicy = "Политика приватности";
  static const String termsOfService = "Условия использования";
  static const String dataDeletion = "Удаление данных";
  static const String e2eeNotice = "Все сообщения зашифрованы E2EE";
}
